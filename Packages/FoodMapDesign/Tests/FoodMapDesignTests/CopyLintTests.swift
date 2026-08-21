import Testing
import Foundation

/// Non-functional — the words themselves (NFR-4.5 … NFR-4.7, NFR-5.5, NFR-5.6).
///
/// Copy had never had a test in this project: the catalogue was checked for *completeness*
/// (TC-N-01) and never for *content*, which is how four separate faults arrived one string at a
/// time (voice note, 21 Aug). These read the catalogue as data.
///
/// They lint; they do not judge. No assertion can tell whether a sentence is friendly. What they
/// can do is stop the faults coming back.
@Suite("Non-functional — the words")
struct CopyLintTests {

    // MARK: - Reading the catalogue

    private struct Catalogue {
        let strings: [String: [String: String]]   // key -> language -> value

        func value(_ key: String, _ language: String) -> String? { strings[key]?[language] }
        var keys: [String] { Array(strings.keys) }
        func values(in language: String) -> [(key: String, value: String)] {
            strings.compactMap { key, byLanguage in
                byLanguage[language].map { (key, $0) }
            }
        }
    }

    /// Located from this file rather than a bundle: the catalogue belongs to the app target, and
    /// these tests deliberately live in a package so they run in the fast loop.
    private static func load() throws -> Catalogue {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()   // FoodMapDesignTests
            .deletingLastPathComponent()              // Tests
            .deletingLastPathComponent()              // FoodMapDesign
            .deletingLastPathComponent()              // Packages
            .deletingLastPathComponent()              // repo root
        let url = root
            .appendingPathComponent("FoodMap/Resources/Localizable.xcstrings")

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let strings = json["strings"] as? [String: Any] ?? [:]

        var parsed: [String: [String: String]] = [:]
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else { continue }
            var byLanguage: [String: String] = [:]
            for (language, unit) in localizations {
                guard let unit = unit as? [String: Any] else { continue }
                if let stringUnit = unit["stringUnit"] as? [String: Any],
                   let value = stringUnit["value"] as? String {
                    byLanguage[language] = value
                } else if let variations = unit["variations"] as? [String: Any],
                          let plural = variations["plural"] as? [String: Any] {
                    // A plural entry stands for all of its cases; join them so a lint that looks
                    // for a forbidden phrase still sees it.
                    let cases = plural.values.compactMap { form -> String? in
                        (form as? [String: Any])
                            .flatMap { $0["stringUnit"] as? [String: Any] }
                            .flatMap { $0["value"] as? String }
                    }
                    byLanguage[language] = cases.joined(separator: " · ")
                }
            }
            parsed[key] = byLanguage
        }
        return Catalogue(strings: parsed)
    }

    // MARK: - The lints

    /// TC-N-30 — one idea, one string.
    @Test("Every key is translated, and no two keys say the same thing in English")
    func TC_N_30_noDuplicateMeanings() throws {
        let catalogue = try Self.load()
        // Guard against a lint that passes because it read nothing.
        #expect(catalogue.keys.count > 100, "The catalogue did not load — these lints prove nothing")

        let untranslated = catalogue.keys.filter { catalogue.value($0, "vi") == nil }
        #expect(untranslated.isEmpty, "Untranslated: \(untranslated.sorted())")

        var byEnglish: [String: [String]] = [:]
        for (key, value) in catalogue.values(in: "en") {
            byEnglish[value.lowercased(), default: []].append(key)
        }
        let duplicates = byEnglish.filter { $0.value.count > 1 }
        #expect(duplicates.isEmpty, """
            Two keys printing one sentence — a reader learns each synonym separately and a \
            translator is handed two entries where there is one idea: \(duplicates)
            """)
    }

    /// TC-N-31 — Vietnamese is written, not translated (NFR-5.5).
    @Test("No English passive, no phone that has lost its signal, no stamp called a seal")
    func TC_N_31_vietnameseIsVietnamese() throws {
        let catalogue = try Self.load()
        // Lower-cased before matching: the first offender found was `Được đóng tem bởi`, at the
        // head of a sentence, which a case-sensitive `contains` walked straight past.
        let vietnamese = catalogue.values(in: "vi").map { (key: $0.key, value: $0.value.lowercased()) }

        // `được … bởi` is a calque of the English passive and reads as machine translation.
        let passive = vietnamese.filter { $0.value.contains("được") && $0.value.contains("bởi") }
        #expect(passive.isEmpty, "Vietnamese says who did it: \(passive.map(\.key))")

        // `sóng` alone is the mobile signal, so "this phone has no sóng" reads as no reception.
        // Qualified — `qua sóng`, `tầm sóng` — it is good Vietnamese and stays.
        let bareRadio = vietnamese.filter {
            $0.value.contains("không có sóng") || $0.value.contains("chưa có sóng")
        }
        #expect(bareRadio.isEmpty, "That claims the phone has no reception: \(bareRadio.map(\.key))")

        // The product's central object is a `tem`. `dấu` is a seal, and was only ever heard by
        // Vietnamese VoiceOver users, who therefore heard a different noun than the screen showed.
        let seal = vietnamese.filter { $0.value.contains("đóng dấu") }
        #expect(seal.isEmpty, "A stamp is a `tem`, on screen and aloud: \(seal.map(\.key))")

        // `chấm điểm` is what a teacher does to homework.
        let marking = vietnamese.filter { $0.value.contains("chấm điểm") }
        #expect(marking.isEmpty, "Rating a meal is `đánh giá`: \(marking.map(\.key))")
    }

    /// TC-N-33 — the lexicon holds (NFR-4.5).
    @Test("No shipped string uses a retired synonym")
    func TC_N_33_lexiconHolds() throws {
        let catalogue = try Self.load()
        // Retired in the voice note, 21 Aug. Exact English values, not substrings: `On` retires
        // as a whole label without outlawing the word inside a sentence.
        let retired: Set<String> = ["Add meal", "Nearby", "Finding you…", "Rate this meal",
                                    "On", "Off", "Show", "Step 2 of 3", "OK", "· %@ meals"]
        let offenders = catalogue.values(in: "en").filter { retired.contains($0.value) }
        #expect(offenders.isEmpty, "Retired synonyms back in the catalogue: \(offenders.map(\.key))")
    }

    /// TC-N-27, extended — a property guaranteed in English is guaranteed in every language
    /// (NFR-5.6). The English-only assertion passed while three Vietnamese inks shared `xanh`.
    @Test("Every friend ink is a distinct word in every language, first word included")
    func TC_N_27_inkWordsAreDistinctInEveryLanguage() throws {
        let catalogue = try Self.load()
        let inks = ["gold", "harbour", "jade", "leaf", "rose", "rust", "teal", "violet"]

        for language in ["en", "vi"] {
            let words = inks.compactMap { catalogue.value($0, language) }
            #expect(words.count == inks.count, "\(language) is missing an ink word")
            #expect(Set(words).count == inks.count, "\(language) repeats an ink word")

            // The first word is what a screen-reader user hears first, and what they must be
            // able to tell apart without waiting out the phrase.
            let firstWords = words.compactMap { $0.split(separator: " ").first.map(String.init) }
            #expect(
                Set(firstWords).count == inks.count,
                "\(language) inks share a leading word: \(firstWords.sorted())"
            )
        }
    }
}
