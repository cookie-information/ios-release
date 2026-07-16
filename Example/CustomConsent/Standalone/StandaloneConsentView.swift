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
/// Colors come from ConsentColors.swift, shared with the other variants.
@available(iOS 15.0, *)
public struct StandaloneConsentView: View {

    private enum Strings {
        static let title = "Cookie settings"
        static let onlyNecessary = "Only Necessary"
        static let saveChoices = "Save choices"
    }

    @ObservedObject var store: ConsentStore

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

            VStack(spacing: 0) {
                ScrollView {
                    // 32pt of vertical spacing between categories instead of divider lines.
                    VStack(alignment: .leading, spacing: 32) {
                        Text(Strings.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(titleColor)

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

                // Action buttons pinned to the bottom of the screen.
                HStack(spacing: 12) {
                    Button(action: store.onlyNecessary) {
                        Text(Strings.onlyNecessary)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(secondary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(secondary, lineWidth: 1)
                            )
                    }

                    Button(action: store.saveChoices) {
                        Text(Strings.saveChoices)
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
