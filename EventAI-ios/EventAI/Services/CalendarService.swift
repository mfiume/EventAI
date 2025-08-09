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
    
    func addEventsToCalendar(icsContent: String, selectedCalendar: EKCalendar? = nil, userTimezone: TimeZone = TimeZone.current, completion: @escaping (Bool, Error?) -> Void) {
        // Parse ICS content and create EKEvents with user's timezone
        let events = parseICSContent(icsContent, userTimezone: userTimezone)
        
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
            
            // Set timezone for the event if available
            if let timeZone = eventData.timeZone {
                event.timeZone = timeZone
                print("🌍 Setting event timezone: \(timeZone.identifier)")
            } else {
                // Fallback to user's current timezone if no timezone specified
                event.timeZone = TimeZone.current
                print("🌍 Using current timezone: \(TimeZone.current.identifier)")
            }
            
            if let location = eventData.location {
                event.location = location
            }
            
            print("📅 Adding event '\(eventData.title)' at \(eventData.startDate) (TZ: \(event.timeZone?.identifier ?? "nil"))")
            
            do {
                try eventStore.save(event, span: .thisEvent)
                successCount += 1
                print("✅ Added event: \(event.title ?? "Unknown") successfully")
            } catch {
                errors.append(error)
                print("❌ Failed to add event: \(event.title ?? "Unknown") - \(error.localizedDescription)")
            }
        }
        
        completion(successCount > 0, errors.first)
    }
    
    private func parseICSContent(_ icsContent: String, userTimezone: TimeZone = TimeZone.current) -> [EventData] {
        var events: [EventData] = []
        let lines = icsContent.components(separatedBy: .newlines)
        
        var currentEvent: EventData?
        var currentTimezone: TimeZone?
        
        print("🔍 DEBUG: Parsing ICS content:")
        print("📄 ICS Content (\(icsContent.count) chars):")
        print(icsContent)
        print(String(repeating: "=", count: 80))
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("BEGIN:VEVENT") {
                currentEvent = EventData()
                print("🆕 Starting new event")
            } else if trimmedLine.hasPrefix("END:VEVENT") {
                if let event = currentEvent {
                    events.append(event)
                    print("✅ Added event: '\(event.title)' at \(event.startDate)")
                }
                currentEvent = nil
            } else if trimmedLine.hasPrefix("BEGIN:VTIMEZONE") || trimmedLine.contains("TZID:") {
                // Extract timezone information
                if let tzidRange = trimmedLine.range(of: "TZID:") {
                    let tzid = String(trimmedLine[tzidRange.upperBound...])
                    currentTimezone = TimeZone(identifier: tzid)
                    print("🌍 Found timezone: \(tzid) -> \(currentTimezone?.identifier ?? "nil")")
                }
            } else if let event = currentEvent {
                if trimmedLine.hasPrefix("SUMMARY:") {
                    event.title = String(trimmedLine.dropFirst(8))
                    print("📝 Title: \(event.title)")
                } else if trimmedLine.hasPrefix("DESCRIPTION:") {
                    event.description = String(trimmedLine.dropFirst(12))
                    print("📄 Description: \(event.description ?? "")")
                } else if trimmedLine.hasPrefix("LOCATION:") {
                    event.location = String(trimmedLine.dropFirst(9))
                    print("📍 Location: \(event.location ?? "")")
                } else if trimmedLine.hasPrefix("DTSTART") {
                    let dateString = extractDateFromICSLine(trimmedLine, prefix: "DTSTART")
                    let timezone = extractTimezoneFromICSLine(trimmedLine) ?? currentTimezone ?? userTimezone
                    
                    event.startDate = parseICSDate(dateString, timezone: timezone) ?? Date()
                    event.timeZone = userTimezone // Always set to user's timezone for display
                    print("⏰ Start: \(dateString) -> \(event.startDate) (Event TZ: \(userTimezone.identifier))")
                } else if trimmedLine.hasPrefix("DTEND") {
                    let dateString = extractDateFromICSLine(trimmedLine, prefix: "DTEND")
                    let timezone = extractTimezoneFromICSLine(trimmedLine) ?? currentTimezone ?? userTimezone
                    
                    event.endDate = parseICSDate(dateString, timezone: timezone) ?? Date().addingTimeInterval(3600)
                    print("⏰ End: \(dateString) -> \(event.endDate) (Event TZ: \(userTimezone.identifier))")
                }
            }
        }
        
        print("🎯 Parsed \(events.count) events total")
        return events
    }
    
    private func extractDateFromICSLine(_ line: String, prefix: String) -> String {
        // Handle both DTSTART:20241010T140000Z and DTSTART;TZID=America/New_York:20241010T140000
        if let colonRange = line.range(of: ":", options: .backwards) {
            return String(line[colonRange.upperBound...])
        }
        return String(line.dropFirst(prefix.count + 1))
    }
    
    private func extractTimezoneFromICSLine(_ line: String) -> TimeZone? {
        // Look for TZID parameter: DTSTART;TZID=America/New_York:20241010T140000
        if let tzidRange = line.range(of: "TZID=") {
            let afterTzid = line[tzidRange.upperBound...]
            if let colonRange = afterTzid.range(of: ":") {
                let tzidString = String(afterTzid[..<colonRange.lowerBound])
                return TimeZone(identifier: tzidString)
            }
        }
        return nil
    }
    
    private func parseICSDate(_ dateString: String, timezone: TimeZone?) -> Date? {
        let cleanDateString = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle UTC dates (ending with Z) specially
        if cleanDateString.hasSuffix("Z") {
            let formatters: [(DateFormatter, String)] = [
                (createICSFormatter("yyyyMMdd'T'HHmmss'Z'", timeZone: TimeZone(identifier: "UTC")), "UTC Z"),
                (createICSFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'", timeZone: TimeZone(identifier: "UTC")), "ISO UTC")
            ]
            
            for (formatter, description) in formatters {
                if let utcDate = formatter.date(from: cleanDateString) {
                    print("✅ Parsed UTC date '\(cleanDateString)' using \(description) -> \(utcDate)")
                    // Return UTC date as-is - EKEvent will handle timezone display
                    return utcDate
                }
            }
        }
        
        // Handle local time dates with timezone
        let formatters: [(DateFormatter, String)] = [
            // Local time with timezone: 20241010T140000
            (createICSFormatter("yyyyMMdd'T'HHmmss", timeZone: timezone), "Local with TZ"),
            // Date only: 20241010
            (createICSFormatter("yyyyMMdd", timeZone: timezone), "Date only"),
            // ISO 8601 variants
            (createICSFormatter("yyyy-MM-dd'T'HH:mm:ss", timeZone: timezone), "ISO Local"),
            (createICSFormatter("yyyy-MM-dd HH:mm:ss", timeZone: timezone), "ISO Space"),
        ]
        
        for (formatter, description) in formatters {
            if let date = formatter.date(from: cleanDateString) {
                print("✅ Parsed local date '\(cleanDateString)' using \(description) -> \(date) in timezone \(timezone?.identifier ?? "current")")
                return date
            }
        }
        
        // Last resort: ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: cleanDateString) {
            print("✅ Parsed '\(cleanDateString)' using ISO8601DateFormatter -> \(date)")
            return date
        }
        
        print("❌ Failed to parse date: '\(cleanDateString)' with timezone: \(timezone?.identifier ?? "nil")")
        return nil
    }
    
    private func createICSFormatter(_ format: String, timeZone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone ?? TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
}

class EventData {
    var title: String = ""
    var description: String?
    var location: String?
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(3600)
    var timeZone: TimeZone?
}