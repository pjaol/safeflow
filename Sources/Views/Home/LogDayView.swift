import SwiftUI
import os

struct LogDayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cycleStore: CycleStore
    let existingDay: CycleDay?
    /// The date to save to when creating a new log. Defaults to today.
    let targetDate: Date
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "LogDayView")

    @State private var selectedFlow: FlowIntensity?
    @State private var selectedSymptoms: Set<Symptom> = []
    @State private var selectedMood: Mood?
    @State private var notes: String = ""
    @State private var selectedSymptomCategory: SymptomCategory = .pain

    init(cycleStore: CycleStore, existingDay: CycleDay?, targetDate: Date = Date()) {
        self.cycleStore = cycleStore
        self.existingDay = existingDay
        self.targetDate = existingDay?.date ?? targetDate

        if let day = existingDay {
            _selectedFlow = State(initialValue: day.flow)
            _selectedSymptoms = State(initialValue: day.symptoms)
            _selectedMood = State(initialValue: day.mood)
            _notes = State(initialValue: day.notes ?? "")
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Metrics.standardSpacing) {
                    flowSection
                    symptomsSection
                    moodSection
                    notesSection
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(existingDay != nil ? "Edit Log" : "New Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                    .accessibilityIdentifier("logDay.cancelButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDay()
                    }
                    .foregroundColor(AppTheme.Colors.primaryBlue)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("logDay.saveButton")
                }
            }
        }
    }

    // MARK: - Flow Section

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Flow", systemImage: "drop.fill", color: AppTheme.Colors.secondaryPink)

            HStack(spacing: 10) {
                // None option
                FlowChip(
                    label: "None",
                    sfSymbol: "xmark",
                    isSelected: selectedFlow == nil,
                    color: AppTheme.Colors.neutralGray
                ) {
                    selectedFlow = nil
                }
                .accessibilityIdentifier("logDay.flow.none")

                ForEach(FlowIntensity.allCases, id: \.self) { flow in
                    FlowChip(
                        label: flow.localizedName,
                        sfSymbol: flow.sfSymbol,
                        isSelected: selectedFlow == flow,
                        color: AppTheme.Colors.secondaryPink
                    ) {
                        selectedFlow = flow
                    }
                    .accessibilityIdentifier("logDay.flow.\(flow.rawValue)")
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
    }

    // MARK: - Symptoms Section

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Symptoms", systemImage: "heart.text.square", color: AppTheme.Colors.accentBlue)

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SymptomCategory.allCases, id: \.self) { category in
                        CategoryTab(
                            label: category.localizedName,
                            isSelected: selectedSymptomCategory == category
                        ) {
                            selectedSymptomCategory = category
                        }
                        .accessibilityIdentifier("logDay.symptomCategory.\(category.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
            }

            // Symptom chips for selected category
            let symptomsInCategory = Symptom.allCases.filter { $0.category == selectedSymptomCategory }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(symptomsInCategory, id: \.self) { symptom in
                    SymptomChip(
                        symptom: symptom,
                        isSelected: selectedSymptoms.contains(symptom)
                    ) {
                        if selectedSymptoms.contains(symptom) {
                            selectedSymptoms.remove(symptom)
                        } else {
                            selectedSymptoms.insert(symptom)
                        }
                    }
                    .accessibilityIdentifier("logDay.symptom.\(symptom.rawValue)")
                }
            }

            if !selectedSymptoms.isEmpty {
                Text("\(selectedSymptoms.count) selected")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("How are you feeling?", systemImage: "circle.grid.2x2.fill", color: AppTheme.Colors.amber)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodCell(
                        mood: mood,
                        isSelected: selectedMood == mood
                    ) {
                        selectedMood = (selectedMood == mood) ? nil : mood
                    }
                    .accessibilityIdentifier("logDay.mood.\(mood.rawValue)")
                }
            }
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Notes", systemImage: "note.text", color: AppTheme.Colors.primaryBlue)

            TextEditor(text: $notes)
                .frame(minHeight: 88)
                .font(AppTheme.Typography.bodyFont)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .accessibilityIdentifier("logDay.notesEditor")
        }
        .padding(AppTheme.Metrics.cardPadding)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(AppTheme.Metrics.cornerRadius)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .font(.system(.callout, weight: .semibold))
            Text(title)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundColor(AppTheme.Colors.deepGrayText)
        }
    }

    private func saveDay() {
        let date = targetDate
        let id = existingDay?.id ?? UUID()
        let day = CycleDay(
            id: id,
            date: date,
            flow: selectedFlow,
            symptoms: selectedSymptoms,
            mood: selectedMood,
            notes: notes.isEmpty ? nil : notes
        )
        logger.debug("Saving day id:\(day.id.uuidString) flow:\(String(describing: day.flow)) symptoms:\(day.symptoms.count)")
        cycleStore.addOrUpdateDay(day)
        dismiss()
    }
}

// MARK: - Flow Chip

struct FlowChip: View {
    let label: String
    let sfSymbol: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.deepGrayText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(AppTheme.Metrics.cornerRadius)
        }
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.deepGrayText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? AppTheme.Colors.accentBlue : AppTheme.Colors.accentBlue.opacity(0.15))
                .cornerRadius(20)
        }
    }
}

// MARK: - Symptom Chip

struct SymptomChip: View {
    let symptom: Symptom
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symptom.sfSymbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.accentBlue)
                Text(symptom.localizedName)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.deepGrayText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.Colors.accentBlue : AppTheme.Colors.accentBlue.opacity(0.12))
            .cornerRadius(AppTheme.Metrics.cornerRadius)
        }
    }
}

// MARK: - Mood Cell

struct MoodCell: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mood.sfSymbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.deepGrayText : AppTheme.Colors.mediumGrayText)
                Text(mood.localizedName)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.deepGrayText : AppTheme.Colors.mediumGrayText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.Colors.amber.opacity(0.15) : AppTheme.Colors.amber.opacity(0.07))
            .cornerRadius(AppTheme.Metrics.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius)
                    .strokeBorder(isSelected ? AppTheme.Colors.amber : Color.clear, lineWidth: 2)
            )
        }
    }
}
