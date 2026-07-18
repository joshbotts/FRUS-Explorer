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

    // MARK: - Per-window navigation routing (visual-review fix 2026-07-18)

    @Test("routeBrowseToActiveHost targets a standalone document window and clears the pending value")
    func routeBrowseToActiveWindowHost() {
        let state = AppState()
        let host = DocumentHostID.window(DocumentWindowID(volumeId: "v1", documentId: "d1", header: "A"))
        state.activeDocumentHost = host
        state.pendingBrowseDocument = DocumentBrowserEntry(documentId: "d2", volumeId: "v2", header: "B")

        state.routeBrowseToActiveHost()

        #expect(state.pendingBrowseDocument == nil)
        #expect(state.routedBrowse?.host == host)
        #expect(state.routedBrowse?.entry.documentId == "d2")
        #expect(state.routedBrowse?.entry.volumeId == "v2")
    }

    @Test("routeBrowseToActiveHost defaults to the main window")
    func routeBrowseToMainHost() {
        let state = AppState()
        state.pendingBrowseDocument = DocumentBrowserEntry(documentId: "d", volumeId: "v", header: "H")
        state.routeBrowseToActiveHost()
        #expect(state.routedBrowse?.host == .main)
        #expect(state.pendingBrowseDocument == nil)
    }

    @Test("routeBrowseToActiveHost is exactly-once: a second call with nothing pending is a no-op")
    func routeBrowseIsExactlyOnce() {
        let state = AppState()
        state.pendingBrowseDocument = DocumentBrowserEntry(documentId: "d", volumeId: "v", header: "H")
        state.routeBrowseToActiveHost()
        let firstRoute = state.routedBrowse
        // A second observer (another open host) running the same translation must not re-fire or
        // overwrite, because the first call already cleared `pendingBrowseDocument`.
        state.routeBrowseToActiveHost()
        #expect(state.routedBrowse == firstRoute)
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

    @Test("AppState.pendingNoteComposer initialises to nil")
    func pendingNoteComposerInitiallyNil() {
        let state = AppState()
        #expect(state.pendingNoteComposer == nil)
    }
}

// MARK: - NoteComposerRequestTests

/// Tests `NoteComposerRequest` hand-off identity (Session 2026-07-04, UI audit C1).
///
/// `NoteComposerWindowView` re-keys the editor with `.id(request.handoffId)`, so two
/// hand-offs for the same document must still compare distinct — otherwise a second
/// "Add note" on the same document would silently reuse the stale editor state.
struct NoteComposerRequestTests {

    @Test("Two requests for the same document are distinct hand-offs")
    func sameDocumentDistinctHandoffs() {
        let a = NoteComposerRequest(documentId: "d1", volumeId: "frus1969-76v01")
        let b = NoteComposerRequest(documentId: "d1", volumeId: "frus1969-76v01")
        #expect(a != b)
        #expect(a.handoffId != b.handoffId)
    }

    @Test("Explicit handoffId round-trips and equal values compare equal")
    func explicitHandoffIdEquality() {
        let id = UUID()
        let noteId = UUID()
        let a = NoteComposerRequest(documentId: "d1", volumeId: "v1",
                                    noteId: noteId, handoffId: id)
        let b = NoteComposerRequest(documentId: "d1", volumeId: "v1",
                                    noteId: noteId, handoffId: id)
        #expect(a == b)
        #expect(a.noteId == noteId)
        #expect(a.linkedHighlightId == nil)
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
        isResearchPanelVisible: Bool = true
    ) -> DocumentCommandActions {
        DocumentCommandActions(
            documentKey: documentKey,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            canHighlight: canHighlight,
            isResearchPanelVisible: isResearchPanelVisible,
            goPrevious: {}, goNext: {}, addNote: {},
            highlightSelection: { _ in }, toggleResearchPanel: {},
            openInNewWindow: {}
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
            openInNewWindow: { sideEffect += 1 }
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
