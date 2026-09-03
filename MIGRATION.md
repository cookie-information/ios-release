# Migrating from 1.x to 2.0

Version 2.0 adds async/await APIs and changes consent submission to a local-first flow. A submitted decision is saved on the device before the SDK attempts to upload it. Callback APIs and synchronous local-data accessors remain available, but popup callback APIs now require both success and error handlers. The `cancel()` method is removed, and the Boolean network-logging initializer is deprecated.

## Requirements

- iOS 15.0 or newer
- Swift Package Manager: Swift 6.2 or newer (Xcode 26+)

## API changes

| 1.x API | 2.0 API | Action required |
| --- | --- | --- |
| `MobileConsents(..., enableNetworkLogger:)` | `MobileConsents(..., networkLoggingMode:)` | Replace explicit uses of `enableNetworkLogger`. The old initializer remains available but is deprecated. |
| `userId` | `getUserId()` | No immediate change. Use the async method when you need persistence errors to be reported. |
| `getSavedConsents()` | `loadSavedConsents()` | No immediate change. Use the async method when you need persistence errors to be reported. |
| `removeStoredConsents()` | `clearStoredConsents()` | No immediate change. Use the async method when you need confirmation that local removal succeeded. |
| Callback-based popup methods with optional callbacks | Callback methods requiring `completion` and `errorHandler`; async overloads with the same names | Provide both callbacks, or adopt async/await. |
| `synchronizeIfNeeded()` | Async overload returning `Bool` | No immediate change. Use the async overload to check whether pending consent remains after the attempt. |
| `cancel()` | No replacement | Remove calls to `cancel()`. |

Objective-C imports the new async local-data methods as `getUserIdWithCompletionHandler:`, `loadSavedConsentsWithCompletionHandler:`, and `removeStoredConsentsWithCompletionHandler:`.

## Behavioral changes

| Scenario | 1.x behavior | 2.0 behavior | Action required |
| --- | --- | --- | --- |
| `postConsent` completes without an error | The consent has reached the server | The consent has been saved locally; upload runs separately | Do not treat a successful completion as server confirmation. |
| A popup submission succeeds | Completion follows the server request | Completion runs after the decision is saved locally and before popup dismissal begins | Use the returned consents immediately if needed, but do not treat completion as server confirmation. |
| A consent upload fails | The submission or popup error callback receives the network error | The saved decision remains pending for a later attempt, and the background upload error is not forwarded to those callbacks | Do not use popup or submission error callbacks to monitor delivery. |
| A pending upload needs another attempt | `synchronizeIfNeeded()` retries it | The SDK attempts synchronization during initialization, after a local save, when a popup workflow starts, and when `synchronizeIfNeeded()` is called | Call `synchronizeIfNeeded()` when you need to request an additional retry. |
| Another decision is saved before a pending decision for the same solution version is uploaded | Each request is handled separately | The newest pending decision replaces the older pending decision | Do not rely on every intermediate selection reaching the server. |
| The app contains consent data saved by 1.x | Data is stored in the 1.x format | The SDK migrates compatible data automatically | No application-side migration is required. |

## Upgrade steps

1. Update the dependency to version 2.0 and ensure the project meets the requirements above.

2. Replace explicit uses of the Boolean logging option:

   ```diff
   let mobileConsentsSDK = MobileConsents(
       clientID: "<CLIENT_ID>",
       clientSecret: "<CLIENT_SECRET>",
       solutionId: "<SOLUTION_ID>",
   -   enableNetworkLogger: true
   +   networkLoggingMode: .redactedRequestsAndResponses
   )
   ```

3. Remove calls to `cancel()`.

4. Provide both `completion` and `errorHandler` when calling callback-based `showPrivacyPopUp` or `showPrivacyPopUpIfNeeded`. Review popup and `postConsent` completions: success confirms local persistence, not delivery to the server.

5. Optionally adopt the async APIs:

   ```swift
   let savedConsents = try await mobileConsentsSDK.loadSavedConsents()
   let selectedConsents = try await mobileConsentsSDK.showPrivacyPopUp()
   try await mobileConsentsSDK.postConsent(consent)
   ```

6. Test saving consent while offline, relaunching the app, and calling `synchronizeIfNeeded()` after connectivity returns.
