import Foundation

enum RelationType: String, Codable, CaseIterable {
    case synonym
    case antonym
    case associate
    case etymology
    case collocation
    
    var displayName: String {
        switch self {
        case .synonym: return "Synonym"
        case .antonym: return "Antonym"
        case .associate: return "Associate"
        case .etymology: return "Etymology"
        case .collocation: return "Collocation"
        }
    }
    
    var color: String {
        switch self {
        case .synonym: return "blue"
        case .antonym: return "red"
        case .associate: return "gray"
        case .etymology: return "teal"
        case .collocation: return "indigo"
        }
    }
}