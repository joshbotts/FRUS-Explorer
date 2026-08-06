// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import VolumeSourcesIndexGeneratorCore

// MARK: - RecordGroupPreservationTests

/// Pins `VolumeSourcesIndexRunner.recordGroupsToWrite` — the guard that stops a keyless run
/// from silently emptying the shipped record-group map (#372 / N-5 follow-up).
///
/// The failure this prevents is invisible by construction: `resolveRecordGroup` has no offline
/// route, so `swift run VolumeSourcesIndexGenerator` without `CATALOG_API_KEY` — the invocation
/// `CLAUDE.md` lists **first**, and the runner's own header calls a benign "offline pass" —
/// wrote `recordGroups: {}` over the bundle. No exception, no non-zero exit, no failing test.
/// The corpus browser's Sources outline would just stop showing header links on **6,373
/// front-matter nodes**, and the next person to notice would be a user.
///
/// Version history:
///   1.0 — Session 2026-08-05: #372 / N-5 follow-up
@Suite("VolumeSourcesIndexRunner — record-group map preservation")
struct RecordGroupPreservationTests {

    private func naid(_ id: String) -> ResolvedNAID {
        ResolvedNAID(naId: id, catalogURL: "https://catalog.archives.gov/id/\(id)",
                     title: "RG \(id)", recordGroup: id, matchType: "api")
    }
    private var shipped: [String: ResolvedNAID] { ["59": naid("388"), "84": naid("1557")] }

    @Test("A keyless run inherits the previous map instead of erasing it")
    func keylessRunPreservesPriorMap() throws {
        let out = try VolumeSourcesIndexRunner.recordGroupsToWrite(
            resolved: [:], headingCount: 31, prior: shipped, outputPath: "/tmp/x.json")
        #expect(out.map.count == 2)
        #expect(out.map["59"]?.naId == "388")
        #expect(out.note != nil, "an inherited map must say so in the log")
    }

    @Test("A keyless run with nothing to inherit throws rather than writing an empty map")
    func keylessRunWithNoPriorThrows() {
        #expect(throws: VolumeSourcesIndexRunner.RunError.self) {
            _ = try VolumeSourcesIndexRunner.recordGroupsToWrite(
                resolved: [:], headingCount: 31, prior: [:], outputPath: "/tmp/x.json")
        }
    }

    /// The guard must not fire on a successful API run — that would make the keyed invocation,
    /// the one that actually rebuilds the map, refuse its own fresh output.
    @Test("An API run writes what it resolved, and never the stale prior")
    func apiRunWritesItsOwnResult() throws {
        let fresh = ["59": naid("999")]
        let out = try VolumeSourcesIndexRunner.recordGroupsToWrite(
            resolved: fresh, headingCount: 31, prior: shipped, outputPath: "/tmp/x.json")
        #expect(out.map["59"]?.naId == "999", "the fresh resolution must win over the prior map")
        #expect(out.map.count == 1, "a shrinking map is a real result, not a failure to inherit")
        #expect(out.note == nil)
    }

    /// A corpus with no record-group headings legitimately resolves none. Throwing there would
    /// break a volume set that simply has no `<hi rend="strong">` headers.
    @Test("A corpus naming no record groups writes an empty map without complaint")
    func noHeadingsIsNotAFailure() throws {
        let out = try VolumeSourcesIndexRunner.recordGroupsToWrite(
            resolved: [:], headingCount: 0, prior: [:], outputPath: "/tmp/x.json")
        #expect(out.map.isEmpty)
        #expect(out.note == nil)
    }

    /// The message has to name the cause and the two ways out, because whoever hits this is
    /// running a command the docs told them was safe.
    @Test("The refusal explains the cause and both remedies")
    func errorMessageIsActionable() {
        let text = String(describing: VolumeSourcesIndexRunner.RunError
            .emptyRecordGroups(headings: 31, output: "/tmp/x.json"))
        #expect(text.contains("/tmp/x.json"))
        #expect(text.contains("31"))
        #expect(text.contains("CATALOG_API_KEY"))
        #expect(text.lowercased().contains("restore"))
    }
}
