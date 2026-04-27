@echo off
echo ========================================
echo Building APK without Agora (smaller size)
echo ========================================
echo.

echo This will create multiple APK files:
echo - app-arm64-v8a-release.apk (for modern phones - SMALLEST)
echo - app-armeabi-v7a-release.apk (for older phones)
echo - app-x86_64-release.apk (for tablets/emulators)
echo - app-universal-release.apk (works on all devices)
echo.

echo Starting build...
flutter build apk --release --split-per-abi

echo.
echo ========================================
echo Build complete!
echo ========================================
echo.
echo APK files are in: build\app\outputs\flutter-apk\
echo.
echo Recommended for distribution:
echo - app-arm64-v8a-release.apk (smallest, works on 95%% of devices)
echo.
pause
