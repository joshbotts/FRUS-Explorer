// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Harvests the front-matter Sources section of every locally-downloaded FRUS volume into a
/// bundled `volume-sources-index.json`: per-volume prose + a resolved archival-collection
/// outline, plus a deduplicated cross-volume authority of the major collections.
///
/// Resolution is offline-first: lot-file citations resolve against the bundled
/// `central-files-index.json`. Record-group / repository headers that the bundle can't
/// resolve are left `resolved == nil` and reported; a later pass (with `CATALOG_API_KEY`)
/// can fill them from the NARA Catalog API.
///
/// Configuration (environment variables):
/// - `VOLUMES_DIR` — directory of volume `*.xml` files (default `/Users/jbotts/Development/frus/volumes`)
/// - `CENTRAL_FILES_INDEX` — bundled index path (default `FRUSExplorer/Resources/central-files-index.json`)
/// - `OUTPUT` — output path (default `FRUSExplorer/Resources/volume-sources-index.json`)
/// - `GENERATED_DATE` — override the `generated` stamp (default: today, `yyyy-MM-dd`)
public enum VolumeSourcesIndexRunner {

    public static func run() throws {
        let env = ProcessInfo.processInfo.environment
        let volumesDir = URL(fileURLWithPath: env["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let indexPath = env["CENTRAL_FILES_INDEX"] ?? "FRUSExplorer/Resources/central-files-index.json"
        let outputPath = env["OUTPUT"] ?? "FRUSExplorer/Resources/volume-sources-index.json"
        let generated = env["GENERATED_DATE"] ?? Self.today()

        let resolver = try BundledLotResolver(indexURL: URL(fileURLWithPath: indexPath))
        FileHandle.standardError.write(Data("Loaded bundled index: \(resolver.lotFileCount) lot files\n".utf8))

        let xmls = try FileManager.default.contentsOfDirectory(at: volumesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !xmls.isEmpty else {
            throw RunError.noVolumes(volumesDir.path)
        }

        var volumes: [String: VolumeSources] = [:]
        var authority: [String: MajorCollection] = [:]
        var totalItems = 0, totalProse = 0, totalHeadings = 0
        var resolvedLot = 0, unresolved = 0

        for url in xmls {
            let volumeId = url.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: url) else { continue }
            let rows = VolumeSourcesExtractor.extract(fromXML: data)
            guard !rows.isEmpty else { continue }

            let prose = rows.filter { $0.kind == .prose }.map(\.text)
            let items = rows.filter { $0.kind == .item }
            var index = 0
            let tree = Self.buildTree(items, &index, depth: 0, resolver: resolver,
                                      resolvedLot: &resolvedLot, unresolved: &unresolved)

            volumes[volumeId] = VolumeSources(prose: prose, collections: tree)
            totalProse += prose.count
            totalItems += items.count
            totalHeadings += items.filter(\.isHeading).count

            Self.accumulateAuthority(tree, volumeId: volumeId, into: &authority)
        }

        let majorCollections = authority.values
            .map { var c = $0; c.volumeIds.sort(); return c }
            .sorted { $0.occurrences != $1.occurrences ? $0.occurrences > $1.occurrences : $0.key < $1.key }

        let output = VolumeSourcesIndex(
            schemaVersion: 1, generated: generated,
            volumes: volumes, majorCollections: majorCollections)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(output)
        try json.write(to: URL(fileURLWithPath: outputPath))

        // Summary to stderr so stdout can carry the artifact path if piped.
        let summary = """
        volume-sources-index.json written to \(outputPath)
          volumes with sources: \(volumes.count) / \(xmls.count)
          prose paragraphs:     \(totalProse)
          collection items:     \(totalItems)  (headings: \(totalHeadings))
          resolved (lot files): \(resolvedLot)
          unresolved (need API):\(unresolved)
          major collections:    \(majorCollections.count)
        """
        FileHandle.standardError.write(Data((summary + "\n").utf8))
    }

    // MARK: - Tree building + resolution

    /// Recursively rebuilds the collection outline from flat pre-ordered rows, resolving each
    /// node against the bundled index as it goes. Gap-tolerant: an orphan depth-jump is
    /// clamped rather than dropped (matching the app's `VolumeSourcesView.build`).
    static func buildTree(_ items: [SourceRow], _ index: inout Int, depth: Int,
                          resolver: BundledLotResolver,
                          resolvedLot: inout Int, unresolved: inout Int) -> [CollectionNode] {
        var nodes: [CollectionNode] = []
        while index < items.count {
            let item = items[index]
            if item.depth < depth { break }
            index += 1
            let children = buildTree(items, &index, depth: item.depth + 1, resolver: resolver,
                                     resolvedLot: &resolvedLot, unresolved: &unresolved)
            var resolved: ResolvedNAID?
            if let lot = item.lotFile, let hit = resolver.resolve(rawLot: lot) {
                resolved = hit
                resolvedLot += 1
            } else if item.isHeading || item.recordGroup != nil || item.lotFile != nil {
                // A collection node the bundle couldn't resolve — a candidate for the API pass.
                unresolved += 1
            }
            nodes.append(CollectionNode(
                text: item.text, isHeading: item.isHeading, depth: item.depth,
                recordGroup: item.recordGroup, lotFile: item.lotFile, repository: item.repository,
                resolved: resolved, children: children))
        }
        return nodes
    }

    // MARK: - Cross-volume authority

    /// Folds a volume's outline into the deduplicated authority, keyed by lot file or
    /// normalized text so a heading that recurs across volumes collapses to one record.
    static func accumulateAuthority(_ nodes: [CollectionNode], volumeId: String,
                                    into authority: inout [String: MajorCollection]) {
        for node in nodes {
            // Only index nodes that name a collection (headings or nodes with archival keys);
            // plain leaf descriptions without keys are skipped from the cross-volume authority.
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

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    public enum RunError: Error, CustomStringConvertible {
        case noVolumes(String)
        public var description: String {
            switch self {
            case .noVolumes(let dir): return "No .xml volumes found in \(dir)"
            }
        }
    }
}
