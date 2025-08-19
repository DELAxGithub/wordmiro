# WordMiro

Interactive English vocabulary memory tree app for iPad with LLM-powered automatic expansion.

## Overview

WordMiro creates visual memory trees for IELTS Reading 7.5-8.0 level vocabulary, where each word expands into related terms (synonyms, antonyms, etymology, collocations) with ~400-character Japanese explanations. The app combines handwritten memory tree learning effectiveness with LLM intelligence and interactive iPad UI.

## Features

### Core Functionality
- **Word Search & Expansion**: Enter words to generate related vocabulary networks via LLM API
- **Interactive Canvas**: Pinch-to-zoom, pan, drag nodes, tap for details
- **Detail Cards**: Japanese explanations (~400 chars), examples (EN/JA), part of speech, register
- **Auto Layout**: Fruchterman-Reingold force-directed layout algorithm
- **Study Mode**: Spaced repetition system (SRS) with 3-level difficulty rating
- **Data Persistence**: SwiftData local storage with JSON export/import

### iPad Optimizations
- **Multi-orientation**: Portrait/landscape support
- **Split View**: Full compatibility with iPad multitasking
- **Pointer Support**: Hover effects and cursor interactions
- **Keyboard Shortcuts**: Cmd+F (search), Cmd+0 (fit), Cmd+L (layout)
- **Dark Mode**: Full system appearance support

## Technical Stack

- **Framework**: SwiftUI + SwiftData
- **Architecture**: MVVM pattern
- **Minimum OS**: iPadOS 17.0+
- **Target Device**: iPad (optimized for large screens)
- **Dependencies**: None (pure Apple frameworks)

## Project Structure

```
WordMiro/
├── App/
│   └── WordMiroApp.swift           # Main app entry point
├── Models/
│   ├── WordNode.swift              # SwiftData word model
│   ├── WordEdge.swift              # Word relationship model
│   └── RelationType.swift          # Relationship types enum
├── Views/
│   ├── ContentView.swift           # Main board screen
│   ├── CanvasView.swift            # Interactive vocabulary canvas
│   ├── NodeView.swift              # Individual word nodes
│   ├── DetailCardView.swift        # Word detail modal
│   └── StudyModeView.swift         # SRS study interface
├── ViewModels/
│   └── CanvasViewModel.swift       # MVVM business logic
├── Services/
│   ├── LLMService.swift            # API communication layer
│   └── LayoutService.swift         # Force-directed layout algorithms
└── Resources/
    └── Info.plist                  # iPad configuration
```

## Development Setup

### Prerequisites
- Xcode 15.0+ 
- iOS 17.0+ SDK
- iPad for testing (recommended)

### Build & Run
1. Open `WordMiro.xcodeproj` in Xcode
2. Select iPad simulator or device
3. Build and run (⌘R)

### Configuration
- **Bundle ID**: `com.personal.wordmiro`
- **Team**: Configure development team in project settings
- **Capabilities**: File sharing enabled for JSON export

## API Integration

The app uses a Backend-for-Frontend (BFF) service for LLM integration:

### Endpoint
```
POST /expand
Content-Type: application/json

{
  "lemma": "ubiquitous",
  "locale": "ja", 
  "max_related": 12
}
```

### Response Schema
```json
{
  "lemma": "ubiquitous",
  "pos": "adjective",
  "register": "ややフォーマル",
  "explanation_ja": "約400字の日本語解説...",
  "example_en": "English example sentence",
  "example_ja": "日本語例文",
  "related": [
    {"term": "omnipresent", "relation": "synonym"},
    {"term": "scarce", "relation": "antonym"},
    {"term": "ubiquity", "relation": "etymology"}
  ]
}
```

**Development Note**: Currently uses mock responses for development. Update `LLMService.swift` baseURL for production API.

## Data Models

### WordNode
- Unique lemma (normalized, lowercase)
- Japanese explanation (~400 chars)
- English/Japanese examples
- Canvas position (x, y coordinates)
- SRS metadata (ease factor, next review date)
- Expansion state

### WordEdge  
- Directional relationships between nodes
- Relationship types: synonym, antonym, associate, etymology, collocation
- Visual styling based on relationship type

### Export Format
JSON v1 schema with full node/edge data for cross-device sharing.

## Performance Targets

- **Response Time**: /expand API P95 < 2.5s (400ms cached)
- **Frame Rate**: 60fps with 200 nodes, 300 edges (30fps minimum)
- **Memory**: < 350MB peak usage
- **Stability**: 0 crashes in 100 consecutive expansions

## Future Enhancements

- Real-time collaborative editing
- Handwriting/freeform notes
- Image attachments
- Web version
- Advanced dictionary API integration
- Server-side user management

## License

Personal use application. LLM-generated content attribution as per service terms.