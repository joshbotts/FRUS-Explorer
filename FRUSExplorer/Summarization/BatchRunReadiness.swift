// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ScopeType

/// What a batch summarization run is scoped to.
///
/// Lifted out of `BackgroundSummarizationSettingsView` in S-3c so `BatchRunReadiness` — which is
/// pure, and tested without a view — can name it.
///
/// Version history:
///   1.0 — Session 21: initial implementation, private to the run form
///   1.1 — #367: `customScope`
///   1.2 — S-3c: promoted to a top-level type
enum ScopeType: String, CaseIterable, Identifiable, Sendable {
    case volume, subseries, userTag, savedSearch, dateRange, customScope
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .volume:       return String(localized: "bg.summarizer.scope.type.volume",      defaultValue: "Volume")
        case .subseries:    return String(localized: "bg.summarizer.scope.type.subseries",   defaultValue: "Subseries")
        case .userTag:      return String(localized: "bg.summarizer.scope.type.userTag",     defaultValue: "User Tag")
        case .savedSearch:  return String(localized: "bg.summarizer.scope.type.savedSearch", defaultValue: "Saved Search")
        case .dateRange:    return String(localized: "bg.summarizer.scope.type.dateRange",   defaultValue: "Date Range")
        case .customScope:  return String(localized: "bg.summarizer.scope.type.customScope", defaultValue: "My Volume Scopes")
        }
    }
}

// MARK: - BatchRunBlocker

/// Why a batch summarization run cannot start (S-3c).
///
/// ## Why a reason and not a boolean
/// The run form used to gate Start on a `canStart: Bool` and dim the button when it was false. A
/// dimmed button with no explanation is the worst of both worlds: the reader can see that
/// something is wrong and cannot see *what*. The North Star's rule is that a start-disabled state
/// surfaces as a footer reason, so this enum carries the sentence the footer prints.
///
/// It also closes a real gap. The old boolean checked `selectedPromptId != nil`, while the start
/// path additionally required that the id still *resolve* to a prompt, that the service existed,
/// and that the download manager existed — and silently returned if any of those failed. Deleting
/// the selected prompt (which the same Settings screen lets you do) therefore left Start enabled
/// and inert. Every precondition the start path checks is now a case here.
///
/// Version history:
///   1.0 — S-3c: initial implementation, replacing `BackgroundSummarizationSettingsView.canStart`
enum BatchRunBlocker: Equatable, Sendable {

    /// Apple Intelligence is not usable on this device.
    case modelUnavailable
    /// The summarization service or the download manager has not been created yet.
    case notReady
    /// No prompts exist at all.
    case noPrompts
    /// A prompt is selected but no longer exists — it was deleted while the form was open.
    case promptMissing
    /// Nothing is downloaded, so no scope could enumerate anything.
    case nothingDownloaded
    /// The chosen scope has not been filled in yet.
    case scopeIncomplete(ScopeType)
    /// The chosen volume scope names no volume that is downloaded.
    case customScopeNotDownloaded

    /// The footer sentence: what is wrong, and what to do about it.
    var reason: String {
        switch self {
        case .modelUnavailable:
            return String(localized: "bg.summarizer.blocked.model",
                          defaultValue: "Apple Intelligence isn’t available on this device, so summaries can’t be generated here.")
        case .notReady:
            return String(localized: "bg.summarizer.blocked.notReady",
                          defaultValue: "Still starting up. Try again in a moment.")
        case .noPrompts:
            return String(localized: "bg.summarizer.blocked.noPrompts",
                          defaultValue: "There are no prompts yet. Create one first — a run needs a prompt to work from.")
        case .promptMissing:
            return String(localized: "bg.summarizer.blocked.promptMissing",
                          defaultValue: "The prompt this run was set to use has been deleted. Choose another.")
        case .nothingDownloaded:
            return String(localized: "bg.summarizer.blocked.nothingDownloaded",
                          defaultValue: "No volumes are downloaded yet. Summarization reads the volume text, so there is nothing to run against.")
        case .scopeIncomplete(let scope):
            switch scope {
            case .volume:
                return String(localized: "bg.summarizer.blocked.scope.volume",
                              defaultValue: "Choose a volume to summarize.")
            case .subseries:
                return String(localized: "bg.summarizer.blocked.scope.subseries",
                              defaultValue: "Choose a subseries to summarize.")
            case .userTag:
                return String(localized: "bg.summarizer.blocked.scope.userTag",
                              defaultValue: "Choose a tag. Only documents carrying it will be summarized.")
            case .savedSearch:
                return String(localized: "bg.summarizer.blocked.scope.savedSearch",
                              defaultValue: "Choose a saved search. Its current results will be summarized.")
            case .dateRange:
                return String(localized: "bg.summarizer.blocked.scope.dateRange",
                              defaultValue: "Enter both a start and an end year.")
            case .customScope:
                return String(localized: "bg.summarizer.blocked.scope.customScope",
                              defaultValue: "Choose a volume scope to summarize.")
            }
        case .customScopeNotDownloaded:
            return String(localized: "bg.summarizer.blocked.customScopeNotDownloaded",
                          defaultValue: "None of this scope’s volumes are downloaded. Summarization reads the volume text, so download at least one first.")
        }
    }
}

// MARK: - BatchRunReadiness

/// Decides whether a batch summarization run can start, and if not, why (S-3c).
///
/// Pure and value-typed so the decision is unit-testable without a model container, an
/// `AppState`, or an on-device language model — none of which a test can reasonably stand up.
///
/// Version history:
///   1.0 — S-3c: initial implementation
struct BatchRunReadiness: Equatable, Sendable {

    /// Whether Apple Intelligence is usable here.
    var modelAvailable: Bool
    /// Whether the background summarization service exists.
    var serviceAvailable: Bool
    /// Whether the download manager exists.
    var downloadManagerAvailable: Bool
    /// How many prompts exist.
    var promptCount: Int
    /// Whether the selected prompt id still resolves to a prompt.
    var selectedPromptExists: Bool
    /// How many volumes are downloaded.
    var downloadedVolumeCount: Int
    /// The chosen scope kind.
    var scopeType: ScopeType
    /// Whether the chosen scope's own inputs are filled in.
    var scopeSelectionComplete: Bool
    /// For `.customScope`: how many of its member volumes are downloaded.
    var customScopeDownloadedCount: Int

    /// The first thing standing in the way, or `nil` when the run can start.
    ///
    /// Ordered by how fundamental each obstacle is: a device that cannot summarize at all is
    /// reported before a half-filled scope picker, so the reader is not sent to fix a detail that
    /// would not have helped.
    var blocker: BatchRunBlocker? {
        if !modelAvailable { return .modelUnavailable }
        if !serviceAvailable || !downloadManagerAvailable { return .notReady }
        if promptCount == 0 { return .noPrompts }
        if !selectedPromptExists { return .promptMissing }
        if downloadedVolumeCount == 0 { return .nothingDownloaded }
        if scopeType == .customScope {
            if !scopeSelectionComplete { return .scopeIncomplete(.customScope) }
            if customScopeDownloadedCount == 0 { return .customScopeNotDownloaded }
            return nil
        }
        if !scopeSelectionComplete { return .scopeIncomplete(scopeType) }
        return nil
    }

    /// Whether Start should be enabled.
    var canStart: Bool { blocker == nil }
}
