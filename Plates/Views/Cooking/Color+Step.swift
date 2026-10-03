import SwiftUI
import UIKit

extension Color {
    /// The background of one step in cooking mode. Each step turns the hue on by the golden
    /// angle, so no two steps in a recipe share a colour and neighbours are never close. The
    /// colour is then darkened until white text on it passes 7:1, which reads at arm's length
    /// and across a kitchen.
    static func step(_ index: Int) -> Color {
        let hue = (0.58 + Double(index) * 0.381966).truncatingRemainder(dividingBy: 1)
        let saturation = 0.55
        var brightness = 0.75
        while brightness > 0.2,
              contrastWithWhite(hue: hue, saturation: saturation, brightness: brightness) < 7 {
            brightness -= 0.01
        }
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private static func contrastWithWhite(hue: Double, saturation: Double, brightness: Double) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
            .getRed(&red, green: &green, blue: &blue, alpha: nil)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return 1.05 / (luminance + 0.05)
    }
}
