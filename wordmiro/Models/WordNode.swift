import Foundation
import SwiftData

@Model
final class WordNode {
    @Attribute(.unique) var id: UUID = UUID()
    var lemma: String
    var pos: String?
    var register: String?
    var explanationJA: String
    var exampleEN: String?
    var exampleJA: String?
    var x: Double = 0
    var y: Double = 0
    var expanded: Bool = false
    var ease: Double = 2.3
    var nextReviewAt: Date?
    
    init(lemma: String, explanationJA: String, pos: String? = nil, register: String? = nil) {
        self.lemma = lemma.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.explanationJA = explanationJA
        self.pos = pos
        self.register = register
    }
    
    // For JSON export
    var exportData: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "lemma": lemma,
            "explanation_ja": explanationJA,
            "x": x,
            "y": y,
            "expanded": expanded,
            "ease": ease
        ]
        
        if let pos = pos { data["pos"] = pos }
        if let register = register { data["register"] = register }
        if let exampleEN = exampleEN { data["example_en"] = exampleEN }
        if let exampleJA = exampleJA { data["example_ja"] = exampleJA }
        if let nextReviewAt = nextReviewAt { 
            data["next_review_at"] = ISO8601DateFormatter().string(from: nextReviewAt)
        }
        
        return data
    }
}