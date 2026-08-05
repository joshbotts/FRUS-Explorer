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

/// Tests for `AppState` initialisation and persistence behaviour.
///
/// All tests run on the main actor because `AppState` is `@MainActor`-isolated.
/// Each test clears the `activeProjectId` UserDefaults key before and after to
/// avoid cross-test contamination from persisted state.
@MainActor
struct AppStateTests {

    // MARK: - Helpers

    private func clearPersistedProjectId() {
        UserDefaults.standard.removeObject(forKey: "activeProjectId")
    }

    // MARK: - Tests

    @Test("AppState initialises with nil activeProjectId when no value is persisted")
    func initialActiveProjectIdIsNilWhenNothingPersisted() {
        clearPersistedProjectId()
        let state = AppState()
        #expect(state.activeProjectId == nil)
        clearPersistedProjectId()
    }

    @Test("AppState initialises with non-nil activeProjectId when a valid UUID is persisted")
    func initialActiveProjectIdRestoredFromUserDefaults() {
        let testId = UUID()
        UserDefaults.standard.set(testId.uuidString, forKey: "activeProjectId")
        let state = AppState()
        #expect(state.activeProjectId == testId)
        clearPersistedProjectId()
    }

    @Test("AppState ignores malformed persisted activeProjectId and defaults to nil")
    func malformedPersistedValueDefaultsToNil() {
        UserDefaults.standard.set("not-a-uuid", forKey: "activeProjectId")
        let state = AppState()
        #expect(state.activeProjectId == nil)
        clearPersistedProjectId()
    }

    @Test("Setting activeProjectId persists the UUID string to UserDefaults")
    func settingActiveProjectIdPersistsToUserDefaults() {
        clearPersistedProjectId()
        let state = AppState()
        let testId = UUID()
        state.activeProjectId = testId
        let stored = UserDefaults.standard.string(forKey: "activeProjectId")
        #expect(stored == testId.uuidString)
        clearPersistedProjectId()
    }

    @Test("Setting activeProjectId to nil removes the persisted value")
    func settingActiveProjectIdToNilClearsPersistence() {
        let testId = UUID()
        UserDefaults.standard.set(testId.uuidString, forKey: "activeProjectId")
        let state = AppState()
        state.activeProjectId = nil
        let stored = UserDefaults.standard.string(forKey: "activeProjectId")
        #expect(stored == nil)
        clearPersistedProjectId()
    }

    @Test("AppState defaults isOnline to true")
    func isOnlineDefaultsToTrue() {
        clearPersistedProjectId()
        let state = AppState()
        #expect(state.isOnline == true)
    }

    @Test("AppState initialises with an empty downloadQueue")
    func downloadQueueInitiallyEmpty() {
        clearPersistedProjectId()
        let state = AppState()
        #expect(state.downloadQueue.isEmpty)
    }

    // MARK: - Per-window provenance routing (Planning/Completed/Window-Routing-Provenance.md)

    private func entry(_ d: String = "d", _ v: String = "v") -> DocumentBrowserEntry {
        DocumentBrowserEntry(documentId: d, volumeId: v, header: "H")
    }

    @Test("openDocument routes a tool to its bound provenance host, ignoring later key activity")
    func provenanceBeatsRecency() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        let hostB = DocumentHostID.window(DocumentWindowID(volumeId: "v1", documentId: "d1", header: "B"))
        state.registerHost(hostA)
        state.registerHost(hostB)
        state.bindTool(.search, to: hostA)
        // The FM-A scenario: the user glances at host B AFTER launching the tool from A —
        // recency moves, provenance must not.
        state.hostBecameKey(hostB)

        state.openDocument(entry("d2", "v2"), from: .tool(.search)) { _ in
            Issue.record("mintWindow must not run while the provenance host is live")
        }

        #expect(state.routedBrowse?.host == hostA)
        #expect(state.routedBrowse?.entry.documentId == "d2")
    }

    @Test("transitive binding: a tool spawned from a tool inherits the ancestor host")
    func transitiveProvenance() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.bindTool(.search, to: hostA)
        // Search spawns Analytics: the launcher binds the child to ITS provenance, not to itself.
        state.bindTool(.analytics, to: state.provenance(of: .search))

        state.openDocument(entry(), from: .tool(.analytics)) { _ in
            Issue.record("mintWindow must not run")
        }
        #expect(state.routedBrowse?.host == hostA)
    }

    @Test("singleton re-bind is last-spawner-wins")
    func singletonRebind() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        let hostB = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.registerHost(hostB)
        state.bindTool(.search, to: hostA)
        state.bindTool(.search, to: hostB)

        state.openDocument(entry(), from: .tool(.search)) { _ in Issue.record("no mint") }
        #expect(state.routedBrowse?.host == hostB)
    }

    @Test("an originless (nil) launch CLEARS the binding so it falls back to recency, not a stale live host")
    func nilBindClearsToFallback() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        let hostB = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.registerHost(hostB)
        state.bindTool(.search, to: hostA)
        // A stays LIVE (open but buried) and B is most-recently-key. An originless re-launch of
        // Search (Settings/Collections) must NOT keep routing to A — the FM-A resurfacing the PR-2
        // review caught. Clearing lets openDocument resolve to B via the D3 fallback.
        state.hostBecameKey(hostB)
        state.bindTool(.search, to: nil)
        #expect(state.provenance(of: .search) == nil)
        state.openDocument(entry("d2", "v2"), from: .tool(.search)) { _ in Issue.record("no mint: B is live") }
        #expect(state.routedBrowse?.host == hostB)
    }

    @Test("a transitive spawn whose parent is unbound clears the child (doesn't inherit a stale host)")
    func transitiveFromUnboundParentClears() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.bindTool(.wordCloud, to: hostA)        // an earlier rail launch bound word cloud → A
        // Later, a word cloud is launched from an UNBOUND Chronology (scene shortcut); its term →
        // Search spawn must not inherit A. provenance(of: .chronology) is nil → clears .wordCloud;
        // and the term→search transitive bind from the now-unbound word cloud clears .search too.
        state.bindTool(.wordCloud, to: state.provenance(of: .chronology))
        #expect(state.provenance(of: .wordCloud) == nil)
        state.bindTool(.search, to: state.provenance(of: .wordCloud))
        #expect(state.provenance(of: .search) == nil)
    }

    @Test("dead provenance falls back to the most-recently-key live host, never stranding")
    func deadProvenanceFallsBack() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        let hostB = DocumentHostID.window(DocumentWindowID(volumeId: "v1", documentId: "d1", header: "B"))
        state.registerHost(hostA)
        state.registerHost(hostB)
        state.bindTool(.search, to: hostA)
        state.unregisterHost(hostA)   // origin closed

        state.openDocument(entry(), from: .tool(.search)) { _ in Issue.record("no mint: B is live") }
        #expect(state.routedBrowse?.host == hostB)
    }

    @Test("no live hosts at all mints a standalone window instead of stranding the click")
    func emptyRegistryMints() {
        let state = AppState()
        var minted: DocumentBrowserEntry?
        state.openDocument(entry("d9", "v9"), from: .global) { minted = $0 }
        #expect(minted?.documentId == "d9")
        #expect(state.routedBrowse == nil)
    }

    @Test("fallback prefers the most recently key host (monotonic stamps, deterministic)")
    func fallbackOrdering() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        let hostB = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.registerHost(hostB)     // B registered later …
        state.hostBecameKey(hostA)    // … but A became key after
        #expect(state.fallbackHost() == hostA)
    }

    @Test("legacy pendingBrowseDocument translation is exactly-once across racing hosts")
    func legacyShimExactlyOnce() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.pendingBrowseDocument = Handoff(target: .macLegacyBrowse, payload: entry("d2", "v2"))

        state.routeLegacyPendingBrowse { _ in Issue.record("no mint: A is live") }
        let first = state.routedBrowse
        #expect(first?.host == hostA)
        #expect(state.pendingBrowseDocument == nil)
        // A second host's observer racing the same translation must be a no-op.
        state.routeLegacyPendingBrowse { _ in Issue.record("no mint on the no-op path") }
        #expect(state.routedBrowse == first)
    }

    @Test("closing a host with an in-flight route re-targets it at the surviving fallback")
    func inFlightRouteRetargetsOnHostClose() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        let hostB = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.registerHost(hostB)
        state.bindTool(.search, to: hostB)
        state.openDocument(entry("d2", "v2"), from: .tool(.search)) { _ in Issue.record("no mint") }
        #expect(state.routedBrowse?.host == hostB)

        // B closes before its consumer runs (FM-F): the route must move to A, not strand.
        state.unregisterHost(hostB)
        #expect(state.routedBrowse?.host == hostA)
        #expect(state.routedBrowse?.entry.documentId == "d2")
    }

    @Test("closing the LAST host demotes an in-flight route to pending for the next host's drain")
    func inFlightRouteDemotesWhenNoSurvivor() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.pendingBrowseDocument = Handoff(target: .macLegacyBrowse, payload: entry("d3", "v3"))
        state.routeLegacyPendingBrowse { _ in Issue.record("no mint: A is live") }
        #expect(state.routedBrowse?.host == hostA)

        state.unregisterHost(hostA)
        #expect(state.routedBrowse == nil)
        #expect(state.pendingBrowseDocument?.payload.documentId == "d3")

        // The next host to mount drains it (the onAppear discipline both hosts implement).
        let hostB = DocumentHostID.main(UUID())
        state.registerHost(hostB)
        state.routeLegacyPendingBrowse { _ in Issue.record("no mint: B is live") }
        #expect(state.routedBrowse?.host == hostB)
        #expect(state.routedBrowse?.entry.documentId == "d3")
    }

    @Test("unregister leaves the binding but liveness hides it")
    func livenessHidesStaleBinding() {
        let state = AppState()
        let hostA = DocumentHostID.main(UUID())
        state.registerHost(hostA)
        state.bindTool(.graph, to: hostA)
        state.unregisterHost(hostA)
        #expect(state.provenance(of: .graph) == nil)
        // Re-registration (e.g. the host window reopens under the same token) revives it.
        state.registerHost(hostA)
        #expect(state.provenance(of: .graph) == hostA)
    }
}

// MARK: - AppTabTests

#if os(iOS)
/// Tests for the `AppTab` enum introduced in Session 43.
///
/// All tests run on the main actor because `AppState` is `@MainActor`-isolated.
@MainActor
struct AppTabTests {

    private let key = "frus.activeTab"

    private func clearPersistedTab() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("AppTab rawValues match expected persistence strings")
    func appTabRawValues() {
        #expect(AppTab.browse.rawValue      == "browse")
        #expect(AppTab.search.rawValue      == "search")
        #expect(AppTab.research.rawValue    == "research")
        #expect(AppTab.collections.rawValue == "collections")
        #expect(AppTab.settings.rawValue    == "settings")
    }

    @Test("AppTab.CaseIterable contains all five cases")
    func appTabAllCasesCount() {
        #expect(AppTab.allCases.count == 5)
    }

    // #316: the shared `activeTab` was replaced by a per-window @SceneStorage selection; the
    // persisted last tab is now the `AppState.seedActiveTab` static + `persistTabSeed(_:)`.
    @Test("AppState.seedActiveTab defaults to .browse when nothing is persisted")
    func seedActiveTabDefaultsToBrowse() {
        clearPersistedTab()
        #expect(AppState.seedActiveTab == .browse)
        clearPersistedTab()
    }

    @Test("persistTabSeed persists the tab rawValue to UserDefaults")
    func persistTabSeedPersists() {
        clearPersistedTab()
        AppState.persistTabSeed(.search)
        #expect(UserDefaults.standard.string(forKey: key) == AppTab.search.rawValue)
        clearPersistedTab()
    }

    @Test("seedActiveTab restores the persisted tab on next launch")
    func seedActiveTabRestoredFromUserDefaults() {
        clearPersistedTab()
        UserDefaults.standard.set(AppTab.collections.rawValue, forKey: key)
        #expect(AppState.seedActiveTab == .collections)
        clearPersistedTab()
    }
}
#endif

// MARK: - NavigationStateTests

/// Tests for navigation-related properties added to AppState in Session 43.
@MainActor
struct NavigationStateTests {

    @Test("AppState.pendingBrowseDocument initialises to nil")
    func pendingBrowseDocumentInitiallyNil() {
        let state = AppState()
        #expect(state.pendingBrowseDocument == nil)
    }

    // showSearch (Session 2026-06-07) and showCitationLookup (Session 2026-07-04,
    // UI audit B4 — Citation Lookup is a macOS Window scene / iOS-local sheet
    // state) were both removed from AppState.

    @Test("AppState.pendingBrowseVolume initialises to nil")
    func pendingBrowseVolumeInitiallyNil() {
        let state = AppState()
        #expect(state.pendingBrowseVolume == nil)
    }

    @Test("AppState.pendingNARALookup initialises to nil")
    func pendingNARALookupInitiallyNil() {
        let state = AppState()
        #expect(state.pendingNARALookup == nil)
    }

    @Test("AppState.pendingVolumeGraph initialises to nil")
    func pendingVolumeGraphInitiallyNil() {
        let state = AppState()
        #expect(state.pendingVolumeGraph == nil)
    }

    // (#363) `pendingNoteComposer` was removed — the composer is now a value-based
    // `WindowGroup(for: NoteComposerRequest.self)`, so there is no init-nil field to
    // assert. `NoteComposerRequest` hand-off identity is covered below.
}

// MARK: - NoteComposerRequestTests

/// Tests `NoteComposerRequest` value identity, which drives macOS window reuse
/// (#363: the composer is a value-based `WindowGroup(for:)`).
///
/// SwiftUI reuses an existing window when the presented value compares equal, so the
/// request's identity must be the *semantic target* — two requests for the same
/// document (or same existing note, or same linked highlight) must compare **equal**
/// so a second "Add note" focuses the open composer instead of stacking a duplicate
/// editor over the same SwiftData store; distinct targets must compare distinct so
/// two different notes open side-by-side. There is deliberately no per-open nonce.
struct NoteComposerRequestTests {

    @Test("Two requests for the same document are equal (window reuse, not duplication)")
    func sameDocumentEqual() {
        let a = NoteComposerRequest(documentId: "d1", volumeId: "frus1969-76v01")
        let b = NoteComposerRequest(documentId: "d1", volumeId: "frus1969-76v01")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Requests for different documents are distinct windows")
    func differentDocumentsDistinct() {
        let a = NoteComposerRequest(documentId: "d1", volumeId: "v1")
        let b = NoteComposerRequest(documentId: "d2", volumeId: "v1")
        #expect(a != b)
    }

    @Test("Requests for different existing notes are distinct windows")
    func differentNotesDistinct() {
        let n1 = UUID(), n2 = UUID()
        let a = NoteComposerRequest(documentId: "d1", volumeId: "v1", noteId: n1)
        let b = NoteComposerRequest(documentId: "d1", volumeId: "v1", noteId: n2)
        #expect(a != b)
        #expect(a.noteId == n1)
        #expect(a.linkedHighlightId == nil)
    }

    @Test("Requests for different linked highlights are distinct windows")
    func differentLinkedHighlightsDistinct() {
        let h1 = UUID(), h2 = UUID()
        let a = NoteComposerRequest(documentId: "d1", volumeId: "v1", linkedHighlightId: h1)
        let b = NoteComposerRequest(documentId: "d1", volumeId: "v1", linkedHighlightId: h2)
        #expect(a != b)
    }

    @Test("Value round-trips through Codable (window-state restoration)")
    func codableRoundTrips() throws {
        let original = NoteComposerRequest(documentId: "d1", volumeId: "v1",
                                           noteId: UUID(), linkedHighlightId: UUID())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NoteComposerRequest.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - DocumentWindowIDTests

/// Tests `DocumentWindowID` value identity (Session 159).
///
/// `WindowGroup(for: DocumentWindowID.self)` reuses a window when the presented
/// value compares equal, so equality/hashing must key on `(volumeId, documentId)`
/// only — `header` is a display placeholder. Without this, the same document
/// opened with a different header (e.g. from a search result vs. a cross-reference
/// tap) would wrongly spawn a duplicate window instead of focusing the open one.
struct DocumentWindowIDTests {

    @Test("Same volume+document with different header are equal")
    func equalIgnoringHeader() {
        let a = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Memo")
        let b = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Different placeholder")
        #expect(a == b)
    }

    @Test("Same volume+document with different header hash equally and dedup in a Set")
    func hashIgnoringHeader() {
        let a = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Memo")
        let b = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Other")
        #expect(a.hashValue == b.hashValue)
        // Behaving as one Set element is exactly the property SwiftUI relies on to
        // reuse (rather than duplicate) a document window.
        #expect(Set([a, b]).count == 1)
    }

    @Test("Different documentId are not equal")
    func differentDocumentNotEqual() {
        let a = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Memo")
        let b = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d2", header: "Memo")
        #expect(a != b)
    }

    @Test("Different volumeId are not equal")
    func differentVolumeNotEqual() {
        let a = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Memo")
        let b = DocumentWindowID(volumeId: "frus1969-76v02", documentId: "d1", header: "Memo")
        #expect(a != b)
    }

    @Test("Codable round-trip preserves all fields, including the non-identifying header")
    func codableRoundTrip() throws {
        let original = DocumentWindowID(volumeId: "frus1969-76v01", documentId: "d1", header: "Memo")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DocumentWindowID.self, from: data)
        #expect(decoded == original)
        #expect(decoded.header == "Memo")
    }
}

// MARK: - CommandFocusedValueTests

/// Tests the equality contracts of the menu-bar command structs (Session
/// 2026-07-04, UI audit gaps 5/6).
///
/// The "Document"/"Collection" CommandMenus consume these via the Equatable
/// `focusedSceneValue(_:_:)` overload, which uses `==` to decide whether a
/// republish reaches the menu. Two properties are load-bearing:
///   1. closures are EXCLUDED from equality (they can't be compared), so two
///      instances with identical state must compare equal even with different
///      closures — otherwise every body evaluation would churn the menu;
///   2. every fact the menu renders or gates on (enablement booleans, toggle
///      state, document/collection identity) MUST participate, or the menu
///      would go stale when only that fact changed.
@MainActor
struct CommandFocusedValueTests {

    /// Builds a `DocumentCommandActions` with no-op closures and the given state.
    private func documentActions(
        documentKey: String = "frus1969-76v01/d1",
        canGoPrevious: Bool = true,
        canGoNext: Bool = true,
        canHighlight: Bool = false,
        isResearchPanelVisible: Bool = true,
        canFindInDocument: Bool = true
    ) -> DocumentCommandActions {
        DocumentCommandActions(
            documentKey: documentKey,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            canHighlight: canHighlight,
            isResearchPanelVisible: isResearchPanelVisible,
            goPrevious: {}, goNext: {}, addNote: {},
            highlightSelection: { _ in }, toggleResearchPanel: {},
            openInNewWindow: {},
            canFindInDocument: canFindInDocument,
            startFindInDocument: {}, findNext: {}, findPrevious: {}
        )
    }

    /// Builds a `CollectionDetailCommandActions` with no-op closures.
    private func detailActions(
        collectionId: UUID,
        isPreviewShown: Bool = false,
        canExport: Bool = true,
        hasEntries: Bool = true,
        hasDocuments: Bool = true
    ) -> CollectionDetailCommandActions {
        CollectionDetailCommandActions(
            collectionId: collectionId,
            isPreviewShown: isPreviewShown,
            canExport: canExport,
            hasEntries: hasEntries,
            hasDocuments: hasDocuments,
            addDocuments: {}, addHeading: {}, addProse: {},
            addHighlights: {}, addApparatus: { _ in }, sortByDate: {},
            togglePreview: {}, toggleSettings: {},
            exportCollection: {}
        )
    }

    @Test("DocumentCommandActions: identical state compares equal across distinct closures")
    func documentEqualityIgnoresClosures() {
        var sideEffect = 0
        let a = documentActions()
        let b = DocumentCommandActions(
            documentKey: "frus1969-76v01/d1",
            canGoPrevious: true, canGoNext: true,
            canHighlight: false, isResearchPanelVisible: true,
            goPrevious: { sideEffect += 1 }, goNext: { sideEffect += 1 },
            addNote: { sideEffect += 1 },
            highlightSelection: { _ in sideEffect += 1 },
            toggleResearchPanel: { sideEffect += 1 },
            openInNewWindow: { sideEffect += 1 },
            canFindInDocument: true,
            startFindInDocument: { sideEffect += 1 },
            findNext: { sideEffect += 1 }, findPrevious: { sideEffect += 1 }
        )
        #expect(a == b)
        #expect(sideEffect == 0)
    }

    @Test("DocumentCommandActions: each menu-rendered field breaks equality")
    func documentEqualityTracksEveryStateField() {
        let base = documentActions()
        #expect(documentActions(documentKey: "frus1969-76v01/d2") != base)
        #expect(documentActions(canGoPrevious: false) != base)
        #expect(documentActions(canGoNext: false) != base)
        #expect(documentActions(canHighlight: true) != base)
        #expect(documentActions(isResearchPanelVisible: false) != base)
        #expect(documentActions(canFindInDocument: false) != base)
    }

    @Test("CollectionDetailCommandActions: identical state compares equal across distinct closures")
    func detailEqualityIgnoresClosures() {
        let id = UUID()
        var sideEffect = 0
        let a = detailActions(collectionId: id)
        let b = CollectionDetailCommandActions(
            collectionId: id, isPreviewShown: false, canExport: true,
            hasEntries: true, hasDocuments: true,
            addDocuments: { sideEffect += 1 }, addHeading: { sideEffect += 1 },
            addProse: { sideEffect += 1 }, addHighlights: { sideEffect += 1 },
            addApparatus: { _ in sideEffect += 1 }, sortByDate: { sideEffect += 1 },
            togglePreview: { sideEffect += 1 }, toggleSettings: { sideEffect += 1 },
            exportCollection: { sideEffect += 1 }
        )
        #expect(a == b)
        #expect(sideEffect == 0)
    }

    @Test("CollectionDetailCommandActions: each menu-rendered field breaks equality")
    func detailEqualityTracksEveryStateField() {
        let id = UUID()
        let base = detailActions(collectionId: id)
        #expect(detailActions(collectionId: UUID()) != base)
        #expect(detailActions(collectionId: id, isPreviewShown: true) != base)
        #expect(detailActions(collectionId: id, canExport: false) != base)
        #expect(detailActions(collectionId: id, hasEntries: false) != base)
        #expect(detailActions(collectionId: id, hasDocuments: false) != base)
    }

    @Test("CollectionManagerCommandActions: stateless — any two instances are interchangeable")
    func managerActionsAreStateless() {
        let a = CollectionManagerCommandActions(newCollection: {})
        var fired = false
        let b = CollectionManagerCommandActions(newCollection: { fired = true })
        #expect(a == b)
        b.newCollection()
        #expect(fired)
    }
}
