import SwiftUI

struct StudyModeView: View {
    let nodes: [WordNode]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var showingAnswer = false
    
    private var reviewableNodes: [WordNode] {
        nodes.filter { node in
            guard let nextReview = node.nextReviewAt else { return true }
            return nextReview <= Date()
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if reviewableNodes.isEmpty {
                    ContentUnavailableView(
                        "No words to review",
                        systemImage: "book.closed",
                        description: Text("Add some words to your vocabulary tree first.")
                    )
                } else {
                    let currentNode = reviewableNodes[currentIndex]
                    
                    // Progress
                    ProgressView(value: Double(currentIndex + 1), total: Double(reviewableNodes.count))
                        .padding()
                    
                    Text("\(currentIndex + 1) / \(reviewableNodes.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Question
                    VStack(spacing: 20) {
                        Text("What does this word mean?")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text(currentNode.lemma)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        
                        if let pos = currentNode.pos {
                            Text("(\(pos))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if showingAnswer {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(currentNode.explanationJA)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                
                                if let example = currentNode.exampleEN {
                                    Text(example)
                                        .font(.subheadline)
                                        .italic()
                                        .padding()
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Action buttons
                    if showingAnswer {
                        VStack(spacing: 12) {
                            Text("How well did you know this word?")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                Button("Forgot") {
                                    rateWord(rating: 0)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                
                                Button("Difficult") {
                                    rateWord(rating: 1)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                                
                                Button("Easy") {
                                    rateWord(rating: 2)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                            }
                        }
                        .padding()
                    } else {
                        Button("Show Answer") {
                            withAnimation {
                                showingAnswer = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
            }
            .navigationTitle("Study Mode")
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
    
    private func rateWord(rating: Int) {
        let currentNode = reviewableNodes[currentIndex]
        
        // Update SRS parameters based on rating
        switch rating {
        case 0: // Forgot
            currentNode.ease = max(2.0, currentNode.ease - 0.2)
            currentNode.nextReviewAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        case 1: // Difficult
            currentNode.nextReviewAt = Calendar.current.date(byAdding: .day, value: Int(currentNode.ease * 1.2), to: Date())
        case 2: // Easy
            currentNode.ease += 0.05
            currentNode.nextReviewAt = Calendar.current.date(byAdding: .day, value: Int(currentNode.ease * 2.5), to: Date())
        default:
            break
        }
        
        // Move to next word or finish
        if currentIndex < reviewableNodes.count - 1 {
            currentIndex += 1
            showingAnswer = false
        } else {
            dismiss()
        }
    }
}