@echo off
echo Clearing Gradle cache...
rmdir /s /q "%USERPROFILE%\.gradle\caches" 2>nul
echo Gradle cache cleared!
echo.
echo Now run: flutter build apk --release
pause
