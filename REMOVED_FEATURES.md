# Removed Features - APK Size Optimization

## What Was Removed

### 1. Agora RTC Engine (Video/Audio Calls)
- **Removed**: `agora_rtc_engine: ^6.3.2` dependency
- **Removed**: Agora Maven repository from build.gradle
- **Removed**: `call_page.dart` - The video/audio call UI
- **Removed**: Call buttons (phone and video icons) from chat interface
- **Removed**: `callUser()` method from CommunityProvider

### 2. Expected APK Size Reduction
- **Before**: ~80-100MB (with Agora SDK)
- **After**: ~20-30MB (without Agora SDK)
- **Reduction**: ~60-70% smaller APK

## What Was Kept

### ✅ Listen Together Feature
- Users can still share audio sermons to chat
- Host controls playback, listeners sync automatically
- Works for both DMs and group rooms
- Uses Flutter's `just_audio` package (lightweight)

### ✅ Audio Recording
- Voice message recording still works
- Uses `record` package (much smaller than Agora)

### ✅ All Other Features
- Chat messaging
- File sharing
- Image sharing
- Sermon library
- Wallet/giving
- All other app functionality

## Technical Changes

### Files Modified:
1. `pubspec.yaml` - Removed agora_rtc_engine dependency
2. `android/build.gradle.kts` - Removed Agora Maven repository
3. `lib/core/providers/community_provider.dart` - Removed callUser() method
4. `lib/presentation/pages/community/chat_room_page.dart` - Removed call buttons and imports

### Files Deleted:
1. `lib/presentation/pages/community/call_page.dart`

## Build Instructions

### Clean build (recommended after removing dependencies):
```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

### Expected output:
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk      (~20-25MB) ✅ Use this for most users
├── app-armeabi-v7a-release.apk    (~20-25MB)
├── app-x86_64-release.apk         (~20-25MB)
└── app-universal-release.apk      (~25-30MB)
```

## If You Need Video/Audio Calls Back

To restore the feature:
1. Add back to `pubspec.yaml`: `agora_rtc_engine: ^6.3.2`
2. Add back Agora Maven repo to `android/build.gradle.kts`
3. Restore `call_page.dart` from git history
4. Restore call buttons in `chat_room_page.dart`
5. Restore `callUser()` method in `community_provider.dart`

## Alternative Solutions for Calls

If you need calling in the future but want smaller APK:
1. **WebRTC** - Use `flutter_webrtc` (smaller than Agora)
2. **Jitsi Meet** - Use `jitsi_meet_flutter_sdk` (external app)
3. **Twilio** - Use Twilio Programmable Video (cloud-based)
4. **Dynamic Feature Module** - Load Agora only when needed (advanced)
