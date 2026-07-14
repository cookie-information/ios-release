# Changelog

## 2.0.0

### Breaking changes
- Minimum supported iOS version raised from 11.0 to 15.0.
- Building the SDK now requires a Swift 5.10 toolchain (Xcode 15.3 or newer).

### iOS 26
- Built and verified with the iOS 26 SDK (Xcode 26); the privacy pop-up was visually verified on iOS 26 in light/dark mode, with accessibility text sizes and on iPad.
- The pop-up top bar now respects the safe area and clears the sheet grabber on iOS 26 (where the transparent navigation bar made the buttons stick to the top edge); the layout on older iOS versions is unchanged.
- Removed the last deprecated API usage (`imageEdgeInsets`); the SDK compiles with no warnings.

### Fixed
- Posting consent before the consent solution has loaded no longer hangs the pop-up spinner: the tap is reported to the SDK, the pop-up stays open and the action can simply be retried.
- The pop-up `completion` and `errorHandler` callbacks are now guaranteed to be invoked at most once per pop-up presentation.
- `cancel()` can safely be called while a request is in flight on another thread.
- Posting an empty consent list no longer erases previously stored consents.
- Privacy pop-up fallback presentation now targets the key window of the foreground-active scene (previously an arbitrary window could be picked in multi-scene apps).
- Storing consents no longer rewrites UserDefaults once per consent item.
- Repaired the unit test suite and both example apps, which no longer compiled against the current SDK API.

### Notes
- If your app needs to support iOS versions older than 15.0, stay on version 1.5.8.
