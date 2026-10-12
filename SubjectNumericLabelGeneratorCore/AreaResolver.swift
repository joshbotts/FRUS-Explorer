// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AreaResolver

/// Reads the country, region or organization element of a subject-numeric key (#1254).
///
/// ## NARA's rule is generative, and that is why a code table cannot answer it alone
/// The archivists describe the element this way: names "may be spelled out in full or they may be
/// abbreviated using a common abbreviation (USSR for the Union of Soviet Socialist Republics and
/// UN for the United Nations) or the first few letters of the name (POL for Poland and KOR N for
/// North Korea)". The Department printed a list of standard codes, and since #1644 a tail that is
/// one of them takes the name printed beside it; the resolver's own comment says why that comes
/// first. But a filer was not held to the list, so behind it there is a NAME, and a filer's
/// abbreviation of it, made three different ways.
///
/// Matching the printed codes letter for letter failed exactly where it mattered: the 1963
/// handbook prints `S VIET` and the corpus writes `VIET S`, so the heaviest tail in the whole
/// channel — 674 documents — resolved to nothing while its neighbours resolved. Both spellings
/// are the same rule applied to the same name. A printed code is therefore looked up by its
/// tokens in any order (``codeKey(_:)``), and a tail the list does not print is matched to a NAME.
///
/// ## The order-free cover is what unifies the two spellings
/// `KOR N` is NARA's own example, and it shows the filer working from the index form of the name
/// (*Korea, North*) rather than the spoken one. Since a filer may write either, each token of the
/// tail is matched to some word of the name without regard to order.
///
/// ## Every acceptance requires the WHOLE name to be accounted for
/// A partial cover reads plausibly and is wrong: measured against the handbook's own appendix,
/// `GER W` matched *Saar (West Germany)* — GER on GERMANY, W on WEST, with SAAR left over — so a
/// caption naming a single town would have stood over every West German document in the corpus. A
/// place filed UNDER a name is not that name.
///
/// Version history:
///   1.0 — #1254: initial implementation
///   1.1 — #1644: the handbook's printed country codes are read first, the common abbreviations
///          after them; a half of a paired tail is read as a whole tail is, curated readings
///          included; the first-few-letters form is one token's alone
public enum AreaResolver {

    /// The compass qualifiers a filer appends to a divided country.
    ///
    /// Expanded rather than left as a letter because the pair `VIET S` / `S VIET` is 830 documents
    /// and both must read the same; a bare `S` would leave the reader to work out which end of the
    /// key it belongs to.
    static let directions: [String: String] = [
        "N": "North", "S": "South", "E": "East", "W": "West",
        "NE": "Northeast", "NW": "Northwest", "SE": "Southeast", "SW": "Southwest",
    ]

    /// Words an English abbreviation passes over when it takes initials.
    static let unInitialised: Set<String> = ["OF", "THE", "AND", "DE", "DU", "LA", "EL"]

    /// A tail as the corpus writes it, normalised for comparison.
    ///
    /// - Parameter raw: The tail as a source note wrote it.
    /// - Returns: Upper case, punctuation dropped, spacing collapsed.
    public static func normalized(_ raw: String) -> String {
        raw.uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9 -]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// The name's words, upper-cased, punctuation dropped.
    ///
    /// - Parameter name: A country, region or organization name.
    /// - Returns: Its words.
    static func words(of name: String) -> [String] {
        name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { $0.uppercased() }
    }

    /// Whether every token of `tokens` truncates a distinct word of `name`, leaving none over.
    ///
    /// - Parameters:
    ///   - name: A candidate name.
    ///   - tokens: The tail's tokens.
    /// - Returns: `true` on a full cover.
    static func fullyCovers(_ name: String, _ tokens: [String]) -> Bool {
        var unused = words(of: name)
        guard !unused.isEmpty, !tokens.isEmpty else { return false }
        for token in tokens {
            guard let index = unused.firstIndex(where: { $0.hasPrefix(token) }) else { return false }
            unused.remove(at: index)
        }
        return unused.isEmpty
    }

    /// The initials an English abbreviation would take from a name.
    ///
    /// - Parameter name: A candidate name.
    /// - Returns: `USSR` for *Union of Soviet Socialist Republics*.
    static func initials(of name: String) -> String {
        words(of: name).filter { !unInitialised.contains($0) }
            .compactMap(\.first).map(String.init).joined()
    }

    /// A code's key in the printed code table: its tokens, in a fixed order.
    ///
    /// The 1963 handbook prints `S VIET` and `W GER` where the corpus writes `VIET S` and
    /// `GER W`. Both are the same code with its qualifier on the other side, so a code is looked
    /// up by its tokens and not by their order.
    ///
    /// - Parameter code: A normalised tail, half or printed code.
    /// - Returns: The key.
    static func codeKey(_ code: String) -> String {
        code.split(separator: " ").sorted().joined(separator: " ")
    }

    /// Resolves one tail, or `nil`.
    ///
    /// ## The order of the sources, and why the printed codes come first
    /// The 1963 handbook says of its own country appendix that it is "a list of standard country
    /// abbreviations … for use in coding papers relating to specific countries", and the 1965
    /// edition that the list was "eliminated but can be obtained from the Division of Records
    /// Management, upon request". So a tail that IS one of the printed codes has a name the
    /// Department gave it, for both schedules, and nothing is inferred: `UK` is *United Kingdom*
    /// because the appendix prints it so. Read without that table, `UK` is the first two letters
    /// of *Ukraine*, the shorter name, and that is what the 1964–1973 schedule shipped over 54
    /// documents (#1644).
    ///
    /// The common abbreviations come second: an agency or an international body named by the
    /// handbook's other appendix (`UN`, `NATO`, `ORG 7 JCS` for the Joint Chiefs). They used to
    /// come first, which let that appendix's misread codes outrank a country: `FLN`, read `FIN`,
    /// made Finland the *Algerian National Liberation Front*, and `CUSA`, read `CUBA`, made
    /// Cuba the *Council for U.S. Aid (Nationalist China)*.
    ///
    /// Last, NARA's generative forms over the names, for a tail the list does not print as the
    /// corpus writes it (`CAMB`, `SAUD`).
    ///
    /// - Parameters:
    ///   - tail: The tail as a source note wrote it.
    ///   - names: Country, region and organization names.
    ///   - organizations: Common abbreviations the handbook states outright.
    ///   - curated: Readings no rule can reach, keyed by normalised tail or half.
    ///   - codes: The handbook's printed country codes, keyed by ``codeKey(_:)``.
    ///   - refused: Tails and halves left unread, because every reading the sources offer for
    ///     them is another thing's.
    /// - Returns: The name, or `nil` when nothing resolves it unambiguously.
    public static func resolve(_ tail: String, names: [String],
                               organizations: [String: String],
                               curated: [String: String],
                               codes: [String: String] = [:],
                               refused: Set<String> = []) -> String? {
        let code = normalized(tail)
        // ONE LETTER IS NOT A PLACE, as a whole tail any more than as half of one. The corpus's
        // one-letter tails are office symbols under `ORG 7` (`S` for the Secretary, `U` for the
        // Under Secretary), and the first few letters of a name, given one letter, is whichever
        // name is shortest: the shipped table read `ORG 7 U` as *Uganda*.
        guard code.count >= 2 else { return nil }
        func one(_ text: String) -> String? {
            refused.contains(text) ? nil
                : resolveOne(text, names: names, organizations: organizations,
                             curated: curated, codes: codes)
        }
        if let whole = one(code) { return whole }

        let tokens = code.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ").map(String.init)
        // A COMPASS QUALIFIER WRITTEN WITH A HYPHEN is still a qualifier: `VIET-S` is South
        // Vietnam, not Vietnam and a second party called S.
        let sides = code.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        if sides.count == 2, sides.contains(where: { directions[$0] != nil }),
           let whole = one(sides.joined(separator: " ")) {
            return whole
        }
        func half(_ text: String) -> String? {
            // ONE LETTER IS NOT A PARTY, whichever way the tail is divided.
            text.count >= 2 ? one(text) : nil
        }

        // TWO PARTIES in one tail — `KOR N-US`, `INDIA PAK`.
        //
        // THE HYPHEN IS THE FILER'S OWN DIVISION and is taken before any other. Searching cut
        // positions first splits `KOR N-US` after `KOR`, which leaves `N US` as the second half
        // and hands its compass qualifier to the wrong country: measured, that shipped
        // *Korea and United States, North* over 87 documents.
        if code.contains("-") {
            let halves = code.split(separator: "-", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if halves.count == 2, let a = half(halves[0]), let b = half(halves[1]), a != b {
                return paired(a, b)
            }
        }
        if tokens.count >= 2 {
            for cut in 1..<tokens.count {
                let left = tokens[..<cut].joined(separator: " ")
                let right = tokens[cut...].joined(separator: " ")
                // A HALF MUST BE AT LEAST TWO CHARACTERS. One letter truncates far too many names
                // to mean anything: `GER B` resolved to *Germany and Bali* on a `B` that fully
                // covers a four-letter island, where the record almost certainly means Berlin.
                if let a = half(left), let b = half(right), a != b {
                    return paired(a, b)
                }
            }
        }
        return nil
    }

    /// Two parties, joined as the reader reads them.
    ///
    /// - Parameters:
    ///   - first: One party's name.
    ///   - second: The other's.
    /// - Returns: The joined reading.
    static func paired(_ first: String, _ second: String) -> String {
        String(format: String(localized: "archival.area.pair %@ %@",
                              defaultValue: "%1$@ and %2$@"), first, second)
    }

    /// One party: a whole tail, or one half of a paired one.
    ///
    /// A half is read exactly as a whole tail is, the curated readings included. They were not
    /// consulted for a half until #1644, so `CHICOM` alone read *China (Communist)* by the
    /// curated map while `CHICOM-US` took the abbreviations appendix's damaged line for the
    /// same code, *Connnunist China and United States*.
    ///
    /// - Parameters:
    ///   - code: A normalised tail or half.
    ///   - names: The name list.
    ///   - organizations: Common abbreviations.
    ///   - curated: Readings no rule can reach.
    ///   - codes: The handbook's printed country codes.
    /// - Returns: The name, or `nil`.
    static func resolveOne(_ code: String, names: [String], organizations: [String: String],
                           curated: [String: String], codes: [String: String]) -> String? {
        if let hand = curated[code] ?? curated[codeKey(code)] { return hand }
        if let printed = codes[codeKey(code)] { return printed }
        if let common = organizations[code] { return common }
        if let direct = match(code, names: names) { return direct }

        // A COMPASS QUALIFIER beside a name: `VIET S` and `S VIET` are the same country.
        let tokens = code.split(separator: " ").map(String.init)
        let qualifiers = tokens.filter { directions[$0] != nil }
        let rest = tokens.filter { directions[$0] == nil }
        guard let qualifier = qualifiers.first, !rest.isEmpty,
              let base = codes[codeKey(rest.joined(separator: " "))]
                ?? match(rest.joined(separator: " "), names: names),
              let word = directions[qualifier]
        else { return nil }
        return "\(base), \(word)"
    }

    /// The one name a tail names, under NARA's three abbreviation forms.
    ///
    /// Ambiguity is REFUSED rather than broken by a coin toss: two different names of equal length
    /// both answering a tail means the evidence does not choose, and a wrong country is worse than
    /// a bare code.
    ///
    /// - Parameters:
    ///   - code: A normalised tail or half.
    ///   - names: The name list.
    /// - Returns: The name, or `nil`.
    static func match(_ code: String, names: [String]) -> String? {
        let tokens = code.split(separator: " ").map(String.init)
        let flat = code.replacingOccurrences(of: " ", with: "")
        var candidates: Set<String> = []
        // LETTERS SET APART ARE INITIALS, NOT TRUNCATIONS. `U S` is the United States written
        // with a space; taken as two first letters it covers *Soviet Union* in full, which is
        // the shorter name and so the one that was chosen.
        let truncates = tokens.contains { $0.count > 1 }
        for name in names {
            if (truncates && fullyCovers(name, tokens)) || initials(of: name) == flat {
                candidates.insert(name)
            } else if tokens.count == 1, flat.count >= 3,
                      words(of: name).joined().hasPrefix(flat) {
                // "the first few letters of the name" taken across the whole name, which is how
                // `SAUD` reaches *Saudi Arabia* and `CAMB` reaches *Cambodia*. ONE token only: a
                // tail of two is two things, and run together `VIET N` is the first five letters
                // of *Vietnam* — which is what North Vietnam's files read until #1644.
                candidates.insert(name)
            }
        }
        let ranked = candidates.sorted { $0.count == $1.count ? $0 < $1 : $0.count < $1.count }
        guard let first = ranked.first else { return nil }
        if ranked.count > 1, ranked[1].count == first.count { return nil }
        return first
    }
}
