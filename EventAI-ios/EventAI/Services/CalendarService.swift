import Foundation
import EventKit

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var availableCalendars: [EKCalendar] = []
    @Published var hasCalendarAccess = false
    
    func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            // Use full access to ensure we can see all calendars like the user sees in Settings
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    self.hasCalendarAccess = granted
                    if granted {
                        print("Calendar full access granted")
                        self.loadAvailableCalendars()
                    } else {
                        print("Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    self.hasCalendarAccess = granted
                    if granted {
                        print("Calendar access granted")
                        self.loadAvailableCalendars()
                    } else {
                        print("Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    private func loadAvailableCalendars() {
        // Get all calendars first for debugging
        let allCalendars = eventStore.calendars(for: .event)
        print("🗓️ DEBUG: Found \(allCalendars.count) total calendars:")
        for calendar in allCalendars {
            print("  - \(calendar.title)")
            print("    Source: \(calendar.source.title)")
            print("    Source Type: \(calendar.source.sourceType.rawValue)")
            print("    Allows Modifications: \(calendar.allowsContentModifications)")
            print("    Is Immutable: \(calendar.isImmutable)")
            print("    Calendar Type: \(calendar.type.rawValue)")
            print("    ---")
        }
        
        // Filter to calendars that can be modified and are not subscribed/read-only
        availableCalendars = allCalendars.filter { calendar in
            // Include local calendars, CalDAV calendars, and Exchange calendars that allow modifications
            return calendar.allowsContentModifications && 
                   !calendar.isImmutable && 
                   (calendar.source.sourceType == .local || 
                    calendar.source.sourceType == .calDAV || 
                    calendar.source.sourceType == .exchange ||
                    calendar.source.sourceType == .mobileMe)
        }
        
        print("🗓️ Filtered to \(availableCalendars.count) writable calendars:")
        for calendar in availableCalendars {
            print("  ✅ \(calendar.title) (Source: \(calendar.source.title))")
        }
        
        // If no calendars found, try a less restrictive filter
        if availableCalendars.isEmpty {
            print("⚠️ No writable calendars found, trying less restrictive filter...")
            availableCalendars = allCalendars.filter { calendar in
                return calendar.allowsContentModifications
            }
            print("🗓️ Less restrictive filter found \(availableCalendars.count) calendars:")
            for calendar in availableCalendars {
                print("  📝 \(calendar.title) (Source: \(calendar.source.title))")
            }
        }
    }
    
    func getDefaultCalendar() -> EKCalendar? {
        return eventStore.defaultCalendarForNewEvents
    }
    
    func addEventsToCalendar(icsContent: String, selectedCalendar: EKCalendar? = nil, completion: @escaping (Bool, Error?) -> Void) {
        // Parse ICS content and create EKEvents
        let events = parseICSContent(icsContent)
        
        // Use selected calendar or default
        let targetCalendar = selectedCalendar ?? eventStore.defaultCalendarForNewEvents
        
        guard let calendar = targetCalendar else {
            completion(false, NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No target calendar available"]))
            return
        }
        
        print("📅 Adding \(events.count) events to calendar: \(calendar.title)")
        
        var successCount = 0
        var errors: [Error] = []
        
        for eventData in events {
            let event = EKEvent(eventStore: eventStore)
            event.title = eventData.title
            event.notes = eventData.description
            event.startDate = eventData.startDate
            event.endDate = eventData.endDate
            event.calendar = calendar
            
            if let location = eventData.location {
                event.location = location
            }
            
            do {
                try eventStore.save(event, span: .thisEvent)
                successCount += 1
                print("✅ Added event: \(event.title)")
            } catch {
                errors.append(error)
                print("❌ Failed to add event: \(event.title) - \(error.localizedDescription)")
            }
        }
        
        completion(successCount > 0, errors.first)
    }
    
    private func parseICSContent(_ icsContent: String) -> [EventData] {
        var events: [EventData] = []
        let lines = icsContent.components(separatedBy: .newlines)
        
        var currentEvent: EventData?
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("BEGIN:VEVENT") {
                currentEvent = EventData()
            } else if trimmedLine.hasPrefix("END:VEVENT") {
                if let event = currentEvent {
                    events.append(event)
                }
                currentEvent = nil
            } else if let event = currentEvent {
                if trimmedLine.hasPrefix("SUMMARY:") {
                    event.title = String(trimmedLine.dropFirst(8))
                } else if trimmedLine.hasPrefix("DESCRIPTION:") {
                    event.description = String(trimmedLine.dropFirst(12))
                } else if trimmedLine.hasPrefix("LOCATION:") {
                    event.location = String(trimmedLine.dropFirst(9))
                } else if trimmedLine.hasPrefix("DTSTART:") {
                    let dateString = String(trimmedLine.dropFirst(8))
                    event.startDate = dateFormatter.date(from: dateString) ?? Date()
                } else if trimmedLine.hasPrefix("DTEND:") {
                    let dateString = String(trimmedLine.dropFirst(6))
                    event.endDate = dateFormatter.date(from: dateString) ?? Date().addingTimeInterval(3600)
                }
            }
        }
        
        return events
    }
}

class EventData {
    var title: String = ""
    var description: String?
    var location: String?
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(3600)
}