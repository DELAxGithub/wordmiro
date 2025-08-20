import SwiftUI
import CoreGraphics
import os.log

/// High-performance edge rendering system with accessibility support
class EdgeRenderer: ObservableObject {
    private let logger = Logger(subsystem: "WordMiro", category: "EdgeRenderer")
    
    @Published var hoveredEdge: WordEdge?
    @Published var selectedEdge: WordEdge?
    
    private let batchRenderingThreshold = 50
    
    /// Render edges using Canvas API for optimal performance
    static func drawEdges(
        context: GraphicsContext,
        nodes: [WordNode],
        edges: [WordEdge],
        draggedNode: WordNode? = nil,
        dragOffset: CGSize = .zero,
        hoveredEdge: WordEdge? = nil,
        selectedEdge: WordEdge? = nil
    ) {
        let nodePositions = createNodePositionMap(
            nodes: nodes,
            draggedNode: draggedNode,
            dragOffset: dragOffset
        )
        
        // Render edges in layers: normal -> hovered -> selected
        let normalEdges = edges.filter { $0 != hoveredEdge && $0 != selectedEdge }
        let hoveredEdges = hoveredEdge.map { [$0] } ?? []
        let selectedEdges = selectedEdge.map { [$0] } ?? []
        
        // Render normal edges
        for edge in normalEdges {
            drawSingleEdge(
                context: context,
                edge: edge,
                nodePositions: nodePositions,
                isHovered: false,
                isSelected: false
            )
        }
        
        // Render hovered edges (highlighted)
        for edge in hoveredEdges {
            drawSingleEdge(
                context: context,
                edge: edge,
                nodePositions: nodePositions,
                isHovered: true,
                isSelected: false
            )
        }
        
        // Render selected edges (most prominent)
        for edge in selectedEdges {
            drawSingleEdge(
                context: context,
                edge: edge,
                nodePositions: nodePositions,
                isHovered: false,
                isSelected: true
            )
        }
    }
    
    private static func createNodePositionMap(
        nodes: [WordNode],
        draggedNode: WordNode?,
        dragOffset: CGSize
    ) -> [UUID: CGPoint] {
        var positions: [UUID: CGPoint] = [:]
        
        for node in nodes {
            let basePosition = CGPoint(x: node.x, y: node.y)
            if draggedNode?.id == node.id {
                positions[node.id] = CGPoint(
                    x: basePosition.x + dragOffset.width,
                    y: basePosition.y + dragOffset.height
                )
            } else {
                positions[node.id] = basePosition
            }
        }
        
        return positions
    }
    
    private static func drawSingleEdge(
        context: GraphicsContext,
        edge: WordEdge,
        nodePositions: [UUID: CGPoint],
        isHovered: Bool,
        isSelected: Bool
    ) {
        guard let fromPos = nodePositions[edge.from],
              let toPos = nodePositions[edge.to] else { return }
        
        let style = getEdgeStyle(
            for: edge.relationship,
            isHovered: isHovered,
            isSelected: isSelected
        )
        
        // Draw the connection line
        drawEdgeLine(
            context: context,
            from: fromPos,
            to: toPos,
            style: style
        )
        
        // Draw relationship symbol if hovered or selected
        if isHovered || isSelected {
            drawRelationshipSymbol(
                context: context,
                from: fromPos,
                to: toPos,
                relationship: edge.relationship,
                style: style
            )
        }
    }
    
    private static func getEdgeStyle(
        for relationship: RelationType,
        isHovered: Bool,
        isSelected: Bool
    ) -> EdgeStyle {
        let baseStyle = relationship.baseStyle
        
        var style = baseStyle
        
        // Adjust for interaction states
        if isSelected {
            style.lineWidth *= 2.0
            style.opacity = 1.0
        } else if isHovered {
            style.lineWidth *= 1.5
            style.opacity = 0.9
        } else {
            style.opacity = 0.6
        }
        
        return style
    }
    
    private static func drawEdgeLine(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        style: EdgeStyle
    ) {
        var path = Path()
        
        // Create smooth curve for better visual flow
        let controlPoint1 = CGPoint(
            x: from.x + (to.x - from.x) * 0.3,
            y: from.y
        )
        let controlPoint2 = CGPoint(
            x: from.x + (to.x - from.x) * 0.7,
            y: to.y
        )
        
        path.move(to: from)
        path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        
        context.stroke(
            path,
            with: .color(style.color.opacity(style.opacity)),
            style: style.strokeStyle
        )
    }
    
    private static func drawRelationshipSymbol(
        context: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        relationship: RelationType,
        style: EdgeStyle
    ) {
        let midPoint = CGPoint(
            x: (from.x + to.x) / 2,
            y: (from.y + to.y) / 2
        )
        
        let symbol = relationship.symbol
        let symbolSize: CGFloat = 16
        
        // Draw background circle for symbol
        let backgroundRect = CGRect(
            x: midPoint.x - symbolSize/2,
            y: midPoint.y - symbolSize/2,
            width: symbolSize,
            height: symbolSize
        )
        
        context.fill(
            Path(ellipseIn: backgroundRect),
            with: .color(.white.opacity(0.9))
        )
        
        context.stroke(
            Path(ellipseIn: backgroundRect),
            with: .color(style.color),
            lineWidth: 1
        )
        
        // Draw symbol text
        let symbolRect = CGRect(
            x: midPoint.x - symbolSize/2,
            y: midPoint.y - symbolSize/2,
            width: symbolSize,
            height: symbolSize
        )
        
        context.draw(
            Text(symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(style.color),
            in: symbolRect
        )
    }
    
    /// Detect edge hit testing for pointer interactions
    static func hitTestEdge(
        point: CGPoint,
        edges: [WordEdge],
        nodePositions: [UUID: CGPoint],
        tolerance: CGFloat = 10
    ) -> WordEdge? {
        for edge in edges {
            guard let fromPos = nodePositions[edge.from],
                  let toPos = nodePositions[edge.to] else { continue }
            
            let distance = distanceFromPointToLine(
                point: point,
                lineStart: fromPos,
                lineEnd: toPos
            )
            
            if distance <= tolerance {
                return edge
            }
        }
        
        return nil
    }
    
    private static func distanceFromPointToLine(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> CGFloat {
        let A = point.x - lineStart.x
        let B = point.y - lineStart.y
        let C = lineEnd.x - lineStart.x
        let D = lineEnd.y - lineStart.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        guard lenSq != 0 else {
            return sqrt(A * A + B * B)
        }
        
        let param = dot / lenSq
        
        let closestPoint: CGPoint
        if param < 0 {
            closestPoint = lineStart
        } else if param > 1 {
            closestPoint = lineEnd
        } else {
            closestPoint = CGPoint(
                x: lineStart.x + param * C,
                y: lineStart.y + param * D
            )
        }
        
        let dx = point.x - closestPoint.x
        let dy = point.y - closestPoint.y
        
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Create accessibility description for an edge
    static func accessibilityDescription(
        for edge: WordEdge,
        nodes: [WordNode]
    ) -> String {
        guard let fromNode = nodes.first(where: { $0.id == edge.from }),
              let toNode = nodes.first(where: { $0.id == edge.to }) else {
            return "Unknown relationship"
        }
        
        let relationshipName = edge.relationship.accessibilityName
        return "\(relationshipName) relationship between \(fromNode.lemma) and \(toNode.lemma)"
    }
}

/// Edge visual styling configuration
struct EdgeStyle {
    let color: Color
    let lineWidth: CGFloat
    let strokeStyle: StrokeStyle
    var opacity: Double = 0.6
    
    init(color: Color, lineWidth: CGFloat, dashPattern: [CGFloat] = []) {
        self.color = color
        self.lineWidth = lineWidth
        self.strokeStyle = StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: dashPattern
        )
    }
}

extension RelationType {
    /// Base visual style for each relationship type
    var baseStyle: EdgeStyle {
        switch self {
        case .synonym:
            return EdgeStyle(color: .blue, lineWidth: 2.0)
        case .antonym:
            return EdgeStyle(color: .red, lineWidth: 2.0, dashPattern: [5, 5])
        case .associate:
            return EdgeStyle(color: .green, lineWidth: 1.5, dashPattern: [2, 3])
        case .etymology:
            return EdgeStyle(color: .purple, lineWidth: 1.5, dashPattern: [8, 4, 2, 4])
        case .collocation:
            return EdgeStyle(color: .orange, lineWidth: 2.5)
        }
    }
    
    /// Symbol for relationship type (color-blind accessibility)
    var symbol: String {
        switch self {
        case .synonym: return "≈"
        case .antonym: return "≠"
        case .associate: return "~"
        case .etymology: return "◊"
        case .collocation: return "+"
        }
    }
    
    /// Accessibility name for VoiceOver
    var accessibilityName: String {
        switch self {
        case .synonym: return "Synonym"
        case .antonym: return "Antonym"
        case .associate: return "Related"
        case .etymology: return "Etymology"
        case .collocation: return "Collocation"
        }
    }
}