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
/// ## NARA's rule is generative, and that is why a code table cannot answer it
/// The archivists describe the element this way: names "may be spelled out in full or they may be
/// abbreviated using a common abbreviation (USSR for the Union of Soviet Socialist Republics and
/// UN for the United Nations) or the first few letters of the name (POL for Poland and KOR N for
/// North Korea)". There is no controlled vocabulary to look a tail up in — there is a NAME, and a
/// filer's abbreviation of it, made three different ways.
///
/// Trying to match the printed codes instead failed exactly where it mattered: the 1963 handbook
/// prints `S VIET` and the corpus writes `VIET S`, so the heaviest tail in the whole channel —
/// 674 documents — resolved to nothing while its neighbours resolved. Both spellings are the same
/// rule applied to the same name, and matching the NAME makes them one question.
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

    /// Resolves one tail against a name list, or `nil`.
    ///
    /// - Parameters:
    ///   - tail: The tail as a source note wrote it.
    ///   - names: Country, region and organization names.
    ///   - organizations: Common abbreviations the handbook states outright.
    ///   - curated: Readings no rule can reach, keyed by normalised tail.
    /// - Returns: The name, or `nil` when nothing resolves it unambiguously.
    public static func resolve(_ tail: String, names: [String],
                               organizations: [String: String],
                               curated: [String: String]) -> String? {
        let code = normalized(tail)
        guard !code.isEmpty else { return nil }
        if let hand = curated[code] { return hand }
        if let common = organizations[code] { return common }
        if let direct = match(code, names: names) { return direct }

        let tokens = code.replacingOccurrences(of: "-", with: " ")
            .split(separator: " ").map(String.init)

        // A COMPASS QUALIFIER beside a name: `VIET S` and `S VIET` are the same country.
        let qualifiers = tokens.filter { directions[$0] != nil }
        let rest = tokens.filter { directions[$0] == nil }
        if let qualifier = qualifiers.first, !rest.isEmpty,
           let base = match(rest.joined(separator: " "), names: names),
           let word = directions[qualifier] {
            return "\(base), \(word)"
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
            if halves.count == 2,
               let a = resolveHalf(halves[0], names: names, organizations: organizations),
               let b = resolveHalf(halves[1], names: names, organizations: organizations),
               a != b {
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
                guard left.count >= 2, right.count >= 2 else { continue }
                if let a = resolveHalf(left, names: names, organizations: organizations),
                   let b = resolveHalf(right, names: names, organizations: organizations),
                   a != b {
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

    /// One half of a paired tail, which may itself carry a compass qualifier.
    ///
    /// - Parameters:
    ///   - half: The half's tokens, space-joined.
    ///   - names: The name list.
    ///   - organizations: Common abbreviations.
    /// - Returns: The name, or `nil`.
    static func resolveHalf(_ half: String, names: [String],
                            organizations: [String: String]) -> String? {
        if let common = organizations[half] { return common }
        if let direct = match(half, names: names) { return direct }
        let tokens = half.split(separator: " ").map(String.init)
        let qualifiers = tokens.filter { directions[$0] != nil }
        let rest = tokens.filter { directions[$0] == nil }
        guard let qualifier = qualifiers.first, !rest.isEmpty,
              let base = match(rest.joined(separator: " "), names: names),
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
        for name in names {
            if fullyCovers(name, tokens) || initials(of: name) == flat {
                candidates.insert(name)
            } else if flat.count >= 3,
                      words(of: name).joined().hasPrefix(flat) {
                // "the first few letters of the name" taken across the whole name, which is how
                // `SAUD` reaches *Saudi Arabia* and `CAMB` reaches *Cambodia*.
                candidates.insert(name)
            }
        }
        let ranked = candidates.sorted { $0.count == $1.count ? $0 < $1 : $0.count < $1.count }
        guard let first = ranked.first else { return nil }
        if ranked.count > 1, ranked[1].count == first.count { return nil }
        return first
    }
}
