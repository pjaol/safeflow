import SwiftUI

// MARK: - CycleRingSummaryCard

/// Replaces CyclePhaseCard + InsightCard + PhaseTipCard + PatternNudgeCard + SeveritySignalCard.
///
/// Home screen shows a single compact card:
///   - Cycle arc ring that fills proportionally through the cycle, coloured by phase
///   - Phase name + day number
///   - Badge dots for pending insights, tips, and alerts
///   - Tap → CycleDetailSheet with tabbed carousel of all content
struct CycleRingSummaryCard: View {
    let cycleStore: CycleStore
    let phase: CyclePhase?
    let cycleDay: Int?
    let predictionRange: (earliest: Date, latest: Date)?
    let averageCycleLength: Int?
    let activeSignals: [SeveritySignal]
    let activeNudge: CycleNudge?
    let onDismissSignal: (String) -> Void
    let onDismissNudge: () -> Void

    @State private var showingDetail = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var phaseColor: Color {
        guard let phase else { return AppTheme.Colors.ringFollicular }
        return AppTheme.Colors.ringColor(for: phase.themeColorName)
    }

    /// 0–1 progress through the current cycle.
    /// Returns 1.0 when overdue (has data but no current day number), 0 when no data at all.
    private var cycleProgress: Double {
        if let day = cycleDay, let length = averageCycleLength, length > 0 {
            return min(1.0, Double(day) / Double(length))
        }
        // Overdue: has cycle history but day is nil
        if averageCycleLength != nil { return 1.0 }
        return 0
    }

    private var alertCount: Int { activeSignals.count + (activeNudge != nil ? 1 : 0) }

    private var insightCount: Int {
        cycleStore.todayInsight() != nil ? 1 : 0
    }

    private var tipCount: Int {
        guard phase != nil else { return 0 }
        return ContentEvaluator(store: cycleStore).dailyTip() != nil ? 1 : 0
    }

    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 20) {
                // Ring
                ZStack {
                    ringTrack
                    ringFill
                    ringCenter
                }
                .frame(width: 88, height: 88)

                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    // Phase + day
                    if let phase {
                        Text(phase.displayName)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                        if let day = cycleDay {
                            Text("Day \(day)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                        }
                        Text(phase.phaseDescription)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    } else if averageCycleLength != nil {
                        // Has data but cycle is overdue — phase is indeterminate
                        Text("Cycle overdue")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                        Text("Your cycle is running longer than usual.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    } else {
                        Text("Start tracking")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                        Text("Log your first period to see your cycle phase.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }

                    // Badge row
                    badgeRow
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.mediumGrayText.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(AppTheme.Metrics.cardPadding)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.Metrics.cornerRadius)
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to see insights, tips, and alerts")
        .accessibilityIdentifier("home.cycleRingSummaryCard")
        .sheet(isPresented: $showingDetail) {
            CycleDetailSheet(
                cycleStore: cycleStore,
                phase: phase,
                cycleDay: cycleDay,
                predictionRange: predictionRange,
                averageCycleLength: averageCycleLength,
                activeSignals: activeSignals,
                activeNudge: activeNudge,
                onDismissSignal: onDismissSignal,
                onDismissNudge: onDismissNudge
            )
        }
    }

    // MARK: - Ring

    private var ringTrack: some View {
        Circle()
            .stroke(phaseColor.opacity(0.15), lineWidth: 9)
    }

    private var ringFill: some View {
        Circle()
            .trim(from: 0, to: cycleProgress)
            .stroke(
                phaseColor,
                style: StrokeStyle(lineWidth: 9, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: cycleProgress)
    }

    private var totalItemCount: Int { alertCount + insightCount + tipCount }

    private var ringCenter: some View {
        ZStack {
            if totalItemCount > 0 {
                Text("\(totalItemCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(phaseColor)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Badge Row

    private var badgeRow: some View {
        HStack(spacing: 8) {
            if alertCount > 0 {
                alertBadge(count: alertCount, color: AppTheme.Colors.amber)
            }
            if insightCount > 0 {
                badge(label: "1 insight", color: phaseColor)
            }
            if tipCount > 0 {
                badge(label: "1 tip", color: AppTheme.Colors.accentBlue.opacity(0.8))
            }
            if alertCount == 0 && insightCount == 0 && tipCount == 0 {
                Text("Tap for details")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
    }

    private func alertBadge(count: Int, color: Color) -> some View {
        Text(count == 1 ? "\(count) alert" : "\(count) alerts")
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func badge(label: LocalizedStringKey, color: Color) -> some View {
        Text(label)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let phase {
            parts.append(phase.displayNameString + " phase")
        }
        if let day = cycleDay {
            parts.append("day \(day)")
        }
        if alertCount > 0 { parts.append("\(alertCount) alert\(alertCount == 1 ? "" : "s")") }
        if insightCount > 0 { parts.append("1 insight") }
        if tipCount > 0 { parts.append("1 tip") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - CycleDetailSheet

/// Full-detail sheet opened from CycleRingSummaryCard.
/// Uses a TabView page carousel so content is discoverable without overwhelming the home screen.
struct CycleDetailSheet: View {
    let cycleStore: CycleStore
    let phase: CyclePhase?
    let cycleDay: Int?
    let predictionRange: (earliest: Date, latest: Date)?
    let averageCycleLength: Int?
    let activeSignals: [SeveritySignal]
    let activeNudge: CycleNudge?
    let onDismissSignal: (String) -> Void
    let onDismissNudge: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 0
    @State private var showingSupport = false

    private var tabs: [DetailTab] { DetailTab.build(
        hasAlerts: !activeSignals.isEmpty || activeNudge != nil,
        hasInsight: cycleStore.todayInsight() != nil,
        hasTip: phase != nil
    )}

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Page content
                TabView(selection: $selectedTab) {
                    ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                        ScrollView {
                            VStack(spacing: 16) {
                                tabContent(for: tab)
                            }
                            .padding()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: selectedTab)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(phase?.displayName ?? "Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSupport = true
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.Colors.secondaryPink)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Get support")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.accentBlue)
                }
            }
            .sheet(isPresented: $showingSupport) {
                GetSupportView(cycleStore: cycleStore)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    Button {
                        withAnimation { selectedTab = index }
                    } label: {
                        HStack(spacing: 5) {
                            if tab == .alerts {
                                Circle()
                                    .fill(AppTheme.Colors.amber)
                                    .frame(width: 6, height: 6)
                            }
                            Text(tab.label)
                                .font(.system(.subheadline, design: .rounded, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundColor(selectedTab == index ? .white : AppTheme.Colors.deepGrayText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == index
                                ? (tab == .alerts ? AppTheme.Colors.amber : AppTheme.Colors.accentBlue)
                                : AppTheme.Colors.secondaryBackground
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(selectedTab == index ? 0.08 : 0.04), radius: 4, x: 0, y: 1)
                    }
                    .accessibilityAddTraits(selectedTab == index ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: DetailTab) -> some View {
        switch tab {
        case .overview:
            overviewContent

        case .insights:
            if let insight = cycleStore.todayInsight() {
                InsightCard(insight: insight)
            }

        case .tips:
            if let phase {
                let tip = ContentEvaluator(store: cycleStore).dailyTip()
                PhaseTipCard(phase: phase, contentTip: tip)
            }

        case .alerts:
            ForEach(activeSignals) { signal in
                SeveritySignalCard(signal: signal) {
                    onDismissSignal(signal.id)
                }
            }
            if let nudge = activeNudge {
                PatternNudgeCard(nudge: nudge, onDismiss: onDismissNudge)
            }
        }
    }

    // MARK: - Overview Content

    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Overdue state — phase is nil but we have cycle history
            if phase == nil && averageCycleLength != nil {
                overdueCard
            }

            // Phase + description
            if let phase {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.forPhase(phase.themeColorName).opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: phase.sfSymbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.forPhase(phase.themeColorName))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let day = cycleDay {
                            Text("Day \(day)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                        }
                        Text(phase.displayName)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                        Text(phase.phaseDescription)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(AppTheme.Metrics.cardPadding)
                .background(AppTheme.Colors.secondaryBackground)
                .cornerRadius(AppTheme.Metrics.cornerRadius)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }

            // Next period prediction
            if let range = predictionRange {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.forecastPeriod)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.Colors.forecastPeriod.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next period")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                        Text(formattedRange(range))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                    }

                    Spacer(minLength: 0)

                    if let length = averageCycleLength {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Avg cycle")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                            Text("\(length) days")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                        }
                    }
                }
                .padding(AppTheme.Metrics.cardPadding)
                .background(AppTheme.Colors.secondaryBackground)
                .cornerRadius(AppTheme.Metrics.cornerRadius)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
        }
    }

    private var overdueCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppTheme.Colors.amber)
                .frame(width: 52, height: 52)
                .background(AppTheme.Colors.amber.opacity(0.12))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Cycle running longer than usual")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                Text("Cycles can run longer for many reasons — stress, illness, changes in sleep or weight, or hormonal shifts. If this is unusual for you and you're concerned, a GP can help.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.amber.opacity(0.08))
        .cornerRadius(AppTheme.Metrics.cornerRadius)
    }

    private func formattedRange(_ range: (earliest: Date, latest: Date)) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDate(range.earliest, equalTo: range.latest, toGranularity: .month) {
            formatter.dateFormat = "d"
            let endStr = formatter.string(from: range.latest)
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: range.earliest))–\(endStr)"
        } else {
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: range.earliest)) – \(formatter.string(from: range.latest))"
        }
    }
}

// MARK: - DetailTab

private enum DetailTab: String, Hashable, CaseIterable {
    case overview, insights, tips, alerts

    var label: LocalizedStringKey {
        switch self {
        case .overview:  return "Overview"
        case .insights:  return "Insights"
        case .tips:      return "Tips"
        case .alerts:    return "Alerts"
        }
    }

    static func build(hasAlerts: Bool, hasInsight: Bool, hasTip: Bool) -> [DetailTab] {
        var tabs: [DetailTab] = [.overview]
        if hasInsight { tabs.append(.insights) }
        if hasTip     { tabs.append(.tips) }
        if hasAlerts  { tabs.append(.alerts) }
        return tabs
    }
}

// MARK: - Preview

#Preview {
    CycleRingSummaryCard(
        cycleStore: CycleStore(),
        phase: .follicular,
        cycleDay: 11,
        predictionRange: (
            earliest: Calendar.current.date(byAdding: .day, value: 8, to: Date())!,
            latest:   Calendar.current.date(byAdding: .day, value: 13, to: Date())!
        ),
        averageCycleLength: 28,
        activeSignals: [],
        activeNudge: nil,
        onDismissSignal: { _ in },
        onDismissNudge: {}
    )
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
