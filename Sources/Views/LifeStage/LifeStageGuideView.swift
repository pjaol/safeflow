import SwiftUI

// MARK: - LifeStageGuideView

/// Full-screen sheet for selecting a life stage.
///
/// Three parts:
///   1. Scrollable stage picker cards with plain-language descriptions
///   2. Per-transition confirmation sheet listing what changes
///   3. First-run home card shown after switching (see LifeStageFirstRunCard)
///
/// Used from:
///   - Settings → "Your Experience → Life Stage" (shows confirmation sheet on change)
///   - Onboarding page 1 (picker only — no confirmation sheet, no existing stage to diff)
struct LifeStageGuideView: View {
    /// The currently active life stage — read and written via AppStorage at the call site.
    @Binding var currentStage: LifeStage

    /// When `true`, the confirmation sheet is suppressed (onboarding path).
    var skipConfirmation: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pendingStage: LifeStage? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    headerText

                    ForEach(LifeStage.allCases, id: \.self) { stage in
                        StageCard(
                            stage: stage,
                            isSelected: currentStage == stage
                        ) {
                            handleSelection(stage)
                        }
                    }

                    contextNote
                        .padding(.top, 4)
                }
                .padding(.horizontal, AppTheme.Metrics.cardPadding)
                .padding(.vertical, AppTheme.Metrics.standardSpacing)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Life Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                        .accessibilityIdentifier("lifeStageGuide.doneButton")
                }
            }
            // Push confirmation into the same NavigationStack — avoids sheet-in-sheet
            .navigationDestination(item: $pendingStage) { pending in
                LifeStageConfirmationSheet(
                    from: currentStage,
                    to: pending
                ) {
                    applyStage(pending)
                    pendingStage = nil
                    dismiss()
                } onCancel: {
                    pendingStage = nil
                }
            }
        }
    }

    // MARK: - Private

    private var headerText: some View {
        Text("Choose what fits where you are right now. You can change this anytime.")
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(AppTheme.Colors.mediumGrayText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("lifeStageGuide.headerText")
    }

    private var contextNote: some View {
        Text("This changes what Clio Daye shows you. Your stored data is never affected.")
            .font(.system(.caption, design: .rounded))
            .foregroundColor(AppTheme.Colors.mediumGrayText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .accessibilityIdentifier("lifeStageGuide.contextNote")
    }

    private func handleSelection(_ stage: LifeStage) {
        guard stage != currentStage else { return }
        if skipConfirmation {
            applyStage(stage)
        } else {
            pendingStage = stage
        }
    }

    private func applyStage(_ stage: LifeStage) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            currentStage = stage
        }
        // Record that a first-run card should appear for this transition
        LifeStageFirstRunCard.markPending(for: stage)
    }
}

// MARK: - StageCard

private struct StageCard: View {
    let stage: LifeStage
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppTheme.Colors.accentBlue : AppTheme.Colors.mediumGrayText.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(AppTheme.Colors.accentBlue)
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.localizedName)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(stage.cardDescription)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }

                Spacer(minLength: 0)
            }
            .padding(AppTheme.Metrics.cardPadding)
            .background(
                isSelected
                    ? AppTheme.Colors.accentBlue.opacity(0.08)
                    : AppTheme.Colors.secondaryBackground
            )
            .cornerRadius(AppTheme.Metrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                    .strokeBorder(
                        isSelected ? AppTheme.Colors.accentBlue.opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: Color.black.opacity(isSelected ? 0.04 : 0.07),
                radius: isSelected ? 4 : 8,
                x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isSelected)
        // Accessibility: treat entire card as a single selectable element
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stage.localizedNameString). \(stage.cardDescriptionString)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select")
        .accessibilityIdentifier("lifeStageGuide.stageCard.\(stage.rawValue)")
        .frame(minHeight: 44)
    }
}

// MARK: - LifeStageConfirmationSheet

struct LifeStageConfirmationSheet: View {
    let from: LifeStage
    let to: LifeStage
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Metrics.standardSpacing) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Here's what changes:")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                }

                // Change list
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(changeItems(from: from, to: to), id: \.self) { item in
                        ChangeItem(text: item)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(changeListAccessibilityLabel(from: from, to: to))
                .accessibilityIdentifier("lifeStageConfirmation.changeList")

                // Closing note
                Text(closingNote(to: to))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .padding(.top, 4)

                // Buttons
                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text("Switch to \(to.localizedNameString)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.Colors.accentBlue)
                            .cornerRadius(AppTheme.Metrics.buttonCornerRadius)
                    }
                    .accessibilityLabel("Confirm switch to \(to.localizedNameString)")
                    .accessibilityIdentifier("lifeStageConfirmation.confirmButton")

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .accessibilityIdentifier("lifeStageConfirmation.cancelButton")
                }
                .padding(.top, 8)
            }
            .padding(AppTheme.Metrics.cardPadding)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle(to.localizedName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Change copy

    private func changeItems(from: LifeStage, to: LifeStage) -> [String] {
        switch to {
        case .perimenopause:
            return [
                "Predictions → your bleed history (more honest when cycles vary)",
                "Your phase card is removed (phase framing doesn't apply when cycles are irregular)",
                "New symptom categories: hot flashes, night sweats, brain fog, joint pain",
                "If your cycles briefly settle, you'll see a note — but it won't drive predictions",
                "Your logged data stays exactly as it is"
            ]
        case .menopause:
            return [
                "Cycle tracking and predictions are removed from your home screen",
                "Your home screen shows how you've been feeling this week",
                "Your calendar switches to a symptom view (logged bleeds are still there)",
                "The flow tracker stays, labelled differently — tap it if you notice any bleeding",
                "\"Your Month\" summarises your patterns in plain language each month",
                "If you log any bleeding, the app will prompt you to mention it to your doctor",
                "Your logged data stays exactly as it is"
            ]
        case .paused:
            return [
                "Period tracking and predictions are paused",
                "Your calendar is hidden while tracking is paused",
                "The app logs mood, energy, and how you're feeling each day",
                "The flow tracker is still available if you need it",
                "Your logged data stays exactly as it is"
            ]
        case .regular:
            return [
                "Cycle tracking and predictions are turned back on",
                "The app will use any bleed data you've logged to start rebuilding your cycle picture",
                "Hot flash and joint pain categories stay available in your log"
            ]
        case .irregular:
            return [
                "Predictions switch to a wider window to reflect that your cycle varies",
                "The app tracks patterns over time rather than a fixed schedule",
                "Your logged data stays exactly as it is"
            ]
        }
    }

    private func changeListAccessibilityLabel(from: LifeStage, to: LifeStage) -> String {
        "Changes when switching to \(to.localizedNameString): " +
        changeItems(from: from, to: to).joined(separator: ". ")
    }

    private func closingNote(to: LifeStage) -> String {
        switch to {
        case .paused:
            return "Resume cycle tracking anytime from here or from Settings."
        default:
            return "You can switch back anytime."
        }
    }
}

// MARK: - ChangeItem

private struct ChangeItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.accentBlue)
                .padding(.top, 2)
                .accessibilityHidden(true)
            // Split on em-dash parenthetical into body + footnote
            if let parenRange = text.range(of: "("),
               text.hasSuffix(")") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text[text.startIndex..<parenRange.lowerBound].trimmingCharacters(in: .whitespaces))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(text[parenRange.lowerBound...]).trimmingCharacters(in: .whitespaces))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 44, alignment: .top)
    }
}

// MARK: - LifeStageFirstRunCard

/// Displays a one-time dismissible card at the top of the home scroll after a life stage change.
/// Dismissed with a single tap. State is stored in UserDefaults.
struct LifeStageFirstRunCard: View {
    let stage: LifeStage

    @State private var isDismissed: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let defaultsKeyPrefix = "lifeStageFirstRunDismissed_"

    static func markPending(for stage: LifeStage) {
        UserDefaults.standard.set(false, forKey: defaultsKeyPrefix + stage.rawValue)
    }

    static func isPending(for stage: LifeStage) -> Bool {
        // Returns true if the key is absent (never shown) OR explicitly set to false
        let key = defaultsKeyPrefix + stage.rawValue
        return !UserDefaults.standard.bool(forKey: key + "_shown")
    }

    var body: some View {
        if !isDismissed {
            Button(action: dismiss) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                        .padding(.top, 1)
                        .accessibilityHidden(true)

                    Text(cardText(for: stage))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppTheme.Colors.deepGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .accessibilityHidden(true)
                }
                .padding(AppTheme.Metrics.cardPadding)
                .background(AppTheme.Colors.accentBlue.opacity(0.07))
                .cornerRadius(AppTheme.Metrics.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                        .strokeBorder(AppTheme.Colors.accentBlue.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            .accessibilityLabel(cardText(for: stage))
            .accessibilityHint("Tap to dismiss")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("lifeStageFirstRunCard.\(stage.rawValue)")
        }
    }

    private func dismiss() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            isDismissed = true
        }
        let key = Self.defaultsKeyPrefix + stage.rawValue + "_shown"
        UserDefaults.standard.set(true, forKey: key)
    }

    private func cardText(for stage: LifeStage) -> String {
        switch stage {
        case .perimenopause:
            return "Predictions are gone — because they'd be wrong. Your bleed history is your reference now. Hot flashes and joint pain are in your log."
        case .menopause:
            return "Cycle tracking is off. Your home screen shows how you've been feeling. Log symptoms as normal — your data is still here."
        case .paused:
            return "Cycle tracking paused. Just log how you feel. Switch back anytime in Settings."
        case .regular:
            return "Cycle tracking is back on. Log a period when it arrives and predictions will start again."
        case .irregular:
            return "Switched to irregular mode. Predictions now show a wider window to reflect your cycle's variability."
        }
    }
}

// MARK: - LifeStage extensions for LifeStageGuideView

extension LifeStage {
    /// Plain string version of `cardDescription` for accessibility labels.
    var cardDescriptionString: String {
        switch self {
        case .regular:
            return "Periods come roughly on schedule. The app predicts your next period and tracks where you are in your cycle each day."
        case .irregular:
            return "Your cycle varies and predictions aren't always reliable. The app shows a wider range and tracks patterns over time."
        case .perimenopause:
            return "Your cycles are shifting. We track what's actually happened instead of guessing what's next, and add hot flashes, brain fog, and joint pain to your tracker."
        case .menopause:
            return "Periods have stopped. The app focuses on how you feel each day and what patterns emerge over time."
        case .paused:
            return "Post-partum, breastfeeding, or taking a break. The app skips period tracking and logs how you feel. Switch back anytime."
        }
    }
}
