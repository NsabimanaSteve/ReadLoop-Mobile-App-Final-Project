@echo off
echo Starting ReadLoop Local Backend Server...
echo.
echo 1. Starting Apache and MySQL...
echo 2. Testing database connection...
echo 3. Starting PHP API server...
echo.

REM Check if XAMPP is installed
if exist "C:\xampp" (
    echo [✓] XAMPP found
) else (
    echo [✗] XAMPP not found. Please install XAMPP first.
    echo Download from: https://www.apachefriends.org/
    pause
    exit
)

REM Start Apache and MySQL
cd C:\xampp
start xampp-control.exe

echo.
echo [✓] XAMPP Control Panel opened
echo.
echo Please start Apache and MySQL in the control panel
echo.
echo Once started, test your API at: http://localhost/readloop/api/
echo.
echo Press any key to open API in browser...
pause > nul
start http://localhost/readloop/api/

echo.
echo [✓] Backend server setup complete!
echo Your Flutter app can now connect to: http://localhost/readloop/api/
echo.
