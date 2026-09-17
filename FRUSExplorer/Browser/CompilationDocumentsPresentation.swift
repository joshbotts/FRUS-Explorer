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

// MARK: - BrowserDocumentLoadFailure

/// What the failure row says under its headline (#1301 round 2).
///
/// ## Why the row does not print `error.localizedDescription`
/// The shipped row did, and the only failure it can actually reach is a throwing
/// `documents(forVolume:)` — which throws `IndexingError.sqliteError` through `auxPrepare` and
/// nothing else. `IndexingError` is `public enum IndexingError: Error, Sendable` with no
/// `LocalizedError` conformance anywhere in the tree, so Foundation's bridging produced, verbatim:
///
///     The operation couldn’t be completed. (FRUSExplorer.IndexingError error 2.)
///
/// — which names a Swift module and an enum ordinal to a historian, drops the SQLite message the
/// case was carrying, and passes through no `String(localized:)`. That is the exact string #1299
/// removed from Search one commit before this branch (`SearchQueryRefusal`, whose tests assert the
/// absence of "couldn’t be completed" and of the type name), so the repo already treats it as a
/// defect rather than a house style.
///
/// ## Mapped here rather than as a conformance on `IndexingError`
/// The #1299 reasoning applies unchanged: `localizedDescription` is rendered at ~85 sites across
/// the app — including `indexRequiredSection`, eleven lines below this row's own call site — and a
/// conformance would silently rewrite every one of them for every case of the enum. This maps at
/// the one place that has a reader in front of it.
///
/// An error that already carries a reader-facing sentence keeps it: ``readable(_:)`` returns
/// `BrowserIndexingError.pipelineUnavailable`'s own message unchanged, which is a real recovery
/// instruction and better than anything this type could say about it.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
public enum BrowserDocumentLoadFailure: LocalizedError, Equatable, Sendable {

    /// The section's rows could not be read out of the search index.
    ///
    /// Deliberately says nothing about *why* beyond that, because the app cannot tell: the SQLite
    /// result code distinguishes a missing table from a corrupt page, and neither is something a
    /// reader can act on differently. What they can act on is the **Retry** button beside this
    /// sentence, and — if it keeps failing — indexing the volume again.
    case unreadableIndex

    /// The sentence, localized.
    public var message: String {
        switch self {
        case .unreadableIndex:
            return String(
                localized: "browser.compilation.loadFailed.detail",
                defaultValue: "FRUS Explorer could not read this section from its search index. Retry below; if it keeps failing, index this volume again."
            )
        }
    }

    /// `LocalizedError` conformance, so this reads correctly wherever an error is shown.
    public var errorDescription: String? { message }

    /// The sentence the failure row shows for a recorded failure.
    ///
    /// - Parameter error: `BrowserDocumentLoadState.failure`, which is `nil` only in states the
    ///   rule never resolves to `.failed`.
    /// - Returns: The error's own reader-facing description when it has one, else
    ///   ``unreadableIndex``'s sentence. Never a Foundation fallback naming a Swift type.
    public static func readable(_ error: (any Error)?) -> String {
        if let described = (error as? any LocalizedError)?.errorDescription, !described.isEmpty {
            return described
        }
        return BrowserDocumentLoadFailure.unreadableIndex.message
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
///   1.1 — #1301 round 2: ``rowKind`` hoists the presentation → row mapping out of the view's
///          `@ViewBuilder`, where a mutation could delete the error row with every test green;
///          ``shouldLoad(isIndexed:)`` is the caller's gate, with a signature that cannot express
///          the manifest lookup #1301 deleted
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

    /// Which row `CompilationView.documentListSection` draws for this presentation.
    ///
    /// ## Why the view's own switch is not the answer
    /// It was, and a mutation sweep walked straight through it: replacing `case .failed:
    /// loadFailedSection(…)` with the spinner left the error row and its **Retry** button
    /// declared, localized, referenced by `EditableContentKeyTests` — and never rendered. Every
    /// unit test and both iPad browse suites stayed green, because nothing outside a
    /// `@ViewBuilder` could see which row a presentation produces. Nine cases collapse to eight
    /// row kinds here, where `#expect` can reach them one at a time.
    ///
    /// The one collapse is ``awaitingLoad`` and ``loading`` sharing ``CompilationRowKind/spinner``
    /// — deliberate, and the reason they stay distinct *values*: an error row before the first
    /// attempt would be a lie and a blank gap reads as a rendering failure, but the rule can still
    /// be held to "`loading` only with a load in flight".
    public var rowKind: CompilationRowKind {
        switch self {
        case .readDirectly:     return .readDirectly
        case .personsList:      return .personsList
        case .sourcesList:      return .sourcesList
        case .indexingProgress: return .indexingProgress
        case .indexRequired:    return .indexRequired
        case .awaitingLoad:     return .spinner
        case .loading:          return .spinner
        case .failed:           return .errorRow
        case .documents:        return .documentRows
        }
    }

    /// Whether `CompilationView`'s keyed load task should run.
    ///
    /// ## The signature is the point
    /// This takes **one** `Bool` and it is the index question. Before #1301 the caller's gate was
    /// `guard volume != nil else { return }` — a lookup through `allSubseriesGroups`, i.e. the
    /// *manifest*, which the load never reads. A volume on disk and indexed but absent from the
    /// catalogue (a side-load) failed that guard and never loaded a single row, with no error and
    /// no change of spinner. Reinstating it here is not a regression that a test has to catch: it
    /// is a compile error, because there is nowhere to put a manifest.
    ///
    /// What the gate DOES check cannot be dropped either: `document_cache` answers an unindexed
    /// volume with an empty set, which records `.loaded` — the one state `loadDocuments`
    /// short-circuits on — so the rows would never be asked for again after the volume was
    /// indexed. The decline is not silent: `resolve` answers the same condition with
    /// ``indexRequired``, a real screen with a real button, before it consults the load state.
    ///
    /// - Parameter isIndexed: `BrowserViewModel.isIndexed(_:)` for the volume.
    /// - Returns: `true` when the load may run.
    public static func shouldLoad(isIndexed: Bool) -> Bool { isIndexed }
}

// MARK: - CompilationRowKind

/// The rows `CompilationView.documentListSection` can draw, as values (#1301 round 2).
///
/// One case per branch of that view's switch, with ``CompilationDocumentsPresentation/awaitingLoad``
/// and `.loading` sharing ``spinner`` — the view's only collapse, and the only one.
///
/// Version history:
///   1.0 — #1301 round 2: initial implementation
public enum CompilationRowKind: Hashable, Sendable {

    /// The "Read [Title]" button for a prose-only front-matter leaf.
    case readDirectly

    /// `FrontMatterPersonsView`.
    case personsList

    /// `VolumeSourcesView`.
    case sourcesList

    /// The live indexing progress bar.
    case indexingProgress

    /// The "Index Required" / "Search Index Unavailable" banner.
    case indexRequired

    /// "Loading documents…" — a load in flight, or one the keyed task is about to start.
    case spinner

    /// The terminal failure row: a localized headline, a readable sentence, and **Retry**.
    case errorRow

    /// The document list, which renders "No documents in this section." for an empty array.
    case documentRows
}
