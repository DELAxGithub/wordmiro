import SwiftUI

/// Performance overlay displaying real-time metrics
struct PerformanceOverlay: View {
    @ObservedObject var metrics: PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: metrics.getPerformanceStatus().icon)
                    .foregroundColor(metrics.getPerformanceStatus().color)
                Text("Performance")
                    .font(.caption.bold())
                Spacer()
                Button(action: {
                    metrics.isPerformanceOverlayEnabled.toggle()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 2) {
                MetricRow(
                    label: "FPS",
                    value: String(format: "%.1f", metrics.currentFPS),
                    target: String(format: "%.0f", metrics.targetFPS),
                    isGood: metrics.currentFPS >= metrics.minimumFPS
                )
                
                MetricRow(
                    label: "Memory",
                    value: String(format: "%.1f MB", metrics.memoryUsageMB),
                    target: String(format: "%.0f MB", metrics.maxMemoryMB),
                    isGood: metrics.memoryUsageMB <= metrics.maxMemoryMB
                )
                
                MetricRow(
                    label: "Nodes",
                    value: "\(metrics.nodeCount)",
                    target: "\(metrics.maxNodes)",
                    isGood: metrics.nodeCount <= metrics.maxNodes
                )
                
                MetricRow(
                    label: "Edges",
                    value: "\(metrics.edgeCount)",
                    target: "\(metrics.maxEdges)",
                    isGood: metrics.edgeCount <= metrics.maxEdges
                )
                
                if metrics.lastLayoutTime > 0 {
                    MetricRow(
                        label: "Layout",
                        value: String(format: "%.1f ms", metrics.lastLayoutTime * 1000),
                        target: "< 100 ms",
                        isGood: metrics.lastLayoutTime < 0.1
                    )
                }
                
                if metrics.networkP95 > 0 {
                    MetricRow(
                        label: "Network P95",
                        value: String(format: "%.1f s", metrics.networkP95),
                        target: "< 2.5s",
                        isGood: metrics.networkP95 < 2.5
                    )
                }
            }
            
            if metrics.shouldShowScaleWarning() {
                Divider()
                
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Scale Warning")
                            .font(.caption.bold())
                        Text(metrics.getScaleWarningMessage())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
        .font(.caption)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let target: String
    let isGood: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .foregroundColor(isGood ? .primary : .red)
                .frame(width: 50, alignment: .trailing)
            Text("/ \(target)")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    PerformanceOverlay(metrics: PerformanceMetrics.shared)
        .padding()
}