# Product Requirements Document: Screenshot Notes

**Version:** 1.1

**Date:** 2025-07-03

**Status:** Sprint 2 Complete - Automatic Screenshot Detection Delivered

---

## 1. Vision & Introduction

Screenshot Notes is a beautiful and intuitive iOS application designed to revolutionize how users manage and interact with their screenshots. In a world where screenshots are a primary method of information capture, this app provides a seamless, intelligent, and fluid experience for automatically organizing, searching, and contextualizing that information. By leveraging the latest in on-device AI, Screenshot Notes transforms a cluttered photo library into an interconnected, searchable knowledge base.

## 2. Target Audience

*   **Power Users & Professionals:** Designers, developers, researchers, and students who rely on screenshots for work, inspiration, and note-taking.
*   **Productivity Enthusiasts:** Individuals who want to optimize their personal information management and reduce digital clutter.
*   **General iOS Users:** Anyone who frequently uses screenshots to save information and struggles to find it later.

## 3. Core Principles & Design Language

The user experience is paramount and will be guided by the following principles:

*   **Intuitive:** The app will be immediately understandable. The user journey, from import to search, will feel natural and require minimal learning.
*   **Fluid & Responsive:** Every interaction, animation, and transition will be smooth, immediate, and delightful, targeting 120fps on ProMotion displays. Design Guidelines: https://developer.apple.com/design/Human-Interface-Guidelines/materials
*   **Reliable:** The app must be exceptionally stable, with robust background processing and data integrity.
*   **Beautiful:** The UI will be clean, modern, and aesthetically pleasing, employing the "Glass UX" language. This involves the use of translucency, layered materials, and depth to create a lightweight and focused environment.

### Design System Specifications

*   **Color Palette:**
    *   Primary: Dynamic system colors adapting to light/dark mode
    *   Glass effects: 15-30% opacity backgrounds with blur
    *   Accent: System blue for interactive elements
*   **Typography:**
    *   Primary: SF Pro Display for headings
    *   Body: SF Pro Text for content
    *   Monospace: SF Mono for OCR text display
*   **Spacing:** 8pt grid system (8, 16, 24, 32, 48, 64)
*   **Corner Radius:** 12pt for cards, 8pt for buttons, 20pt for sheets
*   **Shadows:** Subtle depth with 2-4pt blur radius
*   **Animations:**
    *   Spring animations (dampingFraction: 0.8, response: 0.6)
    *   Gesture-driven interactions with rubber-band effects
    *   Fade and scale transitions for modal presentations

## 4. Features

### 4.1. Automated Screenshot Management
*   **Automatic Import:** The app will monitor the device for new screenshots and automatically import them into its library in the background.
*   **Optional Deletion:** A user-configurable setting will allow for the automatic deletion of the original screenshot from the Apple Photos app to prevent duplicates and reduce clutter.

### 4.2. On-Device Intelligence & Content Extraction
*   **Optical Character Recognition (OCR):** All text and objects within every screenshot will be extracted, indexed, and made searchable. Use Apple Generative AI: https://developer.apple.com/design/human-interface-guidelines/generative-ai
*   **Object & Scene Recognition:** The app will identify and tag key objects, logos, UI elements (e.g., buttons, forms), and scenes (e.g., maps, charts, conversations).
*   **Contextual Linking (Mind Map):** The app will intelligently analyze the content of screenshots to automatically create links between them, forming a visual mind map or knowledge graph based on shared text, topics, or visual context.

### 4.3. Search & Discovery
*   **Universal Search:** A powerful, fast search engine to find screenshots based on:
    *   Any text content within the screenshot.
    *   Automatically or manually assigned tags.
    *   Recognized objects or scenes.
    *   Metadata (e.g., date, time, source application if identifiable).
*   **Visual Navigation:** Users can explore their screenshot library through the interconnected mind map, discovering relationships between notes.

### 4.4. User Interaction & Organization
*   **Manual Context:** Users can add their own notes, text annotations, and tags to any screenshot.
*   **Mind Map Editing:** Users can manually create, edit, or remove the links between screenshots in the mind map to refine the organization.
*   **Manual Import:** Users can explicitly import any image from their Photos library, not just screenshots.
*   **Deletion:** Users can easily delete single or multiple screenshots from the app's library.
*   **Copying:** Users should be able to copy out information (e.g. coupon codes, URLs, information in QR codes, etc.).

## 5. Technical Requirements & Considerations

*   **Platform:** iOS 17.0+, targeting the latest major version.
*   **Primary APIs:**
    *   **Vision Framework:** For all on-device OCR and image analysis tasks.
    *   **Photos Framework:** For observing and fetching screenshots from the user's library.
    *   **SwiftUI:** To build a modern, responsive, and fluid user interface that embodies the design principles.
    *   **SwiftData:** For robust, on-device storage (preferred over Core Data for new projects).
*   **Performance:** All AI processing should happen on-device to ensure user privacy and app responsiveness. Background tasks must be efficient to minimize battery impact.

### Technical Constraints & Quality Standards

*   **Memory Management:**
    *   Maximum 150MB memory usage during active use
    *   Efficient image loading with progressive JPEG support
    *   Lazy loading for large screenshot collections
*   **Performance Benchmarks:**
    *   App launch: <2 seconds cold start, <0.5 seconds warm start
    *   OCR processing: <3 seconds per screenshot
    *   Search results: <100ms response time
    *   Animation frame rate: 60fps minimum, 120fps target
*   **Battery Optimization:**
    *   Background processing limited to 30 seconds per session
    *   Batch OCR processing during device charging
    *   Efficient Core ML model usage with caching
*   **Data Integrity:**
    *   Atomic database operations with rollback support
    *   Automatic data backup and corruption recovery
    *   Graceful handling of Photos library permission changes
*   **Accessibility:**
    *   VoiceOver support for all interactive elements
    *   Dynamic Type support for text scaling
    *   High contrast mode compatibility
    *   Voice Control gesture alternatives

## 6. Implementation Status

### Sprint 0 - Foundation Complete ✅
*   **Git Repository**: Private GitHub repository established
*   **Xcode Project**: iOS 17+ project with SwiftUI and SwiftData configured
*   **Architecture**: MVVM structure with organized folder hierarchy
*   **Data Model**: Screenshot entity with SwiftData schema
*   **Basic UI**: ContentView with empty state and list view components
*   **Asset Catalog**: App icon and accent color placeholders configured

### Sprint 1 - Manual Import MVP Complete ✅
*   **PhotosPicker Integration**: Multi-select import (up to 10 images) with progress tracking
*   **Image Processing**: Automatic optimization and compression (JPEG, 0.8 quality, max 2048px)
*   **Storage System**: SwiftData-based persistence with ImageStorageService abstraction
*   **Gallery View**: Adaptive grid layout with thumbnails and timestamp display
*   **Detail View**: Full-screen viewer with zoom, pan, and double-tap gestures
*   **Deletion**: Long-press gesture with confirmation dialog and smooth animations
*   **Error Handling**: Comprehensive error management with user-friendly messaging
*   **Haptic Feedback**: Contextual tactile feedback for all user interactions
*   **Custom App Icon**: Brain-themed design with all required icon sizes
*   **MVVM Architecture**: Clean separation with ScreenshotListViewModel, ImageStorageService, and HapticService
*   **UI Polish**: Smooth animations, proper visual hierarchy, and accessible design

### Sprint 2 - Automation Engine Complete ✅
*   **Automatic Screenshot Detection**: Real-time monitoring of photo library using PHPhotoLibraryChangeObserver
*   **Background Processing**: BGAppRefreshTask integration for background screenshot import
*   **User Settings Management**: Comprehensive settings service with automatic import controls
*   **Duplicate Prevention**: Asset identifier-based system prevents importing the same screenshot multiple times
*   **Enhanced Animations**: Smooth spring-based transitions for new items appearing in the gallery
*   **Refined UI Layout**: Improved grid spacing, visual hierarchy, and thumbnail design with subtle shadows
*   **Permissions Management**: Complete photo library access handling with guided permission flow
*   **Performance Optimizations**: Memory-efficient sequential processing with batch optimization
*   **Privacy Integration**: Proper Info.plist declarations for photo library access permissions

### Next Sprint: Sprint 3 - OCR & Intelligence
Ready to implement on-device OCR, text extraction, and search functionality.

## 7. Out of Scope (for Version 1.0)

*   Cloud synchronization between multiple devices.
*   Dedicated iPadOS or macOS applications.
*   Real-time collaboration or sharing features.
*   Analysis of video screen recordings.
