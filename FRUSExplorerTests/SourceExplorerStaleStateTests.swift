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
@Suite("Source Explorer stale state")
struct SourceExplorerStaleStateTests {

    private let noteA = "Source: Department of State, Secretary's Memoranda of Conversation: Lot 64 D 199."
    private let noteB = "Source: National Archives, RG 59, OES/OA Files: Lot 90 D 234, Box 1."

    @Test("A different document yields a different key")
    func differentDocumentChangesTheKey() {
        let a = MacSourceExplorerLoadIdentity.make(
            volumeId: "frus1958-60v03", documentId: "d42", rawSourceNote: noteA, documentYear: 1958)
        let b = MacSourceExplorerLoadIdentity.make(
            volumeId: "frus1969-76ve03", documentId: "d69", rawSourceNote: noteB, documentYear: 1976)
        #expect(a != b)
    }

    @Test("Each input alone is enough to change the key")
    func everyInputParticipates() {
        let base = MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958)
        // If any of these compared equal, that input could change without a reload — which
        // is the whole defect, in miniature.
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v2", documentId: "d1", rawSourceNote: noteA, documentYear: 1958))
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d2", rawSourceNote: noteA, documentYear: 1958))
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteB, documentYear: 1958))
        #expect(base != MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1976))
    }

    @Test("The same document yields a stable key — no reload loop")
    func sameDocumentIsStable() {
        let a = MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958)
        let b = MacSourceExplorerLoadIdentity.make(
            volumeId: "v1", documentId: "d1", rawSourceNote: noteA, documentYear: 1958)
        #expect(a == b)
    }

    @Test("Field boundaries are real — two documents cannot concatenate into one key")
    func fieldsCannotRunTogether() {
        // The separator is what stops (volumeId "ab", documentId "c") and
        // (volumeId "a", documentId "bc") from producing the same string. A first draft of
        // this test embedded U+001F in one input instead, which survives an unseparated
        // join and so passed even with the separator removed — it proved nothing.
        let a = MacSourceExplorerLoadIdentity.make(
            volumeId: "ab", documentId: "c", rawSourceNote: "n", documentYear: nil)
        let b = MacSourceExplorerLoadIdentity.make(
            volumeId: "a", documentId: "bc", rawSourceNote: "n", documentYear: nil)
        #expect(a != b)
    }

    @Test("A nil year is distinguishable from year zero")
    func nilYearIsNotZero() {
        #expect(MacSourceExplorerLoadIdentity.make(volumeId: "v", documentId: "d",
                                                   rawSourceNote: "n", documentYear: nil)
                != MacSourceExplorerLoadIdentity.make(volumeId: "v", documentId: "d",
                                                      rawSourceNote: "n", documentYear: 0))
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
@Suite("Source Explorer reload wiring")
struct SourceExplorerReloadWiringAuditTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 5_000, "\(path) is implausibly small — did it move?")
        return text
    }

    @Test("Neither view uses a bare .task for its load")
    func noBareLoadTask() throws {
        for path in ["FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
                     "FRUSExplorer/SourceExplorer/SourceExplorerView.swift"] {
            let src = try Self.source(path)
            #expect(src.contains(".task(id: loadIdentity)"),
                    "\(path) does not key its load task on the document identity")
            #expect(!src.contains(".task { await load() }"),
                    "\(path) still has a bare .task — it will load once and never again")
        }
    }

    @Test("macOS load() clears derived state before repopulating it")
    func loadClearsStaleState() throws {
        let src = try Self.source("FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift")
        // Without these the previous document's provenance stays on screen for the whole of
        // the async work — and permanently if load() takes an early return (no API key, or
        // a strategy with no live route).
        guard let body = src.range(of: "private func load() async {") else {
            Issue.record("load() not found"); return
        }
        let head = String(src[body.upperBound...].prefix(700))
        for cleared in ["parsed = nil", "catalogResults = []", "authorityRecord = nil",
                        "countryResolutions = []", "relatedDocs = []"] {
            #expect(head.contains(cleared),
                    "load() does not reset `\(cleared)` before fetching the new document")
        }
    }
}
