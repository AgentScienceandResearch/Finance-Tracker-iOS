import Foundation
import UserNotifications

/// Schedules a local notification the day before each active recurring bill is due,
/// so the user never misses a payment. Bill reminders are the only local
/// notifications this app uses, so cancelling is a clean sweep.
@MainActor
final class BillReminderManager: ObservableObject {
    static let shared = BillReminderManager()

    @Published var isEnabled: Bool

    private let enabledKey = "billReminders.enabled"
    private let idPrefix = "bill.reminder."
    private let leadDays = 1   // remind this many days before the due date
    private let hour = 9       // at 9:00 AM local

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Turn on: ask permission, then schedule reminders for the given bills.
    func enable(with bills: [RecurringExpense]) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            setEnabled(false)
            return
        }
        setEnabled(true)
        schedule(for: bills)
    }

    func disable() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        setEnabled(false)
    }

    /// Re-sync scheduled reminders to the current bills. Safe to call on every app
    /// open and whenever bills change; a no-op when reminders are off.
    func reschedule(with bills: [RecurringExpense]) {
        guard isEnabled else { return }
        schedule(for: bills)
    }

    // MARK: - Private

    private func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: enabledKey)
    }

    private func schedule(for bills: [RecurringExpense]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let now = Date()

        for bill in bills where bill.isActive {
            guard let remindDay = calendar.date(byAdding: .day, value: -leadDays, to: bill.nextDueDate) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: remindDay)
            comps.hour = hour
            comps.minute = 0
            guard let fireDate = calendar.date(from: comps), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming bill"
            let amount = CurrencyFormatting.shared.string(for: bill.amount)
            content.body = leadDays == 1
                ? "\(bill.title) — \(amount) is due tomorrow."
                : "\(bill.title) — \(amount) is due in \(leadDays) days."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: idPrefix + bill.id.uuidString,
                                             content: content,
                                             trigger: trigger))
        }
    }
}
