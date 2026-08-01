// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - ProjectLeadSnippetTests

/// Snippets on Project Home lead rows (#553 Step 1).
///
/// ## What is actually at risk here
/// The rendering is three lines of SwiftUI. The part that can be wrong is **which fetch is cached
/// against what**, and the failure is silent: a project-keyed fetch leaves the previous lead set's
/// text on screen after a recompute, attached to rows that no longer exist. Every row still looks
/// plausible — it just describes the wrong document, which is the worst failure mode a research
/// tool has.
///
/// So these pin the cache key and the key format, which are the two things a runtime test of the
/// view could not reach anyway (`ProjectHomeView` needs an `AppState`, a live pipeline and a
/// SwiftData context).
///
/// Version history:
///   1.0 — #553 Step 1: initial implementation
@Suite("Project lead snippets")
struct ProjectLeadSnippetTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text
    }

    private static var homeView: String {
        get throws { try source("FRUSExplorer/ProjectContext/ProjectHomeView.swift") }
    }

    // MARK: - The key format the two sides have to agree on

    /// `documentSnippets` keys its result `"\(volumeId)/\(documentId)"`, and the view looks up
    /// `lead.documentKey`. If those ever diverge every lookup silently misses and no snippet
    /// renders — with no error anywhere, because a missing key is a legitimate state (an unindexed
    /// volume). This pins that they are the same string.
    @Test("A lead's document key matches the snippet dictionary's key format")
    func keyFormatsAgree() {
        let lead = ProjectLeadEntry(projectId: UUID(), volumeId: "frus1958-60v08",
                                    documentId: "d42", aggregateScore: 1.0,
                                    contributingSeedKeys: [])
        #expect(lead.documentKey == "frus1958-60v08/d42")

        let pipelineKey = try? Self.source("FRUSExplorer/Search/IndexingPipeline.swift")
        #expect(pipelineKey?.contains(#"result["\(volumeId)/\(documentId)"] = snippet"#) == true,
                """
                documentSnippets no longer keys on volumeId/documentId — every lookup in the view \
                will miss, silently, because a missing key is a legitimate state.
                """)
    }

    // MARK: - The cache key

    /// The correctness point of the whole change. A recompute replaces the lead set **without**
    /// changing `projectId`, so keying the fetch on the project would leave stale text under new
    /// rows.
    @Test("The snippet fetch is keyed on the lead set, not the project")
    func fetchIsKeyedOnLeads() throws {
        let text = try Self.homeView
        #expect(text.contains(".task(id: leadSnippetIdentity)"),
                """
                The snippet fetch must be keyed on the lead identity. Keyed on `projectId` it would \
                not re-run after a recompute, leaving the previous lead set's text attached to rows \
                that are gone.
                """)
        #expect(text.contains("projectLeads.map(\\.documentKey).sorted()"),
                "the identity must be the sorted lead keys — unsorted, a pure re-rank refetches")
    }

    /// The ranking pass must stay snippet-free: it runs per seed over candidates that are mostly
    /// never rendered, which is why the text is fetched at the view instead.
    @Test("The ranking pass still does not extract snippets")
    func rankingPassStaysCheap() throws {
        let service = try Self.source("FRUSExplorer/ProjectContext/ProjectLeadsService.swift")
        #expect(service.contains("includeSnippets: false"),
                """
                ProjectLeadsService turned on snippet extraction. That runs up to seedCap times per \
                recompute over candidates that are never shown; #553 fetches for the ~24 DISPLAYED \
                leads instead.
                """)
    }

    // MARK: - What the row does with a miss

    /// A lead whose volume is not indexed has no `document_cache` row, so its key is absent. That
    /// must render as the pre-#553 row, not as a blank gap or a placeholder.
    @Test("A missing snippet renders nothing extra")
    func missingSnippetDegradesQuietly() throws {
        let text = try Self.homeView
        #expect(text.contains("if let snippet = leadSnippets[lead.documentKey], !snippet.isEmpty"),
                """
                The row must render the snippet only when there is one. An unconditional `Text` \
                would add an empty line to every row for an unindexed volume.
                """)
    }

    /// And a read failure is not an error state — it is indistinguishable from "not indexed", which
    /// the row already handles.
    @Test("A read failure degrades to no snippets")
    func readFailureDegrades() throws {
        #expect(try Self.homeView.contains("(try? await pipeline.documentSnippets(forKeys: keys)) ?? [:]"))
    }
}
