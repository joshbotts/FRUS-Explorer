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

import Testing
import Foundation
@testable import FRUSExplorer

/// The five small findings that closed the 2026-08 navigation and state audit (#757).
///
/// Independent fixes, batched. What they share is that each is small enough to look harmless and
/// specific enough to be worth pinning:
///
/// - **L-41** the ranked-list sheets discarded the list on every open;
/// - **L-42** a dead-but-armed `.constant([])` navigation binding;
/// - **L-44** a graph sheet that could present completely blank;
/// - **L-46** a "session" flag that persisted for the life of the install;
/// - **L-47** an alert action reading a slot its own binding may already have cleared.
///
/// Version history:
///   1.0 — Session 2026-08-08: #757
@Suite("Navigation audit — low-severity batch")
struct NavigationAuditLowSeverityTests {

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
    }

    private static func source(_ relative: String) throws -> String {
        try String(contentsOf: appSourceRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func codeLines(_ source: String) -> [(line: Int, text: String)] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { (line: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.hasPrefix("//") && !$0.text.hasPrefix("///") && !$0.text.hasPrefix("*") }
    }

    // MARK: - The helper earns its trust

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        let sample = """
            // .constant([]) was the old binding
            /// .constant([]) again, in prose
            navigationPath: $vm.navigationPath
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1)
        #expect(kept.first?.text.contains("$vm.navigationPath") == true)
    }

    // MARK: - L-41: the ranked lists survive an open

    @Test("Both ranked-list sheets read in place instead of dismissing the list")
    func rankedListSheetsReadInPlace() throws {
        for relative in ["RelatedDocuments/RelatedDocumentsView.swift",
                         "SourceExplorer/ArchivalNeighborsSheet.swift"] {
            let lines = Self.codeLines(try Self.source(relative))
            #expect(lines.contains { $0.text.contains("onOpenInSheet") }, """
                \(relative) must offer an in-sheet open (#757 / L-41). Opening a row used to hand \
                the document to the Browse tab and dismiss, so stepping through a ranked work list \
                meant re-opening the sheet, re-running the query and re-scrolling every time.
                """)
            #expect(lines.contains { $0.text.contains("@State private var navigationPath") },
                    "\(relative) needs its own stack to push into")
        }
    }

    @Test("The in-sheet reader honours push vs replace")
    func inSheetReaderHonoursJumpKind() throws {
        // #751's distinction has to hold here too, or a page-turn stacks a level per page inside a
        // sheet that has no breadcrumb at all.
        for relative in ["RelatedDocuments/RelatedDocumentsView.swift",
                         "SourceExplorer/ArchivalNeighborsSheet.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("jump == .replace"),
                    "\(relative)'s in-sheet reader must honour DocumentJump.replace (#751)")
        }
    }

    @Test("Removing the dismiss alone would be #750's defect — the sheet still pushes, not strands")
    func openingDoesNotStrandBeneathTheSheet() throws {
        // The tempting one-line fix (delete `dismiss()`) reinstates H-5: the document lands
        // invisibly beneath the still-presented sheet. The in-sheet push is what avoids both.
        for relative in ["RelatedDocuments/RelatedDocumentsView.swift",
                         "SourceExplorer/ArchivalNeighborsSheet.swift"] {
            let source = try Self.source(relative)
            #expect(source.contains("navigationDestination(for: DocumentBrowserEntry.self)"), """
                \(relative) must push the document onto its OWN stack (#757 / L-41). Without a \
                destination the push renders nothing; without the push at all, dropping the dismiss \
                would land the document beneath the sheet (#750 / H-5).
                """)
        }
    }

    // MARK: - L-42: the armed constant binding

    @Test("SearchView's macOS branch passes a real navigation binding")
    func noConstantNavigationBinding() throws {
        let lines = Self.codeLines(try Self.source("Search/SearchView.swift"))
        let constants = lines.filter { $0.text.contains("navigationPath: .constant(") }
        #expect(constants.isEmpty, """
            SearchView still mounts MacDocumentView with a constant navigation binding \
            (#757 / L-42): \(constants.map(\.text).joined(separator: " | ")). Appends into a \
            constant are silently dropped, killing cross-reference taps and prev/next — the exact \
            defect Citation Lookup (#239) and Chronology (D1) were rebuilt to remove. Dead today, \
            but armed for any reuse of SearchView on macOS.
            """)
        #expect(lines.contains { $0.text.contains("navigationPath: $vm.navigationPath") },
                "…and must pass the view model's real path instead")
    }

    // MARK: - L-44: no blank graph sheet

    @Test("The graph sheet says 'preparing' rather than presenting empty")
    func graphSheetNeverPresentsBlank() throws {
        let source = try Self.source("DocumentView/DocumentView.swift")
        // Anchor on the sheet BUILDER, not the bare case label — `case .crossReferenceGraph:` also
        // appears in the sheet-identity switch far earlier in the file (the #752 lesson).
        let start = try #require(source.range(of:
            "case .crossReferenceGraph:\n                if let store = appState.crossReferenceStore {"))
        // Bounded by the NEXT case rather than a character count: the block is longer than a
        // guessed window, and a too-small window reads as "the placeholder is missing" while a
        // too-large one would spill into a neighbouring case and prove the wrong thing (#752's M8).
        let rest = source[start.lowerBound...]
        let end = rest.range(of: "case .summarizePromptPicker:")?.lowerBound ?? rest.endIndex
        let body = String(rest[..<end])
        #expect(body.contains("BootPlaceholderView"), """
            The `if let store` had no else, so a nil store presented a COMPLETELY BLANK sheet \
            (#757 / L-44) — reachable during boot and briefly after an in-session reindex, when the \
            read-only stores are recreated.
            """)
    }

    // MARK: - L-46: a session flag that is one

    @Test("The indexing-education flag is session-scoped, not persisted")
    func educationFlagIsSessionScoped() throws {
        let banner = Self.codeLines(try Self.source("App/IndexingQueueBannerView.swift"))
        #expect(!banner.contains { $0.text.contains("@AppStorage") && $0.text.contains("IndexingEducation") },
                """
                The education flag is persisted again (#757 / L-46). @AppStorage survives launches \
                and nothing ever reset the key, so the designed once-per-session introduction became \
                once per INSTALL — never shown again on a later tranche of downloads.
                """)
        #expect(banner.contains { $0.text.contains("hasShownIndexingEducationThisSession") },
                "it must read the AppState session flag instead")

        let appState = try Self.source("App/AppState.swift")
        #expect(appState.contains("var hasShownIndexingEducationThisSession = false"),
                "AppState — created once per launch — is the session (#757 / L-46)")
    }

    // MARK: - L-47: the alert cannot race its own binding

    @Test("The nudge captures its project id instead of reading a slot the binding clears")
    func nudgeCapturesItsProjectId() throws {
        let source = try Self.source("ProjectContext/ProjectPickerMenu.swift")
        #expect(source.contains("@State private var nudgeProjectId"), """
            The alert action read `appState.pendingSecondProjectNudge`, which its own isPresented \
            setter nils on dismissal. Whether SwiftUI writes isPresented = false before or after a \
            button action has varied across OS releases, so the action could find nil and silently \
            do nothing — with no second chance, since the signal is one-shot (#757 / L-47).
            """)
        #expect(source.contains("if let pending { nudgeProjectId = pending }"),
                "…captured in .onChange, not in a binding getter that mutates state")

        // And the action must actually prefer the captured value.
        let start = try #require(source.range(of: "project.nudge.secondProject.open"))
        let action = String(source[start.lowerBound...].prefix(1_400))
        #expect(action.contains("nudgeProjectId ??"),
                "the action must use the captured id first, falling back to the slot")
    }
}
