[CmdletBinding()]
param(
   [double]$MinimumLineCoverage = 90.0,
   [string]$ScratchPath = $env:CANGJIE_SWIFTPM_SCRATCH
)

$ErrorActionPreference = "Stop"

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

$swift = Get-Command swift -ErrorAction Stop
$llvmCov = Get-Command llvm-cov -ErrorAction Stop

$pushedLocation = $false
try {
   Push-Location $repoRoot
   $pushedLocation = $true

   Write-Host "[1/3] Validate Package.swift"
   & $swift.Source package dump-package | Out-Null
   if ($LASTEXITCODE -ne 0) { throw "swift package dump-package failed: $LASTEXITCODE" }

   Write-Host "[2/3] Run strict concurrency, warnings-as-errors, and coverage tests"
   & $swift.Source test `
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
   $coverageOutput = & $llvmCov.Source export `
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
