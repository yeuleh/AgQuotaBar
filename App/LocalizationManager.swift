import Foundation
import SwiftUI
import Combine

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        case .japanese:
            return "日本語"
        }
    }
}

// MARK: - Localization Manager

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published private(set) var currentLanguage: AppLanguage
    @Published private(set) var refreshId = UUID()
    
    private var bundle: Bundle
    
    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "language")
        let language = AppLanguage(rawValue: savedLanguage ?? "") ?? .english
        self.currentLanguage = language
        self.bundle = Self.loadBundle(for: language) ?? .main
    }
    
    @MainActor
    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        bundle = Self.loadBundle(for: language) ?? .main
        UserDefaults.standard.set(language.rawValue, forKey: "language")
        refreshId = UUID()
    }
    
    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: arguments)
    }
    
    nonisolated private static func loadBundle(for language: AppLanguage) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            if let basePath = Bundle.main.path(forResource: "Base", ofType: "lproj") {
                return Bundle(path: basePath)
            }
            return nil
        }
        return bundle
    }
}

// MARK: - Environment Key

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}

// MARK: - Localized Text View

struct LocalizedText: View {
    @ObservedObject private var manager = LocalizationManager.shared
    let key: String
    let arguments: [CVarArg]
    
    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }
    
    var body: some View {
        if arguments.isEmpty {
            Text(manager.localized(key))
        } else {
            Text(String(format: manager.localized(key), arguments: arguments))
        }
    }
}

// MARK: - Convenience Extension

extension String {
    var localized: String {
        LocalizationManager.shared.localized(self)
    }
    
    func localized(_ arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(self)
        return String(format: format, arguments: arguments)
    }
}
