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

// MARK: - LocalVolumeCatalogTests

/// #777: a side-loaded volume gets a catalogue entry of its own, minted from its own TEI header.
///
/// The tests that matter most here are the **negative** ones. Giving a side-loaded volume an entry
/// is what makes it browsable; it is also what would let it masquerade as a published volume in a
/// citation, hand a repair path a GitHub URL that 404s, or be offered for deletion under a promise
/// of re-download. Each of those is pinned below.
///
/// Version history:
///   1.0 — Session 2026-08-09: #777
@Suite("Side-loaded volumes (#777)")
struct LocalVolumeCatalogTests {

    /// A minimal but real FRUS TEI header — the shape `TEIHeaderParser` was written against.
    ///
    /// **The fixture id `frus1969-76v99` must stay absent from `manifest.json`.** The first draft
    /// used `frus1969-76v42`, which is a real catalogue volume: `refreshLocalEntries` correctly
    /// declined to mint an entry for it, `entry(forVolumeId:)` returned the catalogue's, and the
    /// test failed on a provenance mismatch — a fixture that was testing the opposite of its name.
    private func volumeXML(title: String = "Foreign Relations of the United States, 1969–1976, Volume XCIX, Test",
                           earliest: String = "1969-01-20",
                           latest: String = "1976-01-20") -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader>
            <fileDesc>
              <titleStmt>
                <title>\(title)</title>
                <editor>Smith, Jane</editor>
              </titleStmt>
              <publicationStmt>
                <date type="publication-date">2019</date>
              </publicationStmt>
            </fileDesc>
            <profileDesc>
              <creation><date type="content-date" notBefore="\(earliest)" notAfter="\(latest)"/></creation>
            </profileDesc>
          </teiHeader>
          <text><body><div type="document" xml:id="d1"><p>Body.</p></div></body></text>
        </TEI>
        """
    }

    /// A temp directory holding the named volumes, cleaned up by the caller.
    private func directory(with volumes: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("frus-sideload-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (volumeId, xml) in volumes {
            try xml.write(to: dir.appendingPathComponent("\(volumeId).xml"),
                          atomically: true, encoding: .utf8)
        }
        return dir
    }

    // MARK: - Minting

    @Test("A side-loaded volume gets its title, dates and editors from its own header")
    func entryIsMintedFromTheHeader() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML()])
        defer { try? FileManager.default.removeItem(at: dir) }

        let entry = try #require(LocalVolumeCatalog.entry(
            volumeId: "frus1969-76v99",
            url: dir.appendingPathComponent("frus1969-76v99.xml"),
            sizeBytes: 1234))

        #expect(entry.title.contains("Volume XCIX"), """
            Without a title the volume renders as a raw id among titled neighbours — the visible \
            half of #777 even once it is browsable.
            """)
        #expect(entry.dateRange.earliest == "1969-01-20")
        #expect(entry.dateRange.latest == "1976-01-20")
        #expect(entry.editors == ["Smith, Jane"])
        #expect(entry.publicationDate == "2019")
        #expect(entry.sizeBytes == 1234)
    }

    @Test("It lands in the subseries its name says, so it sits with its neighbours")
    func conventionalNameJoinsItsEra() {
        #expect(LocalVolumeCatalog.subseries(for: "frus1969-76v99") == "1969-76")
        #expect(LocalVolumeCatalog.subseries(for: "frus1861") == "1861")
    }

    @Test("A name that says nothing gets its own group rather than a wrong era")
    func unconventionalNameIsQuarantined() {
        #expect(LocalVolumeCatalog.subseries(for: "my-draft") == LocalVolumeCatalog.sideloadedSubseries)
        #expect(LocalVolumeCatalog.subseries(for: "frusNOTAYEAR") == LocalVolumeCatalog.sideloadedSubseries)
    }

    @Test("A file that will not parse yields no entry at all")
    func unparseableFileIsNotListed() throws {
        let dir = try directory(with: ["broken": "<not-tei>"])
        defer { try? FileManager.default.removeItem(at: dir) }
        // A browse row leading to a document view that cannot render is worse than no row: the
        // reader has been told the volume works.
        #expect(LocalVolumeCatalog.entry(volumeId: "broken",
                                         url: dir.appendingPathComponent("broken.xml"),
                                         sizeBytes: 10) == nil)
    }

    // MARK: - The three things an entry must NOT do

    @Test("It carries no download URL")
    func sideloadedEntryHasNoDownloadURL() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML()])
        defer { try? FileManager.default.removeItem(at: dir) }
        let entry = try #require(LocalVolumeCatalog.entry(
            volumeId: "frus1969-76v99",
            url: dir.appendingPathComponent("frus1969-76v99.xml"), sizeBytes: 1))

        #expect(entry.provenance == .sideloaded)
        #expect(entry.downloadUrl == nil, """
            `downloadUrl` is CONSTRUCTED from the filename, so it is always well-formed and always \
            plausible. For a side-loaded volume it 404s — or, worse, one day resolves to a \
            different volume published under that name.
            """)
    }

    @Test("A catalogue entry still has one")
    func catalogueEntryKeepsItsDownloadURL() {
        let entry = VolumeManifestEntry(
            volumeId: "frus1969-76v01", filename: "frus1969-76v01.xml", subseries: "1969-76",
            title: "T", dateRange: DateRange(earliest: nil, latest: nil), publicationDate: nil,
            status: .published, editors: [], generalEditor: nil, documentCount: 0,
            sizeBytes: 0, tags: [])
        #expect(entry.provenance == .publishedCatalogue,
                "the default must be the catalogue, or manifest.json's 552 entries lose their URLs")
        #expect(entry.downloadUrl?.hasSuffix("frus1969-76v01.xml") == true)
    }

    @Test("Free Up Space cannot offer it")
    func sideloadedEntryIsNotRedownloadable() throws {
        // The composition that matters: the storage hub builds `redownloadableVolumeIds` from the
        // CATALOGUE, not from `browsableEntries` — so making a side-loaded volume browsable must
        // not quietly make it deletable-with-a-promise again (#777 stage 0).
        let plan = StorageRemovalPlan.make(
            entries: [VolumeStorageEntry(volumeId: "frus1969-76v01", volumeFileBytes: 1),
                      VolumeStorageEntry(volumeId: "frus1969-76v99", volumeFileBytes: 1)],
            protectedVolumeIds: [],
            redownloadableVolumeIds: ["frus1969-76v01"],   // the catalogue, which excludes v42
            lastOpenedByVolumeId: [:])
        #expect(plan.candidates.map(\.volumeId) == ["frus1969-76v01"])
    }

    // MARK: - Reconciliation

    @Test("Reconcile parses unknown volumes, writes sidecars, and leaves catalogue volumes alone")
    func reconcileMintsOnlyUnknownVolumes() throws {
        let dir = try directory(with: [
            "frus1969-76v01": volumeXML(title: "A catalogue volume"),
            "frus1969-76v99": volumeXML(title: "A side-loaded volume"),
        ])
        defer { try? FileManager.default.removeItem(at: dir) }

        let local = LocalVolumeCatalog.reconcile(in: dir, known: ["frus1969-76v01"])
        #expect(local.map(\.volumeId) == ["frus1969-76v99"], """
            A volume the catalogue already knows must not be minted a second time — the catalogue's \
            entry has a download URL and a real publication status where a minted one would not.
            """)
        #expect(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("frus1969-76v99.frusmeta.json").path))
        #expect(!FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("frus1969-76v01.frusmeta.json").path))
    }

    @Test("A second reconcile reads the sidecar and keeps the side-loaded provenance")
    func sidecarRoundTripsAsSideloaded() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML()])
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = LocalVolumeCatalog.reconcile(in: dir, known: [])

        let reloaded = try #require(LocalVolumeCatalog.load(from: dir).first)
        #expect(reloaded.volumeId == "frus1969-76v99")
        #expect(reloaded.provenance == .sideloaded, """
            `provenance` is deliberately NOT decoded, so a sidecar round-trips as \
            `.publishedCatalogue` unless `load` re-stamps it — which would hand it a download URL.
            """)
        #expect(reloaded.downloadUrl == nil)
    }

    @Test("A sidecar whose volume is gone is cleaned up")
    func orphanSidecarIsRemoved() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML()])
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = LocalVolumeCatalog.reconcile(in: dir, known: [])
        try FileManager.default.removeItem(at: dir.appendingPathComponent("frus1969-76v99.xml"))

        #expect(LocalVolumeCatalog.reconcile(in: dir, known: []).isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("frus1969-76v99.frusmeta.json").path),
                "the metadata describes a file that no longer exists")
    }

    // MARK: - The claim the whole fix rests on

    /// Nothing above proves the volume is actually *browsable* — that is `browsableEntries`, and
    /// both browse surfaces read it. Without this test the enumeration can be reverted to the
    /// catalogue and every other assertion here still passes.
    @MainActor
    @Test("The volume reaches browsableEntries and entry(forVolumeId:)")
    func localEntriesReachTheBrowseUniverse() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML(title: "A side-loaded volume")])
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = ManifestStore()
        let catalogueCount = store.browsableEntries.count
        #expect(store.entry(forVolumeId: "frus1969-76v99") == nil, "not there before the reconcile")

        store.refreshLocalEntries(volumesDirectory: dir)

        #expect(store.browsableEntries.count == catalogueCount + 1, """
            The side-loaded volume is not in the browse universe. `BrowserViewModel.allVolumes` and             `MacCorpusBrowserWindow.allEntries` both read this, so it produces no subseries group             and no row — which is #777 exactly.
            """)
        let resolved = try #require(store.entry(forVolumeId: "frus1969-76v99"), """
            `entryIndex` still answers from the catalogue, so the volume renders as a raw id at all             ~53 lookup sites even if it is listed.
            """)
        #expect(resolved.title == "A side-loaded volume")
        #expect(resolved.provenance == .sideloaded)
        #expect(resolved.downloadUrl == nil)
    }

    /// The catalogue must be untouched by any of this.
    @MainActor
    @Test("A store with no side-loaded volumes is byte-for-byte the catalogue")
    func noLocalEntriesChangesNothing() throws {
        let dir = try directory(with: [:])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ManifestStore()
        let before = store.browsableEntries.map(\.volumeId)
        store.refreshLocalEntries(volumesDirectory: dir)
        #expect(store.browsableEntries.map(\.volumeId) == before)
        #expect(store.localEntries.isEmpty)
    }
}
