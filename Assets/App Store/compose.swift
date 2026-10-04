import AppKit

let canvasSize = NSSize(width: 1242, height: 2688)
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let languages = ["en", "ja"]

struct Copy {
    let header: String
    let caption: String
}

struct Screenshot {
    let rawName: String
    let outName: String
    /// Keyed by language code. A language without copy is skipped.
    let copy: [String: Copy]
    let gradientTop: NSColor
    let gradientBottom: NSColor
}

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

// Plates orange, the sage of the dish rims, terracotta, and the cooking teal.
let orange = (color(0xE8823A), color(0xB04E14))
let sage = (color(0x7FA88C), color(0x3E6650))
let terracotta = (color(0xC8613F), color(0x7E3320))
let teal = (color(0x4D8580), color(0x1E4643))

let screenshots: [Screenshot] = [
    Screenshot(
        rawName: "01-list",
        outName: "01-list",
        copy: [
            "en": Copy(header: "Your recipe box", caption: "Every recipe gets an icon drawn from the dish"),
            "ja": Copy(header: "あなたのレシピ帳", caption: "料理ごとに描かれたアイコンで、ひと目で探せる"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "08-ideas",
        outName: "02-ideas",
        copy: [
            "en": Copy(header: "Not sure what to cook?", caption: "Say what you feel like, and pick from five dishes"),
        ],
        gradientTop: terracotta.0, gradientBottom: terracotta.1
    ),
    Screenshot(
        rawName: "09-writing",
        outName: "03-writing",
        copy: [
            "en": Copy(header: "Recipes, written for you", caption: "Ingredients, tools, and steps, sorted on device"),
            "ja": Copy(header: "レシピを書き上げます", caption: "材料・道具・手順をデバイス上で整理"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
    Screenshot(
        rawName: "02-detail",
        outName: "04-detail",
        copy: [
            "en": Copy(header: "Everything at a glance", caption: "Time, servings, ingredients, and tools"),
            "ja": Copy(header: "ひと目でわかる", caption: "時間・人数・材料・道具をまとめて表示"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "06-ask",
        outName: "05-ask",
        copy: [
            "en": Copy(header: "Change it in your own words", caption: "Add an ingredient, or cook for more people"),
            "ja": Copy(header: "自分の言葉で変更", caption: "人数の変更も、材料の入れ替えも頼むだけ"),
        ],
        gradientTop: terracotta.0, gradientBottom: terracotta.1
    ),
    Screenshot(
        rawName: "04-steps",
        outName: "06-steps",
        copy: [
            "en": Copy(header: "Steps that say why", caption: "What to look for, and what goes wrong"),
            "ja": Copy(header: "コツまでわかる手順", caption: "目安と理由を、手順ごとに"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
    Screenshot(
        rawName: "05-cook",
        outName: "07-cook",
        copy: [
            "en": Copy(header: "One step at a time", caption: "Large type in the kitchen, with timers built in"),
            "ja": Copy(header: "手順をひとつずつ", caption: "大きな文字で、タイマーも内蔵"),
        ],
        gradientTop: teal.0, gradientBottom: teal.1
    ),
    Screenshot(
        rawName: "03-have",
        outName: "08-shopping",
        copy: [
            "en": Copy(header: "Know what to buy", caption: "Tap what you have, and the rest is your list"),
            "ja": Copy(header: "買うものがわかる", caption: "あるものをタップすると、在庫に追加"),
        ],
        gradientTop: orange.0, gradientBottom: orange.1
    ),
    Screenshot(
        rawName: "07-inventory",
        outName: "09-inventory",
        copy: [
            "en": Copy(header: "Keep track of your kitchen", caption: "Pick ingredients and tools by their icons"),
            "ja": Copy(header: "台所の在庫を管理", caption: "材料と道具をアイコンから選ぶだけ"),
        ],
        gradientTop: sage.0, gradientBottom: sage.1
    ),
]

// MARK: - Text

/// Draws one line centered at `top`, shrinking until it fits `maxWidth`.
/// Returns the drawn height.
@discardableResult
func drawLine(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    top: CGFloat,
    maxWidth: CGFloat
) -> CGFloat {
    var fontSize = size
    var attrs: [NSAttributedString.Key: Any] = [:]
    var lineSize = NSSize.zero
    while fontSize > 10 {
        attrs = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
        ]
        lineSize = (text as NSString).size(withAttributes: attrs)
        if lineSize.width <= maxWidth { break }
        fontSize -= 2
    }
    (text as NSString).draw(
        at: NSPoint(x: (canvasSize.width - lineSize.width) / 2, y: top - lineSize.height),
        withAttributes: attrs
    )
    return lineSize.height
}

// MARK: - Device frame

let hardwareImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Hardware@2x.png"))!
let displayImage = NSImage(contentsOf: scriptDir.appendingPathComponent("Display@2x.png"))!

func cgImage(of image: NSImage) -> CGImage {
    image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

let hardwareCG = cgImage(of: hardwareImage)
let displayCG = cgImage(of: displayImage)
let hardwarePixel = NSSize(width: hardwareCG.width, height: hardwareCG.height)
let displayPixel = NSSize(width: displayCG.width, height: displayCG.height)
// The display mask sits centered within the hardware frame.
let displayOrigin = NSPoint(
    x: (hardwarePixel.width - displayPixel.width) / 2,
    y: (hardwarePixel.height - displayPixel.height) / 2
)

/// The raw capture clipped by the display mask, on a hardware-sized canvas.
func maskedScreen(raw: NSImage) -> NSImage {
    let rawCG = cgImage(of: raw)
    let image = NSImage(size: hardwarePixel)
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let displayRect = CGRect(origin: displayOrigin, size: displayPixel)
    ctx.clip(to: displayRect, mask: displayCG)

    // Aspect-fill the display area.
    let rawSize = CGSize(width: rawCG.width, height: rawCG.height)
    let scale = max(displayPixel.width / rawSize.width, displayPixel.height / rawSize.height)
    let drawSize = CGSize(width: rawSize.width * scale, height: rawSize.height * scale)
    let drawRect = CGRect(
        x: displayRect.midX - drawSize.width / 2,
        y: displayRect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    ctx.draw(rawCG, in: drawRect)
    image.unlockFocus()
    return image
}

// MARK: - Composition

func compose(_ shot: Screenshot, language: String) -> Bool {
    guard let copy = shot.copy[language] else { return true }
    let rawURL = scriptDir
        .appendingPathComponent("Raw")
        .appendingPathComponent(language)
        .appendingPathComponent("\(shot.rawName).png")
    guard let raw = NSImage(contentsOf: rawURL) else {
        print("missing raw capture: \(rawURL.path)")
        return false
    }

    let image = NSImage(size: canvasSize)
    image.lockFocus()

    NSGradient(starting: shot.gradientTop, ending: shot.gradientBottom)?
        .draw(in: NSRect(origin: .zero, size: canvasSize), angle: -90)

    // One-line header and caption. AppKit's origin is bottom-left.
    let textWidth = canvasSize.width - 96
    let headerTop = canvasSize.height - 96
    let headerHeight = drawLine(
        copy.header, size: 84, weight: .bold,
        color: .white, top: headerTop, maxWidth: textWidth
    )
    let captionTop = headerTop - headerHeight - 4
    let captionHeight = drawLine(
        copy.caption, size: 44, weight: .medium,
        color: NSColor.white.withAlphaComponent(0.92), top: captionTop, maxWidth: textWidth
    )

    // Device: hardware frame below, display-masked capture above.
    let textBottom = captionTop - captionHeight
    let deviceTopMargin: CGFloat = 64
    let deviceBottomMargin: CGFloat = 88
    let availableHeight = textBottom - deviceTopMargin - deviceBottomMargin
    let aspect = hardwarePixel.width / hardwarePixel.height
    var deviceSize = NSSize(width: availableHeight * aspect, height: availableHeight)
    if deviceSize.width > canvasSize.width - 120 {
        deviceSize.width = canvasSize.width - 120
        deviceSize.height = deviceSize.width / aspect
    }
    let deviceRect = NSRect(
        x: ((canvasSize.width - deviceSize.width) / 2).rounded(),
        y: deviceBottomMargin,
        width: deviceSize.width,
        height: deviceSize.height
    )

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = NSSize(width: 0, height: -24)
    shadow.set()
    hardwareImage.draw(in: deviceRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    maskedScreen(raw: raw).draw(in: deviceRect)

    image.unlockFocus()

    // Rasterize at exactly 1242 x 2688 pixels.
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width), pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return false }
    bitmap.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: canvasSize))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { return false }
    let outDir = scriptDir.appendingPathComponent(language)
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let outURL = outDir.appendingPathComponent("\(shot.outName).png")
    do {
        try png.write(to: outURL)
        print("wrote \(language)/\(outURL.lastPathComponent)")
        return true
    } catch {
        print("failed to write \(outURL.path): \(error)")
        return false
    }
}

var allOK = true
for language in languages {
    for shot in screenshots {
        allOK = compose(shot, language: language) && allOK
    }
}
exit(allOK ? 0 : 1)
