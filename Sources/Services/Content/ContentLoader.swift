import Foundation
import os

/// Loads and caches all content from bundled JSON files in Resources/Content/.
/// All access is synchronous and in-memory — files are small (~50 KB total).
enum ContentLoader {

    private static let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "ContentLoader")

    // MARK: - Public interface

    static let tips:      [ContentTip]      = load("tips")
    static let nudges:    [ContentNudge]    = load("nudges")
    static let signals:   [ContentSignal]   = load("signals")
    static let resources: [ContentResource] = load("resources")

    // MARK: - Private loader

    private static func load<T: Decodable>(_ name: String) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json",
                                        subdirectory: "Content") else {
            logger.error("ContentLoader: missing bundle resource Content/\(name).json")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([T].self, from: data)
        } catch {
            logger.error("ContentLoader: failed to decode \(name).json — \(error.localizedDescription)")
            return []
        }
    }
}
