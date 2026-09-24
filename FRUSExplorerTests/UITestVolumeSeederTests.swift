// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - UITestVolumeSeederTests

/// The seeding harness the UI suites stand on (#1301 round 2).
///
/// ## Why a harness gets its own tests
/// `contentChanged` is the signal `FRUSExplorerApp` re-indexes a changed fixture on, and it cost
/// #1301 a full red/green cycle to discover it was needed: the volumes directory **and the search
/// index** both survive between simulator runs, and `BrowserViewModel.loadVolumeStructure` prefers
/// the `volume_structures` row persisted at index time over parsing the file. So a warm simulator
/// served the OLD structure from a NEW fixture, and the iPhone control failed at "The nested
/// chapter row is absent from the compilation's Sections list" — for a reason it was not about.
///
/// Nothing pinned it. A mutation sweep replaced the comparison with `false` and every suite in
/// both targets stayed green, because the harm is invisible *within* a run: the run that breaks is
/// the next one, on a machine where the fixture last changed. That is the shape of bug that comes
/// back weeks later as a mystery UI failure, so it is pinned here.
///
/// ## The volume id is a parameter for exactly this reason
/// `seedIfRequested(in:)` reads `FRUS_UI_TEST_SEED_VOLUME` from the process environment, and a
/// Swift Testing run cannot set its own environment. ``UITestVolumeSeeder/seed(volumeId:in:)`` is
/// the same function with that one lookup lifted out — the launch-gated wrapper keeps the
/// environment read, and the part with the logic in it takes an argument.
///
/// ## What round 3 added: the decisions the app makes FROM these signals
/// `contentChanged` was pinned three ways and its only consumer was not, and the cold seam's two
/// boot stand-downs were two independent `if`s of which only one is observable from a UI run. Both
/// are values now — `UITestBrowseSeams.SeedPreparation.plan(cold:contentChanged:)` and
/// `UITestBrowseSeams.bootIndexingStandDown(coldVolumeRequested:)` — with one assertion per input,
/// so deleting an arm is a unit failure rather than an environment-dependent UI one.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
///   1.1 — #1301 round 3: the seeded-fixture preparation plan and the two boot stand-downs
@Suite("The UI-test fixture seeder reports whether it changed anything")
struct UITestVolumeSeederTests {

    private static let volumeId = "frus1961-63v06"

    /// A temp volumes directory. Callers remove it.
    private func makeVolumesDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-seeder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Seeding over an older fixture reports the change, and writes the new bytes")
    func seedingOverAnOlderFixtureReportsTheChange() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("\(Self.volumeId).xml")
        // The shape the fixture had before #1301 added its nested branch: enough to stand in for
        // "a previous revision left a file here and the index describes THAT file".
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0"><text><body>
          <div type="compilation" xml:id="uitestcomp"><head>UI Test Compilation</head></div>
        </body></text></TEI>
        """.write(to: url, atomically: true, encoding: .utf8)

        let result = try #require(UITestVolumeSeeder.seed(volumeId: Self.volumeId, in: dir))

        #expect(result.volumeId == Self.volumeId)
        #expect(result.contentChanged, """
            A fixture whose bytes changed must say so. `FRUSExplorerApp` re-indexes that one \
            volume on this signal, and without it the app goes on serving the persisted \
            `volume_structures` row for the file it just overwrote.
            """)
        #expect(try String(contentsOf: url, encoding: .utf8)
                    == UITestVolumeSeeder.fixtureXML(volumeId: Self.volumeId),
                "and the new fixture is what is on disk")
    }

    @Test("Seeding the same fixture twice reports no change the second time, and rewrites it anyway")
    func seedingTwiceReportsNoChangeButStillWrites() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("\(Self.volumeId).xml")

        _ = UITestVolumeSeeder.seed(volumeId: Self.volumeId, in: dir)
        let second = try #require(UITestVolumeSeeder.seed(volumeId: Self.volumeId, in: dir))

        #expect(second.contentChanged == false, """
            An unchanged fixture must NOT claim a change: every warm launch would then re-index \
            the volume, which is work nobody asked for on every run of every UI suite.
            """)
        #expect(try String(contentsOf: url, encoding: .utf8)
                    == UITestVolumeSeeder.fixtureXML(volumeId: Self.volumeId), """
            The write is unconditional either way — the comparison decides what is REPORTED, not \
            whether the file is refreshed.
            """)
    }

    @Test("A fixture that was not there at all counts as changed")
    func anAbsentFixtureCountsAsChanged() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = try #require(UITestVolumeSeeder.seed(volumeId: Self.volumeId, in: dir))

        #expect(result.contentChanged, """
            An absent file is "changed", and that is deliberate rather than incidental: on a \
            simulator that has never seen this fixture there is nothing indexed to describe it, \
            and the re-index this reports is what makes the FIRST run of a suite behave like \
            every later one.
            """)
    }

    // MARK: - What the app DOES with those signals (#1301 round 3)

    @Test("The seeded fixture's preparation plan, over all four inputs")
    func seedPreparationPlansEveryCombination() {
        #expect(UITestBrowseSeams.SeedPreparation.plan(cold: false, contentChanged: true)
                == .reindex, """
            THE BRANCH ROUND 2 LEFT UNPINNED, and the one that cost #1301 a full red/green cycle. \
            `contentChanged` is pinned three ways above and its only consumer was not: deleting \
            `else if seeded.contentChanged { try await pipeline.indexVolume(…) }` left 31 tests in \
            four suites and every UI suite green, because the run it breaks is the NEXT one, on a \
            machine where the fixture last changed.
            """)
        #expect(UITestBrowseSeams.SeedPreparation.plan(cold: false, contentChanged: false)
                == .none, "an unchanged fixture on a warm run needs nothing")
        #expect(UITestBrowseSeams.SeedPreparation.plan(cold: true, contentChanged: false)
                == .unindex, "and a cold run strips the index rows the seam exists to remove")
        #expect(UITestBrowseSeams.SeedPreparation.plan(cold: true, contentChanged: true)
                == .unindex, """
            COLD WINS OVER CHANGED, and the order is the whole content of this case: a fixture \
            whose bytes changed on a cold run must NOT be re-indexed, because the cold seam's \
            purpose is a volume with no index rows and `requireIndexNow` turns a volume that has \
            them into a failure.
            """)
    }

    @Test("Both boot indexing passes stand down together, or neither does")
    func bothBootPassesStandDownForAColdRun() throws {
        let armed = try #require(UITestBrowseSeams.bootIndexingStandDown(coldVolumeRequested: true),
                                 "an armed cold seam must answer for both passes")
        #expect(armed.dateReindexNeeded == false, """
            THE ARM NO UI RUN CAN SEE. `FRUSExplorerApp` runs two boot passes that each index every \
            downloaded volume they find, and both must stand down or the cold seam's \
            `removeVolume(_:)` is undone before Browse can be walked. They are NOT equally \
            observable: on a simulator that has run this suite before, a date-index version is \
            recorded, `needsDateReindex` is already false, and deleting this arm leaves the cold \
            UI test PASSING (measured: 1 test, 0 failures, 21.5 s, Index Now included) while \
            deleting the other fails it at :262 in 39.2 s. Which half is pinned depended on the \
            machine's history until this assertion existed.
            """)
        #expect(armed.reconcileUnindexedDownloads == false,
                "and the reconcile pass beside it, which is the half a UI run does catch")
        #expect(UITestBrowseSeams.bootIndexingStandDown(coldVolumeRequested: false) == nil, """
            And with the seam unarmed boot decides for itself — `nil` rather than `(true, true)`, \
            because this is not a policy about indexing, only a stand-down while a test needs one \
            volume left alone.
            """)
    }
}

// MARK: - UITestStorageRowsSeederTests

/// The five side-loaded rows `VolumeRemovalTests` stands on (#1356, #1357), and their removal on
/// every launch that did not ask for them.
///
/// The removal arm is the one that matters and the one no UI run can see: three suites launch with
/// `-frus.filterDownloadedOnly YES` counting on exactly one downloaded volume, and a sweep that
/// silently stopped working would leave five more files on every simulator that ever ran the
/// removal suite, each listed under Browse's `sideloaded` group.
///
/// Version history:
///   1.0 — #1356/#1357: initial implementation
struct UITestStorageRowsSeederTests {

    /// A temp volumes directory. Callers remove it.
    private func makeVolumesDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-storage-rows-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The `.xml` files in `dir`, sorted.
    private func xmlFiles(in dir: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".xml") }.sorted()
    }

    @Test("A launch that asks for the rows writes all five")
    func requestedWritesTheFiveRows() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let written = UITestVolumeSeeder.prepareStorageRows(requested: true, in: dir)

        #expect(written == UITestVolumeSeeder.storageRowVolumeIds)
        #expect(try xmlFiles(in: dir) == UITestVolumeSeeder.storageRowVolumeIds.map { "\($0).xml" })
        let third = dir.appendingPathComponent("uitest-storage-03.xml")
        #expect(try String(contentsOf: third, encoding: .utf8)
                    == UITestVolumeSeeder.storageRowXML(volumeId: "uitest-storage-03"))
    }

    @Test("A launch that does not ask removes the rows, and nothing else")
    func unrequestedRemovesOnlyTheRows() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        UITestVolumeSeeder.prepareStorageRows(requested: true, in: dir)
        // The browse fixture and a real volume sit beside them, as on a developer's simulator.
        _ = UITestVolumeSeeder.seed(volumeId: "frus1961-63v06", in: dir)
        try "<TEI/>".write(to: dir.appendingPathComponent("frus1969-76v01.xml"),
                           atomically: true, encoding: .utf8)

        let removed = UITestVolumeSeeder.prepareStorageRows(requested: false, in: dir)

        #expect(removed == UITestVolumeSeeder.storageRowVolumeIds, """
            Every row a previous launch left must go, or Browse lists them under `sideloaded` in \
            every later suite on this simulator.
            """)
        #expect(try xmlFiles(in: dir) == ["frus1961-63v06.xml", "frus1969-76v01.xml"],
                "only the five fixed names are ever removed")
    }

    @Test("A launch with no rows to remove removes nothing and says so")
    func unrequestedWithNothingThereIsANoOp() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "<TEI/>".write(to: dir.appendingPathComponent("frus1969-76v01.xml"),
                           atomically: true, encoding: .utf8)

        #expect(UITestVolumeSeeder.prepareStorageRows(requested: false, in: dir).isEmpty)
        #expect(try xmlFiles(in: dir) == ["frus1969-76v01.xml"])
    }

    @Test("The rows read as side-loaded volumes with a title, outside every catalogue subseries")
    func rowsAreSideloadedAndTitled() throws {
        let dir = try makeVolumesDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        UITestVolumeSeeder.prepareStorageRows(requested: true, in: dir)

        for volumeId in UITestVolumeSeeder.storageRowVolumeIds {
            let url = dir.appendingPathComponent("\(volumeId).xml")
            let entry = try #require(LocalVolumeCatalog.entry(volumeId: volumeId, url: url, sizeBytes: 1),
                                     "the side-load catalogue cannot read \(volumeId)'s header")
            #expect(entry.title == "UI Test Storage Row \(volumeId.suffix(2))")
            #expect(entry.provenance == .sideloaded)
            #expect(LocalVolumeCatalog.subseries(for: volumeId) == LocalVolumeCatalog.sideloadedSubseries, """
                A row id that parses as a FRUS era would join that era's Browse subseries — among \
                the catalogue volumes three suites count on being alone.
                """)
            let xml = try String(contentsOf: url, encoding: .utf8)
            #expect(xml.components(separatedBy: "type=\"document\"").count == 2, """
                Exactly one document: with none, the row never gains a `document_cache` row, so \
                the boot reconcile pass indexes it on every launch and its banner opens the \
                education sheet over the test.
                """)
            for fixtureTitle in UITestVolumeSeeder.documentTitles + UITestVolumeSeeder.nestedDocumentTitles
                + [UITestVolumeSeeder.compilationTitle, UITestVolumeSeeder.twinDocumentTitle] {
                #expect(!xml.localizedCaseInsensitiveContains(fixtureTitle),
                        "a browse suite matching \"\(fixtureTitle)\" could land on \(volumeId)")
            }
        }
    }

    @Test("Each row's index rows follow the launch: indexed when asked for, removed when not")
    func storageRowIndexPlanCoversEveryInput() {
        typealias Action = UITestVolumeSeeder.StorageRowIndexAction
        #expect(Action.plan(requested: true, indexed: false) == .index,
                "asked for and not yet indexed: index it before the pipeline is published")
        #expect(Action.plan(requested: true, indexed: true) == .none,
                "asked for and already indexed: re-indexing on every launch is work nobody asked for")
        #expect(Action.plan(requested: false, indexed: true) == .unindex,
                "not asked for: the file is gone, so its index rows go too")
        #expect(Action.plan(requested: false, indexed: false) == .none,
                "not asked for and not indexed: nothing to do — the case on every ordinary launch")
    }
}
