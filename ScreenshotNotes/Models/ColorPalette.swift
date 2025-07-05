import Foundation
import SwiftUI

public struct ColorPalette: Codable, Sendable {
    public let primaryColor: ColorInfo
    public let secondaryColor: ColorInfo
    public let accentColor: ColorInfo
}

public struct ColorInfo: Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}