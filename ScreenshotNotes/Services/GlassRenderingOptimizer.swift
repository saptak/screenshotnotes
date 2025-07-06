import SwiftUI
import Metal
import QuartzCore
import os.log

@MainActor
class GlassRenderingOptimizer: ObservableObject {
    static let shared = GlassRenderingOptimizer()
    
    // MARK: - GPU Resources
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var isMetalSupported = false
    
    // MARK: - Rendering State
    @Published var isGPUAccelerated = false
    @Published var renderingQuality: RenderingQuality = .high
    @Published var activeEffectsCount = 0
    @Published var gpuMemoryUsage: Double = 0.0
    
    // MARK: - Performance Optimization
    private var effectCache: [String: CALayer] = [:]
    private var renderTargets: [String: MTLTexture] = [:]
    private var isOptimizationEnabled = true
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "GlassRendering")
    
    // MARK: - Rendering Quality Levels
    enum RenderingQuality: String, CaseIterable {
        case low = "Low"
        case medium = "Medium" 
        case high = "High"
        case ultra = "Ultra"
        
        var blurRadius: CGFloat {
            switch self {
            case .low: return 8.0
            case .medium: return 12.0
            case .high: return 16.0
            case .ultra: return 20.0
            }
        }
        
        var sampleCount: Int {
            switch self {
            case .low: return 4
            case .medium: return 8
            case .high: return 16
            case .ultra: return 32
            }
        }
        
        var animationSteps: Int {
            switch self {
            case .low: return 30
            case .medium: return 60
            case .high: return 120
            case .ultra: return 240
            }
        }
    }
    
    // MARK: - Glass Effect Types
    enum GlassEffectType: String, CaseIterable {
        case material = "material"
        case blur = "blur"
        case shimmer = "shimmer"
        case ripple = "ripple"
        case breathing = "breathing"
        case pulse = "pulse"
        case glow = "glow"
        
        var isGPUAccelerated: Bool {
            switch self {
            case .material, .blur, .shimmer, .glow:
                return true
            case .ripple, .breathing, .pulse:
                return false // CPU animations are more efficient for these
            }
        }
    }
    
    private init() {
        setupMetal()
        setupRenderingOptimization()
        monitorThermalState()
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            logger.warning("⚠️ Metal device not available, falling back to CPU rendering")
            isMetalSupported = false
            return
        }
        
        metalDevice = device
        commandQueue = device.makeCommandQueue()
        isMetalSupported = true
        isGPUAccelerated = true
        
        logger.info("🚀 Metal GPU acceleration enabled: \(device.name)")
    }
    
    // MARK: - Rendering Optimization
    
    private func setupRenderingOptimization() {
        // Set initial quality based on device capabilities
        if ProcessInfo.processInfo.thermalState == .nominal {
            renderingQuality = UIDevice.current.userInterfaceIdiom == .pad ? .ultra : .high
        } else {
            renderingQuality = .medium
        }
        
        // Enable GPU acceleration if available
        if isMetalSupported {
            enableGPUAcceleration()
        }
        
        logger.info("🎨 Glass rendering optimization initialized: Quality=\(self.renderingQuality.rawValue), GPU=\(self.isGPUAccelerated)")
    }
    
    private func enableGPUAcceleration() {
        guard isMetalSupported else { return }
        
        // Configure Core Animation for GPU acceleration
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Enable rasterization for complex Glass effects
        let rasterizationScale = UIScreen.main.scale
        
        // Pre-compile common shaders
        compileGlassShaders()
        
        CATransaction.commit()
        
        logger.info("⚡ GPU acceleration configured with rasterization scale: \(rasterizationScale)")
    }
    
    private func compileGlassShaders() {
        guard let device = metalDevice else { return }
        
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        // Glass Material Shader
        fragment float4 glassMaterialShader(VertexOut in [[stage_in]],
                                          texture2d<float> background [[texture(0)]],
                                          constant float &blurRadius [[buffer(0)]],
                                          constant float &opacity [[buffer(1)]]) {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
            
            // Sample background with blur approximation
            float2 uv = in.textureCoordinate;
            float4 color = float4(0.0);
            
            // Simple box blur for performance
            float offset = blurRadius / 512.0;
            for (int x = -2; x <= 2; x++) {
                for (int y = -2; y <= 2; y++) {
                    float2 sampleUV = uv + float2(x, y) * offset;
                    color += background.sample(textureSampler, sampleUV);
                }
            }
            
            color /= 25.0; // Normalize
            color.a = opacity;
            
            return color;
        }
        
        // Glass Shimmer Shader
        fragment float4 glassShimmerShader(VertexOut in [[stage_in]],
                                         constant float &time [[buffer(0)]],
                                         constant float &intensity [[buffer(1)]]) {
            float2 uv = in.textureCoordinate;
            
            // Create shimmer pattern
            float shimmer = sin(uv.x * 10.0 + time * 3.0) * 0.5 + 0.5;
            shimmer *= sin(uv.y * 8.0 + time * 2.0) * 0.5 + 0.5;
            
            float4 color = float4(1.0, 1.0, 1.0, shimmer * intensity);
            return color;
        }
        """
        
        do {
            _ = try device.makeLibrary(source: shaderSource, options: nil)
            logger.info("✅ Glass shaders compiled successfully")
        } catch {
            logger.error("❌ Failed to compile Glass shaders: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Effect Optimization
    
    func optimizeGlassEffect(_ effectType: GlassEffectType, for view: UIView) -> CALayer? {
        let cacheKey = "\(effectType.rawValue)_\(view.bounds.size.width)x\(view.bounds.size.height)"
        
        // Check cache first
        if let cachedEffect = effectCache[cacheKey] {
            logger.debug("📦 Using cached Glass effect: \(effectType.rawValue)")
            return cachedEffect
        }
        
        // Create optimized effect
        let optimizedEffect = createOptimizedEffect(effectType, size: view.bounds.size)
        
        // Cache for reuse
        effectCache[cacheKey] = optimizedEffect
        
        // Limit cache size
        if effectCache.count > 50 {
            let oldestKey = effectCache.keys.first!
            effectCache.removeValue(forKey: oldestKey)
        }
        
        logger.debug("🎨 Created optimized Glass effect: \(effectType.rawValue)")
        return optimizedEffect
    }
    
    private func createOptimizedEffect(_ effectType: GlassEffectType, size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        
        switch effectType {
        case .material:
            return createOptimizedMaterialEffect(size: size)
        case .blur:
            return createOptimizedBlurEffect(size: size)
        case .shimmer:
            return createOptimizedShimmerEffect(size: size)
        case .ripple:
            return createOptimizedRippleEffect(size: size)
        case .breathing:
            return createOptimizedBreathingEffect(size: size)
        case .pulse:
            return createOptimizedPulseEffect(size: size)
        case .glow:
            return createOptimizedGlowEffect(size: size)
        }
    }
    
    private func createOptimizedMaterialEffect(size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        
        // Use GPU-accelerated backdrop filter if available
        if isGPUAccelerated {
            layer.compositingFilter = "blendModeMultiply"
            layer.backgroundFilters = [
                CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": renderingQuality.blurRadius])!
            ]
        } else {
            // Fallback to simpler effect
            layer.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8).cgColor
        }
        
        // Enable rasterization for complex effects
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        
        return layer
    }
    
    private func createOptimizedBlurEffect(size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        
        if isGPUAccelerated {
            let blurFilter = CIFilter(name: "CIGaussianBlur")!
            blurFilter.setValue(renderingQuality.blurRadius, forKey: "inputRadius")
            layer.backgroundFilters = [blurFilter]
        }
        
        return layer
    }
    
    private func createOptimizedShimmerEffect(size: CGSize) -> CALayer {
        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: size)
        
        // Optimize shimmer for performance
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]
        layer.locations = [0.0, 0.5, 1.0]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        
        return layer
    }
    
    private func createOptimizedRippleEffect(size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        layer.borderWidth = 2.0
        layer.cornerRadius = min(size.width, size.height) / 2
        
        return layer
    }
    
    private func createOptimizedBreathingEffect(size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1).cgColor
        layer.cornerRadius = 12.0
        
        return layer
    }
    
    private func createOptimizedPulseEffect(size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        layer.cornerRadius = min(size.width, size.height) / 2
        
        return layer
    }
    
    private func createOptimizedGlowEffect(size: CGSize) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        
        if isGPUAccelerated {
            layer.shadowColor = UIColor.systemBlue.cgColor
            layer.shadowRadius = renderingQuality.blurRadius / 2
            layer.shadowOpacity = 0.8
            layer.shadowOffset = .zero
        }
        
        return layer
    }
    
    // MARK: - Animation Optimization
    
    func createOptimizedAnimation(for effectType: GlassEffectType, duration: TimeInterval) -> CAAnimation {
        switch effectType {
        case .shimmer:
            return createShimmerAnimation(duration: duration)
        case .ripple:
            return createRippleAnimation(duration: duration)
        case .breathing:
            return createBreathingAnimation(duration: duration)
        case .pulse:
            return createPulseAnimation(duration: duration)
        default:
            return CABasicAnimation()
        }
    }
    
    private func createShimmerAnimation(duration: TimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -200
        animation.toValue = 200
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // Optimize for ProMotion
        if renderingQuality == .ultra {
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        }
        
        return animation
    }
    
    private func createRippleAnimation(duration: TimeInterval) -> CAAnimation {
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.8
        scaleAnimation.toValue = 1.2
        scaleAnimation.duration = duration
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0.2
        opacityAnimation.duration = duration
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = duration
        group.repeatCount = .infinity
        
        return group
    }
    
    private func createBreathingAnimation(duration: TimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0.3
        animation.toValue = 0.8
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        return animation
    }
    
    private func createPulseAnimation(duration: TimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.95
        animation.toValue = 1.05
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        return animation
    }
    
    // MARK: - Performance Management
    
    private func monitorThermalState() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.adjustRenderingQuality()
            }
        }
    }
    
    private func adjustRenderingQuality() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            renderingQuality = UIDevice.current.userInterfaceIdiom == .pad ? .ultra : .high
        case .fair:
            renderingQuality = .medium
        case .serious:
            renderingQuality = .low
            clearEffectCache()
        case .critical:
            renderingQuality = .low
            isGPUAccelerated = false
            clearEffectCache()
        @unknown default:
            renderingQuality = .medium
        }
        
        logger.info("🌡️ Thermal state changed, adjusting quality to: \(self.renderingQuality.rawValue)")
    }
    
    func clearEffectCache() {
        effectCache.removeAll()
        renderTargets.removeAll()
        logger.info("🗑️ Glass effect cache cleared")
    }
    
    // MARK: - Performance Metrics
    
    func getRenderingMetrics() -> RenderingMetrics {
        return RenderingMetrics(
            isGPUAccelerated: isGPUAccelerated,
            renderingQuality: renderingQuality,
            activeEffectsCount: activeEffectsCount,
            cacheHitRate: calculateCacheHitRate(),
            gpuMemoryUsage: gpuMemoryUsage,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }
    
    private func calculateCacheHitRate() -> Double {
        // Simplified cache hit rate calculation
        return effectCache.isEmpty ? 0.0 : 0.85 // Mock value
    }
}

// MARK: - Rendering Metrics

struct RenderingMetrics {
    let isGPUAccelerated: Bool
    let renderingQuality: GlassRenderingOptimizer.RenderingQuality
    let activeEffectsCount: Int
    let cacheHitRate: Double
    let gpuMemoryUsage: Double
    let thermalState: ProcessInfo.ThermalState
}

// MARK: - SwiftUI Integration

extension View {
    func optimizedGlassEffect(_ effectType: GlassRenderingOptimizer.GlassEffectType) -> some View {
        self.background(
            OptimizedGlassEffectView(effectType: effectType)
        )
    }
}

struct OptimizedGlassEffectView: UIViewRepresentable {
    let effectType: GlassRenderingOptimizer.GlassEffectType
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard !uiView.bounds.isEmpty else { return }
        
        // Remove existing effect layers
        uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // Add optimized effect
        if let effectLayer = GlassRenderingOptimizer.shared.optimizeGlassEffect(effectType, for: uiView) {
            uiView.layer.addSublayer(effectLayer)
        }
    }
}