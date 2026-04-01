@echo off
chcp 65001 >nul
echo ============================================
echo  ai-enclave setup
echo ============================================
echo.

REM --- intel directory ---
if not exist "C:\intel" (
    echo Creating C:\intel ...
    mkdir "C:\intel"
    echo Done.
) else (
    echo C:\intel already exists. OK.
)
echo.

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
