import Foundation
import Combine

struct ExpandRequest: Codable {
    let lemma: String
    let locale: String
    let maxRelated: Int
    
    enum CodingKeys: String, CodingKey {
        case lemma
        case locale
        case maxRelated = "max_related"
    }
}

struct RelatedWord: Codable {
    let term: String
    let relation: String
}

struct ExpandResponse: Codable {
    let lemma: String
    let pos: String?
    let register: String?
    let explanationJA: String
    let exampleEN: String?
    let exampleJA: String?
    let related: [RelatedWord]
    
    enum CodingKeys: String, CodingKey {
        case lemma, pos, register, related
        case explanationJA = "explanation_ja"
        case exampleEN = "example_en"
        case exampleJA = "example_ja"
    }
}

class LLMService: ObservableObject {
    static let shared = LLMService()
    
    private let openAIService = OpenAIService()
    private let anthropicService = AnthropicService()
    private let keychain = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var settings = LLMSettings()
    
    private init() {
        loadSettings()
    }
    
    func expandWord(lemma: String, locale: String = "ja", maxRelated: Int = 12) -> AnyPublisher<ExpandResponse, Error> {
        switch settings.provider {
        case .openai:
            return openAIService.expandWord(lemma: lemma, locale: locale)
        case .anthropic:
            return anthropicService.expandWord(lemma: lemma, locale: locale)
        }
    }
    
    func updateSettings(_ newSettings: LLMSettings) {
        settings = newSettings
        saveSettings()
    }
    
    private func loadSettings() {
        // Load provider preference
        if let providerString = UserDefaults.standard.string(forKey: "llm_provider"),
           let provider = LLMProvider(rawValue: providerString) {
            settings.provider = provider
        }
        
        // Load API keys from keychain
        switch settings.provider {
        case .openai:
            settings.apiKey = keychain.loadOpenAIKey() ?? ""
        case .anthropic:
            settings.apiKey = keychain.loadAnthropicKey() ?? ""
        }
        
        // Load other settings
        settings.temperature = UserDefaults.standard.double(forKey: "llm_temperature")
        if settings.temperature == 0 { settings.temperature = 0.3 }
        
        settings.maxTokens = UserDefaults.standard.integer(forKey: "llm_max_tokens")
        if settings.maxTokens == 0 { settings.maxTokens = 1000 }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(settings.provider.rawValue, forKey: "llm_provider")
        UserDefaults.standard.set(settings.temperature, forKey: "llm_temperature")
        UserDefaults.standard.set(settings.maxTokens, forKey: "llm_max_tokens")
        
        // Save API key to keychain
        switch settings.provider {
        case .openai:
            _ = keychain.saveOpenAIKey(settings.apiKey)
        case .anthropic:
            _ = keychain.saveAnthropicKey(settings.apiKey)
        }
    }
    
    // Mock response for development
    func mockExpandWord(lemma: String) -> AnyPublisher<ExpandResponse, Error> {
        let mockResponse = ExpandResponse(
            lemma: lemma,
            pos: "adjective",
            register: "ややフォーマル",
            explanationJA: """
            「\(lemma)」は「至る所に存在する、遍在する」という意味の形容詞です。ラテン語のubique（どこでも）とous（満ちた）から派生し、現代では特にテクノロジーの文脈で「ユビキタス」として使われます。日常生活に深く浸透し、意識せずとも常に存在している状態を表現する際に用いられ、やや学術的・技術的なニュアンスを持ちます。単なる「普通」や「一般的」とは異なり、空間的な遍在性を強調する語彙として、IELTS等の学術文書で頻出します。
            """,
            exampleEN: "Smartphones have become ubiquitous in modern society, fundamentally changing how we communicate.",
            exampleJA: "スマートフォンは現代社会において遍在する存在となり、私たちのコミュニケーション方法を根本的に変えた。",
            related: [
                RelatedWord(term: "omnipresent", relation: "synonym"),
                RelatedWord(term: "pervasive", relation: "associate"),
                RelatedWord(term: "widespread", relation: "synonym"),
                RelatedWord(term: "scarce", relation: "antonym"),
                RelatedWord(term: "rare", relation: "antonym"),
                RelatedWord(term: "ubiquity", relation: "etymology"),
                RelatedWord(term: "ubiquitous computing", relation: "collocation"),
                RelatedWord(term: "ubiquitous technology", relation: "collocation")
            ]
        )
        
        // Simulate network delay
        return Just(mockResponse)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.5), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
}