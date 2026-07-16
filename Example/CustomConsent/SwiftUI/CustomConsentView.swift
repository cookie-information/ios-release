import SwiftUI
import MobileConsentsSDK

/// SwiftUI twin of `CustomConsentViewController` — the same design, rendered with SwiftUI.
/// Present it through `CustomConsentSwiftUIController`, which adapts it to the SDK's
/// `customViewType` hook. Colors come from ConsentColors.swift, shared with the UIKit version.
@available(iOS 15.0, *)
public struct CustomConsentView: View {

    private enum Strings {
        // Hardcoded to match the design. Replace with the values from
        // `PrivacyPopUpData` in ConsentScreenState.load(sections:) to use the
        // texts configured in the dashboard instead.
        static let title = "Cookie settings"
        static let onlyNecessary = "Only Necessary"
        static let saveChoices = "Save choices"
    }

    @ObservedObject var state: ConsentScreenState

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

                // Action buttons pinned to the bottom of the screen.
                HStack(spacing: 12) {
                    Button(action: state.onOnlyNecessary) {
                        Text(Strings.onlyNecessary)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(secondary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(secondary, lineWidth: 1)
                            )
                    }

                    Button(action: state.onSaveChoices) {
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

            if state.isLoading {
                background.ignoresSafeArea()
                ProgressView()
                    .tint(accent)
                    .scaleEffect(1.5)
            }
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
