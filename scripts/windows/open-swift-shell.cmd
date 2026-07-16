@echo off
setlocal
call F:\DevTools\VisualStudio\2022\BuildTools\Common7\Tools\VsDevCmd.bat -arch=x64
if errorlevel 1 exit /b %errorlevel%
set "PATH=F:\DevTools\Swift\Toolchains\6.3.3+Asserts\usr\bin;F:\DevTools\Swift\Runtimes\6.3.3\usr\bin;%PATH%"
set "SDKROOT=F:\DevTools\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk"
set "CLANG_MODULE_CACHE_PATH=F:\DevTools\CangJie\ClangModuleCache"
set "TMP=F:\DevTools\CangJie\Temp"
set "TEMP=F:\DevTools\CangJie\Temp"
if not exist "%CLANG_MODULE_CACHE_PATH%" mkdir "%CLANG_MODULE_CACHE_PATH%"
if not exist "%TMP%" mkdir "%TMP%"
cd /d F:\project\CangJie
cmd /k
