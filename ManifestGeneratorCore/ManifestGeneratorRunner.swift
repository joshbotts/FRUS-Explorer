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
/// 5. Write all entries to `manifest.json` (`ManifestWriter`), only when every volume of the
///    listing has one (#2022): otherwise write nothing, name each volume that has none, and exit 1
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
///   1.3 — `sizeBytes` follows symlinks (`fileSize(at:)`): a VOLUMES_DIR whose volume files are
///         symlinks recorded each link's own 51–65 bytes (552 volumes in the run that found it)
///         while reporting 0 parse errors. The summary's "Date-updated" count, which counts ANY
///         changed entry, is relabelled "Changed".
///   1.4 — #2022 (row L61): the online run writes nothing and exits 1, naming each volume, when
///         any volume of the listing did not reach the manifest, where it wrote the rest and
///         exited 0; a 429 or a 5xx is tried again after 2, 4 and 8 seconds first. The pass is
///         `runOnline`, its listing, header fetch and pause handed in, so a test drives it
public struct ManifestGeneratorRunner {

    /// The publication date to record: the printed year if the volume states one, else the date
    /// its `revisionDesc` says it was published.
    ///
    /// A **fallback, never an override**, and the numbers are why. Over the 553 shipped volumes,
    /// where both a `publicationStmt` print year and a `revisionDesc` published `@when` exist, the
    /// four-digit years **agree in 526 and differ in 26** (525 until OH printed frus1981-88v16's
    /// year at corpus cf8abf696) — `frus1950v01` prints 1977 and was
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

    /// The pauses before a header fetch that answered a 429 or a 5xx is tried again: 2, 4 and 8
    /// seconds, so four tries in all before its volume counts as failed (#2022, the owner's "retry
    /// a 429 or a 5xx a few times, with a pause"). L28's six 503s came from raw.githubusercontent.com
    /// at eight fetches at a time, and a run a few minutes later had none.
    static let retryPauses: [Duration] = [.seconds(2), .seconds(4), .seconds(8)]

    /// A volume of the listing that did not reach the manifest, and why.
    public struct VolumeFailure: Error, Sendable, Equatable, CustomStringConvertible {
        /// The volume's file name in the listing, `frus1961-63v20.xml`.
        public let filename: String
        /// What stopped it: the fetch's or the parse's error, or the listing entry's defect.
        public let reason: String

        /// The file name and the reason, as the refusal lists them.
        public var description: String { "\(filename): \(reason)" }
    }

    /// Everything that stops an online run, each before `manifest.json` is written.
    public enum RunError: Error, CustomStringConvertible {
        /// The GitHub listing of `volumes/` could not be read.
        case listingFailed(String)
        /// Volumes of the listing did not reach the manifest, so it was not written (#2022): how
        /// many the listing named, how many reached it, and each that did not, by file name.
        case incompleteListing(listed: Int, reached: Int, failures: [VolumeFailure], outputPath: String)
        /// The manifest could not be written.
        case writeFailed(String)

        /// What the run prints before it exits 1.
        public var description: String {
            switch self {
            case .listingFailed(let error):
                return "Failed to fetch GitHub listing: \(error)"
            case .incompleteListing(let listed, let reached, let failures, let outputPath):
                return "\(listed - reached) of the listing's \(listed) volumes did not reach the "
                    + "manifest, so nothing was written to \(outputPath) and the file there is as it "
                    + "was. Every generator after this one takes the manifest as the set of volumes "
                    + "that ship, and a file without these would take them out of the catalogue "
                    + "(#2022). A 429 or a 5xx was tried \(retryPauses.count + 1) times before it "
                    + "counted; run again."
                    + failures.map { "\n  \($0)" }.joined()
            case .writeFailed(let error):
                return "Failed to write manifest: \(error)"
            }
        }
    }

    private init() {}

    /// Runs the manifest generation pipeline.
    ///
    /// When `localVolumesDirectory` is non-nil, runs the offline **local overlay mode**
    /// (see the type doc-comment); otherwise runs the GitHub pipeline,
    /// ``runOnline(outputPath:concurrencyLimit:listing:fetchHeader:pause:)``, over the live
    /// listing and headers, and exits 1 when it throws.
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
        do {
            try await runOnline(
                outputPath: outputPath,
                concurrencyLimit: concurrencyLimit,
                listing: { try await GitHubClient().fetchVolumeEntries() },
                fetchHeader: { url in try await TEIHeaderFetcher.fetch(from: url) },
                pause: { duration in try? await Task.sleep(for: duration) })
        } catch {
            print("[ManifestGenerator] ✗ \(error)")
            exit(1)
        }
    }

    /// The GitHub pipeline, with its two network reads and its pause handed in, so a test can drive
    /// the whole run over a listing and a host of its own.
    ///
    /// **It writes the manifest only when every volume of the listing reached it (#2022).** Until
    /// row L61 a volume whose header fetch failed was logged, counted under `Errors:` and left out,
    /// and the run wrote the rest, said so and exited 0: L28's rehearsal of the release runbook
    /// (2026-11-26) lost six of 553 volumes that way, to HTTP 503, and every generator after this one
    /// takes the manifest as the set of volumes that ship. A fetch that answers a 429 or a 5xx is
    /// tried again after each of ``retryPauses`` first; a volume that still has no entry — its
    /// fetch, its parse or its listing entry failed — throws ``RunError/incompleteListing(listed:reached:failures:outputPath:)``,
    /// naming each, before anything is written.
    ///
    /// - Parameters:
    ///   - outputPath: Where to write `manifest.json`.
    ///   - concurrencyLimit: Maximum simultaneous volume fetches.
    ///   - listing: Reads the listing of `volumes/` (`GitHubClient.fetchVolumeEntries()`).
    ///   - fetchHeader: Reads one volume's `<teiHeader>` from its download URL
    ///     (`TEIHeaderFetcher.fetch(from:session:)`).
    ///   - pause: Waits before a fetch is tried again (`Task.sleep(for:)`).
    /// - Throws: ``RunError``.
    static func runOnline(
        outputPath: String,
        concurrencyLimit: Int,
        listing: () async throws -> [GitHubVolumeEntry],
        fetchHeader: @escaping @Sendable (URL) async throws -> Data,
        pause: @escaping @Sendable (Duration) async -> Void
    ) async throws {
        print("[ManifestGenerator] Starting manifest generation…")

        // 1. Fetch GitHub directory listing.
        let githubEntries: [GitHubVolumeEntry]
        do {
            githubEntries = try await listing()
        } catch {
            throw RunError.listingFailed(String(describing: error))
        }

        print("[ManifestGenerator] \(githubEntries.count) volumes to process.")

        // 2-4. Concurrently fetch + parse each volume's teiHeader.
        var manifestEntries: [VolumeManifestEntry] = []
        var failures: [VolumeFailure] = []

        await withTaskGroup(of: Result<VolumeManifestEntry, VolumeFailure>.self) { group in
            var inFlight = 0
            var iterator = githubEntries.makeIterator()

            // Seed the group with up to `concurrencyLimit` tasks.
            while inFlight < concurrencyLimit, let entry = iterator.next() {
                group.addTask {
                    await process(githubEntry: entry, fetchHeader: fetchHeader, pause: pause)
                }
                inFlight += 1
            }

            // As tasks complete, collect results and add more work.
            for await result in group {
                switch result {
                case .success(let entry): manifestEntries.append(entry)
                case .failure(let failure): failures.append(failure)
                }
                if let next = iterator.next() {
                    group.addTask {
                        await process(githubEntry: next, fetchHeader: fetchHeader, pause: pause)
                    }
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
          Errors:       \(failures.count)
        """)

        // A run that lost a volume writes nothing, rather than a catalogue without it (#2022). The
        // count is checked as well as the failures, so a volume left out by any other road refuses
        // too.
        guard failures.isEmpty, manifestEntries.count == githubEntries.count else {
            throw RunError.incompleteListing(
                listed: githubEntries.count, reached: manifestEntries.count,
                failures: failures.sorted { $0.filename < $1.filename }, outputPath: outputPath)
        }

        do {
            try ManifestWriter.write(entries: manifestEntries, to: outputPath)
        } catch {
            throw RunError.writeFailed(String(describing: error))
        }
        print("[ManifestGenerator] ✓ manifest.json written to \(outputPath)")
    }

    // MARK: - Local Overlay Mode

    /// The size of the file at `url` in bytes, following symbolic links; `nil` if it cannot be read.
    ///
    /// `FileManager.attributesOfItem(atPath:)` describes a symlink ITSELF, not its target, so
    /// reading it directly recorded the link's own few bytes for every volume FILE that is a
    /// symlink — measured, 51–65 bytes for the 552 linked volumes of the run that found it, with
    /// "Parse errors: 0" because the header parse reads through the link. A symlinked DIRECTORY
    /// was never affected: only the last path component is not followed. A link whose target is
    /// missing cannot be resolved and reports `nil`, never the link's own size. Every
    /// consumer that screens stubs by size (the ≥ 20,000-byte filters) would then hide the corpus.
    ///
    /// - Parameter url: A volume file, or a symlink to one.
    /// - Returns: The target's size in bytes, or `nil`.
    static func fileSize(at url: URL) -> Int? {
        // `resolvingSymlinksInPath()` returns a DANGLING link unchanged, and the attributes read
        // would then describe the link again — the very bug this exists to prevent. Refuse it.
        let resolved = url.resolvingSymlinksInPath()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: resolved.path),
              attributes[.type] as? FileAttributeType != .typeSymbolicLink else { return nil }
        return (attributes[.size] as? NSNumber)?.intValue
    }

    /// Offline pass that re-derives `publicationDate`, `dateRange`, `status`, `tags` and
    /// `sizeBytes` on each existing manifest entry from the local file — the fields it is
    /// authoritative for — preserving all other fields. (This said "ONLY publicationDate,
    /// dateRange and status" until two fields after #1284 made it false.)
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
            // strings nobody has asked to change; `subseries` and `volumeId` are parsed from the
            // filename, not the file. (A `documentCount`, 0 for all 553 entries because no header
            // carries one, was carried forward here until #1504 removed it from the manifest.)
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
                // The local file's own size, which is what the GitHub arm records for its copy.
                // Cosmetic on screen, but a manifest whose byte count disagrees with the file
                // beside it is a manifest a reader cannot use to check anything.
                sizeBytes: Self.fileSize(at: fileURL) ?? entry.sizeBytes,
                tags: header.tags
            )
            if newEntry != entry { changed += 1 }
            updated.append(newEntry)
        }

        print("""
        [ManifestGenerator] Overlay results:
          Entries:      \(updated.count)
          Changed:      \(changed)
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

    /// Reads one volume's header, trying it again after each of ``retryPauses`` while it answers a
    /// 429 or a 5xx (`TEIHeaderFetcher.isWorthRetrying(_:)`, #2022). Any other failure counts at
    /// once: a 404 or a header that is not there answers the same way every time.
    ///
    /// - Parameters:
    ///   - url: The volume's download URL.
    ///   - name: The volume's file name, for the log and the failure.
    ///   - fetch: Reads a `<teiHeader>` from a download URL.
    ///   - pause: Waits before a fetch is tried again.
    /// - Returns: The header's bytes, or the failure naming the last attempt's error.
    private static func readHeader(
        from url: URL,
        name: String,
        fetch: @Sendable (URL) async throws -> Data,
        pause: @Sendable (Duration) async -> Void
    ) async -> Result<Data, VolumeFailure> {
        var attempt = 1
        while true {
            do {
                return .success(try await fetch(url))
            } catch {
                guard TEIHeaderFetcher.isWorthRetrying(error), attempt <= retryPauses.count else {
                    let tries = attempt == 1 ? "" : " on all \(attempt) attempts"
                    print("[ManifestGenerator] ✗ Fetch failed for \(name)\(tries): \(error)")
                    return .failure(VolumeFailure(filename: name, reason: "fetch failed\(tries): \(error)"))
                }
                let wait = retryPauses[attempt - 1]
                print("[ManifestGenerator] ⚠︎ \(name): \(error) on attempt \(attempt) of "
                    + "\(retryPauses.count + 1); trying again in \(wait)")
                await pause(wait)
                attempt += 1
            }
        }
    }

    /// Fetches and parses a single volume's teiHeader: its manifest entry, or why it has none
    /// (logged as well).
    ///
    /// - Parameters:
    ///   - githubEntry: The volume's entry in the listing.
    ///   - fetchHeader: Reads a `<teiHeader>` from a download URL.
    ///   - pause: Waits before a fetch is tried again.
    /// - Returns: The entry, or the failure the refusal names.
    private static func process(
        githubEntry: GitHubVolumeEntry,
        fetchHeader: @Sendable (URL) async throws -> Data,
        pause: @Sendable (Duration) async -> Void
    ) async -> Result<VolumeManifestEntry, VolumeFailure> {
        guard let url = URL(string: githubEntry.downloadUrl) else {
            print("[ManifestGenerator] ✗ Invalid download URL for \(githubEntry.name)")
            return .failure(VolumeFailure(
                filename: githubEntry.name, reason: "invalid download URL \(githubEntry.downloadUrl)"))
        }

        // Parse filename → volumeId + subseries.
        guard let parsed = VolumeIDParser.parse(filename: githubEntry.name) else {
            print("[ManifestGenerator] ✗ Unrecognised filename pattern: \(githubEntry.name)")
            return .failure(VolumeFailure(
                filename: githubEntry.name, reason: "unrecognised filename pattern"))
        }

        // Fetch the teiHeader bytes, a 429 or a 5xx tried again (#2022).
        let headerData: Data
        switch await readHeader(from: url, name: githubEntry.name, fetch: fetchHeader, pause: pause) {
        case .success(let data): headerData = data
        case .failure(let failure): return .failure(failure)
        }

        // Parse the header.
        let header: ParsedTEIHeader
        do {
            header = try TEIHeaderParser.parse(headerData)
        } catch {
            print("[ManifestGenerator] ✗ Parse failed for \(githubEntry.name): \(error)")
            return .failure(VolumeFailure(filename: githubEntry.name, reason: "parse failed: \(error)"))
        }

        #if DEBUG
        print("[ManifestGenerator] ✓ \(parsed.volumeId) — \"\(header.title.prefix(60))…\" tags=\(header.tags.count)")
        #endif

        return .success(VolumeManifestEntry(
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
            sizeBytes: githubEntry.size,
            tags: header.tags
        ))
    }
}
