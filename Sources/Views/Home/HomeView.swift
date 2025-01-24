import SwiftUI
import os

struct HomeView: View {
    @ObservedObject var cycleStore: CycleStore
    @EnvironmentObject private var securityService: SecurityService
    @State private var showingLogSheet = false
    @State private var showingNewEntrySheet = false
    @State private var showingSettingsSheet = false
    #if DEBUG
    @State private var showingDebugMenu = false
    #endif
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Metrics.standardSpacing) {
                    PredictionCard(
                        predictedDate: cycleStore.predictNextPeriod(),
                        averageCycleLength: cycleStore.calculateAverageCycleLength()
                    )
                    
                    CycleCalendarView(cycleStore: cycleStore)
                        .frame(height: 400)
                    
                    DailyLogCard(cycleDay: cycleStore.getCurrentDay())
                        .onTapGesture {
                            showingLogSheet = true
                        }
                    
                    RecentLogsSection(days: cycleStore.recentDays) { id in
                        cycleStore.deleteDay(id: id)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.background)
            .navigationTitle("SafeFlow")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDebugMenu = true
                    } label: {
                        Image(systemName: "ladybug.fill")
                            .foregroundColor(AppTheme.Colors.secondaryPink)
                    }
                }
                #endif
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntrySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                            .foregroundColor(AppTheme.Colors.primaryBlue)
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                LogDayView(cycleStore: cycleStore, existingDay: cycleStore.getCurrentDay())
            }
            .sheet(isPresented: $showingNewEntrySheet) {
                LogDayView(cycleStore: cycleStore, existingDay: nil)
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
                    .environmentObject(securityService)
            }
            #if DEBUG
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenu(cycleStore: cycleStore)
            }
            #endif
        }
        .navigationViewStyle(.stack)
    }
}

struct PredictionCard: View {
    let predictedDate: Date?
    let averageCycleLength: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Period Prediction")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            
            if let date = predictedDate {
                Text(date, style: .date)
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.deepGrayText)
            } else {
                Text("Not enough data")
                    .font(AppTheme.Typography.captionFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
            
            if let length = averageCycleLength {
                Text("Average cycle: \(length) days")
                    .font(AppTheme.Typography.captionFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct DailyLogCard: View {
    let cycleDay: CycleDay?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Log")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            
            if let day = cycleDay {
                VStack(alignment: .leading, spacing: 8) {
                    if let flow = day.flow {
                        Text("Flow: \(flow.rawValue.capitalized)")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                    }
                    
                    if !day.symptoms.isEmpty {
                        Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let mood = day.mood {
                        Text("Mood: \(mood.localizedName)")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                    }
                    
                    if let notes = day.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .foregroundColor(AppTheme.Colors.deepGrayText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(AppTheme.Typography.bodyFont)
            } else {
                Text("Tap to log your day")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct RecentLogsSection: View {
    let days: [CycleDay]
    let onDelete: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(AppTheme.Typography.headlineFont)
                .foregroundColor(AppTheme.Colors.deepGrayText)
            
            if days.isEmpty {
                Text("No recent logs")
                    .font(AppTheme.Typography.bodyFont)
                    .foregroundColor(AppTheme.Colors.mediumGrayText)
            } else {
                ForEach(days) { day in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.date, style: .date)
                                .font(AppTheme.Typography.bodyFont)
                                .foregroundColor(AppTheme.Colors.deepGrayText)
                            
                            if let flow = day.flow {
                                Text("Flow: \(flow.rawValue.capitalized)")
                                    .font(AppTheme.Typography.captionFont)
                                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                            }
                            
                            if !day.symptoms.isEmpty {
                                Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                                    .font(AppTheme.Typography.captionFont)
                                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            onDelete(day.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(AppTheme.Colors.secondaryPink)
                        }
                    }
                    .padding()
                    .background(AppTheme.Colors.secondaryBackground)
                    .cornerRadius(AppTheme.Metrics.cornerRadius)
                }
            }
        }
    }
} 
