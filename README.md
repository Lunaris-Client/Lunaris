# Lunaris

A cross-platform Discourse client for Windows, macOS, Linux, iOS, and Android.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, 3.29+)

### Linux

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev libjsoncpp-dev lld
```

### macOS

- Xcode (latest stable from the App Store)
- Xcode command-line tools: `xcode-select --install`
- CocoaPods: `brew install cocoapods`

### Windows

- [Visual Studio 2022](https://visualstudio.microsoft.com/) with the **Desktop development with C++** workload (includes MSVC and the Windows SDK)

### Android

- [Android Studio](https://developer.android.com/studio) with the Android SDK and command-line tools
- Accept licenses: `flutter doctor --android-licenses`

### iOS

- macOS with Xcode (latest stable)
- CocoaPods: `brew install cocoapods`
- For physical devices: an Apple Developer account

## Setup

```bash
git clone <repo-url> && cd Lunaris

# Generate platform runner directories (one-time)
bash bin/setup_platforms.sh

# Install dependencies
flutter pub get

# Generate model code (freezed/json_serializable)
dart run build_runner build --delete-conflicting-outputs
```

## Run

```bash
flutter run -d linux    # Linux desktop
flutter run -d macos    # macOS desktop
flutter run -d windows  # Windows desktop
flutter run -d chrome   # Web
flutter run              # Connected Android/iOS device or emulator
```

## Build

```bash
# Linux
flutter build linux --debug
# output: build/linux/x64/debug/bundle/lunaris

# macOS
flutter build macos --debug
# output: build/macos/Build/Products/Debug/lunaris.app

# Windows
flutter build windows --debug
# output: build/windows/x64/runner/Debug/lunaris.exe

# Android APK (split by ABI for smaller sizes)
flutter build apk --split-per-abi
# output: build/app/outputs/flutter-apk/app-*-release.apk

# iOS (requires macOS + Xcode)
flutter build ios
# output: build/ios/iphoneos/Runner.app
```

## Discourse Server Configuration

A Discourse admin must allow Lunaris redirect URLs before users can authenticate.

1. Open your Discourse admin panel: **Admin > Settings > Security**
2. Find the `allowed user api auth redirects` setting
3. Add both values (pipe-separated):

```
http://localhost:*/auth_callback|lunaris://auth_redirect
```

- `http://localhost:*/auth_callback` — used by desktop apps (Linux, macOS, Windows) which spin up a temporary local server to receive the auth callback
- `lunaris://auth_redirect` — used by mobile apps (iOS, Android) via deep linking

Without these entries, Discourse will reject the redirect after a user approves access.

## Verify Environment

Run `flutter doctor` to check that all required tooling is installed and configured for your target platforms.
