// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionIdentity

/// The level-1 authority identity of an archival citation — the fields that produce a
/// `collection-authority.json` merge key (`"lot:64D199"` /
/// `"txt:johnson library|national security file"`).
///
/// Produced by ``CollectionKeying/identity(of:note:)`` from a parsed source note; the
/// `CollectionAuthorityGenerator` derives its clustering keys through the **same**
/// function, so an app-side lookup agrees with the bundled artifact by construction.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): initial implementation
public struct CollectionIdentity: Sendable, Equatable {

    /// Canonical compact lot key (`"64D199"`) when the citation is lot-keyed.
    public let lotFileNorm: String?
    /// Canonical repository keyword (`"Johnson Library"`, `"Department of State"`),
    /// or `nil` when the citation names no repository.
    public let repository: String?
    /// The leading citation segment (`"National Security File"`) for textual identities;
    /// `nil` for lot-keyed identities (the lot alone is the identity).
    public let leadingSegment: String?
    /// The canonical decimal / subject-numeric class key carried by the citation
    /// (`"POL 27 ARAB-ISR"`), when one exists — a level-2 hint, not part of the key.
    public let decimalClass: String?

    /// Memberwise initializer.
    public init(lotFileNorm: String? = nil, repository: String? = nil,
                leadingSegment: String? = nil, decimalClass: String? = nil) {
        self.lotFileNorm = lotFileNorm
        self.repository = repository
        self.leadingSegment = leadingSegment
        self.decimalClass = decimalClass
    }

    /// The level-1 merge key this identity clusters under, or `nil` when the identity
    /// carries neither a lot nor a leading segment.
    public var key: String? {
        CollectionKeying.level1Key(lotFileNorm: lotFileNorm, repository: repository,
                                   leadingSegment: leadingSegment)
    }
}

// MARK: - CollectionKeying

/// The shared collection-authority keying rules: the normal form, repository
/// canonicalization, citation-segment tokenization and gating, and the per-provenance
/// level-1 identity derivation.
///
/// **Single source of truth** for both sides of the authority join: the
/// `CollectionAuthorityGenerator`'s `ReferenceBuilder` clusters corpus references
/// through these functions, and the app's `CollectionAuthorityStore` computes lookup
/// keys through the same functions — so a runtime citation lands on the artifact record
/// its corpus siblings were merged into, with no variant fan-out.
///
/// Ports the *idea* of the frus-sources `merge.xq` reconciliation model: a citation
/// sentence tokenizes on `", "` into ordered segments; the leading segment under the
/// repository is the collection. Segments that are locators (boxes, folders, reels,
/// quoted folder titles, file identifiers) never become authority keys.
///
/// Version history:
///   1.0 — Session 2026-07-03 (Source Explorer Phase 4 step 2): extracted from the
///          generator's `ReferenceBuilder` (grammar unchanged) so the app-side
///          authority lookups share every key-producing rule
public enum CollectionKeying {

    // MARK: - Normal form

    /// Normal form for merge keys: lowercased, whitespace collapsed, Unicode dashes →
    /// ASCII hyphen with adjacent spaces removed (`"1967- 69"` ≡ `"1967–69"`), trailing
    /// `.`/`,`/`;`/`:` stripped. Applied to repository names and citation segments;
    /// **merging requires equality of this form** (conservative).
    public static func normalized(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
            .replacingOccurrences(of: " -", with: "-")
            .replacingOccurrences(of: "- ", with: "-")
        while let last = s.last, ".,;:".contains(last) { s = String(s.dropLast()) }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// The level-1 merge key for an identity's fields, or `nil` when neither a lot nor
    /// a leading segment exists (`"lot:64D199"` / `"txt:<repoNorm>|<segmentNorm>"`).
    public static func level1Key(lotFileNorm: String?, repository: String?,
                                 leadingSegment: String?) -> String? {
        if let lot = lotFileNorm { return "lot:" + lot }
        guard let segment = leadingSegment else { return nil }
        return "txt:" + normalized(repository ?? "") + "|" + normalized(segment)
    }

    // MARK: - Repository canonicalization

    /// Repository keywords in match-priority order — shared by the app's front-matter
    /// delegate, the generator's extractor, and the authority lookups, so repository
    /// identity matches across all three.
    public static let repositoryKeywords = [
        "National Archives", "Library of Congress", "Washington National Records Center",
        "Kennedy Library", "Johnson Library", "Nixon", "Ford Library", "Carter Library",
        "Reagan Library", "Bush Library", "Clinton Library", "Eisenhower Library",
        "Truman Library", "Roosevelt Library", "Hoover Institution",
        "Central Intelligence Agency", "Department of State",
        "Department of Defense", "Naval Historical", "Center of Military History",
    ]

    /// Presidential surnames whose libraries FRUS cites with full names
    /// (`"Lyndon B. Johnson Library"`, `"Gerald R. Ford Presidential Library"`).
    private static let presidentialSurnames = [
        "Roosevelt", "Truman", "Eisenhower", "Kennedy", "Johnson", "Nixon",
        "Ford", "Carter", "Reagan", "Bush", "Clinton",
    ]

    /// Canonical repository keyword for any repository string: the first keyword of
    /// ``repositoryKeywords`` the string contains; else, for a presidential-library
    /// full name (`"Gerald R. Ford Presidential Library"`), the keyword form of its
    /// surname (`"Ford Library"`; `"Nixon"` matches the app's bare keyword); else the
    /// trimmed string itself. Bridges doc-note and heading library-name variants to
    /// one repository bucket.
    public static func canonicalRepository(_ repository: String?) -> String? {
        guard let repository else { return nil }
        let trimmed = repository.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        for keyword in repositoryKeywords
        where trimmed.range(of: keyword, options: .caseInsensitive) != nil {
            return keyword
        }
        if trimmed.range(of: "Librar", options: .caseInsensitive) != nil {
            for surname in presidentialSurnames
            where trimmed.range(of: surname, options: .caseInsensitive) != nil {
                return surname == "Nixon" ? "Nixon" : "\(surname) Library"
            }
        }
        return trimmed
    }

    // MARK: - Segment tokenization & gating

    /// Tokenizes a citation sentence on `", "` into trimmed segments (the `merge.xq`
    /// segment model over the class-scan citation sentence).
    public static func segments(ofCitation text: String) -> [String] {
        SourceNoteParser.citationSentence(of: text)
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Locator lead words: a segment starting with one of these is a box/folder-level
    /// locator, never a collection or sub-series name.
    private static let locatorLeads = [
        "box", "boxes", "folder", "entry", "reel", "roll", "tab", "vol", "volume",
        "file no", "frc", "job", "lot", "lots", "rg", "record group", "microfilm",
        "accession", "drawer", "tape", "conversation no", "item",
    ]

    /// Whether `segment` is a plausible collection / sub-series name: leads with an
    /// uppercase letter, contains a letter, is 4–80 characters, is not quoted (quoted
    /// segments are folder titles), is not a locator, is not a bare class key (classes
    /// are level-2 identities via `decimalClassKey`, not series names), and contains no
    /// `/` (file identifiers).
    public static func isSeriesSegment(_ segment: String) -> Bool {
        let s = segment.trimmingCharacters(in: .whitespaces)
        guard s.count >= 4, s.count <= 80 else { return false }
        guard let first = s.first, first.isUppercase, first.isLetter else { return false }
        guard !s.contains("/") else { return false }
        guard s.first != "\"", s.first != "“", s.first != "‘", s.first != "'" else { return false }
        let lower = s.lowercased()
        for lead in locatorLeads {
            if lower == lead { return false }
            if lower.hasPrefix(lead) {
                // Word-bounded: "Box 12" is a locator, "Boxer Rebellion File" is not.
                let next = lower[lower.index(lower.startIndex, offsetBy: lead.count)...].first
                if next == nil || next == " " || next == "." || next == ":" || next == "#" {
                    return false
                }
            }
        }
        guard SourceNoteParser.decimalClassKey(s) == nil else { return false }
        return true
    }

    /// Generic first segments too broad to merge on alone: a reference whose leading
    /// segment normalizes to one of these keeps its **full text** as the merge key
    /// (no cross-variant merging — conservative rather than over-merged).
    private static let genericLeads: Set<String> = [
        "records", "papers", "files", "general records", "miscellaneous records",
        "subject files", "country files", "memoranda", "correspondence", "documents",
    ]

    /// The level-1 merge segment for a front-matter item text or citation: the first
    /// `", "` segment when it is distinctive, else the whole text (see `genericLeads`).
    /// A prose-ish lead is additionally cut at its first sentence boundary (`". "`)
    /// when the cut still passes the gate (`"Central Files. During the 1964–1968
    /// period…"` → `"Central Files"`; dotted forms like `"U.S. Delegation Files"`
    /// fail the cut's gate and keep the uncut segment).
    public static func leadingMergeSegment(of text: String) -> String? {
        var first = text.components(separatedBy: ", ")
            .first?.trimmingCharacters(in: .whitespaces) ?? text
        if let dot = first.range(of: ". ") {
            let cut = String(first[..<dot.lowerBound]).trimmingCharacters(in: .whitespaces)
            if isSeriesSegment(cut) { first = cut }
        }
        guard isSeriesSegment(first) else { return nil }
        if genericLeads.contains(normalized(first)) {
            return text.trimmingCharacters(in: .whitespaces)
        }
        return first
    }

    // MARK: - Central-files override

    /// Central-files leading prefixes (normalized). A collection whose leading segment
    /// starts with one of these is the State Department central files regardless of the
    /// holding-institution phrasing around it — doc notes attribute them to
    /// `"Department of State"` (the pipeline's `.centralFiles` convention) while front
    /// matter nests them under a National Archives heading, and without this override
    /// the same file series splits across two repository buckets.
    private static let centralFilesLeads = [
        "central files", "central foreign policy", "central decimal file",
        "decimal central files", "subject-numeric indexed central files",
        "decimal and subject-numeric indexed central files", "indexed central files",
        "subject-numeric central files",
    ]

    /// Whether `segment` names the State Department central files (see
    /// `centralFilesLeads`). `"White House Central Files"` (a library collection)
    /// does not lead with the phrase and is not overridden.
    public static func isCentralFilesSegment(_ segment: String) -> Bool {
        let norm = normalized(segment)
        return centralFilesLeads.contains { norm.hasPrefix($0) }
    }

    /// The citation-sentence segment naming the central files (`"Central Files
    /// 1967–69"`, `"Central Foreign Policy File"`), or `nil` for bare decimal notes.
    public static func centralFilesAnchorSegment(in note: String) -> String? {
        for segment in segments(ofCitation: note) {
            let lower = segment.lowercased()
            if lower.contains("central files") || lower.contains("central foreign policy") {
                // Trim a trailing colon-attached class ("Central Files 1967-69: POL…").
                let lead = segment.components(separatedBy: ":").first?
                    .trimmingCharacters(in: .whitespaces) ?? segment
                return isSeriesSegment(lead) ? lead : nil
            }
        }
        return nil
    }

    /// The `decimal_class` derivation for a parsed note — the pipeline's
    /// `decimalClassColumn` gating verbatim.
    public static func centralFilesClass(parsed: ParsedSourceNote, note: String) -> String? {
        switch parsed {
        case .centralFiles, .cfpfFile:
            return SourceNoteParser.decimalClassLocation(inCitation: note)
        case .naraCollection(_, let series, _, _):
            guard let series,
                  series.range(of: "Central Files", options: .caseInsensitive) != nil
                    || series.range(of: "Central Foreign Policy", options: .caseInsensitive) != nil
            else { return nil }
            return SourceNoteParser.decimalClassLocation(inCitation: note)
        default:
            return nil
        }
    }

    /// Strips the `RG-` prefix the parser writes (`"RG-59"` → `"59"`), matching the
    /// bare record-group numbers front matter stores.
    public static func bareRG(_ rg: String?) -> String? {
        guard let rg else { return nil }
        let bare = rg.replacingOccurrences(of: #"^RG[\s\-]*"#, with: "",
                                           options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        return bare.isEmpty ? nil : bare
    }

    // MARK: - Level-1 identity of a front-matter row

    /// Derives the level-1 authority identity of a volume front-matter Sources item —
    /// the exact derivation the generator's `ReferenceBuilder.textualLevel1` clusters
    /// by (colon-split class leaves, the bare-class-leaf refusal, the central-files
    /// repository override), so a `volume_sources` row looks up the artifact record its
    /// corpus siblings merged into.
    ///
    /// - Parameters:
    ///   - text: The item's full display text (`entry_text`).
    ///   - repository: The row's repository (own or inherited), raw or canonical.
    ///   - lotFileNorm: The row's canonical compact lot key, when lot-keyed.
    ///   - decimalClass: The row's canonical class key, when it is a class leaf.
    /// - Returns: The identity, or `nil` when the row is not clusterable (a bare class
    ///   leaf with no enclosing collection, or a lead that fails the segment gate).
    public static func frontMatterIdentity(text: String, repository: String?,
                                           lotFileNorm: String?,
                                           decimalClass: String?) -> CollectionIdentity? {
        if let lotFileNorm {
            return CollectionIdentity(lotFileNorm: lotFileNorm,
                                      repository: canonicalRepository(repository))
        }
        var leadText = text
        var classChild: String? = nil
        if let cls = decimalClass {
            if let colon = text.firstIndex(of: ":") {
                leadText = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
                classChild = cls
            } else if SourceNoteParser.decimalClassKey(text) != nil
                        || text.components(separatedBy: ",").first
                            .map({ SourceNoteParser.decimalClassKey($0) != nil }) == true {
                // A bare class leaf with no enclosing collection — not clusterable
                // at level 1 (conservative).
                return nil
            }
        }
        guard let segment = leadingMergeSegment(of: leadText) else { return nil }
        // Central-files override — see `isCentralFilesSegment`.
        let repo = isCentralFilesSegment(segment)
            ? "Department of State" : canonicalRepository(repository)
        return CollectionIdentity(repository: repo, leadingSegment: segment,
                                  decimalClass: classChild)
    }

    // MARK: - Level-1 identity of a parsed note

    /// Derives the level-1 authority identity of a parsed document source note — the
    /// exact derivation the generator's `ReferenceBuilder.reference(volumeId:note:parsed:)`
    /// clusters by, so app-side lookups and artifact keys agree by construction.
    ///
    /// Returns `nil` when the note carries no clusterable collection identity (foreign
    /// archives, previously-published citations, unrecognized notes, bare decimal notes
    /// with no central-files anchor segment, and series names that fail the segment gate).
    public static func identity(of parsed: ParsedSourceNote, note: String) -> CollectionIdentity? {
        switch parsed {
        case .lotFile(_, let lot, _):
            return CollectionIdentity(lotFileNorm: SourceNoteParser.lotFileNorm(lot),
                                      repository: "Department of State")
        case .naraCollection(_, let series, let lot, _):
            if let lot {
                return CollectionIdentity(lotFileNorm: SourceNoteParser.lotFileNorm(lot),
                                          repository: "Department of State")
            }
            let cls = centralFilesClass(parsed: parsed, note: note)
            guard let series, let segment = leadingMergeSegment(of: series) else { return nil }
            // Central-files override — see `isCentralFilesSegment`.
            let repo = isCentralFilesSegment(segment) ? "Department of State" : "National Archives"
            return CollectionIdentity(repository: repo, leadingSegment: segment,
                                      decimalClass: cls)
        case .presidentialLibrary(let library, let collection, _):
            guard let repo = canonicalRepository(library),
                  let segment = leadingMergeSegment(of: collection) else { return nil }
            return CollectionIdentity(repository: repo, leadingSegment: segment)
        case .centralFiles, .cfpfFile:
            guard let cls = centralFilesClass(parsed: parsed, note: note) else { return nil }
            // The anchor segment naming the central files is the level-1 collection;
            // a bare decimal note has none and is not clusterable (conservative).
            guard let anchor = centralFilesAnchorSegment(in: note) else { return nil }
            return CollectionIdentity(repository: "Department of State",
                                      leadingSegment: anchor, decimalClass: cls)
        case .namedFileSeries(let series, _):
            guard let segment = leadingMergeSegment(of: series) else { return nil }
            return CollectionIdentity(leadingSegment: segment)
        case .ciaCollection:
            let segs = segments(ofCitation: note)
            guard let anchorIdx = segs.firstIndex(where: {
                $0.range(of: "Central Intelligence Agency", options: .caseInsensitive) != nil
                    || $0.range(of: #"^(?:Source:\s*)?CIA\b"#, options: .regularExpression) != nil
            }) else { return nil }
            guard let segment = segs.dropFirst(anchorIdx + 1).first(where: isSeriesSegment)
            else { return nil }
            return CollectionIdentity(repository: "Central Intelligence Agency",
                                      leadingSegment: segment)
        default:
            return nil
        }
    }
}
