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
///   1.2 — #1301 round 2: a THIRD rung, ``twinSubchapterTitle``, whose `<head>` is byte-identical
///          to its own parent's under a different `xml:id` — the one shape that distinguishes a
///          load keyed on the section's cache key from one keyed on its title, which no other
///          fixture and no volume in the local corpus can. ``seed(volumeId:in:)`` lifts the
///          environment lookup out of ``seedIfRequested(in:)`` so the change-detection this file
///          exists to report has tests of its own.
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

    /// The `<head>` of the section nested inside ``subchapterTitle`` — **byte-identical to its own
    /// parent's head**, under a different `xml:id` (#1301 round 2).
    ///
    /// This is the one shape that tells a load key from a look-alike. A task keyed on
    /// `section.title` rather than on the section's cache key passed every test #1301 shipped,
    /// because no two sections the suite steps between share a title; stepping from a section into
    /// a child with the SAME head leaves such a key unchanged, so the task never re-runs and the
    /// child shows the parent's state for ever — #1301 exactly, from a different cause.
    ///
    /// Measured against the local corpus before it was written: of 744 TEI volumes, **0** hold a
    /// section whose `<head>` equals an ancestor's, while **71** hold two sections sharing a head
    /// elsewhere in the volume. So this fixture pins the contract rather than reproducing a
    /// shipping defect — the corpus has not yet published the volume that would.
    static let twinSubchapterTitle = subchapterTitle

    /// The `<head>` of the one document inside ``twinSubchapterTitle`` (#1301 round 2). Not a
    /// substring of any other fixture title, for the `CONTAINS[c]` reason above.
    static let twinDocumentTitle = "UI Test Twin Document"

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
        return seed(volumeId: volumeId, in: volumesDirectory)
    }

    /// Writes the fixture for `volumeId`, reporting whether its bytes changed.
    ///
    /// ``seedIfRequested(in:)`` with the one environment lookup lifted out, so the part with the
    /// logic in it can be called from a test: a Swift Testing run cannot set its own process
    /// environment, and ``SeedResult/contentChanged`` — the signal `FRUSExplorerApp` re-indexes
    /// on — had no test at all until #1301 round 2. A mutation that made it always `false` left
    /// every suite in both targets green, because the run it breaks is the NEXT one, on a machine
    /// where the fixture last changed.
    ///
    /// - Parameters:
    ///   - volumeId: The volume ID to seed. Must exist in the bundled manifest to be browsable.
    ///   - volumesDirectory: Where to write it.
    /// - Returns: The result, or `nil` when the write failed.
    @discardableResult
    static func seed(volumeId: String, in volumesDirectory: URL) -> SeedResult? {
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
                  <div type="subchapter" xml:id="uitestsubchaptertwin">
                    <head>\(twinSubchapterTitle)</head>
                    <div type="document" xml:id="t1">
                      <head>\(twinDocumentTitle)</head>
                      <dateline>Washington, March 1, 1962</dateline>
                      <p>Synthetic UI-test content for \(volumeId), twin document.</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </body></text>
        </TEI>
        """
    }
}

// MARK: - Storage rows (#1356, #1357)

/// Five extra volume files for the storage hub's full volume list, and their removal afterwards.
///
/// `VolumeRemovalTests` needs a row in the MIDDLE of *Volumes on This Device* — rows on both sides
/// of it, so a confirmation anchored to the whole list cannot land beside the swiped row by
/// accident — and it removes one of them. The browse fixture above cannot serve: it is one file,
/// and three suites stand on its being there.
///
/// ## Why these ids are not in the manifest
/// Every browse surface enumerates the catalogue, and three suites launch with
/// `-frus.filterDownloadedOnly YES` counting on exactly ONE downloaded volume. A catalogue id here
/// would put five more rows in their Browse. An id the catalogue does not know is read as
/// side-loaded instead (`LocalVolumeCatalog`), which lists it under the separate `sideloaded`
/// group, so the files are also REMOVED on every launch that does not ask for them, and their
/// index rows with them: nothing this seam writes outlives the suite that asked, and
/// `refreshAfterCorpusChange` drops the side-load sidecars of files that are gone. The sweep checks
/// five fixed names, never the directory.
///
/// ## Why each row holds one document, and is indexed before the pipeline is published
/// The boot reconcile pass indexes every file on disk with no rows in `document_cache`, and it
/// runs AFTER the pipeline is published, so its progress banner opens the indexing education sheet
/// over whatever the test is about to tap — in this suite's first UI run, a boot pass's sheet
/// covered the Settings row and all three tests failed on it. A row with no documents never gains
/// a `document_cache` row, so, by that pass's own filter, it would be reconciled — banner, sheet —
/// on every launch; the seam's first draft wrote rows like that. Each row therefore
/// carries one document, and ``prepareStorageRowIndex(pipeline:)`` indexes the rows (or, on a
/// launch that did not ask for them, removes their index rows) BEFORE the pipeline is published —
/// the same silence `UITestBrowseSeams.prepareSeededVolume` gives the browse fixture. The
/// document's title names its row and contains no browse-fixture title, so no suite's
/// `CONTAINS[c]` match can land on it.
///
/// Version history:
///   1.0 — #1356/#1357: initial implementation
extension UITestVolumeSeeder {

    /// The launch-environment key a UI test sets, to `1`, to request the storage rows.
    static let storageRowsEnvironmentKey = "FRUS_UI_TEST_SEED_STORAGE_ROWS"

    /// The volume ids of the storage rows, in the order the list sorts them.
    static let storageRowVolumeIds = (1...5).map { String(format: "uitest-storage-%02d", $0) }

    /// Writes the storage rows when `FRUS_UI_TEST_SEED_STORAGE_ROWS` is `1`, and removes any that
    /// a previous launch left when it is not.
    ///
    /// Called from `bootDownloadManager()` beside ``seedIfRequested(in:)``, before `AppState` knows
    /// the volumes directory, so the boot's side-load reconciliation already sees the result.
    ///
    /// - Parameter volumesDirectory: The app's volumes directory.
    /// - Returns: The volume ids written or removed.
    @discardableResult
    static func prepareStorageRowsIfRequested(in volumesDirectory: URL) -> [String] {
        let requested = ProcessInfo.processInfo.environment[storageRowsEnvironmentKey] == "1"
        return prepareStorageRows(requested: requested, in: volumesDirectory)
    }

    /// ``prepareStorageRowsIfRequested(in:)`` with the environment read lifted out, so a test can
    /// drive both arms.
    ///
    /// - Parameters:
    ///   - requested: Whether this launch asked for the rows.
    ///   - volumesDirectory: The app's volumes directory.
    /// - Returns: The volume ids written (requested) or removed (not requested). A sweep that
    ///   found nothing returns an empty array.
    @discardableResult
    static func prepareStorageRows(requested: Bool, in volumesDirectory: URL) -> [String] {
        let fileManager = FileManager.default
        var touched: [String] = []
        for volumeId in storageRowVolumeIds {
            let url = volumesDirectory.appendingPathComponent("\(volumeId).xml")
            if requested {
                if (try? storageRowXML(volumeId: volumeId)
                        .write(to: url, atomically: true, encoding: .utf8)) != nil {
                    touched.append(volumeId)
                }
            } else if fileManager.fileExists(atPath: url.path),
                      (try? fileManager.removeItem(at: url)) != nil {
                touched.append(volumeId)
            }
        }
        if !touched.isEmpty {
            print("[UITestVolumeSeeder] \(requested ? "Seeded" : "Removed") storage rows: "
                  + touched.joined(separator: ", "))
        }
        return touched
    }

    /// A storage row's TEI: a header the side-load catalogue can read a title from, and one
    /// document, so the row is indexed once and the boot reconcile pass leaves it alone.
    static func storageRowXML(volumeId: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>UI Test Storage Row \(volumeId.suffix(2))</title></titleStmt>
          <publicationStmt><date>1996</date></publicationStmt>
          <sourceDesc><p>UI test fixture — not real FRUS content.</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="document" xml:id="d1">
              <head>UI Test Storage Row \(volumeId.suffix(2)) Document</head>
              <p>Storage-list fixture for \(volumeId).</p>
            </div>
          </body></text>
        </TEI>
        """
    }

    /// What a launch does to one storage row's index rows.
    ///
    /// Version history:
    ///   1.0 — #1356/#1357: initial implementation
    enum StorageRowIndexAction: Equatable {
        /// Index it: this launch asked for the rows and this one has no index rows yet.
        case index
        /// Remove its index rows: this launch did not ask for the rows, and its file is gone.
        case unindex
        /// Leave it alone.
        case none

        /// The action for one row.
        ///
        /// - Parameters:
        ///   - requested: Whether this launch set `FRUS_UI_TEST_SEED_STORAGE_ROWS`.
        ///   - indexed: Whether the row's volume has rows in `document_cache`.
        static func plan(requested: Bool, indexed: Bool) -> StorageRowIndexAction {
            switch (requested, indexed) {
            case (true, false): return .index
            case (false, true): return .unindex
            case (true, true), (false, false): return .none
            }
        }
    }

    /// Brings the storage rows' index rows to what this launch asked for, BEFORE `AppState`
    /// publishes the pipeline — see "Why each row holds one document" above.
    ///
    /// On a launch that did not ask for the rows this costs five `document_cache` primary-key
    /// lookups and nothing else.
    ///
    /// - Parameter pipeline: The pipeline boot just built and has not yet published.
    static func prepareStorageRowIndex(pipeline: IndexingPipeline) async {
        let requested = ProcessInfo.processInfo.environment[storageRowsEnvironmentKey] == "1"
        for volumeId in storageRowVolumeIds {
            let indexed = (try? pipeline.isVolumeIndexed(volumeId)) == true
            switch StorageRowIndexAction.plan(requested: requested, indexed: indexed) {
            case .index:
                try? await pipeline.indexVolume(volumeId)
            case .unindex:
                try? await pipeline.removeVolume(volumeId)
            case .none:
                break
            }
        }
    }
}

#endif
