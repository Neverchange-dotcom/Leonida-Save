@echo off
setlocal EnableExtensions
winget --version
if errorlevel 1 (
    echo Windows could not start WinGet. Install or update App Installer from Microsoft Store and try again.
    pause
    exit /b 1
)

call :install Python.Python.3.12
call :install Microsoft.DotNet.SDK.8
call :install KhronosGroup.VulkanSDK
call :install Git.Git
call :install Gyan.FFmpeg

call :checkVS
if errorlevel 1 (
    winget install -e --id Microsoft.VisualStudio.2022.BuildTools --source winget --accept-source-agreements --accept-package-agreements --custom "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --includeRecommended --wait"
    call :checkVS
    if errorlevel 1 (
        echo C++ Build Tools or Windows SDK 10.0.26100+ could not be verified.
        echo If Build Tools is already installed, use Modify in Visual Studio Installer to add those components.
        set "setup_failed=1"
    )
)

call :llvm
if errorlevel 1 (
    echo LLVM setup failed or the AMDGPU target was unavailable.
    set "setup_failed=1"
)

echo.
echo Checking installed commands using the updated PATH...
powershell.exe -NoProfile -Command "$bad=$false; $env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User'); $p=python --version 2>$null; if($p -match 'Python (\d+\.\d+\.\d+)' -and [version]$Matches[1] -ge [version]'3.12'){ $p }else{ Write-Host 'Python 3.12+ is missing from PATH.'; $bad=$true }; $sdk=dotnet --list-sdks | Select-String '^8\.'; if($sdk){ $sdk }else{ Write-Host '.NET 8 SDK was not detected.'; $bad=$true }; foreach($tool in 'spirv-as','spirv-val','git','ffmpeg'){ $exe=Get-Command $tool -ErrorAction SilentlyContinue; if($exe){ Write-Host $exe.Source }else{ Write-Host ($tool+' was not found on PATH.'); if($tool -ne 'ffmpeg'){ $bad=$true } } }; if($bad){exit 1}"
if errorlevel 1 set "setup_failed=1"

echo.
if defined setup_failed (
    echo Setup needs attention. Review the messages above.
    pause
    exit /b 1
)
echo Required tools verified. You can now launch Build.bat from File Explorer.
pause
exit /b 0

:install
echo.
echo Installing %~1...
winget install -e --id "%~1" --source winget --accept-source-agreements --accept-package-agreements
exit /b

:checkVS
powershell.exe -NoProfile -Command "$base=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)'); $vswhere=Join-Path $base 'Microsoft Visual Studio\Installer\vswhere.exe'; if(-not (Test-Path -LiteralPath $vswhere)){exit 1}; $vs=& $vswhere -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -latest -property installationPath; if(-not $vs){exit 1}; $sdk=Get-ChildItem -LiteralPath (Join-Path $base 'Windows Kits\10\Include') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' -and [version]$_.Name -ge [version]'10.0.26100.0' -and (Test-Path (Join-Path $_.FullName 'um\d3d12.h')) }; if(-not $sdk){exit 1}; $vs; $sdk | ForEach-Object Name; exit 0"
exit /b %errorlevel%

:llvm
set "forge_root=%LOCALAPPDATA%\LeonidaMiniforge"
set "conda_exe=%forge_root%\Scripts\conda.exe"
set "llvm_prefix=%forge_root%\envs\leonida"
set "llvm_exe=%llvm_prefix%\Library\bin\llvm-mc.exe"

if exist "%llvm_exe%" goto llvm_verify
if not exist "%conda_exe%" (
    curl.exe --fail --location --retry 2 --output "%TEMP%\Leonida-Miniforge3.exe" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Windows-x86_64.exe"
    if errorlevel 1 exit /b 1
    start "" /wait "%TEMP%\Leonida-Miniforge3.exe" /InstallationType=JustMe /RegisterPython=0 /S /D=%forge_root%
    if errorlevel 1 exit /b 1
)
if not exist "%conda_exe%" exit /b 1
"%conda_exe%" create --yes --prefix "%llvm_prefix%" --override-channels -c conda-forge "llvm-tools>=21"
if errorlevel 1 exit /b 1

:llvm_verify
if not exist "%llvm_exe%" exit /b 1
"%llvm_exe%" --version | findstr /i /c:"amdgcn"
if errorlevel 1 exit /b 1
setx LLVM_MC "%llvm_exe%"
exit /b %errorlevel%

