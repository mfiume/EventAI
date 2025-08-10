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
            
            // Apply recurrence rule if present
            if let rruleString = eventData.recurrenceRule {
                if let ekRecurrenceRule = parseRRULE(rruleString) {
                    event.addRecurrenceRule(ekRecurrenceRule)
                    print("🔄 Applied recurrence rule: \(rruleString)")
                } else {
                    print("❌ Failed to parse recurrence rule: \(rruleString)")
                }
            }
            
            // Apply additional ICS properties to EKEvent
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
                    event.availability = .busy // Default to busy
                }
            }
            
            // Add priority and categories to notes since EKEvent doesn't support them directly
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
            
            // Append additional info to notes
            if !additionalNotes.isEmpty {
                let additionalText = additionalNotes.joined(separator: "\n")
                if let existingNotes = event.notes {
                    event.notes = "\(existingNotes)\n\n\(additionalText)"
                } else {
                    event.notes = additionalText
                }
            }
            
            // DEBUG: Output complete event details before adding to calendar
            print("🔍 DEBUG - COMPLETE EVENT DETAILS BEFORE ADDING TO CALENDAR:")
            print(String(repeating: "=", count: 80))
            print("📝 Title: \(event.title ?? "nil")")
            print("📄 Notes: \(event.notes ?? "nil")")
            print("📍 Location: \(event.location ?? "nil")")
            print("⏰ Start Date: \(event.startDate)")
            print("⏰ End Date: \(event.endDate)")
            print("🌍 Timezone: \(event.timeZone?.identifier ?? "nil")")
            print("🔗 URL: \(event.url?.absoluteString ?? "nil")")
            print("📊 Availability: \(event.availability.rawValue)")
            print("📅 Calendar: \(event.calendar?.title ?? "nil")")
            
            // DEBUG: Show recurrence rules
            if let recurrenceRules = event.recurrenceRules, !recurrenceRules.isEmpty {
                print("🔄 RECURRENCE RULES (\(recurrenceRules.count)):")
                for (index, rule) in recurrenceRules.enumerated() {
                    print("  [\(index + 1)] Frequency: \(rule.frequency.rawValue)")
                    print("  [\(index + 1)] Interval: \(rule.interval)")
                    print("  [\(index + 1)] Days of Week: \(rule.daysOfTheWeek?.map { $0.dayOfTheWeek.rawValue } ?? [])")
                    print("  [\(index + 1)] End: \(rule.recurrenceEnd?.description ?? "nil")")
                }
            } else {
                print("❌ NO RECURRENCE RULES FOUND!")
            }
            
            // DEBUG: Show original ICS data for comparison
            print("🗂️ ORIGINAL ICS DATA:")
            print("  RRULE: \(eventData.recurrenceRule ?? "nil")")
            print("  UID: \(eventData.uid ?? "nil")")
            print("  Priority: \(eventData.priority ?? 0)")
            print("  Status: \(eventData.status ?? "nil")")
            print("  Categories: \(eventData.categories.joined(separator: ", "))")
            print("  Organizer: \(eventData.organizer ?? "nil")")
            print("  Attendees: \(eventData.attendees.joined(separator: ", "))")
            print(String(repeating: "=", count: 80))
            
            print("📅 Adding event '\(eventData.title)' at \(eventData.startDate) (TZ: \(event.timeZone?.identifier ?? "nil"))")
            
            do {
                try eventStore.save(event, span: .thisEvent)
                successCount += 1
                print("✅ Added event: \(event.title ?? "Unknown") successfully")
                
                // DEBUG: Verify the event was saved with recurrence rules
                if let savedEvent = eventStore.event(withIdentifier: event.eventIdentifier ?? "") {
                    print("🔍 VERIFICATION - Event saved successfully:")
                    print("  Recurrence rules count: \(savedEvent.recurrenceRules?.count ?? 0)")
                    if let rules = savedEvent.recurrenceRules {
                        for (index, rule) in rules.enumerated() {
                            print("  Saved rule [\(index + 1)]: FREQ=\(rule.frequency.rawValue), INTERVAL=\(rule.interval)")
                        }
                    }
                } else {
                    print("⚠️ Could not retrieve saved event for verification")
                }
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
        
        // Handle RFC 5545 line folding (continuation lines start with space or tab)
        var unfoldedLines: [String] = []
        var currentLine = ""
        
        for line in rawLines {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                // This is a continuation line - remove the leading space/tab and append
                currentLine += line.dropFirst()
            } else {
                // This is a new line - save the previous line and start a new one
                if !currentLine.isEmpty {
                    unfoldedLines.append(currentLine)
                }
                currentLine = line
            }
        }
        
        // Don't forget the last line
        if !currentLine.isEmpty {
            unfoldedLines.append(currentLine)
        }
        
        var currentEvent: EventData?
        var currentTimezone: TimeZone?
        
        print("🔍 DEBUG: Parsing ICS content:")
        print("📄 ICS Content (\(icsContent.count) chars):")
        print(icsContent)
        print(String(repeating: "=", count: 80))
        
        // DEBUG: Show raw lines around DESCRIPTION for analysis
        print("🔍 DEBUG: Raw lines around DESCRIPTION:")
        for (index, line) in rawLines.enumerated() {
            if line.contains("DESCRIPTION") || line.contains("eventai") || (index > 0 && rawLines[index-1].contains("DESCRIPTION")) {
                let prefix = line.hasPrefix(" ") ? "[SPACE]" : (line.hasPrefix("\t") ? "[TAB]" : "[NEW]")
                print("  Raw [\(index)] \(prefix): '\(line)'")
            }
        }
        
        // DEBUG: Show line folding results
        print("🔍 DEBUG: Line folding processed \(rawLines.count) raw lines into \(unfoldedLines.count) unfolded lines")
        
        // DEBUG: Show examples of folded lines
        for (index, line) in unfoldedLines.enumerated() {
            if line.contains("DESCRIPTION:") || line.contains("eventai") {
                print("🔍 DEBUG Unfolded line [\(index)]: '\(line)'")
            }
        }
        
        // DEBUG: Also output each line as it's parsed
        print("🔍 DEBUG: Line-by-line ICS parsing:")
        
        for line in unfoldedLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // DEBUG: Print each significant line
            if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("BEGIN:VCALENDAR") && !trimmedLine.hasPrefix("VERSION") && !trimmedLine.hasPrefix("PRODID") && !trimmedLine.hasPrefix("END:VCALENDAR") {
                print("  📋 Line: \(trimmedLine)")
            }
            
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
                } else if trimmedLine.hasPrefix("RRULE:") {
                    event.recurrenceRule = String(trimmedLine.dropFirst(6))
                    print("🔄 Recurrence Rule: \(event.recurrenceRule ?? "")")
                } else if trimmedLine.hasPrefix("UID:") {
                    event.uid = String(trimmedLine.dropFirst(4))
                    print("🆔 UID: \(event.uid ?? "")")
                } else if trimmedLine.hasPrefix("URL:") {
                    event.url = URL(string: String(trimmedLine.dropFirst(4)))
                    print("🔗 URL: \(event.url?.absoluteString ?? "")")
                } else if trimmedLine.hasPrefix("ORGANIZER") {
                    // Handle ORGANIZER with or without parameters like "ORGANIZER;CN=John Doe:mailto:john@example.com"
                    if let colonIndex = trimmedLine.firstIndex(of: ":") {
                        event.organizer = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        print("👤 Organizer: \(event.organizer ?? "")")
                    }
                } else if trimmedLine.hasPrefix("ATTENDEE") {
                    // Handle ATTENDEE with parameters like "ATTENDEE;CN=Jane Doe:mailto:jane@example.com"
                    if let colonIndex = trimmedLine.firstIndex(of: ":") {
                        let attendee = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                        event.attendees.append(attendee)
                        print("👥 Attendee: \(attendee)")
                    }
                } else if trimmedLine.hasPrefix("CATEGORIES:") {
                    let categoryString = String(trimmedLine.dropFirst(11))
                    event.categories = categoryString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    print("🏷️ Categories: \(event.categories.joined(separator: ", "))")
                } else if trimmedLine.hasPrefix("PRIORITY:") {
                    event.priority = Int(String(trimmedLine.dropFirst(9)))
                    print("⚡ Priority: \(event.priority ?? 0)")
                } else if trimmedLine.hasPrefix("STATUS:") {
                    event.status = String(trimmedLine.dropFirst(7))
                    print("📊 Status: \(event.status ?? "")")
                } else if trimmedLine.hasPrefix("TRANSP:") {
                    event.transparency = String(trimmedLine.dropFirst(7))
                    print("👻 Transparency: \(event.transparency ?? "")")
                } else if trimmedLine.hasPrefix("CLASS:") {
                    event.classification = String(trimmedLine.dropFirst(6))
                    print("🔒 Classification: \(event.classification ?? "")")
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
    
    private func parseRRULE(_ rruleString: String) -> EKRecurrenceRule? {
        // Parse RFC 5545 RRULE into EKRecurrenceRule
        // Example: "FREQ=MONTHLY;INTERVAL=6" or "FREQ=WEEKLY;BYDAY=MO,WE,FR"
        
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
        
        // Create the EKRecurrenceRule
        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: freq,
            interval: interval,
            daysOfTheWeek: daysOfWeek.isEmpty ? nil : daysOfWeek,
            daysOfTheMonth: nil, // We could add support for BYMONTHDAY later
            monthsOfTheYear: nil, // We could add support for BYMONTH later
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
        
        return recurrenceRule
    }
    
    private func parseByDay(_ byDayString: String) -> [EKRecurrenceDayOfWeek] {
        // Parse BYDAY values like "MO,WE,FR" or "1MO,-1FR"
        let dayMapping: [String: EKWeekday] = [
            "MO": .monday, "TU": .tuesday, "WE": .wednesday, "TH": .thursday,
            "FR": .friday, "SA": .saturday, "SU": .sunday
        ]
        
        let days = byDayString.components(separatedBy: ",")
        var result: [EKRecurrenceDayOfWeek] = []
        
        for day in days {
            let trimmed = day.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
            // Check if it has a position indicator (like 1MO, -1FR)
            if trimmed.count > 2 {
                // Extract position (number) and day code
                let dayCode = String(trimmed.suffix(2))
                let positionStr = String(trimmed.dropLast(2))
                
                if let weekday = dayMapping[dayCode], let weekNumber = Int(positionStr) {
                    let dayOfWeek = EKRecurrenceDayOfWeek(dayOfTheWeek: weekday, weekNumber: weekNumber)
                    result.append(dayOfWeek)
                }
            } else {
                // Just a day code (like MO, TU)
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
    var recurrenceRule: String? // Store the raw RRULE string
    var uid: String? // Unique identifier
    var url: URL? // Event URL
    var organizer: String? // Event organizer
    var attendees: [String] = [] // List of attendees
    var categories: [String] = [] // Event categories/tags
    var priority: Int? // Event priority (0-9)
    var status: String? // Event status (TENTATIVE, CONFIRMED, CANCELLED)
    var transparency: String? // TRANSPARENT or OPAQUE
    var classification: String? // PUBLIC, PRIVATE, CONFIDENTIAL
    var alarm: String? // VALARM data
}