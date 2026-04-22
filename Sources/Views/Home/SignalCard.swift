import SwiftUI

// MARK: - SignalCardFormatter
//
// Pure function. Takes a SignalResult and produces display-ready strings.
// No view dependency — fully testable.

struct SignalCardFormatter {

    struct Output {
        let headline: String
        let pills: [TrendPill]
        let monthCharacter: MonthCharacter
    }

    struct TrendPill: Identifiable {
        let id = UUID()
        let label: String
        let trend: PillTrend

        enum PillTrend {
            case worse, better, neutral
        }
    }

    static func format(_ result: SignalResult) -> Output {
        let headline = buildHeadline(result)
        let pills = buildPills(result)
        return Output(headline: headline, pills: pills, monthCharacter: result.monthCharacter)
    }

    // MARK: - Headline

    private static func buildHeadline(_ result: SignalResult) -> String {
        let dominant = result.dominantSymptoms.first(where: { $0.trend != .resolved })

        // If we have a dominant active symptom, lead with it
        if let sym = dominant {
            return headlineForSymptom(sym, monthCharacter: result.monthCharacter, hasBaseline: result.hasBaseline)
        }

        // Fall back to month character
        return headlineForMonthCharacter(result.monthCharacter)
    }

    private static func headlineForSymptom(
        _ signal: SymptomSignal,
        monthCharacter: MonthCharacter,
        hasBaseline: Bool
    ) -> String {
        let name = signal.symptom.displayName
        let n = signal.thisMonth

        if !hasBaseline {
            return "\(name) on \(n) \(n == 1 ? "day" : "days") this month."
        }

        switch signal.trend {
        case .escalating:
            let base = Int(signal.baselineAvg.rounded())
            return "\(name) on \(n) \(n == 1 ? "day" : "days") — up from about \(base) a month."
        case .improving:
            let base = Int(signal.baselineAvg.rounded())
            return "\(name) on \(n) \(n == 1 ? "day" : "days") — down from about \(base) a month."
        case .new:
            return "\(name) appeared this month for the first time."
        case .resolved:
            return "\(name) was absent this month."
        case .stable:
            return "\(name) on \(n) \(n == 1 ? "day" : "days") — similar to recent months."
        case .unknown:
            return "\(name) on \(n) \(n == 1 ? "day" : "days") this month."
        }
    }

    private static func headlineForMonthCharacter(_ character: MonthCharacter) -> String {
        switch character {
        case .notableImprovement: return "A noticeably easier month than your recent baseline."
        case .slightImprovement:  return "A slightly easier month than your recent baseline."
        case .similar:            return "A month similar to your recent baseline."
        case .slightlyHarder:     return "A slightly harder month than your recent baseline."
        case .notablyHarder:      return "A harder month than your recent baseline."
        case .noComparison:       return "Keep logging to see patterns over time."
        }
    }

    // MARK: - Pills
    //
    // Up to 2 pills: top symptom trends (if noteworthy).
    // Stable trends produce no pill — stable is the baseline, not news.

    private static func buildPills(_ result: SignalResult) -> [TrendPill] {
        var pills: [TrendPill] = []

        // Symptom pill — first active symptom with a notable trend
        if let sym = result.dominantSymptoms.first(where: { notable($0.trend) }) {
            if let pill = symptomPill(sym) { pills.append(pill) }
        }

        return Array(pills.prefix(2))
    }

    private static func notable(_ trend: SymptomTrend) -> Bool {
        switch trend {
        case .escalating, .improving, .new: return true
        default: return false
        }
    }

    private static func symptomPill(_ signal: SymptomSignal) -> TrendPill? {
        let name = signal.symptom.displayName
        switch signal.trend {
        case .escalating:
            return TrendPill(label: "↑ \(name) more often", trend: .worse)
        case .improving:
            return TrendPill(label: "↓ \(name) less often", trend: .better)
        case .new:
            return TrendPill(label: "New: \(name)", trend: .neutral)
        default:
            return nil
        }
    }

}

// MARK: - Symptom display name

private extension Symptom {
    var displayName: String {
        switch self {
        case .hotFlashes:        return "Hot flashes"
        case .nightSweats:       return "Night sweats"
        case .cramps:            return "Cramps"
        case .bloating:          return "Bloating"
        case .breastTenderness:  return "Breast tenderness"
        case .headache:          return "Headaches"
        case .backPain:          return "Back pain"
        case .fatigue:           return "Fatigue"
        case .insomnia:          return "Insomnia"
        case .nausea:            return "Nausea"
        case .acne:              return "Acne"
        case .foodCravings:      return "Food cravings"
        case .jointPain:         return "Joint pain"
        case .muscleAches:       return "Muscle aches"
        case .exerciseRecovery:  return "Exercise recovery"
        case .brainFog:          return "Brain fog"
        case .mittelschmerz:     return "Ovulation pain"
        case .chills:            return "Chills"
        case .vaginalDryness:    return "Vaginal dryness"
        case .urinaryUrgency:    return "Urinary urgency"
        case .painWithSex:       return "Pain with sex"
        case .appetiteChanges:   return "Appetite changes"
        case .dischargeChanges:  return "Discharge changes"
        case .highEnergy:        return "High energy"
        }
    }
}

// MARK: - SignalCard View

struct SignalCard: View {
    let readiness: SignalReadiness
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch readiness {
        case .learning(let daysLogged):
            LearningStateCard(daysLogged: daysLogged)
        case .ready(let result):
            ReadyStateCard(result: result)
        }
    }
}

// MARK: - Ready state

private struct ReadyStateCard: View {
    let result: SignalResult
    private var output: SignalCardFormatter.Output { SignalCardFormatter.format(result) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 6) {
                if output.monthCharacter != .noComparison {
                    Circle()
                        .fill(dotColor(output.monthCharacter))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
                Text("This month")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }

            // Primary sentence
            Text(output.headline)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.Colors.deepGrayText)
                .fixedSize(horizontal: false, vertical: true)

            // Trend pills
            if !output.pills.isEmpty {
                HStack(spacing: 8) {
                    ForEach(output.pills) { pill in
                        TrendPillView(pill: pill)
                    }
                    Spacer()
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("home.signalCard")
    }

    private var accessibilityLabel: String {
        var parts = ["This month. \(output.headline)"]
        for pill in output.pills { parts.append(pill.label) }
        return parts.joined(separator: ". ")
    }

    private func dotColor(_ character: MonthCharacter) -> Color {
        switch character {
        case .notablyHarder:     return AppTheme.Colors.secondaryPink
        case .slightlyHarder:    return AppTheme.Colors.secondaryPink.opacity(0.6)
        case .similar:           return AppTheme.Colors.mediumGrayText.opacity(0.4)
        case .slightImprovement: return AppTheme.Colors.accentBlue.opacity(0.6)
        case .notableImprovement:return AppTheme.Colors.accentBlue
        case .noComparison:      return .clear
        }
    }
}

// MARK: - Trend pill view

private struct TrendPillView: View {
    let pill: SignalCardFormatter.TrendPill

    private var pillColor: Color {
        switch pill.trend {
        case .worse:   return AppTheme.Colors.secondaryPink.opacity(0.25)
        case .better:  return AppTheme.Colors.accentBlue.opacity(0.2)
        case .neutral: return AppTheme.Colors.mediumGrayText.opacity(0.15)
        }
    }

    private var textColor: Color {
        switch pill.trend {
        case .worse:   return AppTheme.Colors.dartPain
        case .better:  return AppTheme.Colors.accentBlue
        case .neutral: return AppTheme.Colors.mediumGrayText
        }
    }

    var body: some View {
        Text(pill.label)
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillColor)
            .clipShape(Capsule())
            .accessibilityHidden(true) // folded into card label
    }
}

// MARK: - Learning state

private struct LearningStateCard: View {
    let daysLogged: Int
    private let target = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Building your picture")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.deepGrayText)

            Text("Keep logging. After \(target) days Signal will show you what's been happening.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppTheme.Colors.mediumGrayText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Colors.mediumGrayText.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(AppTheme.Colors.accentBlue)
                            .frame(width: geo.size.width * min(CGFloat(daysLogged) / CGFloat(target), 1.0), height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(daysLogged) of \(target) days")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.mediumGrayText)
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Building your picture. \(daysLogged) of \(target) days logged.")
        .accessibilityIdentifier("home.signalCard.learning")
    }
}

// MARK: - Preview

#Preview("Ready — escalating") {
    let result = SignalResult(
        stage: .earlyPerimenopause,
        monthCharacter: .notablyHarder,
        dominantSymptoms: [
            SymptomSignal(symptom: .hotFlashes, thisMonth: 18, baselineAvg: 8, trend: .escalating),
            SymptomSignal(symptom: .nightSweats, thisMonth: 10, baselineAvg: 4, trend: .escalating)
        ],
        hasBaseline: true
    )
    return SignalCard(readiness: .ready(result))
        .padding()
        .background(AppTheme.Colors.background)
}

#Preview("Ready — improving") {
    let result = SignalResult(
        stage: .menopause,
        monthCharacter: .notableImprovement,
        dominantSymptoms: [
            SymptomSignal(symptom: .hotFlashes, thisMonth: 8, baselineAvg: 16, trend: .improving)
        ],
        hasBaseline: true
    )
    return SignalCard(readiness: .ready(result))
        .padding()
        .background(AppTheme.Colors.background)
}

#Preview("Ready — no baseline") {
    let result = SignalResult(
        stage: .earlyPerimenopause,
        monthCharacter: .noComparison,
        dominantSymptoms: [
            SymptomSignal(symptom: .hotFlashes, thisMonth: 9, baselineAvg: 0, trend: .unknown)
        ],
        hasBaseline: false
    )
    return SignalCard(readiness: .ready(result))
        .padding()
        .background(AppTheme.Colors.background)
}

#Preview("Learning") {
    SignalCard(readiness: .learning(daysLogged: 3))
        .padding()
        .background(AppTheme.Colors.background)
}
