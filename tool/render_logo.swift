// Renders Utopia's logo mark, app icon and coin face. Run from the repo root:
//   swiftc -O tool/render_logo.swift -o /tmp/render_logo && /tmp/render_logo
// Writes assets/branding/logo_mark.png (the mark: a stone gateway on a
// floating rock, a sunrise world glowing through it, transparent),
// app_icon.png (the mark in the night sky, opaque, for the launcher
// icons), coin_face.png
// (the gold coin the loader flips and Chip's back: the gateway on gold),
// the native launch images, and the landing page's logo, favicon and
// touch icon. With the argument "coin", only the coin face.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpaceCreateDeviceRGB()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: alpha)
}

func gradient(_ colors: [CGColor], _ stops: [CGFloat]) -> CGGradient {
  CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops)!
}

func makeContext(_ size: Int) -> CGContext {
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  // Work top-down like the app does: y grows downward.
  ctx.translateBy(x: 0, y: CGFloat(size))
  ctx.scaleBy(x: 1, y: -1)
  ctx.interpolationQuality = .high
  return ctx
}

func save(_ image: CGImage, _ path: String) {
  let url = URL(fileURLWithPath: path)
  let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, image, nil)
  CGImageDestinationFinalize(dest)
  print("wrote \(path) \(image.width)x\(image.height)")
}

func resized(_ image: CGImage, _ size: Int) -> CGImage {
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.interpolationQuality = .high
  ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
  return ctx.makeImage()!
}

func sparkle(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ alpha: CGFloat) {
  let p = CGMutablePath()
  p.move(to: CGPoint(x: c.x, y: c.y - r))
  p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + r * 0.12, y: c.y - r * 0.12))
  p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + r * 0.12, y: c.y + r * 0.12))
  p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - r * 0.12, y: c.y + r * 0.12))
  p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - r * 0.12, y: c.y - r * 0.12))
  ctx.setFillColor(color(0xFFFFFF, alpha))
  ctx.addPath(p)
  ctx.fillPath()
}

/// The coin face: a gold medallion with the U, centered at [c] with outer
/// radius [R].
func drawMedallion(_ ctx: CGContext, _ c: CGPoint, _ R: CGFloat) {
  // Gold rim.
  ctx.saveGState()
  ctx.addEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
  ctx.clip()
  ctx.drawRadialGradient(
    gradient([color(0xFFF6CF), color(0xFFD45E), color(0xE0A332), color(0xA86E14)], [0, 0.45, 0.8, 1]),
    startCenter: CGPoint(x: c.x - R * 0.35, y: c.y - R * 0.45), startRadius: 0,
    endCenter: c, endRadius: R * 1.05, options: [.drawsAfterEndLocation])
  // Reeding around the rim.
  ctx.setStrokeColor(color(0x8A5A10, 0.32))
  ctx.setLineWidth(R * 0.018)
  for i in 0..<72 {
    let a = CGFloat(i) / 72 * 2 * .pi
    let d = CGPoint(x: cos(a), y: sin(a))
    ctx.move(to: CGPoint(x: c.x + d.x * R * 0.9, y: c.y + d.y * R * 0.9))
    ctx.addLine(to: CGPoint(x: c.x + d.x * R * 0.985, y: c.y + d.y * R * 0.985))
  }
  ctx.strokePath()
  ctx.restoreGState()
  ctx.setStrokeColor(color(0x7A4E0C, 0.9))
  ctx.setLineWidth(R * 0.014)
  ctx.strokeEllipse(in: CGRect(x: c.x - R * 0.993, y: c.y - R * 0.993, width: R * 1.986, height: R * 1.986))

  // Twilight enamel.
  let r = R * 0.84
  let disc = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
  ctx.saveGState()
  ctx.addEllipse(in: disc)
  ctx.clip()
  ctx.drawRadialGradient(
    gradient([color(0xB79BFF), color(0x7C4DFF), color(0x4A1FB8), color(0x22104F)], [0, 0.4, 0.78, 1]),
    startCenter: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.4), startRadius: 0,
    endCenter: c, endRadius: r * 1.02, options: [.drawsAfterEndLocation])
  // Aurora sweeping across the top.
  ctx.saveGState()
  let aurora = CGMutablePath()
  aurora.addEllipse(in: CGRect(x: c.x - r * 1.3, y: c.y - r * 1.25, width: r * 2.6, height: r * 1.05))
  ctx.addPath(aurora)
  ctx.clip()
  ctx.drawLinearGradient(
    gradient([color(0x6FF5D2, 0.0), color(0x6FF5D2, 0.38), color(0xFF9ECF, 0.3), color(0xFF9ECF, 0.0)], [0, 0.35, 0.7, 1]),
    start: CGPoint(x: c.x - r, y: c.y - r * 0.2), end: CGPoint(x: c.x + r, y: c.y - r * 0.7), options: [])
  ctx.restoreGState()
  // A soft bank of clouds along the bottom of the enamel.
  let bank = CGMutablePath()
  for (dx, dy, cr) in [(-0.7, 0.86, 0.26), (-0.38, 0.8, 0.3), (0.0, 0.84, 0.3), (0.38, 0.79, 0.28), (0.72, 0.86, 0.26)] as [(CGFloat, CGFloat, CGFloat)] {
    bank.addEllipse(in: CGRect(x: c.x + dx * r - cr * r, y: c.y + dy * r - cr * r, width: 2 * cr * r, height: 2 * cr * r))
  }
  bank.addRect(CGRect(x: c.x - r, y: c.y + r * 0.86, width: 2 * r, height: r * 0.3))
  ctx.saveGState()
  ctx.addPath(bank)
  ctx.clip()
  ctx.drawLinearGradient(
    gradient([color(0xF3D2FF, 0.42), color(0xB07BD6, 0.22)], [0, 1]),
    start: CGPoint(x: c.x, y: c.y + r * 0.5), end: CGPoint(x: c.x, y: c.y + r), options: [])
  ctx.restoreGState()
  sparkle(ctx, CGPoint(x: c.x + r * 0.58, y: c.y - r * 0.5), r * 0.12, 0.95)
  sparkle(ctx, CGPoint(x: c.x - r * 0.62, y: c.y - r * 0.28), r * 0.07, 0.8)
  sparkle(ctx, CGPoint(x: c.x + r * 0.3, y: c.y - r * 0.74), r * 0.05, 0.7)
  ctx.restoreGState()
  ctx.setStrokeColor(color(0xFFE9A8, 0.75))
  ctx.setLineWidth(R * 0.016)
  ctx.strokeEllipse(in: disc)

  // The gateway, glowing in the middle of the enamel (the app icon's mark,
  // so the coin matches it).
  ctx.saveGState()
  ctx.addEllipse(in: disc)
  ctx.clip()
  // The mark's art spans about x 150-850, y 250-950 of its 1000 box; fit
  // that to most of the enamel.
  let side = r * 2.05
  let unit = side / 1000
  drawGateway(ctx, CGPoint(x: c.x - 500 * unit, y: c.y - 590 * unit), side, halo: true)
  ctx.restoreGState()

  // Sheen across the top of the medallion.
  ctx.saveGState()
  ctx.addEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
  ctx.clip()
  ctx.setFillColor(color(0xFFFFFF, 0.12))
  ctx.fillEllipse(in: CGRect(x: c.x - R * 0.75, y: c.y - R * 1.02, width: R * 1.5, height: R * 0.75))
  ctx.restoreGState()
}


/// Fills [path] with a gradient from [a] to [b].
func fill(_ ctx: CGContext, _ path: CGPath, _ colors: [CGColor], _ stops: [CGFloat], from a: CGPoint, to b: CGPoint) {
  ctx.saveGState()
  ctx.addPath(path)
  ctx.clip()
  ctx.drawLinearGradient(gradient(colors, stops), start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  ctx.restoreGState()
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
  CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
}

/// An arch standing on [baseY], [halfWidth] across each way from [cx],
/// its round top centred at [archY].
func arch(_ cx: CGFloat, _ baseY: CGFloat, _ archY: CGFloat, _ halfWidth: CGFloat) -> CGMutablePath {
  let p = CGMutablePath()
  p.move(to: CGPoint(x: cx - halfWidth, y: baseY))
  p.addLine(to: CGPoint(x: cx - halfWidth, y: archY))
  p.addArc(center: CGPoint(x: cx, y: archY), radius: halfWidth, startAngle: .pi, endAngle: 0, clockwise: false)
  p.addLine(to: CGPoint(x: cx + halfWidth, y: baseY))
  p.closeSubpath()
  return p
}

func poly(_ pts: [(CGFloat, CGFloat)]) -> CGPath {
  let p = CGMutablePath(); p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
  for (x, y) in pts.dropFirst() { p.addLine(to: CGPoint(x: x, y: y)) }
  p.closeSubpath(); return p
}
func glowDot(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ hex: UInt32, _ a: CGFloat) {
  ctx.drawRadialGradient(gradient([color(hex, a), color(hex, 0)], [0, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
}

/// A faceted floating rock: a flat top (an ellipse [rx] by [ry] around
/// [top]) tapering to a point at [tipY]. [warm] lights the top from the
/// gateway.
func rock(_ ctx: CGContext, cx: CGFloat, top: CGFloat, rx: CGFloat, ry: CGFloat, tipY: CGFloat, warm: Bool) {
  // Rim points along the front of the top ellipse.
  let xs: [CGFloat] = [-1, -0.66, -0.33, 0, 0.33, 0.66, 1]
  let rim = xs.map { f in CGPoint(x: cx + f * rx, y: top + ry * sqrt(max(0, 1 - f * f))) }
  let depth = tipY - top
  let low = [CGPoint(x: cx - rx * 0.78, y: top + depth * 0.36), CGPoint(x: cx - rx * 0.42, y: top + depth * 0.66),
             CGPoint(x: cx, y: tipY), CGPoint(x: cx + rx * 0.44, y: top + depth * 0.62), CGPoint(x: cx + rx * 0.8, y: top + depth * 0.32)]
  // Facets, lit from the upper left and from the portal above.
  let facets: [([CGPoint], UInt32, UInt32)] = [
    ([rim[0], rim[1], low[0]], 0x7C62C9, 0x5A41A6),
    ([rim[1], low[1], low[0]], 0x5B42A8, 0x3D2884),
    ([rim[1], rim[2], low[1]], 0x6A50B8, 0x4A3196),
    ([rim[2], rim[3], low[2], low[1]], 0x54399E, 0x2E1C6E),
    ([rim[3], rim[4], low[3], low[2]], 0x3E2884, 0x231457),
    ([rim[4], low[4], low[3]], 0x33206F, 0x1C0F48),
    ([rim[4], rim[5], low[4]], 0x2E1C68, 0x190D42),
    ([rim[5], rim[6], low[4]], 0x251658, 0x150B38),
  ]
  for (pts, a, b) in facets {
    let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath()
    let ys = pts.map(\.y)
    fill(ctx, p, [color(a), color(b)], [0, 1], from: CGPoint(x: cx, y: ys.min()!), to: CGPoint(x: cx, y: ys.max()!))
    ctx.addPath(p); ctx.setStrokeColor(color(0xB9A6FF, 0.10)); ctx.setLineWidth(1.5); ctx.strokePath()
  }
  // Top face.
  let topFace = CGPath(ellipseIn: CGRect(x: cx - rx, y: top - ry, width: rx * 2, height: ry * 2), transform: nil)
  fill(ctx, topFace, [color(0x9C8AE0), color(0x6E58BF)], [0, 1], from: CGPoint(x: cx, y: top - ry), to: CGPoint(x: cx, y: top + ry))
  if warm {
    ctx.saveGState(); ctx.addPath(topFace); ctx.clip()
    glowDot(ctx, CGPoint(x: cx, y: top - ry * 0.2), rx * 0.95, 0xFFC6A0, 0.85)
    ctx.restoreGState()
  }
  // Bright lip along the front edge.
  let lip = CGMutablePath()
  lip.addArc(center: .zero, radius: 1, startAngle: 0.08 * .pi, endAngle: 0.92 * .pi, clockwise: false)
  var t = CGAffineTransform(translationX: cx, y: top).scaledBy(x: rx, y: ry)
  let lipPath = lip.copy(using: &t)!
  ctx.addPath(lipPath); ctx.setStrokeColor(color(0xFFE2C4, warm ? 0.8 : 0.4)); ctx.setLineWidth(3); ctx.strokePath()
}

/// The mark: a stone gateway standing on a floating, faceted rock, a
/// sunrise world glowing through it and lighting the stone, a pink gem for
/// its keystone, and two shards floating alongside. Drawn in a 1000-unit
/// square whose top-left is [origin], [side] pixels across.
func drawGateway(_ ctx: CGContext, _ origin: CGPoint, _ side: CGFloat, halo: Bool) {
  ctx.saveGState()
  ctx.translateBy(x: origin.x, y: origin.y); ctx.scaleBy(x: side / 1000, y: side / 1000)
  let cx: CGFloat = 500, base: CGFloat = 728, archY: CGFloat = 392, inHW: CGFloat = 116, outHW: CGFloat = 168
  if halo {
    glowDot(ctx, CGPoint(x: cx, y: 470), 470, 0xFF8FC0, 0.30)
    glowDot(ctx, CGPoint(x: cx, y: 520), 300, 0xFFC28A, 0.28)
  }
  // Floating shards.
  rock(ctx, cx: 190, top: 820, rx: 38, ry: 9, tipY: 880, warm: false)
  rock(ctx, cx: 818, top: 862, rx: 28, ry: 7, tipY: 906, warm: false)
  // The island.
  rock(ctx, cx: cx, top: base + 6, rx: 262, ry: 50, tipY: 975, warm: true)

  // The world through the gateway.
  let inner = arch(cx, base, archY, inHW)
  ctx.saveGState(); ctx.addPath(inner); ctx.clip()
  ctx.drawLinearGradient(gradient([color(0x2A1F7A), color(0x6B3FC4), color(0xE0609E), color(0xFFA77A), color(0xFFE1A6)], [0, 0.32, 0.62, 0.84, 1]),
                         start: CGPoint(x: 0, y: archY - inHW), end: CGPoint(x: 0, y: 652), options: [.drawsAfterEndLocation])
  // The sun rising in a valley, with its bloom.
  glowDot(ctx, CGPoint(x: cx, y: 622), 230, 0xFFE9B8, 0.95)
  ctx.setFillColor(color(0xFFF8E6)); ctx.fillEllipse(in: CGRect(x: cx - 50, y: 622 - 50, width: 100, height: 100))
  // Mountain ranges, peaks either side of the sun.
  ctx.addPath(poly([(370, 640), (412, 590), (452, 622), (500, 660), (548, 620), (590, 584), (640, 636), (640, 740), (370, 740)]))
  ctx.setFillColor(color(0x9A58C4, 0.9)); ctx.fillPath()
  ctx.addPath(poly([(370, 676), (424, 636), (476, 668), (500, 680), (530, 660), (584, 632), (640, 668), (640, 740), (370, 740)]))
  ctx.setFillColor(color(0x52298F)); ctx.fillPath()
  ctx.addPath(poly([(370, 708), (440, 690), (500, 702), (566, 686), (640, 700), (640, 740), (370, 740)]))
  ctx.setFillColor(color(0x26124F)); ctx.fillPath()
  // The portal's shimmering edge.
  ctx.addPath(inner); ctx.setStrokeColor(color(0xFFFFFF, 0.5)); ctx.setLineWidth(10); ctx.strokePath()
  ctx.restoreGState()

  // Light spilling from the gateway across the island.
  ctx.saveGState()
  ctx.addPath(CGPath(ellipseIn: CGRect(x: cx - 262, y: base + 6 - 50, width: 524, height: 100), transform: nil)); ctx.clip()
  ctx.addPath(poly([(cx - inHW, base - 4), (cx + inHW, base - 4), (cx + 230, base + 64), (cx - 230, base + 64)]))
  ctx.clip()
  ctx.drawLinearGradient(gradient([color(0xFFF0CC, 1), color(0xFFC09A, 0.55), color(0xFF9FB0, 0)], [0, 0.5, 1]), start: CGPoint(x: 0, y: base - 4), end: CGPoint(x: 0, y: base + 64), options: [])
  ctx.restoreGState()

  // The frame: dark stone, lit gold from the world inside and cool from the sky.
  let outer = arch(cx, base, archY, outHW)
  let frame = CGMutablePath(); frame.addPath(outer); frame.addPath(inner)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 60, color: color(0xFF9CC8, 0.55))
  ctx.addPath(frame); ctx.setFillColor(color(0x221548)); ctx.fillPath(using: .evenOdd)
  ctx.restoreGState()
  ctx.saveGState(); ctx.addPath(frame); ctx.clip(using: .evenOdd)
  ctx.drawLinearGradient(gradient([color(0x4B3796), color(0x2A1B63), color(0x170E3A)], [0, 0.5, 1]),
                         start: CGPoint(x: cx - outHW, y: archY - outHW), end: CGPoint(x: cx + outHW, y: base), options: [])
  // Inner reveal catching the sunrise.
  let reveal = arch(cx, base, archY, inHW + 16)
  let revealRing = CGMutablePath(); revealRing.addPath(reveal); revealRing.addPath(inner)
  ctx.saveGState(); ctx.addPath(revealRing); ctx.clip(using: .evenOdd)
  ctx.drawLinearGradient(gradient([color(0xB98CFF), color(0xFF9CC2), color(0xFFD29A)], [0, 0.55, 1]),
                         start: CGPoint(x: 0, y: archY - inHW - 16), end: CGPoint(x: 0, y: base), options: [])
  ctx.restoreGState()
  // Stone joints.
  ctx.setStrokeColor(color(0x0E0726, 0.55)); ctx.setLineWidth(4)
  for a in stride(from: CGFloat.pi * 1.0, through: CGFloat.pi * 2.0, by: CGFloat.pi / 6) where a > .pi + 0.01 && a < 2 * .pi - 0.01 {
    let d = CGPoint(x: cos(a), y: sin(a))
    ctx.move(to: CGPoint(x: cx + d.x * (inHW + 16), y: archY + d.y * (inHW + 16)))
    ctx.addLine(to: CGPoint(x: cx + d.x * outHW, y: archY + d.y * outHW))
  }
  for y in [470, 560, 650] as [CGFloat] {
    for (x0, x1) in [(cx - outHW, cx - inHW - 16), (cx + inHW + 16, cx + outHW)] {
      ctx.move(to: CGPoint(x: x0, y: y)); ctx.addLine(to: CGPoint(x: x1, y: y))
    }
  }
  ctx.strokePath()
  ctx.restoreGState()
  // Rim light on the outer edge, brightest at the top left.
  ctx.saveGState()
  ctx.addPath(outer); ctx.setLineWidth(5)
  ctx.replacePathWithStrokedPath(); ctx.clip()
  ctx.drawLinearGradient(gradient([color(0xD9CCFF, 0.95), color(0x9F8BFF, 0.5), color(0x6B55D0, 0.1)], [0, 0.5, 1]),
                         start: CGPoint(x: cx - outHW, y: archY - outHW), end: CGPoint(x: cx + outHW, y: base), options: [])
  ctx.restoreGState()
  // Keystone gem.
  let ks = poly([(cx, archY - outHW - 30), (cx + 26, archY - outHW + 2), (cx, archY - outHW + 34), (cx - 26, archY - outHW + 2)])
  ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 28, color: color(0xFF8FD0, 1)); ctx.addPath(ks); ctx.setFillColor(color(0xFF5FB0)); ctx.fillPath(); ctx.restoreGState()
  fill(ctx, ks, [color(0xFFFFFF), color(0xFFB0DE), color(0xD9327F)], [0, 0.45, 1], from: CGPoint(x: cx - 20, y: archY - outHW - 30), to: CGPoint(x: cx + 20, y: archY - outHW + 34))
  // Motes rising from the gateway.
  for (x, y, r) in [(382, 520, 5), (636, 470, 4), (612, 600, 3), (360, 640, 3), (668, 560, 3.5)] as [(CGFloat, CGFloat, CGFloat)] {
    glowDot(ctx, CGPoint(x: x, y: y), r * 4, 0xFFD9B0, 0.5)
    ctx.setFillColor(color(0xFFF3DD, 0.95)); ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
  }
  ctx.restoreGState()
}

/// The icon's backdrop: a deep night sky, faint stars and a vignette.
func drawBackdrop(_ ctx: CGContext, _ S: CGFloat) {
  ctx.drawLinearGradient(gradient([color(0x0B0622), color(0x1A0C45), color(0x35145F), color(0x5A1D6A)], [0, 0.45, 0.8, 1]),
                         start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: S), options: [])
  var seed: UInt64 = 11
  func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 10000) / 10000 }
  for _ in 0..<46 {
    let p = CGPoint(x: rnd() * S, y: rnd() * S * 0.7)
    let r = (0.8 + rnd() * 1.8) * S / 1000
    ctx.setFillColor(color(0xFFFFFF, 0.18 + rnd() * 0.4))
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
  }
  // Vignette.
  ctx.drawRadialGradient(gradient([color(0x000000, 0), color(0x05020F, 0.55)], [0.55, 1]), startCenter: CGPoint(x: S / 2, y: S * 0.48), startRadius: 0, endCenter: CGPoint(x: S / 2, y: S * 0.48), endRadius: S * 0.78, options: [.drawsAfterEndLocation])
}

let size = 1024
let S = CGFloat(size)
// The in-app copies of the coin and the mark: never shown bigger than about
// 150pt, so 768px is plenty at 3x and keeps the download small.
let appSize = 768

// The coin face (the loader coin and Chip's back): the gateway on gold.
let coin = makeContext(size)
drawMedallion(coin, CGPoint(x: S / 2, y: S / 2), S * 0.48)
save(resized(coin.makeImage()!, appSize), "assets/branding/coin_face.png")
if CommandLine.arguments.dropFirst().first == "coin" { exit(0) }

// Logo mark: transparent background.
let mark = makeContext(size)
drawGateway(mark, CGPoint(x: 0, y: 0), S, halo: true)
let markImage = mark.makeImage()!
save(resized(markImage, appSize), "assets/branding/logo_mark.png")

// App icon: the gateway in the night sky, filling the frame.
let icon = makeContext(size)
drawBackdrop(icon, S)
drawGateway(icon, CGPoint(x: -S * 0.06, y: -S * 0.15), S * 1.12, halo: true)
let iconImage = icon.makeImage()!
save(iconImage, "assets/branding/app_icon.png")

// Android's adaptive icon: the sky behind, the gateway in front (the
// launcher icon tool insets it into the mask's safe zone; a little smaller
// so the rock's tip and the shards stay inside a round mask).
let back = makeContext(size)
drawBackdrop(back, S)
save(back.makeImage()!, "assets/branding/adaptive_background.png")
let front = makeContext(size)
drawGateway(front, CGPoint(x: S * 0.04, y: 0), S * 0.92, halo: true)
save(front.makeImage()!, "assets/branding/adaptive_foreground.png")

// Native launch images (the splash's first frame matches these exactly).
let launch = "ios/Runner/Assets.xcassets/LaunchImage.imageset"
save(resized(markImage, 110), "\(launch)/LaunchImage.png")
save(resized(markImage, 220), "\(launch)/LaunchImage@2x.png")
save(resized(markImage, 330), "\(launch)/LaunchImage@3x.png")
for (density, px) in [("mdpi", 110), ("hdpi", 165), ("xhdpi", 220), ("xxhdpi", 330), ("xxxhdpi", 440)] {
  save(resized(markImage, px), "android/app/src/main/res/drawable-\(density)/launch_logo.png")
}

// The landing page: logo, favicon and touch icon.
let site = "../utopia-landingpage/public"
save(resized(markImage, 512), "\(site)/logo.png")
save(resized(iconImage, 64), "\(site)/favicon.png")
save(resized(iconImage, 180), "\(site)/apple-touch-icon.png")
