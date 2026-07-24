@echo off
setlocal
call F:\DevTools\VisualStudio\2022\BuildTools\Common7\Tools\VsDevCmd.bat -arch=x64
if errorlevel 1 exit /b %errorlevel%
set "PATH=%LOCALAPPDATA%\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin;%LOCALAPPDATA%\Programs\Swift\Runtimes\6.3.3\usr\bin;%PATH%"
set "SDKROOT=%LOCALAPPDATA%\Programs\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk"
set "CLANG_MODULE_CACHE_PATH=F:\DevTools\CangJie\ClangModuleCache"
set "CANGJIE_SWIFTPM_SCRATCH=%~dp0..\..\.build-ci\swiftpm"
set "TMP=F:\DevTools\CangJie\Temp"
set "TEMP=F:\DevTools\CangJie\Temp"
for %%D in ("%CLANG_MODULE_CACHE_PATH%" "%CANGJIE_SWIFTPM_SCRATCH%" "%TMP%") do if not exist "%%~D" mkdir "%%~D"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-core.ps1"
exit /b %errorlevel%
