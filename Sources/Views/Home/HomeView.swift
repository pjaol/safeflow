import SwiftUI
import UIKit

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
                VStack(spacing: 20) {
                    PredictionCard(
                        predictedDate: cycleStore.predictNextPeriod(),
                        averageCycleLength: cycleStore.calculateAverageCycleLength()
                    )
                    
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
            .navigationTitle("SafeFlow")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDebugMenu = true
                    } label: {
                        Image(systemName: "ladybug.fill")
                    }
                }
                #endif
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntrySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
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
                .font(.headline)
            
            if let date = predictedDate {
                Text(date, style: .date)
                    .font(.title2)
                    .foregroundColor(.primary)
            } else {
                Text("Not enough data")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let length = averageCycleLength {
                Text("Average cycle: \(length) days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct DailyLogCard: View {
    let cycleDay: CycleDay?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Log")
                .font(.headline)
            
            if let day = cycleDay {
                VStack(alignment: .leading, spacing: 8) {
                    if let flow = day.flow {
                        Text("Flow: \(flow.rawValue.capitalized)")
                            .foregroundColor(.primary)
                    }
                    
                    if !day.symptoms.isEmpty {
                        Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let mood = day.mood {
                        Text("Mood: \(mood.localizedName)")
                            .foregroundColor(.primary)
                    }
                    
                    if let notes = day.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text("Tap to log your day")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct RecentLogsSection: View {
    let days: [CycleDay]
    let onDelete: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(.headline)
            
            if days.isEmpty {
                Text("No recent logs")
                    .foregroundColor(.secondary)
            } else {
                ForEach(days) { day in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            if let flow = day.flow {
                                Text("Flow: \(flow.rawValue.capitalized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !day.symptoms.isEmpty {
                                Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            onDelete(day.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
} 
