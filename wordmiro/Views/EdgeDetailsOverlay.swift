import SwiftUI

/// Overlay showing details about a selected edge relationship
struct EdgeDetailsOverlay: View {
    let edge: WordEdge
    let nodes: [WordNode]
    
    private var fromNode: WordNode? {
        nodes.first { $0.id == edge.from }
    }
    
    private var toNode: WordNode? {
        nodes.first { $0.id == edge.to }
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 8) {
                // Header with relationship type
                HStack {
                    Image(systemName: relationshipIcon)
                        .foregroundColor(relationshipColor)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(edge.relationship.accessibilityName)
                            .font(.headline)
                            .foregroundColor(relationshipColor)
                        
                        Text("Relationship")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(edge.relationship.symbol)
                        .font(.title)
                        .foregroundColor(relationshipColor)
                        .bold()
                }
                
                Divider()
                
                // Connection details
                if let fromNode = fromNode, let toNode = toNode {
                    VStack(alignment: .leading, spacing: 6) {
                        RelationshipConnectionView(
                            fromWord: fromNode.lemma,
                            toWord: toNode.lemma,
                            relationshipType: edge.relationship
                        )
                        
                        if let explanation = relationshipExplanation {
                            Text(explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                
                // Quick actions
                HStack {
                    Button(action: {
                        // Expand from node if not already expanded
                        if let fromNode = fromNode, !fromNode.expanded {
                            // Trigger expansion
                        }
                    }) {
                        Label("Expand \(fromNode?.lemma ?? "word")", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(fromNode?.expanded == true)
                    
                    Button(action: {
                        // Expand to node if not already expanded
                        if let toNode = toNode, !toNode.expanded {
                            // Trigger expansion
                        }
                    }) {
                        Label("Expand \(toNode?.lemma ?? "word")", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(toNode?.expanded == true)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
            .frame(maxWidth: 300)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var relationshipIcon: String {
        switch edge.relationship {
        case .synonym: return "equal.circle"
        case .antonym: return "multiply.circle"
        case .associate: return "link.circle"
        case .etymology: return "book.circle"
        case .collocation: return "plus.circle"
        }
    }
    
    private var relationshipColor: Color {
        edge.relationship.baseStyle.color
    }
    
    private var relationshipExplanation: String? {
        switch edge.relationship {
        case .synonym:
            return "Words with similar or identical meanings"
        case .antonym:
            return "Words with opposite or contrasting meanings"
        case .associate:
            return "Words commonly used together or in similar contexts"
        case .etymology:
            return "Words sharing common linguistic origins or roots"
        case .collocation:
            return "Words that naturally occur together in speech or writing"
        }
    }
    
    private var accessibilityDescription: String {
        guard let fromNode = fromNode, let toNode = toNode else {
            return "Relationship details"
        }
        
        return EdgeRenderer.accessibilityDescription(for: edge, nodes: nodes)
    }
}

/// Visual representation of the word connection
struct RelationshipConnectionView: View {
    let fromWord: String
    let toWord: String
    let relationshipType: RelationType
    
    var body: some View {
        HStack {
            // From word
            Text(fromWord)
                .font(.subheadline.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            
            // Relationship arrow/symbol
            Image(systemName: arrowSymbol)
                .foregroundColor(relationshipType.baseStyle.color)
                .font(.caption)
            
            // To word
            Text(toWord)
                .font(.subheadline.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    private var arrowSymbol: String {
        switch relationshipType {
        case .synonym, .associate:
            return "arrow.left.and.right"
        case .antonym:
            return "arrow.left.and.right.circle"
        case .etymology:
            return "arrow.down.right"
        case .collocation:
            return "plus"
        }
    }
}

#Preview {
    EdgeDetailsOverlay(
        edge: WordEdge(
            from: UUID(),
            to: UUID(),
            type: .synonym
        ),
        nodes: [
            WordNode(lemma: "ubiquitous", explanationJA: "遍在する"),
            WordNode(lemma: "omnipresent", explanationJA: "至る所に存在する")
        ]
    )
    .padding()
}