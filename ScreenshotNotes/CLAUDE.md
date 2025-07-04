# Claude Code Development Notes

This file contains development context and guidelines for Claude Code when working on the ScreenshotNotes project.

## Project Overview

ScreenshotNotes is an iOS app for intelligent screenshot organization with OCR capabilities. The project follows a sprint-based development approach with focus on Material Design principles and high-performance animations.

## Current Project Status

### Completed Development
- **Sprint 1**: Manual Import MVP ✅
- **Sprint 2**: Automatic Screenshot Detection Engine ✅  
- **Sprint 3**: OCR & Intelligence Engine ✅
- **Sprint 4 Sub-Sprint 4.1**: Material Design System ✅
- **Sprint 4 Sub-Sprint 4.2**: Hero Animation System ✅

### Current Sprint
**Sprint 4: Advanced UI & Interactions** (Sub-Sprint 4.3 Next)

## Key Technical Decisions

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

### Navigation Fix Applied
- **Issue**: Black screen when tapping screenshots due to hero animation timing conflicts
- **Solution**: Simplified navigation flow by removing problematic hero animation triggers
- **Status**: Navigation now works correctly with fullScreenCover
- **Future**: Hero animations can be re-enabled with refined timing coordination

## Architecture Patterns

### Service Layer Architecture
All major functionality is implemented as services:
- `HeroAnimationService`: Animation management
- `MaterialDesignSystem`: UI consistency
- `OCRService`: Text extraction
- `SearchService`: Intelligent search
- `PhotoLibraryService`: Photo monitoring

### Performance-First Approach
- 120fps ProMotion target for all animations
- Automated performance testing frameworks
- Memory pressure and thermal throttling handling
- GPU-accelerated rendering where possible

### Testing Strategy
- Comprehensive automated testing for performance
- Visual validation frameworks
- Edge case handling verification
- Manual testing checklists

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

### When Adding New Features
1. **Create service layer** for complex functionality
2. **Include performance tests** for animation-heavy features
3. **Document public APIs** comprehensively
4. **Consider accessibility** from the start

## Common Commands for Development

### Build and Test
```bash
# Build for simulator
xcodebuild -project ScreenshotNotes.xcodeproj -scheme ScreenshotNotes -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Run tests
xcodebuild test -project ScreenshotNotes.xcodeproj -scheme ScreenshotNotes -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Performance Validation
- Use built-in HeroAnimationPerformanceTester for animation validation
- Use MaterialPerformanceTest for UI rendering validation
- Monitor memory usage during OCR processing

## Known Issues & Workarounds

### Hero Animation Navigation Conflict
- **Issue**: Hero animations cause black screen with fullScreenCover
- **Workaround**: Hero animation triggers disabled in navigation flow
- **Fix Required**: Refined timing coordination between animations and presentation

### Large Collection Performance
- **Issue**: Potential performance degradation with 1000+ screenshots
- **Mitigation**: Consider virtual scrolling implementation
- **Monitoring**: Track memory usage in OCR processing

## Next Development Priorities

### Immediate (Sub-Sprint 4.3)
1. **Contextual Menu System**: Long-press menus with haptic feedback
2. **Quick Actions**: Share, copy, delete, tag operations
3. **Batch Operations**: Multi-select functionality

### Short-term (Sub-Sprint 4.4-4.5)
1. **Advanced Gestures**: Pull-to-refresh, swipe actions
2. **Animation Polish**: Loading states, microinteractions
3. **Hero Animation Re-enablement**: Fix navigation timing issues

### Long-term (Sprint 5+)
1. **Export & Sharing**: PDF/ZIP export, AirDrop integration
2. **Tags & Organization**: Custom tagging, AI categorization
3. **Cloud Sync**: iCloud integration for cross-device sync

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
│   ├── MaterialDesignSystem.swift
│   ├── OCRService.swift
│   ├── SearchService.swift
│   └── PhotoLibraryService.swift
├── Views/
│   ├── SearchView.swift
│   ├── SettingsView.swift
│   └── Components/
├── ContentView.swift
├── ScreenshotDetailView.swift
└── Assets.xcassets/
```

### Service Dependencies
- **HeroAnimationService** ← Used by ContentView, ScreenshotDetailView
- **MaterialDesignSystem** ← Used by all Views
- **OCRService** ← Used by ScreenshotListViewModel
- **SearchService** ← Used by SearchView, ContentView
- **PhotoLibraryService** ← Used by ScreenshotListViewModel

## Performance Targets

### Animation Performance
- **120fps** on ProMotion displays
- **60fps minimum** on standard displays
- **<50ms** response time for user interactions
- **<2MB** memory increase during animations

### Search Performance
- **<100ms** response time for text search
- **<500ms** for complex filtered searches
- **Maintain 60fps** during search result updates

### OCR Performance
- **Background processing** without blocking UI
- **Progress indication** for long operations
- **Intelligent caching** to avoid redundant processing

## Testing Protocols

### Before Committing Changes
1. **Build successfully** for both simulator and device
2. **Run performance tests** for affected areas
3. **Test on ProMotion device** if animations involved
4. **Verify accessibility** with VoiceOver
5. **Test edge cases** (low memory, background state)

### Release Criteria
1. **All automated tests pass**
2. **Performance targets met**
3. **No memory leaks detected**
4. **Accessibility compliance verified**
5. **Manual testing checklist completed**

---

**Last Updated**: Post Sub-Sprint 4.2 completion  
**Next Milestone**: Sub-Sprint 4.3 - Contextual Menu System  
**Critical Issues**: Hero animation navigation timing (workaround in place)