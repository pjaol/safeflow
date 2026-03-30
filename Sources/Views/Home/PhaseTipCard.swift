import SwiftUI

/// Shows a rotating contextual tip for the current cycle phase.
///
/// Tips are static, non-medical, and chosen to be useful without being alarming.
/// The displayed tip rotates daily (keyed by day-of-year) so it feels fresh
/// without requiring any state or network calls.
struct PhaseTipCard: View {
    let phase: CyclePhase

    private var tip: PhaseTip { PhaseTip.daily(for: phase) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(tip.emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.forPhase(phase.themeColorName).opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                Text(tip.body)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.forPhase(phase.themeColorName).opacity(0.1))
        .cornerRadius(AppTheme.Metrics.cornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.phaseTipCard")
        .accessibilityLabel("\(tip.title). \(tip.body)")
    }
}

// MARK: - PhaseTip

private struct PhaseTip {
    let emoji: String
    let title: String
    let body: String

    /// Picks a tip for today using day-of-year so it rotates daily without any stored state.
    static func daily(for phase: CyclePhase) -> PhaseTip {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let tips = all[phase] ?? []
        guard !tips.isEmpty else { return PhaseTip(emoji: "💡", title: "Tip", body: "") }
        return tips[dayOfYear % tips.count]
    }

    // MARK: - Tip Content

    static let all: [CyclePhase: [PhaseTip]] = [
        .menstrual: [
            PhaseTip(
                emoji: "🌡️",
                title: "Heat can help",
                body: "A warm compress or hot water bottle on your lower abdomen may ease cramp discomfort."
            ),
            PhaseTip(
                emoji: "💤",
                title: "Rest is productive",
                body: "Your body is doing real work this week. Lighter activity and extra sleep are a good call."
            ),
            PhaseTip(
                emoji: "🥗",
                title: "Iron-rich foods",
                body: "Leafy greens, lentils, and beans can help replenish iron lost during your period."
            ),
            PhaseTip(
                emoji: "💊",
                title: "Ibuprofen timing",
                body: "Anti-inflammatory pain relief (like ibuprofen) works best taken with food at the first sign of cramps, rather than waiting."
            ),
        ],
        .follicular: [
            PhaseTip(
                emoji: "🚀",
                title: "Energy is building",
                body: "Estrogen rises during this phase — many people find focus and motivation easier right now."
            ),
            PhaseTip(
                emoji: "🧠",
                title: "Good time for new things",
                body: "Starting a new project or learning something new tends to feel easier in the follicular phase."
            ),
            PhaseTip(
                emoji: "🏃",
                title: "Movement feels easier",
                body: "Higher estrogen supports muscle recovery, making this a good window for more intense workouts if that's your thing."
            ),
            PhaseTip(
                emoji: "🥦",
                title: "Support your gut",
                body: "Fermented foods like yogurt and kimchi support the gut microbiome, which influences hormone processing."
            ),
        ],
        .ovulatory: [
            PhaseTip(
                emoji: "☀️",
                title: "Peak energy window",
                body: "Many people feel most social and energised around ovulation. A good time for presentations or important conversations."
            ),
            PhaseTip(
                emoji: "🌡️",
                title: "Basal temperature rises",
                body: "A slight rise in basal body temperature after ovulation is normal — it confirms ovulation has occurred."
            ),
            PhaseTip(
                emoji: "💧",
                title: "Stay hydrated",
                body: "Hormonal shifts around ovulation can increase body temperature slightly. Extra water helps."
            ),
            PhaseTip(
                emoji: "🧘",
                title: "Notice your body",
                body: "Some people feel mild one-sided pelvic discomfort around ovulation (mittelschmerz). It's common and usually brief."
            ),
        ],
        .luteal: [
            PhaseTip(
                emoji: "🎵",
                title: "Mood may shift",
                body: "Progesterone rises then drops in the luteal phase. If your mood dips in the second half, that's a recognised pattern."
            ),
            PhaseTip(
                emoji: "🍫",
                title: "Magnesium may help",
                body: "Some research links magnesium intake to reduced PMS symptoms. Dark chocolate and nuts are decent sources."
            ),
            PhaseTip(
                emoji: "😴",
                title: "Sleep changes are normal",
                body: "Progesterone can affect sleep quality in the luteal phase. Cooler room temperature and consistent sleep times help."
            ),
            PhaseTip(
                emoji: "🧂",
                title: "Reduce salt if bloated",
                body: "Bloating is common in the late luteal phase. Reducing salty foods and increasing water can ease it."
            ),
        ],
    ]
}

#Preview {
    VStack(spacing: 12) {
        PhaseTipCard(phase: .menstrual)
        PhaseTipCard(phase: .follicular)
        PhaseTipCard(phase: .ovulatory)
        PhaseTipCard(phase: .luteal)
    }
    .padding()
    .background(AppTheme.Colors.background)
}
