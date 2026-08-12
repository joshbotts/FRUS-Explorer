// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import GeneratorKit

// MARK: - VolumeSummary

/// The per-volume `detected/<volume>.head.json` this tool writes.
///
/// Field names and semantics mirror `harvest_ner.py`'s summary exactly, because
/// `score_detections.py` reads both: `sampled` plus `sampled_doc_ids` is how a scorer knows which
/// documents a detector actually looked at, and a store that sampled without saying which is
/// refused rather than scored.
public struct VolumeSummary: Codable, Sendable {

    /// Volume id.
    public let volume: String

    /// The detector's identity, including the OS build — `NLTagger`'s output is a property of the
    /// system it ran on, so a store without this cannot be compared across machines.
    public let model: String

    /// Whether only some of the volume's documents were scanned.
    public let sampled: Bool

    /// Which documents, when `sampled`. Absent for a full pass, where the answer is all of them.
    public let sampledDocIds: [String]?

    /// Documents scanned.
    public let docsScanned: Int

    /// Documents in the volume's text layer.
    public let docsInVolume: Int

    /// Characters (code points) scanned.
    public let charsScanned: Int

    /// Mentions detected.
    public let mentions: Int

    /// Detections that overlap an editor `<persName>` span.
    public let overlappingMarked: Int

    /// Detections that do not — the whole point of running a detector at all.
    public let novel: Int

    /// Editor spans in the scanned documents, the denominator for `overlappingMarked`.
    public let markedInScannedDocs: Int

    /// Whether the tagger's language was pinned to English.
    public let forcedEnglish: Bool

    /// Wall-clock seconds.
    public let secs: Double

    private enum CodingKeys: String, CodingKey {
        case volume, model, sampled
        case sampledDocIds = "sampled_doc_ids"
        case docsScanned = "docs_scanned"
        case docsInVolume = "docs_in_volume"
        case charsScanned = "chars_scanned"
        case mentions
        case overlappingMarked = "overlapping_marked"
        case novel
        case markedInScannedDocs = "marked_in_scanned_docs"
        case forcedEnglish = "forced_english"
        case secs
    }
}

// MARK: - RunManifest

/// Store-level provenance for a control run.
public struct RunManifest: Codable, Sendable {

    /// Date stamp (`GENERATED_DATE`-overridable, so a run is reproducible in CI).
    public let generated: String

    /// The detector, with the OS build it ran on.
    public let model: String

    /// The full operating-system version string.
    public let operatingSystem: String

    /// The tagger options, spelled out — they are part of the contract, not an implementation
    /// detail, and a run under different options is a different detector.
    public let taggerOptions: [String]

    /// Whether language was pinned to English.
    public let forcedEnglish: Bool

    /// Where the R-0 text came from.
    public let textDir: String

    /// The NER store whose scope and marked layer were read.
    public let store: String

    /// The ground-truth file that restricted the run, when one did.
    public let onlyDocuments: String?

    /// Volumes requested.
    public let volumesRequested: Int

    /// Volumes with no text layer, named rather than counted.
    public let volumesMissing: [String]

    /// Totals across the run.
    public let totals: Totals

    /// Run totals.
    public struct Totals: Codable, Sendable {
        /// Documents scanned.
        public let docs: Int
        /// Characters scanned.
        public let chars: Int
        /// Mentions detected.
        public let mentions: Int
        /// Detections overlapping an editor span.
        public let overlappingMarked: Int
        /// Wall-clock seconds.
        public let secs: Double

        private enum CodingKeys: String, CodingKey {
            case docs, chars, mentions
            case overlappingMarked = "overlapping_marked"
            case secs
        }
    }

    private enum CodingKeys: String, CodingKey {
        case generated, model
        case operatingSystem = "operating_system"
        case taggerOptions = "tagger_options"
        case forcedEnglish = "forced_english"
        case textDir = "text_dir"
        case store
        case onlyDocuments = "only_documents"
        case volumesRequested = "volumes_requested"
        case volumesMissing = "volumes_missing"
        case totals
    }
}

// MARK: - EarlyEraNERControlRunner

/// The `NLTagger` control pass over the #234 R-1 scope — the free baseline an LLM detector has to
/// beat before it earns a sweep.
///
/// It writes the same `detected/` layer `harvest_ner.py` writes, into its own store, so
/// `score_detections.py` scores the two side by side with no adapter in between. It reads the R-0
/// text layer rather than the TEI, which is what makes its offsets the same offsets as the marked
/// layer's and the chunk vectors' by construction rather than by agreement.
///
/// What it does NOT do: identity, roles, dates, confidence. This pass answers "where in the text is
/// a person named" and nothing else, exactly like the LLM route it is the control for.
///
/// **What is reproducible and what is not.** `detected/<volume>.jsonl` is byte-identical across
/// runs on one OS build — rows sort on `(ordinal, start, end)`, mirroring `harvest_ner.py`, and no
/// dictionary iteration reaches the output. `head.json` and `run-manifest.json` are not: they carry
/// `secs`, `generated` and `operating_system` by design. Diff the `.jsonl` layer, not the heads,
/// when checking the recogniser for drift — and remember that a different OS build is a different
/// detector, which is why the build is recorded in both.
///
/// Environment:
///   - `STORE` — the NER store with `scope.json` + `marked/` (default `~/frus-ner-raw`)
///   - `TEXT_DIR` — the embeddings store's `text/` (default `~/frus-semantic-raw/text`)
///   - `OUT_DIR` — where this store is written (default `~/frus-ner-raw-control`)
///   - `VOLUMES` — comma-separated ids, overriding the derived scope
///   - `ONLY_DOCUMENTS` — an `m2a-ground-truth.jsonl`, restricting the run to annotated documents
///   - `LANGUAGE` — `english` (default) or `auto`
///   - `GENERATED_DATE` — date-stamp override
///
/// Version history:
///   1.0 — Session 2026-08-11: #234 R-1 control detector.
public enum EarlyEraNERControlRunner {

    /// Runs the control pass.
    ///
    /// - Parameter environment: Process environment; injectable so the test target can drive it.
    /// - Throws: ``DetectorError`` for absent inputs and corrupt spans; file-system errors as-is.
    public static func run(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        // Tilde expansion happens HERE, not in the shell: `STORE=~/x swift run …` passes a
        // literal `~` (the shell does not expand after `=` in an assignment prefix), and the
        // doc comment above advertises `~/`-shaped defaults, so an operator will type one.
        func path(_ key: String, _ fallback: String) -> String {
            ((environment[key] ?? fallback) as NSString).expandingTildeInPath
        }
        let home = NSHomeDirectory()
        let store = URL(fileURLWithPath: path("STORE", home + "/frus-ner-raw"))
        let textDir = URL(fileURLWithPath: path("TEXT_DIR", home + "/frus-semantic-raw/text"))
        let outDir = URL(fileURLWithPath: path("OUT_DIR", home + "/frus-ner-raw-control"))
        let forceEnglish = path("LANGUAGE", "english").lowercased() != "auto"

        // A mistyped STORE is not detectable later: `markedLayer` returns [] for an absent file
        // — correct for a volume the harvest skipped — so the run would finish clean and report
        // 100% of its detections as novel. Check the directory once, up front.
        var isDirectory: ObjCBool = false
        let markedDir = store.appendingPathComponent("marked")
        guard FileManager.default.fileExists(atPath: markedDir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DetectorError.missingInput(markedDir.path
                + " — set STORE to the NER store harvest_ner.py wrote (N-1)")
        }

        let detectedDir = outDir.appendingPathComponent("detected")
        try FileManager.default.createDirectory(at: detectedDir, withIntermediateDirectories: true)

        var volumes: [String]
        if let explicit = environment["VOLUMES"], !explicit.isEmpty {
            volumes = explicit.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            volumes = try NERStoreIO.scopeVolumes(store: store)
        }

        var onlyDocuments: [String: Set<String>]?
        if let groundTruth = environment["ONLY_DOCUMENTS"], !groundTruth.isEmpty {
            let restricted = try NERStoreIO.groundTruthDocuments(
                at: URL(fileURLWithPath: (groundTruth as NSString).expandingTildeInPath))
            onlyDocuments = restricted
            volumes = volumes.filter { restricted[$0] != nil }
            generatorLog("ONLY_DOCUMENTS: \(volumes.count) volume(s) named by the ground truth")
        }

        let detector = PersonMentionDetector(forceEnglish: forceEnglish)
        var missing: [String] = []
        var totalDocs = 0, totalChars = 0, totalMentions = 0, totalOverlap = 0
        let runStarted = Date()

        for (index, volume) in volumes.enumerated() {
            let headURL = detectedDir.appendingPathComponent(volume + ".head.json")
            if FileManager.default.fileExists(atPath: headURL.path) {
                continue                              // resume: a finished volume is not redone
            }
            let started = Date()
            let documents: [TextLayerDocument]
            do {
                documents = try NERStoreIO.textLayer(volume: volume, in: textDir)
            } catch DetectorError.missingInput(let missingPath) {
                generatorLog("  !! no text layer, skipped: \(missingPath)")
                missing.append(volume)
                continue
            }
            let wanted = onlyDocuments?[volume]
            let scanned: [TextLayerDocument]
            if let wanted {
                scanned = documents.filter { wanted.contains($0.id) }
                // A requested document the text layer does not hold is a corpus mismatch, and
                // `sampled_doc_ids` would otherwise record the found set — letting the scorer
                // treat an incomplete pass as a complete one. Name them.
                let absent = wanted.subtracting(scanned.map(\.id)).sorted()
                if !absent.isEmpty {
                    generatorLog("  !! \(volume): \(absent.count) ground-truth document(s) "
                                 + "not in the text layer: \(absent.joined(separator: ", "))")
                }
            } else {
                scanned = documents
            }

            let marked = try NERStoreIO.markedLayer(
                volume: volume, in: store.appendingPathComponent("marked"))
            var markedByDocument: [String: [(start: Int, end: Int)]] = [:]
            for mention in marked {
                markedByDocument[mention.document, default: []].append((mention.start, mention.end))
            }

            var rows: [DetectedRow] = []
            var overlap = 0
            var markedInScanned = 0
            var chars = 0
            for document in scanned {
                chars += document.text.unicodeScalars.count
                let spans = markedByDocument[document.id] ?? []
                markedInScanned += spans.count
                for mention in try detector.mentions(in: document.text) {
                    rows.append(DetectedRow(document: document.id, ordinal: document.ordinal,
                                            start: mention.start, end: mention.end,
                                            surface: mention.surface))
                    if spans.contains(where: { mention.start < $0.end && $0.start < mention.end }) {
                        overlap += 1
                    }
                }
            }
            rows.sort { ($0.ordinal, $0.start, $0.end) < ($1.ordinal, $1.start, $1.end) }

            try NERStoreIO.writeDetected(
                rows, to: detectedDir.appendingPathComponent(volume + ".jsonl"))
            let elapsed = Date().timeIntervalSince(started)
            let summary = VolumeSummary(
                volume: volume, model: modelIdentity(), sampled: wanted != nil,
                sampledDocIds: wanted == nil ? nil : scanned.map(\.id).sorted(),
                docsScanned: scanned.count, docsInVolume: documents.count, charsScanned: chars,
                mentions: rows.count, overlappingMarked: overlap, novel: rows.count - overlap,
                markedInScannedDocs: markedInScanned, forcedEnglish: forceEnglish,
                secs: (elapsed * 10).rounded() / 10)
            // head.json is written LAST: its presence is the done marker, so a run killed
            // mid-volume redoes that volume and no other.
            try NERStoreIO.encodeJSON(summary).write(to: headURL)

            totalDocs += scanned.count
            totalChars += chars
            totalMentions += rows.count
            totalOverlap += overlap
            // Interpolation rather than String(format:): %d takes 32 bits and every count here
            // is a 64-bit Int, which is a silently-wrong-number bug rather than a compile error.
            let label = volume + String(repeating: " ", count: max(0, 22 - volume.count))
            generatorLog("[\(index + 1)/\(volumes.count)] \(label) \(scanned.count) docs  "
                         + "\(rows.count) mentions  \(rows.count - overlap) novel  "
                         + "\(((elapsed * 10).rounded() / 10))s")
        }

        if totalMentions > 0 && totalOverlap == 0 {
            // Not reachable on real input: the editors marked 253,919 names in this scope, and a
            // detector that agreed with none of them read a different corpus than the marked
            // layer describes. Loud, because the run otherwise looks like a success.
            generatorLog("!! WARNING: \(totalMentions) mentions and NOT ONE overlaps an editor "
                         + "<persName>. Check STORE and TEXT_DIR name the same harvest.")
        }

        // Totals are re-derived from EVERY head.json in the store, not from this invocation's
        // counters: the resume path skips finished volumes without counting them, so a run
        // killed at volume 200 and resumed would otherwise overwrite a complete manifest with
        // the 68 volumes of the second invocation and read as a much smaller corpus.
        var storedDocs = 0, storedChars = 0, storedMentions = 0, storedOverlap = 0
        let decoder = JSONDecoder()
        let heads = (try? FileManager.default.contentsOfDirectory(atPath: detectedDir.path)) ?? []
        for name in heads.sorted() where name.hasSuffix(".head.json") {
            guard let data = try? Data(contentsOf: detectedDir.appendingPathComponent(name)),
                  let head = try? decoder.decode(VolumeSummary.self, from: data) else { continue }
            storedDocs += head.docsScanned
            storedChars += head.charsScanned
            storedMentions += head.mentions
            storedOverlap += head.overlappingMarked
        }

        let totalSeconds = Date().timeIntervalSince(runStarted)
        let manifest = RunManifest(
            generated: generatorDateStamp(override: environment["GENERATED_DATE"]),
            model: modelIdentity(),
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            taggerOptions: ["omitPunctuation", "omitWhitespace", "omitOther", "joinNames"],
            forcedEnglish: forceEnglish, textDir: textDir.path, store: store.path,
            onlyDocuments: environment["ONLY_DOCUMENTS"],
            volumesRequested: volumes.count, volumesMissing: missing,
            totals: RunManifest.Totals(docs: storedDocs, chars: storedChars,
                                       mentions: storedMentions, overlappingMarked: storedOverlap,
                                       secs: (totalSeconds * 10).rounded() / 10))
        try NERStoreIO.encodeJSON(manifest)
            .write(to: outDir.appendingPathComponent("run-manifest.json"))

        generatorLog("""
            control pass: \(storedDocs) documents, \(storedMentions) mentions \
            (\(storedMentions - storedOverlap) beyond the editors' markup) in the store; \
            \(totalDocs) this invocation -> \(outDir.path)
            """)
    }

    /// The detector's identity string, OS build included.
    ///
    /// `NLTagger` is a closed-source recogniser that ships with the system, so its output is a
    /// property of the machine as much as of the input. A store that did not record this could be
    /// compared against a run from another OS release and silently attribute the difference to the
    /// corpus.
    ///
    /// - Returns: e.g. `NLTagger nameType (macOS Version 15.5.0 …)`.
    public static func modelIdentity() -> String {
        "NLTagger nameType (\(ProcessInfo.processInfo.operatingSystemVersionString))"
    }
}
