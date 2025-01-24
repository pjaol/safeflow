import SwiftUI

struct CycleCalendarView: View {
    @ObservedObject var cycleStore: CycleStore
    @State private var selectedDate: Date?
    @State private var showingDayDetail = false
    @State private var currentMonth = Date()
    @State private var predictedDates: [Date] = []
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private var averageCycleLength: Int {
        cycleStore.calculateAverageCycleLength() ?? 28
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar header
            HStack {
                Text("Your Cycle")
                    .font(AppTheme.Typography.headlineFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Spacer()
                
                Button {
                    currentMonth = Date()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundColor(AppTheme.Colors.accentBlue)
                }
            }
            .padding()
            .background(AppTheme.Colors.secondaryBackground)
            
            // Month navigation
            HStack {
                Button {
                    if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                        currentMonth = newDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.Colors.accentBlue)
                }
                
                Spacer()
                
                Text(monthYearString(from: currentMonth))
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
                
                Spacer()
                
                Button {
                    if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                        currentMonth = newDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.Colors.accentBlue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Weekday headers
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(AppTheme.Typography.captionFont)
                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: selectedDate == date,
                            cycleDay: cycleStore.getDay(for: date),
                            isToday: calendar.isDateInToday(date),
                            isPredicted: isPredictedPeriodDay(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            showingDayDetail = true
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(AppTheme.Colors.background)
        .sheet(isPresented: $showingDayDetail) {
            if let selectedDate = selectedDate {
                DayDetailView(
                    cycleStore: cycleStore,
                    date: selectedDate,
                    existingDay: cycleStore.getDay(for: selectedDate)
                )
            }
        }
        .onAppear {
            updatePredictions()
        }
        .onChange(of: currentMonth) { _ in
            updatePredictions()
        }
    }
    
    private func updatePredictions() {
        // Start with the next predicted period
        guard let firstPrediction = cycleStore.predictNextPeriod() else {
            predictedDates = []
            return
        }
        
        var predictions: [Date] = [firstPrediction]
        let numberOfPredictions = 12 // Show predictions for the next year
        
        // Calculate future predictions based on average cycle length
        for i in 1..<numberOfPredictions {
            if let nextDate = calendar.date(byAdding: .day, value: averageCycleLength * i, to: firstPrediction) {
                predictions.append(nextDate)
            }
        }
        
        predictedDates = predictions
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        let remainingCells = 42 - days.count // 6 rows * 7 days
        days.append(contentsOf: Array(repeating: nil, count: remainingCells))
        
        return days
    }
    
    private func isPredictedPeriodDay(_ date: Date) -> Bool {
        for predictedStart in predictedDates {
            // Consider the typical period duration (5-7 days)
            let periodDuration = 5
            
            // Check if the date falls within any predicted period window
            for dayOffset in 0..<periodDuration {
                if let predictedDay = calendar.date(byAdding: .day, value: dayOffset, to: predictedStart),
                   calendar.isDate(date, inSameDayAs: predictedDay) {
                    return true
                }
            }
        }
        return false
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let cycleDay: CycleDay?
    let isToday: Bool
    let isPredicted: Bool
    
    private var dayNumber: String {
        let calendar = Calendar.current
        return "\(calendar.component(.day, from: date))"
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .overlay(
                    Circle()
                        .strokeBorder(isPredicted ? AppTheme.Colors.secondaryPink.opacity(0.5) : Color.clear, lineWidth: 2)
                )
            
            Text(dayNumber)
                .font(AppTheme.Typography.bodyFont)
                .foregroundColor(textColor)
        }
        .aspectRatio(1, contentMode: .fill)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.Colors.secondaryPink
        } else if cycleDay?.flow != nil {
            return AppTheme.Colors.primaryBlue.opacity(0.3)
        } else if isPredicted {
            return AppTheme.Colors.secondaryPink.opacity(0.1)
        } else if isToday {
            return AppTheme.Colors.accentBlue.opacity(0.2)
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if cycleDay?.flow != nil {
            return AppTheme.Colors.deepGrayText
        } else if isPredicted {
            return AppTheme.Colors.secondaryPink
        } else if isToday {
            return AppTheme.Colors.accentBlue
        } else {
            return AppTheme.Colors.mediumGrayText
        }
    }
}

struct DayDetailView: View {
    @ObservedObject var cycleStore: CycleStore
    let date: Date
    let existingDay: CycleDay?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(date, style: .date)
                                .font(AppTheme.Typography.headlineFont)
                            
                            if let day = existingDay {
                                if let flow = day.flow {
                                    Text("Flow: \(flow.rawValue.capitalized)")
                                        .font(AppTheme.Typography.bodyFont)
                                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                                }
                                
                                if !day.symptoms.isEmpty {
                                    Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                                        .font(AppTheme.Typography.bodyFont)
                                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                                }
                                
                                if let mood = day.mood {
                                    Text("Mood: \(mood.localizedName)")
                                        .font(AppTheme.Typography.bodyFont)
                                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                                }
                                
                                if let notes = day.notes, !notes.isEmpty {
                                    Text("Notes: \(notes)")
                                        .font(AppTheme.Typography.bodyFont)
                                        .foregroundColor(AppTheme.Colors.mediumGrayText)
                                }
                            } else {
                                Text("No data recorded")
                                    .font(AppTheme.Typography.bodyFont)
                                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            // Edit day
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(AppTheme.Colors.accentBlue)
                                .imageScale(.large)
                        }
                    }
                }
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.accentBlue)
                }
            }
        }
    }
} 