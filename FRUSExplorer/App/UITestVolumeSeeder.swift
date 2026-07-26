// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

#if DEBUG

// MARK: - UITestVolumeSeeder

/// Writes a tiny synthetic TEI volume into the volumes directory when a UI test asks for one.
///
/// ## Why this exists
/// Every XCUITest launches with `FRUS_UI_TEST_MODE=1` and no downloaded volumes, so the Browse
/// stack has always dead-ended at the Volume level ("Download Required"). Everything below it —
/// the compilation document list, the document reader — was untestable, which is exactly the gap
/// R-9's defect was able to hide in: "Index Required" on an indexed volume shipped because no UI
/// test could reach a compilation at all.
///
/// The alternative was downloading a real volume during the test (the smallest published volume,
/// `frus1961-63v06`, is 1.65 MB). That was rejected: it makes a UI test depend on GitHub being
/// reachable and on multi-second network timing, and it would still need this same env-var seam
/// to know which volume to fetch. A hand-written fixture is offline, deterministic, and ~2 KB.
///
/// ## Contract
/// Gated twice over: the whole file is `#if DEBUG` (so it is absent from AppStore and
/// DirectDistribution builds), and it does nothing unless `FRUS_UI_TEST_SEED_VOLUME` names a
/// volume. The value must be a volume ID that exists in the bundled manifest — the browser lists
/// volumes from the manifest, so a made-up ID would be seeded to disk and never appear.
///
/// The fixture is rewritten on every launch that requests it. That is deliberate: the UI-test
/// store lives on disk and survives between runs, so a stale fixture from an older revision would
/// otherwise persist (already indexed) into a run that expects the current one.
///
/// Version history:
///   1.0 — Wave R / R-9: initial implementation
enum UITestVolumeSeeder {

    /// The launch-environment key a UI test sets to request seeding. The value is the volume ID.
    static let environmentKey = "FRUS_UI_TEST_SEED_VOLUME"

    /// The `<head>` of the single compilation in the fixture. UI tests match on this, and it is
    /// deliberately not plausible as real FRUS content — nobody should mistake a seeded volume
    /// for a downloaded one.
    static let compilationTitle = "UI Test Compilation"

    /// The `<head>` values of the fixture's documents, in order.
    static let documentTitles = [
        "UI Test Document One",
        "UI Test Document Two",
        "UI Test Document Three",
    ]

    /// Seeds the fixture volume into `volumesDirectory` if `FRUS_UI_TEST_SEED_VOLUME` is set.
    ///
    /// Called from `bootDownloadManager()` before the `IndexingPipeline` is constructed, so the
    /// file is on disk by the time anything reads the directory.
    ///
    /// - Parameter volumesDirectory: The app's volumes directory (`…/FRUSExplorer/Volumes`).
    /// - Returns: The seeded volume ID, or `nil` when no seeding was requested.
    @discardableResult
    static func seedIfRequested(in volumesDirectory: URL) -> String? {
        guard let volumeId = ProcessInfo.processInfo.environment[environmentKey],
              !volumeId.isEmpty else { return nil }

        let url = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        do {
            try fixtureXML(volumeId: volumeId).write(to: url, atomically: true, encoding: .utf8)
            print("[UITestVolumeSeeder] Seeded \(volumeId) at \(url.path)")
            return volumeId
        } catch {
            print("[UITestVolumeSeeder] Failed to seed \(volumeId): \(error)")
            return nil
        }
    }

    /// The fixture's TEI XML — one compilation holding ``documentTitles``.
    ///
    /// Shaped after the minimal volume the `IndexingPipelineTests` helpers write: a `teiHeader`
    /// and a `<div type="compilation">` of `<div type="document">` children, each with a `<head>`
    /// and a `<p>`. That is the whole of what `parseVolumeStructure` and `indexVolume` need.
    static func fixtureXML(volumeId: String) -> String {
        let docs = documentTitles.enumerated().map { index, title in
            """
                  <div type="document" xml:id="d\(index + 1)">
                    <head>\(title)</head>
                    <dateline>Washington, January \(index + 1), 1962</dateline>
                    <p>Synthetic UI-test content for \(volumeId), document \(index + 1).</p>
                  </div>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>1996</date></publicationStmt>
          <sourceDesc><p>UI test fixture — not real FRUS content.</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="compilation" xml:id="uitestcomp">
              <head>\(compilationTitle)</head>
        \(docs)
            </div>
          </body></text>
        </TEI>
        """
    }
}

#endif
