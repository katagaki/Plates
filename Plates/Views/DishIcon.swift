import CulinaryIntelligence
import SwiftUI

/// The finished dish seen from above, put together from the drawn parts in the asset catalog:
/// the vessel, the food it is built on, and what goes on top. Pieces cast a small shadow, and a
/// piece whose colours would vanish into what it lands on is drawn with an outline.
struct DishIcon: View {
    let recipe: Recipe
    var size: CGFloat = 72

    /// The four directions and the four diagonals an outline is stamped in.
    private static let directions: [CGSize] = [
        CGSize(width: 1, height: 0), CGSize(width: -1, height: 0),
        CGSize(width: 0, height: 1), CGSize(width: 0, height: -1),
        CGSize(width: 0.7, height: 0.7), CGSize(width: -0.7, height: 0.7),
        CGSize(width: 0.7, height: -0.7), CGSize(width: -0.7, height: -0.7),
    ]

    var body: some View {
        let placements = DishIconCache.placements(for: recipe)
        Canvas { context, canvas in
            let scale = canvas.width / DishLayout.canvas
            for placement in placements {
                draw(placement, in: &context, scale: scale)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func draw(_ placement: DishPlacement, in context: inout GraphicsContext, scale: CGFloat) {
        var context = context
        context.translateBy(x: placement.x * scale, y: placement.y * scale)
        context.rotate(by: .degrees(placement.rotation))
        let side = placement.size * scale
        let frame = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)

        if placement.isPiece {
            var shadow = context.resolve(Image(placement.asset).renderingMode(.template))
            shadow.shading = .color(.black.opacity(0.22))
            var offset = context
            // The shadow falls down the canvas whichever way the piece is turned.
            offset.rotate(by: .degrees(-placement.rotation))
            offset.translateBy(x: 0.35 * scale, y: 0.7 * scale)
            offset.rotate(by: .degrees(placement.rotation))
            offset.draw(shadow, in: frame)
        }
        if let outline = placement.outline.flatMap(Color.init(hex:)) {
            var edge = context.resolve(Image(placement.asset).renderingMode(.template))
            edge.shading = .color(outline)
            for direction in Self.directions {
                var stamped = context
                stamped.rotate(by: .degrees(-placement.rotation))
                stamped.translateBy(x: direction.width * 0.7 * scale, y: direction.height * 0.7 * scale)
                stamped.rotate(by: .degrees(placement.rotation))
                stamped.draw(edge, in: frame)
            }
        }
        context.draw(context.resolve(Image(placement.asset)), in: frame)
    }
}

/// Dish layouts worked out once a recipe, so a scrolling grid does not plan every dish again on
/// every frame. A recipe that is edited is a different value and is laid out afresh.
@MainActor
private enum DishIconCache {
    private static var cache: [Recipe: [DishPlacement]] = [:]

    static func placements(for recipe: Recipe) -> [DishPlacement] {
        if let cached = cache[recipe] { return cached }
        let placements = DishLayout.placements(for: Dish.planned(for: recipe), seed: recipe.id)
        cache[recipe] = placements
        return placements
    }
}

private extension Color {
    /// A colour written as `#rrggbb`.
    nonisolated init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
