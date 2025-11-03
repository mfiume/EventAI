import Foundation
import UIKit

// MARK: - Forward Declaration
// CalendarEvent is defined in AIConfiguration.swift
// This file is included in the same target, so no import needed

// MARK: - Legacy Models (kept for backwards compatibility with CalendarService)
struct ParsedEvent: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let startDate: String
    let endDate: String?
    let location: String?
    let isRecurring: Bool
    let recurrencePattern: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case title, description, location, timezone
        case startDate = "start_date"
        case endDate = "end_date"
        case isRecurring = "is_recurring"
        case recurrencePattern = "recurrence_pattern"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        startDate = try container.decode(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        recurrencePattern = try container.decodeIfPresent(String.self, forKey: .recurrencePattern)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
    }

    // Convenience initializer from CalendarEvent
    init(from event: CalendarEvent) {
        self.title = event.title
        self.description = event.description
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.isRecurring = event.isRecurring
        self.recurrencePattern = event.recurrencePattern
        self.timezone = event.timezone
    }

    var formattedStartDate: Date? {
        // Try multiple date formats
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: startDate) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: startDate) {
            return date
        }

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: startDate) {
            return date
        }

        print("Failed to parse start date: \(startDate)")
        return nil
    }

    var formattedEndDate: Date? {
        guard let endDate = endDate else { return nil }

        // Try multiple date formats
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: endDate) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: endDate) {
            return date
        }

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: endDate) {
            return date
        }

        print("Failed to parse end date: \(endDate)")
        return nil
    }
}

// MARK: - Note
// This file previously contained backend API calls.
// EventAI 2.0 has removed the backend and uses direct AI API calls.
// See AIService.swift for the new implementation.
