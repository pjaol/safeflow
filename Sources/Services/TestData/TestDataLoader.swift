import Foundation

enum TestDataError: Error {
    case fileNotFound(String)
    case invalidFormat(String)
    case invalidDate(String)
    case invalidFlow(String)
    case invalidSymptom(String)
    case invalidMood(String)
}

class TestDataLoader {
    static let shared = TestDataLoader()
    private let dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    func loadTestCases(from directory: URL) async throws -> [CycleTestCase] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        
        // Filter for CSV files that don't end in _predictions.csv
        let testFiles = contents.filter { url in
            url.pathExtension.lowercased() == "csv" && !url.lastPathComponent.contains("_predictions")
        }
        
        return try await withThrowingTaskGroup(of: CycleTestCase.self) { group in
            for fileURL in testFiles {
                group.addTask {
                    try await self.loadTestCase(from: fileURL)
                }
            }
            
            var testCases: [CycleTestCase] = []
            for try await testCase in group {
                testCases.append(testCase)
            }
            return testCases
        }
    }
    
    private func loadTestCase(from fileURL: URL) async throws -> CycleTestCase {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let predictionsURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileName + "_predictions.csv")
        
        // Load main data
        let csvString = try String(contentsOf: fileURL, encoding: .utf8)
        let entries = try parseEntries(from: csvString)
        
        // Load predictions if they exist
        var predictions: [Date] = []
        if FileManager.default.fileExists(atPath: predictionsURL.path) {
            let predictionsString = try String(contentsOf: predictionsURL, encoding: .utf8)
            predictions = try parsePredictions(from: predictionsString)
        }
        
        // Load metadata if it exists
        let metadataURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileName + "_metadata.csv")
        var metadata: [String: String] = [:]
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            let metadataString = try String(contentsOf: metadataURL, encoding: .utf8)
            metadata = try parseMetadata(from: metadataString, baseName: fileName)
        }
        
        return CycleTestCase(
            name: fileName,
            description: metadata["description"] ?? "No description provided",
            entries: entries,
            expectedPredictions: predictions,
            metadata: metadata
        )
    }
    
    /// Public wrapper so debug tooling can parse a CSV directly without going through a full TestCase.
    func parseEntriesPublic(from csv: String) throws -> [CycleDayTestEntry] {
        try parseEntries(from: csv)
    }

    private func parseEntries(from csv: String) throws -> [CycleDayTestEntry] {
        var lines = csv.components(separatedBy: .newlines)
        
        // Remove empty lines
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Verify header
        guard lines.count > 1 else {
            throw TestDataError.invalidFormat("CSV file is empty or missing header")
        }
        
        let header = lines[0].lowercased()
        guard header.contains("date") else {
            throw TestDataError.invalidFormat("CSV header must contain 'date' column")
        }
        
        // Parse entries
        return try lines.dropFirst().map { line in
            try parseEntry(from: line)
        }
    }
    
    private func parseEntry(from line: String) throws -> CycleDayTestEntry {
        let components = splitCSVLine(line)
        guard components.count >= 1 else {
            throw TestDataError.invalidFormat("Invalid line format: \(line)")
        }
        
        // Parse date (required) — accepts either "yyyy-MM-dd" or an integer day offset from today (0 = today, -7 = 7 days ago)
        let dateString = components[0].trimmingCharacters(in: .whitespaces)
        let date: Date
        if let offset = Int(dateString) {
            let cal = Calendar.current
            date = cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date()) ?? Date())
        } else if let parsed = dateFormatter.date(from: dateString) {
            date = parsed
        } else {
            throw TestDataError.invalidDate("Invalid date format: \(dateString)")
        }
        
        // Parse flow (optional)
        let flow: FlowIntensity?
        if components.count > 1 && !components[1].isEmpty {
            let flowString = components[1].trimmingCharacters(in: .whitespaces).lowercased()
            if let parsedFlow = FlowIntensity(rawValue: flowString) {
                flow = parsedFlow
            } else {
                throw TestDataError.invalidFlow("Invalid flow value: \(components[1])")
            }
        } else {
            flow = nil
        }
        
        // Parse symptoms (optional)
        var symptoms: Set<Symptom> = []
        if components.count > 2 && !components[2].isEmpty {
            let symptomStrings = components[2].split(separator: ",").map(String.init)
            for symptomString in symptomStrings {
                let trimmed = symptomString.trimmingCharacters(in: .whitespaces)
                if let symptom = Symptom(rawValue: trimmed) {
                    symptoms.insert(symptom)
                } else {
                    throw TestDataError.invalidSymptom("Invalid symptom: \(trimmed)")
                }
            }
        }
        
        // Parse mood (optional)
        let mood: Mood?
        if components.count > 3 && !components[3].isEmpty {
            let moodString = components[3].trimmingCharacters(in: .whitespaces).lowercased()
            if let parsedMood = Mood(rawValue: moodString) {
                mood = parsedMood
            } else {
                throw TestDataError.invalidMood("Invalid mood value: \(components[3])")
            }
        } else {
            mood = nil
        }
        
        // Parse notes (optional, column 4)
        let notes = components.count > 4 ? components[4].trimmingCharacters(in: .whitespaces) : nil

        return CycleDayTestEntry(
            date: date,
            flow: flow,
            symptoms: symptoms,
            mood: mood,
            notes: notes
        )
    }
    
    private func parsePredictions(from csv: String) throws -> [Date] {
        var lines = csv.components(separatedBy: .newlines)
        lines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else {
            throw TestDataError.invalidFormat("Predictions CSV file is empty or missing header")
        }
        
        return try lines.dropFirst().compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let date = dateFormatter.date(from: trimmed) else {
                throw TestDataError.invalidDate("Invalid prediction date: \(trimmed)")
            }
            return date
        }
    }
    
    private func parseMetadata(from csv: String, baseName: String) throws -> [String: String] {
        var metadata: [String: String] = [:]
        let lines = csv.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .dropFirst() // Skip header row
        
        for line in lines {
            let components = splitCSVLine(line)
            guard components.count >= 2 else { continue }
            let key = components[0].trimmingCharacters(in: .whitespaces)
            let value = components[1].trimmingCharacters(in: .whitespaces)
            metadata[key] = value
        }
        
        // Add name based on the base name
        metadata["name"] = baseName
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
        
        return metadata
    }
    
    private func splitCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false
        
        for char in line {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if insideQuotes {
                    currentComponent.append(char)
                } else {
                    components.append(currentComponent)
                    currentComponent = ""
                }
            default:
                currentComponent.append(char)
            }
        }
        
        components.append(currentComponent)
        return components
    }
    
    func loadTestCase(mainFile: URL, metadataFile: URL, predictionsFile: URL) async throws -> CycleTestCase {
        // Extract base name from the main file URL
        let baseName = mainFile.deletingPathExtension().lastPathComponent
        
        let contents = try String(contentsOf: metadataFile)
        let metadata = try parseMetadata(from: contents, baseName: baseName)
        let entries = try await loadEntries(from: mainFile)
        let predictions = try await loadPredictions(from: predictionsFile)
        
        return CycleTestCase(
            name: metadata["name"] ?? baseName,
            description: metadata["description"] ?? "",
            entries: entries,
            expectedPredictions: predictions
        )
    }
    
    private func loadMetadata(from file: URL) async throws -> TestCaseMetadata {
        let contents = try String(contentsOf: file)
        let baseName = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_metadata", with: "")
        let metadata = try parseMetadata(from: contents, baseName: baseName)
        
        return TestCaseMetadata(
            name: metadata["name"] ?? baseName,
            description: metadata["description"] ?? ""
        )
    }
    
    private func loadEntries(from file: URL) async throws -> [CycleDayTestEntry] {
        let contents = try String(contentsOf: file)
        let lines = contents.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .dropFirst() // Skip header row
        
        return try lines.map { line in
            let components = splitCSVLine(line)
            guard components.count >= 4 else {
                throw TestDataError.invalidFormat("Invalid number of columns in entry")
            }
            
            let dateStr = components[0].trimmingCharacters(in: .whitespaces)
            guard let date = dateFormatter.date(from: dateStr) else {
                throw TestDataError.invalidDate(dateStr)
            }
            
            let flowStr = components[1].trimmingCharacters(in: .whitespaces)
            guard let flow = FlowIntensity(rawValue: flowStr) else {
                throw TestDataError.invalidFlow(flowStr)
            }
            
            let symptomsStr = components[2].trimmingCharacters(in: .whitespaces)
            let symptoms = symptomsStr.split(separator: ";")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .compactMap { Symptom(rawValue: $0) }
            
            let moodStr = components[3].trimmingCharacters(in: .whitespaces)
            guard let mood = Mood(rawValue: moodStr) else {
                throw TestDataError.invalidMood(moodStr)
            }
            
            let notes = components.count > 4 ? components[4].trimmingCharacters(in: .whitespaces) : nil
            
            return CycleDayTestEntry(
                date: date,
                flow: flow,
                symptoms: Set(symptoms),
                mood: mood,
                notes: notes
            )
        }
    }
    
    private func loadPredictions(from file: URL) async throws -> [Date] {
        let contents = try String(contentsOf: file)
        return try parsePredictions(from: contents)
    }
}

private struct TestCaseMetadata {
    let name: String
    let description: String
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
} 