// Renders Utopia's logo mark, app icon and coin face. Run from the repo root:
//   swiftc -O tool/render_logo.swift -o /tmp/render_logo && /tmp/render_logo
// Writes assets/branding/logo_mark.png (the mark: a floating island with a
// glowing gateway into a sunrise world, transparent), app_icon.png (the
// mark in the night sky, opaque, for the launcher icons), coin_face.png
// (the gold coin the loader flips and Chip's back), the native launch
// images, and the landing page's logo, favicon and touch icon.
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

  // Orbit ring: tilted, passing behind the U and back out in front of it.
  let ringRx = r * 0.86, ringRy = r * 0.24, tilt: CGFloat = -0.32
  let ringCenter = CGPoint(x: c.x, y: c.y + r * 0.12)
  // The ring is one continuous loop; its near half is drawn again over the
  // U so the U sits inside it.
  func ring(nearHalfOnly: Bool) {
    ctx.saveGState()
    ctx.translateBy(x: ringCenter.x, y: ringCenter.y)
    ctx.rotate(by: tilt)
    if nearHalfOnly {
      // Top-down coordinates: the near half is the lower one (y > 0).
      ctx.clip(to: CGRect(x: -ringRx * 1.3, y: 0, width: ringRx * 2.6, height: ringRy * 2))
    }
    let loop = CGPath(ellipseIn: CGRect(x: -ringRx, y: -ringRy, width: ringRx * 2, height: ringRy * 2), transform: nil)
    ctx.addPath(loop.copy(strokingWithWidth: r * 0.075, lineCap: .butt, lineJoin: .round, miterLimit: 1))
    ctx.clip()
    ctx.drawLinearGradient(
      gradient([color(0xFFF1B8), color(0xFFC94D), color(0xFF8FC4)], [0, 0.55, 1]),
      start: CGPoint(x: -ringRx, y: 0), end: CGPoint(x: ringRx, y: 0), options: [])
    ctx.restoreGState()
  }
  ring(nearHalfOnly: false)

  // The U: one thick rounded stroke.
  let uw = r * 0.62, top = c.y - r * 0.42, bottomY = c.y + r * 0.08
  let u = CGMutablePath()
  u.move(to: CGPoint(x: c.x - uw / 2, y: top))
  u.addLine(to: CGPoint(x: c.x - uw / 2, y: bottomY))
  u.addArc(center: CGPoint(x: c.x, y: bottomY), radius: uw / 2, startAngle: .pi, endAngle: 0, clockwise: true)
  u.addLine(to: CGPoint(x: c.x + uw / 2, y: top))
  let uShape = u.copy(strokingWithWidth: r * 0.26, lineCap: .round, lineJoin: .round, miterLimit: 1)
  // Soft drop shadow.
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: r * 0.05), blur: r * 0.08, color: color(0x12082E, 0.7))
  ctx.setFillColor(color(0xFFFFFF))
  ctx.addPath(uShape)
  ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(uShape)
  ctx.clip()
  ctx.drawLinearGradient(
    gradient([color(0xFFFFFF), color(0xF3EDFF), color(0xCDBBFF)], [0, 0.5, 1]),
    start: CGPoint(x: c.x, y: top - r * 0.15), end: CGPoint(x: c.x, y: bottomY + uw / 2 + r * 0.15), options: [])
  // Gloss on the left arm.
  ctx.setFillColor(color(0xFFFFFF, 0.55))
  ctx.fillEllipse(in: CGRect(x: c.x - uw / 2 - r * 0.07, y: top - r * 0.06, width: r * 0.09, height: r * 0.34))
  ctx.restoreGState()

  ring(nearHalfOnly: true)
  // A little planet riding the ring.
  let planet = CGPoint(
    x: ringCenter.x + cos(0.35) * ringRx * cos(tilt) - sin(0.35) * ringRy * sin(tilt),
    y: ringCenter.y + cos(0.35) * ringRx * sin(tilt) + sin(0.35) * ringRy * cos(tilt))
  let pr = r * 0.11
  ctx.saveGState()
  ctx.addEllipse(in: CGRect(x: planet.x - pr, y: planet.y - pr, width: 2 * pr, height: 2 * pr))
  ctx.clip()
  ctx.drawRadialGradient(
    gradient([color(0xFFE3F2), color(0xFF7EB8), color(0xB0306E)], [0, 0.55, 1]),
    startCenter: CGPoint(x: planet.x - pr * 0.4, y: planet.y - pr * 0.4), startRadius: 0,
    endCenter: planet, endRadius: pr, options: [.drawsAfterEndLocation])
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

/// The mark: a floating island with a glowing gateway standing on it, a
/// sunrise world showing through the gateway, a waterfall pouring off the
/// edge and crystals glinting in the rock. Drawn in a 1000-unit square
/// whose top-left is [origin], [side] pixels across.
func drawIsland(_ ctx: CGContext, _ origin: CGPoint, _ side: CGFloat, glow: Bool) {
  ctx.saveGState()
  ctx.translateBy(x: origin.x, y: origin.y)
  ctx.scaleBy(x: side / 1000, y: side / 1000)

  if glow {
    ctx.drawRadialGradient(
      gradient([color(0xC6A2FF, 0.42), color(0xC6A2FF, 0)], [0, 1]),
      startCenter: CGPoint(x: 500, y: 520), startRadius: 0,
      endCenter: CGPoint(x: 500, y: 520), endRadius: 470, options: [])
  }

  // The rock beneath: jagged, layered, tapering to a point.
  let rock = CGMutablePath()
  let jag: [(CGFloat, CGFloat)] = [
    (160, 668), (200, 742), (252, 762), (292, 836), (352, 856), (402, 922),
    (462, 938), (500, 985), (540, 934), (594, 918), (644, 852), (702, 832),
    (748, 760), (802, 744), (840, 668),
  ]
  rock.move(to: CGPoint(x: jag[0].0, y: jag[0].1))
  for (x, y) in jag.dropFirst() { rock.addLine(to: CGPoint(x: x, y: y)) }
  rock.closeSubpath()
  fill(ctx, rock, [color(0x9A74E0), color(0x6440B0), color(0x2C1766)], [0, 0.45, 1],
       from: CGPoint(x: 500, y: 660), to: CGPoint(x: 500, y: 985))
  // Strata.
  ctx.saveGState()
  ctx.addPath(rock)
  ctx.clip()
  ctx.setStrokeColor(color(0xC9B4FF, 0.32))
  ctx.setLineWidth(7)
  ctx.setLineCap(.round)
  for (y, w) in [(752, 270), (828, 190), (900, 100)] as [(CGFloat, CGFloat)] {
    ctx.move(to: CGPoint(x: 500 - w, y: y))
    ctx.addQuadCurve(to: CGPoint(x: 500 + w, y: y - 6), control: CGPoint(x: 500, y: y + 26))
  }
  ctx.strokePath()
  // Shade down the right-hand side.
  ctx.setFillColor(color(0x1A0C40, 0.28))
  ctx.fill(CGRect(x: 560, y: 640, width: 320, height: 360))
  ctx.restoreGState()
  // Crystals glinting in the rock.
  for (x, y, h, c1, c2) in [
    (318, 790, 46, 0x9AF6FF, 0x3BB8E6), (448, 884, 34, 0xFFB8E4, 0xE0499A),
    (628, 810, 40, 0xFFB8E4, 0xE0499A),
  ] as [(CGFloat, CGFloat, CGFloat, UInt32, UInt32)] {
    let gem = CGMutablePath()
    gem.move(to: CGPoint(x: x, y: y - h))
    gem.addLine(to: CGPoint(x: x + h * 0.42, y: y))
    gem.addLine(to: CGPoint(x: x, y: y + h * 0.5))
    gem.addLine(to: CGPoint(x: x - h * 0.42, y: y))
    gem.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 22, color: color(c1, 0.9))
    ctx.addPath(gem)
    ctx.setFillColor(color(c2))
    ctx.fillPath()
    ctx.restoreGState()
    fill(ctx, gem, [color(0xFFFFFF), color(c1), color(c2)], [0, 0.4, 1],
         from: CGPoint(x: x - h * 0.4, y: y - h), to: CGPoint(x: x + h * 0.4, y: y + h * 0.5))
  }

  // A waterfall pouring off the right-hand edge, fading into mist.
  let fall = CGPath(roundedRect: CGRect(x: 738, y: 684, width: 50, height: 240), cornerWidth: 25, cornerHeight: 25, transform: nil)
  fill(ctx, fall, [color(0xE6FBFF), color(0x8FE0FF, 0.9), color(0x8FE0FF, 0)], [0, 0.6, 1],
       from: CGPoint(x: 0, y: 684), to: CGPoint(x: 0, y: 924))
  ctx.setStrokeColor(color(0xFFFFFF, 0.75))
  ctx.setLineWidth(5)
  for x in [752, 770] as [CGFloat] {
    ctx.move(to: CGPoint(x: x, y: 700))
    ctx.addLine(to: CGPoint(x: x, y: 820))
  }
  ctx.strokePath()
  for (x, y, r) in [(744, 912, 22), (780, 920, 26), (762, 902, 18)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.setFillColor(color(0xFFFFFF, 0.28))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
  }

  // The grass on top: its edge, then the lawn.
  ctx.addPath(ellipse(500, 676, 342, 78))
  ctx.setFillColor(color(0x188A5C))
  ctx.fillPath()
  fill(ctx, ellipse(500, 650, 340, 70), [color(0xB6FAD2), color(0x5FDB9C), color(0x2FB57A)], [0, 0.55, 1],
       from: CGPoint(x: 500, y: 580), to: CGPoint(x: 500, y: 720))

  // Light pouring out of the gateway onto the island.
  ctx.drawRadialGradient(
    gradient([color(0xFFE7A8, 0.65), color(0xFFB3D1, 0.25), color(0xFFB3D1, 0)], [0, 0.5, 1]),
    startCenter: CGPoint(x: 500, y: 560), startRadius: 0,
    endCenter: CGPoint(x: 500, y: 560), endRadius: 300, options: [])

  // Little round trees either side.
  for (x, y, r) in [(232, 612, 40), (790, 618, 34), (282, 634, 26)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.setFillColor(color(0x6B4A7A))
    ctx.fill(CGRect(x: x - 6, y: y, width: 12, height: 34))
    fill(ctx, ellipse(x, y - r * 0.3, r, r), [color(0xC2FFE0), color(0x4FD39A), color(0x1F9A66)], [0, 0.5, 1],
         from: CGPoint(x: x - r, y: y - r * 1.3), to: CGPoint(x: x + r, y: y + r * 0.7))
  }

  // The gateway: a pearl-white stone arch with a sunrise world inside.
  let cx: CGFloat = 500, base: CGFloat = 652, archY: CGFloat = 372
  let outer = arch(cx, base, archY, 168)
  let inner = arch(cx, base, archY, 120)
  // The world through it.
  ctx.saveGState()
  ctx.addPath(inner)
  ctx.clip()
  ctx.drawLinearGradient(
    gradient([color(0x7CC4FF), color(0xC7A6FF), color(0xFFA9D2), color(0xFFD98C)], [0, 0.38, 0.7, 1]),
    start: CGPoint(x: 0, y: archY - 120), end: CGPoint(x: 0, y: base), options: [])
  ctx.drawRadialGradient(
    gradient([color(0xFFF8D8), color(0xFFF1B8, 0.85), color(0xFFE08A, 0)], [0, 0.45, 1]),
    startCenter: CGPoint(x: cx, y: 560), startRadius: 0,
    endCenter: CGPoint(x: cx, y: 560), endRadius: 120, options: [])
  ctx.setFillColor(color(0xFFFBEA))
  ctx.fillEllipse(in: CGRect(x: cx - 46, y: 560 - 46, width: 92, height: 92))
  // Clouds drifting in that world's sky.
  ctx.setFillColor(color(0xFFFFFF, 0.85))
  for (x, y, r) in [(432, 352, 22), (458, 344, 28), (486, 354, 20), (556, 318, 18), (578, 310, 24), (600, 320, 17)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
  }
  // Rolling hills.
  let hillBack = CGMutablePath()
  hillBack.move(to: CGPoint(x: 360, y: 640))
  hillBack.addQuadCurve(to: CGPoint(x: 520, y: 600), control: CGPoint(x: 420, y: 560))
  hillBack.addQuadCurve(to: CGPoint(x: 640, y: 590), control: CGPoint(x: 590, y: 540))
  hillBack.addLine(to: CGPoint(x: 640, y: 660))
  hillBack.addLine(to: CGPoint(x: 360, y: 660))
  hillBack.closeSubpath()
  ctx.addPath(hillBack)
  ctx.setFillColor(color(0x6FD9B8))
  ctx.fillPath()
  let hillFront = CGMutablePath()
  hillFront.move(to: CGPoint(x: 360, y: 610))
  hillFront.addQuadCurve(to: CGPoint(x: 640, y: 640), control: CGPoint(x: 470, y: 600))
  hillFront.addLine(to: CGPoint(x: 640, y: 660))
  hillFront.addLine(to: CGPoint(x: 360, y: 660))
  hillFront.closeSubpath()
  ctx.addPath(hillFront)
  ctx.setFillColor(color(0x2FB88C))
  ctx.fillPath()
  ctx.restoreGState()

  // The stone frame, glowing.
  let frame = CGMutablePath()
  frame.addPath(outer)
  frame.addPath(inner)
  ctx.saveGState()
  ctx.setShadow(offset: .zero, blur: 46, color: color(0xC9A8FF, 0.95))
  ctx.addPath(frame)
  ctx.setFillColor(color(0xEDE4FF))
  ctx.fillPath(using: .evenOdd)
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(frame)
  ctx.clip(using: .evenOdd)
  ctx.drawLinearGradient(
    gradient([color(0xFFFFFF), color(0xF1EAFF), color(0xBBA4FF)], [0, 0.45, 1]),
    start: CGPoint(x: cx - 168, y: archY - 168), end: CGPoint(x: cx + 168, y: base), options: [])
  // Carved joints between the stones.
  ctx.setStrokeColor(color(0x9F87EA, 0.75))
  ctx.setLineWidth(5)
  for a in stride(from: CGFloat.pi * 1.0, through: CGFloat.pi * 2.0, by: CGFloat.pi / 5) {
    let d = CGPoint(x: cos(a), y: sin(a))
    ctx.move(to: CGPoint(x: cx + d.x * 118, y: archY + d.y * 118))
    ctx.addLine(to: CGPoint(x: cx + d.x * 170, y: archY + d.y * 170))
  }
  for y in [452, 532, 612] as [CGFloat] {
    for x in [cx - 168, cx + 120] {
      ctx.move(to: CGPoint(x: x, y: y))
      ctx.addLine(to: CGPoint(x: x + 48, y: y))
    }
  }
  ctx.strokePath()
  ctx.restoreGState()
  ctx.addPath(frame)
  ctx.setStrokeColor(color(0x5B3AB0, 0.55))
  ctx.setLineWidth(6)
  ctx.strokePath()
  // A step at its foot.
  let step = CGPath(roundedRect: CGRect(x: cx - 196, y: base - 10, width: 392, height: 30), cornerWidth: 15, cornerHeight: 15, transform: nil)
  fill(ctx, step, [color(0xF6F0FF), color(0xB49DF5)], [0, 1], from: CGPoint(x: 0, y: base - 10), to: CGPoint(x: 0, y: base + 20))
  // The keystone: a pink gem.
  let ks = CGMutablePath()
  ks.move(to: CGPoint(x: cx, y: archY - 196))
  ks.addLine(to: CGPoint(x: cx + 34, y: archY - 150))
  ks.addLine(to: CGPoint(x: cx, y: archY - 112))
  ks.addLine(to: CGPoint(x: cx - 34, y: archY - 150))
  ks.closeSubpath()
  ctx.saveGState()
  ctx.setShadow(offset: .zero, blur: 30, color: color(0xFF8FD0, 0.95))
  ctx.addPath(ks)
  ctx.setFillColor(color(0xFF5FB0))
  ctx.fillPath()
  ctx.restoreGState()
  fill(ctx, ks, [color(0xFFFFFF), color(0xFFB0DE), color(0xE0398F)], [0, 0.4, 1],
       from: CGPoint(x: cx - 30, y: archY - 196), to: CGPoint(x: cx + 30, y: archY - 112))

  sparkle(ctx, CGPoint(x: 712, y: 262), 36, 0.95)
  sparkle(ctx, CGPoint(x: 290, y: 318), 24, 0.85)
  sparkle(ctx, CGPoint(x: 700, y: 440), 15, 0.7)
  ctx.restoreGState()
}

let size = 1024
let S = CGFloat(size)

// The coin face (the loader coin and Chip's back): the old medallion.
let coin = makeContext(size)
drawMedallion(coin, CGPoint(x: S / 2, y: S / 2), S * 0.48)
save(coin.makeImage()!, "assets/branding/coin_face.png")

// Logo mark: transparent background.
let mark = makeContext(size)
drawIsland(mark, CGPoint(x: 0, y: 0), S, glow: true)
let markImage = mark.makeImage()!
save(markImage, "assets/branding/logo_mark.png")

/// The icon's night sky: stars, a ringed planet, clouds along the bottom.
func drawSky(_ ctx: CGContext, _ S: CGFloat) {
  ctx.drawLinearGradient(
    gradient([color(0x120B2E), color(0x2A1463), color(0x5A2582), color(0xC2668F)], [0, 0.42, 0.78, 1]),
    start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: S), options: [])
  ctx.drawRadialGradient(
    gradient([color(0xFFB38A, 0.4), color(0xFFB38A, 0)], [0, 1]),
    startCenter: CGPoint(x: S / 2, y: S * 0.95), startRadius: 0,
    endCenter: CGPoint(x: S / 2, y: S * 0.95), endRadius: S * 0.6, options: [])
  var seed: UInt64 = 7
  func rnd() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 33) % 10000) / 10000
  }
  for _ in 0..<70 {
    let p = CGPoint(x: rnd() * S, y: rnd() * S * 0.62)
    let r = 1.5 + rnd() * 3
    ctx.setFillColor(color(0xFFFFFF, 0.4 + rnd() * 0.5))
    ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
  }
  // A small ringed planet up in the corner.
  let pc = CGPoint(x: S * 0.83, y: S * 0.17), prad = S * 0.05
  ctx.saveGState()
  ctx.addEllipse(in: CGRect(x: pc.x - prad, y: pc.y - prad, width: 2 * prad, height: 2 * prad))
  ctx.clip()
  ctx.drawRadialGradient(
    gradient([color(0xFFE7C8), color(0xFF9E7A), color(0xB0406E)], [0, 0.55, 1]),
    startCenter: CGPoint(x: pc.x - prad * 0.4, y: pc.y - prad * 0.4), startRadius: 0,
    endCenter: pc, endRadius: prad, options: [.drawsAfterEndLocation])
  ctx.restoreGState()
  ctx.saveGState()
  ctx.translateBy(x: pc.x, y: pc.y)
  ctx.rotate(by: -0.35)
  ctx.setStrokeColor(color(0xFFD9A8, 0.85))
  ctx.setLineWidth(S * 0.008)
  ctx.strokeEllipse(in: CGRect(x: -prad * 1.8, y: -prad * 0.45, width: prad * 3.6, height: prad * 0.9))
  ctx.restoreGState()
  // Clouds along the bottom.
  let iconBank = CGMutablePath()
  for (x, y, r) in [(0.04, 0.97, 0.12), (0.22, 0.95, 0.14), (0.78, 0.95, 0.14), (0.96, 0.97, 0.12)] as [(CGFloat, CGFloat, CGFloat)] {
    iconBank.addEllipse(in: CGRect(x: x * S - r * S, y: y * S - r * S, width: 2 * r * S, height: 2 * r * S))
  }
  ctx.saveGState()
  ctx.addPath(iconBank)
  ctx.clip()
  ctx.drawLinearGradient(
    gradient([color(0xF3D2FF, 0.9), color(0xC78AE0, 0.8), color(0x8E5CC0, 0.8)], [0, 0.5, 1]),
    start: CGPoint(x: 0, y: S * 0.82), end: CGPoint(x: 0, y: S), options: [])
  ctx.restoreGState()
}

// App icon: the island floating in the night sky.
let icon = makeContext(size)
drawSky(icon, S)
drawIsland(icon, CGPoint(x: S * 0.03, y: S * 0.02), S * 0.94, glow: true)
let iconImage = icon.makeImage()!
save(iconImage, "assets/branding/app_icon.png")

// Android's adaptive icon: the sky behind, the island in front (the
// launcher icon tool insets it into the mask's safe zone; raised a little
// so the tip of the rock stays inside a round mask).
let back = makeContext(size)
drawSky(back, S)
save(back.makeImage()!, "assets/branding/adaptive_background.png")
let front = makeContext(size)
drawIsland(front, CGPoint(x: 0, y: -S * 0.04), S, glow: true)
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
