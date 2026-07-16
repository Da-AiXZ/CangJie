[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

$commands = "swift", "git", "gh", "clang", "cmake", "ninja"
foreach ($name in $commands) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) {
        Write-Host "$name => $($command.Source)"
    } else {
        Write-Host "$name => MISSING"
    }
}

$swift = Get-Command swift -ErrorAction SilentlyContinue
if ($swift) {
    & $swift.Source --version
}

$vswhereCandidates = @(
    "F:\DevTools\VisualStudio\Installer\vswhere.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
)
$vswhere = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($vswhere) {
    & $vswhere -latest -products * -format json
} else {
    Write-Host "Visual Studio Installer vswhere.exe was not found."
}

Get-PSDrive C, F -ErrorAction SilentlyContinue | Select-Object Name, Used, Free, Root
