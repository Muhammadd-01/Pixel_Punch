# PixelPunch — Release and Build Guide

## 1. Application Identifiers
- **Android Application ID**: `com.nexovate.pixel_punch`
- **iOS Bundle Identifier**: `com.nexovate.pixelPunch`
- **Recommended Orientation**: Landscape Left & Landscape Right (`SystemChrome.setPreferredOrientations`)

---

## 2. Building for Android

### Debug Build
```bash
flutter build apk --debug
```

### Release APK
```bash
flutter build apk --release
```

### Release App Bundle (Google Play)
```bash
flutter build appbundle --release
```

---

## 3. Building for iOS
Requires macOS with Xcode installed:
```bash
flutter build ios --release --no-codesign
```
Open `ios/Runner.xcworkspace` in Xcode to configure Signing & Capabilities with your Apple Developer Team.

---

## 4. Environment Checklist Before Release
- [x] All 26 automated unit and widget tests passing.
- [x] Zero analyzer errors or lints (`dart analyze lib`).
- [x] Bundled JSON data files verified.
- [x] Offline gameplay verified without network access.
- [x] Landscape layout tested on phone and tablet viewports.
- [x] Supabase cloud sync verified with valid publishable key.
