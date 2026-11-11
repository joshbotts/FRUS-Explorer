// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - SourceExplorerStaleStateTests

/// The `.task(id:)` key that makes Source Explorer notice it is looking at a new document,
/// and the audit that it is actually used.
///
/// ## The bug
/// The macOS Source Explorer is a persistent `Window`. SwiftUI kept one view instance and
/// swapped its properties, so a bare `.task { await load() }` fired once and never again:
/// the raw source note tracked the current document (it is read in `body`) while the lot
/// number, record group, archival collection and NARA results stayed pinned to the first
/// document opened. Reported against build 39 with one document's note shown above another
/// document's provenance.
///
/// Version history:
///   1.0 — Session 2026-08-04: N-8 stale-state fix
///   1.1 — 2026-09-13: pipeline availability joins the key
///   1.2 — 2026-11-10 (FRUS Explorer Light, S22b): moved into FRUSCoreKit's suites with the load identity;
///         the scans of the twins' source run in Xcode alone
@Suite("Source Explorer stale state")
struct SourceExplorerStaleStateTests {

    private let noteA = "Source: Department of State, Secretary's Memoranda of Conversation: Lot 64 D 199."
    private let noteB = "Source: National Archives, RG 59, OES/OA Files: Lot 90 D 234, Box 1."

    @Test("A different document yields a different key")
    func differentDocumentChangesTheKey() {
        let a = MacSourceExplorerLoadIdentity.make(
            volumeId: "frus1958-60v03", documentId: "d42", rawSourceNote: noteA, documentYear: 1958,
            pipelineAvailable: true)
        let b = MacSourceExplorerLoadIdentity.make(
            volumeId: "frus1969-76ve03", documentId: "d69", rawSourceNote: noteB, documentYear: 1976,
            pipelineAvailable: true)
        #expect(a != b)
    }

    @Test("Each input alone is enough to change the key")
    func everyInputParticipates() {
        let base = MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958, pipelineAvailable: true)
        // If any of these compared equal, that input could change without a reload — which
        // is the whole defect, in miniature.
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v2", documentId: "d1", rawSourceNote: noteA, documentYear: 1958, pipelineAvailable: true))
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d2", rawSourceNote: noteA, documentYear: 1958, pipelineAvailable: true))
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteB, documentYear: 1958, pipelineAvailable: true))
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1976, pipelineAvailable: true))
        // The pipeline appearing after a window rendered is the change a restored window never saw:
        // with the key unchanged, its load never re-ran and the pre-1906 section stayed "not checked".
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958, pipelineAvailable: false))
    }

    @Test("The same document yields a stable key — no reload loop")
    func sameDocumentIsStable() {
        let a = MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958, pipelineAvailable: true)
        let b = MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958, pipelineAvailable: true)
        #expect(a == b)
    }

    @Test("Field boundaries are real — two documents cannot concatenate into one key")
    func fieldsCannotRunTogether() {
        // The separator is what stops (volumeId "ab", documentId "c") and
        // (volumeId "a", documentId "bc") from producing the same string. A first draft of
        // this test embedded U+001F in one input instead, which survives an unseparated
        // join and so passed even with the separator removed — it proved nothing.
        let a = MacSourceExplorerLoadIdentity.make(
            volumeId: "ab", documentId: "c", rawSourceNote: "n", documentYear: nil, pipelineAvailable: true)
        let b = MacSourceExplorerLoadIdentity.make(
            volumeId: "a", documentId: "bc", rawSourceNote: "n", documentYear: nil, pipelineAvailable: true)
        #expect(a != b)
    }

    @Test("A nil year is distinguishable from year zero")
    func nilYearIsNotZero() {
        #expect(MacSourceExplorerLoadIdentity.make(volumeId: "v", documentId: "d",
                                                   rawSourceNote: "n", documentYear: nil, pipelineAvailable: true)
                != MacSourceExplorerLoadIdentity.make(volumeId: "v", documentId: "d",
                                                      rawSourceNote: "n", documentYear: 0, pipelineAvailable: true))
    }
}

// MARK: - SourceExplorerHydrationTests

/// `SourceExplorerDocumentContext.hydrate` — how Source Explorer fills in what the opening route did
/// not pass, one rule per test, each fixture breaking exactly one condition.
///
/// The type case is `frus1863p2/d573` opened from the iPad Research tab: the route passed `d573` as
/// its header and no dateline, so no pre-1906 roll could be offered. The index row holds
/// `Mr. Seward to Mr. Dayton.`, `Department of State , Washington , November 10, 1863.` and serial 428.
///
/// Version history:
///   1.0 — 2026-09-13: initial implementation
@Suite("Source Explorer hydration")
struct SourceExplorerHydrationTests {

    /// d573's index row, as read live from the device index.
    private let d573Row = IndexingPipeline.SourceExplorerFacts(
        header: "Mr. Seward to Mr. Dayton.",
        dateline: "Department of State , Washington , November 10, 1863.",
        despatchSerial: "428")

    /// A row that disagrees with every route value below, so a test can tell which one won.
    private let disagreeingRow = IndexingPipeline.SourceExplorerFacts(
        header: "Index header", dateline: "Paris, January 1, 1850.", despatchSerial: "7")

    @Test("R1: a dateline the route passed wins over the index's, and so does its real header")
    func hydrateR1() {
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: "Mr. Seward to Mr. Dayton.", routeDateline: "Department of State, Washington, November 10, 1863.",
            routeYear: nil, documentId: "d573", indexed: disagreeingRow)
        #expect(context.dateline == "Department of State, Washington, November 10, 1863.")
        #expect(context.header == "Mr. Seward to Mr. Dayton.")
        // The year comes from the dateline that won — 1863, not the index dateline's 1850.
        #expect(context.year == 1863)
    }

    @Test("R1: a route header that is only the document id gives way to the index header")
    func hydrateR1PlaceholderHeader() {
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: "d573", routeDateline: "Department of State, Washington, November 10, 1863.",
            routeYear: 1863, documentId: "d573", indexed: d573Row)
        #expect(context.header == "Mr. Seward to Mr. Dayton.")
        #expect(context.dateline == "Department of State, Washington, November 10, 1863.",
                "the route's dateline still wins under R1")
        let blank = SourceExplorerDocumentContext.hydrate(
            routeHeader: "  ", routeDateline: "Department of State, Washington, November 10, 1863.",
            routeYear: 1863, documentId: "d573", indexed: d573Row)
        #expect(blank.header == "Mr. Seward to Mr. Dayton.")
    }

    @Test("R2: with no route dateline, both the dateline and the header come from the index")
    func hydrateR2() {
        // A Citation Lookup-style header: not blank and not the document id, so R1's placeholder test
        // would keep it. Only R2 replaces it.
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: "frus1863p2 — d573", routeDateline: nil, routeYear: nil,
            documentId: "d573", indexed: d573Row)
        #expect(context.header == "Mr. Seward to Mr. Dayton.")
        #expect(context.dateline == "Department of State , Washington , November 10, 1863.")
        #expect(context.year == 1863)
    }

    @Test("R3: with no index row, the route's values are kept")
    func hydrateR3() {
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: "frus1863p2 — d573", routeDateline: nil, routeYear: nil,
            documentId: "d573", indexed: nil)
        #expect(context.header == "frus1863p2 — d573")
        #expect(context.dateline == nil)
        #expect(context.year == nil)
        #expect(context.despatchSerial == nil)
    }

    @Test("R4: the serial comes from the index even when the route's dateline wins")
    func hydrateR4() {
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: "Mr. Seward to Mr. Dayton.", routeDateline: "Department of State, Washington, November 10, 1863.",
            routeYear: 1863, documentId: "d573", indexed: d573Row)
        #expect(context.despatchSerial == "428")
    }

    /// The key reads what the host passed; hydration writes view state. If a twin keyed on the hydrated
    /// year, hydrating would change the key and reload the view it just hydrated.
    @Test("Hydration does not change the load key, and neither twin keys on a hydrated value")
    func keyUnchangedByHydration() throws {
        let context = SourceExplorerDocumentContext.hydrate(
            routeHeader: "d573", routeDateline: nil, routeYear: nil, documentId: "d573", indexed: d573Row)
        #expect(context.year == 1863, "fixture guard: hydration must fill a year the route left out")
        let hostKey = MacSourceExplorerLoadIdentity.make(
            volumeId: "frus1863p2", documentId: "d573", rawSourceNote: "", documentYear: nil, pipelineAvailable: true)
        #expect(hostKey != MacSourceExplorerLoadIdentity.make(
            volumeId: "frus1863p2", documentId: "d573", rawSourceNote: "", documentYear: context.year,
            pipelineAvailable: true), "fixture guard: keying on the hydrated year WOULD change the key")

        #if !SWIFT_PACKAGE // every scan of the twins' source is the app's (its CLAUDE.md)
        var swept = 0
        for path in SourceExplorerReloadWiringAuditTests.twins {
            let body = try SourceExplorerReloadWiringAuditTests.body(
                of: "var loadIdentity: String {", in: SourceExplorerReloadWiringAuditTests.code(path))
            #expect(body.contains("documentYear: documentYear"), "\(path) must key on the host's year")
            #expect(!body.contains("effectiveYear") && !body.contains("documentContext"),
                    "\(path) keys on a hydrated value — hydrating would reload the view")
            swept += 1
        }
        #expect(swept == 2)
        #endif
    }
}

// MARK: - SourceExplorerReloadWiringAuditTests

#if !SWIFT_PACKAGE // every scan of the twins' source is the app's (its CLAUDE.md)

/// That both Source Explorer views key their load task and clear stale state.
///
/// A unit test cannot observe a SwiftUI `.task(id:)` firing, and the key being *correct* is
/// worth nothing if the view still uses a bare `.task` — which is exactly the state the
/// codebase was in. A source scan is the available guard.
///
/// Version history:
///   1.0 — Session 2026-08-04: N-8 stale-state fix
///   1.1 — 2026-09-13: both twins reset the pre-1906 outcome and context before any await, call the
///         shared `evaluate`, key on the pipeline, label the serial through the shared type, and print
///         "couldn't be predicted" only for a check that found nothing. Scans are scoped to a member
///         body with comment lines stripped.
///   1.2 — 2026-09-24: the order scan reads the pointer load as `loadUnprintedPointers(sourceNote:
///         note)`, which now takes the note the load parsed (#1390)
///   1.3 — 2026-11-10 (FRUS Explorer Light, S22b): the twins' `load()` runs the shared sequence
///         (`SourceExplorerResolution.resolved`), so the scans read that each sets its starting value
///         before its first await, runs the sequence once with the host's route, index and the app's
///         dependencies, writes it only while its load is current and asks NARA nothing once cancelled,
///         that neither runs a step of it itself, and that the Mac's Refresh goes through the load key.
///         The order the steps run in is the kit's, which `SourceExplorerResolutionTests` drives at run
///         time, so the order scan is gone
@Suite("Source Explorer reload wiring")
struct SourceExplorerReloadWiringAuditTests {

    /// The two hand-maintained twins.
    static let twins = ["FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
                        "FRUSExplorer/SourceExplorer/SourceExplorerView.swift"]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 5_000, "\(path) is implausibly small — did it move?")
        return text
    }

    /// A twin's source with comment lines blanked, so a comment can neither satisfy nor break a scan.
    static func code(_ path: String) throws -> String {
        try source(path).split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
    }

    /// The body of the member whose declaration line contains `signature`, up to its matching brace.
    static func body(of signature: String, in text: String) throws -> String {
        let start = try #require(text.range(of: signature), "\(signature) not found")
        var depth = 1
        var index = start.upperBound
        while index < text.endIndex, depth > 0 {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" { depth -= 1 }
            index = text.index(after: index)
        }
        return String(text[start.upperBound..<index])
    }

    @Test("Neither view uses a bare .task for its load")
    func noBareLoadTask() throws {
        for path in Self.twins {
            let src = try Self.source(path)
            #expect(src.contains(".task(id: loadIdentity)"),
                    "\(path) does not key its load task on the document identity")
            #expect(!src.contains(".task { await load() }"),
                    "\(path) still has a bare .task — it will load once and never again")
        }
    }

    @Test("Both twins set their starting value before their first await; macOS clears its live results too")
    func loadClearsStaleState() throws {
        var swept = 0
        for path in Self.twins {
            let load = try Self.body(of: "private func load() async {", in: Self.code(path))
            let beforeAwait = String(load[..<(load.range(of: "await ")?.lowerBound ?? load.endIndex)])
            // Without this the previous document's rolls, serial, year, pointers and neighbours stay on
            // screen for the whole of the async work — and the new key reloads a live view in place. The
            // resolution is one value, so one write sets every part of it: the parse alone for another
            // document, and for the one already shown its parts with the pre-1906 section reset.
            #expect(beforeAwait.contains("resolution = start") && beforeAwait.contains("resolvedDocument = document"),
                    "\(path) load() does not set its starting value before its first await")
            #expect(beforeAwait.contains("resolution?.resolvingAgain()")
                        && beforeAwait.contains("SourceExplorerResolution(rawSourceNote: rawSourceNote)"),
                    "\(path) load() does not choose its start by the document it shows")
            if path.contains("Mac") {
                for cleared in ["catalogResults = []", "loadError = nil", "manualQuery = \"\""] {
                    #expect(beforeAwait.contains(cleared),
                            "load() does not reset `\(cleared)` before fetching the new document")
                }
            }
            swept += 1
        }
        #expect(swept == 2)
    }

    @Test("Both twins run the shared sequence once, write it only while current, and run no step of it")
    func bothTwinsRunTheSharedSequence() throws {
        var swept = 0
        for path in Self.twins {
            let text = try Self.code(path)
            let load = try Self.body(of: "private func load() async {", in: Self.code(path))
            let flat = load.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            // The sequence's call, which `route:` opens; `.resolved(` also opens two `case` patterns in each
            // view, the country series' outcome's and the digitized range's.
            let sequenceCall = try Regex(#"\.resolved\(\s*route:"#)
            #expect(text.matches(of: sequenceCall).count == 1,
                    "\(path) runs the sequence more than once, or not at all")
            // The host's own route, its index and the app's files: a route built with another year or
            // without the document, or no index, would silently lose the day, the marking, the pointers
            // and the neighbours, and every other test would still pass.
            #expect(flat.contains("CountrySeriesRoute(header: documentHeader, dateline: documentDateline, "
                                  + "year: documentYear, volumeId: documentVolumeId, documentId: documentId)"),
                    "\(path) builds its route from something other than what the host passed")
            #expect(flat.contains("await start.resolved( route: route, pipeline: indexingPipeline, "
                                  + "dependencies: .app(appState, volumeId: documentVolumeId))"),
                    "\(path) runs the sequence with another route, index or dependencies")
            #expect(!load.contains("roster:"), "\(path) passes its own roster")
            // Order, not presence: each step's value is written after the cancel check, the result only
            // after another, and nothing after a cancel — no live call either, whose result or error would
            // land on the load that replaced this one.
            let call = try #require(load.firstMatch(of: sequenceCall)?.range, "\(path)")
            let stepGuard = try #require(load.range(of: "guard !Task.isCancelled else { return }",
                                                    range: call.upperBound..<load.endIndex), "\(path)")
            let stepWrite = try #require(load.range(of: "resolution = step",
                                                    range: stepGuard.upperBound..<load.endIndex), "\(path)")
            let finalGuard = try #require(load.range(of: "guard !Task.isCancelled else { return }",
                                                     range: stepWrite.upperBound..<load.endIndex),
                                          "\(path) writes the result without checking for a cancel")
            #expect(load.range(of: "resolution = resolved", range: finalGuard.upperBound..<load.endIndex) != nil,
                    "\(path) does not write the result after its cancel check")
            #expect(!load[call.lowerBound..<finalGuard.lowerBound].contains("client."),
                    "\(path) asks NARA something between the sequence and its cancel check")
            // Every step is the sequence's; a copy left in a twin is the drift this refactor exists to end.
            for moved in ["CentralFilesClassifier.evaluate(", "CentralFilesClassifier.classify(", "enclosureHomes(",
                          ".despatchSerial(volumeId:", "UnprintedPointer.list(", ".externalCitations(",
                          ".archivalNeighbors(", "relatedDocuments(for:", "PresidentialLibraryOutcome.resolve(",
                          "SourceExplorerDocumentContext.documentDay(", "SourceExplorerDocumentContext.storedClassification(",
                          ".record(forParsed:", "resolveCountrySeries", "loadUnprintedPointers", "loadRelatedDocuments"] {
                #expect(!text.contains(moved), "\(path) still runs \(moved) itself")
            }
            swept += 1
        }
        #expect(swept == 2)
    }

    /// The Mac window is persistent and Refresh ran `load()` in an unstructured `Task`, which no change
    /// of document cancels: its values would land on the next document. It bumps the load key instead.
    @Test("The Mac's Refresh re-runs the keyed load, not a load of its own")
    func refreshGoesThroughTheLoadKey() throws {
        let text = try Self.code("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift")
        #expect(!text.contains("Task { await load() }"), "Refresh runs a load no change of document cancels")
        #expect(text.contains("refreshGeneration += 1"), "Refresh does not change the load key")
        let key = try Self.body(of: "var loadIdentity: String {", in: text)
        #expect(key.contains("refreshGeneration"), "the load key leaves Refresh out")
    }

    @Test("Both twins key their load on pipeline availability")
    func bothTwinsKeyOnPipeline() throws {
        var swept = 0
        for path in Self.twins {
            let key = try Self.body(of: "var loadIdentity: String {", in: Self.code(path))
            #expect(key.contains("pipelineAvailable: indexingPipeline != nil"),
                    "\(path) leaves the pipeline out of its load key")
            swept += 1
        }
        #expect(swept == 2)
    }

    @Test("Neither twin hard-codes the despatch label")
    func neitherTwinHardCodesTheSerialLabel() throws {
        var swept = 0
        for path in Self.twins {
            let text = try Self.code(path)
            #expect(!text.contains("\"Despatch No. %@\""), "\(path) still labels every serial a despatch")
            #expect(text.contains("serialLabel.title(serial: serial)") && text.contains("serialLabel.caption"),
                    "\(path) does not label the serial through CentralFilesSerialLabel")
            swept += 1
        }
        #expect(swept == 2)
    }

    /// "Couldn't be predicted from its dateline and FRUS chapter" is true only when the check ran and
    /// found nothing. It used to print while loading, for every refusal, and for 1906-and-later
    /// documents where nothing ran at all.
    @Test("Only the no-match state prints the couldn't-be-predicted sentence")
    func onlyNoMatchUsesNoNoteDetail() throws {
        let members = ["FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift": "private var noSourceNoteBox: some View {",
                       "FRUSExplorer/SourceExplorer/SourceExplorerView.swift": "private var noSourceNoteSection: some View {"]
        var swept = 0
        for (path, signature) in members {
            let text = try Self.code(path)
            #expect(text.components(separatedBy: "\"source.explorer.noNote.detail\"").count - 1 == 1,
                    "\(path) uses noNote.detail more than once")
            let body = try Self.body(of: signature, in: text)
            var currentCase: String?
            var found = false
            for line in body.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("case ") { currentCase = trimmed }
                if line.contains("\"source.explorer.noNote.detail\"") {
                    found = true
                    #expect(currentCase == "case .noMatch:", "\(path) prints noNote.detail under \(currentCase ?? "no case")")
                }
            }
            #expect(found, "\(path) no longer prints noNote.detail inside \(signature)")
            swept += 1
        }
        #expect(swept == 2)
    }
}
#endif
