import SwiftUI

struct DetailCardView: View {
    let node: WordNode
    let viewModel: CanvasViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(node.lemma)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            if !node.expanded {
                                Button("Expand") {
                                    viewModel.expandNode(node)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        
                        HStack {
                            if let pos = node.pos {
                                Text(pos)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                    .font(.caption)
                            }
                            
                            if let register = node.register {
                                Text(register)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("説明")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(node.explanationJA)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    
                    // Examples
                    if let exampleEN = node.exampleEN {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("例文")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exampleEN)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                
                                if let exampleJA = node.exampleJA {
                                    Text(exampleJA)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}