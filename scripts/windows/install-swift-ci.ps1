[CmdletBinding()]
param(
    [string]$SwiftVersion = '6.3.3'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw $Message
}

if ($SwiftVersion -ne '6.3.3') {
    Fail "Unsupported CI Swift version: $SwiftVersion"
}

function Find-SwiftExecutable([string]$Root, [string]$Version) {
    $preferred = Join-Path $Root "Toolchains\$Version+Asserts\usr\bin\swift.exe"
    if (Test-Path -LiteralPath $preferred -PathType Leaf) {
        return $preferred
    }

    $toolchains = Join-Path $Root 'Toolchains'
    if (-not (Test-Path -LiteralPath $toolchains -PathType Container)) {
        return $null
    }

    $matches = @(Get-ChildItem -LiteralPath $toolchains -Filter swift.exe -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\$([regex]::Escape($Version))\+Asserts\\usr\bin\swift\.exe$" })
    if ($matches.Count -eq 1) {
        return $matches[0].FullName
    }
    if ($matches.Count -gt 1) {
        Fail "Expected one Swift $Version executable under $Root, found $($matches.Count)."
    }
    return $null
}

function Audit-Swift([string]$Executable, [string]$Version) {
    $output = (& $Executable --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Fail "Swift audit failed with exit code ${LASTEXITCODE}: $output"
    }
    if ($output -notmatch "Swift version $([regex]::Escape($Version))\b") {
        Fail "Unexpected Swift version output: $output"
    }
    if ($output -notmatch 'Target:\s+x86_64-unknown-windows-msvc') {
        Fail "Unexpected Swift target: $output"
    }
    return $output
}

$swiftRoot = Join-Path $env:LOCALAPPDATA 'Programs\Swift'
$runtimeBin = Join-Path $swiftRoot "Runtimes\$SwiftVersion\usr\bin"
$sdkRoot = Join-Path $swiftRoot "Platforms\$SwiftVersion\Windows.platform\Developer\SDKs\Windows.sdk"
$swiftExecutable = Find-SwiftExecutable -Root $swiftRoot -Version $SwiftVersion
$requiresInstall = -not $swiftExecutable
if ($swiftExecutable) {
    $candidateToolchainBin = Split-Path -Parent $swiftExecutable
    $candidateLlvmCov = Join-Path $candidateToolchainBin 'llvm-cov.exe'
    $requiresInstall =
        -not (Test-Path -LiteralPath $candidateLlvmCov -PathType Leaf) -or
        -not (Test-Path -LiteralPath $runtimeBin -PathType Container) -or
        -not (Test-Path -LiteralPath $sdkRoot -PathType Container)
    if ($requiresInstall) {
        Write-Warning 'Existing Swift installation is incomplete; rerunning the verified official installer.'
    }
}

if ($requiresInstall) {
    $downloadUrl = "https://download.swift.org/swift-$SwiftVersion-release/windows10/swift-$SwiftVersion-RELEASE/swift-$SwiftVersion-RELEASE-windows10.exe"
    $expectedSha256 = '235626548F249CD516D3D4D90EEE980DCCAD46F3822DAC1F8E3119B0FEDE94B7'
    $downloadRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
    if (-not (Test-Path -LiteralPath $downloadRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
    }
    $installer = Join-Path $downloadRoot "swift-$SwiftVersion-windows-x64.exe"

    Write-Host "Downloading official Swift $SwiftVersion Windows installer"
    & curl.exe --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 3 --retry-delay 2 --output $installer $downloadUrl
    if ($LASTEXITCODE -ne 0) {
        Fail "Swift installer download failed with exit code $LASTEXITCODE."
    }
    $actualSha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualSha256 -ne $expectedSha256) {
        Fail "Swift installer SHA-256 mismatch: $actualSha256"
    }

    $process = Start-Process -FilePath $installer -ArgumentList @('/quiet', '/norestart') -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -notin @(0, 3010)) {
        Fail "Swift installer exited with code $($process.ExitCode)."
    }
    $swiftExecutable = Find-SwiftExecutable -Root $swiftRoot -Version $SwiftVersion
    if (-not $swiftExecutable) {
        Fail "Swift installer completed without installing the expected executable."
    }
}

$toolchainBin = Split-Path -Parent $swiftExecutable
$llvmCovExecutable = Join-Path $toolchainBin 'llvm-cov.exe'
if (-not (Test-Path -LiteralPath $llvmCovExecutable -PathType Leaf)) {
    Fail "Swift llvm-cov is missing: $llvmCovExecutable"
}
if (-not (Test-Path -LiteralPath $runtimeBin -PathType Container)) {
    Fail "Swift runtime is missing: $runtimeBin"
}
if (-not (Test-Path -LiteralPath $sdkRoot -PathType Container)) {
    Fail "Swift Windows SDK is missing: $sdkRoot"
}
$env:SDKROOT = $sdkRoot
$pathEntries = @($toolchainBin)
if (Test-Path -LiteralPath $runtimeBin -PathType Container) {
    $pathEntries += $runtimeBin
}
$env:Path = (($pathEntries + @($env:Path)) -join [IO.Path]::PathSeparator)
# Native Windows environments can preserve both PATH and Path. Swift Foundation rejects that duplicate.
$normalizedPath = $env:Path
[Environment]::SetEnvironmentVariable('PATH', $null, 'Process')
[Environment]::SetEnvironmentVariable('Path', $null, 'Process')
[Environment]::SetEnvironmentVariable('Path', $normalizedPath, 'Process')
$versionOutput = Audit-Swift -Executable $swiftExecutable -Version $SwiftVersion

foreach ($entry in $pathEntries) {
    if ($env:GITHUB_PATH) {
        Add-Content -LiteralPath $env:GITHUB_PATH -Value $entry -Encoding utf8
    }
}
if ($env:GITHUB_ENV) {
    Add-Content -LiteralPath $env:GITHUB_ENV -Value "SDKROOT=$sdkRoot" -Encoding utf8
}

Write-Host $versionOutput
Write-Host "SDKROOT: $sdkRoot"
