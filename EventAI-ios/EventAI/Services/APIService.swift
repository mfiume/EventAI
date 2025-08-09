import Foundation
import UIKit

struct CalendarEventResponse: Codable {
    let icsContent: String
    let eventsFound: Int
    let message: String
    let events: [ParsedEvent]?
}

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
    
    var formattedStartDate: Date? {
        // Try multiple date formats
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: startDate) {
            print("📅 Parsed start date with ISO: \(startDate) -> \(date)")
            return date
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: startDate) {
            print("📅 Parsed start date with custom format: \(startDate) -> \(date)")
            return date
        }
        
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: startDate) {
            print("📅 Parsed start date with space format: \(startDate) -> \(date)")
            return date
        }
        
        print("❌ Failed to parse start date: \(startDate)")
        return nil
    }
    
    var formattedEndDate: Date? {
        guard let endDate = endDate else { return nil }
        
        // Try multiple date formats
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: endDate) {
            print("📅 Parsed end date with ISO: \(endDate) -> \(date)")
            return date
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: endDate) {
            print("📅 Parsed end date with custom format: \(endDate) -> \(date)")
            return date
        }
        
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: endDate) {
            print("📅 Parsed end date with space format: \(endDate) -> \(date)")
            return date
        }
        
        print("❌ Failed to parse end date: \(endDate)")
        return nil
    }
}


@MainActor
class APIService: ObservableObject {
    private let baseURL: String
    private let session = URLSession.shared
    
    init() {
        // Use production EventAI API
        self.baseURL = "https://eventai.leveluplife.app/api"
        print("🚀 EventAI API configured: \(baseURL)")
    }
    
    func convertTextToCalendar(text: String, timezone: String = "America/New_York", userLocation: String? = nil, image: UIImage? = nil) async throws -> CalendarEventResponse {
        let fullURL = "\(baseURL)/convert"
        print("🔗 Making API call to: \(fullURL)")
        if image != nil {
            print("🖼️ Including image attachment")
        }
        
        guard let url = URL(string: fullURL) else {
            print("❌ Invalid URL: \(fullURL)")
            throw APIError.invalidURL
        }
        
        // DEBUG: Print request being sent
        print("🔍 DEBUG - REQUEST TO BACKEND:")
        print(String(repeating: "=", count: 80))
        print("Text: \(text)")
        print("Timezone: \(timezone)")
        print("User Location: \(userLocation ?? "nil")")
        if let image = image {
            print("Image: Attached (\(image.size.width)x\(image.size.height))")
        }
        print(String(repeating: "=", count: 80))
        
        // Always use multipart form data for consistency (works with or without image)
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var formData = Data()
        
        // Add text field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(text)\r\n".data(using: .utf8)!)
        
        // Add timezone field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"timezone\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(timezone)\r\n".data(using: .utf8)!)
        
        // Add userLocation field if present
        if let userLocation = userLocation {
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"userLocation\"\r\n\r\n".data(using: .utf8)!)
            formData.append("\(userLocation)\r\n".data(using: .utf8)!)
        }
        
        // Add image field if present
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            formData.append(imageData)
            formData.append("\r\n".data(using: .utf8)!)
        }
        
        // Close boundary
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        urlRequest.httpBody = formData
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let calendarResponse = try JSONDecoder().decode(CalendarEventResponse.self, from: data)
            
            // DEBUG: Print response from backend
            print("🤖 DEBUG - RESPONSE FROM BACKEND:")
            print(String(repeating: "=", count: 80))
            print("Events Found: \(calendarResponse.eventsFound)")
            print("Message: \(calendarResponse.message)")
            if let events = calendarResponse.events {
                print("Events:")
                for (index, event) in events.enumerated() {
                    print("  [\(index + 1)] \(event.title)")
                    print("      Start: \(event.startDate)")
                    print("      End: \(event.endDate ?? "nil")")
                    print("      Location: \(event.location ?? "nil")")
                    print("      Recurring: \(event.isRecurring)")
                    print("      Pattern: \(event.recurrencePattern ?? "nil")")
                    print("      Timezone: \(event.timezone ?? "nil")")
                }
            }
            print("ICS Content Length: \(calendarResponse.icsContent.count) characters")
            print(String(repeating: "=", count: 80))
            
            return calendarResponse
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case encodingError
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Failed to encode request"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}