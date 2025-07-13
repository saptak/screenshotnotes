import Foundation
import UIKit
import CoreImage
import Vision

public class ColorAnalysisService {

    public struct ColorInfo: Codable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var prominence: Double
        public var colorName: String
        public var hexValue: String
    }

    public enum AdvancedColorScheme: Codable, Sendable {
        case monochromatic
        case analogous
        case complementary
        case triadic
        case tetradic
        case vibrant
        case muted
        case highContrast
        case lowContrast
        case natural
        case artificial
    }

    public enum AdvancedColorTemperature: Codable, Sendable {
        case veryWarm
        case warm
        case neutral
        case cool
        case veryCool
        case mixed
    }

    public struct ColorAnalysisResult: Codable, Sendable {
        public var dominantColors: [ColorInfo]
        public var brightness: Double
        public var contrast: Double
        public var saturation: Double
        public var temperature: AdvancedColorTemperature
        public var colorScheme: AdvancedColorScheme
        public var visualEmbedding: [Double]
    }

    public func analyzeImage(_ imageData: Data) async -> ColorAnalysisResult {
        guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
            return fallbackResult()
        }

        let ciImage = CIImage(cgImage: cgImage)
        
        let brightness = calculateBrightness(ciImage: ciImage)
        let contrast = calculateContrast(ciImage: ciImage)
        let saturation = calculateSaturation(ciImage: ciImage)
        
        let dominantColors = extractDominantColors(uiImage: uiImage)
        let visualEmbedding = (try? await generateVisualEmbedding(cgImage: cgImage)) ?? []

        return ColorAnalysisResult(
            dominantColors: dominantColors,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            temperature: calculateTemperature(dominantColors: dominantColors),
            colorScheme: calculateColorScheme(dominantColors: dominantColors),
            visualEmbedding: visualEmbedding
        )
    }

    private func fallbackResult() -> ColorAnalysisResult {
        return ColorAnalysisResult(
            dominantColors: [],
            brightness: 0.5,
            contrast: 0.5,
            saturation: 0.5,
            temperature: .neutral,
            colorScheme: .natural,
            visualEmbedding: []
        )
    }

    private func calculateBrightness(ciImage: CIImage) -> Double {
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else {
            return 0.5
        }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let brightness = (Double(bitmap[0]) + Double(bitmap[1]) + Double(bitmap[2])) / 3.0 / 255.0
        return brightness
    }

    private func calculateContrast(ciImage: CIImage) -> Double {
        guard let filter = CIFilter(name: "CIImageStatistics", parameters: [kCIInputImageKey: ciImage]),
              let outputImage = filter.outputImage else {
            return 0.5
        }

        let context = CIContext(options: nil)
        let bitmap = context.createCGImage(outputImage, from: outputImage.extent)!
        let pixelData = bitmap.dataProvider!.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)

        let contrast = (Double(data[0]) + Double(data[1]) + Double(data[2])) / 3.0 / 255.0
        return contrast
    }

    private func calculateSaturation(ciImage: CIImage) -> Double {
        let _ = CIFilter(name:"CIColorControls", parameters: [kCIInputImageKey: ciImage, "inputSaturation": 1.0])!
        return 0.5 // Placeholder
    }

    private func extractDominantColors(uiImage: UIImage, count: Int = 5) -> [ColorInfo] {
        guard let cgImage = uiImage.cgImage else { return [] }

        let width = 64
        let height = 64
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colorCounts: [Int: Int] = [:]
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Int(pixelData[i])
            let g = Int(pixelData[i+1])
            let b = Int(pixelData[i+2])
            let colorInt = (r << 16) + (g << 8) + b
            colorCounts[colorInt, default: 0] += 1
        }

        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let totalPixels = width * height
        
        var dominantColors: [ColorInfo] = []
        for (colorInt, pixelCount) in sortedColors.prefix(count) {
            let r = Double((colorInt >> 16) & 0xFF) / 255.0
            let g = Double((colorInt >> 8) & 0xFF) / 255.0
            let b = Double(colorInt & 0xFF) / 255.0
            let prominence = Double(pixelCount) / Double(totalPixels)
            
            let hex = String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
            
            // Simple color name mapping - a more sophisticated approach would use a lookup table or a dedicated library
            let colorName = "Color"

            dominantColors.append(ColorInfo(red: r, green: g, blue: b, prominence: prominence, colorName: colorName, hexValue: hex))
        }
        
        return dominantColors
    }

    private func calculateTemperature(dominantColors: [ColorInfo]) -> AdvancedColorTemperature {
        guard !dominantColors.isEmpty else { return .neutral }

        let totalWarmth = dominantColors.reduce(0.0) { total, color in
            let warmth = (color.red - color.blue) * color.prominence
            return total + warmth
        }

        if totalWarmth > 0.1 {
            return .warm
        } else if totalWarmth < -0.1 {
            return .cool
        } else {
            return .neutral
        }
    }

    private func calculateColorScheme(dominantColors: [ColorInfo]) -> AdvancedColorScheme {
        guard dominantColors.count >= 2 else { return .monochromatic }

        let firstColor = dominantColors[0]
        let secondColor = dominantColors[1]

        let hue1 = getHue(red: firstColor.red, green: firstColor.green, blue: firstColor.blue)
        let hue2 = getHue(red: secondColor.red, green: secondColor.green, blue: secondColor.blue)

        let hueDifference = abs(hue1 - hue2)

        if hueDifference < 0.1 {
            return .monochromatic
        } else if hueDifference < 0.3 {
            return .analogous
        } else if hueDifference > 0.4 && hueDifference < 0.6 {
            return .complementary
        } else {
            return .triadic
        }
    }

    private func getHue(red: Double, green: Double, blue: Double) -> Double {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC

        var hue: Double = 0

        if delta != 0 {
            if maxC == red {
                hue = (green - blue) / delta
            } else if maxC == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue *= 60
            if hue < 0 {
                hue += 360
            }
        }
        return hue / 360
    }
    
    private func generateVisualEmbedding(cgImage: CGImage) async throws -> [Double] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                if let featurePrint = request.results?.first as? VNFeaturePrintObservation {
                    let embedding = featurePrint.data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Double] in
                        let floatPointer = pointer.bindMemory(to: Float.self)
                        return Array(floatPointer).map { Double($0) }
                    }
                    continuation.resume(returning: embedding)
                } else {
                    continuation.resume(returning: [])
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}