import SwiftUI

struct MenuBarIcon: View {
    let percentage: Int?
    let isMonochrome: Bool
    let isStale: Bool
    let showPercentage: Bool

    var body: some View {
        HStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.25), lineWidth: 2.5)
                
                if let ringTrim = ringTrim, ringTrim > 0 {
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 14, height: 14)
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
    
    private var ringTrim: CGFloat? {
        guard let percentage else {
            return nil
        }
        return CGFloat(max(0, min(percentage, 100))) / 100
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
