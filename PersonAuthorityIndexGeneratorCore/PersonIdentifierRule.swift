// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - PersonIdentifierRule

/// When an overlay entry's Wikidata or VIAF id is stamped on a registry record (#1767, item 1): only
/// when its item fits the record and something independent agrees. This is the identifier assessment's
/// rule (b4) (`Planning/Person-Authority-Identifier-Assessment-2026-10-17.md` §7.1), ported test for test
/// from the scripts that measured it.
///
/// ## Why there is one
/// Read back from Wikidata, about 1,600 of the 3,769 Wikidata ids the overlay gave the bundle named
/// someone else, and so did about 580 of the 2,186 of its VIAF ids that could be checked: name-only
/// matches no life year contradicts (Senator Paul M. Simon wore the singer-songwriter), relatives
/// (Herbert Hoover Jr. wore his father), and items that are not people (Leonid Brezhnev wore the
/// aircraft carrier *Admiral Kuznetsov*). Decision 55 took none of them for build 51; this rule takes
/// back those it can corroborate, which the assessment measured at about 96% right for Wikidata and 97%
/// for VIAF, against 57% and 73% before.
///
/// ## A Wikidata id
/// The item, read from the ``WikidataSnapshot``, must pass every test, and at least one thing
/// independent of the overlay's match must agree with it. The tests:
/// - **hard**: the item is a person (`not-a-person`; a deleted id is `deleted`); a word of the record's
///   surname, or of an alternate name's, is in one of the item's names (`surname`); a birth or death
///   year within a year of the registry's (`birth-year`, `death-year`); born at least 15 years before
///   the record's first FRUS volume (`too-young`), and dead no more than 40 years before it
///   (`died-long-before`);
/// - **soft**: the record's first given name, or a nickname of it, opens one of the item's names, and a
///   second given name or initial the two both spell agrees (`given-name`); and the VIAF id the record
///   would carry, when an item holds it, is held by this one (`viaf-held-by-other-item`).
///
/// What agrees: the registry's life years (a birth or death year within one of the item's), the VIAF id
/// the record would carry, held by the item, or a word of the record's own registry remarks in the item's
/// description, positions, occupations or employers (four letters or more, not a stopword, a nationality
/// or the record's surname). A country is a role word: left out with the nationalities, it took 17 right
/// ids off the bundle to take 2 wrong ones (#1767's follow-up, measured 2026-11-01).
///
/// ## A VIAF id
/// Kept when the item the record carries, or is about to, holds it; or when an item that holds it passes
/// every test against the record and the registry's years or a role word agree with it. Holding the VIAF
/// id itself is no corroboration there, since every holder holds it. A VIAF id no item holds is never
/// kept: nothing can corroborate it (the assessment's 824).
///
/// ## What it cannot see
/// Two relatives of one name and era: Truman's nephew keeps the President's item through the word
/// *President* in his own remark. And an overlay that took both ids from one wrong item: the two then
/// agree with each other.
///
/// Version history:
///   1.0 — #1767 lane B: initial implementation, from the assessment's `classify.py`, `overlap.py` and
///         `simulate.py` (option "W-corroborated+role+V-holder")
public struct PersonIdentifierRule: Sendable {

    /// The facts every test reads.
    public let snapshot: WikidataSnapshot

    /// Creates the rule over `snapshot`.
    public init(snapshot: WikidataSnapshot) {
        self.snapshot = snapshot
    }

    // MARK: - The record

    /// What a test reads of the registry record an id would be stamped on.
    public struct Record: Sendable, Equatable {
        /// The registry's preferred name, "Surname, Given".
        public let name: String
        /// The registry's birth year, if it has one.
        public let birthYear: Int?
        /// The registry's death year, if it has one.
        public let deathYear: Int?
        /// The registry's alternate names, whose surnames the surname test also accepts.
        public let alternateNames: [String]
        /// The registry's remarks, the record's own role words.
        public let remarks: [String]
        /// The year of the record's earliest FRUS volume in the registry, the era the item is tested against.
        public let firstVolumeYear: Int?

        /// Creates a record.
        public init(name: String, birthYear: Int?, deathYear: Int?, alternateNames: [String] = [],
                    remarks: [String] = [], firstVolumeYear: Int?) {
            self.name = name
            self.birthYear = birthYear
            self.deathYear = deathYear
            self.alternateNames = alternateNames
            self.remarks = remarks
            self.firstVolumeYear = firstVolumeYear
        }

        /// The record as the bundle has it, with what the registry says beyond the bundle.
        init(entry: AuthorityEntry, facts: RegistryFacts?) {
            self.init(name: entry.n, birthYear: entry.b, deathYear: entry.d,
                      alternateNames: facts?.alternateNames ?? [], remarks: facts?.remarks ?? [],
                      firstVolumeYear: facts?.firstVolumeYear)
        }
    }

    // MARK: - The tests

    /// A test an item fails, named as the assessment's reads name it.
    public enum Failure: String, Sendable, Equatable {
        case deleted
        case notAPerson = "not-a-person"
        case surname
        case birthYear = "birth-year"
        case deathYear = "death-year"
        case tooYoung = "too-young"
        case diedLongBefore = "died-long-before"
        case givenName = "given-name"
        case viafHeldByAnotherItem = "viaf-held-by-other-item"
    }

    /// What one item's tests found against one record.
    public struct Verdict: Sendable, Equatable {
        /// Tests that rule the item out.
        public var hard: [Failure] = []
        /// Tests that rule it out unless the reading is wrong; the rule takes neither.
        public var soft: [Failure] = []
        /// A birth or death year of the item is within a year of the registry's.
        public var registryYearsAgree = false
        /// The item holds the VIAF id the record would carry.
        public var holdsRecordVIAF = false

        /// No test failed.
        public var passes: Bool { hard.isEmpty && soft.isEmpty }
    }

    /// Whether an id is stamped, and why not when it is not.
    public struct Decision: Sendable, Equatable {
        /// The id is stamped.
        public let accepted: Bool
        /// What decided it: the agreement that kept it, or the tests that failed.
        public let reason: String
    }

    /// The item `itemId`, tested against `record`.
    ///
    /// - Parameter recordVIAF: The VIAF id the record would carry (its own, else the entry's), whose
    ///   holders the item is compared with; `nil` to compare none.
    public func test(_ itemId: String, against record: Record, recordVIAF: String?) -> Verdict {
        var verdict = Verdict()
        guard let item = snapshot.items[itemId], !item.missing else {
            verdict.hard = [.deleted]
            return verdict
        }
        if !item.human { verdict.hard.append(.notAPerson) }
        let names = Self.nameTests(record: record, names: item.names)
        if !names.surnameFits { verdict.hard.append(.surname) }
        if names.givenConflict { verdict.soft.append(.givenName) }
        verdict.hard += Self.yearTests(record: record, births: item.born, deaths: item.died)
        verdict.registryYearsAgree = Self.within(record.birthYear, item.born)
            || Self.within(record.deathYear, item.died)
        if let recordVIAF {
            if item.viaf.contains(recordVIAF) {
                verdict.holdsRecordVIAF = true
            } else {
                let holders = snapshot.allHolders(of: recordVIAF)
                if !holders.isEmpty {
                    if holders.contains(canonical(itemId)) {
                        verdict.holdsRecordVIAF = true
                    } else {
                        verdict.soft.append(.viafHeldByAnotherItem)
                    }
                }
            }
        }
        return verdict
    }

    /// The words of `record`'s remarks found in the item's description, positions, occupations and
    /// employers: four letters or more, none a stopword, a nationality or a word of the record's surname.
    public func roleWords(of record: Record, in itemId: String) -> Set<String> {
        guard let item = snapshot.items[itemId] else { return [] }
        let itemWords = Self.roleTokens([item.description ?? ""] + item.roles)
        return Self.roleTokens(record.remarks).intersection(itemWords)
            .subtracting(AuthorityText.words(AuthorityText.surname(of: record.name)))
    }

    // MARK: - The decisions

    /// Whether an entry's Wikidata id `q` is stamped on `record`: no test fails, and the registry's years,
    /// the VIAF id the record would carry, or a role word agrees.
    public func decideWikidata(_ q: String, for record: Record, recordVIAF: String?) -> Decision {
        let verdict = test(q, against: record, recordVIAF: recordVIAF)
        guard verdict.passes else {
            return Decision(accepted: false, reason: Self.describe(verdict))
        }
        if verdict.registryYearsAgree { return Decision(accepted: true, reason: "registry-years-agree") }
        if verdict.holdsRecordVIAF { return Decision(accepted: true, reason: "item-holds-record-viaf") }
        let words = roleWords(of: record, in: q)
        if !words.isEmpty { return Decision(accepted: true, reason: "role words " + words.sorted().joined(separator: ",")) }
        return Decision(accepted: false, reason: "uncorroborated")
    }

    /// Whether an entry's VIAF id `viaf` is stamped on `record`: the item the record carries or is about to
    /// (`acceptedItem`) holds it, or an item that holds it fits the record and the registry's years or a role
    /// word agree with it.
    public func decideVIAF(_ viaf: String, for record: Record, acceptedItem: String?) -> Decision {
        let live = snapshot.holders(of: viaf)
        // Holders at a deprecated rank count for agreement only when no other item holds it.
        let agreeing = live.isEmpty ? (snapshot.viafDeprecatedHolders[viaf] ?? []) : live
        if let acceptedItem, agreeing.contains(canonical(acceptedItem)) {
            return Decision(accepted: true, reason: "held by \(acceptedItem)")
        }
        var refused: [String] = []
        for holder in live.sorted(by: Self.itemOrder) {
            let verdict = test(holder, against: record, recordVIAF: nil)
            if verdict.passes {
                if verdict.registryYearsAgree {
                    return Decision(accepted: true, reason: "held by \(holder): registry-years-agree")
                }
                let words = roleWords(of: record, in: holder)
                if !words.isEmpty {
                    return Decision(accepted: true,
                                    reason: "held by \(holder): role words " + words.sorted().joined(separator: ","))
                }
                refused.append("\(holder) uncorroborated")
            } else {
                refused.append("\(holder) \(Self.describe(verdict))")
            }
        }
        if live.isEmpty {
            return Decision(accepted: false, reason: agreeing.isEmpty ? "held by no item" : "held at a deprecated rank only")
        }
        return Decision(accepted: false, reason: "held by " + refused.joined(separator: "; "))
    }

    // MARK: - Helpers

    /// The id an item answers to, through a redirect.
    private func canonical(_ itemId: String) -> String {
        snapshot.items[itemId]?.redirect ?? itemId
    }

    private static func describe(_ verdict: Verdict) -> String {
        (verdict.hard.map(\.rawValue) + verdict.soft.map(\.rawValue)).joined(separator: ",")
    }

    /// Q2 before Q10.
    private static func itemOrder(_ a: String, _ b: String) -> Bool {
        (Int(a.dropFirst()) ?? 0, a) < (Int(b.dropFirst()) ?? 0, b)
    }

    /// A year of `years` within one of `year`, when the registry has one.
    private static func within(_ year: Int?, _ years: [Int]) -> Bool {
        guard let year, year != 0, let nearest = years.map({ abs(year - $0) }).min() else { return false }
        return nearest <= 1
    }

    /// The surname test and the given-name test over every name an item offers.
    static func nameTests(record: Record, names: [String]) -> (surnameFits: Bool, givenConflict: Bool) {
        let surnameWords = surnameWords(of: record)
        let nameWords = Set(names.flatMap(AuthorityText.words))
        let surnameFits = surnameWords.isEmpty || !surnameWords.isDisjoint(with: nameWords)
        let given = givenWords(AuthorityText.given(of: record.name))
        guard let first = given.first, !names.isEmpty else { return (surnameFits, false) }
        var best: Bool?
        for name in names {
            let tokens = givenWords(name).filter { !surnameWords.contains($0) }
            guard let opening = tokens.first else { continue }
            var fits = nicknameFits(first, opening) || tokens.dropFirst().prefix(1).contains { nicknameFits(first, $0) }
            // A second given name or initial, compared only when both sides spell one.
            if fits, given.count > 1, tokens.count > 1, let initial = given[1].first,
               tokens[1].first != initial, !tokens.dropFirst().contains(where: { $0.first == initial }) {
                fits = false
            }
            best = (best ?? false) || fits
        }
        return (surnameFits, best == false)
    }

    /// The year tests: a life year more than a year from the registry's, or an item too young for, or
    /// dead too long before, the record's first FRUS volume.
    static func yearTests(record: Record, births: [Int], deaths: [Int]) -> [Failure] {
        var hard: [Failure] = []
        if let year = record.birthYear, year != 0, let nearest = births.map({ abs(year - $0) }).min(), nearest > 1 {
            hard.append(.birthYear)
        }
        if let year = record.deathYear, year != 0, let nearest = deaths.map({ abs(year - $0) }).min(), nearest > 1 {
            hard.append(.deathYear)
        }
        if let first = record.firstVolumeYear {
            if let born = births.first, first - born < 15 { hard.append(.tooYoung) }
            if let died = deaths.first, first - died > 40 { hard.append(.diedLongBefore) }
        }
        return hard
    }

    /// The words of the record's surname and of its alternate names' surnames, particles and single
    /// letters aside.
    static func surnameWords(of record: Record) -> Set<String> {
        let surnames = [AuthorityText.surname(of: record.name)] + record.alternateNames.map(AuthorityText.surname(of:))
        return Set(surnames.flatMap(AuthorityText.words).filter { !particles.contains($0) && $0.count > 1 })
    }

    /// The words of a name, honorifics aside.
    static func givenWords(_ text: String) -> [String] {
        AuthorityText.words(text).filter { !honorifics.contains($0) }
    }

    /// One given name fits another: the same, one a prefix of the other, or a listed nickname.
    static func nicknameFits(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b) || b.hasPrefix(a)
            || nicknames[a]?.contains(b) == true || nicknames[b]?.contains(a) == true
    }

    /// The role words of `texts`.
    static func roleTokens(_ texts: [String]) -> Set<String> {
        Set(texts.flatMap(AuthorityText.words).filter {
            $0.count >= 4 && !stopWords.contains($0) && !nationalities.contains($0) && !$0.allSatisfy(\.isASCIIDigit)
        })
    }

    // MARK: - Word lists
    //
    // Part of the rule: a change to one changes the bundle, and is measured against the control.

    static let particles: Set<String> = ["de", "da", "del", "della", "der", "di", "du", "la", "le", "van",
                                         "von", "y", "e", "al", "el", "ben", "bin", "ibn", "abu", "st", "mac", "o"]

    static let honorifics: Set<String> = [
        "sir", "jr", "sr", "ii", "iii", "iv", "v", "dr", "mrs", "mr", "ms", "miss", "lord", "lady",
        "general", "gen", "admiral", "adm", "colonel", "col", "prince", "princess", "king", "queen",
        "sheikh", "shaikh", "emir", "amir", "pasha", "bey", "baron", "count", "rev", "father", "the",
        "senior", "junior", "hon", "madame", "mme", "senor", "don", "dona", "esq"]

    static let nicknames: [String: Set<String>] = [
        "richard": ["dick", "rick", "ricky", "dickie"], "william": ["bill", "billy", "will", "willie"],
        "robert": ["bob", "bobby", "rob", "bert"], "james": ["jim", "jimmy", "jamie"], "john": ["jack", "johnny"],
        "thomas": ["tom", "tommy"], "charles": ["chuck", "charlie", "chas"], "edward": ["ted", "ed", "eddie", "ned"],
        "joseph": ["joe"], "henry": ["hank", "harry"], "harold": ["harry", "hal"], "lawrence": ["larry"],
        "anthony": ["tony"], "francis": ["frank"], "frank": ["francis"], "gerald": ["jerry"],
        "daniel": ["dan"], "david": ["dave"], "donald": ["don"], "douglas": ["doug"], "frederick": ["fred"],
        "herbert": ["herb", "bert"], "leonard": ["len"], "michael": ["mike"], "nicholas": ["nick"],
        "peter": ["pete"], "raymond": ["ray"], "ronald": ["ron"], "samuel": ["sam"], "stephen": ["steve"],
        "steven": ["steve"], "theodore": ["ted", "teddy"], "walter": ["walt"], "zbigniew": ["zbig"],
        "alexander": ["alex"], "benjamin": ["ben"], "kenneth": ["ken"], "patrick": ["pat"], "philip": ["phil"],
        "eugene": ["gene"], "clifford": ["cliff"], "albert": ["al"], "alfred": ["al", "fred"], "allen": ["al"],
        "edmund": ["ed", "ted"], "elizabeth": ["betty", "liz", "beth"], "margaret": ["peggy", "meg"],
        "katherine": ["kay", "kate", "kathy"], "catherine": ["kay", "kate", "kathy"], "dwight": ["ike"]]

    static let stopWords: Set<String> = Set("""
        the and for from with until after before since into during under over between their his her was were \
        has have had this that also american united states state member members staff office department bureau \
        division section affairs assistant deputy special acting former senior chief head officer official \
        government national international general republic people peoples
        """.split(separator: " ").map(String.init))

    static let nationalities: Set<String> = Set("""
        american british french german soviet russian chinese japanese israeli egyptian iranian iraqi indian \
        pakistani italian spanish greek turkish polish hungarian vietnamese korean canadian australian mexican \
        brazilian argentine cuban belgian dutch swedish norwegian danish finnish swiss austrian czech czechoslovak \
        yugoslav romanian bulgarian portuguese irish scottish welsh english arab saudi jordanian syrian lebanese \
        libyan moroccan algerian tunisian ethiopian kenyan nigerian ghanaian chilean peruvian venezuelan colombian \
        bolivian panamanian philippine filipino indonesian thai cambodian laotian burmese taiwanese icelandic
        """.split(separator: " ").map(String.init))
}

// MARK: - AuthorityText

/// How the person authority compares names and texts: folded to unaccented lower case, and split into
/// words of the letters a to z and the digits.
///
/// A letter folding leaves outside a to z (ł, ø, đ, Cyrillic, Greek) divides words, as the assessment's
/// scripts divided them, and a German umlaut or ß is also read in its transliteration (ö as oe), so that
/// *Wörner* fits *Woerner*.
enum AuthorityText {

    /// `text` decomposed (NFKD), its combining marks dropped, lower-cased, with ’ as '.
    static func fold(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.decomposedStringWithCompatibilityMapping.unicodeScalars
        where scalar.properties.canonicalCombiningClass == .notReordered {
            scalars.append(scalar)
        }
        return String(scalars).lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }

    /// The folded words of `text`; where it holds a German umlaut, the words of its transliteration
    /// follow those not already among them.
    static func words(_ text: String) -> [String] {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\u{DF}": scalars.append(contentsOf: "ss".unicodeScalars)
            case "\u{1E9E}": scalars.append(contentsOf: "SS".unicodeScalars)
            default: scalars.append(scalar)
            }
        }
        let text = String(scalars)
        var out = split(fold(text))
        if text.unicodeScalars.contains(where: { umlauts[$0] != nil }) {
            var transliterated = String.UnicodeScalarView()
            for scalar in text.unicodeScalars {
                transliterated.append(contentsOf: umlauts[scalar]?.unicodeScalars ?? String(scalar).unicodeScalars)
            }
            for word in split(fold(String(transliterated))) where !out.contains(word) {
                out.append(word)
            }
        }
        return out
    }

    /// The registry's "Surname, Given" → "Surname"; a name with no comma → the whole name.
    static func surname(of name: String) -> String {
        guard let comma = name.firstIndex(of: ",") else { return name.trimmingCharacters(in: .whitespacesAndNewlines) }
        return name[..<comma].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The registry's "Surname, Given" → "Given"; a name with no comma → "".
    static func given(of name: String) -> String {
        guard let comma = name.firstIndex(of: ",") else { return "" }
        return name[name.index(after: comma)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let umlauts: [Unicode.Scalar: String] = [
        "\u{E4}": "ae", "\u{F6}": "oe", "\u{FC}": "ue", "\u{C4}": "Ae", "\u{D6}": "Oe", "\u{DC}": "Ue"]

    /// Runs of a to z and 0 to 9 in folded text.
    private static func split(_ folded: String) -> [String] {
        var words: [String] = []
        var current = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                current.append(scalar)
            } else if !current.isEmpty {
                words.append(String(current))
                current = String.UnicodeScalarView()
            }
        }
        if !current.isEmpty { words.append(String(current)) }
        return words
    }
}

private extension Character {
    /// 0 to 9.
    var isASCIIDigit: Bool { isASCII && isNumber }
}
