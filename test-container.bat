@echo off
REM Build and test the HTTP Sink container (Windows)
REM This script builds the container and runs acceptance tests

echo Building HTTP Sink container...

if "%VERSION%"=="" set VERSION=dev
if "%GIT_COMMIT%"=="" (
    for /f "tokens=*" %%i in ('git rev-parse --short HEAD 2^>nul') do set GIT_COMMIT=%%i
    if "!GIT_COMMIT!"=="" set GIT_COMMIT=unknown
)

for /f "tokens=*" %%i in ('powershell -Command "Get-Date -Format yyyy-MM-ddTHH:mm:ssZ"') do set BUILD_DATE=%%i

echo Version: %VERSION%
echo Build Date: %BUILD_DATE%
echo Git Commit: %GIT_COMMIT%
echo.

REM Build the container
docker-compose build
if errorlevel 1 (
    echo Build failed!
    exit /b 1
)

echo.
echo Running acceptance tests...
echo.

REM Run acceptance tests
docker-compose up --abort-on-container-exit --exit-code-from acceptance-test
set TEST_EXIT_CODE=%ERRORLEVEL%

REM Cleanup
echo.
echo Cleaning up...
docker-compose down -v

if %TEST_EXIT_CODE% equ 0 (
    echo.
    echo All tests passed!
    exit /b 0
) else (
    echo.
    echo Tests failed!
    exit /b 1
)
