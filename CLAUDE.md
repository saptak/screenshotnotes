# Claude Code Development Notes

This file contains development context and guidelines for Claude Code when working on the ScreenshotNotes project.

## Project Overview

Screenshot Vault is an iOS app for intelligent screenshot organization with OCR capabilities. The project follows a sprint-based development approach with focus on Glass Design principles and high-performance animations.

### Architecture Foundation
- **MVVM Pattern**: Clear separation with Views/, ViewModels/, Models/, Services/
- **SwiftData**: Modern iOS 17+ development with better SwiftUI integration
- **Service-Oriented Architecture**: Protocol-based services for modularity and testing
- **Bundle ID**: `com.screenshotnotes.app`
- **iOS Target**: 17.0+ (iPhone and iPad)
- **Performance**: 60fps minimum, targeting 120fps ProMotion

## Current Project Status

### Completed Development
- **Sprint 0**: Foundation & Setup ✅ (Xcode project, MVVM architecture, SwiftData integration)
- **Sprint 1**: Manual Import MVP ✅ (PhotosPicker integration, thumbnail grid, detail view)
- **Sprint 2**: Automatic Screenshot Detection Engine ✅ (Background detection, settings, duplicate prevention)
- **Sprint 3**: OCR & Intelligence Engine ✅ (Vision Framework OCR, advanced search, Glass UX)
- **Sprint 4 Sub-Sprint 4.1**: Glass Design System Migration ✅ (Complete Material→Glass migration, responsive layout)
- **Sprint 4 Sub-Sprint 4.2**: Hero Animation System ✅ (matchedGeometryEffect infrastructure)
- **Sprint 4 Sub-Sprint 4.3**: Contextual Menu System ✅ (Long-press menus, haptic feedback)
- **Sprint 4 Sub-Sprint 4.4**: Advanced Gestures ✅ (Enhanced gestures, accessibility integration)
- **Sprint 5 Sub-Sprint 5.1.1**: Core ML Setup & Query Parser Foundation ✅ (Natural language processing)
- **Sprint 5 Sub-Sprint 5.1.2**: Entity Extraction Engine ✅ (16 entity types, multi-language support)
- **Sprint 5 Sub-Sprint 5.1.4**: Search Robustness Enhancement ✅ (5-tier progressive fallback, fuzzy matching, synonym expansion)
- **Sprint 5 Sub-Sprint 5.2.1**: Enhanced Vision Processing ✅ (Advanced object detection, scene classification, color analysis)
- **Sprint 5 Sub-Sprint 5.2.2**: Color Analysis & Visual Embeddings ✅ (Dominant color extraction, visual similarity)
- **Sprint 5 Sub-Sprint 5.2.3**: Semantic Tagging & Content Understanding ✅ (AI-powered semantic tags, business entity recognition)
- **Sprint 5 Sub-Sprint 5.4.2**: Glass Conversational Experience ✅ (6-state orchestration, premium Glass UX, Siri integration)
- **Sprint 5 Sub-Sprint 5.4.3**: Glass Design System & Performance Optimization ✅ (120fps ProMotion, GPU acceleration, intelligent caching, memory management)
- **Sprint 6 Sub-Sprint 6.5.1**: Comprehensive Semantic Processing Pipeline ✅ (Complete OCR, entity extraction, semantic tagging integration)
- **Sprint 6 Sub-Sprint 6.5.2**: Background Mind Map Generation ✅ (Automated mind map pipeline, instant cache-based loading)
- **Sprint 6 Sub-Sprint 6.6**: Glass Design System Unification ✅ (Complete Material→Glass migration, responsive layout for all iOS devices, dark mode fixes)

## Key Technical Decisions

### Enhanced Interface Development Strategy (Sprint 8)
- **Implementation**: Dual UX Architecture with Legacy Interface + Enhanced Interface
- **Status**: Planned for Sprint 8 with 25 atomic daily iterations
- **User Control**: Settings toggle "Enable Enhanced Interface" (disabled by default)
- **Zero Risk Strategy**: Legacy Interface remains completely unchanged and functional
- **Features**:
  - **Single-Click Voice**: Tap-to-activate voice commands with session management
  - **Content Constellation**: Smart grouping of travel, projects, events with workspace creation
  - **Intelligent Triage**: AI-powered content cleanup with voice and touch controls
  - **Progressive Disclosure**: 4-level complexity adaptation (Gallery → Constellation → Exploration → Search)
  - **Liquid Glass Foundation**: Advanced material system with responsive device adaptation
- **Evaluation Process**: 60-90 day beta evaluation with strict criteria before any Legacy Interface changes
- **Files**:
  - `Settings/InterfaceSettings.swift` (interface toggle management)
  - `Voice/VoiceSessionManager.swift` (single-click voice activation)
  - `AI/ContentConstellationDetector.swift` (smart content grouping)
  - `Services/IntelligentTriageService.swift` (content relevancy analysis)

### Glass Design System Unification (Sub-Sprint 6.6)
- **Implementation**: Complete migration from Material Design to Glass Design system
- **Status**: Fully implemented with responsive layout support
- **Architecture**: Comprehensive responsive layout system with device-specific adaptations
- **Performance**: Maintained 120fps ProMotion with optimized Glass effects
- **Features**:
  - **Responsive Layout**: iPhone SE (320pt) → iPad Pro (1024pt+) with adaptive spacing/typography
  - **Device Classification**: 6 device types with specific material/spacing configurations
  - **Dark Mode Support**: Complete light/dark theme adaptation across all Glass components
  - **Material Hierarchy**: 5 Glass materials (.ultraThin → .chrome) with accessibility support
  - **Performance Optimization**: Efficient layout calculations with environment-based responsive design
- **Files**:
  - `Design/GlassDesignSystem.swift` (enhanced with responsive system)
  - `Views/SearchView.swift` (migrated to responsive Glass design)
  - `Views/MindMapView.swift` (migrated to responsive Glass design)
  - All service files updated to use Glass backgrounds

### Hero Animation System (Sub-Sprint 4.2)
- **Implementation**: Complete infrastructure using matchedGeometryEffect
- **Status**: Temporarily disabled due to navigation timing conflicts
- **Architecture**: Comprehensive service layer with edge case handling
- **Performance**: 120fps ProMotion optimization with automated testing
- **Files**: 
  - `Services/HeroAnimationService.swift`
  - `Services/HeroAnimationEdgeCaseHandler.swift`
  - `Services/HeroAnimationPerformanceTester.swift`
  - `Services/HeroAnimationVisualValidator.swift`

### Contextual Menu System (Sub-Sprint 4.3)
- **Implementation**: Complete contextual menu system with long-press gestures
- **Status**: Fully implemented and functional
- **Architecture**: Comprehensive service layer with haptic feedback, batch selection, and accessibility
- **Performance**: Advanced performance testing framework with comprehensive metrics
- **Files**:
  - `Services/HapticFeedbackService.swift`
  - `Services/ContextualMenuService.swift`
  - `Services/QuickActionService.swift`
  - `Services/ContextualMenuPerformanceTester.swift`
  - `Services/ContextualMenuAccessibilityService.swift`

### Full Screen Swipe Navigation (Enhancement)
- **Implementation**: Complete swipe gesture system for full screen screenshot viewing
- **Status**: Fully implemented and functional
- **Features**:
  - **Swipe down**: Close full screen mode
  - **Swipe left/right**: Navigate between screenshots
  - **Swipe up**: Show share/delete action sheet
  - **Navigation indicators**: Current position display (e.g., "2 of 15")
  - **Haptic feedback**: Different patterns for each gesture type
- **Files**:
  - `ScreenshotDetailView.swift` (enhanced with swipe navigation)
  - `ContentView.swift` (updated to pass screenshot collection)
  - `Views/SearchView.swift` (updated for navigation compatibility)

### Comprehensive Semantic Processing Pipeline (Sub-Sprint 6.5.1)
- **Implementation**: Complete 5-phase background processing pipeline
- **Status**: Fully implemented and optimized for performance
- **Architecture**: Integrated OCR, vision analysis, semantic tagging, and mind map generation
- **Performance**: Intelligent redundancy prevention, background processing, zero UI blocking
- **Features**:
  - **Phase 1**: OCR text extraction (only if `extractedText == nil`)
  - **Phase 2**: Vision analysis (only if `needsVisionAnalysis == true`)
  - **Phase 3**: Semantic tagging with 16-type entity extraction
  - **Phase 4**: Mind map generation with relationship discovery
  - **Phase 5**: Cache storage and completion
- **Files**:
  - `Services/BackgroundSemanticProcessor.swift` (main orchestrator)
  - `Services/BackgroundOCRProcessor.swift` (text extraction)
  - `Services/BackgroundVisionProcessor.swift` (vision analysis)
  - `Services/EntityExtractionService.swift` (entity recognition)
  - `Services/SemanticTaggingService.swift` (AI tagging)

### Background Mind Map Generation (Sub-Sprint 6.5.2)
- **Implementation**: Automated mind map pipeline integrated with semantic processing
- **Status**: Fully implemented with instant cache-based loading
- **Architecture**: Background generation, intelligent caching, automatic updates
- **Performance**: <0.5s instant loading, background processing, cache-first approach
- **Features**:
  - **Automatic Generation**: Triggered after semantic processing completes
  - **Incremental Updates**: Regenerates when new screenshots imported
  - **Smart Caching**: JSON-based persistence with data fingerprinting
  - **Instant Loading**: Cache-first approach in MindMapView
  - **Resource Management**: 3+ screenshots minimum, semantic data filtering
- **Files**:
  - `Services/MindMapService.swift` (mind map generation and caching)
  - `Services/AI/EntityRelationshipService.swift` (relationship discovery)
  - `Views/MindMapView.swift` (cache-first loading)
  - `ContentView.swift` (trigger integration)

## Architecture Patterns

### Service Layer Architecture
All major functionality is implemented as services:
- `HeroAnimationService`: Animation management and coordination
- `MaterialDesignSystem`: UI consistency and design tokens
- `HapticFeedbackService`: Advanced haptic feedback patterns
- `ContextualMenuService`: Long-press menus and batch operations
- `QuickActionService`: Action execution with progress tracking
- `ContextualMenuAccessibilityService`: Comprehensive accessibility support
- `ContextualMenuPerformanceTester`: Performance validation and metrics
- `OCRService`: Text extraction and intelligent processing
- `SearchService`: Advanced search with filters and caching
- `PhotoLibraryService`: Photo library monitoring and import
- `SimpleQueryParser`: Natural language query parsing with intent classification
- `EntityExtractionService`: Advanced entity recognition with 16 entity types and multi-language support
- `SemanticTaggingService`: AI-powered semantic tagging combining vision, OCR, and business entity recognition
- `BackgroundSemanticProcessor`: 5-phase processing pipeline with OCR, vision analysis, semantic tagging, and mind map generation
- `BackgroundOCRProcessor`: Text extraction with intelligent processing triggers
- `BackgroundVisionProcessor`: Enhanced vision analysis with object detection and scene classification
- `MindMapService`: Intelligent mind map generation with caching and automatic updates
- `GlassConversationalSearchOrchestrator`: 6-state Glass conversational search management
- `GlassDesignSystem`: Premium Glass UX with 5 material types and physics-based animations
- `GlassPerformanceMonitor`: Real-time 120fps ProMotion performance tracking
- `GlassRenderingOptimizer`: GPU-accelerated rendering with Metal optimization
- `GlassCacheManager`: Intelligent multi-tier caching with LRU eviction
- `GlassMemoryManager`: Advanced memory pressure handling and optimization

### Performance-First Approach
- 120fps ProMotion target for all animations
- Real-time performance monitoring with automated testing frameworks
- Memory pressure and thermal throttling handling with 3-tier optimization
- GPU-accelerated rendering with Metal shader compilation
- Intelligent caching with 80%+ hit rate targets

## Development Guidelines

### When Working on Hero Animations
1. **Test thoroughly** on ProMotion devices (120fps target)
2. **Handle edge cases**: memory pressure, thermal throttling, device rotation
3. **Validate timing**: Ensure smooth coordination with SwiftUI navigation
4. **Monitor performance**: Use built-in testing frameworks

### When Working on Material Design
1. **Use MaterialDesignSystem service** for all UI components
2. **Follow elevation principles** for visual hierarchy
3. **Test performance** with automated frameworks
4. **Maintain consistency** across all views

### When Working on Contextual Menus
1. **Use ContextualMenuService** for menu management and batch operations
2. **Integrate HapticFeedbackService** for tactile responses
3. **Test accessibility** with ContextualMenuAccessibilityService
4. **Validate performance** with ContextualMenuPerformanceTester

### When Working on Swipe Gestures
1. **Test gesture conflicts** with zoom and pan interactions
2. **Ensure proper haptic feedback** for different gesture types
3. **Validate navigation bounds** checking for edge cases
4. **Test accessibility** with VoiceOver and alternative input methods

### When Working on Glass Performance
1. **Use GlassPerformanceMonitor** for real-time performance tracking
2. **Leverage GlassRenderingOptimizer** for GPU-accelerated rendering
3. **Implement GlassCacheManager** for intelligent caching strategies
4. **Monitor GlassMemoryManager** for memory pressure handling
5. **Test on ProMotion devices** for 120fps validation
6. **Handle thermal throttling** with dynamic quality adjustment

### When Working on Semantic Processing
1. **Use BackgroundSemanticProcessor** for comprehensive AI processing pipeline
2. **Leverage existing phases** to avoid redundant processing (OCR, vision, semantic)
3. **Implement intelligent checks** for processing requirements (e.g., `needsSemanticAnalysis`)
4. **Follow phase-based approach** for optimal performance and resource management
5. **Integrate with import triggers** to ensure new content gets processed
6. **Monitor processing metrics** for performance optimization

### When Working on Mind Map Features
1. **Use MindMapService.shared** for all mind map operations
2. **Implement cache-first loading** for instant user experience
3. **Trigger background generation** after semantic processing completes
4. **Leverage existing semantic data** (entities, tags, relationships)
5. **Handle minimum data requirements** (3+ screenshots with semantic data)
6. **Test incremental updates** when new screenshots are added

### When Working on Enhanced Interface (Sprint 8)
1. **Maintain Dual UX Architecture** - Legacy Interface must remain unchanged and functional
2. **Use InterfaceSettings.swift** for all interface toggle management
3. **Test both interfaces** ensure feature parity and performance consistency
4. **Implement feature flags** to control Enhanced Interface feature access
5. **Document rollback strategies** for each atomic iteration
6. **Validate Settings toggle** ensures instant switching without app restart

### When Working on Voice Features
1. **Use single-click activation** - no ambient listening or continuous voice detection
2. **Implement session management** with VoiceSessionManager for clear start/end boundaries
3. **Add visual state feedback** with microphone button states (inactive/listening/processing)
4. **Include session timeout** (10 seconds) with automatic return to inactive state
5. **Test deliberate activation** ensure each voice command requires explicit user intent
6. **Integrate haptic feedback** for voice session start/end confirmation
7. **Validate privacy compliance** no voice data stored or transmitted

### When Working on Content Constellation
1. **Use ContentConstellationDetector** for smart content grouping algorithms
2. **Implement workspace creation** for detected content groups (travel, projects, events)
3. **Leverage existing semantic data** entities, tags, relationships from semantic processing
4. **Add progress tracking** for workspace completion and milestone suggestions
5. **Test relationship accuracy** validate content grouping with user scenarios
6. **Monitor performance** ensure constellation detection doesn't impact app responsiveness

### When Working on Intelligent Triage
1. **Use IntelligentTriageService** for relevancy analysis and cleanup suggestions
2. **Implement safety mechanisms** confirmation dialogs and undo functionality
3. **Add voice triage support** with single-click activation for each command
4. **Preserve important content** intelligent protection logic for valuable screenshots
5. **Test batch operations** ensure efficient bulk management with performance monitoring
6. **Validate accessibility** triage operations accessible via VoiceOver and assistive technologies

### When Adding New Features
1. **Create service layer** for complex functionality
2. **Include performance tests** for animation-heavy features
3. **Document public APIs** comprehensively
4. **Consider accessibility** from the start
5. **Integrate haptic feedback** for enhanced user experience
6. **Monitor Glass performance** if using Glass components
7. **Integrate with semantic pipeline** if AI processing is needed
8. **Consider interface compatibility** ensure features work appropriately in both Legacy and Enhanced interfaces

## Common Commands for Development

### Build and Test
```bash
# Build for simulator
xcodebuild -project ScreenshotNotes.xcodeproj -scheme ScreenshotNotes -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build

# Run tests
xcodebuild test -project ScreenshotNotes.xcodeproj -scheme ScreenshotNotes -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

### Performance Validation
- Use built-in HeroAnimationPerformanceTester for animation validation
- Use MaterialPerformanceTest for UI rendering validation
- Use ContextualMenuPerformanceTester for menu interaction validation
- Use GlassPerformanceMonitor for 120fps ProMotion validation
- Use GlassTestingSuite for comprehensive Glass system testing
- Monitor semantic processing pipeline performance and memory usage
- Test background OCR processing efficiency and resource management
- Validate mind map generation performance and cache hit rates
- Monitor entity extraction accuracy and processing times
- Test haptic feedback efficiency and responsiveness
- **Enhanced Interface Testing**: Validate interface toggle switching, feature parity, performance consistency
- **Voice Session Testing**: Verify single-click activation, session management, timeout handling
- **Content Constellation Testing**: Validate grouping accuracy, workspace creation, relationship detection
- **Triage Performance Testing**: Monitor relevancy analysis efficiency, batch operation performance

## Code Organization

### File Structure
```
ScreenshotNotes/
├── Models/
│   └── Screenshot.swift
├── Services/
│   ├── HeroAnimationService.swift
│   ├── HeroAnimationEdgeCaseHandler.swift
│   ├── HeroAnimationPerformanceTester.swift
│   ├── HeroAnimationVisualValidator.swift
│   ├── HapticFeedbackService.swift
│   ├── ContextualMenuService.swift
│   ├── QuickActionService.swift
│   ├── ContextualMenuPerformanceTester.swift
│   ├── ContextualMenuAccessibilityService.swift
│   ├── MaterialDesignSystem.swift
│   ├── MaterialPerformanceTest.swift
│   ├── MaterialVisualTest.swift
│   ├── OCRService.swift
│   ├── BackgroundOCRProcessor.swift
│   ├── SearchService.swift
│   ├── SearchCache.swift
│   ├── PhotoLibraryService.swift
│   ├── BackgroundTaskService.swift
│   ├── SettingsService.swift
│   ├── ImageStorageService.swift
│   ├── GlassConversationalSearchOrchestrator.swift
│   ├── GlassPerformanceMonitor.swift
│   ├── GlassRenderingOptimizer.swift
│   ├── GlassCacheManager.swift
│   ├── GlassMemoryManager.swift
│   └── AI/
│       ├── QueryParserService.swift
│       ├── EntityExtractionService.swift
│       ├── SearchRobustnessService.swift
│       ├── FuzzyMatchingService.swift
│       └── SynonymExpansionService.swift
├── Views/
│   ├── SearchView.swift
│   ├── SearchFiltersView.swift
│   ├── SettingsView.swift
│   ├── PermissionsView.swift
│   └── Components/
│       ├── GlassSearchBar.swift
│       └── GlassConversationalMicrophoneButton.swift
├── ContentView.swift
├── ScreenshotDetailView.swift (enhanced with swipe navigation)
├── ScreenshotListViewModel.swift
├── HapticService.swift
└── Assets.xcassets/
```

### Service Dependencies
- **HeroAnimationService** ← Used by ContentView, ScreenshotDetailView
- **MaterialDesignSystem** ← Used by all Views for consistent design
- **HapticFeedbackService** ← Used by ContextualMenuService, ScreenshotDetailView, ContentView
- **ContextualMenuService** ← Used by ContentView for long-press menus and batch selection
- **QuickActionService** ← Used by ContextualMenuService for action execution
- **ContextualMenuAccessibilityService** ← Used by accessible menu components
- **OCRService** ← Used by ScreenshotListViewModel for text extraction
- **SearchService** ← Used by SearchView, ContentView for intelligent search
- **PhotoLibraryService** ← Used by ScreenshotListViewModel for screenshot detection
- **BackgroundTaskService** ← Used for background processing coordination
- **QueryParserService** ← Used by ContentView for natural language understanding
- **EntityExtractionService** ← Used by QueryParserService for 16-type entity recognition
- **SearchRobustnessService** ← Used by ContentView for 5-tier progressive fallback search
- **FuzzyMatchingService** ← Used by SearchRobustnessService for advanced similarity matching
- **SynonymExpansionService** ← Used by SearchRobustnessService for query expansion
- **GlassConversationalSearchOrchestrator** ← Used by GlassSearchBar for 6-state conversational search management
- **GlassPerformanceMonitor** ← Used by Glass components for real-time performance tracking
- **GlassRenderingOptimizer** ← Used by Glass components for GPU-accelerated rendering
- **GlassCacheManager** ← Used by Glass components for intelligent caching strategies
- **GlassMemoryManager** ← Used by Glass components for memory pressure handling
- **SettingsService** ← Used by SettingsView, GlassConversationalSearchOrchestrator, and app configuration
- **BackgroundSemanticProcessor** ← Used by ContentView for comprehensive semantic processing pipeline
- **BackgroundOCRProcessor** ← Used by ContentView and ScreenshotNotesApp for text extraction
- **BackgroundVisionProcessor** ← Used by ContentView for enhanced vision analysis
- **MindMapService** ← Used by MindMapView and BackgroundSemanticProcessor for visualization generation

## Performance Targets

### Animation Performance
- **120fps** on ProMotion displays
- **60fps minimum** on standard displays
- **<50ms** response time for user interactions
- **<2MB** memory increase during animations
- **Smooth transitions** for swipe navigation between screenshots

### Interaction Performance
- **<50ms** contextual menu response time
- **<100ms** haptic feedback latency
- **<200ms** quick action execution start
- **Seamless gesture recognition** for swipe navigation

### Search Performance
- **<100ms** response time for text search
- **<500ms** for complex filtered searches
- **Maintain 60fps** during search result updates
- **Intelligent caching** for repeated searches

### Semantic Processing Performance
- **5-phase pipeline** with intelligent redundancy prevention
- **Background processing** without blocking UI
- **<5ms** entity extraction, 90%+ accuracy across 16 entity types
- **Batch processing** with optimized memory usage
- **Intelligent caching** to avoid redundant processing

### Mind Map Performance
- **<0.5s** instant loading from cache
- **Background generation** after semantic processing
- **Automatic updates** when new content added
- **Smart caching** with data fingerprinting
- **Resource management** with minimum data thresholds

## Testing Protocols

### Before Committing Changes
1. **Build successfully** for both simulator and device
2. **Run performance tests** for affected areas
3. **Test on ProMotion device** if animations involved
4. **Verify accessibility** with VoiceOver
5. **Test edge cases** (low memory, background state)
6. **Test haptic feedback** on physical device
7. **Validate gesture interactions** for conflicts
8. **Test contextual menus** and quick actions
