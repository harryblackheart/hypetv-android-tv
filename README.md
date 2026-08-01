# HypeTV for Android TV

HypeTV is a landscape-first Flutter application for Android TV. It uses a
red-and-black Material 3 interface, directional remote navigation, secure
five-digit activation, and responsive layouts designed for 1080p and 4K TVs.

## Included in v1

- Animated HypeTV splash experience
- Five-digit D-pad and keyboard activation screen
- Encrypted activation persistence with `flutter_secure_storage`
- Typed HTTP API client with timeouts and user-facing errors
- Netflix-style home hero and content rails
- Focus animations and automatic D-pad scrolling
- Settings, secure deactivation, and version display
- GitHub Releases update checker
- Android TV Leanback manifest and landscape lock
- GitHub Actions analysis, tests, and debug APK artifact

## Architecture

```text
lib/
├── core/
│   ├── constants/       # Build-time and backend constants
│   ├── network/         # API transport and errors
│   ├── router/          # GoRouter configuration
│   └── theme/           # Material 3 theme and brand tokens
├── features/
│   ├── activation/      # Secure activation state and UI
│   ├── home/            # Catalogue domain, data and TV presentation
│   ├── settings/        # Device and application settings
│   └── splash/          # Startup animation and activation routing
├── services/            # Secure storage and application updates
├── widgets/             # Shared, focus-aware TV components
├── app.dart
└── main.dart
```

Riverpod owns application state and service dependencies. GoRouter owns the
four top-level routes: splash, activation, home, and settings.

## Backend

The API base URL is configured in `lib/core/constants/app_constants.dart`:

```text
https://hypetv-control-centre.opsplatform.workers.dev
```

Activation is isolated in `ApiClient.activate` and currently calls
`POST /api/activate` with:

```json
{"code":"12345","platform":"android_tv"}
```

The client accepts either `token` or `activationToken` from the response. If
the final backend contract changes, only this adapter needs to change.

## Local development

Install Flutter 3.x with Android SDK tooling, connect an Android TV or launch a
TV emulator, then run:

```shell
flutter pub get
flutter analyze
flutter test
flutter run
```

Build a sideloadable debug APK with:

```shell
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Automated builds

Every push and pull request to `main` runs formatting, analysis, tests, and a
debug APK build. Download the `hypetv-debug-apk` artifact from the workflow run
in GitHub Actions. Manual runs are also supported.

## Production notes

- Replace the demo home catalogue with the authenticated catalogue endpoint.
- Supply production launcher and 320×180 TV banner artwork.
- Configure a private release keystore before distributing a release APK/AAB.
- Publish tagged GitHub Releases so the in-app update checker can announce them.
