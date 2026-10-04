import XCTest
@testable import AirCard_iOS

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolution() {
        XCTAssertEqual(AppLanguage.identifier(for: ["en-US"]), "en")
        XCTAssertEqual(AppLanguage.identifier(for: ["zh-CN"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.identifier(for: ["zh-Hans-SG"]), "zh-Hans")
        XCTAssertEqual(AppLanguage.identifier(for: ["zh-TW"]), "zh-Hant")
        XCTAssertEqual(AppLanguage.identifier(for: ["zh-HK"]), "zh-Hant")
        XCTAssertEqual(AppLanguage.identifier(for: ["zh-Hant"]), "zh-Hant")
        XCTAssertEqual(AppLanguage.identifier(for: []), "en")
    }

    func testLanguageSelectionPersists() {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = LanguageSettings(defaults: defaults)
        XCTAssertEqual(settings.language, .system)
        settings.language = .traditionalChinese
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "zh-Hant")
        XCTAssertEqual(LanguageSettings(defaults: defaults).language, .traditionalChinese)
    }

    func testLocalizedResourcesAndFormatting() throws {
        for language in [AppLanguage.english, .simplifiedChinese, .traditionalChinese] {
            let bundle = AppLocalization.bundle(for: language)
            let setting = bundle.localizedString(forKey: "Settings", value: nil, table: nil)
            XCTAssertNotEqual(setting, "", "Missing Settings translation for \(language.rawValue)")
        }

        let hans = AppLocalization.bundle(for: .simplifiedChinese)
        let format = hans.localizedString(forKey: "Card #%lld", value: nil, table: nil)
        XCTAssertEqual(String(format: format, CLongLong(3)), "卡片 #3")
    }

    func testLocalizationKeySetsMatchAndChineseValuesAreNotEmpty() throws {
        let languages: [AppLanguage] = [.english, .simplifiedChinese, .traditionalChinese]
        let dictionaries = try languages.map { language -> [String: String] in
            let bundle = AppLocalization.bundle(for: language)
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.binary
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
            return try XCTUnwrap(plist as? [String: String])
        }

        XCTAssertEqual(Set(dictionaries[0].keys), Set(dictionaries[1].keys))
        XCTAssertEqual(Set(dictionaries[0].keys), Set(dictionaries[2].keys))
        XCTAssertFalse(dictionaries[1].values.contains(where: { $0.isEmpty }))
        XCTAssertFalse(dictionaries[2].values.contains(where: { $0.isEmpty }))

        for key in ["Settings", "Pairing", "Wallet Cards", "Passcode", "Wallpapers"] {
            XCTAssertNotEqual(dictionaries[1][key], dictionaries[0][key])
            XCTAssertNotEqual(dictionaries[2][key], dictionaries[0][key])
        }
    }
}
