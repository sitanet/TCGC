@echo off
echo ========================================
echo Freeing up disk space for Flutter build
echo ========================================
echo.

echo [1/4] Cleaning Flutter build cache...
flutter clean
echo.

echo [2/4] Cleaning Gradle cache...
rmdir /s /q "%USERPROFILE%\.gradle\caches" 2>nul
echo.

echo [3/4] Cleaning Gradle build outputs...
rmdir /s /q "build" 2>nul
rmdir /s /q "android\.gradle" 2>nul
rmdir /s /q "android\build" 2>nul
rmdir /s /q "android\app\build" 2>nul
echo.

echo [4/4] Cleaning pub cache (optional - only if desperate)...
echo Skipping pub cache clean (run 'flutter pub cache clean' manually if needed)
echo.

echo ========================================
echo Cleanup complete!
echo ========================================
echo.
echo Next steps:
echo 1. Check your C: drive space (should have at least 5GB free)
echo 2. Delete unnecessary files if still low on space
echo 3. Run: flutter build apk --release
echo.
pause
