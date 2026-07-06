# Changelog

## 2.0.0

### Breaking changes
- Minimum supported iOS version raised from 11.0 to 15.0.
- Building the SDK now requires a Swift 5.10 toolchain (Xcode 15.3 or newer).

### iOS 26
- Built and verified with the iOS 26 SDK (Xcode 26); the privacy pop-up was visually verified on iOS 26 in light/dark mode, with accessibility text sizes and on iPad.
- The pop-up top bar now respects the safe area (on iOS 26 the transparent navigation bar made the buttons stick to the top edge).
- Removed the last deprecated API usage (`imageEdgeInsets`); the SDK compiles with no warnings.

### Fixed
- Privacy pop-up fallback presentation now targets the key window of the foreground-active scene (previously an arbitrary window could be picked in multi-scene apps).
- Storing consents no longer rewrites UserDefaults once per consent item.
- Repaired the unit test suite and both example apps, which no longer compiled against the current SDK API.

### Notes
- If your app needs to support iOS versions older than 15.0, stay on version 1.5.8.
