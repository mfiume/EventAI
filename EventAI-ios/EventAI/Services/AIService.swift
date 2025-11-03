import Foundation
import UIKit

// MARK: - AI Service Protocol
protocol AIServiceProtocol {
    func convertTextToEvents(text: String, timezone: String, image: UIImage?) async throws -> [CalendarEvent]
    func testConnection() async throws -> Bool
}

// MARK: - AI Service Factory
class AIServiceFactory {
    static func createService(configuration: AIConfiguration, apiKey: String) -> AIServiceProtocol {
        switch configuration.provider {
        case .anthropic:
            return AnthropicService(apiKey: apiKey, configuration: configuration)
        case .openai:
            return OpenAIService(apiKey: apiKey, configuration: configuration)
        }
    }
}

// MARK: - Anthropic Service
class AnthropicService: AIServiceProtocol {
    private let apiKey: String
    private let configuration: AIConfiguration
    private let baseURL = "https://api.anthropic.com/v1/messages"

    init(apiKey: String, configuration: AIConfiguration) {
        self.apiKey = apiKey
        self.configuration = configuration
    }

    func convertTextToEvents(text: String, timezone: String, image: UIImage?) async throws -> [CalendarEvent] {
        // Build prompt
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        dateFormatter.timeZone = TimeZone(identifier: timezone)

        let prompt = """
        Extract calendar events from the following text.
        Current timezone: \(timezone)
        Current date: \(dateFormatter.string(from: currentDate))

        Return ONLY a valid JSON array with this exact format (no additional text, no markdown):
        [{
          "title": "Event Title",
          "start_date": "2025-11-05T14:00:00",
          "end_date": "2025-11-05T15:00:00",
          "is_all_day": false,
          "is_recurring": false,
          "recurrence_pattern": null,
          "location": null,
          "description": null
        }]

        Rules:
        - Use ISO 8601 format for dates (YYYY-MM-DDTHH:MM:SS)
        - If no time specified, infer reasonable times
        - For recurring events, set is_recurring to true and provide recurrence_pattern
        - Return empty array [] if no events found

        Text: \(text)
        """

        // Build content array
        var content: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]

        // Add image if provided
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            let base64 = imageData.base64EncodedString()
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        // Build request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30.0

        let body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": configuration.maxTokens,
            "temperature": configuration.temperature,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AIServiceError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw AIServiceError.rateLimitExceeded
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let textContent = contentArray.first?["text"] as? String else {
            throw AIServiceError.invalidResponse
        }

        // Parse events JSON
        let events = try parseEventsJSON(textContent)
        return events
    }

    func testConnection() async throws -> Bool {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10.0

        let body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": 10,
            "messages": [
                [
                    "role": "user",
                    "content": "Hello"
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }

    private func parseEventsJSON(_ text: String) throws -> [CalendarEvent] {
        // Try to extract JSON array from response
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonText.hasPrefix("```json") {
            jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if jsonText.hasPrefix("```") {
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find JSON array in text
        if let range = jsonText.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) {
            jsonText = String(jsonText[range])
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIServiceError.jsonParsingFailed
        }

        let decoder = JSONDecoder()
        let events = try decoder.decode([CalendarEvent].self, from: jsonData)
        return events
    }
}

// MARK: - OpenAI Service
class OpenAIService: AIServiceProtocol {
    private let apiKey: String
    private let configuration: AIConfiguration
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String, configuration: AIConfiguration) {
        self.apiKey = apiKey
        self.configuration = configuration
    }

    func convertTextToEvents(text: String, timezone: String, image: UIImage?) async throws -> [CalendarEvent] {
        // Build prompt
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        dateFormatter.timeZone = TimeZone(identifier: timezone)

        let systemPrompt = "You are a calendar event extraction assistant. Extract events from text and return ONLY a valid JSON array, no other text."

        let userPrompt = """
        Extract calendar events from this text.
        Current timezone: \(timezone)
        Current date: \(dateFormatter.string(from: currentDate))

        Return ONLY a valid JSON array with this format:
        [{
          "title": "Event Title",
          "start_date": "2025-11-05T14:00:00",
          "end_date": "2025-11-05T15:00:00",
          "is_all_day": false,
          "is_recurring": false,
          "recurrence_pattern": null,
          "location": null,
          "description": null
        }]

        Text: \(text)
        """

        // Build messages
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Add user message with optional image
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
            let base64 = "data:image/jpeg;base64," + imageData.base64EncodedString()
            messages.append([
                "role": "user",
                "content": [
                    ["type": "text", "text": userPrompt],
                    ["type": "image_url", "image_url": ["url": base64]]
                ]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": userPrompt
            ])
        }

        // Build request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AIServiceError.invalidAPIKey
            } else if httpResponse.statusCode == 429 {
                throw AIServiceError.rateLimitExceeded
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let textContent = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        // Parse events JSON
        let events = try parseEventsJSON(textContent)
        return events
    }

    func testConnection() async throws -> Bool {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "user", "content": "Hello"]
            ],
            "max_tokens": 10
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return httpResponse.statusCode == 200
    }

    private func parseEventsJSON(_ text: String) throws -> [CalendarEvent] {
        // Try to extract JSON array from response
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonText.hasPrefix("```json") {
            jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if jsonText.hasPrefix("```") {
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find JSON array in text
        if let range = jsonText.range(of: #"\[[\s\S]*\]"#, options: .regularExpression) {
            jsonText = String(jsonText[range])
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AIServiceError.jsonParsingFailed
        }

        let decoder = JSONDecoder()
        let events = try decoder.decode([CalendarEvent].self, from: jsonData)
        return events
    }
}

// MARK: - AI Service Errors
enum AIServiceError: LocalizedError {
    case invalidResponse
    case invalidAPIKey
    case rateLimitExceeded
    case jsonParsingFailed
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .invalidAPIKey:
            return "Invalid API key. Please check your settings."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .jsonParsingFailed:
            return "Failed to parse events from AI response"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        }
    }
}
