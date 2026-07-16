[CmdletBinding()]
param(
    [string]$DevRoot = "F:\DevTools\CangJie"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DevRoot)) {
    throw "DevRoot must not be empty."
}

$fullDevRoot = [IO.Path]::GetFullPath($DevRoot)
$root = [IO.Path]::GetPathRoot($fullDevRoot)
if (-not [string]::Equals($root, "F:\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "DevRoot must be located on drive F:. Actual: $fullDevRoot"
}

$directories = @(
    $fullDevRoot,
    (Join-Path $fullDevRoot "SwiftPM\scratch"),
    (Join-Path $fullDevRoot "SwiftPM\cache"),
    (Join-Path $fullDevRoot "ClangModuleCache"),
    (Join-Path $fullDevRoot "Temp")
)

foreach ($directory in $directories) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

[Environment]::SetEnvironmentVariable(
    "CANGJIE_SWIFTPM_SCRATCH",
    (Join-Path $fullDevRoot "SwiftPM\scratch"),
    "User"
)
[Environment]::SetEnvironmentVariable(
    "CLANG_MODULE_CACHE_PATH",
    (Join-Path $fullDevRoot "ClangModuleCache"),
    "User"
)
[Environment]::SetEnvironmentVariable("TMP", (Join-Path $fullDevRoot "Temp"), "User")
[Environment]::SetEnvironmentVariable("TEMP", (Join-Path $fullDevRoot "Temp"), "User")

Write-Host "Prepared CangJie development directory: $fullDevRoot"
Write-Host "Install Swift and Visual Studio Build Tools as documented in M0_VALIDATION.md."
Write-Host "Open a new terminal and run scripts/windows/toolchain-audit.ps1."
