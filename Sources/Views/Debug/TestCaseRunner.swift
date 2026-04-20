import SwiftUI
import os

@MainActor
class TestRunner: ObservableObject {
    @Published var testCases: [CycleTestCase] = []
    @Published var selectedTestCase: CycleTestCase?
    @Published var isLoading = false
    @Published var error: String?
    @Published var testResults: [UUID: TestResult] = [:]
    
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "TestRunner")
    
    struct TestResult {
        let success: Bool
        let predictedDates: [Date]
        let expectedDates: [Date]
        let message: String
    }
    
    func loadTestCases() {
        isLoading = true
        error = nil
        
        Task {
            do {
                // Debug: Print bundle contents
                if let resourcePath = Bundle.main.resourcePath {
                    logger.debug("Bundle resource path: \(resourcePath)")
                    let fileManager = FileManager.default
                    let contents = try fileManager.contentsOfDirectory(atPath: resourcePath)
                    logger.debug("Bundle contents: \(contents)")
                    
                    // Find base names by looking for main CSV files (those without _metadata or _predictions)
                    let baseNames = contents
                        .filter { $0.hasSuffix(".csv") }
                        .filter { !$0.contains("_metadata") && !$0.contains("_predictions") }
                        .map { $0.replacingOccurrences(of: ".csv", with: "") }
                    
                    logger.debug("Found base names: \(baseNames)")
                    
                    var testCases: [CycleTestCase] = []
                    for baseName in baseNames {
                        do {
                            if let mainFile = Bundle.main.url(forResource: baseName, withExtension: "csv"),
                               let metadataFile = Bundle.main.url(forResource: "\(baseName)_metadata", withExtension: "csv"),
                               let predictionsFile = Bundle.main.url(forResource: "\(baseName)_predictions", withExtension: "csv") {
                                
                                logger.debug("Loading test case for \(baseName)")
                                logger.debug("Main file: \(mainFile)")
                                logger.debug("Metadata file: \(metadataFile)")
                                logger.debug("Predictions file: \(predictionsFile)")
                                
                                let testCase = try await TestDataLoader.shared.loadTestCase(
                                    mainFile: mainFile,
                                    metadataFile: metadataFile,
                                    predictionsFile: predictionsFile
                                )
                                testCases.append(testCase)
                                logger.debug("Successfully loaded test case: \(testCase.name)")
                            } else {
                                logger.error("Could not find all required files for \(baseName)")
                            }
                        } catch {
                            logger.error("Error loading test case \(baseName): \(error)")
                        }
                    }
                    
                    await MainActor.run {
                        self.testCases = testCases
                        logger.debug("Loaded \(testCases.count) test cases")
                    }
                } else {
                    throw TestDataError.fileNotFound("Bundle resource path not found")
                }
            } catch let error as TestDataError {
                await MainActor.run {
                    switch error {
                    case .fileNotFound(let path):
                        self.error = "File not found: \(path)"
                    case .invalidFormat(let details):
                        self.error = "Invalid file format: \(details)"
                    case .invalidDate(let value):
                        self.error = "Invalid date format: \(value)"
                    case .invalidFlow(let value):
                        self.error = "Invalid flow value: \(value)"
                    case .invalidSymptom(let value):
                        self.error = "Invalid symptom: \(value)"
                    case .invalidMood(let value):
                        self.error = "Invalid mood value: \(value)"
                    }
                    logger.error("Failed to load test cases: \(self.error ?? "Unknown error")")
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    logger.error("Unexpected error loading test cases: \(error.localizedDescription)")
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func runTest(testCase: CycleTestCase) {
        Task {
            await runTestAsync(testCase: testCase)
        }
    }
    
    private func runTestAsync(testCase: CycleTestCase) async {
        let cycleStore = CycleStore()
        
        // Wait for initialization to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second for store to initialize
        
        // Clear any existing data
        await cycleStore.clearAllData()
        logger.debug("Cleared existing data for test case: \(testCase.name)")
        
        // Load test data into store
        logger.debug("Loading \(testCase.entries.count) entries for test case: \(testCase.name)")
        for entry in testCase.entries {
            let cycleDay = CycleDay(
                id: UUID(),
                date: entry.date,
                flow: entry.flow,
                symptoms: entry.symptoms,
                mood: entry.mood,
                notes: entry.notes
            )
            await cycleStore.addOrUpdateDay(cycleDay)
            logger.debug("Added entry for date: \(entry.date), flow: \(String(describing: entry.flow))")
        }
        
        // Wait for data to be saved
        try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds for data to be saved
        
        // Verify data was loaded
        let loadedDays = await cycleStore.getAllDays()
        logger.debug("Loaded \(loadedDays.count) days in CycleStore")
        
        // Get predictions
        var predictedDates: [Date] = []
        if let firstPrediction = await cycleStore.predictNextPeriod() {
            logger.debug("First prediction: \(firstPrediction)")
            predictedDates.append(firstPrediction)
            
            // Calculate additional predictions
            let numberOfPredictions = testCase.expectedPredictions.count
            let averageCycleLength = await cycleStore.calculateAverageCycleLength() ?? 28
            logger.debug("Average cycle length: \(averageCycleLength)")
            
            for i in 1..<numberOfPredictions {
                if let nextDate = Calendar.current.date(byAdding: .day, value: averageCycleLength * i, to: firstPrediction) {
                    logger.debug("Additional prediction \(i): \(nextDate)")
                    predictedDates.append(nextDate)
                }
            }
        } else {
            logger.error("Failed to get first prediction")
        }
        
        // Compare predictions with expected dates
        let calendar = Calendar.current
        let success = predictedDates.count == testCase.expectedPredictions.count &&
            zip(predictedDates, testCase.expectedPredictions).allSatisfy { predicted, expected in
                calendar.isDate(predicted, inSameDayAs: expected)
            }
        
        let message: String
        if success {
            message = "All predictions match expected dates"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let predictedString = predictedDates.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
            let expectedString = testCase.expectedPredictions.map { dateFormatter.string(from: $0) }.joined(separator: ", ")
            
            message = """
                Predictions do not match expected dates
                Predicted: \(predictedString)
                Expected: \(expectedString)
                """
            logger.error("\(message)")
        }
        
        testResults[testCase.id] = TestResult(
            success: success,
            predictedDates: predictedDates,
            expectedDates: testCase.expectedPredictions,
            message: message
        )
    }
    
    func runAllTests() {
        Task {
            for testCase in testCases {
                await runTestAsync(testCase: testCase)
            }
        }
    }
}

struct TestCaseRunnerView: View {
    @StateObject private var runner = TestRunner()
    
    var body: some View {
        List {
            if runner.isLoading {
                ProgressView("Loading test cases...")
            } else if let error = runner.error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                Section {
                    Button("Run All Tests") {
                        runner.runAllTests()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                Section("Test Cases") {
                    ForEach(runner.testCases) { testCase in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(testCase.name)
                                    .font(AppTheme.Typography.bodyFont)
                                
                                Spacer()
                                
                                if let result = runner.testResults[testCase.id] {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                }
                            }
                            
                            if !testCase.description.isEmpty {
                                Text(testCase.description)
                                    .font(AppTheme.Typography.captionFont)
                                    .foregroundColor(AppTheme.Colors.mediumGrayText)
                            }
                            
                            if let result = runner.testResults[testCase.id] {
                                Text(result.message)
                                    .font(AppTheme.Typography.captionFont)
                                    .foregroundColor(result.success ? .green : .red)
                            }
                            
                            Button("Run Test") {
                                runner.runTest(testCase: testCase)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Test Cases")
        .onAppear {
            runner.loadTestCases()
        }
    }
} 