import SwiftUI

struct AboutSettingsView: View {
    @ObservedObject private var l10n = LocalizationManager.shared
    
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
                
                GravityArc(
                    percentage: 72,
                    ringColor: Color.white,
                    trackColor: Color.white.opacity(0.25),
                    lineWidth: 6
                )
                .frame(width: 44, height: 44)
            }
            .padding(.bottom, 20)
            
            Text(verbatim: "AgQuotaBar")
                .font(.title.bold())
            
            Text(L10n.About.version("0.1"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            
            Text(L10n.About.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 16)
            
            Spacer()
            
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 40)
                
                Text(verbatim: "Author: Leon Yeu <github@ulenium.com>")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(verbatim: "© 2026 ulenium studio")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
