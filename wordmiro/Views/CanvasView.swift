import SwiftUI
import SwiftData

struct CanvasView: View {
    let nodes: [WordNode]
    @Binding var selectedNode: WordNode?
    @State private var offset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var draggedNode: WordNode?
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
            
            // Transform container
            ZStack {
                // Render nodes
                ForEach(nodes, id: \.id) { node in
                    NodeView(
                        node: node,
                        isSelected: selectedNode?.id == node.id
                    )
                    .position(
                        x: CGFloat(node.x) + (draggedNode?.id == node.id ? dragOffset.width : 0),
                        y: CGFloat(node.y) + (draggedNode?.id == node.id ? dragOffset.height : 0)
                    )
                    .onTapGesture {
                        selectedNode = node
                    }
                    .scaleEffect(draggedNode?.id == node.id ? 1.05 : 1.0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if draggedNode == nil {
                                    draggedNode = node
                                }
                                if draggedNode?.id == node.id {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                if draggedNode?.id == node.id {
                                    node.x += Double(value.translation.width)
                                    node.y += Double(value.translation.height)
                                }
                                draggedNode = nil
                                dragOffset = .zero
                            }
                    )
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    // Pan gesture
                    DragGesture()
                        .onChanged { value in
                            if draggedNode == nil {
                                offset = value.translation
                            }
                        }
                        .onEnded { _ in
                            if draggedNode == nil {
                                // Keep the final offset
                            }
                        },
                    
                    // Zoom gesture
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(0.1, min(3.0, value))
                        }
                        .onEnded { value in
                            withAnimation(.easeOut(duration: 0.2)) {
                                scale = max(0.5, min(2.0, value))
                            }
                        }
                )
            )
        }
        .clipped()
    }
}