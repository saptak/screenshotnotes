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
        
        // Update FPS (simplified - real implementation would use CADisplayLink)
        liquidGlassFPS = optimizationMode == .performance ? 60.0 : 
                        optimizationMode == .balanced ? 45.0 : 30.0
        
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