# Screenshot Notes

A beautiful and intuitive iOS application for automatically organizing, searching, and contextualizing screenshots using on-device AI.

## Project Status

**Current Sprint**: Sprint 0 Complete ✅  
**Next Sprint**: Sprint 1 - Manual Import MVP

## Features (Planned)

- 🖼️ **Automatic Screenshot Import**: Monitor photo library for new screenshots
- 🔍 **Intelligent Search**: OCR-powered text search within screenshots
- 🧠 **Mind Map Visualization**: AI-generated connections between related screenshots
- 🏷️ **Smart Tagging**: Object recognition and manual tagging
- 📝 **Contextual Notes**: Add personal notes and annotations
- 🎨 **Glass UI Design**: Modern, translucent interface with fluid animations

## Technical Stack

- **Platform**: iOS 17.0+
- **Framework**: SwiftUI
- **Database**: SwiftData
- **Architecture**: MVVM
- **AI/ML**: Vision Framework (OCR, Object Recognition)

## Project Structure

```
ScreenshotNotes/
├── ScreenshotNotesApp.swift       # Main app entry point
├── Views/                         # SwiftUI views
│   └── ContentView.swift         # Main navigation view
├── ViewModels/                    # Business logic
├── Models/                        # Data models
│   └── Screenshot.swift          # Core data model
├── Services/                      # External services
└── Assets.xcassets/              # App assets
```

## Development Setup

1. **Clone Repository**
   ```bash
   git clone https://github.com/saptak/screenshotnotes.git
   cd screenshotnotes
   ```

2. **Open in Xcode**
   ```bash
   open ScreenshotNotes.xcodeproj
   ```

3. **Build and Run**
   - Select iOS Simulator
   - Press Cmd+R to build and run

## Sprint Progress

### Sprint 0: Foundation ✅
- [x] Private Git repository setup
- [x] Xcode project with SwiftUI and SwiftData
- [x] MVVM architecture structure
- [x] Basic Screenshot model with comprehensive schema
- [x] Initial UI components (ContentView, EmptyStateView, ScreenshotListView)
- [x] Asset catalog configuration

### Sprint 1: Manual Import MVP (Next)
- [ ] PhotosPicker integration for manual import
- [ ] Image storage and retrieval
- [ ] Chronological list/grid view
- [ ] Full-screen detail view
- [ ] Swipe-to-delete functionality

## Design Principles

- **Intuitive**: Immediately understandable user journey
- **Fluid**: 120fps animations on ProMotion displays
- **Reliable**: Robust background processing and data integrity
- **Beautiful**: Glass UX with translucency and layered materials

## Documentation

- [Product Requirements Document](prd.md)
- [Implementation Plan](implementation_plan.md)
- [Technical Notes](TECHNICAL_NOTES.md)

## License

Private project - All rights reserved.