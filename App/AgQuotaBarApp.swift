import SwiftUI
import AppKit

@main
struct AgQuotaBarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuDropdown(appState: appState)
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: renderIcon(
                    percentage: appState.selectedDisplayPercentage,
                    isMonochrome: appState.isMonochrome,
                    isStale: appState.isStale
                ))
                
                if appState.showPercentage {
                    if let percentage = appState.selectedDisplayPercentage {
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
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }

    @MainActor
    private func renderIcon(percentage: Int?, isMonochrome: Bool, isStale: Bool) -> NSImage {
        let view = MenuBarIcon(
            percentage: percentage,
            isMonochrome: isMonochrome,
            isStale: isStale,
            showPercentage: false
        )
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage ?? NSImage()
    }
}
