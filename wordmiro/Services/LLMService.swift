import Foundation
import Combine
import os.log

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
    var explanationJA: String
    let exampleEN: String?
    let exampleJA: String?
    var related: [RelatedWord]
    
    enum CodingKeys: String, CodingKey {
        case lemma, pos, register, related
        case explanationJA = "explanation_ja"
        case exampleEN = "example_en"
        case exampleJA = "example_ja"
    }
}

struct ValidationStats {
    var totalRequests: Int = 0
    var successfulValidations: Int = 0
    var repairedResponses: Int = 0
    var failedValidations: Int = 0
    var totalResponseTime: TimeInterval = 0
    var totalValidationTime: TimeInterval = 0
    var averageExplanationLength: Double = 0
    var averageRelatedCount: Double = 0
    var repairHistory: [ValidationRepairLog] = []
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulValidations) / Double(totalRequests)
    }
    
    var repairRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(repairedResponses) / Double(totalRequests)
    }
    
    var failureRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(failedValidations) / Double(totalRequests)
    }
    
    var averageResponseTime: TimeInterval {
        guard totalRequests > 0 else { return 0 }
        return totalResponseTime / Double(totalRequests)
    }
    
    var averageValidationTime: TimeInterval {
        guard totalRequests > 0 else { return 0 }
        return totalValidationTime / Double(totalRequests)
    }
}

struct ValidationRepairLog {
    let lemma: String
    let originalExplanationLength: Int
    let repairedExplanationLength: Int
    let originalRelatedCount: Int
    let repairedRelatedCount: Int
    let errorType: String
    let timestamp: Date
}

class LLMService: ObservableObject {
    static let shared = LLMService()
    
    private let openAIService = OpenAIService()
    private let anthropicService = AnthropicService()
    private let keychain = KeychainService.shared
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "WordMiro", category: "LLMService")
    
    @Published var settings = LLMSettings()
    @Published var validationStats = ValidationStats()
    
    private init() {
        loadSettings()
    }
    
    func expandWord(lemma: String, locale: String = "ja", maxRelated: Int = 12) -> AnyPublisher<ExpandResponse, Error> {
        let startTime = CACurrentMediaTime()
        
        return getLLMResponse(lemma: lemma, locale: locale)
            .flatMap { response in
                self.validateAndSanitizeResponse(response, startTime: startTime)
            }
            .eraseToAnyPublisher()
    }
    
    private func getLLMResponse(lemma: String, locale: String) -> AnyPublisher<ExpandResponse, Error> {
        switch settings.provider {
        case .openai:
            return openAIService.expandWord(lemma: lemma, locale: locale)
        case .anthropic:
            return anthropicService.expandWord(lemma: lemma, locale: locale)
        }
    }
    
    private func validateAndSanitizeResponse(_ response: ExpandResponse, startTime: CFTimeInterval) -> AnyPublisher<ExpandResponse, Error> {
        return Future<ExpandResponse, Error> { promise in
            let validationStartTime = CACurrentMediaTime()
            
            do {
                // Client-side validation (fallback for when BFF isn't available)
                try JSONValidator.validateFullResponse(response)
                
                // Record successful validation
                let validationTime = CACurrentMediaTime() - validationStartTime
                let totalTime = CACurrentMediaTime() - startTime
                
                self.recordValidationSuccess(
                    responseTime: totalTime,
                    validationTime: validationTime,
                    explanationLength: response.explanationJA.count,
                    relatedCount: response.related.count
                )
                
                self.logger.info("Response validation successful for '\(response.lemma)'")
                promise(.success(response))
                
            } catch let validationError as JSONValidationError {
                self.logger.warning("Validation failed: \(validationError.localizedDescription)")
                
                // Attempt auto-repair
                let sanitizedResponse = JSONValidator.sanitizeResponse(response)
                
                do {
                    try JSONValidator.validateFullResponse(sanitizedResponse)
                    
                    self.recordValidationRepair(
                        originalResponse: response,
                        repairedResponse: sanitizedResponse,
                        error: validationError
                    )
                    
                    self.logger.info("Response auto-repair successful for '\(response.lemma)'")
                    promise(.success(sanitizedResponse))
                    
                } catch {
                    self.recordValidationFailure(error: validationError)
                    promise(.failure(validationError))
                }
                
            } catch {
                self.recordValidationFailure(error: error)
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func recordValidationSuccess(responseTime: TimeInterval, validationTime: TimeInterval, explanationLength: Int, relatedCount: Int) {
        validationStats.totalRequests += 1
        validationStats.successfulValidations += 1
        validationStats.totalResponseTime += responseTime
        validationStats.totalValidationTime += validationTime
        validationStats.averageExplanationLength = (validationStats.averageExplanationLength + Double(explanationLength)) / 2
        validationStats.averageRelatedCount = (validationStats.averageRelatedCount + Double(relatedCount)) / 2
    }
    
    private func recordValidationRepair(originalResponse: ExpandResponse, repairedResponse: ExpandResponse, error: JSONValidationError) {
        validationStats.totalRequests += 1
        validationStats.repairedResponses += 1
        
        let repairLog = ValidationRepairLog(
            lemma: originalResponse.lemma,
            originalExplanationLength: originalResponse.explanationJA.count,
            repairedExplanationLength: repairedResponse.explanationJA.count,
            originalRelatedCount: originalResponse.related.count,
            repairedRelatedCount: repairedResponse.related.count,
            errorType: String(describing: error),
            timestamp: Date()
        )
        
        validationStats.repairHistory.append(repairLog)
        
        // Keep only recent repair history
        if validationStats.repairHistory.count > 100 {
            validationStats.repairHistory.removeFirst()
        }
    }
    
    private func recordValidationFailure(error: Error) {
        validationStats.totalRequests += 1
        validationStats.failedValidations += 1
        
        logger.error("Validation failure: \(error.localizedDescription)")
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