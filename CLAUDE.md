# WordMiro Development Guidelines

This document defines development principles and practices specific to the WordMiro project, based on the PM review findings and established architecture.

## Project Context

WordMiro is an iPad-optimized English vocabulary learning app that creates interactive memory trees using LLM-powered word expansion. Target users are IELTS Reading 7.5-8.0 level learners.

## Development Principles

### 1. Spec-Driven Development
- All features must have written requirements before implementation
- User stories (US-01, US-02, US-03) are the source of truth
- API contracts (JSON Schema) defined before client integration
- Performance budgets are requirements, not aspirations

### 2. Architecture Boundaries
- **UI Layer**: SwiftUI views with minimal logic
- **ViewModel**: Business logic and state management (MVVM pattern)
- **Services**: External integrations (LLM, persistence, layout)
- **Models**: Data structures with clear responsibilities
- **Repository**: Data access abstraction

### 3. iPad-First Design
- Canvas utilizes full screen real estate
- Multi-orientation support (portrait/landscape)
- Hardware keyboard shortcuts (Cmd+F, Cmd+0, Cmd+L)
- Pointer/trackpad optimization with hover effects
- Large touch targets and gesture-friendly interactions

### 4. Performance as a Feature
- 60fps average, 30fps minimum with 200 nodes/300 edges
- Memory usage under 350MB on iPad Pro M1
- API response P95 < 2.5s (cached < 400ms)
- Render time budget: 16.67ms per frame (60fps)

### 5. LLM Integration Standards
- Temperature 0.2-0.4 for consistent outputs
- JSON Schema validation on all responses
- 400-character explanations (±15% variance acceptable)
- Relationship limits: 3 per type, 12 total maximum
- Automatic content repair pipeline for malformed responses

## Code Standards

### File Organization
```
WordMiro/
├── Models/           # Data structures (WordNode, WordEdge, RelationType)
├── Views/            # SwiftUI interface components
├── ViewModels/       # MVVM business logic
├── Services/         # External integrations and utilities
└── Resources/        # Assets, configuration, legal documents
```

### Naming Conventions
- Models: `WordNode`, `WordEdge`, `RelationType`
- Services: `LLMService`, `LayoutService`, `KeychainService`
- Views: `CanvasView`, `NodeView`, `DetailCardView`
- ViewModels: `CanvasViewModel`, `StudyModeViewModel`

### Error Handling
- Use `Result<Success, Error>` for expected failures
- Network errors should be recoverable with user guidance
- JSON validation failures return structured error messages
- Crash-worthy errors only for unrecoverable states

### Testing Requirements
- Unit tests for business logic (SRS, layout algorithms, data models)
- Integration tests for LLM service contracts
- UI tests for user stories (US-01, US-02, US-03)
- Performance tests for canvas rendering and memory usage

## API Integration Guidelines

### BFF Architecture (Target State)
- Client never stores API keys (Keychain usage temporary)
- All LLM requests go through Backend-for-Frontend service
- Caching with ETag/If-None-Match headers
- Rate limiting: 60 requests/min per device
- Anonymous telemetry for performance monitoring

### JSON Contract Validation
```swift
// All LLM responses must validate against schema
struct ExpandResponse: Codable {
    let lemma: String
    let explanation_ja: String  // 350-450 characters
    let related: [RelatedWord]  // max 12, max 3 per type
    // ... additional fields
}
```

### Error Response Handling
- 422: Malformed request, show user-friendly message
- 429: Rate limited, implement exponential backoff
- 500: Server error, fallback to cached responses
- Timeout: Network error, retry with user confirmation

## UI/UX Standards

### Accessibility Requirements
- VoiceOver support for all interactive elements
- Color-blind friendly design (color + shape + label redundancy)
- Dynamic Type support for text scaling
- Keyboard navigation for all features
- High contrast mode compatibility

### Canvas Interaction Patterns
- Pinch-to-zoom with scale limits (0.5x - 2.0x)
- Two-finger pan for viewport navigation
- Single-finger drag for node positioning
- Tap for selection, double-tap for expansion
- Hover effects on pointer-enabled devices

### Visual Design
- Relationship edge types: solid (synonym), dashed (antonym), dotted (associate)
- Node size based on importance/centrality
- Subtle shadows and rounded corners for depth
- Loading states for all async operations
- Error states with clear recovery actions

## Performance Optimization

### Canvas Rendering
- Use `Canvas` for edge drawing (batched operations)
- CAShapeLayer for complex paths and animations
- Viewport culling for off-screen elements
- Level-of-detail rendering when zoomed out

### Layout Algorithm
- Time-sliced computation (50-100μs per frame)
- Background thread for force calculations
- Main thread only for position updates
- Quadtree optimization for large graphs (>100 nodes)

### Memory Management
- Weak references in delegate patterns
- Image caching with memory pressure handling
- Periodic cleanup of unused SwiftData objects
- Profile regularly with Instruments

## Security & Privacy

### Data Handling
- Only search terms sent to LLM services
- No personal information collected or transmitted
- Local storage encrypted via SwiftData
- Anonymous usage telemetry only

### API Security
- HTTPS-only communications
- API keys rotated regularly (server-side)
- Request signing for BFF authentication
- Input sanitization for all user content

## Quality Gates

### Pre-commit Checks
- Swift code compiles without warnings
- Unit tests pass (>80% coverage target)
- SwiftLint style compliance
- No force unwrapping in production code

### Pre-release Validation
- All user stories pass E2E automation
- Performance benchmarks within targets
- Memory leaks detected via Instruments
- Accessibility validation with Voice Control

### App Store Readiness
- Privacy policy and terms of service complete
- App metadata and screenshots prepared
- Age rating and content warnings accurate
- Review team notes document ready

## Development Workflow

### Issue Management
- Use GitHub issues for all development tasks
- One issue per development session
- Clear acceptance criteria in issue description
- Link related issues and dependencies

### Branch Strategy
- `main` branch always deployable
- Feature branches for individual issues
- PR required for all changes to main
- Automated testing on all PRs

### Documentation
- README reflects current implementation state
- ADR (Architecture Decision Record) for major choices
- Code comments for complex algorithms only
- API documentation for all public interfaces

## Tools and Dependencies

### Required Tools
- Xcode 15.0+ for development
- Instruments for performance profiling
- Accessibility Inspector for compliance testing
- iOS Simulator for cross-device testing

### Framework Usage
- SwiftUI for all interface components
- SwiftData for local persistence
- Combine for reactive programming
- Network for HTTP communications
- Security framework for keychain access

### External Dependencies
- None (pure Apple frameworks for initial version)
- Future: Charts framework for study analytics
- Consider: Zip framework for export features

## Deployment Considerations

### Target Platform
- iPad only (not iPhone compatible)
- iOS 17.0+ minimum deployment target
- Optimized for iPad Pro but supports all iPad models
- App Store distribution exclusively

### Performance Profiles
- Debug: Full logging and debug overlays
- Release: Optimized builds with telemetry
- TestFlight: Beta features with feedback collection
- App Store: Production configuration

---

**These guidelines ensure consistent, high-quality development aligned with WordMiro's educational mission and technical requirements.**