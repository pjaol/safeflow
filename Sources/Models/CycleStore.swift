import Foundation

class CycleStore: ObservableObject {
    @Published private var days: [CycleDay] = []
    let securityService: SecurityService
    
    init(securityService: SecurityService = SecurityService()) {
        self.securityService = securityService
        loadData()
    }
    
    // ... existing code ...
} 