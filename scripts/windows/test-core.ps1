[CmdletBinding()]
param(
   [double]$MinimumLineCoverage = 90.0,
   [string]$ScratchPath = $env:CANGJIE_SWIFTPM_SCRATCH,
   [string]$SwiftVersion = '6.3.3'
)

$ErrorActionPreference = "Stop"

if ($SwiftVersion -ne '6.3.3') {
   throw "Unsupported CI Swift version: $SwiftVersion"
}
$swiftRoot = Join-Path $env:LOCALAPPDATA 'Programs\Swift'
$expectedToolchainBin = Join-Path $swiftRoot "Toolchains\$SwiftVersion+Asserts\usr\bin"
$expectedSwiftExecutable = [IO.Path]::GetFullPath((Join-Path $expectedToolchainBin 'swift.exe'))
$expectedLlvmCovExecutable = [IO.Path]::GetFullPath((Join-Path $expectedToolchainBin 'llvm-cov.exe'))
$swiftExecutable = [IO.Path]::GetFullPath((Get-Command swift -ErrorAction Stop).Source)
$llvmCovExecutable = [IO.Path]::GetFullPath((Get-Command llvm-cov -ErrorAction Stop).Source)
if (-not $swiftExecutable.Equals($expectedSwiftExecutable, [StringComparison]::OrdinalIgnoreCase)) {
   throw "Unexpected Swift executable: $swiftExecutable"
}
if (-not $llvmCovExecutable.Equals($expectedLlvmCovExecutable, [StringComparison]::OrdinalIgnoreCase)) {
   throw "Unexpected llvm-cov executable: $llvmCovExecutable"
}
$versionOutput = (& $swiftExecutable --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch "Swift version $([regex]::Escape($SwiftVersion))\b" -or $versionOutput -notmatch 'Target:\s+x86_64-unknown-windows-msvc') {
   throw "Unexpected Swift toolchain: $versionOutput"
}
$expectedSdkRoot = [IO.Path]::GetFullPath((Join-Path $swiftRoot "Platforms\$SwiftVersion\Windows.platform\Developer\SDKs\Windows.sdk"))
if ([string]::IsNullOrWhiteSpace($env:SDKROOT)) {
   throw 'SDKROOT is not set.'
}
$actualSdkRoot = [IO.Path]::GetFullPath($env:SDKROOT)
if (-not $actualSdkRoot.Equals($expectedSdkRoot, [StringComparison]::OrdinalIgnoreCase)) {
   throw "Unexpected SDKROOT: $actualSdkRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $actualSdkRoot 'SDKSettings.json') -PathType Leaf)) {
   throw "Swift Windows SDK settings are missing under SDKROOT: $actualSdkRoot"
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
   throw "Visual Studio locator is missing: $vswhere"
}
$installations = @(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
$installationPath = $installations | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($installationPath)) {
   throw "Visual Studio with the x64 C++ toolchain was not found."
}
$installationPath = [IO.Path]::GetFullPath($installationPath)
$launchVsDevShell = Join-Path $installationPath "Common7\Tools\Launch-VsDevShell.ps1"
if (-not (Test-Path -LiteralPath $launchVsDevShell -PathType Leaf)) {
   throw "Visual Studio developer shell launcher is missing: $launchVsDevShell"
}
& $launchVsDevShell -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
$linkExecutable = (Get-Command link.exe -ErrorAction Stop).Source
$linkExecutable = [IO.Path]::GetFullPath($linkExecutable)
$visualStudioPrefix = $installationPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $linkExecutable.StartsWith($visualStudioPrefix, [StringComparison]::OrdinalIgnoreCase)) {
   throw "Visual Studio developer environment exposed an unexpected linker: $linkExecutable"
}
foreach ($requiredEnvironmentVariable in @('VCToolsInstallDir', 'WindowsSdkDir', 'INCLUDE', 'LIB')) {
   $value = [Environment]::GetEnvironmentVariable($requiredEnvironmentVariable, 'Process')
   if ([string]::IsNullOrWhiteSpace($value)) {
       throw "Visual Studio developer environment did not set $requiredEnvironmentVariable."
   }
}

# Some Windows launchers preserve both PATH and Path in the native environment
# block. Swift Foundation rejects those case-insensitive duplicates, so collapse
# them before starting any Swift process.
$normalizedPath = $env:Path
[Environment]::SetEnvironmentVariable("PATH", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $null, "Process")
[Environment]::SetEnvironmentVariable("Path", $normalizedPath, "Process")

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))

if ([string]::IsNullOrWhiteSpace($ScratchPath)) {
   if (Test-Path -LiteralPath "F:\DevTools\CangJie" -PathType Container) {
       $ScratchPath = "F:\DevTools\CangJie\SwiftPM\scratch"
   } else {
       $ScratchPath = Join-Path $repoRoot ".build-ci"
   }
}
$ScratchPath = [IO.Path]::GetFullPath($ScratchPath)
New-Item -ItemType Directory -Path $ScratchPath -Force | Out-Null

$temporaryRoot = Join-Path $repoRoot ".build-ci\temp"
$temporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
$runTemporaryPath = [IO.Path]::GetFullPath((Join-Path $temporaryRoot ("test-core-{0}-{1}" -f $PID, [Guid]::NewGuid().ToString("N"))))
$expectedPrefix = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $runTemporaryPath.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
   throw "Refusing to use a temporary path outside the configured root: $runTemporaryPath"
}
New-Item -ItemType Directory -Path $runTemporaryPath -Force | Out-Null
$env:TMP = $runTemporaryPath
$env:TEMP = $runTemporaryPath


$pushedLocation = $false
try {
   Push-Location $repoRoot
   $pushedLocation = $true

   Write-Host "[1/3] Validate Package.swift"
   & $swiftExecutable package dump-package | Out-Null
   if ($LASTEXITCODE -ne 0) { throw "swift package dump-package failed: $LASTEXITCODE" }

   Write-Host "[2/3] Run strict concurrency, warnings-as-errors, and coverage tests"
   & $swiftExecutable test `
       --enable-code-coverage `
       -Xswiftc -strict-concurrency=complete `
       -Xswiftc -warnings-as-errors `
       --scratch-path $ScratchPath
   if ($LASTEXITCODE -ne 0) { throw "swift test failed: $LASTEXITCODE" }

   $testBinary = Get-ChildItem -LiteralPath $ScratchPath -Recurse -File `
       -Filter "CangJieCorePackageTests.xctest" |
       Sort-Object LastWriteTimeUtc -Descending |
       Select-Object -First 1
   $profile = Get-ChildItem -LiteralPath $ScratchPath -Recurse -File `
       -Filter "default.profdata" |
       Sort-Object LastWriteTimeUtc -Descending |
       Select-Object -First 1
   if (-not $testBinary -or -not $profile) {
       throw "Swift coverage executable or default.profdata was not found."
   }

   Write-Host "[3/3] Enforce the CangJieCore line coverage gate"
   $coverageOutput = & $llvmCovExecutable export `
       $testBinary.FullName `
       "-instr-profile=$($profile.FullName)" `
       "-ignore-filename-regex=Tests|\.build|SwiftPM" `
       -summary-only
   if ($LASTEXITCODE -ne 0) { throw "llvm-cov export failed: $LASTEXITCODE" }

   $coverage = ($coverageOutput -join "`n") | ConvertFrom-Json
   $lineCoverage = [double]$coverage.data[0].totals.lines.percent
   Write-Host ("CangJieCore line coverage: {0:N2}% (minimum {1:N2}%)" -f $lineCoverage, $MinimumLineCoverage)
   if ($lineCoverage -lt $MinimumLineCoverage) {
       throw ("Coverage gate failed: {0:N2}% < {1:N2}%" -f $lineCoverage, $MinimumLineCoverage)
   }
} finally {
   if ($pushedLocation) {
       Pop-Location
   }
   if (Test-Path -LiteralPath $runTemporaryPath -PathType Container) {
       Remove-Item -LiteralPath $runTemporaryPath -Recurse -Force -ErrorAction SilentlyContinue
   }
}
