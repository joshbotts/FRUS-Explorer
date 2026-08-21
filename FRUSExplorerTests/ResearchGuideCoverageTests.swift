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

// MARK: - ResearchGuideCoverageTests

/// The Research Guide explains the features that shipped (#597 PR 2).
///
/// ## Why this needs a test at all
/// The whole Query & Corpus Analysis wave — eight sessions, twenty-odd PRs — shipped with **zero**
/// mentions in the guide. Not a bad section: no section. Nothing failed, because nothing was
/// looking. That is the same silent-omission shape as the tip that lost its anchor, and it wants
/// the same answer: name the thing, and let the suite notice when it goes missing.
///
/// ## What this can and cannot check
/// It checks that a capability is *named* somewhere a reader will meet it. It cannot check that the
/// prose is any good, or still accurate — a section describing last year's behaviour passes. So
/// keep the list short and load-bearing: these are the features whose *absence* was the bug, not a
/// checklist of everything the app does.
///
/// Version history:
///   1.0 — #597 PR 2: initial implementation
@Suite("Research guide coverage")
struct ResearchGuideCoverageTests {

    /// Capabilities the guide must name, with the term a reader would recognise.
    ///
    /// Adding a user-facing analysis feature means adding a row — and writing the section that
    /// makes it pass.
    private static let mustCover = [
        "keyness or distinctiveness ranking": ["keyness", "distinctiveness", "distinctive"],
        "collocation": ["collocate", "collocation"],
        "the concordance": ["concordance"],
        "result-set facets": ["facet"],
        "working corpora": ["working corpus", "working corpora"],
        "the Query Inspector": ["query inspector"],
        "the method appendix": ["method appendix", "query log"],
        "excerpt verification": ["quotation", "verif"],
        // #835: the tool appeared NOWHERE in the guide until this row's section was written —
        // exactly the absence-is-the-bug case this suite exists for.
        "archival analytics": ["archival analytics"],
        // V-4: the semantic map shipped as an analytics window. Same shape as the row above — the
        // app's own Analysis Tools tooltip listed it while the guide did not.
        "semantic analytics": ["semantic analytics"],
        // #1026: the guide taught the VOLUME grain only. The document-grain Subjects section in the
        // results Facets panel narrows the result set and went unmentioned, while the sentence that
        // did cover subjects claimed a distinctiveness filter the app had stopped applying.
        //
        // TERMS CHOSEN TO FAIL AGAINST THE OLD TEXT, which is the whole discipline here: "subjects"
        // and "facet" were both already present, so a row using them would have passed on the day
        // it was added and pinned nothing. Both of these were absent from the guide, the mirror and
        // both manuals before the section was written.
        "the subjects facet on search results": ["subjects facet", "topic area"]
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, "\(path) is implausibly small — did it move?")
        return text.lowercased()
    }

    @Test("The in-app guide names every wave capability")
    func guideCoversTheWave() throws {
        let guide = try Self.source("FRUSExplorer/Onboarding/IndexingEducationView.swift")
        for (capability, terms) in Self.mustCover {
            #expect(terms.contains { guide.contains($0) },
                    """
                    The Research Guide never mentions \(capability). A user who cannot find a \
                    feature has nowhere to look it up — which is exactly the state the whole \
                    Q&CA wave shipped in.
                    """)
        }
    }

    /// `Docs/EditableContent.md` is the annotated mirror the owner edits prose in. A section that
    /// exists only in Swift cannot be revised there, so the mirror drifting is a real loss.
    @Test("The editable mirror carries the same sections")
    func mirrorMatchesTheGuide() throws {
        let mirror = try Self.source("Docs/EditableContent.md")
        for (capability, terms) in Self.mustCover {
            #expect(terms.contains { mirror.contains($0) },
                    "Docs/EditableContent.md does not mirror the guide's coverage of \(capability)")
        }
    }

    /// Both platform manuals, because they are hand-maintained in parallel and this repo's standing
    /// hazard is exactly that shape.
    @Test("Both platform manuals cover the two features they were missing")
    func manualsCoverTheLateAdditions() throws {
        for path in ["Docs/iOS-User-Manual.md", "Docs/macOS-User-Manual.md"] {
            let manual = try Self.source(path)
            #expect(manual.contains("method appendix"),
                    "\(path) never mentions the method appendix")
            #expect(manual.contains("count_basis") || manual.contains("at least 7,500"),
                    """
                    \(path) documents the query log without the floor-versus-total rule. That rule \
                    is the whole reason the export is trustworthy; omitting it invites a reader to \
                    sum a column of floors.
                    """)
            #expect(manual.contains("paraphrase does not pass"),
                    "\(path) never explains what the excerpt check does and does not forgive")
        }
    }

    /// Anti-vacuity: if the guide source ever stops being readable as prose, every `contains`
    /// above would fail rather than silently pass — but a capability list that had quietly emptied
    /// would pass everything. Pin that it is populated.
    @Test("The coverage list is not empty")
    func listIsPopulated() {
        #expect(Self.mustCover.count >= 8)
        #expect(Self.mustCover.values.allSatisfy { !$0.isEmpty })
    }
}
