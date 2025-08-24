import Foundation

// MARK: - Shared API Service for iOS and macOS
public class SharedAPIService: ObservableObject {
    public static let shared = SharedAPIService()
    
    private let baseURL: String
    private let apiKey: String
    
    public init() {
        // Try to load from Config.plist first (macOS), then fall back to Info.plist (iOS)
        var configDict: [String: Any]?
        
        // Look for Config.plist in the bundle
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist") {
            configDict = NSDictionary(contentsOfFile: configPath) as? [String: Any]
        }
        
        // Load configuration
        if let config = configDict {
            self.baseURL = config["API_BASE_URL"] as? String ?? "https://eventai.leveluplife.app/api"
            self.apiKey = config["API_KEY"] as? String ?? ""
        } else {
            // Fallback to Info.plist (for iOS)
            self.baseURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? "https://eventai.leveluplife.app/api"
            self.apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String ?? ""
        }
        
        print("🔑 API Configuration loaded - BaseURL: \(baseURL), API Key: \(apiKey.isEmpty ? "EMPTY" : "****")")
    }
    
    // MARK: - API Response Models
    public struct ConversionResponse: Codable {
        public let eventsFound: Int
        public let events: [CalendarEvent]
        public let message: String
        public let usage: UsageInfo?
        public let requiresPremium: Bool
        
        // Computed property for compatibility
        public var success: Bool {
            return eventsFound > 0
        }
        
        // Computed property for compatibility  
        public var usageInfo: UsageInfo? {
            return usage
        }
        
        public init(eventsFound: Int, events: [CalendarEvent], message: String, usage: UsageInfo? = nil, requiresPremium: Bool = false) {
            self.eventsFound = eventsFound
            self.events = events
            self.message = message
            self.usage = usage
            self.requiresPremium = requiresPremium
        }
    }
    
    public struct CalendarEvent: Codable, Identifiable {
        public let id = UUID()
        public let title: String
        public let description: String?
        public let startDate: String
        public let endDate: String?
        public let location: String?
        public let isRecurring: Bool
        public let recurrencePattern: String?
        public let timezone: String?
        
        // Computed properties for compatibility
        public var notes: String? { return description }
        public var isAllDay: Bool {
            // Simple heuristic - if no specific time is mentioned, assume all day
            return !startDate.contains("T") || startDate.contains("00:00:00")
        }
        
        // Computed properties for easy date handling
        public var formattedStartDate: Date? {
            return ISO8601DateFormatter().date(from: startDate)
        }
        
        public var formattedEndDate: Date? {
            guard let endDate = endDate else { return nil }
            return ISO8601DateFormatter().date(from: endDate)
        }
        
        enum CodingKeys: String, CodingKey {
            case title, description, location, timezone
            case startDate = "start_date"
            case endDate = "end_date"
            case isRecurring = "is_recurring"
            case recurrencePattern = "recurrence_pattern"
        }
        
        public init(title: String, description: String?, startDate: String, endDate: String?, location: String?, isRecurring: Bool, recurrencePattern: String?, timezone: String?) {
            self.title = title
            self.description = description
            self.startDate = startDate
            self.endDate = endDate
            self.location = location
            self.isRecurring = isRecurring
            self.recurrencePattern = recurrencePattern
            self.timezone = timezone
        }
    }
    
    public struct UsageInfo: Codable {
        public let count: Int
        public let limit: Int
        public let remaining: Int
        public let resetDate: String?
        
        public init(count: Int, limit: Int, remaining: Int, resetDate: String?) {
            self.count = count
            self.limit = limit
            self.remaining = remaining
            self.resetDate = resetDate
        }
    }
    
    public struct UsageResponse: Codable {
        public let allowed: Bool
        public let count: Int
        public let limit: Int
        public let remaining: Int
        public let isPremium: Bool
        public let resetDate: String?
        public let resetTime: String?
        public let resetTimezone: String?
        
        enum CodingKeys: String, CodingKey {
            case allowed, count, limit, remaining
            case isPremium = "is_premium"
            case resetDate = "reset_date"
            case resetTime = "reset_time"
            case resetTimezone = "reset_timezone"
        }
        
        public init(allowed: Bool, count: Int, limit: Int, remaining: Int, isPremium: Bool, resetDate: String?, resetTime: String?, resetTimezone: String?) {
            self.allowed = allowed
            self.count = count
            self.limit = limit
            self.remaining = remaining
            self.isPremium = isPremium
            self.resetDate = resetDate
            self.resetTime = resetTime
            self.resetTimezone = resetTimezone
        }
    }
    
    // MARK: - API Methods
    public func convertTextToCalendar(text: String, timezone: String, image: Data? = nil) async throws -> ConversionResponse {
        guard !apiKey.isEmpty else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/convert")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Use multipart form data like iOS app
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("macos-device-\(UUID().uuidString)", forHTTPHeaderField: "X-Device-ID")
        request.timeoutInterval = 30.0
        
        var formData = Data()
        
        // Add text field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"text\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(text)\r\n".data(using: .utf8)!)
        
        // Add timezone field
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"timezone\"\r\n\r\n".data(using: .utf8)!)
        formData.append("\(timezone)\r\n".data(using: .utf8)!)
        
        // Add image if present
        if let image = image {
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            formData.append(image)
            formData.append("\r\n".data(using: .utf8)!)
        }
        
        // Close boundary
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else if httpResponse.statusCode == 429 {
            throw APIError.quotaExceeded
        } else if httpResponse.statusCode != 200 {
            throw APIError.serverError
        }
        
        let conversionResponse = try JSONDecoder().decode(ConversionResponse.self, from: data)
        return conversionResponse
    }
    
    public func getUsage() async throws -> UsageResponse {
        guard !apiKey.isEmpty else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/usage")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("macos-device-\(UUID().uuidString)", forHTTPHeaderField: "X-Device-ID")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        } else if httpResponse.statusCode != 200 {
            throw APIError.serverError
        }
        
        let usageResponse = try JSONDecoder().decode(UsageResponse.self, from: data)
        return usageResponse
    }
}

// MARK: - API Errors
public enum APIError: Error, LocalizedError {
    case unauthorized
    case quotaExceeded
    case networkError
    case serverError
    case serverUnavailable
    case timeout
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication failed"
        case .quotaExceeded:
            return "Daily usage limit exceeded"
        case .networkError:
            return "Network connection error"
        case .serverError:
            return "Server error occurred"
        case .serverUnavailable:
            return "Service temporarily unavailable"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}