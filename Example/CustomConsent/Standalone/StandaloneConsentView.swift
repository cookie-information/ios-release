import SwiftUI
import MobileConsentsSDK

/// Standalone (pure SwiftUI) variant of the custom consent screen — the same design
/// as the other variants, but with no UIKit involved. The app presents it itself and
/// closes it in the store's callbacks:
///
///     @StateObject private var store = ConsentStore(mobileConsents: mobileConsents)
///     @State private var showConsent = false
///
///     var body: some View {
///         content
///             .fullScreenCover(isPresented: $showConsent) {
///                 StandaloneConsentView(store: store)
///             }
///             .onAppear {
///                 store.onFinished = { consents in showConsent = false }
///                 store.onError = { error in showConsent = false }
///                 if !store.hasSavedConsents { showConsent = true }
///             }
///     }
///
/// Text lives in ConsentConfiguration.swift, colors in ConsentColors.swift, both shared with
/// the other variants.
@available(iOS 15.0, *)
public struct StandaloneConsentView: View {

    @ObservedObject var store: ConsentStore
    @State private var policy: PolicyContent?

    private let background = Color(uiColor: ConsentColors.background)
    private let titleColor = Color(uiColor: ConsentColors.title)
    private let descriptionColor = Color(uiColor: ConsentColors.categoryDescription)
    private let accent = Color(uiColor: ConsentColors.accent)
    private let onAccent = Color(uiColor: ConsentColors.onAccent)
    private let secondary = Color(uiColor: ConsentColors.secondary)
    private let trackOff = Color(uiColor: ConsentColors.trackOff)
    private let divider = Color(uiColor: ConsentColors.divider)

    public var body: some View {
        ZStack {
            background.ignoresSafeArea()

            // The category list scrolls; the action buttons stay fixed at the bottom.
            VStack(spacing: 0) {
                ScrollView {
                    // 32pt of vertical spacing between categories instead of divider lines.
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(ConsentConfiguration.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(titleColor)

                            PolicyIntroText(privacyPolicy: store.privacyPolicy) { content in
                                policy = PolicyContent(content: content)
                            }
                        }

                        ForEach($store.categories) { $category in
                            categoryRow($category)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }

                Rectangle()
                    .fill(divider)
                    .frame(height: 1)

                HStack(spacing: 12) {
                    // Accepts the required categories, rejects every optional one.
                    Button(action: store.onlyNecessary) {
                        Text(ConsentConfiguration.onlyNecessaryButton)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(secondary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(secondary, lineWidth: 1)
                            )
                    }

                    // "Accept All" until the user enables an optional category, then "Save Choices".
                    Button(action: store.hasOptionalSelection ? store.saveChoices : store.acceptAll) {
                        Text(store.hasOptionalSelection
                             ? ConsentConfiguration.saveChoicesButton
                             : ConsentConfiguration.acceptAllButton)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(onAccent)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }

            if store.isLoading {
                background.ignoresSafeArea()
                ProgressView()
                    .tint(accent)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            if store.categories.isEmpty {
                store.load()
            }
        }
        .fullScreenCover(item: $policy) { policy in
            PolicyWebView(content: policy.content).ignoresSafeArea()
        }
    }

    private func categoryRow(_ category: Binding<ConsentStore.Category>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(category.wrappedValue.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(titleColor)
                Spacer(minLength: 8)
                Toggle("", isOn: category.isOn)
                    .labelsHidden()
                    // Required categories are locked on: greyed out and not toggleable.
                    .tint(category.wrappedValue.isRequired ? trackOff : accent)
                    .disabled(category.wrappedValue.isRequired)
            }
            Text(category.wrappedValue.description)
                .font(.system(size: 15))
                .foregroundColor(descriptionColor)
        }
    }
}
