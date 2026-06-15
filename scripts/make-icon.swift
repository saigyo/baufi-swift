// Generiert das App-Icon (1024 px) im Bauplan-Stil der App und legt es als
// scripts/icon1024.png ab. Aufruf:  swift scripts/make-icon.swift
import AppKit

let S: CGFloat = 1024

func col(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Hintergrund: abgerundetes Rechteck mit vertikalem Verlauf (dunkles Grün → Ink)
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: S, height: S), xRadius: 229, yRadius: 229)
bg.addClip()
NSGradient(colors: [col(0x2A4E40), col(0x141D1B)])!.draw(in: NSRect(x: 0, y: 0, width: S, height: S), angle: -90)

// Blueprint-Gitter
col(0xFFFFFF, 0.05).setStroke()
let grid = NSBezierPath(); grid.lineWidth = 2
let step = S / 16
var p: CGFloat = 0
while p <= S {
    grid.move(to: NSPoint(x: p, y: 0)); grid.line(to: NSPoint(x: p, y: S))
    grid.move(to: NSPoint(x: 0, y: p)); grid.line(to: NSPoint(x: S, y: p))
    p += step
}
grid.stroke()

// Grundlinie (0 €) mit gestricheltem Stil
let cream = col(0xF2F5F3)
let baseY: CGFloat = 300
let base = NSBezierPath(); base.lineWidth = 7
let dash: [CGFloat] = [10, 12]
base.setLineDash(dash, count: 2, phase: 0)
col(0xF2F5F3, 0.55).setStroke()
base.move(to: NSPoint(x: 150, y: baseY)); base.line(to: NSPoint(x: 874, y: baseY))
base.stroke()

// Haus: Dach (Chevron) + Korpus, oben links – cremefarben
cream.setStroke()
let roof = NSBezierPath()
roof.lineWidth = 50; roof.lineCapStyle = .round; roof.lineJoinStyle = .round
roof.move(to: NSPoint(x: 250, y: 720))
roof.line(to: NSPoint(x: 410, y: 850))
roof.line(to: NSPoint(x: 570, y: 720))
roof.stroke()

let body = NSBezierPath()
body.lineWidth = 50; body.lineJoinStyle = .round; body.lineCapStyle = .round
body.move(to: NSPoint(x: 300, y: 720))
body.line(to: NSPoint(x: 300, y: 560))
body.line(to: NSPoint(x: 520, y: 560))
body.line(to: NSPoint(x: 520, y: 720))
body.stroke()

// Fallende Restschuld-Kurve in Akzent-Grün, von oben links zur Grundlinie unten rechts
let curve = NSBezierPath()
curve.lineWidth = 56; curve.lineCapStyle = .round
curve.move(to: NSPoint(x: 250, y: 640))
curve.curve(to: NSPoint(x: 838, y: baseY),
            controlPoint1: NSPoint(x: 540, y: 600),
            controlPoint2: NSPoint(x: 620, y: 330))
col(0x46B083).setStroke()
curve.stroke()

// Endpunkt der Kurve auf der Grundlinie markieren
col(0x46B083).setFill()
let dot = NSBezierPath(ovalIn: NSRect(x: 838 - 34, y: baseY - 34, width: 68, height: 68))
dot.fill()

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: "scripts/icon1024.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("✓ \(out.path)")
