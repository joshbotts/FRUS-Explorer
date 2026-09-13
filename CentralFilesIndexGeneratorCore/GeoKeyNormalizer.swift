// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Normalizes country / post names into canonical geographic keys so a FRUS chapter name
/// (`Argentine Republic`) and a NARA file-unit / roll name (`Argentina`) resolve to the
/// same key, and combined rolls (`Uruguay and Paraguay`) expand to multiple keys.
///
/// The same normalizer runs on both sides of the lookup — the harvested index keys and the
/// app's classifier input — so they must agree. A canonical key is lower-cased, with
/// surrounding noise (a `Volume N:` prefix, trailing punctuation) stripped and internal
/// whitespace collapsed; recognized aliases map to a single preferred key.
///
/// The alias table is a seed from the reference data and common historical names; it will
/// be extended once the diplomatic-series survey reveals the real file-unit vocabulary.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2 — seed table
///   1.1 — 2026-09-13: FRUS chapter-title forms the pre-1906 classifier could not read as a
///         country — a chapter number (`XXIX.—Spain.`), a `(Continued.)` suffix, a letter-to-letter
///         en dash (`Austria–Hungary.`), a chapter of correspondence with a foreign legation in
///         Washington (`British legation.`), `Chili`, and `Rome.` for the Papal States.
///         `canonicalize` gains one alias (`chili`) and nothing else: no roll title in the bundled
///         index contains that spelling, so the keys the generator harvests are unchanged.
///         `Turkish Empire` is deliberately NOT aliased: in `frus1876` it is the parent chapter of
///         `Egypt.`, and Source Explorer takes the first title from the volume root that resolves,
///         so reading it as Turkey moved a document that resolved to Egypt onto the Turkey rolls.
public enum GeoKeyNormalizer {

    /// Maps a normalized variant → preferred canonical key.
    ///
    /// Canonical keys use the **historical** names that appear in pre-1910 FRUS chapter
    /// headings (Persia not Iran, Siam not Thailand), because the app's classifier derives
    /// the lookup key from the FRUS chapter — both sides must converge on the same key.
    ///
    /// Variants come from the four diplomatic series' real vocabularies (harvested
    /// 2026-06-15): country names (Despatches, Notes to), demonyms (Notes from —
    /// `Venezuelan` → venezuela), and FRUS chapter spellings (`Argentine Republic`, `Hayti`,
    /// `Servia`, `Corea`). Combined names (`Sweden and Norway`) are split before lookup.
    static let aliases: [String: String] = [
        // Argentina
        "argentine": "argentina", "argentine republic": "argentina",
        "argentine confederation": "argentina",
        // Austria(-Hungary)
        "austrian": "austria", "austria-hungary": "austria", "austria hungary": "austria",
        // Belgium
        "belgian": "belgium",
        // Bolivia / Brazil / Chile
        "bolivian": "bolivia", "brazilian": "brazil", "chilean": "chile", "chilian": "chile",
        "chili": "chile",
        // China / Colombia
        "chinese": "china",
        "colombian": "colombia", "new granada": "colombia",
        "united states of colombia": "colombia",
        // Costa Rica / Cuba / Denmark
        "costa rican": "costa rica", "cuban": "cuba", "danish": "denmark",
        // Ecuador
        "ecuadorean": "ecuador", "ecuadorian": "ecuador",
        // El Salvador
        "salvador": "el salvador", "salvadoran": "el salvador", "salvadorean": "el salvador",
        // France
        "french": "france",
        // Germany / German States / Prussia / Hanseatic
        "german empire": "germany", "german": "germany",
        "the german states": "german states", "prussian": "prussia",
        "hanse towns": "hanseatic cities", "hanseatic republics": "hanseatic cities",
        // Great Britain
        "british": "great britain", "great britain and ireland": "great britain",
        "united kingdom": "great britain", "england": "great britain",
        // Greece
        "greek": "greece",
        // Haiti / Hawaii
        "haitian": "haiti", "hayti": "haiti", "haytian": "haiti",
        "hawaiian": "hawaii", "hawaiian islands": "hawaii", "sandwich islands": "hawaii",
        // Honduras
        "honduran": "honduras",
        // Italy / Italian States / Sardinia / Two Sicilies
        "italian": "italy", "the italian states": "italian states",
        "sardinian": "sardinia",
        "two sicilies": "two sicilies", "the two sicilies": "two sicilies",
        "kingdom of the two sicilies": "two sicilies", "naples": "two sicilies",
        // Japan / Korea
        "japanese": "japan",
        "korean": "korea", "corea": "korea", "corean": "korea",
        // Liberia / Madagascar / Mexico / Montenegro
        "liberian": "liberia", "madagascan": "madagascar", "malagasy": "madagascar",
        "mexican": "mexico", "montenegrin": "montenegro",
        // Netherlands
        "the netherlands": "netherlands", "dutch": "netherlands", "holland": "netherlands",
        // Norway / Panama / Paraguay
        "norwegian": "norway", "panamanian": "panama", "paraguayan": "paraguay",
        // Persia (historical) / Peru / Portugal
        "persian": "persia",
        "peruvian": "peru", "portuguese": "portugal",
        // Russia / Samoa / Siam (historical)
        "russian": "russia", "samoan": "samoa",
        "siamese": "siam",
        // Spain / Sweden / Switzerland
        "spanish": "spain", "swedish": "sweden", "swiss": "switzerland",
        // Texas / Tunisia / Turkey
        "texan": "texas", "tunisian": "tunisia",
        "turkish": "turkey", "ottoman empire": "turkey", "ottoman porte": "turkey",
        "sublime porte": "turkey",
        // Uruguay / Venezuela / Nicaragua
        "uruguayan": "uruguay", "venezuelan": "venezuela", "nicaraguan": "nicaragua",
        // Dominican Republic
        "the dominican republic": "dominican republic", "dominican": "dominican republic",
        "santo domingo": "dominican republic", "san domingo": "dominican republic",
        // Romania / Serbia (historical spellings)
        "romania": "rumania", "romanian": "rumania", "rumanian": "rumania",
        "roumania": "rumania",
        "serbian": "serbia", "servia": "serbia", "servian": "serbia",
        // Central America
        "central american": "central america", "central american states": "central america",
    ]

    /// Whole FRUS chapter titles that file under a country their words do not spell.
    ///
    /// Read ONLY by `keys(from:)`, never by `canonicalize`: the same word is a consular POST key
    /// elsewhere in the index, and `canonicalize` is what the generator's roll parser calls — an
    /// alias for `rome` there would move the Rome consulate's rolls.
    ///
    /// **`Rome.` is the Papal States.** FRUS titles a chapter `Rome.` only in the 1861–1867
    /// volumes, and every document in it is the U.S. legation at Rome — the mission to the Papal
    /// States, closed in 1868 — or the Department's instructions to it; after 1870 FRUS files Rome
    /// under Italy. The index holds the Papal States instructions as a roll of their own, so those
    /// resolve exactly. Its Papal States despatches sit inside the Italian States series under
    /// `italian states`, beside the Kingdom of Italy's, so a despatch from Rome resolves to nothing
    /// rather than to a set that also names another legation's rolls.
    public static let chapterTitleAliases: [String: String] = [
        "rome": "papal states",
    ]

    /// Returns the canonical geographic key(s) for a raw country/post string.
    ///
    /// Splits combined names (`Uruguay and Paraguay`, `Brazil & Argentina`) into multiple
    /// keys, strips a leading `Volume N:` segment, applies the alias table, and lower-cases.
    /// A FRUS chapter title is read through its decoration first (1.1): a chapter number, a
    /// `(Continued.)` suffix, a letter-to-letter en dash, a foreign-legation chapter, and the whole
    /// titles in `chapterTitleAliases`.
    /// Returns `[]` when no usable name remains (e.g. an empty or purely numeric string).
    public static func keys(from raw: String) -> [String] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip a leading "Volume 18:" / "Vol. 3:" segment.
        if let r = text.range(of: #"^\s*Vol(?:ume|\.)?\s*\d+\s*:\s*"#,
                              options: [.regularExpression, .caseInsensitive]) {
            text = String(text[r.upperBound...])
        }

        // A trailing ": <dates>" segment, if any, is not part of the name.
        if let colon = text.firstIndex(of: ":") {
            text = String(text[..<colon])
        }

        text = stripChapterDecoration(text)
        if let legationCountry = foreignLegationName(inChapterTitle: text) {
            text = legationCountry
        } else if let alias = chapterTitleAliases[fold(text)] {
            return [alias]
        }

        return splitConjunctions(text)
            .map(canonicalize)
            .filter { !$0.isEmpty }
    }

    /// The country a FRUS chapter of correspondence with a FOREIGN legation or embassy in
    /// Washington is about, as the title spells it, or `nil` when the title is not such a chapter.
    ///
    /// The 1860s volumes title these `British legation.` or `Correspondence with the Mexican
    /// legation.`; the 1880s volumes `Correspondence with the legation of Mexico at Washington.`;
    /// `frus1894app1` `Correspondence Between the Department of State and the German Embassy.`
    /// The distinction matters to the classifier as well as to the key: documents in these chapters
    /// are notes to and from the foreign minister in Washington, not instructions to or despatches
    /// from the U.S. minister abroad.
    ///
    /// Refused, so a U.S. mission is never read as a foreign one: a name that is the United States
    /// or American, and any name carrying a place clause (`the embassy of the United States at
    /// Paris`) — the only place a foreign legation's chapter may name is Washington or the United
    /// States.
    public static func foreignLegationName(inChapterTitle raw: String) -> String? {
        let title = fold(stripChapterDecoration(raw))
        let lead = #"(?:correspondence (?:with|between the department of state and) )?(?:the )?"#
        let washington = #"(?:,? (?:at|in) (?:washington(?:,? d\. ?c)?|the united states(?: of america)?))?"#
        let patterns = [
            "^" + lead + #"(?:legation|embassy) of (?:the )?(.+?)"# + washington + "$",
            "^" + lead + #"(\p{L}[\p{L}'-]*(?: \p{L}[\p{L}'-]*){0,2}) (?:legation|embassy)"# + washington + "$",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
                  let range = Range(match.range(at: 1), in: title) else { continue }
            let name = String(title[range])
            let words = name.split(separator: " ").map(String.init)
            if words.contains(where: { ["at", "in", "to", "for", "from", "by"].contains($0) }) { return nil }
            if ["american", "united states", "united states of america"].contains(name)
                || name.hasPrefix("u. s") || name.hasPrefix("u.s") { return nil }
            return name
        }
        return nil
    }

    /// Normalizes a single already-isolated name to its canonical key (no splitting).
    public static func canonicalize(_ name: String) -> String {
        let collapsed = fold(name)
        return aliases[collapsed] ?? collapsed
    }

    /// Trims surrounding whitespace and `.,;`, lower-cases, and collapses internal spaces.
    private static func fold(_ name: String) -> String {
        name
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;")))
            .lowercased()
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
    }

    /// Removes the decoration a FRUS chapter title puts around its name (1.1).
    ///
    /// - a chapter number with its dash: `XXIX.—Spain.`, `1.—Ottoman Porte.`, and the page-marked
    ///   `[199] *I.—France.` / `[347] *III. — Portugal.` of `frus1872p2v2`;
    /// - a `(Continued.)` suffix: `Great Britain. (Continued.)`;
    /// - an en or em dash between two letters, which is the hyphen the aliases spell:
    ///   `Austria–Hungary.`.
    ///
    /// A title without decoration is returned unchanged, so no title that already read as a country
    /// can read differently.
    private static func stripChapterDecoration(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = text.range(of: #"^(?:\[\d+\]\s*)?\*?\s*(?:[IVXLCDM]+|\d{1,3})\.\s*[—–-]\s*"#,
                              options: .regularExpression) {
            text = String(text[r.upperBound...])
        }
        if let r = text.range(of: #"\s*\(\s*continued\.?\s*\)\s*$"#,
                              options: [.regularExpression, .caseInsensitive]) {
            text = String(text[..<r.lowerBound])
        }
        return text.replacingOccurrences(of: #"(?<=\p{L})[–—](?=\p{L})"#, with: "-",
                                         options: .regularExpression)
    }

    /// Splits `A and B`, `A & B`, `A, B` conjunction forms into component names.
    private static func splitConjunctions(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: " & ", with: " and ")
            .replacingOccurrences(of: ", ", with: " and ")
            .components(separatedBy: " and ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
