import SwiftUI

#if DEBUG
struct DebugMenu: View {
    @ObservedObject var cycleStore: CycleStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Data") {
                    Button("Load Sample Data (3 cycles)") {
                        TestData.loadSampleData(into: cycleStore)
                        dismiss()
                    }
                    
                    Button("Clear All Data") {
                        cycleStore.clearAllData()
                        dismiss()
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Debug Menu")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif 