// Draws AppIcon.png (1024²) — a chameleon on a branch. Its body runs through
// a colour gradient, which is the whole conceit of the app.
import AppKit

let S: CGFloat = 1024
let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255,
            blue: CGFloat(b)/255, alpha: a).cgColor
}
func gradient(_ colors: [CGColor], _ locs: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: colors as CFArray, locations: locs)!
}

// ── Background tile ───────────────────────────────────────────────────────
let inset: CGFloat = 44
let tile = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 205, cornerHeight: 205,
                   transform: nil))
ctx.clip()
ctx.drawLinearGradient(gradient([rgb(40, 78, 90), rgb(17, 38, 48)], [0, 1]),
                       start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0),
                       options: [])

// Everything below is drawn in a roomier space, then centred in the tile.
ctx.saveGState()
ctx.translateBy(x: -70, y: -112)
ctx.scaleBy(x: 1.16, y: 1.16)

// ── Branch (bleeds off both edges) ────────────────────────────────────────
ctx.setLineCap(.round)
ctx.setStrokeColor(rgb(138, 101, 68))
ctx.setLineWidth(46)
ctx.move(to: CGPoint(x: -120, y: 330)); ctx.addLine(to: CGPoint(x: 1180, y: 348))
ctx.strokePath()
ctx.setStrokeColor(rgb(104, 74, 48))
ctx.setLineWidth(14)
ctx.move(to: CGPoint(x: -120, y: 312)); ctx.addLine(to: CGPoint(x: 1180, y: 330))
ctx.strokePath()
// little twig
ctx.setStrokeColor(rgb(138, 101, 68))
ctx.setLineWidth(22)
ctx.move(to: CGPoint(x: 890, y: 344)); ctx.addLine(to: CGPoint(x: 968, y: 418))
ctx.strokePath()

// ── Legs (short, bent, gripping) ──────────────────────────────────────────
func leg(hipX: CGFloat, hipY: CGFloat, kneeX: CGFloat, footX: CGFloat) {
    ctx.setStrokeColor(rgb(84, 178, 124))
    ctx.setLineWidth(56)
    ctx.move(to: CGPoint(x: hipX, y: hipY))
    ctx.addLine(to: CGPoint(x: kneeX, y: 424))
    ctx.addLine(to: CGPoint(x: footX, y: 372))
    ctx.strokePath()
    // two toes pinching the branch
    ctx.setLineWidth(26)
    ctx.move(to: CGPoint(x: footX, y: 372))
    ctx.addLine(to: CGPoint(x: footX - 40, y: 330))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: footX, y: 372))
    ctx.addLine(to: CGPoint(x: footX + 34, y: 336))
    ctx.strokePath()
}
leg(hipX: 500, hipY: 492, kneeX: 452, footX: 486)
leg(hipX: 704, hipY: 498, kneeX: 742, footX: 706)

// ── Tail: tapering spiral, tucked under the branch line ───────────────────
var angle: CGFloat = 1.026          // starts at the body's tail base
var radius: CGFloat = 108
var width: CGFloat = 70
let spiralCenter = CGPoint(x: 300, y: 430)
for _ in 0..<30 {
    ctx.setStrokeColor(rgb(126, 217, 87))
    ctx.setLineWidth(width)
    ctx.addArc(center: spiralCenter, radius: radius,
               startAngle: angle, endAngle: angle - 0.30, clockwise: true)
    ctx.strokePath()
    angle -= 0.28
    radius *= 0.953
    width  *= 0.947
}

// ── Body ──────────────────────────────────────────────────────────────────
let body = CGMutablePath()
body.move(to: CGPoint(x: 352, y: 506))                         // tail base
body.addCurve(to: CGPoint(x: 566, y: 688),                     // back hump
              control1: CGPoint(x: 392, y: 626),
              control2: CGPoint(x: 458, y: 684))
body.addCurve(to: CGPoint(x: 632, y: 712),                     // nape
              control1: CGPoint(x: 596, y: 692),
              control2: CGPoint(x: 610, y: 702))
body.addCurve(to: CGPoint(x: 712, y: 784),                     // swept casque
              control1: CGPoint(x: 664, y: 744),
              control2: CGPoint(x: 682, y: 772))
body.addCurve(to: CGPoint(x: 800, y: 600),                     // brow → snout
              control1: CGPoint(x: 790, y: 782),
              control2: CGPoint(x: 812, y: 672))
body.addCurve(to: CGPoint(x: 744, y: 542),                     // snout tip
              control1: CGPoint(x: 794, y: 562),
              control2: CGPoint(x: 774, y: 542))
body.addCurve(to: CGPoint(x: 478, y: 458),                     // jaw → belly
              control1: CGPoint(x: 662, y: 542),
              control2: CGPoint(x: 572, y: 458))
body.addCurve(to: CGPoint(x: 352, y: 506),                     // belly → tail
              control1: CGPoint(x: 412, y: 458),
              control2: CGPoint(x: 364, y: 470))
body.closeSubpath()

ctx.saveGState()
ctx.addPath(body)
ctx.clip()
ctx.drawLinearGradient(
    gradient([rgb(126, 217, 87), rgb(53, 199, 217), rgb(150, 122, 232)],
             [0, 0.55, 1]),
    start: CGPoint(x: 340, y: 440), end: CGPoint(x: 810, y: 790), options: [])
ctx.restoreGState()

// soft spots, clipped so they never spill past the silhouette
ctx.saveGState()
ctx.addPath(body)
ctx.clip()
ctx.setFillColor(rgb(255, 255, 255, 0.16))
for (x, y, r) in [(468, 596, 40), (556, 626, 32), (628, 640, 24),
                  (508, 528, 26)] as [(CGFloat, CGFloat, CGFloat)] {
    ctx.fillEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
}
ctx.restoreGState()

// ── Eye turret ────────────────────────────────────────────────────────────
let eye = CGPoint(x: 706, y: 630)
ctx.setFillColor(rgb(104, 210, 182))
ctx.fillEllipse(in: CGRect(x: eye.x-74, y: eye.y-74, width: 148, height: 148))
ctx.setFillColor(rgb(255, 255, 255))
ctx.fillEllipse(in: CGRect(x: eye.x-43, y: eye.y-43, width: 86, height: 86))
ctx.setFillColor(rgb(26, 42, 50))
ctx.fillEllipse(in: CGRect(x: eye.x-2, y: eye.y-21, width: 43, height: 43))
ctx.setFillColor(rgb(255, 255, 255, 0.95))
ctx.fillEllipse(in: CGRect(x: eye.x+16, y: eye.y+3, width: 16, height: 16))

// ── Smile ─────────────────────────────────────────────────────────────────
ctx.setStrokeColor(rgb(26, 42, 50, 0.5))
ctx.setLineWidth(12)
ctx.move(to: CGPoint(x: 756, y: 570))
ctx.addCurve(to: CGPoint(x: 702, y: 556),
             control1: CGPoint(x: 740, y: 556), control2: CGPoint(x: 720, y: 552))
ctx.strokePath()

ctx.restoreGState()   // chameleon transform
ctx.restoreGState()   // tile clip
image.unlockFocus()

let tiff = image.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "AppIcon.png"))
print("wrote AppIcon.png")
