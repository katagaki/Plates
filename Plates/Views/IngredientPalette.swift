import SwiftUI
import UIKit

/// The colours a recipe is drawn in, taken from the ingredient icons themselves. Each icon is
/// averaged down to the one colour it reads as, so a tomato is red and spinach is green
/// without a colour ever being written down by hand.
enum IngredientPalette {
    /// Averaged icon colours, kept for as long as the app runs so a scrolling grid measures
    /// each icon once.
    private static var cache: [String: Color?] = [:]

    /// The four corner colours a recipe's card blends. Ingredients are read in the order they
    /// are written, the flattest ones are passed over, and a short list is filled out by
    /// shading the colours it does have.
    static func colors(for recipe: Recipe, in scheme: ColorScheme) -> [Color] {
        let paths = (recipe.ingredients.supermarket ?? []).map(\.icon)
            + (recipe.ingredients.general ?? []).map(\.icon)
        let candidates = paths.compactMap(color(forIcon:))
        let picked = spread(candidates)
        guard !picked.isEmpty else { return fallback.map { $0.tuned(for: scheme) } }
        var colors = picked
        let shades = [0.10, -0.10, 0.18]
        var index = 0
        while colors.count < 4 {
            colors.append(picked[index % picked.count].shaded(by: shades[index % shades.count]))
            index += 1
        }
        return colors.map { $0.tuned(for: scheme) }
    }

    /// Colours that read as their own, so a card of four near identical greens does not
    /// happen. Anything passed over is put back on the end to fill the four out.
    private static func spread(_ candidates: [Color]) -> [Color] {
        var picked: [Color] = []
        var rest: [Color] = []
        for color in candidates {
            let hue = color.hsb.hue
            if picked.contains(where: { abs(hueDistance($0.hsb.hue, hue)) < 0.06 }) {
                rest.append(color)
            } else {
                picked.append(color)
            }
            if picked.count == 4 { return picked }
        }
        return Array((picked + rest).prefix(4))
    }

    /// How far apart two hues are on the wheel, the short way round.
    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let difference = abs(a - b)
        return min(difference, 1 - difference)
    }

    /// The one colour an ingredient icon averages out to, or nothing when the icon is missing
    /// or too washed out to colour a card with.
    private static func color(forIcon path: String) -> Color? {
        guard let asset = IconCatalog.assetName(for: path) else { return nil }
        if let cached = cache[asset] { return cached }
        let color = averageColor(ofAsset: asset).flatMap { $0.hsb.saturation < 0.18 ? nil : $0 }
        cache[asset] = color
        return color
    }

    /// The icon drawn small and averaged, weighting each pixel by how opaque it is so the
    /// transparent ground around the shape counts for nothing.
    private static func averageColor(ofAsset asset: String) -> Color? {
        guard let image = UIImage(named: asset)?.cgImage else { return nil }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[pixel + 3]) / 255
            guard alpha > 0 else { continue }
            red += Double(pixels[pixel]) / 255
            green += Double(pixels[pixel + 1]) / 255
            blue += Double(pixels[pixel + 2]) / 255
            weight += alpha
        }
        guard weight > 0 else { return nil }
        return Color(red: red / weight, green: green / weight, blue: blue / weight)
    }

    /// What a recipe with nothing to take a colour from is drawn in.
    private static let fallback: [Color] = [
        Color(red: 0.85, green: 0.80, blue: 0.70),
        Color(red: 0.78, green: 0.82, blue: 0.72),
        Color(red: 0.88, green: 0.78, blue: 0.72),
        Color(red: 0.80, green: 0.78, blue: 0.82),
    ]
}

private extension Color {
    /// The colour read back as hue, saturation, and brightness.
    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (Double(hue), Double(saturation), Double(brightness))
    }

    /// The same colour pulled into the range a card reads well in: pale and light against a
    /// white card, deeper and darker against a black one, so the title keeps its contrast
    /// either way and neither a pale flour nor a near black squid ink flattens the blend.
    func tuned(for scheme: ColorScheme) -> Color {
        let hsb = hsb
        let saturation = scheme == .dark ? (0.35, 0.72) : (0.22, 0.62)
        let brightness = scheme == .dark ? (0.30, 0.46) : (0.55, 0.92)
        return Color(
            hue: hsb.hue,
            saturation: min(max(hsb.saturation, saturation.0), saturation.1),
            brightness: min(max(hsb.brightness, brightness.0), brightness.1)
        )
    }

    /// The same colour lifted or dropped in brightness, used to fill a short list out.
    func shaded(by amount: Double) -> Color {
        let hsb = hsb
        return Color(
            hue: hsb.hue,
            saturation: min(max(hsb.saturation + amount * 0.2, 0.18), 0.7),
            brightness: min(max(hsb.brightness + amount, 0.5), 0.95)
        )
    }
}
