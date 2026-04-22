import SwiftUI

#if DEBUG || BETA
struct DebugMenu: View {
    @ObservedObject var cycleStore: CycleStore
    @Environment(\.dismiss) private var dismiss
    @State private var loadStatus: String?
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @AppStorage(LifeStage.defaultsKey) private var lifeStage: LifeStage = .regular


    // MARK: - Scenarios

    private struct Scenario {
        let name: String
        let description: String
        let filename: String
        let seedCycleLength: Int
        let seedPeriodLength: Int
    }

    private let scenarios: [Scenario] = [
        Scenario(
            name: "Symptom-Rich (6 cycles)",
            description: "Regular 28-day cycles with detailed symptom and mood logging across 6 cycles. Good general-purpose baseline.",
            filename: "symptom_rich_cycles",
            seedCycleLength: 28,
            seedPeriodLength: 6
        ),
        Scenario(
            name: "New User (1 cycle)",
            description: "Only one period logged. Tests early-data states: wide prediction range, no nudges, no insights.",
            filename: "scenario_new_user",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "High Variability / PCOS",
            description: "Cycles ranging 22–45 days across 7 cycles. Triggers high-variability nudge and increasing-variability (perimenopause) nudge.",
            filename: "scenario_high_variability",
            seedCycleLength: 34,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "Heavy Flow Pattern",
            description: "Consistently heavy flow across 6 cycles. Triggers heavy-flow severity signal.",
            filename: "scenario_heavy_flow",
            seedCycleLength: 28,
            seedPeriodLength: 6
        ),
        Scenario(
            name: "Escalating Cramps",
            description: "Cramp days increase cycle over cycle (1→2→4→4→5→6). Triggers cramps-escalating severity signal.",
            filename: "scenario_escalating_cramps",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "Overdue Cycle",
            description: "Last period was ~70 days ago with 5 prior regular cycles. Tests the overdue-cycle nudge and ring arc behaviour.",
            filename: "scenario_overdue_cycle",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "PMDD Pattern",
            description: "Negative mood (anxious, irritable, sad, sensitive) logged in late luteal across 6 cycles. Triggers PMDD pattern signal.",
            filename: "scenario_pmdd_pattern",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
        // Signal scenarios — perimenopause + menopause
        Scenario(
            name: "Signal: Early Perimenopause",
            description: "Jan–Apr 2025. Cycles arriving but getting variable (28→42 day gaps). Hot flashes absent in Jan, escalating to 10+ days by Apr. Sleep declining. Use with Life Stage → Perimenopause.",
            filename: "scenario_early_perimenopause",
            seedCycleLength: 32,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "Signal: Late Perimenopause",
            description: "Jan–Apr 2025. No flow at all. 16–22 hot flash days/month escalating. Consistently poor sleep and energy. Use with Life Stage → Perimenopause.",
            filename: "scenario_late_perimenopause",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "Signal: Menopause Stable",
            description: "Jan–Apr 2025. Improving arc — 16 hot flash days in Jan down to 8 in Apr. Sleep trending better. Use with Life Stage → Menopause.",
            filename: "scenario_menopause_stable",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
        Scenario(
            name: "Signal: Symptoms Returning",
            description: "Jan–Apr 2025. Quiet Jan/Feb (possible HRT), regression from Mar — 16 hot flash days in Apr. Sleep worsening. Use with Life Stage → Menopause.",
            filename: "scenario_menopause_symptoms_returning",
            seedCycleLength: 28,
            seedPeriodLength: 5
        ),
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section("Data Management") {
                    Button("Clear All Data", role: .destructive) {
                        cycleStore.clearAllData()
                        loadStatus = "✓ Data cleared"
                    }
                }

                Section {
                    if let status = loadStatus {
                        HStack(spacing: 8) {
                            Image(systemName: status.hasPrefix("✓") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(status.hasPrefix("✓") ? .green : .red)
                                .font(.caption)
                            Text(status)
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                        }
                    }
                }

                Section("Test Scenarios") {
                    ForEach(scenarios, id: \.filename) { scenario in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(scenario.name)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                            Text(scenario.description)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(AppTheme.Colors.mediumGrayText)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Clear + Load") {
                                loadScenario(scenario)
                            }
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.accentBlue)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Life Stage") {
                    Picker("Life Stage", selection: $lifeStage) {
                        Text("Regular").tag(LifeStage.regular)
                        Text("Irregular").tag(LifeStage.irregular)
                        Text("Perimenopause").tag(LifeStage.perimenopause)
                        Text("Menopause").tag(LifeStage.menopause)
                        Text("Paused").tag(LifeStage.paused)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Language") {
                    Picker("Language", selection: $appLanguage) {
                        Text("System default").tag("system")
                        Text("English").tag("en")
                        Text("Deutsch (de-DE)").tag("de-DE")
                        Text("Español (es-MX)").tag("es-MX")
                        Text("Français (fr-FR)").tag("fr-FR")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Testing") {
                    NavigationLink("Prediction Test Cases") {
                        TestCaseRunnerView()
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Loader

    private func loadScenario(_ scenario: Scenario) {
        loadStatus = "Loading \(scenario.name)..."
        Task {
            do {
                guard let url = Bundle.main.url(forResource: scenario.filename, withExtension: "csv") else {
                    await MainActor.run { loadStatus = "✗ File not found: \(scenario.filename).csv" }
                    return
                }
                let csv = try String(contentsOf: url, encoding: .utf8)
                let entries = try TestDataLoader.shared.parseEntriesPublic(from: csv)

                cycleStore.clearAllData()

                if let firstEntry = entries.first {
                    let seed = CycleSeedData(
                        lastPeriodStartDate: firstEntry.date,
                        typicalPeriodLength: scenario.seedPeriodLength,
                        typicalCycleLength: scenario.seedCycleLength
                    )
                    cycleStore.saveSeedData(seed)
                }

                for entry in entries {
                    let day = CycleDay(
                        id: UUID(),
                        date: entry.date,
                        flow: entry.flow,
                        symptoms: entry.symptoms,
                        mood: entry.mood,
                        notes: entry.notes
                    )
                    cycleStore.addOrUpdateDay(day)
                }

                await MainActor.run {
                    loadStatus = "✓ Loaded \(scenario.name) — \(entries.count) days"
                    cycleStore.rescheduleSupplyReminder()
                }
            } catch {
                await MainActor.run { loadStatus = "✗ Error: \(error.localizedDescription)" }
            }
        }
    }
}
#endif
