// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SQLite3

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
/// and seven suites, in six files, seed it and stand on its being there.
///
/// ## Why these ids are not in the manifest
/// Every browse surface enumerates the catalogue, and four suites launch with
/// `-frus.filterDownloadedOnly YES` counting on exactly ONE downloaded volume. A catalogue id here
/// would put five more rows in their Browse. An id the catalogue does not know is read as
/// side-loaded instead (`LocalVolumeCatalog`), which lists it under the separate `sideloaded`
/// group, so the files are also REMOVED on every launch that does not ask for them, and their
/// index rows with them. The one thing that can outlive the suite is a side-load sidecar
/// (`LocalVolumeCatalog`) a hub minted for a row while the suite ran; only
/// `LocalVolumeCatalog.reconcile` reads sidecars, and it drops each one whose file is gone, so an
/// orphan is inert until the next `AppState.refreshAfterCorpusChange` — a hub action or the end of
/// an indexing batch, never boot. The sweep checks five fixed names, never the directory.
///
/// ## Why each row holds one document, and is indexed before the pipeline is published
/// The boot reconcile pass indexes every file on disk with no rows in `document_cache`, and it
/// runs AFTER the pipeline is published, so its progress banner opens the indexing education sheet
/// over whatever the test is about to tap. A row with no documents never gains a
/// `document_cache` row, so, by that pass's own filter, it would be reconciled — banner, sheet —
/// on every launch; the seam's first draft wrote rows like that. (The suite's first UI run failed
/// all three tests on that sheet, but it is not evidence for this rule: its banner read "Volume 7
/// of 11" — eleven volumes, more than the six the suite seeds — so that pass was re-indexing more
/// than these rows, which fits the index-version bump `VolumeRemovalTests.settleAfterLaunch`
/// names.) Each row therefore
/// carries one document, and ``prepareStorageRowIndex(pipeline:)`` indexes the rows (or, on a
/// launch that did not ask for them, removes their index rows) BEFORE the pipeline is published —
/// the same silence `UITestBrowseSeams.prepareSeededVolume` gives the browse fixture. The
/// document's title names its row and contains no browse-fixture title, so no suite's
/// `CONTAINS[c]` match can land on it.
///
/// Version history:
///   1.0 — #1356/#1357: initial implementation
///   1.1 — #1356 review, round 1: ``prepareStorageRowIndex(pipeline:requested:)`` takes the
///          launch's answer as a parameter so a test can drive its dispatch, and
///          `FRUS_UI_TEST_HOLD_STORAGE_REMOVAL` holds a removal open
extension UITestVolumeSeeder {

    /// The launch-environment key a UI test sets, to `1`, to request the storage rows.
    static let storageRowsEnvironmentKey = "FRUS_UI_TEST_SEED_STORAGE_ROWS"

    /// The volume ids of the storage rows, in the order the list sorts them.
    static let storageRowVolumeIds = (1...5).map { String(format: "uitest-storage-%02d", $0) }

    /// Writes the storage rows when `FRUS_UI_TEST_SEED_STORAGE_ROWS` is `1`, and removes any that
    /// a previous launch left when it is not.
    ///
    /// Called from `bootDownloadManager()` beside ``seedIfRequested(in:)``, before the pipeline is
    /// built, so the files are on disk for ``prepareStorageRowIndex(pipeline:requested:)``. No
    /// boot step reconciles side-loaded volumes — `ManifestStore.refreshLocalEntries` runs only
    /// from `AppState.refreshAfterCorpusChange` — so a launch can list the rows by their ids until
    /// a hub action or an indexing batch reads their headers.
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
        /// Remove its index rows: this launch did not ask for the rows. Its file has been swept by
        /// then (``prepareStorageRowsIfRequested(in:)`` runs first), but the plan does not look at
        /// the file: were a sweep to fail, the boot reconcile pass would index the row again.
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
    /// - Parameters:
    ///   - pipeline: The pipeline boot just built and has not yet published.
    ///   - requested: Whether this launch asked for the rows. Boot passes nothing and gets the
    ///     launch environment's answer; `UITestStorageRowsSeederTests` passes each answer in turn
    ///     and drives this dispatch against a real pipeline.
    static func prepareStorageRowIndex(
        pipeline: IndexingPipeline,
        requested: Bool = ProcessInfo.processInfo.environment[storageRowsEnvironmentKey] == "1"
    ) async {
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

    // MARK: Holding a removal open

    /// The launch-environment key a UI test sets, to a whole number of seconds, to hold every
    /// storage removal open that long before each volume's first step (#1356 review) — so a Free
    /// Up Space removal of several volumes is held once per volume.
    ///
    /// A removal of a seeded row takes about a second on a simulator, which is too short for a UI
    /// test to read the row's *removing…* mark or to leave Volumes & Storage and come back while
    /// it runs — and a test that raced it would pass on a fast removal and flake on a slow one. A
    /// held removal is marked for as long as the hold lasts, on the fixed code, and never marked at
    /// all on code that does not mark it. `VolumeRemovalTests.testRemovalMarkSurvivesLeavingTheHub`
    /// and `testFreeUpSpaceKeepsItsVolumeWhileRemovingIt` set it.
    static let storageRemovalHoldEnvironmentKey = "FRUS_UI_TEST_HOLD_STORAGE_REMOVAL"

    /// The hold `FRUS_UI_TEST_HOLD_STORAGE_REMOVAL` asks for, or `nil` when it is absent, zero, or
    /// not a whole number of seconds.
    ///
    /// - Parameter environment: The launch environment; tests pass their own.
    static func storageRemovalHold(
        in environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Duration? {
        guard let raw = environment[storageRemovalHoldEnvironmentKey],
              let seconds = Int(raw), seconds > 0 else { return nil }
        return .seconds(seconds)
    }

    /// Sleeps for the hold a UI test asked for, if any. Called before each volume's first removal
    /// step by `DownloadedVolumesListModel.removeVolumes(_:in:context:remeasure:)`, the
    /// routing both hubs share — so a hub that stopped routing through it is not held, and its
    /// row is never marked.
    ///
    /// The sleep's tolerance is pinned. Left to the system, on an iOS 27.0 iPad simulator, a 40 s
    /// hold ended 2.7 s late by the app's own log, which showed every later step of the removal
    /// taking 60 ms together; in the run before it a 25 s hold's row left 53.6 s after the
    /// confirmation, and the hold is the only step that could have taken the other 28 s. A late
    /// enough hold reads, to the test, as a removal that never finished.
    static func holdStorageRemovalIfRequested() async {
        guard let hold = storageRemovalHold() else { return }
        print("[UITestVolumeSeeder] Holding a storage removal for \(hold)")
        try? await Task.sleep(for: hold, tolerance: .milliseconds(100))
    }
}

// MARK: - Cross-reference matrix rows (#1379)

/// Citations among fifteen real volumes, written straight into the index's `cross_references`
/// table, so Cross-Reference Analytics draws a FULL heat matrix — fifteen rows — with nothing
/// downloaded.
///
/// ## Why this exists
/// #1379's defects show only on a full matrix: the grid is 565 pt tall at fifteen rows, and the
/// scroll box it sat in stopped at 480 pt, so rows 14 and 15 were never on screen. Every UI test
/// launches with no volumes, and the one fixture volume (``seed(volumeId:in:)``) cites nothing, so
/// no suite could draw a matrix at all. `CrossReferenceMatrixScrollTests` launches with
/// `FRUS_UI_TEST_SEED_CROSSREF_MATRIX=1`.
///
/// ## Why rows and not volumes
/// The heat matrix reads one table, `cross_references`, grouped by volume — so rows are the whole
/// of what it needs. Fifteen fixture volumes would each be indexed at boot (and announced by the
/// indexing banner), and each would be a downloaded volume in the four suites that launch with
/// `-frus.filterDownloadedOnly YES` counting on exactly one. Rows are neither: a volume is
/// downloaded when its file is on disk and indexed when it has `document_cache` rows, and these
/// write neither.
///
/// ## Why real volume ids
/// A row is labelled from the manifest, and #1379 is about how a REAL title's label is cut: the two
/// Potsdam volumes, whose shared 49-character topic the old label cut at both ends; five more topics
/// over 40 characters (`frus1945v03` and `frus1961-63v25` among them); the longest tag in the
/// bundled corpus (`frus1969-76ve15p2Ed2`, "1969-76 vE-15 pt.2 ed.2"); and a volume with no topic at
/// all (`frus1864p1`), which the view draws as its tag alone.
/// `UITestCrossReferenceMatrixSeederTests.fixtureVolumesCoverTheLabelShapes` pins each of those by
/// name: the Potsdam pair, at least seven topics over 40 characters with the two named ones among
/// them, that tag as long as any tag in the bundled manifest, and `frus1864p1`'s empty topic.
///
/// ## Marked, and swept on every launch that did not ask
/// Every fixture row's source document id begins ``crossReferenceMatrixSourcePrefix``, which no
/// FRUS document id does, and every launch of a debug build deletes the rows so marked — before
/// writing them again when this launch asked for them — so a simulator that ran the suite shows a
/// developer's own launch only its own citations. The sweep names the fifteen source volumes,
/// which puts it on `idx_crossref_source` rather than a scan of the whole table: on a full-corpus
/// index that table holds millions of rows, and this runs at every debug boot.
///
/// Version history:
///   1.0 — #1379: initial implementation
///   1.1 — #1379 review round 1: the counts of suites that seed the browse fixture (seven) and
///          launch with the Downloaded filter (four) corrected, and the label shapes named as
///          pinned
extension UITestVolumeSeeder {

    /// The launch-environment key a UI test sets, to `1`, to request the matrix rows.
    static let crossReferenceMatrixEnvironmentKey = "FRUS_UI_TEST_SEED_CROSSREF_MATRIX"

    /// The fifteen volumes the rows run between — `CrossReferenceAnalyticsView.matrixVolumeLimit`,
    /// so the matrix is full. None is the browse fixture's `frus1961-63v06`, which seven suites
    /// index as a synthetic volume: re-indexing a volume deletes the rows it is the source of.
    static let crossReferenceMatrixVolumeIds = [
        "frus1945Berlinv01",
        "frus1945Berlinv02",
        "frus1945v03",
        "frus1864p1",
        "frus1919Parisv01",
        "frus1917-72PubDipv06",
        "frus1952-54v02p1",
        "frus1955-57v03mSupp",
        "frus1961-63v07",
        "frus1961-63v10-12mSupp",
        "frus1961-63v11",
        "frus1961-63v13",
        "frus1961-63v25",
        "frus1969-76ve15p2Ed2",
        "frus1977-80v09Ed2",
    ]

    /// The start of every fixture row's source document id — the mark the sweep deletes by.
    static let crossReferenceMatrixSourcePrefix = "uitest-matrix-"

    /// One fixture citation: a document of one volume citing a document of another.
    ///
    /// Version history:
    ///   1.0 — #1379: initial implementation
    struct CrossReferenceMatrixRow: Equatable, Sendable {
        /// The citing volume.
        let sourceVolumeId: String
        /// The citing document — always ``crossReferenceMatrixSourcePrefix`` followed by the cited
        /// volume's position and the citation's ordinal, so each is unique within its volume.
        let sourceDocumentId: String
        /// The cited volume.
        let targetVolumeId: String
        /// The cited document, `d1`…`d3`: a document id the analytics' document filter admits.
        let targetDocumentId: String
    }

    /// Every fixture citation. Each volume cites each other one once, twice or three times — the
    /// count varies with the pair, so the cells shade differently rather than reading as one flat
    /// colour — for 420 rows in all.
    static var crossReferenceMatrixRows: [CrossReferenceMatrixRow] {
        let ids = crossReferenceMatrixVolumeIds
        var rows: [CrossReferenceMatrixRow] = []
        for (i, source) in ids.enumerated() {
            for (j, target) in ids.enumerated() where i != j {
                for k in 0..<(1 + (i + j) % 3) {
                    rows.append(CrossReferenceMatrixRow(
                        sourceVolumeId: source,
                        sourceDocumentId: "\(crossReferenceMatrixSourcePrefix)\(j)-\(k)",
                        targetVolumeId: target,
                        targetDocumentId: "d\(1 + (i + k) % 3)"))
                }
            }
        }
        return rows
    }

    /// What one preparation did to the table.
    ///
    /// Version history:
    ///   1.0 — #1379: initial implementation
    struct CrossReferenceMatrixPreparation: Equatable, Sendable {
        /// Fixture rows a previous launch left, deleted.
        let removed: Int
        /// Fixture rows written: all of ``crossReferenceMatrixRows`` when requested, else `0`.
        let written: Int
    }

    /// Brings the matrix rows to what this launch asked for — see the extension's doc.
    ///
    /// Called from `bootDownloadManager()` once the pipeline has made the database and before
    /// `crossReferenceStore` opens on it.
    ///
    /// - Parameter databaseURL: The search index's database.
    /// - Returns: What was removed and written, or `nil` when the database could not be changed.
    @discardableResult
    static func prepareCrossReferenceMatrixIfRequested(databaseURL: URL) -> CrossReferenceMatrixPreparation? {
        let requested = ProcessInfo.processInfo.environment[crossReferenceMatrixEnvironmentKey] == "1"
        return prepareCrossReferenceMatrix(requested: requested, databaseURL: databaseURL)
    }

    /// ``prepareCrossReferenceMatrixIfRequested(databaseURL:)`` with the environment read lifted
    /// out, so a test can drive both arms.
    ///
    /// The sweep and the write are one transaction: a launch that asked for the rows never sees
    /// the old ones gone and the new ones not yet there.
    ///
    /// - Parameters:
    ///   - requested: Whether this launch asked for the rows.
    ///   - databaseURL: The search index's database. It must exist: this opens it without
    ///     creating it, because a path that names no database is a boot that failed before here,
    ///     and an empty file would hide that.
    /// - Returns: What was removed and written, or `nil` when the database could not be opened or
    ///   a statement failed — a database without a `cross_references` table, say — in which case
    ///   nothing was changed.
    @discardableResult
    static func prepareCrossReferenceMatrix(requested: Bool,
                                            databaseURL: URL) -> CrossReferenceMatrixPreparation? {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let db = handle else {
            sqlite3_close(handle)
            print("[UITestVolumeSeeder] Cannot open \(databaseURL.lastPathComponent) for the matrix rows")
            return nil
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5_000)
        guard sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { return nil }

        let ids = crossReferenceMatrixVolumeIds
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ", ")
        let sweep = """
            DELETE FROM cross_references
            WHERE source_volume_id IN (\(placeholders))
              AND source_document_id GLOB '\(crossReferenceMatrixSourcePrefix)*'
            """
        guard run(sweep, in: db, binding: [ids]) else { return rollBack(db) }
        let removed = Int(sqlite3_changes(db))

        var written = 0
        if requested {
            let insert = """
                INSERT INTO cross_references
                (source_volume_id, source_document_id, target_volume_id, target_document_id)
                VALUES (?, ?, ?, ?)
                """
            let values = crossReferenceMatrixRows.map {
                [$0.sourceVolumeId, $0.sourceDocumentId, $0.targetVolumeId, $0.targetDocumentId]
            }
            guard run(insert, in: db, binding: values) else { return rollBack(db) }
            written = values.count
        }
        guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else { return rollBack(db) }
        if removed > 0 || written > 0 {
            print("[UITestVolumeSeeder] Matrix rows: removed \(removed), wrote \(written)")
        }
        return CrossReferenceMatrixPreparation(removed: removed, written: written)
    }

    /// Runs one statement once per set of values, binding each value as text in order.
    ///
    /// - Parameters:
    ///   - sql: The statement.
    ///   - db: An open connection.
    ///   - rows: One array of values per execution.
    /// - Returns: `false` when the statement cannot be prepared or an execution fails.
    private static func run(_ sql: String, in db: OpaquePointer, binding rows: [[String]]) -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            sqlite3_finalize(statement)
            print("[UITestVolumeSeeder] Matrix rows: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        defer { sqlite3_finalize(statement) }
        // SQLITE_TRANSIENT: SQLite copies each value before the Swift string it came from goes.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for values in rows {
            sqlite3_reset(statement)
            for (index, value) in values.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), value, -1, transient)
            }
            guard sqlite3_step(statement) == SQLITE_DONE else { return false }
        }
        return true
    }

    /// Rolls back the open transaction and reports the failure.
    ///
    /// - Parameter db: The connection holding the transaction.
    /// - Returns: `nil`, so a caller can `return rollBack(db)`.
    private static func rollBack(_ db: OpaquePointer) -> CrossReferenceMatrixPreparation? {
        sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
        return nil
    }
}

#endif
