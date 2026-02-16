# Deploy: APK and Web

## Prerequisites

- Flutter SDK installed and on PATH
- Run once: `flutter pub get`
- For Android APK: Android SDK (Android Studio or command-line tools)
- For Web: Chrome (for testing); no extra SDK needed

---

## 1. Build APK (Android)

From project root:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

- Install on device: copy the APK and open it (enable "Install from unknown sources" if needed).
- For a **smaller split APK per ABI** (optional):  
  `flutter build apk --release --split-per-abi`  
  Outputs: `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`, `app-x86_64-release.apk`.

---

## 2. Build Web

From project root:

```bash
flutter clean
flutter pub get
flutter build web --release
```

**Output:** `build/web/` (static files: `index.html`, JS, CSS, assets)

### Run locally

```bash
flutter run -d chrome
# or after building:
# Serve build/web with any static server, e.g.:
# cd build/web && python -m http.server 8080
```

### Deploy to a server

Upload the **contents** of `build/web/` to your web server (e.g. Firebase Hosting, Netlify, Vercel, or your own server). Ensure:

- The server serves `index.html` for all routes (SPA) if you use Flutter web routing.
- HTTPS is used in production (required for Firebase Auth, etc.).

---

## 3. (Optional) Android App Bundle for Play Store

For Google Play you typically use an App Bundle, not the APK:

```bash
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`  
Upload this `.aab` in Google Play Console.

---

## Quick reference

| Target   | Command                          | Output folder / file                    |
|----------|-----------------------------------|-----------------------------------------|
| APK      | `flutter build apk --release`     | `build/app/outputs/flutter-apk/`        |
| Web      | `flutter build web --release`     | `build/web/`                            |
| App Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/` |
