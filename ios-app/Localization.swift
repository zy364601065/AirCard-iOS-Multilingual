import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    static let storageKey = "aircard.app_language"

    var id: String { rawValue }

    /// Language names intentionally stay in their native form in every UI language.
    var displayName: String {
        switch self {
        case .system: return L("Follow System")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }

    var resolvedIdentifier: String {
        switch self {
        case .system:
            return Self.identifier(for: Locale.preferredLanguages)
        case .english, .simplifiedChinese, .traditionalChinese:
            return rawValue
        }
    }

    var locale: Locale { Locale(identifier: resolvedIdentifier) }

    static func identifier(for preferredLanguages: [String]) -> String {
        guard let preferred = preferredLanguages.first else { return "en" }
        let normalized = preferred.replacingOccurrences(of: "_", with: "-")
        let parts = normalized.split(separator: "-").map { String($0).lowercased() }
        guard parts.first == "zh" else { return "en" }

        if parts.contains("hant") || parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) {
            return "zh-Hant"
        }
        return "zh-Hans"
    }
}

final class LanguageSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: AppLanguage.storageKey)
        language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    var locale: Locale { language.locale }
}

enum AppLocalization {
    private final class BundleToken {}

    private static var resourceBundle: Bundle { Bundle(for: BundleToken.self) }

    static var selectedLanguage: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        return stored.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    static func bundle(for language: AppLanguage? = nil) -> Bundle {
        let identifier = (language ?? selectedLanguage).resolvedIdentifier
        if let path = resourceBundle.path(forResource: identifier, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = resourceBundle.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return resourceBundle
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle().localizedString(forKey: key, value: nil, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: selectedLanguage.locale, arguments: arguments)
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let format = AppLocalization.bundle().localizedString(forKey: key, value: nil, table: nil)
    guard !arguments.isEmpty else { return format }
    return String(format: format, locale: AppLocalization.selectedLanguage.locale, arguments: arguments)
}

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageSettings: LanguageSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            languageSettings.language = language
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if languageSettings.language == language {
                                    Image(systemName: "checkmark")
                                        .font(.body.bold())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("App Language")
                } footer: {
                    Text("This setting changes AirCard-iOS only. The passcode theme language target is configured separately in the Passcode tab.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .id(languageSettings.language.rawValue)
    }
}
