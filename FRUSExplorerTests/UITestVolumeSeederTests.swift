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
/// Version history:
///   1.0 — #1301 round 2: initial implementation
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
}
