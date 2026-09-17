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
/// The fixture is rewritten on every launch that requests it. That is deliberate: the volumes
/// directory and the search index live on disk and survive between runs (only SwiftData is in
/// memory under `FRUS_UI_TEST_MODE`), so a stale fixture from an older revision would otherwise
/// persist (already indexed) into a run that expects the current one.
///
/// **Rewriting the XML is only half of that, and #1301 paid for the other half.** The *index*
/// survives too, and `BrowserViewModel.loadVolumeStructure` prefers the structure persisted in
/// `volume_structures` at index time over parsing the file. So a warm simulator went on serving
/// the OLD structure from a NEW fixture: measured on iPhone 17 (iOS 26.5), the nested chapter this
/// revision added was simply absent from the compilation's Sections list, and the suite failed for
/// a reason it was not about. ``seedIfRequested(in:)`` therefore compares what it is about to write
/// against what is there and reports ``SeedResult/contentChanged``; `FRUSExplorerApp` re-indexes
/// that one volume when it is `true`.
///
/// **Re-indexing the one volume, not deleting the index.** A developer's simulator is not a clean
/// room — the one this was measured on carried a 115 MB index over thirteen real volumes beside the
/// 2 KB fixture — so deleting the database to refresh a fixture would throw away work that has
/// nothing to do with the fixture. `indexVolume(_:)` upserts the volume's rows and deletes the ones
/// that vanished from its TEI, which is exactly and only what a changed fixture needs.
///
/// ## The nested branch (#1301)
/// Since #1301 the compilation also carries a **chapter inside a subchapter**, because the
/// defect that issue reports is only reachable below the first compilation level. On an iPad
/// two-pane Browse the detail pane *renders* the deepest path element in place, so stepping
/// `.compilation → .compilation` reuses one `CompilationView` instance and an unkeyed `.task`
/// never re-runs. The flat fixture could not express that: `uitestcomp` is reached by a
/// `.volume → .compilation` step, which crosses `levelView`'s switch branches and therefore
/// builds a fresh view every time.
///
/// The branch mirrors `frus1945Malta`'s real shape, measured from the TEI: `comp3` (0 direct
/// documents, 2 subsections) → `ch8` (0 direct documents, 7 subsections) → `ch11` (8 documents,
/// 0 subsections). ``chapterTitle`` is the middle rung and holds **no documents of its own**, so
/// a completed load renders "No documents in this section." there — the fingerprint that
/// distinguishes a load that ran and found nothing from a load that never ran at all.
///
/// The compilation keeps its three direct documents unchanged, so `CompilationDocumentsTests`
/// and `TwoPaneDocumentTests` see exactly what they saw before. The nested titles are chosen so
/// that none of them contains another as a substring: the suites match with
/// `CONTAINS[c]`, and "UI Test Nested Document One" does not contain "UI Test Document One".
///
/// Version history:
///   1.0 — Wave R / R-9: initial implementation
///   1.1 — #1301: the fixture grows a nested chapter → subchapter branch so a UI test can step
///          `.compilation → .compilation` twice. Adds ``chapterTitle``, ``subchapterTitle`` and
///          ``nestedDocumentTitles`` (2 documents); the three existing documents and
///          ``compilationTitle`` are unchanged, so the two suites that already read this fixture
///          are unaffected. Seeding also reports whether the fixture's bytes changed, because the
///          persisted `volume_structures` row outlived the file it described.
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

    /// The `<head>` of the chapter nested inside ``compilationTitle`` (#1301).
    ///
    /// Holds **no documents of its own** — only ``subchapterTitle`` — so reaching it and seeing
    /// "No documents in this section." proves a load completed here rather than never starting.
    static let chapterTitle = "UI Test Chapter"

    /// The `<head>` of the subchapter nested inside ``chapterTitle`` (#1301). This is the leaf
    /// that holds ``nestedDocumentTitles``, two compilation levels below the first.
    static let subchapterTitle = "UI Test Subchapter"

    /// The `<head>` values of the documents inside ``subchapterTitle``, in order (#1301).
    ///
    /// Deliberately not substrings of ``documentTitles``: the UI suites match rows with
    /// `CONTAINS[c]`, and "Nested UI Test Document One" *would* have matched a query for
    /// "UI Test Document One" while this spelling does not.
    static let nestedDocumentTitles = [
        "UI Test Nested Document One",
        "UI Test Nested Document Two",
    ]

    /// What a seeding run did, so the caller can act on a fixture whose shape changed.
    ///
    /// Version history:
    ///   1.0 — #1301: initial implementation
    struct SeedResult {
        /// The volume ID that was seeded.
        let volumeId: String
        /// `true` when the bytes written differ from the bytes that were already there — the
        /// signal that anything indexed from the previous fixture is now stale.
        let contentChanged: Bool
    }

    /// Seeds the fixture volume into `volumesDirectory` if `FRUS_UI_TEST_SEED_VOLUME` is set.
    ///
    /// Called from `bootDownloadManager()` before the `IndexingPipeline` is constructed, so the
    /// file is on disk by the time anything reads the directory.
    ///
    /// - Parameter volumesDirectory: The app's volumes directory (`…/FRUSExplorer/Volumes`).
    /// - Returns: The result, or `nil` when no seeding was requested or the write failed.
    @discardableResult
    static func seedIfRequested(in volumesDirectory: URL) -> SeedResult? {
        guard let volumeId = ProcessInfo.processInfo.environment[environmentKey],
              !volumeId.isEmpty else { return nil }

        let url = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        let fixture = fixtureXML(volumeId: volumeId)
        // Compared BEFORE the write: `write(to:atomically:)` replaces the file unconditionally, so
        // afterwards there is nothing left to compare against.
        let changed = (try? String(contentsOf: url, encoding: .utf8)) != fixture

        do {
            try fixture.write(to: url, atomically: true, encoding: .utf8)
            print("[UITestVolumeSeeder] Seeded \(volumeId) at \(url.path)"
                  + (changed ? " — content CHANGED, a re-index is owed" : " — unchanged"))
            return SeedResult(volumeId: volumeId, contentChanged: changed)
        } catch {
            print("[UITestVolumeSeeder] Failed to seed \(volumeId): \(error)")
            return nil
        }
    }

    /// The fixture's TEI XML — one compilation holding ``documentTitles`` **and** the #1301
    /// chapter → subchapter branch holding ``nestedDocumentTitles``.
    ///
    /// Shaped after the minimal volume the `IndexingPipelineTests` helpers write: a `teiHeader`
    /// and a `<div type="compilation">` of `<div type="document">` children, each with a `<head>`
    /// and a `<p>`. That is the whole of what `parseVolumeStructure` and `indexVolume` need.
    ///
    /// The chapter is the **last** child of the compilation, after its three documents, because
    /// that is the order the real corpus uses and `FRUSDocumentParser.popFrame` builds
    /// `documentIds` (direct children) and `subsections` (nested `<div>`s) independently of it.
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

        let nestedDocs = nestedDocumentTitles.enumerated().map { index, title in
            """
                      <div type="document" xml:id="n\(index + 1)">
                        <head>\(title)</head>
                        <dateline>Washington, February \(index + 1), 1962</dateline>
                        <p>Synthetic UI-test content for \(volumeId), nested document \(index + 1).</p>
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
              <div type="chapter" xml:id="uitestchapter">
                <head>\(chapterTitle)</head>
                <div type="subchapter" xml:id="uitestsubchapter">
                  <head>\(subchapterTitle)</head>
        \(nestedDocs)
                </div>
              </div>
            </div>
          </body></text>
        </TEI>
        """
    }
}

#endif
