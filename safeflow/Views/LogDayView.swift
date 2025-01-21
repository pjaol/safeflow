import SwiftUI
import os

struct LogDayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cycleStore: CycleStore
    let existingDay: CycleDay?
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "LogDayView")
    
    @State private var selectedFlow: FlowIntensity = .none
    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var selectedMood: Mood = .neutral
    @State private var notes: String = ""
    
    init(cycleStore: CycleStore, existingDay: CycleDay?) {
        self.cycleStore = cycleStore
        self.existingDay = existingDay
        
        // Initialize state with existing values if editing
        if let day = existingDay {
            logger.debug("Initializing view with existing day: \(day.id.uuidString), date: \(day.date.description)")
            _selectedFlow = State(initialValue: day.flow ?? .none)
            _selectedSymptoms = State(initialValue: day.symptoms)
            _selectedMood = State(initialValue: day.mood ?? .neutral)
            _notes = State(initialValue: day.notes ?? "")
        } else {
            logger.debug("Initializing view for new day")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Flow") {
                    Picker("Flow Intensity", selection: $selectedFlow) {
                        ForEach(FlowIntensity.allCases, id: \.self) { flow in
                            Text(flow.localizedName)
                                .tag(flow)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Symptoms") {
                    ForEach(Symptom.allCases, id: \.self) { symptom in
                        Toggle(symptom.localizedName, isOn: binding(for: symptom))
                    }
                }
                
                Section("Mood") {
                    Picker("Mood", selection: $selectedMood) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            Text(mood.localizedName)
                                .tag(mood)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(existingDay != nil ? "Edit Log" : "New Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        logger.debug("Cancelling log entry")
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let day = CycleDay(
                            id: existingDay?.id ?? UUID(),
                            date: existingDay?.date ?? Date(),
                            flow: selectedFlow == .none ? nil : selectedFlow,
                            symptoms: selectedSymptoms,
                            mood: selectedMood == .neutral ? nil : selectedMood,
                            notes: notes.isEmpty ? nil : notes
                        )
                        logger.debug("Saving day with id: \(day.id.uuidString), date: \(day.date.description), flow: \(String(describing: day.flow)), symptoms count: \(day.symptoms.count)")
                        cycleStore.addOrUpdateDay(day)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func binding(for symptom: Symptom) -> Binding<Bool> {
        Binding(
            get: { selectedSymptoms.contains(symptom) },
            set: { isSelected in
                if isSelected {
                    selectedSymptoms.insert(symptom)
                } else {
                    selectedSymptoms.remove(symptom)
                }
            }
        )
    }
} 