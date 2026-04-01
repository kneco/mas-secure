@echo off
chcp 65001 >nul
echo ============================================
echo  ai-enclave setup
echo ============================================
echo.

REM --- Prerequisite Check 1: WSL2 ---
echo [1/3] Checking WSL2...
wsl -l -v >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: WSL2 is not installed.
    echo Please install WSL2 first:
    echo   https://learn.microsoft.com/ja-jp/windows/wsl/install
    echo.
    pause
    exit /b 1
)
echo   WSL2 OK.
echo.

REM --- Prerequisite Check 2: Docker Desktop ---
echo [2/3] Checking Docker Desktop...
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Docker Desktop is not installed.
    echo Please install Docker Desktop first:
    echo   https://docs.docker.com/desktop/setup/install/windows-install/
    echo.
    pause
    exit /b 1
)
echo   Docker Desktop OK.
echo.

REM --- Prerequisite Check 3: Docker Daemon ---
echo [3/3] Checking Docker daemon...
docker info >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Docker Desktop is not running.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)
echo   Docker daemon OK.
echo.

REM --- Intel directory path ---
set "INTEL_DEFAULT=C:\intel"
set "INTEL_PATH="
set /p "INTEL_PATH=Enter intel directory path (default: %INTEL_DEFAULT%): "
if "%INTEL_PATH%"=="" set "INTEL_PATH=%INTEL_DEFAULT%"

REM Create directory if not exists
if not exist "%INTEL_PATH%" (
    echo Creating %INTEL_PATH% ...
    mkdir "%INTEL_PATH%"
    echo Done.
) else (
    echo %INTEL_PATH% already exists. OK.
)
echo.

REM --- Update docker-compose.yml if path differs from default ---
if /i NOT "%INTEL_PATH%"=="%INTEL_DEFAULT%" (
    echo Updating docker-compose.yml with intel path: %INTEL_PATH%
    REM Convert Windows path (C:\foo\bar) to WSL path (/mnt/c/foo/bar)
    powershell -NoProfile -Command ^
        "$p = '%INTEL_PATH%' -replace '\\\\', '/'; ^
         $p = $p -replace '^([A-Za-z]):', { '/mnt/' + $Matches[1].ToLower() }; ^
         (Get-Content 'docker-compose.yml' -Raw) -replace 'source: /mnt/c/intel', ('source: ' + $p) ^
         | Set-Content 'docker-compose.yml' -NoNewline"
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Failed to update docker-compose.yml.
        pause
        exit /b 1
    )
    echo   docker-compose.yml updated.
    echo.
)

REM --- Docker build ---
echo Building Docker image ...
docker compose build
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker build failed.
    pause
    exit /b 1
)
echo Build complete.
echo.

REM --- Start container ---
echo Starting container ...
docker compose up -d
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Container start failed.
    pause
    exit /b 1
)
echo Container started.
echo.

REM --- Summary ---
echo ============================================
echo  Setup complete!
echo ============================================
echo.
echo   Enter the enclave:
echo     docker exec -it ai-enclave bash
echo.
echo   Start code-server (inside container):
echo     code-server --bind-addr 0.0.0.0:8080 /workspace
echo     Then open http://localhost:8080
echo.
echo   Start toast notifications (this PC):
echo     powershell -ExecutionPolicy Bypass -File scripts\ntfy_toast.ps1
echo.
pause
