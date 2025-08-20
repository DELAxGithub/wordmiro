import Foundation
import SwiftUI
import os.log

class LayoutService {
    static let shared = LayoutService()
    
    private init() {}
    
    // Fruchterman-Reingold layout parameters
    private let k: Double = 100.0 // Optimal distance
    private let iterations = 150
    private let initialTemperature = 100.0
    
    // Performance optimization parameters
    private let timeSliceBudget: TimeInterval = 0.0001 // 100μs per frame
    private let useQuadTreeThreshold = 50 // Use QuadTree for >50 nodes
    
    private let logger = Logger(subsystem: "WordMiro", category: "Layout")
    
    // Background layout state
    private var layoutTask: Task<Void, Never>?
    private var isLayoutRunning = false
    
    var isRunning: Bool {
        return isLayoutRunning
    }
    
    func cancelLayout() {
        layoutTask?.cancel()
        isLayoutRunning = false
    }
    
    func applyForceDirectedLayout(nodes: [WordNode], edges: [WordEdge], bounds: CGSize = CGSize(width: 800, height: 600)) {
        guard nodes.count > 1 else { return }
        
        // Stop any existing layout task
        layoutTask?.cancel()
        
        // Use optimized algorithm for large graphs
        if nodes.count > useQuadTreeThreshold {
            applyOptimizedLayout(nodes: nodes, edges: edges, bounds: bounds)
        } else {
            applyStandardLayout(nodes: nodes, edges: edges, bounds: bounds)
        }
    }
    
    // Time-sliced background layout for large graphs
    private func applyOptimizedLayout(nodes: [WordNode], edges: [WordEdge], bounds: CGSize) {
        layoutTask = Task { @MainActor in
            isLayoutRunning = true
            defer { isLayoutRunning = false }
            
            var temperature = initialTemperature
            let cooling = pow(0.01 / initialTemperature, 1.0 / Double(iterations))
            
            logger.info("Starting optimized layout for \(nodes.count) nodes")
            let startTime = CACurrentMediaTime()
            
            for iteration in 0..<iterations {
                guard !Task.isCancelled else { break }
                
                let iterationStart = CACurrentMediaTime()
                
                // Build QuadTree for this iteration
                let treeBounds = CGRect(
                    x: -bounds.width, y: -bounds.height,
                    width: bounds.width * 2, height: bounds.height * 2
                )
                let quadTree = QuadTree(boundary: treeBounds)
                
                for node in nodes {
                    let point = QuadTreePoint(
                        id: node.id,
                        position: CGPoint(x: node.x, y: node.y)
                    )
                    quadTree.insert(point: point)
                }
                
                var forces: [UUID: CGPoint] = [:]
                for node in nodes {
                    forces[node.id] = CGPoint.zero
                }
                
                // Calculate repulsive forces using QuadTree (Barnes-Hut)
                for node in nodes {
                    let point = QuadTreePoint(
                        id: node.id,
                        position: CGPoint(x: node.x, y: node.y)
                    )
                    let force = quadTree.calculateForce(on: point, k: k)
                    forces[node.id]?.x += force.x
                    forces[node.id]?.y += force.y
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
                applyBoundaryConstraints(nodes: nodes, bounds: bounds)
                
                temperature *= cooling
                
                // Time slicing: yield control if we've used our budget
                let iterationTime = CACurrentMediaTime() - iterationStart
                if iterationTime > timeSliceBudget {
                    await Task.yield()
                }
            }
            
            let totalTime = CACurrentMediaTime() - startTime
            logger.info("Layout completed in \(totalTime, privacy: .public)s")
        }
    }
    
    // Standard O(N²) layout for smaller graphs
    private func applyStandardLayout(nodes: [WordNode], edges: [WordEdge], bounds: CGSize) {
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
            applyBoundaryConstraints(nodes: nodes, bounds: bounds)
            
            temperature *= cooling
        }
    }
    
    private func applyBoundaryConstraints(nodes: [WordNode], bounds: CGSize) {
        let margin = 50.0
        for node in nodes {
            node.x = max(-bounds.width/2 + margin, min(bounds.width/2 - margin, node.x))
            node.y = max(-bounds.height/2 + margin, min(bounds.height/2 - margin, node.y))
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