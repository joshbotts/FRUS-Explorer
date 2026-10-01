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
            status: .published, editors: [], generalEditor: nil,
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

    // MARK: - Citation resolution refuses it (#1523)

    /// Owner decision D7 (#1523): Citation Lookup and Add Documents refuse a side-loaded volume —
    /// they resolve citations against the bundled catalogue only, which knows a published volume's
    /// numbering and a side-loaded one's not — and the import says so. This pins the refusal through
    /// the real engine over a side-loaded volume that is on disk, in the browse universe, and
    /// titled, so an engine widened to `browsableEntries` fails each half (measured, by that
    /// mutant): a link to it, the same link pasted into Add Documents, and the app's own citation
    /// of it (which `entry(forVolumeId:)` lets Copy Citation build).
    ///
    /// The citation half asks an engine that counts no volume downloaded, because there a
    /// resolution that reached the volume would show as a row naming it, offered for download; an
    /// engine reading the file on disk with no index behind it answers a citation of it with
    /// nothing either way, so it could not tell a refusal from a resolution (the first draft of
    /// this test passed under the mutant for that reason).
    @MainActor
    @Test("Citation Lookup and Add Documents refuse a side-loaded volume's link and citation, though it is on disk and browsable (#1523)")
    func citationResolutionRefusesASideloadedVolume() async throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML()])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ManifestStore()
        store.refreshLocalEntries(volumesDirectory: dir)
        let sideloaded = try #require(store.entry(forVolumeId: "frus1969-76v99"),
                                      "the fixture must be a browsable side-loaded volume, or the test proves nothing")
        #expect(sideloaded.provenance == .sideloaded)
        #expect(store.browsableEntries.contains { $0.volumeId == "frus1969-76v99" })

        let onDisk = CitationMatchingEngine(manifestStore: store, searchService: nil, pageRangeStore: nil,
                                            volumesDirectory: dir)
        let parser = CitationParser()
        let link = "https://history.state.gov/historicaldocuments/frus1969-76v99/d1"
        let linked = try await onDisk.match(input: parser.parse(link))
        #expect(linked.isEmpty, "a link to the side-loaded volume answered \(linked.map(\.volumeId))")

        let addDocuments = CollectionCitationLineResolver(parse: { parser.parse($0) },
                                                          match: { try await onDisk.match(input: $0) })
        let outcome = await addDocuments.resolve(line: link)
        let noMatch = String(localized: "collection.addDocs.citations.noMatch",
                             defaultValue: "No match found in the local manifest or index")
        #expect(outcome == .unresolved(reason: noMatch), "Add Documents answered the side-loaded volume's link: \(outcome)")

        let ownCitation = HistoryAtStateCitationFormatter().format(
            document: FRUSDocumentMetadata(documentId: "d1", documentNumber: "1", header: "Header", dateline: nil),
            volume: FRUSVolumeMetadata(sideloaded))
        let catalogueOnly = CitationMatchingEngine(manifestStore: store, searchService: nil, pageRangeStore: nil,
                                                   downloadedVolumeIds: [])
        let cited = try await catalogueOnly.match(input: parser.parse(ownCitation))
        #expect(!cited.isEmpty, "the citation must reach some volume, or the check below is vacuous: \(ownCitation)")
        #expect(!cited.contains { $0.volumeId == "frus1969-76v99" }, "\(ownCitation) → \(cited.map(\.volumeId))")
    }

    /// The other half of D7 (#1523): when the reader side-loads a volume, the import tells them that
    /// such volumes are left out of the features that rely on the bundled publication data. The two
    /// storage hubs are hand-maintained twins (one per platform, and the iOS test host compiles
    /// only its own), so each is read: its import handler collects the ids it imported and asks
    /// `SideloadCatalogueNotice.applies` with the catalogue citation resolution reads, and its
    /// outcome row is followed by the notice.
    @Test("Both storage hubs tell the reader after a side-load that citation resolution leaves the volume out (#1523)",
          arguments: ["FRUSExplorer/Settings/VolumesStorageHubView.swift",
                      "FRUSExplorer/Settings/MacVolumesStorageHub.swift"])
    func hubsShowTheCatalogueNotice(_ path: String) throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        let handler = try #require(CitationLookupViewWiringTests.body(
            after: "private func handleSideload(_ result: Result<[URL], Error>) async", in: source),
            "\(path): no import handler")
        #expect(handler.contains("importedIds.append(volumeId)"), "\(path): \(handler)")
        // Compared with every space removed, so the call may wrap as it likes.
        let unspaced = handler.filter { !$0.isWhitespace }
        #expect(unspaced.contains(#"sideloadNoticeShown=SideloadCatalogueNotice.applies(importedVolumeIds:importedIds,citableVolumeIds:Set(appState.manifestStore.citableEntries.map(\.volumeId)))"#),
                "\(path): \(handler)")
        let collapsed = source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(collapsed.contains("if let outcome = sideloadOutcome { sideloadOutcomeRow(outcome) } if sideloadNoticeShown { SideloadCatalogueNoticeRow() }"),
                "\(path): the outcome row is not followed by the notice")
    }

    /// The rule the hubs call, one fixture per answer: an import of a volume the catalogue lacks
    /// draws the notice, one named after a catalogue volume does not (that file IS the catalogue's
    /// volume, which citation resolution answers for), a mixed import does, and an import that
    /// added no volume does not. The catalogue is the real `citableEntries`, which holds no
    /// side-loaded volume.
    @MainActor
    @Test("The side-load notice is drawn by a volume the catalogue lacks, and only by one (#1523)")
    func catalogueNoticeRule() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML()])
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ManifestStore()
        store.refreshLocalEntries(volumesDirectory: dir)
        let citable = Set(store.citableEntries.map(\.volumeId))
        #expect(citable.count >= 553, "the catalogue read \(citable.count) volumes")
        #expect(!citable.contains("frus1969-76v99"), "a side-loaded volume must not be citable")
        #expect(SideloadCatalogueNotice.applies(importedVolumeIds: ["frus1969-76v99"], citableVolumeIds: citable))
        #expect(!SideloadCatalogueNotice.applies(importedVolumeIds: ["frus1969-76v01"], citableVolumeIds: citable))
        #expect(SideloadCatalogueNotice.applies(importedVolumeIds: ["frus1969-76v01", "frus1969-76v99"],
                                                citableVolumeIds: citable))
        #expect(!SideloadCatalogueNotice.applies(importedVolumeIds: [], citableVolumeIds: citable))
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

    // MARK: - Boot reconciliation

    /// What boot calls: `AppState`'s reconcile reads the side-loaded volumes in its volumes
    /// directory into its catalogue, so they carry their titles before anything has run.
    @MainActor
    @Test("AppState's reconcile puts the side-loaded volumes in its catalogue")
    func appStateReconcileReadsTheVolumesDirectory() throws {
        let dir = try directory(with: ["frus1969-76v99": volumeXML(title: "A side-loaded volume")])
        defer { try? FileManager.default.removeItem(at: dir) }
        let appState = AppState()
        appState.reconcileSideloadedVolumes()
        #expect(appState.manifestStore.entry(forVolumeId: "frus1969-76v99") == nil,
                "no volumes directory yet, so nothing to read")

        appState.volumesDirectory = dir
        appState.reconcileSideloadedVolumes()
        #expect(appState.manifestStore.entry(forVolumeId: "frus1969-76v99")?.title == "A side-loaded volume")
    }

    /// The source text of `FRUSExplorer/App/FRUSExplorerApp.swift`'s `bootDownloadManager()`, read
    /// to the brace that balances its opening one.
    private func bootBody() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: "FRUSExplorer/App/FRUSExplorerApp.swift"),
                              encoding: .utf8)
        let declaration = try #require(text.range(of: "private func bootDownloadManager() async"),
                                       "bootDownloadManager moved")
        let open = try #require(text[declaration.upperBound...].firstIndex(of: "{"))
        var depth = 0
        var index = open
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return String(text[open...index]) }
            }
            index = text.index(after: index)
        }
        Issue.record("bootDownloadManager's braces never balance")
        return ""
    }

    /// `text` with every `//` comment cut, so a call that has been commented out is not read as a
    /// call (measured: the first draft of the test below passed with the boot call commented out).
    private func code(_ text: String) -> String {
        text.components(separatedBy: "\n").map { line in
            line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line
        }.joined(separator: "\n")
    }

    /// Before 2026-10-01 nothing at boot read the sidecars, and two doc comments said it did: a
    /// relaunch with no indexing batch listed side-loaded volumes by raw id until a hub action or
    /// the end of a batch reached `refreshAfterCorpusChange`. The UI suite's storage rows read
    /// `uitest-storage-0N` where their headers say "UI Test Storage Row 0N" (`VolumeRemovalTests`
    /// checks the title on screen).
    @Test("Boot reconciles side-loaded volumes once the volumes directory is known and the UI-test rows are on disk")
    func bootReconcilesSideloadedVolumes() throws {
        let boot = code(try bootBody())
        #expect(boot.count > 1_000, "bootDownloadManager is implausibly small (\(boot.count) characters)")
        let call = try #require(boot.range(of: "appState.reconcileSideloadedVolumes()"), """
            Boot does not reconcile side-loaded volumes, so a relaunch lists them by raw id until a \
            hub action or an indexing batch.
            """)
        let directory = try #require(boot.range(of: "appState.volumesDirectory = volumesDir"))
        #expect(directory.upperBound <= call.lowerBound,
                "boot reconciles before the volumes directory is set, which makes it a no-op")
        let rows = try #require(boot.range(of: "UITestVolumeSeeder.prepareStorageRowsIfRequested(in: volumesDir)"))
        #expect(rows.upperBound <= call.lowerBound, """
            Boot reconciles before the UI-test storage rows are written or swept, so a launch reads \
            the previous launch's rows.
            """)
    }
}
