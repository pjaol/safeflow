import SwiftUI

/// Displays a single symptom or mood insight combining the user's personal pattern
/// with population context. Rotates daily so the home screen always feels fresh.
///
/// Three visual states:
///   - Personal pattern + population context (main case, 2+ cycles of data)
///   - Population context only (1 cycle, limited personal data)
///   - Severity signal (escalating or phase-inconsistent symptom)
struct InsightCard: View {
    let insight: SymptomInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: insight.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.forPhase(insight.phase.themeColorName))
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.forPhase(insight.phase.themeColorName).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.headlineText)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.deepGrayText)

                    Text(insight.phase.displayName + " phase")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
            }

            // Personal pattern sentence
            Text(insight.personalSentence)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(AppTheme.Colors.deepGrayText)
                .fixedSize(horizontal: false, vertical: true)

            // Population context bar + label
            populationBar

            // Clinical note if present
            if let note = insight.populationNorm.note {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                    Text(note)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.insightCard")
        .accessibilityLabel(insight.accessibilityDescription)
    }

    // MARK: - Population Bar

    private var populationBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("How common is this?")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                Spacer()
                Text(insight.populationNorm.percentageString)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.Colors.background)
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.Colors.forPhase(insight.phase.themeColorName).opacity(0.8))
                        .frame(
                            width: geo.size.width * insight.populationNorm.prevalenceFraction,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text(insight.populationNorm.solidarityLabel)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(AppTheme.Colors.mediumGrayText)
        }
    }
}

// MARK: - SeveritySignalCard

/// Separate card for severity signals — uses a more prominent amber style
/// to indicate "pay attention" without being alarming.
struct SeveritySignalCard: View {
    let signal: SeveritySignal
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.forecastMood)
                .frame(width: 32, height: 32)
                .background(AppTheme.Colors.forecastMood.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(signal.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                Text(signal.body)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .padding(6)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.forecastMood.opacity(0.12))
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.severitySignalCard.\(signal.id)")
    }
}

// MARK: - SymptomInsight display helpers

private extension SymptomInsight {

    var headlineText: String {
        switch kind {
        case .personalPattern:
            return symptom?.localizedName ?? "Symptom pattern"
        case .moodPattern(let valence):
            switch valence {
            case .positive: return "Positive mood pattern"
            case .negative: return "Low mood pattern"
            case .neutral:  return "Mood pattern"
            }
        }
    }

    var personalSentence: String {
        switch kind {
        case .personalPattern:
            guard let s = symptom else { return "" }
            let freq = Int(round(personalFrequency * 100))
            return "You log \(s.localizedName.lowercased()) on \(freq)% of your \(phase.dayLabel)s."
        case .moodPattern(let valence):
            let freq = Int(round(personalFrequency * 100))
            switch valence {
            case .positive:
                return "You tend to feel positive on \(freq)% of your \(phase.dayLabel)s."
            case .negative:
                return "You tend to feel low on \(freq)% of your \(phase.dayLabel)s."
            case .neutral:
                return "Your mood is often neutral during your \(phase.dayLabel)s."
            }
        }
    }

    var sfSymbol: String {
        switch kind {
        case .moodPattern(let valence):
            switch valence {
            case .positive: return "face.smiling"
            case .negative: return "face.dashed"
            case .neutral:  return "minus.circle"
            }
        case .personalPattern:
            return symptom?.sfSymbol ?? "waveform.path.ecg"
        }
    }

    var accessibilityDescription: String {
        "\(headlineText) during \(phase.displayName) phase. \(personalSentence) \(populationNorm.prevalenceLabel) overall, \(populationNorm.percentageString) of people."
    }
}

private extension PopulationNorm {
    /// 0–1 fraction for the bar fill, mapped from prevalence level.
    var prevalenceFraction: CGFloat {
        switch prevalence {
        case .veryCommon:   return 0.85
        case .common:       return 0.65
        case .fairlyCommon: return 0.40
        case .lessCommon:   return 0.20
        case .rare:         return 0.08
        }
    }

    /// Solidarity-framed label for the population bar.
    /// Low prevalence renders as "a recognised experience, though less common" to avoid
    /// implying the user's experience is unusual or not worth acting on (REQ-001 R3).
    var solidarityLabel: String {
        switch prevalence {
        case .veryCommon, .common:
            return prevalenceLabel.capitalized + " in people who track their cycles"
        case .fairlyCommon:
            return "A fairly common experience in people who track their cycles"
        case .lessCommon, .rare:
            return "A recognised experience, though less common"
        }
    }
}


// MARK: - Previews

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            InsightCard(insight: SymptomInsight(
                symptom: .cramps,
                phase: .menstrual,
                personalFrequency: 0.8,
                populationNorm: PopulationNorm.lookup(symptom: .cramps, phase: .menstrual),
                kind: .personalPattern
            ))
            InsightCard(insight: SymptomInsight(
                symptom: .fatigue,
                phase: .luteal,
                personalFrequency: 0.55,
                populationNorm: PopulationNorm.lookup(symptom: .fatigue, phase: .luteal),
                kind: .personalPattern
            ))
            InsightCard(insight: SymptomInsight(
                symptom: nil,
                phase: .luteal,
                personalFrequency: 0.7,
                populationNorm: PopulationNorm.moodNorm(phase: .luteal, valence: .negative),
                kind: .moodPattern(valence: .negative)
            ))
            SeveritySignalCard(
                signal: SeveritySignal(
                    id: "severity.crampsEscalating",
                    symptom: .cramps,
                    title: "Your cramp days are increasing",
                    body: "Period pain that gets worse cycle over cycle is worth mentioning to a doctor. It can have treatable causes.",
                    priority: .high
                ),
                onDismiss: {}
            )
        }
        .padding()
    }
    .background(AppTheme.Colors.background)
}
