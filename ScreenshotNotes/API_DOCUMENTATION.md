# API Documentation - ScreenshotNotes

This document provides comprehensive API documentation for all services, models, and key components in the ScreenshotNotes application.

## Core Services

### HeroAnimationService

**Purpose**: Manages seamless view transitions using matchedGeometryEffect with 120fps ProMotion performance.

```swift
@MainActor
final class HeroAnimationService: ObservableObject
```

#### Key Types

```swift
enum TransitionType: String, CaseIterable {
    case gridToDetail = "grid_to_detail"
    case searchToDetail = "search_to_detail"
    case detailToGrid = "detail_to_grid"
    case detailToSearch = "detail_to_search"
}

struct AnimationConfiguration {
    let duration: Double
    let timing: Animation
    let delay: Double
    let dampingFraction: Double
    let response: Double
}
```

#### Public Methods

```swift
// Get namespace for transition type
func namespace(for transitionType: TransitionType) -> Namespace.ID

// Start hero animation transition
func startTransition(
    _ transitionType: TransitionType,
    from sourceId: String,
    to destinationId: String,
    completion: (() -> Void)? = nil
)

// Check if animation is currently active
func isAnimationActive(_ animationId: String) -> Bool
```

#### Usage Example

```swift
@StateObject private var heroService = HeroAnimationService.shared
@Namespace private var heroNamespace

// In view body
.heroSource(
    id: "thumbnail_\(screenshot.id)",
    in: heroNamespace,
    transitionType: .gridToDetail
)

// Trigger animation
heroService.startTransition(
    .gridToDetail,
    from: "thumbnail_\(screenshot.id)",
    to: "detail_\(screenshot.id)"
)
```

---

### HeroAnimationEdgeCaseHandler

**Purpose**: Handles complex animation scenarios including memory pressure, thermal throttling, and device rotation.

```swift
@MainActor
final class HeroAnimationEdgeCaseHandler: ObservableObject
```

#### Edge Case Types

```swift
enum EdgeCaseType: String, CaseIterable {
    case rapidTransition = "rapid_transition"
    case memoryPressure = "memory_pressure"
    case deviceRotation = "device_rotation"
    case backgroundTransition = "background_transition"
    case thermalThrottling = "thermal_throttling"
    case lowBattery = "low_battery"
    case accessibilityMotionReduction = "accessibility_motion_reduction"
    case networkConnectivityChange = "network_connectivity_change"
}
```

#### Public Methods

```swift
// Check for edge cases before animation
func checkEdgeCasesBeforeAnimation(
    for transitionType: HeroAnimationService.TransitionType,
    completion: @escaping (Bool, [EdgeCaseType], EdgeCaseConfiguration?) -> Void
)

// Handle animation interruption
func handleAnimationInterruption(
    for edgeCases: [EdgeCaseType],
    currentAnimation: HeroAnimationService.TransitionType
)

// Get modified animation configuration
func getAnimationConfiguration(for edgeCases: [EdgeCaseType]) -> HeroAnimationService.AnimationConfiguration
```

---

### HeroAnimationPerformanceTester

**Purpose**: Automated performance testing framework for validating 120fps ProMotion performance.

```swift
@MainActor
final class HeroAnimationPerformanceTester: ObservableObject
```

#### Test Configuration

```swift
struct TestConfiguration {
    let name: String
    let transitionType: HeroAnimationService.TransitionType
    let iterations: Int
    let targetFrameRate: Double
    let targetDuration: Double
    let memoryThreshold: Double
}
```

#### Performance Metrics

```swift
struct DetailedPerformanceMetrics {
    let testName: String
    let frameRateMetrics: FrameRateMetrics
    let animationMetrics: AnimationMetrics
    let memoryMetrics: MemoryMetrics
    let thermalMetrics: ThermalMetrics
    let batteryMetrics: BatteryMetrics
    let timestamp: Date
}
```

#### Public Methods

```swift
// Run comprehensive performance test suite
func runFullPerformanceTestSuite() async
```

---

### HeroAnimationVisualValidator

**Purpose**: Visual continuity and state management validation for hero animations.

```swift
@MainActor
final class HeroAnimationVisualValidator: ObservableObject
```

#### Validation Results

```swift
struct ValidationResult {
    let testName: String
    let visualContinuity: VisualContinuityResult
    let stateManagement: StateManagementResult
    let animationTiming: AnimationTimingResult
    let userExperience: UserExperienceResult
    let timestamp: Date
}
```

#### Public Methods

```swift
// Run comprehensive visual validation tests
func runVisualValidationSuite() async
```

---

### MaterialDesignSystem

**Purpose**: Comprehensive Material Design implementation with performance optimization.

```swift
@MainActor
final class MaterialDesignSystem: ObservableObject
```

#### Design Tokens

```swift
enum DesignToken {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    enum Elevation {
        static let level0: CGFloat = 0
        static let level1: CGFloat = 1
        static let level2: CGFloat = 3
        static let level3: CGFloat = 6
        static let level4: CGFloat = 8
        static let level5: CGFloat = 12
    }
}
```

#### Surface Materials

```swift
struct SurfaceMaterial {
    let elevation: CGFloat
    let color: Color
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let cornerRadius: CGFloat
}
```

#### View Extensions

```swift
extension View {
    func surfaceMaterial(
        elevation: CGFloat = DesignToken.Elevation.level1,
        cornerRadius: CGFloat = 12,
        stroke: StrokeConfiguration? = nil
    ) -> some View
    
    func overlayMaterial(
        elevation: CGFloat = DesignToken.Elevation.level2,
        cornerRadius: CGFloat = 8
    ) -> some View
    
    func modalMaterial(
        elevation: CGFloat = DesignToken.Elevation.level5,
        cornerRadius: CGFloat = 16
    ) -> some View
}
```

---

### OCRService

**Purpose**: High-accuracy text extraction from screenshots using VisionKit.

```swift
@MainActor
final class OCRService: ObservableObject
```

#### Public Methods

```swift
// Extract text from image data
func extractText(from imageData: Data) async -> String?

// Process multiple screenshots in background
func processScreenshots(_ screenshots: [Screenshot]) async

// Check if OCR is available
static func isOCRAvailable() -> Bool
```

#### Usage Example

```swift
let ocrService = OCRService()
let extractedText = await ocrService.extractText(from: screenshot.imageData)
```

---

### SearchService & AdvancedSearchService

**Purpose**: Intelligent search with full-text capabilities and advanced filtering.

```swift
protocol SearchServiceProtocol {
    func searchScreenshots(query: String, in screenshots: [Screenshot]) -> [Screenshot]
}

protocol AdvancedSearchServiceProtocol: SearchServiceProtocol {
    func searchScreenshots(
        query: String,
        in screenshots: [Screenshot],
        filters: SearchFilters
    ) -> [Screenshot]
}
```

#### Search Filters

```swift
struct SearchFilters {
    var dateRange: DateRange?
    var hasText: Bool?
    var fileTypes: Set<String>
    var sortOrder: SortOrder
}

enum SortOrder: String, CaseIterable {
    case newest = "newest"
    case oldest = "oldest"
    case relevance = "relevance"
    case filename = "filename"
}
```

#### Public Methods

```swift
// Basic text search
func searchScreenshots(query: String, in screenshots: [Screenshot]) -> [Screenshot]

// Advanced search with filters
func searchScreenshots(
    query: String,
    in screenshots: [Screenshot],
    filters: SearchFilters
) -> [Screenshot]
```

---

### PhotoLibraryService

**Purpose**: Automatic screenshot detection and real-time photo library monitoring.

```swift
@MainActor
class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, ObservableObject
```

#### Public Methods

```swift
// Start monitoring photo library changes
func startMonitoring()

// Stop monitoring
func stopMonitoring()

// Check if automatic import is enabled
func isAutomaticImportEnabled() -> Bool

// Enable/disable automatic import
func setAutomaticImportEnabled(_ enabled: Bool)

// Request photo library access
func requestPhotoLibraryAccess() async -> Bool

// Fetch all screenshots from library
func fetchAllScreenshots() async -> [PHAsset]
```

---

## Data Models

### Screenshot

**Purpose**: Core data model for screenshot storage with SwiftData integration.

```swift
@Model
final class Screenshot {
    var id: UUID
    var filename: String
    var imageData: Data
    var timestamp: Date
    var extractedText: String?
    var fileSize: Int64
    var imageWidth: Int
    var imageHeight: Int
    var thumbnailData: Data?
    
    init(imageData: Data, filename: String)
}
```

#### Properties

- **id**: Unique identifier (UUID)
- **filename**: Original filename from photo library
- **imageData**: Raw image data
- **timestamp**: Date when screenshot was taken
- **extractedText**: OCR-extracted text content
- **fileSize**: Image file size in bytes
- **imageWidth/Height**: Image dimensions
- **thumbnailData**: Cached thumbnail for performance

---

## View Components

### Hero Animation View Modifiers

```swift
extension View {
    // Apply general hero animation effect
    func heroAnimation(
        id: String,
        in namespace: Namespace.ID,
        transitionType: HeroAnimationService.TransitionType = .gridToDetail
    ) -> some View
    
    // Mark view as hero animation source
    func heroSource(
        id: String,
        in namespace: Namespace.ID,
        transitionType: HeroAnimationService.TransitionType = .gridToDetail
    ) -> some View
    
    // Mark view as hero animation destination
    func heroDestination(
        id: String,
        in namespace: Namespace.ID,
        transitionType: HeroAnimationService.TransitionType = .gridToDetail
    ) -> some View
}
```

### Material Design View Modifiers

```swift
extension View {
    // Apply surface material styling
    func surfaceMaterial(
        elevation: CGFloat = DesignToken.Elevation.level1,
        cornerRadius: CGFloat = 12,
        stroke: StrokeConfiguration? = nil
    ) -> some View
    
    // Apply overlay material styling  
    func overlayMaterial(
        elevation: CGFloat = DesignToken.Elevation.level2,
        cornerRadius: CGFloat = 8
    ) -> some View
    
    // Apply modal material styling
    func modalMaterial(
        elevation: CGFloat = DesignToken.Elevation.level5,
        cornerRadius: CGFloat = 16
    ) -> some View
}
```

---

## Performance Guidelines

### Animation Performance

```swift
// Target performance metrics
struct PerformanceTargets {
    static let proMotionFrameRate: Double = 120.0
    static let standardFrameRate: Double = 60.0
    static let maxResponseTime: TimeInterval = 0.05 // 50ms
    static let maxMemoryIncrease: Double = 2.0 // MB
}
```

### Memory Management

```swift
// Memory thresholds for edge case handling
struct MemoryThresholds {
    static let normal: Double = 50.0 // MB
    static let warning: Double = 80.0 // MB
    static let critical: Double = 200.0 // MB
}
```

### Testing Requirements

```swift
// Performance validation requirements
protocol PerformanceValidatable {
    func validateFrameRate() -> Bool
    func validateMemoryUsage() -> Bool
    func validateResponseTime() -> Bool
}
```

---

## Error Handling

### Animation Errors

```swift
enum HeroAnimationError: Error {
    case namespaceNotFound
    case animationInProgress
    case memoryPressure
    case thermalThrottling
    case unsupportedTransition
}
```

### OCR Errors

```swift
enum OCRError: Error {
    case notAvailable
    case processingFailed
    case invalidImageData
    case textNotFound
}
```

### Photo Library Errors

```swift
enum PhotoLibraryError: Error {
    case accessDenied
    case notAvailable
    case fetchFailed
    case monitoringFailed
}
```

---

## Usage Examples

### Complete Hero Animation Implementation

```swift
struct ExampleView: View {
    @StateObject private var heroService = HeroAnimationService.shared
    @Namespace private var heroNamespace
    @State private var selectedItem: Item?
    
    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(items) { item in
                ItemThumbnail(item: item)
                    .heroSource(
                        id: "item_\(item.id)",
                        in: heroNamespace,
                        transitionType: .gridToDetail
                    )
                    .onTapGesture {
                        heroService.startTransition(
                            .gridToDetail,
                            from: "item_\(item.id)",
                            to: "detail_\(item.id)"
                        )
                        selectedItem = item
                    }
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            ItemDetailView(item: item, heroNamespace: heroNamespace)
        }
    }
}
```

### OCR Processing with Progress

```swift
struct OCRProcessingExample: View {
    @StateObject private var ocrService = OCRService()
    @State private var isProcessing = false
    @State private var progress: Double = 0.0
    
    func processScreenshots() {
        isProcessing = true
        Task {
            await ocrService.processScreenshots(screenshots)
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}
```

---

**API Version**: 1.0.0  
**Last Updated**: Post Sub-Sprint 4.2 completion  
**Platform Compatibility**: iOS 18.0+