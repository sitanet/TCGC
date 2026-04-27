# APK Size Optimization Guide

## Current Optimizations Applied

### 1. ABI Splitting (Most Important)
- **What it does**: Creates separate APKs for different CPU architectures
- **Size reduction**: ~60-70% per APK
- **Result**: Instead of one 80MB APK, you get:
  - `app-arm64-v8a-release.apk` (~25-30MB) - Modern 64-bit devices (most common)
  - `app-armeabi-v7a-release.apk` (~25-30MB) - Older 32-bit devices
  - `app-x86_64-release.apk` (~25-30MB) - Emulators/tablets
  - `app-universal-release.apk` (~80MB) - Works on all devices (backup)

### 2. Code Minification & Resource Shrinking
- Removes unused code and resources
- Obfuscates code for smaller size
- Already enabled in your build

### 3. Debug Symbol Removal
- Removes debugging information from native libraries
- Reduces Agora SDK size

### 4. Metadata Exclusion
- Removes unnecessary license and metadata files

## Which APK to Use?

### For Google Play Store:
Upload the **universal APK** or use **App Bundle** (recommended):
```bash
flutter build appbundle --release
```
Google Play will automatically serve the right APK size to each device.

### For Direct Distribution:
- **Most users**: Use `app-arm64-v8a-release.apk` (smallest, works on 95% of modern devices)
- **Older devices**: Use `app-armeabi-v7a-release.apk`
- **All devices**: Use `app-universal-release.apk` (largest but guaranteed to work)

## Build Commands

### Build Split APKs (Recommended for size):
```bash
flutter build apk --release --split-per-abi
```

### Build Universal APK (Larger but compatible):
```bash
flutter build apk --release
```

### Build App Bundle (Best for Play Store):
```bash
flutter build appbundle --release
```

## APK Locations After Build

Split APKs will be in:
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk      (~25-30MB)
├── app-armeabi-v7a-release.apk    (~25-30MB)
├── app-x86_64-release.apk         (~25-30MB)
└── app-universal-release.apk      (~80MB)
```

## Why is Agora SDK Large?

The Agora RTC Engine includes:
- Native libraries for audio/video processing
- Multiple codec support (VP8, VP9, H.264, H.265)
- Audio processing (noise suppression, echo cancellation)
- Network optimization code
- Support for multiple CPU architectures

Each architecture adds ~20-25MB to the APK.

## Further Size Reduction Options

If you need even smaller APKs:

1. **Remove unused Agora features** (requires custom Agora SDK build)
2. **Use dynamic feature modules** (advanced)
3. **Compress images** in `assets/images/` folder
4. **Remove unused fonts** if any

## Testing

Always test the split APKs on real devices:
- Test `arm64-v8a` on modern phones (2019+)
- Test `armeabi-v7a` on older phones (2015-2019)
- Keep `universal` as backup for compatibility issues
