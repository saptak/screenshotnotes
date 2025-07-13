//
//  LiquidGlassPerformanceMonitor.swift
//  ScreenshotNotes
//
//  Sprint 8.1.2: Liquid Glass Performance Monitoring
//  Created by Assistant on 7/13/25.
//

import Foundation
import SwiftUI
import Combine

/// Performance monitoring service for Liquid Glass rendering and user experience
/// Tracks rendering performance, memory usage, and user interaction metrics
@MainActor
class LiquidGlassPerformanceMonitor: ObservableObject {
    static let shared = LiquidGlassPerformanceMonitor()
    
    // MARK: - Performance Metrics
    
    /// Current rendering FPS for Liquid Glass materials
    @Published var liquidGlassFPS: Double = 60.0
    
    /// Memory usage specific to Liquid Glass rendering (MB)
    @Published var liquidGlassMemoryUsage: Double = 0.0
    
    /// Whether Liquid Glass rendering is currently active
    @Published var isLiquidGlassActive: Bool = false
    
    /// Performance warning level
    @Published var performanceWarningLevel: WarningLevel = .none
    
    /// Rendering optimization mode
    @Published var optimizationMode: OptimizationMode = .balanced
    
    /// ProMotion display refresh rate tracking (Sprint 8.1.3)
    @Published var displayRefreshRate: Double = 60.0
    
    /// Target frame rate for current session
    @Published var targetFrameRate: Double = 120.0
    
    /// Advanced renderer integration (Sprint 8.1.3)
    private var renderer: LiquidGlassRenderer {
        return LiquidGlassRenderer.shared
    }
    
    // MARK: - A/B Testing Metrics
    
    /// Material switch frequency for A/B testing analysis
    @Published var materialSwitchCount: Int = 0
    
    /// Average rating per material type
    @Published var materialRatings: [String: Double] = [:]
    
    /// Session duration with Enhanced Interface
    @Published var enhancedInterfaceSessionDuration: TimeInterval = 0
    
    // MARK: - Performance Thresholds
    
    enum WarningLevel: String, CaseIterable {
        case none = "none"
        case mild = "mild"
        case moderate = "moderate"
        case severe = "severe"
        
        var color: Color {
            switch self {
            case .none: return .green
            case .mild: return .yellow
            case .moderate: return .orange
            case .severe: return .red
            }
        }
        
        var description: String {
            switch self {
            case .none: return "Optimal Performance"
            case .mild: return "Minor Performance Impact"
            case .moderate: return "Moderate Performance Impact"
            case .severe: return "Significant Performance Impact"
            }
        }
    }
    
    enum OptimizationMode: String, CaseIterable {
        case performance = "performance"
        case balanced = "balanced"
        case quality = "quality"
        
        var description: String {
            switch self {
            case .performance: return "Performance Priority"
            case .balanced: return "Balanced Quality/Performance"
            case .quality: return "Quality Priority"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var sessionStartTime: Date?
    private var performanceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        loadSavedMetrics()
        setupPerformanceMonitoring()
        setupMemoryPressureMonitoring() // Sprint 8.1.3
        detectProMotionCapability() // Sprint 8.1.3
    }
    
    // MARK: - Public Interface
    
    /// Starts monitoring Liquid Glass performance
    func startMonitoring() {
        isLiquidGlassActive = true
        sessionStartTime = Date()
        
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    /// Stops monitoring and saves metrics
    func stopMonitoring() {
        isLiquidGlassActive = false
        performanceTimer?.invalidate()
        performanceTimer = nil
        
        if let startTime = sessionStartTime {
            enhancedInterfaceSessionDuration += Date().timeIntervalSince(startTime)
        }
        sessionStartTime = nil
        
        saveMetrics()
    }
    
    /// Records a material switch for A/B testing analysis
    func recordMaterialSwitch() {
        materialSwitchCount += 1
        UserDefaults.standard.set(materialSwitchCount, forKey: "liquidGlass_materialSwitchCount")
    }
    
    /// Records a material rating
    func recordMaterialRating(material: String, rating: Int) {
        // Update running average
        let currentRating = materialRatings[material] ?? 0.0
        let currentCount = UserDefaults.standard.integer(forKey: "liquidGlass_\(material)_count")
        let newCount = currentCount + 1
        
        let newAverage = ((currentRating * Double(currentCount)) + Double(rating)) / Double(newCount)
        materialRatings[material] = newAverage
        
        UserDefaults.standard.set(newAverage, forKey: "liquidGlass_\(material)_rating")
        UserDefaults.standard.set(newCount, forKey: "liquidGlass_\(material)_count")
    }
    
    /// Gets comprehensive performance report
    func getPerformanceReport() -> LiquidGlassPerformanceReport {
        return LiquidGlassPerformanceReport(
            averageFPS: liquidGlassFPS,
            memoryUsage: liquidGlassMemoryUsage,
            warningLevel: performanceWarningLevel,
            sessionDuration: enhancedInterfaceSessionDuration,
            materialSwitches: materialSwitchCount,
            materialRatings: materialRatings,
            recommendations: generateRecommendations()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupPerformanceMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func updatePerformanceMetrics() {
        // Simulate performance metrics (in real implementation, this would use Metal Performance Shaders)
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            liquidGlassMemoryUsage = Double(memoryInfo.resident_size) / 1024.0 / 1024.0
        }
        
        // Update FPS based on renderer metrics and target frame rate (Sprint 8.1.3)
        let rendererMetrics = renderer.renderingMetrics
        liquidGlassFPS = min(targetFrameRate, 
            1000.0 / max(rendererMetrics.averageFrameTime, 1.0))
        
        // Sync with renderer thermal state
        if renderer.thermalState != .nominal {
            performanceWarningLevel = switch renderer.thermalState {
            case .fair: .mild
            case .serious: .moderate
            case .critical: .severe
            default: .none
            }
        }
        
        // Optimize for display if performance is suboptimal
        if !rendererMetrics.isPerformanceOptimal {
            optimizeForDisplay()
        }
        
        // Update warning level based on metrics
        updateWarningLevel()
    }
    
    private func updateWarningLevel() {
        if liquidGlassMemoryUsage > 200 || liquidGlassFPS < 30 {
            performanceWarningLevel = .severe
        } else if liquidGlassMemoryUsage > 150 || liquidGlassFPS < 45 {
            performanceWarningLevel = .moderate
        } else if liquidGlassMemoryUsage > 100 || liquidGlassFPS < 55 {
            performanceWarningLevel = .mild
        } else {
            performanceWarningLevel = .none
        }
    }
    
    private func handleMemoryWarning() {
        optimizationMode = .performance
        performanceWarningLevel = .severe
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if performanceWarningLevel == .severe {
            recommendations.append("Consider switching to Performance mode for better stability")
        }
        
        if materialSwitchCount > 20 {
            recommendations.append("High material switching detected - consider user preference analysis")
        }
        
        let averageRating = materialRatings.values.reduce(0, +) / Double(materialRatings.count)
        if averageRating < 3.0 {
            recommendations.append("Low user satisfaction - review material design")
        }
        
        if enhancedInterfaceSessionDuration > 600 { // 10 minutes
            recommendations.append("Extended Enhanced Interface usage - excellent user adoption")
        }
        
        return recommendations
    }
    
    // MARK: - ProMotion Detection & Optimization (Sprint 8.1.3)
    
    private func detectProMotionCapability() {
        // Detect ProMotion capability using CADisplayLink
        let displayLink = CADisplayLink(target: self, selector: #selector(detectRefreshRate))
        displayLink.add(to: .main, forMode: .default)
        
        // Remove after brief detection period
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            displayLink.invalidate()
        }
    }
    
    @objc private func detectRefreshRate() {
        if #available(iOS 15.0, *) {
            // Use preferredFrameRateRange for ProMotion detection
            let displayLink = CADisplayLink(target: self, selector: #selector(detectRefreshRate))
            displayRefreshRate = Double(displayLink.targetTimestamp - displayLink.timestamp) > 0 ? 
                1.0 / (displayLink.targetTimestamp - displayLink.timestamp) : 60.0
            
            // Set optimal target frame rate based on display capability
            if displayRefreshRate >= 120.0 {
                targetFrameRate = 120.0
                print("✅ ProMotion 120Hz display detected")
            } else if displayRefreshRate >= 90.0 {
                targetFrameRate = 90.0
                print("✅ 90Hz display detected")
            } else {
                targetFrameRate = 60.0
                print("✅ Standard 60Hz display detected")
            }
        } else {
            displayRefreshRate = 60.0
            targetFrameRate = 60.0
        }
        
        // Sync with renderer
        renderer.targetFrameRate = switch targetFrameRate {
        case 120.0: .promotion120
        case 90.0: .promotion90
        default: .standard60
        }
    }
    
    /// Optimizes rendering for current display capabilities
    private func optimizeForDisplay() {
        // Adaptive quality based on display refresh rate and performance
        if displayRefreshRate >= 120.0 {
            // ProMotion device - can handle higher quality at 120fps
            if renderer.renderingMetrics.isPerformanceOptimal {
                renderer.setRenderingQuality(.balanced)
            } else {
                renderer.setRenderingQuality(.performance)
            }
        } else {
            // Standard display - optimize for 60fps
            renderer.setRenderingQuality(.quality)
        }
        
        // Sync optimization modes
        optimizationMode = switch renderer.renderingQuality {
        case .performance: .performance
        case .balanced: .balanced
        case .quality: .quality
        }
    }
    
    // MARK: - Memory Pressure Handling (Sprint 8.1.3)
    
    private func setupMemoryPressureMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryPressure()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryPressure() {
        // Immediately reduce quality to free memory
        renderer.setRenderingQuality(.performance)
        performanceWarningLevel = .severe
        
        // Clear any cached rendering data
        materialSwitchCount = max(0, materialSwitchCount - 10) // Reset some tracking
        
        print("🚨 Memory pressure detected - reducing Liquid Glass quality")
    }
    
    private func loadSavedMetrics() {
        materialSwitchCount = UserDefaults.standard.integer(forKey: "liquidGlass_materialSwitchCount")
        enhancedInterfaceSessionDuration = UserDefaults.standard.double(forKey: "liquidGlass_sessionDuration")
        
        // Load material ratings
        for material in ["ethereal", "gossamer", "crystal", "prism", "mercury"] {
            let rating = UserDefaults.standard.double(forKey: "liquidGlass_\(material)_rating")
            if rating > 0 {
                materialRatings[material] = rating
            }
        }
    }
    
    private func saveMetrics() {
        UserDefaults.standard.set(enhancedInterfaceSessionDuration, forKey: "liquidGlass_sessionDuration")
    }
}

// MARK: - Performance Report

struct LiquidGlassPerformanceReport {
    let averageFPS: Double
    let memoryUsage: Double
    let warningLevel: LiquidGlassPerformanceMonitor.WarningLevel
    let sessionDuration: TimeInterval
    let materialSwitches: Int
    let materialRatings: [String: Double]
    let recommendations: [String]
    
    var formattedSessionDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: sessionDuration) ?? "0s"
    }
}

// MARK: - mach_task_basic_info struct (for memory monitoring)

struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t = 0
    var resident_size: mach_vm_size_t = 0
    var resident_size_max: mach_vm_size_t = 0
    var user_time: time_value_t = time_value_t()
    var system_time: time_value_t = time_value_t()
    var policy: policy_t = 0
    var suspend_count: integer_t = 0
}