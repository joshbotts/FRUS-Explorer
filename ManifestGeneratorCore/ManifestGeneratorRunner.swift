// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Orchestrates the full manifest generation pipeline.
///
/// Called from `ManifestGenerator/main.swift`. Steps:
/// 1. Fetch the GitHub volume listing (`GitHubClient`)
/// 2. For each volume, stream-fetch its `<teiHeader>` (`TEIHeaderFetcher`)
/// 3. Parse the header (`TEIHeaderParser`)
/// 4. Assemble a `VolumeManifestEntry` from parsed header + GitHub metadata
/// 5. Write all entries to `manifest.json` (`ManifestWriter`)
///
/// Fetching runs concurrently with a configurable concurrency limit to respect
/// GitHub API rate limits (default: 8 concurrent requests).
///
/// ## Output Path
/// By default writes to `./FRUSExplorer/Resources/manifest.json` relative to the
/// current working directory (the project root when invoked via `swift run`).
///
/// ## Local Overlay Mode (`VOLUMES_DIR`)
/// When the caller sets a local corpus directory (via `run(localVolumesDirectory:)`,
/// wired to the `VOLUMES_DIR` env var), the runner does NOT hit GitHub. Instead it loads
/// the existing manifest at `outputPath` as the base and, for each entry, re-parses only
/// the local `<teiHeader>` at `VOLUMES_DIR/<entry.filename>`, overriding **only**
/// `publicationDate` and `dateRange` while preserving every other field byte-for-byte.
/// This yields an offline, deterministic, date-only semantic diff — the mode used to
/// enrich the bundled manifest with true print years + coverage ranges (SA-1a). Entries
/// whose local file is missing are logged and left unchanged.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — SA-1a: local overlay mode (VOLUMES_DIR) that re-derives only date fields offline.
public struct ManifestGeneratorRunner {

    /// Default output path relative to the project root.
    public static let defaultOutputPath = "FRUSExplorer/Resources/manifest.json"

    /// Default number of concurrent volume fetches.
    public static let defaultConcurrencyLimit = 8

    private init() {}

    /// Runs the manifest generation pipeline.
    ///
    /// When `localVolumesDirectory` is non-nil, runs the offline **local overlay mode**
    /// (see the type doc-comment); otherwise runs the full GitHub fetch pipeline.
    ///
    /// - Parameters:
    ///   - outputPath: Where to write `manifest.json`. In overlay mode this is also read as
    ///     the base manifest. Defaults to `defaultOutputPath`.
    ///   - concurrencyLimit: Maximum simultaneous volume fetches (GitHub mode only).
    ///     Defaults to `defaultConcurrencyLimit`.
    ///   - localVolumesDirectory: A directory of local FRUS volume XML files. When set,
    ///     enables local overlay mode and GitHub is not contacted. Defaults to nil.
    public static func run(
        outputPath: String = defaultOutputPath,
        concurrencyLimit: Int = defaultConcurrencyLimit,
        localVolumesDirectory: String? = nil
    ) async {
        if let localDir = localVolumesDirectory {
            runLocalOverlay(outputPath: outputPath, volumesDirectory: localDir)
            return
        }

        print("[ManifestGenerator] Starting manifest generation…")

        let client = GitHubClient()

        // 1. Fetch GitHub directory listing.
        let githubEntries: [GitHubVolumeEntry]
        do {
            githubEntries = try await client.fetchVolumeEntries()
        } catch {
            print("[ManifestGenerator] ✗ Failed to fetch GitHub listing: \(error)")
            exit(1)
        }

        print("[ManifestGenerator] \(githubEntries.count) volumes to process.")

        // 2-4. Concurrently fetch + parse each volume's teiHeader.
        var manifestEntries: [VolumeManifestEntry] = []
        var errorCount = 0

        await withTaskGroup(of: VolumeManifestEntry?.self) { group in
            var inFlight = 0
            var iterator = githubEntries.makeIterator()

            // Seed the group with up to `concurrencyLimit` tasks.
            while inFlight < concurrencyLimit, let entry = iterator.next() {
                group.addTask { await process(githubEntry: entry) }
                inFlight += 1
            }

            // As tasks complete, collect results and add more work.
            for await result in group {
                if let entry = result {
                    manifestEntries.append(entry)
                } else {
                    errorCount += 1
                }
                if let next = iterator.next() {
                    group.addTask { await process(githubEntry: next) }
                }
            }
        }

        // 5. Write output.
        let withTags = manifestEntries.filter { !$0.tags.isEmpty }.count
        let withoutTags = manifestEntries.filter { $0.tags.isEmpty }.count

        print("""
        [ManifestGenerator] Results:
          Processed:    \(manifestEntries.count)
          With tags:    \(withTags)
          Without tags: \(withoutTags) (valid — volumes may predate the tagging system)
          Errors:       \(errorCount)
        """)

        do {
            try ManifestWriter.write(entries: manifestEntries, to: outputPath)
            print("[ManifestGenerator] ✓ manifest.json written to \(outputPath)")
        } catch {
            print("[ManifestGenerator] ✗ Failed to write manifest: \(error)")
            exit(1)
        }
    }

    // MARK: - Local Overlay Mode

    /// Offline pass that overrides ONLY `publicationDate` and `dateRange` on each existing
    /// manifest entry from the locally-parsed `<teiHeader>`, preserving all other fields.
    ///
    /// - Parameters:
    ///   - outputPath: Path to the existing manifest, read as the base and rewritten in place.
    ///   - volumesDirectory: Directory holding `<entry.filename>` XML files to parse.
    static func runLocalOverlay(outputPath: String, volumesDirectory: String) {
        print("[ManifestGenerator] Local overlay mode — volumes: \(volumesDirectory)")

        // 1. Load the existing manifest as the base.
        let baseEntries: [VolumeManifestEntry]
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
            baseEntries = try JSONDecoder().decode([VolumeManifestEntry].self, from: data)
        } catch {
            print("[ManifestGenerator] ✗ Failed to load base manifest at \(outputPath): \(error)")
            exit(1)
        }

        print("[ManifestGenerator] Loaded \(baseEntries.count) base entries.")

        let volumesURL = URL(fileURLWithPath: volumesDirectory, isDirectory: true)
        var updated: [VolumeManifestEntry] = []
        updated.reserveCapacity(baseEntries.count)

        var missing = 0
        var parseErrors = 0
        var changed = 0

        // 2. For each entry, re-derive the date fields from the local teiHeader.
        for entry in baseEntries {
            let fileURL = volumesURL.appendingPathComponent(entry.filename)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("[ManifestGenerator] ⚠︎ Missing local file, leaving unchanged: \(entry.filename)")
                missing += 1
                updated.append(entry)
                continue
            }

            let header: ParsedTEIHeader
            do {
                // Files are a few MB; reading the whole file and feeding the same parser the
                // GitHub path uses keeps behavior identical. The parser only needs the header.
                let data = try Data(contentsOf: fileURL)
                header = try TEIHeaderParser.parse(data)
            } catch {
                print("[ManifestGenerator] ✗ Parse failed for \(entry.filename): \(error) — leaving unchanged")
                parseErrors += 1
                updated.append(entry)
                continue
            }

            // 3. Override ONLY publicationDate + dateRange; preserve every other field.
            let newEntry = VolumeManifestEntry(
                volumeId: entry.volumeId,
                filename: entry.filename,
                subseries: entry.subseries,
                title: entry.title,
                dateRange: DateRange(earliest: header.earliestDate, latest: header.latestDate),
                publicationDate: header.publicationDate,
                status: entry.status,
                editors: entry.editors,
                generalEditor: entry.generalEditor,
                documentCount: entry.documentCount,
                sizeBytes: entry.sizeBytes,
                tags: entry.tags
            )
            if newEntry != entry { changed += 1 }
            updated.append(newEntry)
        }

        print("""
        [ManifestGenerator] Overlay results:
          Entries:      \(updated.count)
          Date-updated: \(changed)
          Missing file: \(missing)
          Parse errors: \(parseErrors)
        """)

        // 4. Write back in the same deterministic format.
        do {
            try ManifestWriter.write(entries: updated, to: outputPath)
            print("[ManifestGenerator] ✓ manifest.json overlaid at \(outputPath)")
        } catch {
            print("[ManifestGenerator] ✗ Failed to write manifest: \(error)")
            exit(1)
        }
    }

    // MARK: - Per-Volume Processing

    /// Fetches and parses a single volume's teiHeader. Returns nil on failure (logged).
    private static func process(githubEntry: GitHubVolumeEntry) async -> VolumeManifestEntry? {
        guard let url = URL(string: githubEntry.downloadUrl) else {
            print("[ManifestGenerator] ✗ Invalid download URL for \(githubEntry.name)")
            return nil
        }

        // Parse filename → volumeId + subseries.
        guard let parsed = VolumeIDParser.parse(filename: githubEntry.name) else {
            print("[ManifestGenerator] ✗ Unrecognised filename pattern: \(githubEntry.name)")
            return nil
        }

        // Fetch the teiHeader bytes.
        let headerData: Data
        do {
            headerData = try await TEIHeaderFetcher.fetch(from: url)
        } catch {
            print("[ManifestGenerator] ✗ Fetch failed for \(githubEntry.name): \(error)")
            return nil
        }

        // Parse the header.
        let header: ParsedTEIHeader
        do {
            header = try TEIHeaderParser.parse(headerData)
        } catch {
            print("[ManifestGenerator] ✗ Parse failed for \(githubEntry.name): \(error)")
            return nil
        }

        #if DEBUG
        print("[ManifestGenerator] ✓ \(parsed.volumeId) — \"\(header.title.prefix(60))…\" tags=\(header.tags.count)")
        #endif

        return VolumeManifestEntry(
            volumeId: parsed.volumeId,
            filename: githubEntry.name,
            subseries: parsed.subseries,
            title: header.title,
            dateRange: DateRange(earliest: header.earliestDate, latest: header.latestDate),
            publicationDate: header.publicationDate,
            status: header.status,
            editors: header.editors,
            generalEditor: header.generalEditor,
            documentCount: header.documentCount,
            sizeBytes: githubEntry.size,
            tags: header.tags
        )
    }
}
