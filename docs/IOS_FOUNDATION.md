# HypeTV iPhone / iPad foundation

The shared Flutter application is being prepared for iOS and iPadOS without changing Android TV behaviour.

## Permanent Apple identity

- App name: HypeTV
- Intended Bundle ID: `com.hypetv.app`
- Existing Android activation identifier remains `android_tv`.
- Apple mobile activations use `ios`.

## Current validation boundary

The source backup used for this milestone did not contain a committed `ios/` Flutter runner. CI therefore generates a disposable iOS runner on a macOS GitHub runner and performs an unsigned release compile. This validates shared Dart code and Flutter plugins but is not a distributable/TestFlight build.

Before TestFlight, create and commit the permanent iOS Runner from macOS/Xcode, set its Bundle ID to `com.hypetv.app`, configure capabilities and signing, then create the matching App ID/App Store Connect record.

## Secrets

Never commit Apple certificates, provisioning profiles, App Store Connect API private keys, Android JKS files, passwords, or Base64-encoded private keys.
