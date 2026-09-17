// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BrowserDocumentLoadState

/// Where one compilation section's document load has got to (#1301).
///
/// ## Why the absence of a result is not a state
/// Before #1301 `CompilationView` drew its spinner on
/// `vm.isLoadingDocuments || vm.compilationDocuments[cacheKey] == nil` — a disjunction whose
/// second operand is the **absence of a result**, not a loading fact. Nothing in the tree ever
/// cleared `compilationDocuments`, and "No documents in this section." was reachable only through
/// a *successful* load, so a section whose load never ran, or ran and threw, had no terminal state
/// at all: it showed a spinner for the life of the process, with no error row and no retry.
///
/// This enum is that missing terminal state. Every section key ends in ``loaded`` or ``failed(_:)``
/// once a load has been attempted, and ``notStarted`` is only reachable in the frames before the
/// keyed `.task` runs — see `CompilationDocumentsPresentation` for the coupling that makes the one
/// remaining silent decline observable.
///
/// Not `Equatable`, because `failed` carries the error the row displays. Tests compare through
/// ``isLoaded``/``failure`` or through the `CompilationDocumentsPresentation` the rule resolves to.
///
/// Version history:
///   1.0 — #1301: initial implementation
public enum BrowserDocumentLoadState {

    /// No load has been attempted for this section key yet.
    case notStarted

    /// A load is genuinely in flight.
    case loading

    /// A load completed. `BrowserViewModel.compilationDocuments` holds this key's rows, which may
    /// legitimately be an empty array — `frus1945Malta`'s *8. Minutes and related documents* holds
    /// seven subsections and no documents of its own.
    case loaded

    /// A load was attempted and could not produce rows.
    case failed(any Error)

    /// `true` only for ``loaded``. The one state `BrowserViewModel.loadDocuments` short-circuits on.
    public var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    /// The error from ``failed(_:)``, or `nil` in every other state.
    public var failure: (any Error)? {
        if case .failed(let error) = self { return error }
        return nil
    }
}

// MARK: - CompilationDocumentsPresentation

/// What `CompilationView.documentListSection` draws, as a value (#1301).
///
/// ## Why this is a free enum and a free `static func`, not a member of the view
/// The rule used to live inside a `@ViewBuilder` computed property, where nothing but a source
/// scan could reach it — and this repo has **measured** a source scan of that shape to be vacuous
/// (`VolumeStructure.swift:200` records a guard that asserted a literal over raw source and stayed
/// green while a mutant reinstated the bug in full). Extracted here it is an ordinary pure
/// function with ordinary unit tests. It is deliberately *not* a `static` on `CompilationView`:
/// statics on a `View` are `@MainActor`-isolated, and the fix for that is to move the rule out,
/// not to annotate the test.
///
/// ## The order of the branches is the contract
/// `indexRequired` is resolved **before** the load state is consulted, and that is load-bearing
/// rather than incidental. `CompilationView`'s `.task` still declines for an unindexed volume —
/// it must, because `document_cache` would answer an unindexed volume with an empty set that then
/// cached as `loaded` and was never reloaded after indexing — so the state stays ``notStarted``.
/// That decline is *observable* precisely because the same condition resolves here to
/// ``indexRequired``, which is a real screen with a real button. `IndexRequiredWinsOverNotStarted`
/// in `CompilationDocumentLoadingTests` is the pin.
///
/// ## `awaitingLoad` is a separate value from `loading`, and draws the same spinner
/// The view maps both to one spinner row, because an error row flashed before the first attempt
/// would be a lie and a blank gap would read as a rendering failure. They are nevertheless
/// distinct *values*, so the rule can be held to the claim that matters: `loading` is produced
/// **if and only if** a load is genuinely in flight, and no terminal state is ever drawn as one.
/// `LoadingIsProducedOnlyByAnInFlightLoad` in `CompilationDocumentLoadingTests` sweeps all four
/// load states for exactly that.
///
/// What makes `awaitingLoad` safe on screen — and what was missing before #1301 — is that it can
/// only be reached with the volume indexed and not indexing (the branches above), which is
/// precisely when `CompilationView`'s `.task` runs; and that task is now keyed on the section's
/// cache key, so a `.compilation → .compilation` step in the iPad detail pane re-runs it even
/// though the view instance is reused.
///
/// ## The Observation hazard this shape removes
/// Every input is an evaluated argument, so the body **always reads** the per-section load state.
/// The old disjunction short-circuited: while `isLoadingDocuments` was `true` the body never read
/// `compilationDocuments`, so Observation registered no dependency on the dictionary and it was
/// the flag's own write that invalidated the view. A per-section refactor that kept a
/// short-circuit would have left the data arriving and the spinner never clearing — the same bug
/// in new clothes.
///
/// Version history:
///   1.0 — #1301: initial implementation
public enum CompilationDocumentsPresentation: Equatable {

    /// A prose-only front-matter leaf — offer "Read [Title]" instead of a document list.
    case readDirectly

    /// The structured persons glossary (`FrontMatterPersonsView`).
    case personsList

    /// The structured archival sources list (`VolumeSourcesView`).
    case sourcesList

    /// A volume index run is in progress; show its live progress.
    case indexingProgress

    /// The volume is not indexed (or cannot be checked, because there is no pipeline).
    case indexRequired

    /// The keyed `.task` has not started a load for this section yet. Drawn as the spinner, but
    /// a distinct value from ``loading`` — see the type's doc comment.
    case awaitingLoad

    /// A load is genuinely in flight.
    case loading

    /// A load was attempted and failed. The error is read separately, from
    /// `BrowserDocumentLoadState.failure`, so this enum can stay `Equatable`.
    case failed

    /// A load completed; draw the rows (which may be an empty list).
    case documents

    /// Resolves what the document list should draw.
    ///
    /// - Parameters:
    ///   - canReadDirectly: `VolumeSection.canReadDirectly`.
    ///   - isPersonsList: `VolumeSection.isPersonsList`.
    ///   - isSourcesList: `VolumeSection.isSourcesList`.
    ///   - isIndexing: `BrowserViewModel.isIndexing`.
    ///   - isIndexed: `BrowserViewModel.isIndexed(_:)` for this volume.
    ///   - loadState: `BrowserViewModel.documentLoadState(forKey:)` for this section's cache key.
    /// - Returns: The branch to render.
    public static func resolve(
        canReadDirectly: Bool,
        isPersonsList: Bool,
        isSourcesList: Bool,
        isIndexing: Bool,
        isIndexed: Bool,
        loadState: BrowserDocumentLoadState
    ) -> CompilationDocumentsPresentation {
        if canReadDirectly { return .readDirectly }
        if isPersonsList { return .personsList }
        if isSourcesList { return .sourcesList }
        // Indexing takes priority over the index check: mid-run `isIndexed` flips partway and the
        // reader should watch the progress bar rather than the banner it is about to replace.
        if isIndexing { return .indexingProgress }
        // Before the load state, deliberately — see "The order of the branches is the contract".
        if !isIndexed { return .indexRequired }
        switch loadState {
        case .notStarted: return .awaitingLoad
        case .loading:    return .loading
        case .failed:     return .failed
        case .loaded:     return .documents
        }
    }
}
