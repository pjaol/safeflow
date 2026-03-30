import Foundation

/// Initial cycle parameters collected during onboarding.
///
/// Stored separately from `CycleDay` records so they never pollute period
/// detection. The prediction engine falls back to these values when logged
/// data is insufficient.
struct CycleSeedData: Codable, Equatable {
    /// The date the user's most recent period began (day 1).
    let lastPeriodStartDate: Date
    /// Typical period duration in days (3–7).
    let typicalPeriodLength: Int
    /// Typical full cycle length in days (first day of period to first day of next period).
    let typicalCycleLength: Int
}
