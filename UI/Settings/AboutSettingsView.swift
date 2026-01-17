import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.3), radius: 12, y: 6)
                
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 20)
            
            Text("AgQuotaBar")
                .font(.title.bold())
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            
            Text("Monitor your Google Antigravity quota from the macOS menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 16)
            
            Spacer()
            
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 40)
                
                HStack(spacing: 4) {
                    Text("Made with")
                        .foregroundStyle(.tertiary)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.caption)
                    Text("for developers")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                
                Text("© 2024 AgQuotaBar")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
