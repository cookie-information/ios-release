import SwiftUI
import MobileConsentsSDK

/// SwiftUI twin of `CustomConsentViewController` — the same design, rendered with SwiftUI.
/// Present it through `CustomConsentSwiftUIController`, which adapts it to the SDK's
/// `customViewType` hook. Text lives in ConsentConfiguration.swift, colors in
/// ConsentColors.swift, both shared with the other variants.
@available(iOS 15.0, *)
public struct CustomConsentView: View {

    @ObservedObject var state: ConsentScreenState
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

                            PolicyIntroText(privacyPolicy: state.privacyPolicy) { content in
                                policy = PolicyContent(content: content)
                            }
                        }

                        ForEach(state.categories) { category in
                            categoryRow(category)
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
                    Button(action: state.onOnlyNecessary) {
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
                    Button(action: state.hasOptionalSelection ? state.onSaveChoices : state.onAcceptAll) {
                        Text(state.hasOptionalSelection
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

            if state.isLoading {
                background.ignoresSafeArea()
                ProgressView()
                    .tint(accent)
                    .scaleEffect(1.5)
            }
        }
        .fullScreenCover(item: $policy) { policy in
            PolicyWebView(content: policy.content).ignoresSafeArea()
        }
    }

    private func categoryRow(_ category: ConsentScreenState.Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(category.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(titleColor)
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { category.isOn },
                    set: { state.setSelected($0, for: category.id) }
                ))
                .labelsHidden()
                // Required categories are locked on: greyed out and not toggleable.
                .tint(category.isRequired ? trackOff : accent)
                .disabled(category.isRequired)
            }
            Text(category.description)
                .font(.system(size: 15))
                .foregroundColor(descriptionColor)
        }
    }
}
