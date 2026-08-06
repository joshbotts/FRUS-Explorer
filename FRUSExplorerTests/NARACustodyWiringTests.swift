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

// MARK: - NARACustodyWiringTests

/// Pins that both Source Explorer views actually apply the #681 custody gate and the lot
/// reroute, rather than merely being able to.
///
/// These are **source audits**, and they say so. The behaviour they guard lives inside a
/// SwiftUI `body` and an `async` fetch that both need a live `NARACatalogClient` and an API
/// key, so no unit test can drive them; what a source audit can catch — and what this codebase
/// has actually shipped before (#617 sent a Collections affordance to iOS only) — is one
/// platform being wired and the other forgotten.
///
/// The rule itself is tested properly in `SourceNoteKitTests/NARACustodyTests`.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681
@Suite("NARA custody gate — platform wiring")
struct NARACustodyWiringTests {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        // Comments mention these symbols freely; only live code counts.
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let views = ["FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
                                "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift"]

    /// The gate must sit on the query itself. Measured, 1,961 documents name repositories the
    /// National Archives does not administer; before this, each ran a free-text query whose
    /// results were rendered as up to three findings.
    @Test("Both views gate the presidential-library query on custody")
    func bothViewsGateTheQuery() throws {
        for path in Self.views {
            let code = try source(path)
            #expect(code.contains("NARACustody.mayQueryCatalog(forRepository:"),
                    Comment(rawValue: "\(path) does not consult NARACustody"))
            // The gate must sit inside the branch that issues the query. Checking only that it
            // appears *somewhere earlier* is not enough and was measurably not enough: the
            // macOS view also consults NARACustody in its provenance rows some 750 lines
            // above the fetch, so deleting the real guard left the ordering check passing.
            var searchStart = code.startIndex
            var checkedADispatchBranch = false
            while let libCase = code.range(of: "case .presidentialLibrary(",
                                           range: searchStart..<code.endIndex) {
                let branch = String(code[libCase.lowerBound...].prefix(900))
                searchStart = libCase.upperBound
                guard let query = branch.range(of: "searchByPresidentialMaterials(") else { continue }
                checkedADispatchBranch = true
                guard let gate = branch.range(of: "NARACustody.mayQueryCatalog(forRepository:") else {
                    Issue.record(Comment(rawValue: "\(path) issues the presidential-library "
                                         + "query without checking custody in the same branch"))
                    continue
                }
                #expect(gate.lowerBound < query.lowerBound,
                        Comment(rawValue: "\(path) queries before it checks custody"))
            }
            #expect(checkedADispatchBranch,
                    Comment(rawValue: "\(path) has no .presidentialLibrary branch that queries "
                            + "the catalogue — this audit inspected nothing"))
        }
    }

    /// A record-group citation that names a lot belongs on the guarded route — 853 documents
    /// that were running the unfiltered record-group query for a citation the acceptance test
    /// was built for.
    @Test("Both views route a lot-carrying record-group citation to the guarded path")
    func bothViewsRerouteLotCarryingCollections() throws {
        for path in Self.views {
            let code = try source(path)
            // Both files match `.naraCollection` more than once — the provenance rows render
            // one branch and the catalogue fetch another. Anchor on the branch that actually
            // queries, or this audit passes by inspecting the wrong one.
            var searchStart = code.startIndex
            var checkedADispatchBranch = false
            while let naraCase = code.range(of: "case .naraCollection(", range: searchStart..<code.endIndex) {
                let branch = String(code[naraCase.lowerBound...].prefix(1600))
                searchStart = naraCase.upperBound
                guard branch.contains("searchByRecordGroup") else { continue }
                checkedADispatchBranch = true
                #expect(branch.contains("resolveLotFileVariants"),
                        Comment(rawValue: "\(path) never routes a lot-carrying record-group "
                                + "citation to the guarded lot path"))
            }
            #expect(checkedADispatchBranch,
                    Comment(rawValue: "\(path) has no .naraCollection branch that queries the "
                            + "catalogue — this audit inspected nothing"))
        }
    }

    /// Refusing silently would be its own defect: the researcher would see an empty section and
    /// conclude the catalogue had been searched and found nothing.
    @Test("Both views explain the refusal rather than showing nothing")
    func bothViewsExplainTheRefusal() throws {
        for path in Self.views {
            #expect(try source(path).contains("source.explorer.nara.outsideCustody"),
                    Comment(rawValue: "\(path) refuses without saying why"))
        }
    }
}
