import Foundation
import EventKit

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var availableCalendars: [EKCalendar] = []
    @Published var hasCalendarAccess = false
    
    func requestCalendarAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    self.hasCalendarAccess = granted
                    if granted {
                        self.loadAvailableCalendars()
                    } else {
                        print("❌ Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    self.hasCalendarAccess = granted
                    if granted {
                        self.loadAvailableCalendars()
                    } else {
                        print("❌ Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    private func loadAvailableCalendars() {
        let allCalendars = eventStore.calendars(for: .event)
        
        // Filter to calendars that can be modified
        availableCalendars = allCalendars.filter { calendar in
            return calendar.allowsContentModifications && 
                   !calendar.isImmutable && 
                   (calendar.source.sourceType == .local || 
                    calendar.source.sourceType == .calDAV || 
                    calendar.source.sourceType == .exchange ||
                    calendar.source.sourceType == .mobileMe)
        }
        
        // If no calendars found, try a less restrictive filter
        if availableCalendars.isEmpty {
            availableCalendars = allCalendars.filter { calendar in
                return calendar.allowsContentModifications
            }
        }
    }
    
    func getDefaultCalendar() -> EKCalendar? {
        return eventStore.defaultCalendarForNewEvents
    }

    // Helper method to add a single CalendarEvent (from AIConfiguration.swift)
    func addEventToCalendar(event: CalendarEvent, timezone: TimeZone, selectedCalendar: EKCalendar? = nil) async throws {
        let targetCalendar = selectedCalendar ?? eventStore.defaultCalendarForNewEvents

        guard let calendar = targetCalendar else {
            throw NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No target calendar available"])
        }

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.notes = event.description
        ekEvent.calendar = calendar
        ekEvent.timeZone = timezone

        // Parse start date with multiple formats
        print("🔍 Attempting to parse start date: \(event.startDate)")

        if let startDate = parseFlexibleDate(event.startDate, timezone: timezone) {
            ekEvent.startDate = startDate
            print("✅ Parsed start date: \(startDate)")
        } else {
            print("❌ Failed to parse start date: \(event.startDate)")
            throw NSError(domain: "CalendarService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid start date format: \(event.startDate)"])
        }

        // Parse end date with multiple formats
        if let endDateString = event.endDate {
            if let endDate = parseFlexibleDate(endDateString, timezone: timezone) {
                ekEvent.endDate = endDate
                print("✅ Parsed end date: \(endDate)")
            } else {
                print("⚠️ Failed to parse end date, using 1 hour after start")
                ekEvent.endDate = ekEvent.startDate.addingTimeInterval(3600)
            }
        } else {
            // Default to 1 hour after start if no end date
            ekEvent.endDate = ekEvent.startDate.addingTimeInterval(3600)
        }

        if let location = event.location {
            ekEvent.location = location
        }

        ekEvent.isAllDay = event.isAllDay

        // Handle recurrence
        if event.isRecurring, let recurrencePattern = event.recurrencePattern {
            if let ekRecurrenceRule = parseRRULE(recurrencePattern) {
                ekEvent.addRecurrenceRule(ekRecurrenceRule)
            }
        }

        // Save the event
        let span: EKSpan = event.isRecurring ? .futureEvents : .thisEvent
        try eventStore.save(ekEvent, span: span)
    }

    // Flexible date parser that tries multiple formats
    private func parseFlexibleDate(_ dateString: String, timezone: TimeZone) -> Date? {
        // Try ISO8601 first (with various options)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = timezone

        // Try with fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try with just date and time
        isoFormatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try common date formats
        let formatters: [(String, TimeZone?)] = [
            ("yyyy-MM-dd'T'HH:mm:ss.SSSZ", nil),      // ISO8601 with milliseconds and timezone
            ("yyyy-MM-dd'T'HH:mm:ssZ", nil),          // ISO8601 with timezone
            ("yyyy-MM-dd'T'HH:mm:ss", timezone),      // ISO8601 without timezone
            ("yyyy-MM-dd HH:mm:ss", timezone),        // Space separator
            ("yyyy-MM-dd'T'HH:mm", timezone),         // Without seconds
            ("yyyy-MM-dd", timezone),                 // Date only
        ]

        for (format, tz) in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = tz ?? TimeZone(identifier: "UTC")
            formatter.locale = Locale(identifier: "en_US_POSIX")

            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    func addEventsToCalendar(icsContent: String, selectedCalendar: EKCalendar? = nil, userTimezone: TimeZone = TimeZone.current, completion: @escaping (Bool, Error?) -> Void) {
        let events = parseICSContent(icsContent, userTimezone: userTimezone)
        let targetCalendar = selectedCalendar ?? eventStore.defaultCalendarForNewEvents
        
        guard let calendar = targetCalendar else {
            completion(false, NSError(domain: "CalendarService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No target calendar available"]))
            return
        }
        
        var successCount = 0
        var errors: [Error] = []
        
        for eventData in events {
            let event = EKEvent(eventStore: eventStore)
            event.title = eventData.title
            event.notes = eventData.description
            event.startDate = eventData.startDate
            event.endDate = eventData.endDate
            event.calendar = calendar
            event.timeZone = eventData.timeZone ?? userTimezone
            
            if let location = eventData.location {
                event.location = location
            }
            
            // Apply recurrence rule if present
            if let rruleString = eventData.recurrenceRule {
                if let ekRecurrenceRule = parseRRULE(rruleString) {
                    event.addRecurrenceRule(ekRecurrenceRule)
                } else {
                    print("❌ Failed to parse recurrence rule: \(rruleString)")
                }
            }
            
            // Apply additional ICS properties
            if let url = eventData.url {
                event.url = url
            }
            
            // Map ICS status to EKEvent availability
            if let status = eventData.status?.uppercased() {
                switch status {
                case "TENTATIVE":
                    event.availability = .tentative
                case "CONFIRMED":
                    event.availability = .busy
                case "CANCELLED":
                    event.availability = .free
                default:
                    event.availability = .busy
                }
            }
            
            // Add additional info to notes
            var additionalNotes: [String] = []
            
            if let priority = eventData.priority {
                additionalNotes.append("Priority: \(priority)")
            }
            
            if !eventData.categories.isEmpty {
                let categoriesText = eventData.categories.joined(separator: ", ")
                additionalNotes.append("Categories: \(categoriesText)")
            }
            
            if let organizer = eventData.organizer {
                additionalNotes.append("Organizer: \(organizer)")
            }
            
            if !eventData.attendees.isEmpty {
                let attendeesList = eventData.attendees.joined(separator: ", ")
                additionalNotes.append("Attendees: \(attendeesList)")
            }
            
            if !additionalNotes.isEmpty {
                let additionalText = additionalNotes.joined(separator: "\n")
                if let existingNotes = event.notes {
                    event.notes = "\(existingNotes)\n\n\(additionalText)"
                } else {
                    event.notes = additionalText
                }
            }
            
            do {
                let span: EKSpan = (event.recurrenceRules?.isEmpty == false) ? .futureEvents : .thisEvent
                try eventStore.save(event, span: span)
                successCount += 1
            } catch {
                errors.append(error)
                print("❌ Failed to add event: \(event.title ?? "Unknown") - \(error.localizedDescription)")
            }
        }
        
        completion(successCount > 0, errors.first)
    }
    
    private func parseICSContent(_ icsContent: String, userTimezone: TimeZone = TimeZone.current) -> [EventData] {
        var events: [EventData] = []
        let rawLines = icsContent.components(separatedBy: .newlines)
        
        // Handle RFC 5545 line folding
        var unfoldedLines: [String] = []
        var currentLine = ""
        
        for line in rawLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                continue
            }
            
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                currentLine += line.dropFirst()
            } else {
                if !currentLine.isEmpty {
                    unfoldedLines.append(currentLine)
                }
                currentLine = line
            }
        }
        
        if !currentLine.isEmpty {
            unfoldedLines.append(currentLine)
        }
        
        var currentEvent: EventData?
        var currentTimezone: TimeZone?
        
        for line in unfoldedLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("BEGIN:VEVENT") {
                currentEvent = EventData()
            } else if trimmedLine.hasPrefix("END:VEVENT") {
                if let event = currentEvent {
                    events.append(event)
                }
                currentEvent = nil
            } else if trimmedLine.hasPrefix("BEGIN:VTIMEZONE") || trimmedLine.contains("TZID:") {
                if let tzidRange = trimmedLine.range(of: "TZID:") {
                    let tzid = String(trimmedLine[tzidRange.upperBound...])
                    currentTimezone = TimeZone(identifier: tzid)
                }
            } else if let event = currentEvent {
                parseEventLine(trimmedLine, event: event, currentTimezone: currentTimezone, userTimezone: userTimezone)
            }
        }
        
        return events
    }
    
    private func parseEventLine(_ line: String, event: EventData, currentTimezone: TimeZone?, userTimezone: TimeZone) {
        if line.hasPrefix("SUMMARY:") {
            event.title = String(line.dropFirst(8))
        } else if line.hasPrefix("DESCRIPTION:") {
            event.description = String(line.dropFirst(12))
        } else if line.hasPrefix("LOCATION:") {
            event.location = String(line.dropFirst(9))
        } else if line.hasPrefix("DTSTART") {
            let dateString = extractDateFromICSLine(line, prefix: "DTSTART")
            let timezone = extractTimezoneFromICSLine(line) ?? currentTimezone ?? userTimezone
            event.startDate = parseICSDate(dateString, timezone: timezone) ?? Date()
            event.timeZone = userTimezone
        } else if line.hasPrefix("DTEND") {
            let dateString = extractDateFromICSLine(line, prefix: "DTEND")
            let timezone = extractTimezoneFromICSLine(line) ?? currentTimezone ?? userTimezone
            event.endDate = parseICSDate(dateString, timezone: timezone) ?? Date().addingTimeInterval(3600)
        } else if line.hasPrefix("RRULE:") {
            event.recurrenceRule = String(line.dropFirst(6))
        } else if line.hasPrefix("UID:") {
            event.uid = String(line.dropFirst(4))
        } else if line.hasPrefix("URL:") {
            event.url = URL(string: String(line.dropFirst(4)))
        } else if line.hasPrefix("ORGANIZER") {
            if let colonIndex = line.firstIndex(of: ":") {
                event.organizer = String(line[line.index(after: colonIndex)...])
            }
        } else if line.hasPrefix("ATTENDEE") {
            if let colonIndex = line.firstIndex(of: ":") {
                let attendee = String(line[line.index(after: colonIndex)...])
                event.attendees.append(attendee)
            }
        } else if line.hasPrefix("CATEGORIES:") {
            let categoryString = String(line.dropFirst(11))
            event.categories = categoryString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        } else if line.hasPrefix("PRIORITY:") {
            event.priority = Int(String(line.dropFirst(9)))
        } else if line.hasPrefix("STATUS:") {
            event.status = String(line.dropFirst(7))
        } else if line.hasPrefix("TRANSP:") {
            event.transparency = String(line.dropFirst(7))
        } else if line.hasPrefix("CLASS:") {
            event.classification = String(line.dropFirst(6))
        }
    }
    
    private func extractDateFromICSLine(_ line: String, prefix: String) -> String {
        if let colonRange = line.range(of: ":", options: .backwards) {
            return String(line[colonRange.upperBound...])
        }
        return String(line.dropFirst(prefix.count + 1))
    }
    
    private func extractTimezoneFromICSLine(_ line: String) -> TimeZone? {
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
        
        // Handle UTC dates (ending with Z)
        if cleanDateString.hasSuffix("Z") {
            let formatters: [DateFormatter] = [
                createICSFormatter("yyyyMMdd'T'HHmmss'Z'", timeZone: TimeZone(identifier: "UTC")),
                createICSFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'", timeZone: TimeZone(identifier: "UTC"))
            ]
            
            for formatter in formatters {
                if let utcDate = formatter.date(from: cleanDateString) {
                    return utcDate
                }
            }
        }
        
        // Handle local time dates with timezone
        let formatters: [DateFormatter] = [
            createICSFormatter("yyyyMMdd'T'HHmmss", timeZone: timezone),
            createICSFormatter("yyyyMMdd", timeZone: timezone),
            createICSFormatter("yyyy-MM-dd'T'HH:mm:ss", timeZone: timezone),
            createICSFormatter("yyyy-MM-dd HH:mm:ss", timeZone: timezone)
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: cleanDateString) {
                return date
            }
        }
        
        // Last resort: ISO8601DateFormatter
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: cleanDateString) {
            return date
        }
        
        print("❌ Failed to parse date: '\(cleanDateString)'")
        return nil
    }
    
    private func createICSFormatter(_ format: String, timeZone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone ?? TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    private func parseRRULE(_ rruleString: String) -> EKRecurrenceRule? {
        let components = rruleString.components(separatedBy: ";")
        var frequency: EKRecurrenceFrequency?
        var interval = 1
        var daysOfWeek: [EKRecurrenceDayOfWeek] = []
        var end: EKRecurrenceEnd?
        
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
            if trimmed.hasPrefix("FREQ=") {
                let freqValue = String(trimmed.dropFirst(5))
                switch freqValue {
                case "DAILY":
                    frequency = .daily
                case "WEEKLY":
                    frequency = .weekly
                case "MONTHLY":
                    frequency = .monthly
                case "YEARLY":
                    frequency = .yearly
                default:
                    print("❌ Unsupported frequency: \(freqValue)")
                    return nil
                }
            } else if trimmed.hasPrefix("INTERVAL=") {
                if let intervalValue = Int(String(trimmed.dropFirst(9))) {
                    interval = intervalValue
                }
            } else if trimmed.hasPrefix("BYDAY=") {
                let dayString = String(trimmed.dropFirst(6))
                daysOfWeek = parseByDay(dayString)
            } else if trimmed.hasPrefix("COUNT=") {
                if let count = Int(String(trimmed.dropFirst(6))) {
                    end = EKRecurrenceEnd(occurrenceCount: count)
                }
            } else if trimmed.hasPrefix("UNTIL=") {
                let untilString = String(trimmed.dropFirst(6))
                if let untilDate = parseICSDate(untilString, timezone: nil) {
                    end = EKRecurrenceEnd(end: untilDate)
                }
            }
        }
        
        guard let freq = frequency else {
            print("❌ No valid frequency found in RRULE: \(rruleString)")
            return nil
        }
        
        return EKRecurrenceRule(
            recurrenceWith: freq,
            interval: interval,
            daysOfTheWeek: daysOfWeek.isEmpty ? nil : daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
    }
    
    private func parseByDay(_ byDayString: String) -> [EKRecurrenceDayOfWeek] {
        let dayMapping: [String: EKWeekday] = [
            "MO": .monday, "TU": .tuesday, "WE": .wednesday, "TH": .thursday,
            "FR": .friday, "SA": .saturday, "SU": .sunday
        ]
        
        let days = byDayString.components(separatedBy: ",")
        var result: [EKRecurrenceDayOfWeek] = []
        
        for day in days {
            let trimmed = day.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
            if trimmed.count > 2 {
                let dayCode = String(trimmed.suffix(2))
                let positionStr = String(trimmed.dropLast(2))
                
                if let weekday = dayMapping[dayCode], let weekNumber = Int(positionStr) {
                    let dayOfWeek = EKRecurrenceDayOfWeek(dayOfTheWeek: weekday, weekNumber: weekNumber)
                    result.append(dayOfWeek)
                }
            } else {
                if let weekday = dayMapping[trimmed] {
                    let dayOfWeek = EKRecurrenceDayOfWeek(weekday)
                    result.append(dayOfWeek)
                }
            }
        }
        
        return result
    }
}

class EventData {
    var title: String = ""
    var description: String?
    var location: String?
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(3600)
    var timeZone: TimeZone?
    var recurrenceRule: String?
    var uid: String?
    var url: URL?
    var organizer: String?
    var attendees: [String] = []
    var categories: [String] = []
    var priority: Int?
    var status: String?
    var transparency: String?
    var classification: String?
    var alarm: String?
}