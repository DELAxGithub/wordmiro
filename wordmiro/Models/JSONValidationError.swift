import Foundation

/// JSON validation error types for BFF responses
enum JSONValidationError: Error, LocalizedError {
    case malformedResponse(String)
    case invalidSchema(String)
    case contentValidationFailed(String)
    case explanationTooShort(Int, minimum: Int)
    case explanationTooLong(Int, maximum: Int)
    case tooManyRelatedTerms(Int, maximum: Int)
    case invalidRelationType(String)
    case duplicateTerms([String])
    case missingRequiredFields([String])
    case autoRepairFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .malformedResponse(let details):
            return "Malformed JSON response: \(details)"
        case .invalidSchema(let details):
            return "JSON schema validation failed: \(details)"
        case .contentValidationFailed(let details):
            return "Content validation failed: \(details)"
        case .explanationTooShort(let length, let minimum):
            return "Explanation too short (\(length) chars, minimum \(minimum))"
        case .explanationTooLong(let length, let maximum):
            return "Explanation too long (\(length) chars, maximum \(maximum))"
        case .tooManyRelatedTerms(let count, let maximum):
            return "Too many related terms (\(count), maximum \(maximum))"
        case .invalidRelationType(let type):
            return "Invalid relation type: \(type)"
        case .duplicateTerms(let terms):
            return "Duplicate terms found: \(terms.joined(separator: ", "))"
        case .missingRequiredFields(let fields):
            return "Missing required fields: \(fields.joined(separator: ", "))"
        case .autoRepairFailed(let reason):
            return "Auto-repair failed: \(reason)"
        }
    }
    
    var recoveryAction: String {
        switch self {
        case .malformedResponse, .invalidSchema:
            return "Please try again. If the problem persists, contact support."
        case .contentValidationFailed, .autoRepairFailed:
            return "Content quality issue detected. Please try a different word."
        case .explanationTooShort, .explanationTooLong:
            return "Explanation length outside acceptable range. Please try again."
        case .tooManyRelatedTerms:
            return "Too many related terms found. Results may be limited."
        case .invalidRelationType:
            return "Unknown relationship type. Some connections may be missing."
        case .duplicateTerms:
            return "Duplicate terms were filtered out."
        case .missingRequiredFields:
            return "Incomplete response. Please try again."
        }
    }
}

/// JSON validation response from BFF
struct ValidationResponse: Codable {
    let valid: Bool
    let errors: [String]?
    let warnings: [String]?
    let repaired: Bool?
    let originalLength: Int?
    let repairedLength: Int?
    
    func toValidationError() -> JSONValidationError? {
        guard !valid else { return nil }
        
        let errorMessage = errors?.joined(separator: "; ") ?? "Unknown validation error"
        return .contentValidationFailed(errorMessage)
    }
}

/// Client-side JSON validation utilities
struct JSONValidator {
    
    static func validateExpandResponse(_ response: ExpandResponse) throws {
        var validationErrors: [String] = []
        
        // Validate explanation length
        let explanationLength = response.explanationJA.count
        if explanationLength < 350 {
            throw JSONValidationError.explanationTooShort(explanationLength, minimum: 350)
        }
        if explanationLength > 450 {
            throw JSONValidationError.explanationTooLong(explanationLength, maximum: 450)
        }
        
        // Validate related terms count
        if response.related.count > 12 {
            throw JSONValidationError.tooManyRelatedTerms(response.related.count, maximum: 12)
        }
        
        // Check for duplicate terms
        let terms = response.related.map { $0.term.lowercased() }
        let uniqueTerms = Set(terms)
        if terms.count != uniqueTerms.count {
            let duplicates = terms.filter { term in
                terms.filter { $0 == term }.count > 1
            }
            throw JSONValidationError.duplicateTerms(Array(Set(duplicates)))
        }
        
        // Validate relation types
        for relatedWord in response.related {
            let validTypes = ["synonym", "antonym", "associate", "etymology", "collocation"]
            if !validTypes.contains(relatedWord.relation) {
                throw JSONValidationError.invalidRelationType(relatedWord.relation)
            }
        }
        
        // Check relationship type limits (max 3 per type)
        let relationTypeCounts = Dictionary(grouping: response.related, by: { $0.relation })
            .mapValues { $0.count }
        
        for (relationType, count) in relationTypeCounts {
            if count > 3 {
                validationErrors.append("Too many \(relationType) relations (\(count), max 3)")
            }
        }
        
        if !validationErrors.isEmpty {
            throw JSONValidationError.contentValidationFailed(validationErrors.joined(separator: "; "))
        }
    }
    
    static func validateRequiredFields(_ response: ExpandResponse) throws {
        var missingFields: [String] = []
        
        if response.lemma.isEmpty {
            missingFields.append("lemma")
        }
        
        if response.explanationJA.isEmpty {
            missingFields.append("explanation_ja")
        }
        
        if response.related.isEmpty {
            missingFields.append("related")
        }
        
        // Validate nested required fields
        for (index, relatedWord) in response.related.enumerated() {
            if relatedWord.term.isEmpty {
                missingFields.append("related[\(index)].term")
            }
            if relatedWord.relation.isEmpty {
                missingFields.append("related[\(index)].relation")
            }
        }
        
        if !missingFields.isEmpty {
            throw JSONValidationError.missingRequiredFields(missingFields)
        }
    }
    
    /// Full client-side validation (fallback when BFF validation isn't available)
    static func validateFullResponse(_ response: ExpandResponse) throws {
        try validateRequiredFields(response)
        try validateExpandResponse(response)
    }
    
    /// Create a sanitized response from potentially invalid data
    static func sanitizeResponse(_ response: ExpandResponse) -> ExpandResponse {
        var sanitized = response
        
        // Truncate explanation if too long
        if sanitized.explanationJA.count > 450 {
            let endIndex = sanitized.explanationJA.index(sanitized.explanationJA.startIndex, offsetBy: 450)
            sanitized.explanationJA = String(sanitized.explanationJA[..<endIndex]) + "..."
        }
        
        // Limit related terms to 12
        if sanitized.related.count > 12 {
            sanitized.related = Array(sanitized.related.prefix(12))
        }
        
        // Remove duplicates
        var seenTerms = Set<String>()
        sanitized.related = sanitized.related.compactMap { relatedWord in
            let lowercaseTerm = relatedWord.term.lowercased()
            if seenTerms.contains(lowercaseTerm) {
                return nil
            }
            seenTerms.insert(lowercaseTerm)
            return relatedWord
        }
        
        // Limit to 3 per relation type
        var relationTypeCounts: [String: Int] = [:]
        sanitized.related = sanitized.related.compactMap { relatedWord in
            let currentCount = relationTypeCounts[relatedWord.relation] ?? 0
            if currentCount >= 3 {
                return nil
            }
            relationTypeCounts[relatedWord.relation] = currentCount + 1
            return relatedWord
        }
        
        return sanitized
    }
}