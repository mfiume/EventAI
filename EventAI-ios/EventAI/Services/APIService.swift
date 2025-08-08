import Foundation

struct CalendarEventResponse: Codable {
    let icsContent: String
    let eventsFound: Int
    let message: String
}

struct TextToCalendarRequest: Codable {
    let text: String
    let timezone: String
}

@MainActor
class APIService: ObservableObject {
    private let baseURL = "https://eventai.leveluplife.app"
    private let session = URLSession.shared
    
    func convertTextToCalendar(text: String, timezone: String = "America/New_York") async throws -> CalendarEventResponse {
        guard let url = URL(string: "\(baseURL)/convert") else {
            throw APIError.invalidURL
        }
        
        let request = TextToCalendarRequest(text: text, timezone: timezone)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw APIError.encodingError
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            let calendarResponse = try JSONDecoder().decode(CalendarEventResponse.self, from: data)
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