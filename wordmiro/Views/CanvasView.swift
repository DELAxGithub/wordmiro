import SwiftUI
import SwiftData

struct CanvasView: View {
    let nodes: [WordNode]
    let edges: [WordEdge]
    @Binding var selectedNode: WordNode?
    @State private var offset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var draggedNode: WordNode?
    @State private var dragOffset = CGSize.zero
    @State private var hoveredEdge: WordEdge?
    @State private var selectedEdge: WordEdge?
    @StateObject private var performanceMetrics = PerformanceMetrics.shared
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
            
            // Transform container
            ZStack {
                // Render edges using optimized EdgeRenderer
                Canvas { context, size in
                    performanceMetrics.markFrameStart()
                    
                    EdgeRenderer.drawEdges(
                        context: context,
                        nodes: nodes,
                        edges: edges,
                        draggedNode: draggedNode,
                        dragOffset: dragOffset,
                        hoveredEdge: hoveredEdge,
                        selectedEdge: selectedEdge
                    )
                    
                    performanceMetrics.markFrameEnd()
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleCanvasInteraction(at: value.location)
                        }
                )
                .onHover { _ in
                    // Hover handling for desktop/iPad with trackpad
                }
                #if os(iOS)
                .onTapGesture { location in
                    handleEdgeTap(at: location)
                }
                #endif
                
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
            
            // Performance overlay (top-right corner)
            if performanceMetrics.isPerformanceOverlayEnabled {
                VStack {
                    HStack {
                        Spacer()
                        PerformanceOverlay(metrics: performanceMetrics)
                            .frame(width: 200)
                    }
                    Spacer()
                }
                .padding()
            }
            
            // Edge relationship details overlay
            if let selectedEdge = selectedEdge {
                VStack {
                    Spacer()
                    EdgeDetailsOverlay(edge: selectedEdge, nodes: nodes)
                        .padding(.bottom, 100) // Above scale warning
                }
            }
            
            // Scale warning overlay (bottom)
            if performanceMetrics.shouldShowScaleWarning() {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(performanceMetrics.getScaleWarningMessage())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Optimize") {
                            // Trigger layout optimization
                            LayoutService.shared.applyForceDirectedLayout(
                                nodes: nodes, 
                                edges: edges
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
                .padding()
            }
        }
        .clipped()
        .onAppear {
            performanceMetrics.updateNodeEdgeCount(nodes: nodes.count, edges: edges.count)
        }
        .onChange(of: nodes.count) { count in
            performanceMetrics.updateNodeEdgeCount(nodes: count, edges: edges.count)
        }
        .onChange(of: edges.count) { count in
            performanceMetrics.updateNodeEdgeCount(nodes: nodes.count, edges: count)
        }
    }
    
    // MARK: - Edge Interaction Handling
    
    private func handleCanvasInteraction(at location: CGPoint) {
        // Convert screen coordinates to canvas coordinates
        let canvasLocation = convertToCanvasCoordinates(location)
        
        // Create node position map for hit testing
        let nodePositions = createNodePositionMap()
        
        // Test for edge hover
        let hitEdge = EdgeRenderer.hitTestEdge(
            point: canvasLocation,
            edges: edges,
            nodePositions: nodePositions,
            tolerance: 15
        )
        
        if hoveredEdge != hitEdge {
            withAnimation(.easeInOut(duration: 0.2)) {
                hoveredEdge = hitEdge
            }
        }
    }
    
    private func handleEdgeTap(at location: CGPoint) {
        let canvasLocation = convertToCanvasCoordinates(location)
        let nodePositions = createNodePositionMap()
        
        let tappedEdge = EdgeRenderer.hitTestEdge(
            point: canvasLocation,
            edges: edges,
            nodePositions: nodePositions,
            tolerance: 20
        )
        
        if let edge = tappedEdge {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedEdge = (selectedEdge == edge) ? nil : edge
            }
        } else {
            // Tap on empty space - clear edge selection
            if selectedEdge != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedEdge = nil
                }
            }
        }
    }
    
    private func convertToCanvasCoordinates(_ screenLocation: CGPoint) -> CGPoint {
        // Adjust for canvas transform (scale and offset)
        let adjustedX = (screenLocation.x - offset.width) / scale
        let adjustedY = (screenLocation.y - offset.height) / scale
        return CGPoint(x: adjustedX, y: adjustedY)
    }
    
    private func createNodePositionMap() -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        
        for node in nodes {
            let basePosition = CGPoint(x: node.x, y: node.y)
            if draggedNode?.id == node.id {
                positions[node.id] = CGPoint(
                    x: basePosition.x + Double(dragOffset.width),
                    y: basePosition.y + Double(dragOffset.height)
                )
            } else {
                positions[node.id] = basePosition
            }
        }
        
        return positions
    }
}