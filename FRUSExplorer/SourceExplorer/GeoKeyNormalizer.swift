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
/// > Mirror of `CentralFilesIndexGeneratorCore/GeoKeyNormalizer` (the app cannot import the
/// > SPM tool target). Keep the alias table in sync — both sides must produce identical keys.
///
/// Version history:
///   1.0 — Session 2026-06-15: Phase 2 — seed table
enum GeoKeyNormalizer {

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

    /// Returns the canonical geographic key(s) for a raw country/post string.
    ///
    /// Splits combined names (`Uruguay and Paraguay`, `Brazil & Argentina`) into multiple
    /// keys, strips a leading `Volume N:` segment, applies the alias table, and lower-cases.
    /// Returns `[]` when no usable name remains (e.g. an empty or purely numeric string).
    static func keys(from raw: String) -> [String] {
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

        return splitConjunctions(text)
            .map(canonicalize)
            .filter { !$0.isEmpty }
    }

    /// Normalizes a single already-isolated name to its canonical key (no splitting).
    static func canonicalize(_ name: String) -> String {
        let collapsed = name
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;")))
            .lowercased()
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
        return aliases[collapsed] ?? collapsed
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
