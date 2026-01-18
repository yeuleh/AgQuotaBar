import SwiftUI

struct MenuBarIcon: View {
    let percentage: Int?
    let isMonochrome: Bool
    let isStale: Bool
    let showPercentage: Bool

    var body: some View {
        HStack(spacing: 3) {
            GravityArc(
                percentage: percentage.map(Double.init),
                ringColor: ringColor,
                trackColor: Color.primary.opacity(0.25),
                lineWidth: 2.5
            )
            .frame(width: 16, height: 16)
            .padding(4)

            if showPercentage {
                if let percentage {
                    Text("\(percentage)%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text("--")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ringColor: Color {
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
            return .red
        }
        if percentage < 50 {
            return .yellow
        }
        return .green
    }
}

struct GravityArc: View {
    let percentage: Double?
    let ringColor: Color
    let trackColor: Color
    let lineWidth: CGFloat

    private var normalizedPercentage: Double {
        guard let percentage else {
            return 0
        }
        return min(max(percentage, 0), 100)
    }

    private var trimValue: CGFloat {
        CGFloat(normalizedPercentage / 100)
    }

    private var satelliteSize: CGFloat {
        lineWidth * 1.5
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let inset = max(lineWidth, satelliteSize)
            let radius = (size - inset) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let endAngle = (normalizedPercentage / 100 * 360) - 90

            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)

                if trimValue > 0 {
                    Circle()
                        .trim(from: 0, to: trimValue)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                if trimValue > 0 && trimValue < 1 {
                    Circle()
                        .fill(ringColor)
                        .frame(width: satelliteSize, height: satelliteSize)
                        .position(
                            x: center.x + radius * cos(endAngle.degreesToRadians),
                            y: center.y + radius * sin(endAngle.degreesToRadians)
                        )
                }
            }
        }
    }
}

private extension Double {
    var degreesToRadians: CGFloat {
        CGFloat(self) * .pi / 180
    }
}
