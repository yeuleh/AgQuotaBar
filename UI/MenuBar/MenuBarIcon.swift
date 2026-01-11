import SwiftUI

struct MenuBarIcon: View {
    let percentage: Int?
    let isMonochrome: Bool
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: renderRingImage())
            
            if let percentage {
                Text("\(percentage)%")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func renderRingImage() -> NSImage {
        let pointSize: CGFloat = 22
        let ringDiameter: CGFloat = 14
        let lineWidth: CGFloat = 2
        let scale: CGFloat = 2
        let pixelSize = NSSize(width: pointSize * scale, height: pointSize * scale)
        let image = NSImage(size: pixelSize)

        image.lockFocus()
        NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)

        let ringOrigin = (pointSize - ringDiameter) / 2
        let ringRect = NSRect(
            x: ringOrigin + (lineWidth / 2),
            y: ringOrigin + (lineWidth / 2),
            width: ringDiameter - lineWidth,
            height: ringDiameter - lineWidth
        )
        let backgroundPath = NSBezierPath(ovalIn: ringRect)
        NSColor.labelColor.withAlphaComponent(0.2).setStroke()
        backgroundPath.lineWidth = lineWidth
        backgroundPath.stroke()

        if ringTrim > 0 {
            let foregroundPath = NSBezierPath()
            let center = NSPoint(x: pointSize / 2, y: pointSize / 2)
            let radius = (ringDiameter - lineWidth) / 2
            let startAngle: CGFloat = 90
            let endAngle: CGFloat = 90 - (360 * ringTrim)
            foregroundPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            ringNSColor.setStroke()
            foregroundPath.lineWidth = lineWidth
            foregroundPath.lineCapStyle = .round
            foregroundPath.stroke()
        }

        image.unlockFocus()
        image.size = NSSize(width: pointSize, height: pointSize)
        image.isTemplate = isMonochrome
        return image
    }

    private var ringTrim: CGFloat {
        guard let percentage else {
            return 0
        }
        return CGFloat(max(0, min(percentage, 100))) / 100
    }

    private var ringNSColor: NSColor {
        if isStale {
            return .gray
        }
        guard let percentage else {
            return .gray
        }
        if isMonochrome {
            return .gray
        }
        if percentage < 20 {
            return .systemRed
        }
        if percentage < 50 {
            return .systemYellow
        }
        return .systemGreen
    }
}
