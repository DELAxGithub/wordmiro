import Foundation
import Combine

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

class OpenAIService {
    private let baseURL = "https://api.openai.com/v1"
    private let keychain = KeychainService.shared
    
    func expandWord(lemma: String, locale: String = "ja") -> AnyPublisher<ExpandResponse, Error> {
        guard let apiKey = keychain.loadOpenAIKey(), !apiKey.isEmpty else {
            return Fail(error: LLMError.noAPIKey)
                .eraseToAnyPublisher()
        }
        
        let systemPrompt = """
        あなたは英語語彙の解説専門家です。IELTS Reading 7.5–8.0レベルを想定し、やや硬めの語彙解説を日本語で約400字で作成してください。
        語源/ニュアンス/代表用例（英→日訳）を含め、出力は指定されたJSONのみとしてください。
        """
        
        let userPrompt = """
        語: \(lemma)
        言語: \(locale)
        関係語タイプ: synonym/antonym/associate/etymology/collocation
        各タイプの上限: 3（合計最大12）
        
        以下のJSONスキーマに従って応答してください:
        {
          "lemma": "\(lemma)",
          "pos": "品詞",
          "register": "文体レベル",
          "explanation_ja": "約400字の日本語解説",
          "example_en": "英語例文",
          "example_ja": "日本語例文",
          "related": [
            {"term": "関連語", "relation": "synonym|antonym|associate|etymology|collocation"}
          ]
        }
        
        JSON以外の出力・箇条書き・改行装飾は禁止です。
        """
        
        let messages = [
            OpenAIMessage(role: "system", content: systemPrompt),
            OpenAIMessage(role: "user", content: userPrompt)
        ]
        
        let request = OpenAIRequest(
            model: "gpt-4o",
            messages: messages,
            temperature: 0.3,
            maxTokens: 1000
        )
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .tryMap { response in
                guard let choice = response.choices.first else {
                    throw LLMError.noResponse
                }
                
                let jsonString = choice.message.content
                guard let jsonData = jsonString.data(using: .utf8) else {
                    throw LLMError.invalidResponse
                }
                
                return try JSONDecoder().decode(ExpandResponse.self, from: jsonData)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

enum LLMError: Error, LocalizedError {
    case noAPIKey
    case noResponse
    case invalidResponse
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured"
        case .noResponse:
            return "No response from LLM service"
        case .invalidResponse:
            return "Invalid response format"
        case .invalidJSON:
            return "Invalid JSON in response"
        }
    }
}