// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if DEBUG
import Foundation

// MARK: - The index volume (Lane 2 of the editors' annotations follow-ups plan)

/// One catalogue volume, `frus1932v04`, written small, for the UI suite that taps a "See" link in
/// a back-of-volume index (`IndexSeeLinkTests`).
///
/// ## Why the browse fixture cannot carry that suite
/// Seven suites stand on the browse fixture's shape, and a back-matter index added to it would
/// change the volume page every one of them walks. This volume is written beside it, under a
/// catalogue id so that Browse lists it by its subseries, as the real 1932 IV, whose Index is the
/// plan's example ("Aviation. *See under* China"), and removed by any launch that does not ask for
/// it, so the four suites that count on exactly one downloaded volume never see it.
///
/// ## Its shape
/// One document in one compilation, so the volume indexes and `-frus.filterDownloadedOnly` lists
/// it, and a back-matter Index as the corpus encodes one (`type="section" subtype="index"`,
/// `<list type="index">`): "Aviation. *See under* China" with `<ref target="#in2">` second, eighty
/// filler entries, and then `<item xml:id="in2">China (see also …)</item>`, far below the fold on
/// an iPhone and an iPad alike, so a run can see the scroll.
///
/// ## Contract — the spoken-row volume's own
/// `#if DEBUG`, and inert unless `FRUS_UI_TEST_SEED_INDEX_VOLUME` is `1`. A launch that asks writes
/// the file and indexes it before the pipeline is published; **any launch that does not ask
/// removes the file and its index rows**.
///
/// Version history:
///   1.0 — 2026-11-08: Lane 2 of the follow-ups plan
extension UITestVolumeSeeder {

    /// The launch-environment key a UI test sets, to `1`, to request the index volume.
    static let indexVolumeEnvironmentKey = "FRUS_UI_TEST_SEED_INDEX_VOLUME"

    /// The volume's id: a catalogue volume's, 1932 IV, whose real Index is the plan's example.
    static let indexVolumeId = "frus1932v04"

    /// The entries before the one the "See" link names: enough that the entry sits far below the
    /// fold on an iPad's 13-inch screen.
    static let indexFillerEntries = 80

    /// Writes the volume when `FRUS_UI_TEST_SEED_INDEX_VOLUME` is `1`, and removes it when it is
    /// not. Called from `bootDownloadManager()` beside the spoken-row volume, before the pipeline is
    /// built.
    ///
    /// - Parameter volumesDirectory: The app's volumes directory.
    /// - Returns: Whether a file was written or removed.
    @discardableResult
    static func prepareIndexVolumeIfRequested(in volumesDirectory: URL) -> Bool {
        prepareIndexVolume(
            requested: ProcessInfo.processInfo.environment[indexVolumeEnvironmentKey] == "1",
            in: volumesDirectory)
    }

    /// ``prepareIndexVolumeIfRequested(in:)`` with the environment read lifted out, so a test can
    /// drive both arms.
    ///
    /// - Parameters:
    ///   - requested: Whether this launch asked for the volume.
    ///   - volumesDirectory: The app's volumes directory.
    /// - Returns: Whether a file was written (requested) or removed (not requested).
    @discardableResult
    static func prepareIndexVolume(requested: Bool, in volumesDirectory: URL) -> Bool {
        let url = volumesDirectory.appendingPathComponent("\(indexVolumeId).xml")
        if requested {
            let written = (try? indexVolumeXML().write(to: url, atomically: true, encoding: .utf8)) != nil
            if written { print("[UITestVolumeSeeder] Seeded the index volume") }
            return written
        }
        guard FileManager.default.fileExists(atPath: url.path),
              (try? FileManager.default.removeItem(at: url)) != nil else { return false }
        print("[UITestVolumeSeeder] Removed the index volume")
        return true
    }

    /// The volume's TEI: a header, one document in one compilation, and a back-matter Index whose
    /// second entry sends the reader to an entry eighty entries further down.
    static func indexVolumeXML() -> String {
        let filler = (1...indexFillerEntries).map { n in
            """
                    <item>UI Test Index Entry \(n), <ref target="#pg_\(n)">\(n)</ref></item>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>UI Test Index Volume</title></titleStmt>
          <publicationStmt><date>1948</date></publicationStmt>
          <sourceDesc><p>UI test fixture — not real FRUS content.</p></sourceDesc></fileDesc></teiHeader>
          <text>
            <body>
              <div type="compilation" xml:id="comp1">
                <head>UI Test Index Compilation</head>
                <div type="document" xml:id="d1" n="1">
                  <head>1. UI Test Index Document</head>
                  <dateline>Tokyo, January 4, 1932</dateline>
                  <p>Index fixture, the one document.</p>
                </div>
              </div>
            </body>
            <back>
              <div type="section" subtype="index" xml:id="index">
                <head>Index</head>
                <list type="index">
                  <item>Agreements. <hi rend="italic">See</hi> <ref target="#in1">Treaties, conventions, etc.</ref></item>
                  <item>Aviation. <hi rend="italic">See under</hi> <ref target="#in2">China</ref>: <ref target="#in8">Political situation</ref>.</item>
        \(filler)
                  <item xml:id="in2">China (<hi rend="italic">see also</hi> Sino-Japanese dispute), <ref target="#pg_1">1</ref>–<ref target="#pg_463">463</ref></item>
                  <item xml:id="in8">Political situation in China, <ref target="#pg_20">20</ref></item>
                  <item xml:id="in1">Treaties, conventions, etc., <ref target="#pg_100">100</ref>–<ref target="#pg_200">200</ref></item>
                </list>
              </div>
            </back>
          </text>
        </TEI>
        """
    }

    /// Brings the volume's index rows to what this launch asked for, before `AppState` publishes the
    /// pipeline: indexed when asked for and not yet indexed, removed when not asked for and still
    /// there.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline boot just built and has not yet published.
    ///   - requested: Whether this launch asked for the volume. Boot passes nothing and gets the
    ///     launch environment's answer; a test passes each answer in turn.
    static func prepareIndexVolumeIndex(
        pipeline: IndexingPipeline,
        requested: Bool = ProcessInfo.processInfo.environment[indexVolumeEnvironmentKey] == "1"
    ) async {
        let indexed = (try? pipeline.isVolumeIndexed(indexVolumeId)) == true
        switch StorageRowIndexAction.plan(requested: requested, indexed: indexed) {
        case .index:
            try? await pipeline.indexVolume(indexVolumeId)
        case .unindex:
            try? await pipeline.removeVolume(indexVolumeId)
        case .none:
            break
        }
    }
}
#endif
