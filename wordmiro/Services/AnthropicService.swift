import Foundation
import Combine

struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let temperature: Double
    let system: String
    let messages: [AnthropicMessage]
    
    enum CodingKeys: String, CodingKey {
        case model, system, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct AnthropicContent: Codable {
    let type: String
    let text: String
}

struct AnthropicResponse: Codable {
    let content: [AnthropicContent]
}

class AnthropicService {
    private let baseURL = "https://api.anthropic.com/v1"
    private let keychain = KeychainService.shared
    
    func expandWord(lemma: String, locale: String = "ja") -> AnyPublisher<ExpandResponse, Error> {
        guard let apiKey = keychain.loadAnthropicKey(), !apiKey.isEmpty else {
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
        
        JSON以外の出力・箇条書き・改行装飾は禁止です。文字数は約400字厳守してください。
        """
        
        let messages = [
            AnthropicMessage(role: "user", content: userPrompt)
        ]
        
        let request = AnthropicRequest(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 1000,
            temperature: 0.3,
            system: systemPrompt,
            messages: messages
        )
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: AnthropicResponse.self, decoder: JSONDecoder())
            .tryMap { response in
                guard let content = response.content.first else {
                    throw LLMError.noResponse
                }
                
                let jsonString = content.text
                guard let jsonData = jsonString.data(using: .utf8) else {
                    throw LLMError.invalidResponse
                }
                
                return try JSONDecoder().decode(ExpandResponse.self, from: jsonData)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}