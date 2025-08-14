import Foundation
import UIKit

struct CalendarEventResponse: Codable {
    let icsContent: String
    let eventsFound: Int
    let message: String
    let events: [ParsedEvent]?
}

struct UsageResponse: Codable {
    let count: Int
    let limit: Int
    let remaining: Int
    let isPremium: Bool
    let resetDate: String
    let canConvert: Bool
    
    enum CodingKeys: String, CodingKey {
        case count, limit, remaining
        case isPremium = "is_premium"
        case resetDate = "reset_date"
        case canConvert = "can_convert"
    }
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
        
        print("❌ Failed to parse start date: \(startDate)")
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
        
        print("❌ Failed to parse end date: \(endDate)")
        return nil
    }
}


@MainActor
class APIService: ObservableObject {
    private let baseURL: String
    private let apiKey: String
    private let session = URLSession.shared
    
    init() {
        // Get configuration from xcconfig via Info.plist
        guard let baseURL = Bundle.main.infoDictionary?["BACKEND_BASE_URL"] as? String else {
            fatalError("❌ BACKEND_BASE_URL not found in configuration")
        }
        
        guard let apiKey = Bundle.main.infoDictionary?["API_KEY"] as? String else {
            fatalError("❌ API_KEY not found in configuration")
        }
        
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    func getUsageStats() async throws -> UsageResponse {
        let fullURL = "\(baseURL)/usage"
        
        print("🔄 [APIService] Starting getUsageStats() call to: \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ [APIService] Invalid URL: \(fullURL)")
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.timeoutInterval = 20.0 // Increased timeout for slow BigQuery API
        
        print("🔄 [APIService] Making HTTP request with timeout: \(urlRequest.timeoutInterval)s")
        
        do {
            let startTime = Date()
            let (data, response) = try await session.data(for: urlRequest)
            let duration = Date().timeIntervalSince(startTime)
            
            print("✅ [APIService] HTTP request completed in \(String(format: "%.2f", duration))s")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIService] Invalid HTTP response")
                throw APIError.invalidResponse
            }
            
            print("📊 [APIService] HTTP status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [APIService] API Error: Status \(httpResponse.statusCode)")
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                } else if httpResponse.statusCode >= 500 {
                    throw APIError.serverUnavailable
                } else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            let usageResponse = try JSONDecoder().decode(UsageResponse.self, from: data)
            print("✅ [APIService] Usage API response: count=\(usageResponse.count), limit=\(usageResponse.limit), remaining=\(usageResponse.remaining)")
            return usageResponse
            
        } catch let error as URLError where error.code == .timedOut {
            print("⏰ [APIService] Usage API timed out after \(urlRequest.timeoutInterval)s")
            throw APIError.timeout
        } catch let error as APIError {
            print("❌ [APIService] Usage API error: \(error)")
            throw error
        } catch {
            print("❌ [APIService] Usage API network error: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    func convertTextToCalendar(text: String, timezone: String = "America/New_York", userLocation: String? = nil, image: UIImage? = nil) async throws -> CalendarEventResponse {
        let fullURL = "\(baseURL)/convert"
        
        guard let url = URL(string: fullURL) else {
            print("❌ Invalid URL: \(fullURL)")
            throw APIError.invalidURL
        }
        
        // Always use multipart form data for consistency (works with or without image)
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.timeoutInterval = 30.0 // Longer timeout for conversion requests
        
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
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                } else if httpResponse.statusCode == 429 {
                    throw APIError.quotaExceeded
                } else if httpResponse.statusCode >= 500 {
                    throw APIError.serverUnavailable
                } else {
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            
            let calendarResponse = try JSONDecoder().decode(CalendarEventResponse.self, from: data)
            return calendarResponse
            
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
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
    case timeout
    case unauthorized
    case quotaExceeded
    case serverUnavailable
    
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
        case .timeout:
            return "Request timed out"
        case .unauthorized:
            return "Authentication failed"
        case .quotaExceeded:
            return "Daily limit exceeded"
        case .serverUnavailable:
            return "Service temporarily unavailable"
        }
    }
    
}