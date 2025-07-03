# Screenshot Notes

A beautiful and intuitive iOS application for automatically organizing, searching, and contextualizing screenshots using on-device AI.

## Project Status

**Current Sprint**: Sprint 1 Complete ✅  
**Next Sprint**: Sprint 2 - AI Integration

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
│   ├── ContentView.swift         # Main photo picker and list view
│   └── ScreenshotDetailView.swift # Full-screen screenshot viewer
├── ViewModels/                    # MVVM business logic
│   └── ScreenshotListViewModel.swift # Import and list management
├── Models/                        # Data models
│   └── Screenshot.swift          # SwiftData screenshot entity
├── Services/                      # Service layer
│   ├── ImageStorageService.swift # File storage management
│   └── HapticService.swift       # Haptic feedback system
└── Assets.xcassets/              # App assets and icons
    └── AppIcon.appiconset/       # Custom brain-themed app icon
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

### Sprint 1: Manual Import MVP ✅
- [x] PhotosPicker integration for manual import
- [x] Image storage and retrieval system
- [x] Import progress tracking with haptic feedback
- [x] Chronological grid view with visual layout
- [x] Full-screen detail view for screenshots
- [x] Swipe-to-delete functionality with confirmation
- [x] Error handling and user feedback
- [x] Custom app icon integration

### Sprint 2: AI Integration (Next)
- [ ] OCR text extraction using Vision framework
- [ ] Object recognition and tagging
- [ ] Search functionality across screenshot content
- [ ] Smart categorization and grouping

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