# Custom consent screen (example)

A fully custom cookie consent screen built on the **MobileConsentsSDK**. All reusable
code lives in this folder — the SDK keeps handling networking, caching, offline retry
and consent storage; these files provide only the UI.

The design:

- an intro above the categories with links to the Privacy Policy and the Cookie Policy,
- a scrolling category list with the action buttons fixed at the bottom of the screen,
- categories separated by 32pt of vertical spacing instead of divider lines,
- brand blue (`#093A5C`) for the primary button and selected toggles,
- dark mode limited to black, white and grey tones (accent stays brand blue).

The screen comes in three variants rendering the same design — pick the one that
matches your app's UI stack. Every variant also needs the three shared files
`ConsentColors.swift` (palette), `ConsentConfiguration.swift` (text and settings) and
`PolicyViewController.swift` (the screen the policy links open):

| Variant | Files to copy (plus the shared three) | Minimum iOS |
|---|---|---|
| **UIKit** | `CustomConsentViewController.swift` | 12 |
| **SwiftUI** | `SwiftUI/CustomConsentView.swift` + `SwiftUI/CustomConsentSwiftUIController.swift` + `PolicyWebView.swift` | 15 |
| **Standalone SwiftUI** | `Standalone/StandaloneConsentView.swift` + `Standalone/ConsentStore.swift` + `PolicyWebView.swift` | 15 |

The UIKit and SwiftUI variants plug into the SDK's `customViewType` hook — the SDK
presents and dismisses the screen and reports the result through its completion
closures (the SwiftUI variant is hosted in a thin `UIViewController` wrapper for that
purpose). Use one of these unless you have a hard requirement to avoid UIKit.

The **standalone** variant involves no UIKit at all: it talks to the SDK's low-level
API (`fetchConsentSolution` / `postConsent`) and your app presents it itself, e.g.
with `.fullScreenCover`. The trade-off: the SDK does not expose the stored solution
version, so this variant cannot fully replicate `showPrivacyPopUpIfNeeded` — it can
only check whether any consents are saved (`store.hasSavedConsents`), and it will not
re-prompt users after the solution changes in the dashboard. Usage example is in the
`StandaloneConsentView` documentation comment.

## Setup

1. Add the MobileConsentsSDK to your app (Swift Package Manager or CocoaPods, see the
   main [README](../../README.md)).
2. Copy the files of your chosen variant (see table above) into your project.
3. Pass the class to the SDK when showing the popup:

   ```swift
   let mobileConsents = MobileConsents(
       clientID: "YOUR_CLIENT_ID",
       clientSecret: "YOUR_CLIENT_SECRET",
       solutionId: "YOUR_SOLUTION_ID"
   )

   // Always show the screen (SwiftUI: pass CustomConsentSwiftUIController.self instead):
   mobileConsents.showPrivacyPopUp(customViewType: CustomConsentViewController.self) { consents in
       consents.forEach { print("\($0.purpose): \($0.isSelected)") }
   } errorHandler: { error in
       print(error.localizedDescription)
   }

   // Or show it only when the user has not responded to the latest solution:
   mobileConsents.showPrivacyPopUpIfNeeded(customViewType: CustomConsentViewController.self) { consents in
       // called with the saved consents whether or not the screen was shown
   }
   ```

The completion closure receives the user's saved consents once the screen closes.
`MobileConsents.removeStoredConsents()` clears locally stored consent data.

## Screenshots

| Light | Dark |
|---|---|
| <img src="screenshots/light.png" width="240"> | <img src="screenshots/dark.png" width="240"> |

## Consent screen buttons

| Button | What it does |
|---|---|
| **Only Necessary** (secondary) | Accepts the required categories and rejects every optional one, whatever the toggles show. |
| **Accept All** (primary, default) | Accepts every category. |
| **Save Choices** (primary, after a change) | Once the user enables an optional category the primary button becomes "Save Choices" and saves exactly what the user toggled. |

Optional categories always start off, so a returning user is not shown their previous
selection as the default. This affects the toggles only — previously given consents stay
saved and are still returned by `getSavedConsents()`. Nothing is silently revoked either:
with every optional category off the primary button reads "Accept All", so rejecting them
all takes a deliberate tap on "Only Necessary".

Required categories (for example *Necessary*) are shown on, greyed out and cannot be
turned off.

## Category order

Categories are shown in the order Necessary, Functional, Statistical, Marketing, then
anything else as the dashboard returns it.

The two variants presented through the `customViewType` hook only receive the category
*titles* from the SDK, so they match the keywords in
`ConsentConfiguration.categoryOrderKeywords` case-insensitively against the title —
**adjust that list to your own dashboard category names** (for example `"advertising"`
instead of `"marketing"`). The standalone variant has the category type available and
orders by it directly, ignoring the list.

## Privacy and Cookie policy links

The intro above the categories shows two links, each opening in an in-app web view.

**Privacy Policy** content comes from the dashboard, the same as the SDK's built-in UI:
whatever is configured there is what opens — a URL loads that page, text or HTML is
rendered as is.

**Cookie Policy** has no entry in the dashboard, so its URL is set in
`ConsentConfiguration.cookiePolicyURL`. A link whose content is missing is shown as
plain, non-tappable text.

Both links open `PolicyViewController`, a plain web view styled with `ConsentColors`.
The SDK's built-in `PrivacyPolicyDetail` is public and can be used instead if you would
rather carry one file less — see the note at the top of `PolicyViewController.swift` for
the differences.

## Where to change things

| Change | Where |
|---|---|
| Screen text (title, intro, button labels) | `ConsentConfiguration.swift` |
| Cookie Policy URL, category order | `ConsentConfiguration.swift` |
| Brand color, light and dark palette | `ConsentColors.swift` |
| Spacing, corner radius, button height | `Layout` enum in `CustomConsentViewController.swift`; inline modifiers in the SwiftUI views |
| Screen layout | The variant's view file |

## Trying it in the example app

Run the `Example` scheme, tap the button in the top bar and pick **Brand custom UI**
(UIKit), **Brand custom UI (SwiftUI)** or **Brand custom UI (pure SwiftUI)** — the
first two present the screen through `showPrivacyPopUp(customViewType:)`, the third
through the standalone store. Switch the simulator to dark mode (⇧⌘A) to preview the
dark palette.
