import Foundation
import Observation

// MARK: - Streak-Tracking für Truppen-Imports

@MainActor
@Observable
final class TroopUpdateStreakStore {

    static let shared = TroopUpdateStreakStore()

    // MARK: - Observable Properties

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastUpdateDate: Date? = nil
    var totalUpdateCount: Int = 0

    // MARK: - Keys

    @ObservationIgnored private let streakKey = "troopStreakCount"
    @ObservationIgnored private let longestKey = "troopStreakLongest"
    @ObservationIgnored private let lastDateKey = "troopStreakLastDate"
    @ObservationIgnored private let totalKey = "troopStreakTotalCount"

    // MARK: - Init

    private init() {
        loadFromDefaults()
    }

    // MARK: - Record Update

    /// Nach jedem erfolgreichen Import aufrufen.
    /// Aktualisiert Streak (Kalendertag-basiert), Rekord und Zähler.
    func recordUpdate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let last = lastUpdateDate {
            let lastDay = calendar.startOfDay(for: last)
            let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if diff == 0 {
                // Gleicher Kalendertag → Streak unverändert
            } else if diff == 1 {
                // Nächster Tag → Streak +1
                currentStreak += 1
            } else {
                // Lücke > 1 Tag → Reset
                currentStreak = 1
            }
        } else {
            // Allererster Import
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        totalUpdateCount += 1
        lastUpdateDate = Date()
        saveToDefaults()
    }

    // MARK: - Computed State

    /// Wurde heute (gleicher Kalendertag) bereits importiert?
    var hasUpdatedToday: Bool {
        guard let last = lastUpdateDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// Stunden seit letztem Import (nil wenn nie importiert)
    var hoursSinceUpdate: Double? {
        guard let last = lastUpdateDate else { return nil }
        return Date().timeIntervalSince(last) / 3600
    }

    /// Daten veraltet (>24h seit letztem Import)
    var isStale: Bool {
        guard let hours = hoursSinceUpdate else { return false }
        return hours > 24
    }

    /// Streak in Gefahr: Gestern importiert, heute noch nicht
    var streakAtRisk: Bool {
        guard currentStreak > 0, !hasUpdatedToday else { return false }
        guard let last = lastUpdateDate else { return false }
        return Calendar.current.isDateInYesterday(last)
    }

    // MARK: - Relative Time

    /// Gibt "jetzt", "vor 5min", "vor 3h", "vor 2T" zurück
    func relativeTimeString() -> String? {
        guard let last = lastUpdateDate else { return nil }
        let seconds = Int(Date().timeIntervalSince(last))
        if seconds < 60 { return "jetzt" }
        if seconds < 3600 { return "vor \(seconds / 60)min" }
        if seconds < 86400 { return "vor \(seconds / 3600)h" }
        return "vor \(seconds / 86400)T"
    }

    // MARK: - Logout

    func handleLogout() {
        currentStreak = 0
        longestStreak = 0
        lastUpdateDate = nil
        totalUpdateCount = 0
        UserDefaults.standard.removeObject(forKey: streakKey)
        UserDefaults.standard.removeObject(forKey: longestKey)
        UserDefaults.standard.removeObject(forKey: lastDateKey)
        UserDefaults.standard.removeObject(forKey: totalKey)
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard
        currentStreak = defaults.integer(forKey: streakKey)
        longestStreak = defaults.integer(forKey: longestKey)
        totalUpdateCount = defaults.integer(forKey: totalKey)

        if let interval = defaults.object(forKey: lastDateKey) as? TimeInterval {
            lastUpdateDate = Date(timeIntervalSince1970: interval)

            // Streak validieren: Falls letzter Import > 1 Tag her, Reset
            if let last = lastUpdateDate {
                let calendar = Calendar.current
                let lastDay = calendar.startOfDay(for: last)
                let today = calendar.startOfDay(for: Date())
                let diff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
                if diff > 1 {
                    currentStreak = 0
                    saveToDefaults()
                }
            }
        }
    }

    private func saveToDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(currentStreak, forKey: streakKey)
        defaults.set(longestStreak, forKey: longestKey)
        defaults.set(totalUpdateCount, forKey: totalKey)
        if let date = lastUpdateDate {
            defaults.set(date.timeIntervalSince1970, forKey: lastDateKey)
        }
    }
}
