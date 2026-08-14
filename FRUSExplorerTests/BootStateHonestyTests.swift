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

/// "Not yet" and "nothing here" must not be the same sentence (#753).
///
/// ## The defect
/// The async boot runs *after* the first frame. Every surface reading a service it creates —
/// `searchService`, `crossReferenceStore`, `downloadManager` — had a nil branch, and all three
/// rendered a **definitive** statement rather than a wait:
///
/// - the Search tab: *"Search Unavailable — the search index is not available"*, over a fully built
///   index of 316,839 documents (M-23);
/// - a restored Cross-Reference Graph window: *"No Document Selected"*, while holding a perfectly
///   good restored request (M-22);
/// - `ContentView`: the **first-run Welcome screen**, to a researcher with hundreds of downloaded
///   volumes, because `hasDownloadedVolumes(in: nil)` is `false` (M-20).
///
/// The flash lengthens with store size, so it is worst for the users with the most to lose — and
/// each message reads as loss or breakage, not as a wait.
///
/// ## What these tests protect
/// The distinction, at each site, and the failure branch that must *survive* it: a store that
/// genuinely fails to open still has to say so. Deleting the honest error message would be a way to
/// make "never lie during boot" pass while making the app worse.
///
/// Source-reading, because this is about which branch a view takes when a service is nil — absence
/// of a lie has no runtime signature without a UI harness driving a half-booted app. **The two
/// M-20 tests are the exception as of 2.0**: `ContentView`'s decision has been extracted to the
/// pure `AppRootRouter`, so they now drive the real function instead of reading the file.
///
/// Version history:
///   1.0 — Session 2026-08-08: #753 (audit M-20, M-22, M-23)
///   2.0 — the M-20 pair converted from source-reading to driving `AppRootRouter`
@Suite("Boot-state honesty")
struct BootStateHonestyTests {

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

    /// Index of the first code line satisfying `predicate`, for adjacency/ordering assertions.
    ///
    /// Ordering is asserted on **code-line indices**, not character offsets: a character window is a
    /// proximity heuristic that happily reads a neighbouring branch — the mistake #752's mutation
    /// sweep caught in a guard of mine that was measuring a different sheet's correctness.
    private static func firstIndex(in lines: [(line: Int, text: String)],
                                   where predicate: (String) -> Bool) -> Int? {
        lines.firstIndex { predicate($0.text) }
    }

    // MARK: - The helper earns its trust

    @Test("codeLines keeps code and drops prose")
    func codeLinesFilters() {
        let sample = """
            // Search Unavailable was the old message
            /// Search Unavailable again, in prose
            BootPlaceholderView()
            """
        let kept = Self.codeLines(sample)
        #expect(kept.count == 1)
        #expect(kept.first?.text == "BootPlaceholderView()")
    }

    // MARK: - The shared vocabulary

    @Test("There is one boot placeholder, and it is not an error state")
    func placeholderExists() throws {
        let source = try Self.source("App/BootPlaceholderView.swift")
        #expect(source.contains("struct BootPlaceholderView"),
                "the three sites must share one 'still starting' surface, not three near-copies")
        #expect(source.contains("ProgressView()"),
                "a boot placeholder must look like waiting, not like a dead end")
        // ContentUnavailableView is the vocabulary of "there is nothing here" — the exact thing this
        // surface exists to stop being said during boot.
        #expect(!source.contains("ContentUnavailableView"),
                "the placeholder must not be built from the empty-state control it replaces")
    }

    @Test("The boot signal is derived, not a flag someone has to remember to set")
    func bootSignalIsDerived() throws {
        let source = try Self.source("App/AppState.swift")
        #expect(source.contains("var isBootComplete: Bool { downloadManager != nil }"), """
            isBootComplete must be COMPUTED from downloadManager, which bootDownloadManager assigns \
            last. A stored flag can be forgotten at one of its set sites and then lies in the \
            opposite direction — claiming ready when nothing is (#753).
            """)
    }

    // MARK: - M-20: an onboarded user never sees Welcome again mid-boot

    // These two were source-reading, for the reason the suite header gives: the decision lived
    // inside `ContentView.body`, where it had no runtime signature to assert against. It has since
    // been extracted to `AppRootRouter` (a pure function) so the Skip dead-end could be tested at
    // all, and that extraction hands these tests the signature they wanted. They now assert the
    // OUTCOME rather than the shape of the source — which is stronger: the old versions passed on
    // the presence of a line of text and would have gone on passing if the branches were reordered
    // into the wrong answer, and failed (as they did) on a refactor that changed nothing.

    @Test("An onboarded user gets the placeholder, not Onboarding, while booting")
    func onboardedUserNeverFlashesWelcome() {
        // The M-20 defect exactly: a researcher with hundreds of volumes looks identical to one
        // with none until boot finishes, because `hasDownloadedVolumes(in: nil)` is false. Neither
        // of these may resolve to the first-run screen.
        #expect(AppRootRouter.destination(
            hasCompletedOnboarding: true, isBootComplete: false, hasVolumes: false,
            hasActiveDownloads: false, hasFinishedOnboardingWithoutVolumes: false,
            isUITestMode: false) == .bootPlaceholder)
        #expect(AppRootRouter.destination(
            hasCompletedOnboarding: true, isBootComplete: false, hasVolumes: true,
            hasActiveDownloads: false, hasFinishedOnboardingWithoutVolumes: false,
            isUITestMode: false) == .bootPlaceholder)

        // And the new-user answer must not wait for boot: it needs nothing boot provides, so a
        // first-run reader must never sit on a spinner before the wizard appears.
        #expect(AppRootRouter.destination(
            hasCompletedOnboarding: false, isBootComplete: false, hasVolumes: false,
            hasActiveDownloads: false, hasFinishedOnboardingWithoutVolumes: false,
            isUITestMode: false) == .onboarding)
    }

    @Test("Re-onboarding still happens when the library is genuinely empty")
    func emptyLibraryStillReOnboards() {
        // The fix must not become "never show Onboarding again". A reader who removed every volume
        // is still re-onboarded — once that is TRUE rather than merely unknown, i.e. after boot.
        #expect(AppRootRouter.destination(
            hasCompletedOnboarding: true, isBootComplete: true, hasVolumes: false,
            hasActiveDownloads: false, hasFinishedOnboardingWithoutVolumes: false,
            isUITestMode: false) == .onboarding)
    }

    // MARK: - M-23: the Search tab

    @Test("The Search tab says 'preparing' while booting and keeps its failure message after")
    func searchTabDistinguishesBootFromFailure() throws {
        let source = try Self.source("App/MainTabView.swift")
        let lines = Self.codeLines(source)

        let bootBranch = try #require(
            Self.firstIndex(in: lines) { $0.contains("} else if !appState.isBootComplete {") },
            "the Search tab needs the boot guard macOS Search already had (#753 / M-23)")
        let placeholder = try #require(
            Self.firstIndex(in: lines) { $0.contains("BootPlaceholderView(") },
            "…rendering the shared placeholder")
        #expect(placeholder > bootBranch)

        // And the honest error must survive — deleting it would make this suite pass while making
        // a real store-open failure silent.
        let failure = try #require(
            Self.firstIndex(in: lines) { $0.contains("search.unavailable.title") },
            "the genuine 'Search Unavailable' failure state must remain for the post-boot case")
        #expect(failure > placeholder,
                "the failure branch belongs after the boot branch, not instead of it")
    }

    // MARK: - M-22: the restored graph window

    @Test("A restored graph window with a live request says 'preparing', not 'No Document Selected'")
    func graphWindowDistinguishesBootFromEmpty() throws {
        let source = try Self.source("App/FRUSExplorerApp.swift")
        let lines = Self.codeLines(source)

        let bootBranch = try #require(
            Self.firstIndex(in: lines) { $0.contains("} else if request != nil {") }, """
            The graph scene guarded `if let request, let store = ...` in ONE condition, so a \
            restored request waiting on a booting store rendered the same definitive empty state as \
            a genuinely empty window (#753 / M-22).
            """)
        let placeholder = try #require(
            Self.firstIndex(in: lines) { $0.contains("BootPlaceholderView(") && $0 > "" },
            "…and must render the placeholder there")
        #expect(placeholder > bootBranch)

        let empty = try #require(
            Self.firstIndex(in: lines) { $0.contains("graphWindow.empty.title") },
            "the genuine 'No Document Selected' state must remain for a window with no request")
        #expect(empty > bootBranch,
                "the empty state belongs after the boot branch")
    }

    // MARK: - The whole point, stated once

    @Test("All three sites speak the same boot vocabulary")
    func allThreeSitesUseThePlaceholder() throws {
        // Deliberately NOT "every site mentions isBootComplete" — that was my first draft and it
        // was wrong. `isBootComplete` is derived from `downloadManager`, which is the right signal
        // for ContentView and the Search tab; the graph scene is waiting on `crossReferenceStore`
        // specifically, and keying it to the download manager would be less accurate, not more
        // consistent. What the three genuinely share is the placeholder, which is what the issue
        // asked for: one vocabulary, not one variable.
        for relative in ["App/ContentView.swift", "App/MainTabView.swift", "App/FRUSExplorerApp.swift"] {
            let source = try Self.source(relative)
            let uses = Self.codeLines(source).filter { $0.text.contains("BootPlaceholderView") }
            #expect(!uses.isEmpty, """
                \(relative) renders a boot-sensitive surface but never shows BootPlaceholderView \
                (#753). "Not yet" and "nothing here" must not be the same sentence.
                """)
        }

        // And the two that DO key on the derived signal must still do so.
        for relative in ["App/ContentView.swift", "App/MainTabView.swift"] {
            let source = try Self.source(relative)
            #expect(Self.codeLines(source).contains { $0.text.contains("isBootComplete") },
                    "\(relative) must consult isBootComplete (#753 / M-20, M-23)")
        }
    }
}

// MARK: - TabBadgeTests

/// #657, first step: the Settings tab's unindexed-volumes badge is absent at zero, not empty.
///
/// A source assertion because there is nothing else to assert against — `Tab` builds no inspectable
/// value, and the badge's effect is a `UILabel` inside UIKit's tab-item layout. What is checkable is
/// that the zero branch is `nil`, and that is the whole of the change.
///
/// Version history:
///   1.0 — Session 2026-08-09: #657 first step
@Suite("Tab badges")
struct TabBadgeTests {

    private static func source(_ relative: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/\(relative)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("The zero case is no badge, not an empty one")
    func zeroMeansNoBadge() throws {
        let source = try Self.source("App/MainTabView.swift")
        let badge = try #require(
            source.split(separator: "\n").first(where: { $0.contains(".badge(") }),
            "MainTabView no longer carries a badge at all")

        #expect(badge.contains(": nil)"), """
            The zero case must pass `nil`. An empty string is still a badge — it materialises a \
            label in the tab item's layout, which is the stack #657's crash log names. \
            Found: \(badge.trimmingCharacters(in: .whitespaces))
            """)
        #expect(!badge.contains(": \"\")"), """
            The empty-string badge is back (#657). It reads as harmless and is not: `""` and `nil` \
            are different badges to UIKit, which is the entire point of the change.
            """)
        #expect(badge.contains("Text("), """
            The badge must be spelled `Text?`. `Tab` conforms to `TabContent`, not `View`, and \
            `TabContent.badge` has no optional-String overload — a `String?` here does not compile, \
            which is how this gets reverted to `""` by someone fixing a build error.
            """)
    }
}
