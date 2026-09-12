// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import TEIHeaderKit

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
/// the existing manifest at `outputPath` as the base and, for each entry, re-parses the local
/// `<teiHeader>` at `VOLUMES_DIR/<entry.filename>`, overriding the fields that header — or the file
/// itself — is authoritative for: `publicationDate`, `dateRange`, `status`, `tags` and `sizeBytes`.
/// Every other field is preserved byte-for-byte.
///
/// **The list has grown twice, each time after a field went stale unnoticed.** `status` joined in
/// September 2026: re-deriving the date from a header while leaving the status that header also
/// states is how two modes of one generator come to disagree. `tags` and `sizeBytes` joined at
/// #1284, when the Office of the Historian added eighteen volume tags to `frus1981-88v16` in place
/// (corpus commit c95d35451) and this mode could not see them — it read `entry.tags` back out of
/// the manifest it was correcting. If a future field turns out to be one OH edits in place, it
/// belongs here too; the rule is "what does the local file know that the manifest might not".
///
/// Entries whose local file is missing are logged and left unchanged.
///
/// Version history:
///   1.0 — Session 02: initial implementation
///   1.1 — SA-1a: local overlay mode (VOLUMES_DIR) that re-derives only date fields offline.
///   1.2 — #1284: the overlay also re-derives `tags` and `sizeBytes`, the two fields OH's in-place
///         edit to frus1981-88v16 moved and this mode could not see.
public struct ManifestGeneratorRunner {

    /// The publication date to record: the printed year if the volume states one, else the date
    /// its `revisionDesc` says it was published.
    ///
    /// A **fallback, never an override**, and the numbers are why. Over the 553 shipped volumes,
    /// where both a `publicationStmt` print year and a `revisionDesc` published `@when` exist, the
    /// four-digit years **agree in 525 and differ in 26** — `frus1950v01` prints 1977 and was
    /// published digitally in 1998. They are two different facts, so the printed year keeps the
    /// field whenever the volume prints one, and the digital date is admitted only where there is
    /// nothing else to say.
    ///
    /// **It has now retired itself, exactly as predicted, and that is worth recording.** It was
    /// measured filling exactly one volume — `frus1981-88v16`, released mid-run with an empty
    /// `publicationStmt/date` and `<change corresp="#frus1981-88v16" status="published"
    /// when="2026-09-18"/>`. OH filled the printed year in on 2026-09-10 (corpus commit cf8abf696),
    /// so as of #1284 the fallback fills **zero** volumes and the manifest holds 552 bare `YYYY`
    /// strings against a single full ISO date (`frus1969-76v32`, 2010-11-05), which reached the
    /// manifest by a different route. The code is kept because the condition recurs at every
    /// mid-cycle release; it is the measurement that has moved, not the rule.
    ///
    /// - Parameters:
    ///   - header: The parsed TEI header.
    /// - Returns: The date to store, or nil when the header states neither.
    static func publicationDate(from header: ParsedTEIHeader) -> String? {
        if let printed = header.publicationDate, !printed.isEmpty { return printed }
        return header.publishedWhen
    }

    /// The manifest status for a volume, from `revisionDesc/@status`.
    ///
    /// The header's six words map onto three manifest cases, and the mapping is narrow because the
    /// shipped set is narrow. Measured over the **553 volumes the app carries**, `revisionDesc`
    /// says `published` 550 times and `partially-published` **3** times — `frus1969-76ve10`,
    /// `frus1977-80v27` and `frus1981-88v16`. The four in-progress states occur only among the 141
    /// corpus files the app does not ship.
    ///
    /// **An absent `revisionDesc` stays `.published`**, which is a guard rather than a case: every
    /// one of the 694 corpus files carries one. It exists for a side-loaded or hand-edited header,
    /// where reading silence as "not published" would demote a volume the reader can plainly see.
    ///
    /// **`planned` is honoured** — it maps one-to-one onto a case that exists for exactly it, and
    /// `VolumeStatus.planned`'s own documentation says such a volume "may appear in manifests as a
    /// placeholder". No shipped volume is planned today.
    ///
    /// **The three `being-*` words, and anything unrecognised, stay `.published` and say so.** A
    /// volume in this listing has content the app can download, so demoting it would contradict
    /// the file just parsed, and there is no measurement behind any other choice. Nothing reaches
    /// that branch today, which is exactly why it prints rather than guessing quietly.
    ///
    /// - Parameters:
    ///   - header: The parsed TEI header.
    ///   - volumeId: The volume, for the log line.
    /// - Returns: The status to record.
    static func status(from header: ParsedTEIHeader, volumeId: String) -> VolumeStatus {
        switch header.publicationStatus {
        case "published", nil:
            return .published
        case _ where header.isPartiallyPublished:
            return .partiallyPublished
        case "planned":
            return .planned
        case .some(let other):
            print("[ManifestGenerator] \(volumeId) is in the published listing but its revisionDesc "
                + "says \"\(other)\" — recorded as published. If this is now common, the mapping "
                + "in ManifestGeneratorRunner.status(from:volumeId:) needs a decision.")
            return .published
        }
    }

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

    /// Offline pass that overrides ONLY `publicationDate`, `dateRange` and `status` on each existing
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

            // 3. Re-derive every field the LOCAL FILE is authoritative for; preserve the rest.
            //
            // The set has grown twice, each time for the same reason: the Office of the Historian
            // edits a published volume in place, and a field this overlay declines to re-derive is
            // a field that silently goes stale against a corpus the repository has already pulled.
            // `status` joined at the vol. XVI ingest; `tags` and `sizeBytes` join here (#1284),
            // because OH added eighteen volume tags to `frus1981-88v16` in corpus commit c95d35451
            // and the overlay had no way to see them — `tags: entry.tags` read them straight back
            // out of the base manifest it was supposed to be correcting.
            //
            // What is STILL preserved is preserved for a reason, not by omission: `title`,
            // `editors` and `generalEditor` are header-derivable but the GitHub arm's values are
            // the shipped ones and re-deriving them here would let two modes disagree about
            // strings nobody has asked to change; `documentCount` is 0 for all 553 entries by
            // construction (no header carries it); `subseries` and `volumeId` are parsed from the
            // filename, not the file.
            let newEntry = VolumeManifestEntry(
                volumeId: entry.volumeId,
                filename: entry.filename,
                subseries: entry.subseries,
                title: entry.title,
                dateRange: DateRange(earliest: header.earliestDate, latest: header.latestDate),
                publicationDate: Self.publicationDate(from: header),
                // Now re-derived here too. The overlay's contract was publicationDate + dateRange
                // only, and preserving a stale status while re-deriving the date beside it is the
                // drift this repository keeps rediscovering: two modes, one artifact, different
                // answers.
                status: Self.status(from: header, volumeId: entry.volumeId),
                editors: entry.editors,
                generalEditor: entry.generalEditor,
                documentCount: entry.documentCount,
                // The local file's own size, which is what the GitHub arm records for its copy.
                // Cosmetic on screen, but a manifest whose byte count disagrees with the file
                // beside it is a manifest a reader cannot use to check anything.
                sizeBytes: (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size])
                    .flatMap { ($0 as? NSNumber)?.intValue } ?? entry.sizeBytes,
                tags: header.tags
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
            publicationDate: Self.publicationDate(from: header),
            // Was hardcoded `.published` behind a comment saying the TEI header carries no
            // publication status. It does — `revisionDesc/@status` — and two shipped volumes were
            // being recorded as fully published while their own headers said otherwise.
            status: Self.status(from: header, volumeId: parsed.volumeId),
            editors: header.editors,
            generalEditor: header.generalEditor,
            documentCount: header.documentCount,
            sizeBytes: githubEntry.size,
            tags: header.tags
        )
    }
}
