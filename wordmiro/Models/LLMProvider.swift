import Foundation

enum LLMProvider: String, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        }
    }
    
    var baseURL: String {
        switch self {
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1"
        }
    }
    
    var model: String {
        switch self {
        case .openai:
            return "gpt-4o"
        case .anthropic:
            return "claude-3-5-sonnet-20241022"
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .openai:
            return 1000
        case .anthropic:
            return 1000
        }
    }
}

struct LLMSettings {
    var provider: LLMProvider = .openai
    var apiKey: String = ""
    var temperature: Double = 0.3
    var maxTokens: Int = 1000
    
    var isValid: Bool {
        return !apiKey.isEmpty
    }
}