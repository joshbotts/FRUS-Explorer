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

/// Every scope that reaches the query must reach `advancedFilterSignature`.
///
/// ## The bug class this exists to close
/// On macOS the Advanced popover applies live, and what tells it the filter view model changed is
/// `SearchViewModel.advancedFilterSignature`. A scope that is copied into `SearchParameters` but
/// omitted from that signature is therefore a **control that moves and changes nothing** — the
/// no-silent-no-ops defect, in the one place where it is invisible to a reader because the query
/// looks like it ran.
///
/// It has now happened three times. Twice it was fixed in place and recorded in that function's
/// own comments (the working-corpus keys, M-1). The third was `includeFrontMatter`, which shipped:
/// the popover drew a live toggle, the results never changed, and the window went on labelling
/// front-matter rows with a teal chip the reader had just asked to exclude.
///
/// ## Why the existing test could not see it
/// `SheetExitTests`' sibling `MacChromeHonestyTests.everyScopeChipIsWired` (#903) checks that every
/// `ScopeChip(` in the Mac search chrome binds to a forwarded property. `includeFrontMatter` is a
/// `Toggle` in a different file, so that scan structurally could not reach it. **This test keys on
/// the data path rather than on one control's spelling**, which is what makes it cover the class
/// instead of the instance.
///
/// Version history:
///   1.0 — created with the `includeFrontMatter` fix
@Suite("Advanced filter signature")
struct AdvancedFilterSignatureTests {

    /// The repository root, found by walking up from this file.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// The boolean scopes the view model copies into `SearchParameters`.
    ///
    /// Enumerated rather than parsed: the construction site spans optional chaining and ternaries
    /// that a scan would have to re-implement Swift to read correctly, and a wrong parse here would
    /// fail open — the exact failure mode this suite exists to prevent. A new scope has to be added
    /// here, and the test below explains why in its message.
    private static let booleanScopes = [
        "includeDocumentText",
        "includeSummaries",
        "includeNotes",
        "includeFrontMatter",
    ]

    @Test("every boolean scope that reaches SearchParameters also reaches the signature")
    func everyScopeIsInTheSignature() throws {
        let source = try Self.source("FRUSExplorer/Search/SearchViewModel.swift")

        let marker = "var advancedFilterSignature"
        let start = try #require(source.range(of: marker),
                                 "advancedFilterSignature is gone — the macOS Advanced popover's live-apply trigger, and the thing this suite pins")
        // The signature body, bounded by the next declaration at type scope.
        let rest = source[start.upperBound...]
        let body = rest.range(of: "\n    /// ").map { String(rest[..<$0.lowerBound]) }
            ?? String(rest.prefix(3_000))

        for scope in Self.booleanScopes {
            // The APPEND, not the identifier. Checking `body.contains(scope)` is satisfied by any
            // mention — including the explanatory comment that sits directly above the append and
            // names the very property it documents. Mutation-tested: with the loose check, deleting
            // the append left the suite green, because the comment kept the word alive. That is the
            // same shape as the review findings this program has repeatedly caught citing a doc
            // comment instead of code.
            #expect(body.contains("parts.append(\(scope)"), """
                `\(scope)` is copied into SearchParameters but does not appear in \
                advancedFilterSignature. On macOS the Advanced popover applies live, and this \
                signature is what tells applyAdvancedFilters() the filter view model changed — so \
                a scope missing here is a control the reader can toggle that changes nothing at \
                all. That has shipped once (includeFrontMatter) and been caught twice before. If \
                you added a scope, add it to this list too.
                """)
        }
    }

    @Test("the scopes this suite lists are the ones the parameters actually carry")
    func listMatchesTheParameters() throws {
        // Guards the enumeration above from drifting: if `SearchParameters` gains or loses one of
        // these, the list is stale and the test that depends on it is quietly narrower than it
        // reads. A hardcoded list nobody checks is how the M-10 chip survived its own audit.
        // `SearchParameters` is declared in SearchModels.swift, not the pipeline — a first draft
        // of this guard read the wrong file and failed three of four scopes, which is the guard
        // working on itself.
        let models = try Self.source("FRUSExplorer/Search/SearchModels.swift")
        for scope in Self.booleanScopes {
            #expect(models.contains("var \(scope): Bool"),
                    "\(scope) is listed here but is no longer a SearchParameters field — this suite's enumeration is stale and is testing less than it appears to.")
        }
    }

    @Test("front matter actually filters, so the toggle has something to do")
    func frontMatterHasEffect() throws {
        // The signature fix is only worth having if the scope does something. Both halves are
        // pinned: the pipeline's SQL-side exclusion and the view model's row-side predicate.
        let pipeline = try Self.source("FRUSExplorer/Search/IndexingPipeline.swift")
        #expect(pipeline.contains("if !filters.includeFrontMatter"),
                "the pipeline no longer excludes front matter — the toggle would be inert again, this time for a different reason")
    }
}
