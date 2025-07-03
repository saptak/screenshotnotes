
# Screenshot Notes: Iterative Implementation Plan

**Version:** 1.1

**Date:** 2025-07-03

**Status:** Sprint 2 Complete - Automation Engine Delivered

---

## Guiding Principles

This plan is designed to be iterative and agile, ensuring that a usable and functional version of the app (codenamed "Lens") is available at the end of every sprint. Each sprint builds upon the last, progressively adding layers of intelligence, beauty, and refinement.

### Architecture Overview

*   **MVVM Pattern:** Clean separation with SwiftUI Views, ViewModels, and SwiftData Models
*   **Dependency Injection:** Protocol-based services for testability and modularity
*   **Background Processing:** Efficient queuing system for OCR and analysis tasks
*   **Memory Management:** Lazy loading and image caching with automatic cleanup
*   **Error Handling:** Comprehensive error types with user-friendly messaging
*   **Testing Strategy:** Unit tests for business logic, UI tests for critical user flows

### Sprint Success Criteria

Each sprint must meet the following criteria before proceeding:
*   **Functional:** All features work as specified without crashes
*   **Performance:** Meets defined benchmarks (load times, animation smoothness)
*   **Quality:** Code review completed, tests passing, no critical bugs
*   **UX:** User testing validates intuitive interaction patterns

*   **Sprint 0: Foundation & Setup** ✅ **COMPLETED**
    *   **Goal:** Prepare the project environment and architecture.
    *   **Tasks:**
        *   ✅ Initialize a private Git repository.
        *   ✅ Set up Xcode project with Swift Package Manager for dependencies.
        *   ✅ Define basic project structure: Views, ViewModels, Models, Services.
        *   ✅ Establish a basic SwiftUI view hierarchy.
        *   ✅ Set up data persistence using SwiftData with initial schema for a "Screenshot" entity (image data, timestamp).
    *   **Implementation Notes:**
        *   Created GitHub repository: `screenshotnotes` (private)
        *   Xcode project configured for iOS 17+ with SwiftUI and SwiftData
        *   MVVM architecture established with organized folder structure
        *   Screenshot model includes all properties for future sprints (extractedText, objectTags, userNotes, userTags)
        *   Basic ContentView with EmptyStateView and ScreenshotListView components
        *   Asset catalog configured with app icon and accent color placeholders
    *   **Files Created:**
        *   `ScreenshotNotesApp.swift` - Main app entry point with SwiftData container
        *   `Models/Screenshot.swift` - SwiftData model with comprehensive schema
        *   `Views/ContentView.swift` - Main view with list and empty state
        *   Xcode project structure and asset catalogs

*   **Sprint 1: The MVP - Manual & Functional** ✅ **COMPLETED**
    *   **Goal:** A user can manually import a photo and see it in a list.
    *   **Features:**
        *   ✅ Implement a manual import button using `PhotosPicker` to select an image from the Photos library.
        *   ✅ Save the imported image to the app's local storage.
        *   ✅ Display imported screenshots in a simple, chronological list or grid view.
        *   ✅ Implement a detail view to see a single screenshot fullscreen.
        *   ✅ Implement basic deletion functionality from the list view.
    *   **Technical Specifications:**
        *   ✅ SwiftData model: `Screenshot` entity with `id`, `imageData`, `timestamp`, `filename`
        *   ✅ Image storage: In-memory data storage using SwiftData
        *   ✅ List view: LazyVGrid with adaptive columns, minimum 160pt width
        *   ✅ Detail view: Zoomable ScrollView with double-tap to zoom
        *   ✅ Delete: Long-press gesture with confirmation dialog
    *   **Implementation Notes:**
        *   PhotosPicker integration with multi-select support (up to 10 images)
        *   Image optimization and compression before storage (JPEG, 0.8 quality, max 2048px)
        *   Progress tracking with haptic feedback during import operations
        *   Thumbnail grid view with timestamp display (filename removed for cleaner UI)
        *   Full-screen detail view with zoom, pan, and double-tap gestures
        *   Comprehensive error handling with user-friendly messaging
        *   Custom app icon with brain-themed design integrated
        *   MVVM architecture with ImageStorageService and HapticService
    *   **Files Created/Updated:**
        *   `ViewModels/ScreenshotListViewModel.swift` - Import logic and state management
        *   `Views/ScreenshotDetailView.swift` - Full-screen image viewer with gestures
        *   `Services/ImageStorageService.swift` - Image processing and storage
        *   `Services/HapticService.swift` - Centralized haptic feedback
        *   `ContentView.swift` - Updated with thumbnail grid and import flow
        *   `Assets.xcassets/AppIcon.appiconset/` - Custom brain-themed app icon
    *   **UX Focus:** Clean, functional UI with smooth animations and haptic feedback.
    *   **Definition of Done:** ✅ User can import, view, and delete screenshots with smooth animations

*   **Sprint 2: The Automation Engine** ✅ **COMPLETED**
    *   **Goal:** The app automatically detects and imports new screenshots.
    *   **Features:**
        *   ✅ Implement background monitoring of the Photos library for new screenshots using the Photos Framework.
        *   ✅ Create a robust background task handler to import screenshots efficiently.
        *   ✅ Add a user setting (with a simple toggle) to enable/disable automatic import.
        *   ✅ Add the optional setting to delete the original screenshot from the Photos app after import (ensure prominent user warning/permission for this).
    *   **Technical Specifications:**
        *   ✅ PHPhotoLibraryChangeObserver implementation for real-time monitoring
        *   ✅ Background task: BGAppRefreshTask with 30-second time limit
        *   ✅ Settings: UserDefaults-backed ObservableObject for configuration
        *   ✅ Permissions: PHAuthorizationStatus handling with fallback UI
        *   ✅ Filtering: PHAssetMediaSubtype.photoScreenshot for screenshot detection
        *   ✅ Duplicate prevention: Asset identifier-based comparison for reliable deduplication
    *   **Implementation Notes:**
        *   Created PhotoLibraryService with PHPhotoLibraryChangeObserver for automatic detection
        *   Background task registration and scheduling with BGAppRefreshTask
        *   Comprehensive SettingsService with ObservableObject pattern for reactive UI updates
        *   PermissionsView and Settings integration for guided photo library access
        *   Memory-efficient sequential processing to prevent performance issues
        *   Enhanced thumbnail grid with improved spacing (16pt), subtle shadows, and rounded corners
        *   Spring-based animations with scale and opacity transitions for smooth item appearance
        *   Complete Info.plist integration with privacy permission descriptions
    *   **Files Created/Updated:**
        *   `Services/PhotoLibraryService.swift` - Automatic detection and import engine
        *   `Services/BackgroundTaskService.swift` - Background processing coordination
        *   `Services/SettingsService.swift` - User preferences and configuration management
        *   `Views/SettingsView.swift` - Comprehensive settings interface with permission status
        *   `Views/PermissionsView.swift` - Guided photo library permission flow
        *   `Screenshot.swift` - Updated model with assetIdentifier for duplicate prevention
        *   `ContentView.swift` - Enhanced grid layout and settings integration
        *   `ScreenshotNotesApp.swift` - Background task registration and service initialization
        *   `project.pbxproj` - Info.plist privacy permissions for photo library access
    *   **UX Focus:** ✅ Introduced subtle spring animations for new items appearing in the list. Refined the grid view with better spacing (16pt), visual hierarchy, and enhanced thumbnails with shadows.
    *   **Definition of Done:** ✅ App automatically imports new screenshots in background with comprehensive user control

*   **Sprint 3: The Intelligent Eye - Basic OCR & Search**
    *   **Goal:** Users can search for screenshots based on their text content.
    *   **Features:**
        *   Integrate the Vision Framework.
        *   On import, process each screenshot with OCR to extract all text.
        *   Store the extracted text in the database, associated with its screenshot.
        *   Implement a basic search bar that filters the main list/grid based on the OCR text.
    *   **Technical Specifications:**
        *   Vision Framework: VNRecognizeTextRequest with accurate recognition level
        *   SwiftData: Add `extractedText` property to Screenshot model
        *   OCR pipeline: Async processing with progress indicators
        *   Search: Case-insensitive, partial matching with highlighting
        *   Performance: Background queue for OCR, main queue for UI updates
        *   Caching: Store OCR results to avoid reprocessing
    *   **UX Focus:** Design and implement a clean, accessible search interface. Add placeholder text and clear button. The search results should update live and feel responsive.
    *   **Definition of Done:** Users can search screenshots by text content with <100ms response time

*   **Sprint 4: The Glass Aesthetic**
    *   **Goal:** Evolve the UI to be beautiful and fluid, introducing the "Glass UX" language.
    *   **Features:**
        *   Refactor core UI components (lists, navigation bars, detail views) to use translucent materials and background blurs.
        *   Implement smooth, physics-based animations and transitions for all major interactions (opening detail view, searching, deleting).
        *   Design a custom app icon and splash screen.
        *   Choose and implement a clean, modern font.
    *   **Technical Specifications:**
        *   Materials: .ultraThinMaterial and .regularMaterial with proper contrast
        *   Animations: Spring animations with dampingFraction: 0.8, response: 0.6
        *   Transitions: matchedGeometryEffect for hero animations
        *   Gestures: Pan, pinch, and rotation recognizers with proper feedback
        *   Visual hierarchy: Layered backgrounds with proper z-index management
        *   App icon: 1024x1024 vector-based design with iOS icon guidelines
    *   **UX Focus:** The entire app should feel lighter, more responsive, and visually polished. Pay close attention to motion design.
    *   **Definition of Done:** App achieves 60fps animations with polished glass aesthetic

*   **Sprint 5: The Connected Brain - The Mind Map**
    *   **Goal:** Introduce the initial version of the contextual mind map.
    *   **Features:**
        *   Implement basic on-device analysis to find simple links between screenshots (e.g., shared phone numbers, names, or URLs in the OCR text).
        *   Create a new view that visualizes this graph. Screenshots are nodes, and relationships are edges.
        *   Allow users to tap on a node to navigate to that screenshot.
    *   **Technical Specifications:**
        *   SwiftData: Add `Connection` entity with `sourceId`, `targetId`, `relationship`, `confidence`
        *   Algorithm: String similarity matching (Levenshtein distance) for common entities
        *   Visualization: Custom Canvas-based graph with force-directed layout
        *   Gestures: MagnificationGesture and DragGesture for pan/zoom
        *   Performance: Limit to 50 nodes visible at once, clustering for larger sets
        *   Animation: Spring-based node positioning with staggered appearance
    *   **UX Focus:** The graph visualization must be clean and readable. Implement pan and zoom gestures. Animate the layout of the graph to feel organic and alive.
    *   **Definition of Done:** Interactive mind map with smooth navigation and relationship discovery

*   **Sprint 6: Deeper Intelligence & User Context**
    *   **Goal:** Enhance search with more context and allow users to add their own.
    *   **Features:**
        *   Use the Vision Framework to perform basic object recognition on import. Tag screenshots with identified objects (e.g., "cat," "car," "chart").
        *   Expand the search functionality to include these object tags.
        *   Allow users to add manual notes (a simple text field) and tags to each screenshot.
        *   Incorporate user-added text and tags into the search index.
    *   **Technical Specifications:**
        *   Vision Framework: VNClassifyImageRequest for object recognition
        *   SwiftData: Add `objectTags`, `userNotes`, `userTags` properties to Screenshot
        *   Object detection: Confidence threshold of 0.7 for automatic tagging
        *   Search expansion: Combined text + object + user tag indexing
        *   UI: Sheet presentation for note editing with rich text support
        *   Tags: Tokenized input with autocomplete from existing tags
    *   **UX Focus:** Design an elegant and unobtrusive UI for adding and viewing metadata in the detail view.
    *   **Definition of Done:** Enhanced search with object recognition and user annotation capabilities

*   **Sprint 7: Refinement & Final Polish**
    *   **Goal:** Harden the app, optimize performance, and refine all interactions.
    *   **Features:**
        *   Profile and optimize background processing and battery usage.
        *   Refine the mind map UI: allow manual creation/deletion of links.
        *   Add an onboarding flow to explain the app's features and permissions.
        *   Implement comprehensive error handling and user feedback for all operations.
        *   Final review of all animations, haptics, and visual details.
    *   **Technical Specifications:**
        *   Performance: Instruments profiling for memory leaks and CPU usage
        *   Battery optimization: Background task efficiency metrics
        *   Error handling: Comprehensive Result types with localized error messages
        *   Onboarding: Multi-step flow with permission requests and feature preview
        *   Haptics: UIFeedbackGenerator for tactile feedback on interactions
        *   Testing: 90%+ code coverage with unit and UI tests
        *   Analytics: Privacy-focused usage metrics with user consent
    *   **UX Focus:** The app should feel exceptionally reliable, intuitive, and delightful to use from first launch to daily operation.
    *   **Definition of Done:** Production-ready app with comprehensive testing and optimization
