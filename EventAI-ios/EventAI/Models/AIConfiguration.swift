import Foundation

// MARK: - AI Provider
enum AIProvider: String, CaseIterable, Identifiable {
    case anthropic = "anthropic"
    case openai = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic:
            return "Anthropic Claude"
        case .openai:
            return "OpenAI GPT"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic:
            return "claude-3-5-haiku-20241022"
        case .openai:
            return "gpt-4o-mini"
        }
    }

    var availableModels: [AIModel] {
        switch self {
        case .anthropic:
            return [
                AIModel(id: "claude-3-5-haiku-20241022", displayName: "Claude 3.5 Haiku", isDefault: true),
                AIModel(id: "claude-3-5-sonnet-20241022", displayName: "Claude 3.5 Sonnet", isDefault: false)
            ]
        case .openai:
            return [
                AIModel(id: "gpt-4o-mini", displayName: "GPT-4o Mini", isDefault: true),
                AIModel(id: "gpt-4o", displayName: "GPT-4o", isDefault: false),
                AIModel(id: "gpt-4-turbo", displayName: "GPT-4 Turbo", isDefault: false)
            ]
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .anthropic:
            return "sk-ant-api03-..."
        case .openai:
            return "sk-proj-..."
        }
    }

    var signupURL: String {
        switch self {
        case .anthropic:
            return "https://console.anthropic.com"
        case .openai:
            return "https://platform.openai.com"
        }
    }
}

// MARK: - AI Model
struct AIModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let isDefault: Bool
}

// MARK: - AI Configuration
struct AIConfiguration {
    var provider: AIProvider
    var model: String
    var temperature: Double
    var maxTokens: Int

    static let defaultTemperature: Double = 0.1
    static let defaultMaxTokens: Int = 2000

    init(provider: AIProvider = .anthropic,
         model: String? = nil,
         temperature: Double = AIConfiguration.defaultTemperature,
         maxTokens: Int = AIConfiguration.defaultMaxTokens) {
        self.provider = provider
        self.model = model ?? provider.defaultModel
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    // MARK: - UserDefaults Keys
    private static let providerKey = "ai_provider"
    private static let modelKey = "ai_model"
    private static let temperatureKey = "ai_temperature"
    private static let maxTokensKey = "ai_max_tokens"

    // MARK: - Save/Load from UserDefaults
    func save() {
        UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey)
        UserDefaults.standard.set(model, forKey: Self.modelKey)
        UserDefaults.standard.set(temperature, forKey: Self.temperatureKey)
        UserDefaults.standard.set(maxTokens, forKey: Self.maxTokensKey)
    }

    static func load() -> AIConfiguration {
        let providerRawValue = UserDefaults.standard.string(forKey: providerKey) ?? AIProvider.anthropic.rawValue
        let provider = AIProvider(rawValue: providerRawValue) ?? .anthropic

        let model = UserDefaults.standard.string(forKey: modelKey) ?? provider.defaultModel
        let temperature = UserDefaults.standard.double(forKey: temperatureKey)
        let maxTokens = UserDefaults.standard.integer(forKey: maxTokensKey)

        return AIConfiguration(
            provider: provider,
            model: model,
            temperature: temperature == 0 ? defaultTemperature : temperature,
            maxTokens: maxTokens == 0 ? defaultMaxTokens : maxTokens
        )
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: providerKey)
        UserDefaults.standard.removeObject(forKey: modelKey)
        UserDefaults.standard.removeObject(forKey: temperatureKey)
        UserDefaults.standard.removeObject(forKey: maxTokensKey)
    }
}

// MARK: - Calendar Event Model
struct CalendarEvent: Codable, Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let startDate: String
    let endDate: String?
    let location: String?
    let isAllDay: Bool
    let isRecurring: Bool
    let recurrencePattern: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case startDate = "start_date"
        case endDate = "end_date"
        case location
        case isAllDay = "is_all_day"
        case isRecurring = "is_recurring"
        case recurrencePattern = "recurrence_pattern"
        case timezone
    }

    // Computed properties for date formatting (compatible with ParsedEvent)
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
