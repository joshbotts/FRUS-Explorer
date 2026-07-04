// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SourceNoteKit

/// Turns extracted rows (front-matter Sources items and parsed document source notes)
/// into `CollectionReference`s — the two-level clustering input.
///
/// Ports the *idea* of the frus-sources `merge.xq` reconciliation model at two-level
/// depth (owner decision S4): a citation sentence tokenizes on `", "` into ordered
/// segments; the leading segment under the repository is the collection (level 1); the
/// next segment is the sub-series (level 2). Segments that are locators (boxes,
/// folders, reels, quoted folder titles, file identifiers) never become authority keys.
public enum ReferenceBuilder {

    // MARK: - Normalization

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

    /// Presidential surnames whose libraries FRUS cites with full names
    /// (`"Lyndon B. Johnson Library"`, `"Gerald R. Ford Presidential Library"`).
    private static let presidentialSurnames = [
        "Roosevelt", "Truman", "Eisenhower", "Kennedy", "Johnson", "Nixon",
        "Ford", "Carter", "Reagan", "Bush", "Clinton",
    ]

    /// Canonical repository keyword for any repository string: the first keyword of the
    /// shared front-matter list (`FrontMatterSourcesExtractor.repoKeywords`) the string
    /// contains; else, for a presidential-library full name (`"Gerald R. Ford
    /// Presidential Library"`), the keyword form of its surname (`"Ford Library"`;
    /// `"Nixon"` matches the app's bare keyword); else the trimmed string itself.
    /// Bridges doc-note and heading library-name variants to one repository bucket.
    public static func canonicalRepository(_ repository: String?) -> String? {
        guard let repository else { return nil }
        let trimmed = repository.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        for keyword in FrontMatterSourcesExtractor.repoKeywords
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

    /// Generic grouping headings that must not become collections of their own
    /// (`"Lot Files"` under an RG heading groups the real lot collections below it).
    private static let groupingDenylist: Set<String> = [
        "lot files", "lot file", "other lot files", "office files", "miscellaneous files",
        "unpublished sources", "published sources", "archival sources", "archives",
    ]

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

    // MARK: - Front-matter outline → references

    /// A node of the rebuilt front-matter outline (structure only).
    struct OutlineNode {
        let row: FrontSourceRow
        var children: [OutlineNode]
    }

    /// Rebuilds the outline tree from flat pre-ordered item rows (gap-tolerant, the
    /// same clamping walk as `VolumeSourcesIndexRunner.buildTree`).
    static func buildTree(_ items: [FrontSourceRow], _ index: inout Int, depth: Int) -> [OutlineNode] {
        var nodes: [OutlineNode] = []
        while index < items.count {
            let item = items[index]
            if item.depth < depth { break }
            index += 1
            let children = buildTree(items, &index, depth: item.depth + 1)
            nodes.append(OutlineNode(row: item, children: children))
        }
        return nodes
    }

    /// Whether an outline node is **structural** — a repository / record-group heading
    /// or a generic grouping — that scopes its children but is not a collection itself.
    /// A heading is a repository heading when its *first comma segment* names a
    /// repository (`"Dwight D. Eisenhower Library, Abilene, Kansas"`); a collection
    /// that merely mentions one later (`"Ball Papers, Johnson Library"`) is not.
    static func isStructural(_ row: FrontSourceRow) -> Bool {
        guard row.lotFileNorm == nil else { return false }
        if FrontMatterSourcesExtractor.extractRecordGroup(from: row.text) != nil { return true }
        let first = row.text.components(separatedBy: ", ")
            .first?.trimmingCharacters(in: .whitespaces) ?? row.text
        for keyword in FrontMatterSourcesExtractor.repoKeywords
        where first.range(of: keyword, options: .caseInsensitive) != nil {
            return true
        }
        // Full-name presidential-library headings ("Lyndon B. Johnson Library").
        if first.range(of: "Librar", options: .caseInsensitive) != nil,
           canonicalRepository(first) != first {
            return true
        }
        return groupingDenylist.contains(normalized(row.text))
    }

    /// Converts one volume's front-matter rows into references (two-level outline walk).
    ///
    /// Rules:
    /// - lot-keyed items are **always level 1** (their outline children become level-2
    ///   sub-series);
    /// - structural nodes (repository / RG headings, generic groupings) pass through,
    ///   scoping their children without becoming collections;
    /// - the first non-structural, non-lot ancestor is level 1; its non-lot descendants
    ///   are level 2 (deeper levels fold into level 2's parent — S4 caps depth at two);
    /// - a class-leaf item under a level-1 collection is a level-2 class child; a
    ///   class-leaf item that *is* its own level 1 (`"Central Files 1967–69: POL 27
    ///   ARAB–ISR"`) splits on the colon — lead = collection, class = child.
    public static func references(volumeId: String,
                                  frontRows: [FrontSourceRow]) -> [CollectionReference] {
        let items = frontRows.filter { $0.kind == .item }
        var index = 0
        let tree = buildTree(items, &index, depth: 0)
        var refs: [CollectionReference] = []
        walk(tree, volumeId: volumeId, level1: nil, inheritedRepo: nil, refs: &refs)
        return refs
    }

    /// Context for the enclosing level-1 collection during the outline walk.
    private struct Level1Context {
        let repository: String?
        let recordGroup: String?
        let lotFileNorm: String?
        let rawLot: String?
        let leadingSegment: String?
        let displayName: String?
    }

    private static func walk(_ nodes: [OutlineNode], volumeId: String,
                             level1: Level1Context?, inheritedRepo: String?,
                             refs: inout [CollectionReference]) {
        for node in nodes {
            let row = node.row
            if isStructural(row) {
                // A repository heading scopes its children: bridge full-name library
                // headings the keyword extractor misses ("Lyndon B. Johnson Library").
                let headingRepo = canonicalRepository(row.repository)
                    ?? structuralRepository(of: row)
                walk(node.children, volumeId: volumeId, level1: level1,
                     inheritedRepo: headingRepo ?? inheritedRepo, refs: &refs)
                continue
            }
            let repo = canonicalRepository(row.repository) ?? inheritedRepo
            if let lotNorm = row.lotFileNorm {
                // Level 1: a lot-keyed collection. The full item text is the display
                // name; a distinctive series tail is an alias via the display name.
                let context = Level1Context(repository: repo, recordGroup: row.recordGroup,
                                            lotFileNorm: lotNorm, rawLot: row.lotFile,
                                            leadingSegment: nil, displayName: row.text)
                refs.append(CollectionReference(
                    volumeId: volumeId, origin: .frontMatter, repository: repo,
                    recordGroup: row.recordGroup, lotFileNorm: lotNorm, rawLot: row.lotFile,
                    seriesAlias: lotSeriesAlias(fromItemText: row.text),
                    displayName: row.text))
                walkSubs(node.children, volumeId: volumeId, level1: context,
                         inheritedRepo: repo ?? inheritedRepo, refs: &refs)
                continue
            }
            if let level1 {
                // Level 2 under an established collection.
                appendSubReference(row: row, volumeId: volumeId, level1: level1, refs: &refs)
                // Deeper levels fold into the same level-1 (S4: two levels).
                walkSubs(node.children, volumeId: volumeId, level1: level1,
                         inheritedRepo: repo ?? inheritedRepo, refs: &refs)
                continue
            }
            // Candidate level 1 (textual).
            if let context = textualLevel1(row: row, repo: repo, volumeId: volumeId, refs: &refs) {
                walkSubs(node.children, volumeId: volumeId, level1: context,
                         inheritedRepo: repo ?? inheritedRepo, refs: &refs)
            } else {
                // Not clusterable itself; children may still be (e.g. lots below).
                walk(node.children, volumeId: volumeId, level1: nil,
                     inheritedRepo: repo ?? inheritedRepo, refs: &refs)
            }
        }
    }

    /// The canonical repository a structural heading contributes to its children, when
    /// its first comma segment bridges to a keyword form (`"Gerald R. Ford Presidential
    /// Library"` → `"Ford Library"`), or `nil`.
    private static func structuralRepository(of row: FrontSourceRow) -> String? {
        let first = row.text.components(separatedBy: ", ")
            .first?.trimmingCharacters(in: .whitespaces) ?? row.text
        let canonical = canonicalRepository(first)
        return canonical == first ? nil : canonical
    }

    /// Walks descendants of an established level-1 collection: lot children become
    /// their own level-1 records; everything else is level 2 under `level1`.
    private static func walkSubs(_ nodes: [OutlineNode], volumeId: String,
                                 level1: Level1Context, inheritedRepo: String?,
                                 refs: inout [CollectionReference]) {
        for node in nodes {
            let row = node.row
            if row.lotFileNorm != nil || isStructural(row) {
                walk([node], volumeId: volumeId, level1: level1,
                     inheritedRepo: inheritedRepo, refs: &refs)
                continue
            }
            appendSubReference(row: row, volumeId: volumeId, level1: level1, refs: &refs)
            walkSubs(node.children, volumeId: volumeId, level1: level1,
                     inheritedRepo: inheritedRepo, refs: &refs)
        }
    }

    /// Emits a textual level-1 reference for `row`, returning the context for its
    /// children, or `nil` when the row is not clusterable. Handles the single-item
    /// `"Collection: CLASS"` shape by splitting on the colon.
    private static func textualLevel1(row: FrontSourceRow, repo: String?, volumeId: String,
                                      refs: inout [CollectionReference]) -> Level1Context? {
        var leadText = row.text
        var classChild: String? = nil
        if let cls = row.decimalClass {
            if let colon = row.text.firstIndex(of: ":") {
                leadText = String(row.text[..<colon]).trimmingCharacters(in: .whitespaces)
                classChild = cls
            } else if SourceNoteParser.decimalClassKey(row.text) != nil
                        || row.text.components(separatedBy: ",").first
                            .map({ SourceNoteParser.decimalClassKey($0) != nil }) == true {
                // A bare class leaf with no enclosing collection — not clusterable
                // at level 1 (conservative; logged as unclustered by the runner).
                return nil
            }
        }
        guard let segment = leadingMergeSegment(of: leadText) else { return nil }
        // Central-files override: the same file series must not split across the
        // National-Archives (front-matter heading) and Department-of-State (doc-note
        // convention) buckets.
        let central = isCentralFilesSegment(segment)
        let effectiveRepo = central ? "Department of State" : repo
        let effectiveRG = central ? (row.recordGroup ?? "59") : row.recordGroup
        let context = Level1Context(repository: effectiveRepo, recordGroup: effectiveRG,
                                    lotFileNorm: nil, rawLot: nil,
                                    leadingSegment: segment, displayName: leadText)
        refs.append(CollectionReference(
            volumeId: volumeId, origin: .frontMatter, repository: effectiveRepo,
            recordGroup: effectiveRG, leadingSegment: segment,
            subSegment: nil, subDecimalClass: classChild, displayName: leadText))
        return context
    }

    /// Emits a level-2 reference for `row` under `level1` (class key preferred, else a
    /// gated leading segment).
    private static func appendSubReference(row: FrontSourceRow, volumeId: String,
                                           level1: Level1Context,
                                           refs: inout [CollectionReference]) {
        let sub: String?
        if row.decimalClass != nil {
            sub = nil
        } else {
            sub = leadingMergeSegment(of: row.text)
            guard sub != nil else { return }
        }
        refs.append(CollectionReference(
            volumeId: volumeId, origin: .frontMatter, repository: level1.repository,
            recordGroup: level1.recordGroup ?? row.recordGroup,
            lotFileNorm: level1.lotFileNorm, rawLot: level1.rawLot,
            leadingSegment: level1.leadingSegment, subSegment: sub,
            subDecimalClass: row.decimalClass, displayName: level1.displayName))
    }

    /// A series alias embedded in a lot item's own text: the distinctive tail after the
    /// lot number (`"Lot 64 D 199, Records of the Policy Planning Staff"` →
    /// `"Records of the Policy Planning Staff"`), when it passes the segment gate.
    static func lotSeriesAlias(fromItemText text: String) -> String? {
        guard let (_, range) = SourceNoteParser.firstLotReference(in: text) else { return nil }
        let tail = String(text[range.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.;: ").union(.whitespaces))
        guard let segment = tail.components(separatedBy: ", ").first,
              isSeriesSegment(segment) else { return nil }
        return segment
    }

    // MARK: - Document source notes → references

    /// Converts one parsed document source note into a reference, mirroring the
    /// pipeline's `documentSourceRow` key derivations (same classifications, same
    /// class-column gating), then deriving the two-level segments from the citation
    /// sentence.
    public static func reference(volumeId: String, note: String,
                                 parsed: ParsedSourceNote) -> CollectionReference? {
        switch parsed {
        case .lotFile(let rg, let lot, _):
            return lotReference(volumeId: volumeId, note: note, rawLot: lot,
                                recordGroup: bareRG(rg))
        case .naraCollection(let rg, let series, let lot, _):
            if let lot {
                return lotReference(volumeId: volumeId, note: note, rawLot: lot,
                                    recordGroup: bareRG(rg))
            }
            let cls = centralFilesClass(parsed: parsed, note: note)
            guard let series, let segment = leadingMergeSegment(of: series) else { return nil }
            let segs = segments(ofCitation: note)
            let sub = cls == nil ? followingSegment(after: segment, in: segs) : nil
            // Central-files override — see `textualLevel1`.
            let repo = isCentralFilesSegment(segment) ? "Department of State" : "National Archives"
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: repo, recordGroup: bareRG(rg),
                                       leadingSegment: segment, subSegment: sub,
                                       subDecimalClass: cls)
        case .presidentialLibrary(let library, let collection, _):
            guard let repo = canonicalRepository(library),
                  let segment = leadingMergeSegment(of: collection) else { return nil }
            let segs = segments(ofCitation: note)
            let sub = followingSegment(after: segment, in: segs)
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: repo, recordGroup: nil,
                                       leadingSegment: segment, subSegment: sub)
        case .centralFiles, .cfpfFile:
            guard let cls = centralFilesClass(parsed: parsed, note: note) else { return nil }
            // The anchor segment naming the central files is the level-1 collection;
            // a bare decimal note has none and is not clusterable (conservative).
            guard let anchor = centralFilesAnchorSegment(in: note) else { return nil }
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: "Department of State", recordGroup: "59",
                                       leadingSegment: anchor, subDecimalClass: cls)
        case .namedFileSeries(let series, _):
            guard let segment = leadingMergeSegment(of: series) else { return nil }
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: nil, recordGroup: nil,
                                       leadingSegment: segment)
        case .ciaCollection:
            let segs = segments(ofCitation: note)
            guard let anchorIdx = segs.firstIndex(where: {
                $0.range(of: "Central Intelligence Agency", options: .caseInsensitive) != nil
                    || $0.range(of: #"^(?:Source:\s*)?CIA\b"#, options: .regularExpression) != nil
            }) else { return nil }
            guard let segment = segs.dropFirst(anchorIdx + 1).first(where: isSeriesSegment)
            else { return nil }
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: "Central Intelligence Agency",
                                       recordGroup: nil, leadingSegment: segment)
        default:
            return nil
        }
    }

    /// Builds a lot-keyed reference, harvesting the named-series segment that precedes
    /// the lot in the citation sentence as an alias (`"PPS Files: Lot 64 D 199"`,
    /// `"Secretary's Memoranda of Conversation, lot 64 D 199"`).
    private static func lotReference(volumeId: String, note: String, rawLot: String,
                                     recordGroup: String?) -> CollectionReference {
        var alias: String? = nil
        let sentence = SourceNoteParser.citationSentence(of: note)
        if let (_, range) = SourceNoteParser.firstLotReference(in: sentence) {
            let lead = String(sentence[..<range.lowerBound])
            let candidate = lead
                .components(separatedBy: CharacterSet(charactersIn: ",:;"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last { !$0.isEmpty } ?? ""
            // The segment before the lot, minus a leading "Source:" wrapper.
            let cleaned = candidate.replacingOccurrences(
                of: #"^Source:\s*"#, with: "", options: .regularExpression)
            if isSeriesSegment(cleaned) { alias = cleaned }
        }
        return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                   repository: "Department of State",
                                   recordGroup: recordGroup,
                                   lotFileNorm: SourceNoteParser.lotFileNorm(rawLot),
                                   rawLot: rawLot, seriesAlias: alias)
    }

    /// The gated segment immediately following `segment` in the tokenized citation
    /// sentence — the level-2 sub-series candidate.
    static func followingSegment(after segment: String, in segs: [String]) -> String? {
        let key = normalized(segment)
        guard let idx = segs.firstIndex(where: {
            normalized($0) == key || normalized($0).hasSuffix(key)
        }) else { return nil }
        guard let next = segs.dropFirst(idx + 1).first else { return nil }
        return isSeriesSegment(next) ? next : nil
    }

    /// The `decimal_class` derivation for a parsed note — the pipeline's
    /// `decimalClassColumn` gating verbatim.
    static func centralFilesClass(parsed: ParsedSourceNote, note: String) -> String? {
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

    /// The citation-sentence segment naming the central files (`"Central Files
    /// 1967–69"`, `"Central Foreign Policy File"`), or `nil` for bare decimal notes.
    static func centralFilesAnchorSegment(in note: String) -> String? {
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

    /// Strips the `RG-` prefix the parser writes (`"RG-59"` → `"59"`), matching the
    /// bare record-group numbers front matter stores.
    static func bareRG(_ rg: String?) -> String? {
        guard let rg else { return nil }
        let bare = rg.replacingOccurrences(of: #"^RG[\s\-]*"#, with: "",
                                           options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        return bare.isEmpty ? nil : bare
    }
}
