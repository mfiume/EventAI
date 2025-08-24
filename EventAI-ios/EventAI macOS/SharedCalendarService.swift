import Foundation
import EventKit

// MARK: - Shared Calendar Service for iOS and macOS
public class SharedCalendarService: ObservableObject {
    public static let shared = SharedCalendarService()
    
    private let eventStore = EKEventStore()
    @Published public var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    public init() {
        updateAuthorizationStatus()
    }
    
    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    // MARK: - Authorization
    public func requestAccess() async -> Bool {
        do {
            // Use the modern API for macOS 14+
            if #available(macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    updateAuthorizationStatus()
                }
                return granted
            } else {
                // Fallback to older API
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    updateAuthorizationStatus()
                }
                return granted
            }
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }
    
    // MARK: - Event Creation
    public func addEventsToCalendar(_ events: [SharedAPIService.CalendarEvent]) async -> (success: Int, failed: Int, errors: [String]) {
        var successCount = 0
        var failedCount = 0
        var errors: [String] = []
        
        // Request access if needed
        if #available(macOS 14.0, *) {
            if authorizationStatus != .fullAccess {
                let granted = await requestAccess()
                if !granted {
                    return (0, events.count, ["Calendar access denied"])
                }
            }
        } else {
            if authorizationStatus != .authorized {
                let granted = await requestAccess()
                if !granted {
                    return (0, events.count, ["Calendar access denied"])
                }
            }
        }
        
        for event in events {
            do {
                let ekEvent = EKEvent(eventStore: eventStore)
                
                // Basic event properties
                ekEvent.title = event.title
                ekEvent.notes = event.notes
                ekEvent.location = event.location
                
                // Date handling
                guard let startDate = event.formattedStartDate else {
                    errors.append("Invalid start date for event: \(event.title)")
                    failedCount += 1
                    continue
                }
                
                ekEvent.startDate = startDate
                
                if let endDate = event.formattedEndDate {
                    ekEvent.endDate = endDate
                } else {
                    // Default to 1 hour duration if no end date
                    ekEvent.endDate = startDate.addingTimeInterval(3600)
                }
                
                ekEvent.isAllDay = event.isAllDay
                
                // Recurrence handling
                if event.isRecurring, let pattern = event.recurrencePattern {
                    if let recurrenceRule = parseRecurrencePattern(pattern) {
                        ekEvent.addRecurrenceRule(recurrenceRule)
                    }
                }
                
                // Use default calendar
                ekEvent.calendar = eventStore.defaultCalendarForNewEvents
                
                // Save the event
                try eventStore.save(ekEvent, span: .thisEvent)
                successCount += 1
                
            } catch {
                errors.append("Failed to create event '\(event.title)': \(error.localizedDescription)")
                failedCount += 1
            }
        }
        
        return (successCount, failedCount, errors)
    }
    
    // MARK: - Helper Methods
    private func parseRecurrencePattern(_ pattern: String) -> EKRecurrenceRule? {
        // Basic recurrence pattern parsing
        let uppercased = pattern.uppercased()
        
        if uppercased.contains("DAILY") {
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        } else if uppercased.contains("WEEKLY") {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        } else if uppercased.contains("MONTHLY") {
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        } else if uppercased.contains("YEARLY") {
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
        
        return nil
    }
    
    // MARK: - Calendar Access Status
    public var hasCalendarAccess: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    public var canRequestAccess: Bool {
        return authorizationStatus == .notDetermined
    }
}