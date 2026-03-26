import Foundation
import UserNotifications
import Combine

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted.")
            } else if let error = error {
                print("Notification permissions error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDeadlineNotification(for deadline: PersistedDeadline) {
        guard deadline.isNotificationActive ?? true else { return }
        
        let content = UNMutableNotificationContent()
        
        let isUrgent = (deadline.weight ?? 0.0) >= 30 && deadline.daysRemaining <= 3
        
        content.title = isUrgent ? "🚨 CRITICAL DEADLINE: \(deadline.title)" : "Upcoming Deadline: \(deadline.title)"
        content.body = isUrgent 
            ? "Urgent: Your \(deadline.moduleName ?? "module") exam represents \(Int(deadline.weight ?? 0.0))% of your grade. Focus required."
            : "Your \(deadline.moduleName ?? "module") exam (\(Int(deadline.weight ?? 0.0))%) is approaching in 24 hours."
        
        content.sound = isUrgent ? .defaultCritical : .default
        
        // Trigger 24 hours before the deadline
        let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: deadline.date) ?? deadline.date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: deadline.id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(for deadlineId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [deadlineId])
    }
}
