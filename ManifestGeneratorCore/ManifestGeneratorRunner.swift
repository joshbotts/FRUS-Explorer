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
/// Version history:
///   1.0 — Session 02: initial implementation
public struct ManifestGeneratorRunner {

    /// Default output path relative to the project root.
    public static let defaultOutputPath = "FRUSExplorer/Resources/manifest.json"

    /// Default number of concurrent volume fetches.
    public static let defaultConcurrencyLimit = 8

    private init() {}

    /// Runs the full manifest generation pipeline.
    ///
    /// - Parameters:
    ///   - outputPath: Where to write `manifest.json`. Defaults to `defaultOutputPath`.
    ///   - concurrencyLimit: Maximum simultaneous volume fetches. Defaults to `defaultConcurrencyLimit`.
    public static func run(
        outputPath: String = defaultOutputPath,
        concurrencyLimit: Int = defaultConcurrencyLimit
    ) async {
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
