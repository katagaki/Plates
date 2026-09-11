import SwiftUI
import UIKit

/// The colours a recipe is drawn in, taken from the ingredient icons themselves. Each icon is
/// read down to the one colour it reads as, so a tomato is red and spinach is green without a
/// colour ever being written down by hand. The cache below is shared, and the cards that read
/// it are drawn on the main actor, so the whole of it is held there.
@MainActor
enum IngredientPalette {
    /// Icon colours, kept for as long as the app runs so a scrolling grid measures each icon
    /// once.
    private static var cache: [String: Color?] = [:]

    /// The four corner colours a recipe's card blends, taken from across the whole ingredient
    /// list rather than the first few entries of it. A short list is filled out by shading the
    /// colours it does have.
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

    /// The four colours that sit furthest apart on the wheel, so a card takes from the whole
    /// list instead of the ingredients that happen to be written first. The first ingredient
    /// leads, then each pick is whichever colour is least like the ones already held.
    private static func spread(_ candidates: [Color]) -> [Color] {
        guard let first = candidates.first else { return [] }
        var picked = [first]
        var rest = Array(candidates.dropFirst())
        while picked.count < 4, !rest.isEmpty {
            let hues = picked.map(\.hsb.hue)
            let scored = rest.enumerated().max { left, right in
                distance(left.element, from: hues) < distance(right.element, from: hues)
            }
            guard let next = scored, distance(next.element, from: hues) >= 0.04 else { break }
            picked.append(next.element)
            rest.remove(at: next.offset)
        }
        return picked
    }

    /// How far a colour sits from the nearest hue already picked.
    private static func distance(_ color: Color, from hues: [Double]) -> Double {
        let hue = color.hsb.hue
        return hues.map { hueDistance($0, hue) }.min() ?? 1
    }

    /// How far apart two hues are on the wheel, the short way round.
    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let difference = abs(a - b)
        return min(difference, 1 - difference)
    }

    /// The one colour an ingredient icon reads as, or nothing when the icon is missing or has
    /// no colour in it to draw a card with.
    private static func color(forIcon path: String) -> Color? {
        guard let asset = IconCatalog.assetName(for: path) else { return nil }
        if let cached = cache[asset] { return cached }
        let color = dominantColor(ofAsset: asset)
        cache[asset] = color
        return color
    }

    /// The icon drawn small and sorted into hue bins, each pixel counting for as much as it is
    /// opaque and saturated. The heaviest bin wins, which is the colour the icon reads as.
    /// Averaging the pixels instead would mix a green stalk into a red body and hand back the
    /// muddy yellow that lies between them.
    private static func dominantColor(ofAsset asset: String) -> Color? {
        guard let image = UIImage(named: asset)?.cgImage else { return nil }
        let side = 32
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

        let bins = 18
        var weights = [Double](repeating: 0, count: bins)
        var sines = [Double](repeating: 0, count: bins)
        var cosines = [Double](repeating: 0, count: bins)
        var saturations = [Double](repeating: 0, count: bins)
        var brightnesses = [Double](repeating: 0, count: bins)

        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[pixel + 3]) / 255
            guard alpha > 0.35 else { continue }
            let hsb = components(
                red: min(Double(pixels[pixel]) / 255 / alpha, 1),
                green: min(Double(pixels[pixel + 1]) / 255 / alpha, 1),
                blue: min(Double(pixels[pixel + 2]) / 255 / alpha, 1)
            )
            guard hsb.saturation > 0.2, hsb.brightness > 0.12 else { continue }
            let bin = min(Int(hsb.hue * Double(bins)), bins - 1)
            let weight = alpha * hsb.saturation
            let angle = hsb.hue * 2 * .pi
            weights[bin] += weight
            sines[bin] += sin(angle) * weight
            cosines[bin] += cos(angle) * weight
            saturations[bin] += hsb.saturation * weight
            brightnesses[bin] += hsb.brightness * weight
        }

        guard let bin = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[bin] > 0.5
        else { return nil }
        let weight = weights[bin]
        var hue = atan2(sines[bin], cosines[bin]) / (2 * .pi)
        if hue < 0 { hue += 1 }
        return Color(
            hue: hue,
            saturation: saturations[bin] / weight,
            brightness: brightnesses[bin] / weight
        )
    }

    /// A straight colour read as hue, saturation, and brightness, done by hand so a whole
    /// icon's worth of pixels is not run through `UIColor` one at a time.
    private static func components(
        red: Double,
        green: Double,
        blue: Double
    ) -> (hue: Double, saturation: Double, brightness: Double) {
        let high = max(red, green, blue)
        let low = min(red, green, blue)
        let range = high - low
        guard range > 0 else { return (0, 0, high) }
        var hue: Double
        switch high {
        case red: hue = (green - blue) / range / 6
        case green: hue = (2 + (blue - red) / range) / 6
        default: hue = (4 + (red - green) / range) / 6
        }
        if hue < 0 { hue += 1 }
        return (hue, range / high, high)
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

    /// The same colour pulled into the range a card reads well in: full enough to carry white
    /// text in either appearance, a little brighter in light mode than in dark, so neither a
    /// pale flour nor a near black squid ink flattens the blend.
    func tuned(for scheme: ColorScheme) -> Color {
        let hsb = hsb
        let saturation = scheme == .dark ? (0.62, 0.95) : (0.55, 0.90)
        let brightness = scheme == .dark ? (0.42, 0.58) : (0.54, 0.68)
        return Color(
            hue: hsb.hue,
            saturation: min(max(hsb.saturation, saturation.0), saturation.1),
            brightness: min(max(hsb.brightness, brightness.0), brightness.1)
        )
    }

    /// The same colour lifted or dropped in brightness, used to fill a short list out. What
    /// comes back is tuned afterwards, so the clamps here only keep the shading from running
    /// away.
    func shaded(by amount: Double) -> Color {
        let hsb = hsb
        return Color(
            hue: hsb.hue,
            saturation: min(max(hsb.saturation + amount * 0.2, 0.18), 0.95),
            brightness: min(max(hsb.brightness + amount, 0.2), 0.95)
        )
    }
}
