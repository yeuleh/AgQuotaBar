import SwiftUI

struct MenuBarIcon: View {
    let percentage: Int?
    let isMonochrome: Bool

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: ringTrim)
                    .stroke(ringColor, lineWidth: 3)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)

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

    private var ringTrim: CGFloat {
        guard let percentage else {
            return 0
        }
        return CGFloat(max(0, min(percentage, 100))) / 100
    }

    private var ringColor: Color {
        guard let percentage else {
            return Color.gray
        }
        if isMonochrome {
            return Color.gray
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
