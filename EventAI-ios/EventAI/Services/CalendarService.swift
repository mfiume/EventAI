import Foundation
import EventKit

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    
    func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Calendar access granted")
                } else {
                    print("Calendar access denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    func addEventsToCalendar(icsContent: String, completion: @escaping (Bool, Error?) -> Void) {
        // Parse ICS content and create EKEvents
        let events = parseICSContent(icsContent)
        
        var successCount = 0
        var errors: [Error] = []
        
        for eventData in events {
            let event = EKEvent(eventStore: eventStore)
            event.title = eventData.title
            event.notes = eventData.description
            event.startDate = eventData.startDate
            event.endDate = eventData.endDate
            event.calendar = eventStore.defaultCalendarForNewEvents
            
            if let location = eventData.location {
                event.location = location
            }
            
            do {
                try eventStore.save(event, span: .thisEvent)
                successCount += 1
            } catch {
                errors.append(error)
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