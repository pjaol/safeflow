import SwiftUI

#if DEBUG
struct DebugMenu: View {
    @ObservedObject var cycleStore: CycleStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingTestRunner = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Data Management") {
                    Button("Clear All Data", role: .destructive) {
                        cycleStore.clearAllData()
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif 