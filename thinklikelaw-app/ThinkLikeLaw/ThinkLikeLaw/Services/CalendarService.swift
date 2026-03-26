import Foundation
import EventKit

class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            print("CalendarService: Error requesting access: \(error)")
            return false
        }
    }
    
    func addDeadlineEvent(for deadline: PersistedDeadline) async throws {
        let granted = await requestAccess()
        guard granted else {
            throw NSError(domain: "CalendarService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Calendar access not granted"])
        }
        
        // Check if event already exists (by title and date) to prevent duplicates in calendar
        let predicate = eventStore.predicateForEvents(withStart: deadline.date, end: deadline.date.addingTimeInterval(3600), calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)
        
        if existingEvents.contains(where: { $0.title == "EXAM DEADLINE: \(deadline.title)" }) {
            print("CalendarService: Event already exists for \(deadline.title)")
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "EXAM DEADLINE: \(deadline.title)"
        event.startDate = deadline.date
        event.endDate = deadline.date.addingTimeInterval(3600) // 1 hour duration
        event.notes = "Module: \(deadline.moduleName ?? "N/A")\nWeight: \(Int(deadline.weight ?? 0.0))%\nStrategic reminder from ThinkLikeLaw."
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alarm 1 day before
        let alarm = EKAlarm(relativeOffset: -86400) // 24 hours
        event.addAlarm(alarm)
        
        try eventStore.save(event, span: .thisEvent)
        print("CalendarService: Successfully added event for \(deadline.title)")
    }
}
