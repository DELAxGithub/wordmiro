import Foundation
import SwiftUI
import os.log

/// Performance monitoring service for canvas optimization and metrics collection
@MainActor
class PerformanceMetrics: ObservableObject {
    static let shared = PerformanceMetrics()
    
    @Published var currentFPS: Double = 60.0
    @Published var memoryUsageMB: Double = 0.0
    @Published var nodeCount: Int = 0
    @Published var edgeCount: Int = 0
    @Published var lastLayoutTime: TimeInterval = 0.0
    @Published var networkP95: TimeInterval = 0.0
    @Published var isPerformanceOverlayEnabled: Bool = false
    
    // Performance thresholds (NFR compliance)
    let targetFPS: Double = 60.0
    let minimumFPS: Double = 30.0
    let maxMemoryMB: Double = 350.0
    let maxNodes: Int = 200
    let maxEdges: Int = 300
    
    // FPS tracking
    private var frameStartTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private let fpsUpdateInterval: CFTimeInterval = 1.0
    
    // Memory tracking
    private var lastMemoryCheck: CFTimeInterval = 0
    private let memoryCheckInterval: CFTimeInterval = 2.0
    
    // Network response time tracking
    private var networkResponseTimes: [TimeInterval] = []
    private let maxResponseTimesSamples = 100
    
    private let logger = Logger(subsystem: "WordMiro", category: "Performance")
    
    private init() {
        startPerformanceMonitoring()
    }
    
    // MARK: - Performance Monitoring
    
    func startPerformanceMonitoring() {
        frameStartTime = CACurrentMediaTime()
        lastFPSUpdate = frameStartTime
        lastMemoryCheck = frameStartTime
    }
    
    func markFrameStart() {
        let currentTime = CACurrentMediaTime()
        frameStartTime = currentTime
        frameCount += 1
        
        // Update FPS every second
        if currentTime - lastFPSUpdate >= fpsUpdateInterval {
            currentFPS = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
            
            // Log performance warnings
            if currentFPS < minimumFPS {
                logger.warning("FPS below minimum: \(self.currentFPS, privacy: .public)")
            }
        }
        
        // Update memory usage periodically
        if currentTime - lastMemoryCheck >= memoryCheckInterval {
            updateMemoryUsage()
            lastMemoryCheck = currentTime
        }
    }
    
    func markFrameEnd() {
        // Frame timing is handled in markFrameStart
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / (1024 * 1024)
            
            if memoryUsageMB > maxMemoryMB {
                logger.warning("Memory usage exceeds limit: \(self.memoryUsageMB, privacy: .public) MB")
            }
        }
    }
    
    // MARK: - Layout Performance
    
    func measureLayoutPerformance<T>(operation: () throws -> T) rethrows -> T {
        let startTime = CACurrentMediaTime()
        let result = try operation()
        lastLayoutTime = CACurrentMediaTime() - startTime
        
        if lastLayoutTime > 0.1 { // 100ms threshold
            logger.warning("Layout operation took: \(self.lastLayoutTime * 1000, privacy: .public) ms")
        }
        
        return result
    }
    
    // MARK: - Network Performance
    
    func recordNetworkResponse(time: TimeInterval) {
        networkResponseTimes.append(time)
        
        // Keep only recent samples
        if networkResponseTimes.count > maxResponseTimesSamples {
            networkResponseTimes.removeFirst()
        }
        
        // Calculate P95
        if networkResponseTimes.count >= 10 {
            let sorted = networkResponseTimes.sorted()
            let p95Index = Int(Double(sorted.count) * 0.95)
            networkP95 = sorted[min(p95Index, sorted.count - 1)]
        }
        
        if time > 2.5 {
            logger.warning("Network response time exceeded P95 target: \(time, privacy: .public)s")
        }
    }
    
    // MARK: - Scale Management
    
    func updateNodeEdgeCount(nodes: Int, edges: Int) {
        nodeCount = nodes
        edgeCount = edges
        
        if nodes > maxNodes || edges > maxEdges {
            logger.info("Scale warning: \(nodes) nodes, \(edges) edges")
        }
    }
    
    func shouldShowScaleWarning() -> Bool {
        return nodeCount > maxNodes || edgeCount > maxEdges
    }
    
    func getScaleWarningMessage() -> String {
        if nodeCount > maxNodes && edgeCount > maxEdges {
            return "High node and edge count may impact performance. Consider organizing into subgroups."
        } else if nodeCount > maxNodes {
            return "High node count (\(nodeCount)) may impact performance."
        } else if edgeCount > maxEdges {
            return "High edge count (\(edgeCount)) may impact performance."
        }
        return ""
    }
    
    // MARK: - Performance Status
    
    func getPerformanceStatus() -> PerformanceStatus {
        if currentFPS < minimumFPS || memoryUsageMB > maxMemoryMB {
            return .critical
        } else if currentFPS < targetFPS * 0.8 || memoryUsageMB > maxMemoryMB * 0.8 {
            return .warning
        } else {
            return .good
        }
    }
    
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            fps: currentFPS,
            memoryMB: memoryUsageMB,
            nodeCount: nodeCount,
            edgeCount: edgeCount,
            layoutTimeMs: lastLayoutTime * 1000,
            networkP95: networkP95,
            status: getPerformanceStatus()
        )
    }
}

enum PerformanceStatus {
    case good
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

struct PerformanceReport {
    let fps: Double
    let memoryMB: Double
    let nodeCount: Int
    let edgeCount: Int
    let layoutTimeMs: Double
    let networkP95: TimeInterval
    let status: PerformanceStatus
}