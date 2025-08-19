import Foundation
import SwiftData

@Model
final class WordEdge {
    @Attribute(.unique) var id: UUID = UUID()
    var from: UUID
    var to: UUID
    var type: RelationType
    
    init(from: UUID, to: UUID, type: RelationType) {
        self.from = from
        self.to = to
        self.type = type
    }
    
    // For JSON export
    var exportData: [String: Any] {
        return [
            "id": id.uuidString,
            "from": from.uuidString,
            "to": to.uuidString,
            "type": type.rawValue
        ]
    }
}