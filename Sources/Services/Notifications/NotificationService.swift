import Foundation
import UserNotifications
import os

/// Manages all local notifications for SafeFlow.
///
/// Responsibilities:
/// - Request notification permission (called once after onboarding)
/// - Schedule a supply reminder 2 days before the predicted period window opens
/// - Cancel the pending reminder when the period is logged early
///
/// All scheduling is idempotent — calling `scheduleSupplyReminder` replaces any
/// existing reminder so it is safe to call whenever cycle data changes.
@MainActor
final class NotificationService: ObservableObject {

    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.thevgergroup.safeflow", category: "NotificationService")

    private enum NotificationID {
        static let supplyReminder = "safeflow.supplyReminder"
    }

    private init() {}

    // MARK: - Permission

    /// Requests notification permission. Safe to call multiple times — no-ops if already granted/denied.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification authorization granted: \(granted)")
            await refreshAuthorizationStatus()
        } catch {
            logger.error("Notification authorization error: \(error.localizedDescription)")
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Supply Reminder

    /// Schedules a single "check your supplies" notification 2 days before `periodEarliest`.
    /// Replaces any previously scheduled reminder.
    func scheduleSupplyReminder(periodEarliest: Date) async {
        await cancelSupplyReminder()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            logger.info("Notifications not authorized — skipping supply reminder")
            return
        }

        let calendar = Calendar.current
        guard let reminderDate = calendar.date(byAdding: .day, value: -2, to: periodEarliest),
              reminderDate > Date() else {
            logger.info("Reminder date is in the past — skipping")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Period coming up"
        content.body = "Your period window opens in about 2 days. Good time to check your supplies."
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        // Fire at 9 AM on the reminder day
        var fireComponents = DateComponents()
        fireComponents.year   = components.year
        fireComponents.month  = components.month
        fireComponents.day    = components.day
        fireComponents.hour   = 9
        fireComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.supplyReminder,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logger.info("Supply reminder scheduled for \(reminderDate)")
        } catch {
            logger.error("Failed to schedule supply reminder: \(error.localizedDescription)")
        }
    }

    /// Cancels the pending supply reminder — call when the period is logged early.
    func cancelSupplyReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.supplyReminder])
        logger.info("Supply reminder cancelled")
    }
}
