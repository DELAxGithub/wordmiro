import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var nodes: [WordNode]
    @Query private var edges: [WordEdge]
    @StateObject private var viewModel = CanvasViewModel()
    @State private var searchText = ""
    @State private var showingStudyMode = false
    @State private var showingSettings = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        TextField("Enter word to expand...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                viewModel.expandWord(searchText)
                                searchText = ""
                            }
                        
                        Button("Search") {
                            viewModel.expandWord(searchText)
                            searchText = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    
                    // Canvas
                    ZStack {
                        Color.gray.opacity(0.1)
                            .ignoresSafeArea()
                        
                        CanvasView(nodes: nodes, edges: edges, selectedNode: $viewModel.selectedNode)
                            .onTapGesture { location in
                                viewModel.selectedNode = nil
                            }
                    }
                    .clipped()
                }
            }
            .navigationTitle("WordMiro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.togglePerformanceOverlay()
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // FAB buttons
                VStack(spacing: 12) {
                    Button {
                        showingStudyMode = true
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    
                    Button {
                        viewModel.autoArrangeNodes()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    
                    Button {
                        addNewNode()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $viewModel.selectedNode) { node in
            DetailCardView(node: node, viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingStudyMode) {
            StudyModeView(nodes: nodes)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            viewModel.setup(modelContext: modelContext)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }
    
    private func addNewNode() {
        searchText = ""
        // Focus on search bar
    }
}