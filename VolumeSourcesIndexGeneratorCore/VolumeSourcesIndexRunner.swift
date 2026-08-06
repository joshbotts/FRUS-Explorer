// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CentralFilesIndexGeneratorCore

/// Harvests the front-matter Sources section of every locally-downloaded FRUS volume into a
/// bundled `volume-sources-index.json`: per-volume prose + a resolved archival-collection
/// outline, plus a deduplicated cross-volume authority of the major collections.
///
/// Resolution is two-stage, and each distinct archival key is resolved **once**:
/// 1. **Offline** — lot-file citations resolve against the bundled `central-files-index.json`.
/// 2. **NARA Catalog API** (only when `CATALOG_API_KEY` is set) — lot files the bundle
///    missed resolve via `variantControlNumber_is`; `<hi rend="strong">` record-group headers
///    resolve to their record-group record. Every outcome is cached to `CACHE_DIR`, so
///    re-runs and partial failures never re-query.
///
/// Configuration (environment variables):
/// - `VOLUMES_DIR` — directory of volume `*.xml` files (default `/Users/jbotts/Development/frus/volumes`)
/// - `CENTRAL_FILES_INDEX` — bundled index path (default `FRUSExplorer/Resources/central-files-index.json`)
/// - `OUTPUT` — output path (default `FRUSExplorer/Resources/volume-sources-index.json`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`)
/// - `CATALOG_API_KEY` — enable the NARA Catalog resolution pass (offline-only when absent)
/// - `CACHE_DIR` — API resolution cache (default `.cache/volume-sources`)
public enum VolumeSourcesIndexRunner {

    public static func run() async throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath: env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let indexPath = env["CENTRAL_FILES_INDEX"] ?? "FRUSExplorer/Resources/central-files-index.json"
        let outputPath = env["OUTPUT"] ?? "FRUSExplorer/Resources/volume-sources-index.json"
        let generated = env["GENERATED_DATE"] ?? today()

        let bundled = try BundledLotResolver(indexURL: URL(fileURLWithPath: indexPath))
        log("Loaded bundled index: \(bundled.lotFileCount) lot files")

        // NARA Catalog client — nil (offline only) when no API key is provided.
        let apiClient: NARACatalogHarvestClient? = env["CATALOG_API_KEY"].map { key in
            let cacheDir = URL(fileURLWithPath: env["CACHE_DIR"] ?? ".cache/volume-sources")
            return NARACatalogHarvestClient(apiKey: key, cacheDirectory: cacheDir)
        }
        log(apiClient == nil ? "No CATALOG_API_KEY — offline pass only" : "API pass enabled")

        // MARK: Phase A — parse every volume into an unresolved collection tree.
        let xmls = try FileManager.default.contentsOfDirectory(at: volumesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !xmls.isEmpty else { throw RunError.noVolumes(volumesDir.path) }

        var volumeTrees: [(volumeId: String, prose: [String], tree: [CollectionNode])] = []
        for url in xmls {
            let volumeId = url.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: url) else { continue }
            let rows = VolumeSourcesExtractor.extract(fromXML: data)
            guard !rows.isEmpty else { continue }
            let prose = rows.filter { $0.kind == .prose }.map(\.text)
            var index = 0
            let tree = buildTree(rows.filter { $0.kind == .item }, &index, depth: 0)
            volumeTrees.append((volumeId, prose, tree))
        }

        // MARK: Phase B — gather the distinct archival keys to resolve.
        var lotKeys: [String: String] = [:]   // normalizedLot -> inferred record group
        var rgHeadings: [String: String] = [:]   // record group number -> a representative heading title
        for vt in volumeTrees { gatherKeys(vt.tree, inheritedRG: nil, lotKeys: &lotKeys, rgHeadings: &rgHeadings) }
        log("Distinct keys: \(lotKeys.count) lot files, \(rgHeadings.count) record groups")

        // MARK: Phase C — resolve each distinct key once (offline first, then API).
        var lotMap: [String: ResolvedNAID] = [:]
        var rgMap: [String: ResolvedNAID] = [:]
        var apiLotHits = 0, apiRGHits = 0
        for (lot, rg) in lotKeys {
            if let hit = bundled.resolve(rawLot: lot) { lotMap[lot] = hit; continue }
            guard let apiClient else { continue }
            if let r = try? await apiClient.resolveLotFile(normalized: lot, recordGroup: rg) {
                lotMap[lot] = ResolvedNAID(naId: r.record.naId,
                                           catalogURL: NARACatalogHarvestClient.catalogIDBase + r.record.naId,
                                           title: r.record.title, recordGroup: rg, matchType: r.matchType)
                apiLotHits += 1
            }
        }
        if let apiClient {
            for (rg, heading) in rgHeadings {
                if let r = try? await apiClient.resolveRecordGroup(number: rg, title: heading) {
                    rgMap[rg] = ResolvedNAID(naId: r.naId,
                                             catalogURL: NARACatalogHarvestClient.catalogIDBase + r.naId,
                                             title: r.title, recordGroup: rg, matchType: "api")
                }
            }
            // Guard: distinct record groups must resolve to distinct NAIDs. A collision is
            // the signature of an ignored filter (every RG collapsing to one record) — discard
            // those rather than bundle mislinked headers.
            let byNAID = Dictionary(grouping: rgMap.keys) { rgMap[$0]!.naId }
            for (naId, rgs) in byNAID where rgs.count > 1 {
                log("WARNING: \(rgs.count) record groups (\(rgs.sorted().joined(separator: ", "))) all resolved to NAID \(naId) — discarding as a likely ignored-filter bug")
                for rg in rgs { rgMap[rg] = nil }
            }
            apiRGHits = rgMap.count
        }

        let prior = (try? JSONDecoder().decode(
            PriorIndex.self, from: Data(contentsOf: URL(fileURLWithPath: outputPath))))?.recordGroups
        let decided = try recordGroupsToWrite(resolved: rgMap, headingCount: rgHeadings.count,
                                              prior: prior ?? [:], outputPath: outputPath)
        rgMap = decided.map
        if let note = decided.note { log(note) }

        // MARK: Phase D — apply resolutions to the (transient) trees to fold the cross-volume
        // authority and count coverage. The resolved trees themselves are not serialized —
        // only the `recordGroups` / `lots` resolution maps and the authority ship.
        var authority: [String: MajorCollection] = [:]
        var totalItems = 0, totalProse = 0, totalHeadings = 0, resolvedNodes = 0
        for vt in volumeTrees {
            let resolved = applyResolution(vt.tree, inheritedRG: nil, bundled: bundled, lotMap: lotMap, rgMap: rgMap)
            totalProse += vt.prose.count
            countTree(resolved, items: &totalItems, headings: &totalHeadings, resolved: &resolvedNodes)
            accumulateAuthority(resolved, volumeId: vt.volumeId, into: &authority)
        }

        let majorCollections = authority.values
            .map { var c = $0; c.volumeIds.sort(); return c }
            .sorted { $0.occurrences != $1.occurrences ? $0.occurrences > $1.occurrences : $0.key < $1.key }

        let output = VolumeSourcesIndex(schemaVersion: 2, generated: generated,
                                        recordGroups: rgMap, lots: lotMap,
                                        majorCollections: majorCollections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(output).write(to: URL(fileURLWithPath: outputPath))

        log("""
        volume-sources-index.json written to \(outputPath)
          volumes with sources: \(volumeTrees.count) / \(xmls.count)
          prose paragraphs:     \(totalProse)
          collection items:     \(totalItems)  (headings: \(totalHeadings))
          resolved nodes:       \(resolvedNodes)  (API lot hits: \(apiLotHits), API RG hits: \(apiRGHits))
          record groups:        \(rgMap.count)   lot files: \(lotMap.count)
          major collections:    \(majorCollections.count)
        """)
    }

    // MARK: - Tree building (structure only; resolution applied later)

    /// Rebuilds the collection outline from flat pre-ordered rows. Gap-tolerant: an orphan
    /// depth-jump is clamped rather than dropped (matching the app's `VolumeSourcesView.build`).
    static func buildTree(_ items: [SourceRow], _ index: inout Int, depth: Int) -> [CollectionNode] {
        var nodes: [CollectionNode] = []
        while index < items.count {
            let item = items[index]
            if item.depth < depth { break }
            index += 1
            let children = buildTree(items, &index, depth: item.depth + 1)
            nodes.append(CollectionNode(
                text: item.text, isHeading: item.isHeading, depth: item.depth,
                recordGroup: item.recordGroup, lotFile: item.lotFile, repository: item.repository,
                resolved: nil, children: children))
        }
        return nodes
    }

    // MARK: - Key gathering & resolution application (ancestor RG carried down)

    /// The record group in effect for a node: its own, else the nearest ancestor heading's,
    /// else a State-Department default (`"59"` — most FRUS lots are RG 59).
    private static func effectiveRG(_ node: CollectionNode, inherited: String?) -> String {
        node.recordGroup ?? inherited ?? "59"
    }

    static func gatherKeys(_ nodes: [CollectionNode], inheritedRG: String?,
                           lotKeys: inout [String: String], rgHeadings: inout [String: String]) {
        for node in nodes {
            let rg = node.recordGroup ?? inheritedRG
            if let lot = node.lotFile {
                lotKeys[BundledLotResolver.normalizeLot(lot)] = effectiveRG(node, inherited: inheritedRG)
            } else if let recordGroup = node.recordGroup {
                // Keep the first heading text seen for this RG as the title-relevance fallback.
                if rgHeadings[recordGroup] == nil { rgHeadings[recordGroup] = node.text }
            }
            gatherKeys(node.children, inheritedRG: rg, lotKeys: &lotKeys, rgHeadings: &rgHeadings)
        }
    }

    static func applyResolution(_ nodes: [CollectionNode], inheritedRG: String?,
                                bundled: BundledLotResolver,
                                lotMap: [String: ResolvedNAID], rgMap: [String: ResolvedNAID]) -> [CollectionNode] {
        nodes.map { node in
            let rg = node.recordGroup ?? inheritedRG
            var resolved: ResolvedNAID?
            if let lot = node.lotFile {
                let key = BundledLotResolver.normalizeLot(lot)
                resolved = bundled.resolve(rawLot: lot) ?? lotMap[key]
            } else if let recordGroup = node.recordGroup {
                resolved = rgMap[recordGroup]
            }
            var copy = node
            copy.resolved = resolved
            copy.children = applyResolution(node.children, inheritedRG: rg, bundled: bundled,
                                            lotMap: lotMap, rgMap: rgMap)
            return copy
        }
    }

    // MARK: - Cross-volume authority

    /// Folds a volume's outline into the deduplicated authority, keyed by lot file or
    /// normalized text so a heading that recurs across volumes collapses to one record.
    static func accumulateAuthority(_ nodes: [CollectionNode], volumeId: String,
                                    into authority: inout [String: MajorCollection]) {
        for node in nodes {
            if node.isHeading || node.recordGroup != nil || node.lotFile != nil {
                let key = node.lotFile.map { "lot:" + BundledLotResolver.normalizeLot($0) }
                    ?? "txt:" + node.text.lowercased()
                if var existing = authority[key] {
                    if !existing.volumeIds.contains(volumeId) { existing.volumeIds.append(volumeId) }
                    existing.occurrences += 1
                    if existing.resolved == nil { existing.resolved = node.resolved }
                    authority[key] = existing
                } else {
                    authority[key] = MajorCollection(
                        key: key, text: node.text, isHeading: node.isHeading,
                        recordGroup: node.recordGroup, lotFile: node.lotFile,
                        repository: node.repository, resolved: node.resolved,
                        volumeIds: [volumeId], occurrences: 1)
                }
            }
            accumulateAuthority(node.children, volumeId: volumeId, into: &authority)
        }
    }

    // MARK: - Helpers

    private static func countTree(_ nodes: [CollectionNode], items: inout Int, headings: inout Int, resolved: inout Int) {
        for node in nodes {
            items += 1
            if node.isHeading { headings += 1 }
            if node.resolved != nil { resolved += 1 }
            countTree(node.children, items: &items, headings: &headings, resolved: &resolved)
        }
    }

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    /// Just enough of the previous artifact to carry its record-group map forward.
    struct PriorIndex: Decodable {
        let recordGroups: [String: ResolvedNAID]
    }

    /// The record-group map to write, given what this run resolved and what the previous
    /// artifact holds.
    ///
    /// ## Why this exists
    /// `recordGroups` can **only** be built by the API pass — `resolveRecordGroup` has no
    /// offline route, and `apiClient` is `nil` whenever `CATALOG_API_KEY` is absent. So the
    /// keyless invocation this file's own header calls an "offline pass", and which
    /// `CLAUDE.md` documents *first*, wrote `recordGroups: {}` over the shipped bundle and
    /// silently deleted every record-group resolution in it. Nothing downstream would have
    /// failed: the volume-Sources outline's header links — **6,373 front-matter nodes** —
    /// would simply have stopped appearing, with no error anywhere.
    ///
    /// A "refuse to write empty" guard alone would have been wrong, because it would make the
    /// documented offline invocation fail every time. Carrying the previous map forward is what
    /// makes that invocation *safe* rather than merely loud — the same shape as
    /// `ManifestGenerator`'s offline overlay mode, which preserves the fields it cannot
    /// re-derive. The throw is kept for the one case nothing can rescue: no API pass **and** no
    /// usable prior artifact.
    ///
    /// - Returns: the map to write, and a line to log when it was inherited.
    static func recordGroupsToWrite(resolved: [String: ResolvedNAID],
                                    headingCount: Int,
                                    prior: [String: ResolvedNAID],
                                    outputPath: String)
        throws -> (map: [String: ResolvedNAID], note: String?) {
        // A run that resolved anything, or a corpus with no record-group headers at all, is
        // self-consistent and writes what it has.
        guard resolved.isEmpty, headingCount > 0 else { return (resolved, nil) }
        guard !prior.isEmpty else {
            throw RunError.emptyRecordGroups(headings: headingCount, output: outputPath)
        }
        return (prior, "Preserved \(prior.count) record-group resolutions from the existing "
                + "\(outputPath) — this run had no CATALOG_API_KEY and cannot re-derive them.")
    }

    public enum RunError: Error, CustomStringConvertible {
        case noVolumes(String)
        case emptyRecordGroups(headings: Int, output: String)
        public var description: String {
            switch self {
            case .noVolumes(let dir): return "No .xml volumes found in \(dir)"
            case .emptyRecordGroups(let headings, let output):
                return """
                    Refusing to write \(output) with an EMPTY recordGroups map.
                    The corpus names \(headings) record-group headers, but this run resolved none \
                    and there is no usable existing artifact to carry forward.
                    resolveRecordGroup has no offline route, so a keyless run can only preserve \
                    the previous map — not rebuild it. Either set CATALOG_API_KEY, or restore the \
                    committed volume-sources-index.json before re-running.
                    """
            }
        }
    }
}
