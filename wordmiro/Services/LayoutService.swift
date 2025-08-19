import Foundation
import SwiftUI

class LayoutService {
    static let shared = LayoutService()
    
    private init() {}
    
    // Fruchterman-Reingold layout parameters
    private let k: Double = 100.0 // Optimal distance
    private let iterations = 150
    private let initialTemperature = 100.0
    
    func applyForceDirectedLayout(nodes: [WordNode], edges: [WordEdge], bounds: CGSize = CGSize(width: 800, height: 600)) {
        guard nodes.count > 1 else { return }
        
        var temperature = initialTemperature
        let cooling = pow(0.01 / initialTemperature, 1.0 / Double(iterations))
        
        for iteration in 0..<iterations {
            var forces: [UUID: CGPoint] = [:]
            
            // Initialize forces
            for node in nodes {
                forces[node.id] = CGPoint.zero
            }
            
            // Calculate repulsive forces between all pairs of nodes
            for i in 0..<nodes.count {
                for j in (i + 1)..<nodes.count {
                    let nodeA = nodes[i]
                    let nodeB = nodes[j]
                    
                    let dx = nodeA.x - nodeB.x
                    let dy = nodeA.y - nodeB.y
                    let distance = max(sqrt(dx * dx + dy * dy), 0.1)
                    
                    let force = k * k / distance
                    let fx = (dx / distance) * force
                    let fy = (dy / distance) * force
                    
                    forces[nodeA.id]?.x += fx
                    forces[nodeA.id]?.y += fy
                    forces[nodeB.id]?.x -= fx
                    forces[nodeB.id]?.y -= fy
                }
            }
            
            // Calculate attractive forces for connected nodes
            for edge in edges {
                guard let nodeA = nodes.first(where: { $0.id == edge.from }),
                      let nodeB = nodes.first(where: { $0.id == edge.to }) else { continue }
                
                let dx = nodeA.x - nodeB.x
                let dy = nodeA.y - nodeB.y
                let distance = max(sqrt(dx * dx + dy * dy), 0.1)
                
                let force = distance * distance / k
                let fx = (dx / distance) * force
                let fy = (dy / distance) * force
                
                forces[nodeA.id]?.x -= fx
                forces[nodeA.id]?.y -= fy
                forces[nodeB.id]?.x += fx
                forces[nodeB.id]?.y += fy
            }
            
            // Apply forces with temperature cooling
            for node in nodes {
                guard let force = forces[node.id] else { continue }
                
                let forceLength = sqrt(force.x * force.x + force.y * force.y)
                if forceLength > 0.1 {
                    let displacement = min(forceLength, temperature)
                    node.x += (force.x / forceLength) * displacement
                    node.y += (force.y / forceLength) * displacement
                }
            }
            
            // Keep nodes within bounds
            let margin = 50.0
            for node in nodes {
                node.x = max(-bounds.width/2 + margin, min(bounds.width/2 - margin, node.x))
                node.y = max(-bounds.height/2 + margin, min(bounds.height/2 - margin, node.y))
            }
            
            temperature *= cooling
        }
    }
    
    // Arrange child nodes in a circle around parent
    func arrangeChildrenInCircle(parent: WordNode, children: [WordNode], radius: Double = 120) {
        guard !children.isEmpty else { return }
        
        let angleStep = 2.0 * Double.pi / Double(children.count)
        
        for (index, child) in children.enumerated() {
            let angle = Double(index) * angleStep
            child.x = parent.x + radius * cos(angle)
            child.y = parent.y + radius * sin(angle)
        }
    }
    
    // Calculate optimal radius based on number of children and node size
    func calculateOptimalRadius(childCount: Int, nodeSize: CGSize = CGSize(width: 80, height: 40)) -> Double {
        let circumference = Double(childCount) * max(nodeSize.width, nodeSize.height) * 1.5
        return circumference / (2.0 * Double.pi)
    }
    
    // Center all nodes in the view
    func centerNodes(_ nodes: [WordNode], in bounds: CGSize) {
        guard !nodes.isEmpty else { return }
        
        let minX = nodes.map(\.x).min() ?? 0
        let maxX = nodes.map(\.x).max() ?? 0
        let minY = nodes.map(\.y).min() ?? 0
        let maxY = nodes.map(\.y).max() ?? 0
        
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        let offsetX = -centerX
        let offsetY = -centerY
        
        for node in nodes {
            node.x += offsetX
            node.y += offsetY
        }
    }
}