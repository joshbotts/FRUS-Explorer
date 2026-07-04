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
///
/// Every key-producing rule (the normal form, repository canonicalization, segment
/// tokenization and gating, and the per-provenance level-1 identity) lives in
/// `SourceNoteKit.CollectionKeying`, which the app's authority lookups share — the thin
/// wrappers here keep the generator's original call surface. This file owns only the
/// generator-side concerns: the front-matter outline walk and the level-2 / alias
/// harvesting around the shared identity.
public enum ReferenceBuilder {

    // MARK: - Shared keying rules (SourceNoteKit.CollectionKeying)

    /// Normal form for merge keys — see `CollectionKeying.normalized`.
    public static func normalized(_ text: String) -> String {
        CollectionKeying.normalized(text)
    }

    /// Canonical repository keyword — see `CollectionKeying.canonicalRepository`.
    public static func canonicalRepository(_ repository: String?) -> String? {
        CollectionKeying.canonicalRepository(repository)
    }

    /// Citation-sentence tokenization — see `CollectionKeying.segments(ofCitation:)`.
    public static func segments(ofCitation text: String) -> [String] {
        CollectionKeying.segments(ofCitation: text)
    }

    /// Series-segment gate — see `CollectionKeying.isSeriesSegment`.
    public static func isSeriesSegment(_ segment: String) -> Bool {
        CollectionKeying.isSeriesSegment(segment)
    }

    /// Level-1 merge segment — see `CollectionKeying.leadingMergeSegment`.
    public static func leadingMergeSegment(of text: String) -> String? {
        CollectionKeying.leadingMergeSegment(of: text)
    }

    /// Central-files override gate — see `CollectionKeying.isCentralFilesSegment`.
    public static func isCentralFilesSegment(_ segment: String) -> Bool {
        CollectionKeying.isCentralFilesSegment(segment)
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

    /// Generic grouping headings that must not become collections of their own
    /// (`"Lot Files"` under an RG heading groups the real lot collections below it).
    private static let groupingDenylist: Set<String> = [
        "lot files", "lot file", "other lot files", "office files", "miscellaneous files",
        "unpublished sources", "published sources", "archival sources", "archives",
    ]

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
        for keyword in CollectionKeying.repositoryKeywords
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
        // Level-1 identity (colon-split class leaves, bare-class refusal, segment gate,
        // and the central-files repository override) is the shared derivation — the
        // same one the app's authority lookups apply to `volume_sources` rows.
        guard let identity = CollectionKeying.frontMatterIdentity(
            text: row.text, repository: repo, lotFileNorm: nil,
            decimalClass: row.decimalClass), let segment = identity.leadingSegment
        else { return nil }
        // Display name: the colon-split lead when a class child split off, else the text.
        let leadText = identity.decimalClass != nil
            ? String(row.text[..<(row.text.firstIndex(of: ":") ?? row.text.endIndex)])
                .trimmingCharacters(in: .whitespaces)
            : row.text
        // RG 59 defaults only when the central-files override actually re-bucketed
        // the row to Department of State — a library-held "Central Files…" row keeps
        // its library identity (and no State record group).
        let central = isCentralFilesSegment(segment)
            && identity.repository == "Department of State"
        let effectiveRG = central ? (row.recordGroup ?? "59") : row.recordGroup
        let context = Level1Context(repository: identity.repository, recordGroup: effectiveRG,
                                    lotFileNorm: nil, rawLot: nil,
                                    leadingSegment: segment, displayName: leadText)
        refs.append(CollectionReference(
            volumeId: volumeId, origin: .frontMatter, repository: identity.repository,
            recordGroup: effectiveRG, leadingSegment: segment,
            subSegment: nil, subDecimalClass: identity.decimalClass, displayName: leadText))
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

    /// Converts one parsed document source note into a reference: the level-1 identity
    /// comes from the shared `CollectionKeying.identity(of:note:)` (the same derivation
    /// the app's authority lookups use), and this wrapper adds the generator-side
    /// extras — record group, the level-2 segment from the citation sentence, and the
    /// named-series alias harvested around a lot reference.
    public static func reference(volumeId: String, note: String,
                                 parsed: ParsedSourceNote) -> CollectionReference? {
        guard let identity = CollectionKeying.identity(of: parsed, note: note) else { return nil }

        // Lot-keyed identities: harvest the raw lot and its preceding series alias.
        if let lotNorm = identity.lotFileNorm {
            let (rawLot, rg): (String, String?) = {
                switch parsed {
                case .lotFile(let rg, let lot, _): return (lot, CollectionKeying.bareRG(rg))
                case .naraCollection(let rg, _, let lot, _): return (lot ?? "", CollectionKeying.bareRG(rg))
                default: return ("", nil)
                }
            }()
            return lotReference(volumeId: volumeId, note: note, rawLot: rawLot,
                                lotNorm: lotNorm, recordGroup: rg)
        }

        guard let segment = identity.leadingSegment else { return nil }
        switch parsed {
        case .naraCollection(let rg, _, _, _):
            let segs = segments(ofCitation: note)
            let sub = identity.decimalClass == nil
                ? followingSegment(after: segment, in: segs) : nil
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: identity.repository,
                                       recordGroup: CollectionKeying.bareRG(rg),
                                       leadingSegment: segment, subSegment: sub,
                                       subDecimalClass: identity.decimalClass)
        case .presidentialLibrary:
            let segs = segments(ofCitation: note)
            let sub = followingSegment(after: segment, in: segs)
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: identity.repository, recordGroup: nil,
                                       leadingSegment: segment, subSegment: sub)
        case .centralFiles, .cfpfFile:
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: identity.repository, recordGroup: "59",
                                       leadingSegment: segment,
                                       subDecimalClass: identity.decimalClass)
        case .namedFileSeries, .ciaCollection:
            return CollectionReference(volumeId: volumeId, origin: .documentNote,
                                       repository: identity.repository, recordGroup: nil,
                                       leadingSegment: segment)
        default:
            return nil
        }
    }

    /// Builds a lot-keyed reference, harvesting the named-series segment that precedes
    /// the lot in the citation sentence as an alias (`"PPS Files: Lot 64 D 199"`,
    /// `"Secretary's Memoranda of Conversation, lot 64 D 199"`).
    private static func lotReference(volumeId: String, note: String, rawLot: String,
                                     lotNorm: String, recordGroup: String?) -> CollectionReference {
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
                                   lotFileNorm: lotNorm,
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
}
