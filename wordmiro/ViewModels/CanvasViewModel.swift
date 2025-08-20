import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var selectedNode: WordNode?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let llmService = LLMService.shared
    private let layoutService = LayoutService.shared
    private let performanceMetrics = PerformanceMetrics.shared
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func expandWord(_ lemma: String) {
        guard !lemma.isEmpty else { return }
        
        let normalizedLemma = lemma.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if node already exists
        if let existingNode = findNode(by: normalizedLemma) {
            selectedNode = existingNode
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let startTime = CACurrentMediaTime()
        
        // Use configured LLM service
        llmService.expandWord(lemma: normalizedLemma)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                        
                        // Record network performance
                        let responseTime = CACurrentMediaTime() - startTime
                        self?.performanceMetrics.recordNetworkResponse(time: responseTime)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.createNodeFromResponse(response)
                }
            )
            .store(in: &cancellables)
    }
    
    func expandNode(_ node: WordNode) {
        guard !node.expanded else { return }
        
        isLoading = true
        errorMessage = nil
        
        llmService.expandWord(lemma: node.lemma)
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    self?.addChildNodesToNode(node, response: response)
                }
            )
            .store(in: &cancellables)
    }
    
    func autoArrangeNodes() {
        guard let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<WordNode>()
            let nodes = try modelContext.fetch(descriptor)
            
            let edgeDescriptor = FetchDescriptor<WordEdge>()
            let edges = try modelContext.fetch(edgeDescriptor)
            
            // Measure layout performance
            performanceMetrics.measureLayoutPerformance {
                layoutService.applyForceDirectedLayout(nodes: nodes, edges: edges)
            }
            
            try modelContext.save()
        } catch {
            errorMessage = "Failed to arrange nodes: \(error.localizedDescription)"
        }
    }
    
    func togglePerformanceOverlay() {
        performanceMetrics.isPerformanceOverlayEnabled.toggle()
    }
    
    private func findNode(by lemma: String) -> WordNode? {
        guard let modelContext = modelContext else { return nil }
        
        do {
            let descriptor = FetchDescriptor<WordNode>(
                predicate: #Predicate { $0.lemma == lemma }
            )
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }
    
    private func createNodeFromResponse(_ response: ExpandResponse) {
        guard let modelContext = modelContext else { return }
        
        let newNode = WordNode(
            lemma: response.lemma,
            explanationJA: response.explanationJA,
            pos: response.pos,
            register: response.register
        )
        
        newNode.exampleEN = response.exampleEN
        newNode.exampleJA = response.exampleJA
        
        // Position at center if first node
        do {
            let descriptor = FetchDescriptor<WordNode>()
            let existingNodes = try modelContext.fetch(descriptor)
            
            if existingNodes.isEmpty {
                newNode.x = 0
                newNode.y = 0
            } else {
                newNode.x = Double.random(in: -200...200)
                newNode.y = Double.random(in: -200...200)
            }
        } catch {
            newNode.x = 0
            newNode.y = 0
        }
        
        modelContext.insert(newNode)
        
        // Create child nodes and edges
        createRelatedNodes(parent: newNode, relatedWords: response.related)
        
        selectedNode = newNode
        
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save node: \(error.localizedDescription)"
        }
    }
    
    private func addChildNodesToNode(_ parentNode: WordNode, response: ExpandResponse) {
        parentNode.expanded = true
        createRelatedNodes(parent: parentNode, relatedWords: response.related)
        
        do {
            try modelContext?.save()
        } catch {
            errorMessage = "Failed to expand node: \(error.localizedDescription)"
        }
    }
    
    private func createRelatedNodes(parent: WordNode, relatedWords: [RelatedWord]) {
        guard let modelContext = modelContext else { return }
        
        var newChildren: [WordNode] = []
        
        for relatedWord in relatedWords {
            let normalizedTerm = relatedWord.term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if node already exists
            let existingNode = findNode(by: normalizedTerm)
            let childNode: WordNode
            
            if let existing = existingNode {
                childNode = existing
            } else {
                childNode = WordNode(
                    lemma: normalizedTerm,
                    explanationJA: "Related to \(parent.lemma)" // Placeholder
                )
                modelContext.insert(childNode)
                newChildren.append(childNode)
            }
            
            // Create edge if it doesn't exist
            if !edgeExists(from: parent.id, to: childNode.id) {
                let relationshipType = RelationType(rawValue: relatedWord.relation) ?? .associate
                let edge = WordEdge(from: parent.id, to: childNode.id, type: relationshipType)
                modelContext.insert(edge)
            }
        }
        
        // Arrange new children in circle around parent
        if !newChildren.isEmpty {
            let radius = layoutService.calculateOptimalRadius(childCount: newChildren.count)
            layoutService.arrangeChildrenInCircle(parent: parent, children: newChildren, radius: radius)
        }
    }
    
    private func edgeExists(from: UUID, to: UUID) -> Bool {
        guard let modelContext = modelContext else { return false }
        
        do {
            let descriptor = FetchDescriptor<WordEdge>(
                predicate: #Predicate { edge in
                    (edge.from == from && edge.to == to) ||
                    (edge.from == to && edge.to == from)
                }
            )
            let edges = try modelContext.fetch(descriptor)
            return !edges.isEmpty
        } catch {
            return false
        }
    }
}