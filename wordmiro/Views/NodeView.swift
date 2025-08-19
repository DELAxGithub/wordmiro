import SwiftUI

struct NodeView: View {
    let node: WordNode
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(node.lemma)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if let pos = node.pos {
                Text(pos)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(
                    isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .shadow(
            color: .black.opacity(0.1),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: isSelected ? 4 : 2
        )
    }
}