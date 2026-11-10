// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

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
    }
}

// MARK: - SourceExplorerReloadWiringAuditTests

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
@Suite("Source Explorer reload wiring")
struct SourceExplorerReloadWiringAuditTests {

    /// The two hand-maintained twins.
    static let twins = ["FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
                        "FRUSExplorer/SourceExplorer/SourceExplorerView.swift"]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
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

    @Test("Both twins reset the pre-1906 state before their first await; macOS clears the rest too")
    func loadClearsStaleState() throws {
        var swept = 0
        for path in Self.twins {
            let load = try Self.body(of: "private func load() async {", in: Self.code(path))
            let head = String(load.prefix(700))
            let beforeAwait = String(load[..<(load.range(of: "await ")?.lowerBound ?? load.endIndex)])
            // Without these the previous document's rolls, serial and year stay on screen for the
            // whole of the async work — and the new key reloads a live view in place.
            for cleared in ["countrySeriesOutcome = .loading", "documentContext = nil"] {
                #expect(head.contains(cleared) && beforeAwait.contains(cleared),
                        "\(path) load() does not reset `\(cleared)` before its first await")
            }
            if path.contains("Mac") {
                for cleared in ["parsed = nil", "catalogResults = []", "authorityRecord = nil", "relatedDocs = []"] {
                    #expect(head.contains(cleared),
                            "load() does not reset `\(cleared)` before fetching the new document")
                }
            }
            swept += 1
        }
        #expect(swept == 2)
    }

    @Test("Both twins run the shared evaluation, leave the roster to it, and neither re-implements it")
    func bothTwinsCallEvaluate() throws {
        var swept = 0
        for path in Self.twins {
            let text = try Self.code(path)
            let resolve = try Self.body(of: "private func resolveCountrySeries() async {", in: text)
            #expect(resolve.contains("CentralFilesClassifier.evaluate("), "\(path) does not call evaluate")
            // `evaluate` reads the bundled roster itself, off the main actor and only once both gates pass;
            // a twin passing `roster:` would decode pocom-index.json on the main actor on first open.
            #expect(!resolve.contains("roster:"), "\(path) passes its own roster to evaluate")
            // Order, not presence: the cancel check comes after the evaluation's await and before either write,
            // or a load cancelled mid-evaluation writes its document's answer over the next one's reset.
            let evaluated = try #require(resolve.range(of: "CentralFilesClassifier.evaluate("), "\(path)")
            let cancelCheck = try #require(resolve.range(of: "guard !Task.isCancelled"), "\(path) has no cancel check")
            let writeContext = try #require(resolve.range(of: "documentContext = result.context"), "\(path)")
            let writeOutcome = try #require(resolve.range(of: "countrySeriesOutcome = result.outcome"), "\(path)")
            #expect(evaluated.lowerBound < cancelCheck.lowerBound, "\(path) checks for a cancel before the evaluation")
            #expect(cancelCheck.lowerBound < writeContext.lowerBound && cancelCheck.lowerBound < writeOutcome.lowerBound,
                    "\(path) writes the outcome before checking for a cancel")
            #expect(text.components(separatedBy: "CentralFilesClassifier.evaluate(").count - 1 == 1)
            // The loop, the enclosure lookup and the serial read moved into the classifier; a copy left
            // in a twin is the drift this refactor exists to end.
            for moved in ["CentralFilesClassifier.classify(", "enclosureHomes(", ".despatchSerial(volumeId:"] {
                #expect(!text.contains(moved), "\(path) still calls \(moved) itself")
            }
            swept += 1
        }
        #expect(swept == 2)
    }

    /// The evaluation can parse the document for its enclosures on an AST-cache miss, so whatever waits
    /// behind it waits on that. The authority record reads no year and goes first; everything that reads
    /// the year the evaluation may fill in comes after it.
    @Test("Both twins evaluate after the authority record and before the pointers and related documents")
    func evaluateRunsAfterTheAuthorityRecord() throws {
        var swept = 0
        for path in Self.twins {
            let load = try Self.body(of: "private func load() async {", in: Self.code(path))
            let authority = try #require(load.range(of: "authorityRecord = await"), "\(path)")
            let evaluate = try #require(load.range(of: "await resolveCountrySeries()"), "\(path)")
            // #1390: the loader takes the note this load parsed, so every pointer carries it.
            let pointers = try #require(load.range(of: "await loadUnprintedPointers(sourceNote: note)"),
                                        "\(path)")
            let related = try #require(load.range(of: "await loadRelatedDocuments("), "\(path)")
            #expect(authority.lowerBound < evaluate.lowerBound, "\(path) evaluates before the authority record")
            #expect(evaluate.lowerBound < pointers.lowerBound, "\(path) evaluates after the pointers")
            #expect(evaluate.lowerBound < related.lowerBound, "\(path) evaluates after Related Documents")
            #expect(load.components(separatedBy: "await resolveCountrySeries()").count - 1 == 1)
            swept += 1
        }
        #expect(swept == 2)
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
