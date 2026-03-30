import SwiftUI

#if DEBUG
struct DebugMenu: View {
    @ObservedObject var cycleStore: CycleStore
    @Environment(\.dismiss) private var dismiss
    @State private var loadStatus: String?

    var body: some View {
        NavigationView {
            List {
                Section("Data Management") {
                    Button("Clear All Data", role: .destructive) {
                        cycleStore.clearAllData()
                        loadStatus = "Data cleared"
                    }
                }

                Section("Test Fixtures") {
                    Button("Load Symptom-Rich Dataset") {
                        loadSymptomRichData()
                    }
                    if let status = loadStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(AppTheme.Colors.mediumGrayText)
                    }
                }

                Section("Testing") {
                    NavigationLink("Test Cases") {
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

    // MARK: - Symptom-Rich Fixture Loader

    private func loadSymptomRichData() {
        loadStatus = "Loading..."
        Task {
            do {
                guard let url = Bundle.main.url(forResource: "symptom_rich_cycles", withExtension: "csv") else {
                    await MainActor.run { loadStatus = "Error: file not found in bundle" }
                    return
                }
                let csv = try String(contentsOf: url, encoding: .utf8)
                let entries = try TestDataLoader.shared.parseEntriesPublic(from: csv)

                cycleStore.clearAllData()

                // Seed data: 28-day cycle, last period = first entry date
                if let firstEntry = entries.first {
                    let seed = CycleSeedData(
                        lastPeriodStartDate: firstEntry.date,
                        typicalPeriodLength: 6,
                        typicalCycleLength: 28
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
                    loadStatus = "Loaded \(entries.count) days across 6 cycles"
                    cycleStore.rescheduleSupplyReminder()
                }
            } catch {
                await MainActor.run { loadStatus = "Error: \(error.localizedDescription)" }
            }
        }
    }
}
#endif 