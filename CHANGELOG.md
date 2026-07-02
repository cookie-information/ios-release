# Changelog

## 2.0.0

### Breaking changes
- Minimum supported iOS version raised from 11.0 to 15.0.
- Building the SDK now requires a Swift 5.10 toolchain (Xcode 15.3 or newer).

### Fixed
- Privacy pop-up fallback presentation now targets the key window of the foreground-active scene (previously an arbitrary window could be picked in multi-scene apps).
- Storing consents no longer rewrites UserDefaults once per consent item.
- Repaired the unit test suite and both example apps, which no longer compiled against the current SDK API.

### Notes
- If your app needs to support iOS versions older than 15.0, stay on version 1.5.8.
