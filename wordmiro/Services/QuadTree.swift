import Foundation
import CoreGraphics

/// QuadTree implementation for Barnes-Hut force approximation
/// Optimizes repulsion force calculations from O(N²) to O(N log N)
class QuadTree {
    private let boundary: CGRect
    private let capacity: Int
    private var points: [QuadTreePoint] = []
    private var children: [QuadTree] = []
    private var centerOfMass: CGPoint = .zero
    private var totalMass: Double = 0.0
    private var isLeaf: Bool = true
    
    // Barnes-Hut approximation threshold
    private let theta: Double = 0.5
    
    init(boundary: CGRect, capacity: Int = 1) {
        self.boundary = boundary
        self.capacity = capacity
    }
    
    func insert(point: QuadTreePoint) -> Bool {
        // Check if point is within boundary
        guard boundary.contains(point.position) else {
            return false
        }
        
        // Update center of mass
        let newTotalMass = totalMass + point.mass
        if newTotalMass > 0 {
            centerOfMass.x = (centerOfMass.x * totalMass + point.position.x * point.mass) / newTotalMass
            centerOfMass.y = (centerOfMass.y * totalMass + point.position.y * point.mass) / newTotalMass
        }
        totalMass = newTotalMass
        
        // If we have capacity and no children, add point
        if isLeaf && points.count < capacity {
            points.append(point)
            return true
        }
        
        // If we're at capacity, subdivide
        if isLeaf {
            subdivide()
        }
        
        // Try to insert in children
        for child in children {
            if child.insert(point: point) {
                return true
            }
        }
        
        return false
    }
    
    private func subdivide() {
        let x = boundary.minX
        let y = boundary.minY
        let w = boundary.width / 2
        let h = boundary.height / 2
        
        children = [
            QuadTree(boundary: CGRect(x: x, y: y, width: w, height: h), capacity: capacity),
            QuadTree(boundary: CGRect(x: x + w, y: y, width: w, height: h), capacity: capacity),
            QuadTree(boundary: CGRect(x: x, y: y + h, width: w, height: h), capacity: capacity),
            QuadTree(boundary: CGRect(x: x + w, y: y + h, width: w, height: h), capacity: capacity)
        ]
        
        // Redistribute existing points
        for point in points {
            for child in children {
                if child.insert(point: point) {
                    break
                }
            }
        }
        
        points.removeAll()
        isLeaf = false
    }
    
    /// Calculate force on a point using Barnes-Hut approximation
    func calculateForce(on point: QuadTreePoint, k: Double) -> CGPoint {
        // If this is an empty node, no force
        guard totalMass > 0 else { return .zero }
        
        let dx = centerOfMass.x - point.position.x
        let dy = centerOfMass.y - point.position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Avoid self-interaction
        guard distance > 0.1 else { return .zero }
        
        // If this is a leaf node or the node is far enough away, use approximation
        if isLeaf || (boundary.width / distance) < theta {
            let force = k * k * totalMass / (distance * distance)
            return CGPoint(
                x: (dx / distance) * force,
                y: (dy / distance) * force
            )
        }
        
        // Otherwise, recursively calculate forces from children
        var totalForce = CGPoint.zero
        for child in children {
            let childForce = child.calculateForce(on: point, k: k)
            totalForce.x += childForce.x
            totalForce.y += childForce.y
        }
        
        return totalForce
    }
    
    /// Get all points in a given range (for debugging/visualization)
    func query(range: CGRect) -> [QuadTreePoint] {
        var result: [QuadTreePoint] = []
        
        // If range doesn't intersect boundary, return empty
        guard boundary.intersects(range) else { return result }
        
        // Add points that are in range
        for point in points {
            if range.contains(point.position) {
                result.append(point)
            }
        }
        
        // Recursively query children
        for child in children {
            result.append(contentsOf: child.query(range: range))
        }
        
        return result
    }
    
    /// Clear all points from the tree
    func clear() {
        points.removeAll()
        children.removeAll()
        centerOfMass = .zero
        totalMass = 0.0
        isLeaf = true
    }
    
    /// Get statistics about the tree structure
    func getStats() -> QuadTreeStats {
        var stats = QuadTreeStats()
        collectStats(&stats)
        return stats
    }
    
    private func collectStats(_ stats: inout QuadTreeStats) {
        stats.nodeCount += 1
        stats.pointCount += points.count
        
        if isLeaf {
            stats.leafCount += 1
            stats.maxDepth = max(stats.maxDepth, stats.currentDepth)
        } else {
            for child in children {
                stats.currentDepth += 1
                child.collectStats(&stats)
                stats.currentDepth -= 1
            }
        }
    }
}

/// Represents a point in the QuadTree with mass for Barnes-Hut calculations
struct QuadTreePoint {
    let id: UUID
    let position: CGPoint
    let mass: Double
    
    init(id: UUID, position: CGPoint, mass: Double = 1.0) {
        self.id = id
        self.position = position
        self.mass = mass
    }
}

/// Statistics about QuadTree structure for performance monitoring
struct QuadTreeStats {
    var nodeCount: Int = 0
    var leafCount: Int = 0
    var pointCount: Int = 0
    var maxDepth: Int = 0
    var currentDepth: Int = 0
    
    var averagePointsPerLeaf: Double {
        return leafCount > 0 ? Double(pointCount) / Double(leafCount) : 0
    }
    
    var efficiency: Double {
        // Efficiency metric: lower is better (closer to O(N log N))
        return pointCount > 0 ? Double(nodeCount) / Double(pointCount) : 0
    }
}