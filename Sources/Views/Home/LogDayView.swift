import SwiftUI
import os

struct LogDayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cycleStore: CycleStore
    let existingDay: CycleDay?
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "LogDayView")
    
    @State private var selectedFlow: FlowIntensity?
    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var selectedMood: Mood = .neutral
    @State private var notes: String = ""
    
    init(cycleStore: CycleStore, existingDay: CycleDay?) {
        self.cycleStore = cycleStore
        self.existingDay = existingDay
        
        // Initialize state with existing values if editing
        if let day = existingDay {
            logger.debug("Initializing view with existing day: \(day.id.uuidString), date: \(day.date.description)")
            _selectedFlow = State(initialValue: day.flow)
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
                        Text("None").tag(Optional<FlowIntensity>.none)
                        ForEach(FlowIntensity.allCases, id: \.self) { flow in
                            Text(flow.rawValue.capitalized)
                                .tag(Optional(flow))
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.Colors.primaryBlue)
                }
                
                Section("Symptoms") {
                    ForEach(Symptom.allCases, id: \.self) { symptom in
                        Toggle(symptom.localizedName, isOn: binding(for: symptom))
                            .tint(AppTheme.Colors.secondaryPink)
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
                    .tint(AppTheme.Colors.paleYellow)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .font(AppTheme.Typography.bodyFont)
                }
            }
            .navigationTitle(existingDay != nil ? "Edit Log" : "New Log")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        logger.debug("Cancelling log entry")
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let date = existingDay?.date ?? Date()
                        let id = existingDay?.id ?? UUID()
                        
                        let day = CycleDay(
                            id: id,
                            date: date,
                            flow: selectedFlow,
                            symptoms: selectedSymptoms,
                            mood: selectedMood == .neutral ? nil : selectedMood,
                            notes: notes.isEmpty ? nil : notes
                        )
                        logger.debug("Saving day with id: \(day.id.uuidString), date: \(day.date.description), flow: \(String(describing: day.flow)), symptoms count: \(day.symptoms.count)")
                        cycleStore.addOrUpdateDay(day)
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primaryBlue)
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
