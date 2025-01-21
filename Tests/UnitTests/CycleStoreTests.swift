import XCTest
@testable import safeflow

final class CycleStoreTests: XCTestCase {
    var sut: CycleStore!
    var userDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        sut = CycleStore(userDefaults: userDefaults)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: #file)
        userDefaults = nil
        sut = nil
        super.tearDown()
    }
    
    func testAddDay() async {
        // Given
        let date = Date()
        let cycleDay = CycleDay(date: date, flow: .medium, symptoms: [.cramps], mood: .happy)
        
        // When
        await sut.addOrUpdateDay(cycleDay)
        
        // Then
        XCTAssertEqual(await sut.cycleDays.count, 1)
        XCTAssertEqual(await sut.cycleDays.first?.flow, .medium)
        XCTAssertEqual(await sut.cycleDays.first?.symptoms, [.cramps])
        XCTAssertEqual(await sut.cycleDays.first?.mood, .happy)
    }
    
    func testUpdateDay() async {
        // Given
        let id = UUID()
        let date = Date()
        let originalDay = CycleDay(id: id, date: date, flow: .light)
        let updatedDay = CycleDay(id: id, date: date, flow: .heavy)
        
        // When
        await sut.addOrUpdateDay(originalDay)
        await sut.addOrUpdateDay(updatedDay)
        
        // Then
        XCTAssertEqual(await sut.cycleDays.count, 1)
        XCTAssertEqual(await sut.cycleDays.first?.flow, .heavy)
    }
    
    func testDeleteDay() async {
        // Given
        let day = CycleDay(date: Date(), flow: .medium)
        await sut.addOrUpdateDay(day)
        
        // When
        await sut.deleteDay(id: day.id)
        
        // Then
        XCTAssertTrue(await sut.cycleDays.isEmpty)
    }
    
    func testGetDaysInRange() async {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        
        let days = [
            CycleDay(date: today, flow: .medium),
            CycleDay(date: yesterday, flow: .light),
            CycleDay(date: twoDaysAgo, flow: .heavy),
            CycleDay(date: threeDaysAgo, flow: .spotting)
        ]
        
        for day in days {
            await sut.addOrUpdateDay(day)
        }
        
        // When
        let rangeResults = await sut.getDaysInRange(start: yesterday, end: today)
        
        // Then
        XCTAssertEqual(rangeResults.count, 2)
    }
    
    func testPredictNextPeriod() async {
        // Given
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: today)!
        
        let days = [
            CycleDay(date: today, flow: .medium),
            CycleDay(date: thirtyDaysAgo, flow: .medium),
            CycleDay(date: sixtyDaysAgo, flow: .medium)
        ]
        
        for day in days {
            await sut.addOrUpdateDay(day)
        }
        
        // When
        let prediction = await sut.predictNextPeriod()
        
        // Then
        XCTAssertNotNil(prediction)
        if let prediction = prediction {
            let daysUntilPrediction = calendar.dateComponents([.day], from: today, to: prediction).day
            XCTAssertEqual(daysUntilPrediction, 30)
        }
    }
    
    func testPredictNextPeriodWithInsufficientData() async {
        // Given
        let day = CycleDay(date: Date(), flow: .medium)
        await sut.addOrUpdateDay(day)
        
        // When
        let prediction = await sut.predictNextPeriod()
        
        // Then
        XCTAssertNil(prediction)
    }
} 