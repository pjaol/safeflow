import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var cycleStore: CycleStore
    @State private var showingLogSheet = false
    @State private var showingNewEntrySheet = false
    
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
            .navigationTitle("SafeFlow")
            .toolbar {
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
        }
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
                if let flow = day.flow {
                    Text("Flow: \(flow.rawValue.capitalized)")
                }
                if !day.symptoms.isEmpty {
                    Text("Symptoms: \(day.symptoms.map { $0.localizedName }.joined(separator: ", "))")
                }
                if let mood = day.mood {
                    Text("Mood: \(mood.localizedName)")
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
            
            ForEach(days) { day in
                HStack {
                    VStack(alignment: .leading) {
                        Text(day.date, style: .date)
                            .font(.subheadline)
                        if let flow = day.flow {
                            Text(flow.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                .padding(.vertical, 8)
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
} 
