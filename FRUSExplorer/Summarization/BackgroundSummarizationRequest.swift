// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// A persisted background-summarization run that the iOS `BGProcessingTask` can
/// resume after the app is suspended.
///
/// The pre-computed scope (including resolved `documentKeys` for tag/saved-search
/// runs) plus the prompt id is all that's needed; volume URLs, the manifest, and
/// the active project are rebuilt from `AppState` at wake time.
///
/// Version history:
///   1.0 — Background summarization (BGProcessingTask integration)
public struct BackgroundSummarizationRequest: Codable, Sendable, Equatable {
    /// The documents to summarize.
    public let scope: SummarizationScope
    /// The summarization prompt to use.
    public let promptId: UUID

    /// Creates a request.
    public init(scope: SummarizationScope, promptId: UUID) {
        self.scope = scope
        self.promptId = promptId
    }
}

/// Persists the active background-summarization request and the user's preference
/// for continuing summarization in the background.
///
/// Stored in `UserDefaults` so it survives relaunch (a `BGProcessingTask` may not
/// fire until long after the app is suspended). The request is cleared once its
/// scope is fully summarized.
///
/// Version history:
///   1.0 — Background summarization (BGProcessingTask integration)
enum BackgroundSummarizationRequestStore {

    private static let requestKey = "frus.backgroundSummarization.request"
    private static let enabledKey = "frus.backgroundSummarization.continueInBackground"

    /// Whether the user wants summarization to continue in the background.
    /// Defaults to `false` (opt-in — it uses the on-device model and battery).
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Sets the background-continuation preference. Clears the pending request when
    /// turned off.
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled { clear() }
    }

    /// The persisted request, or `nil` if none is pending.
    static func load() -> BackgroundSummarizationRequest? {
        guard let data = UserDefaults.standard.data(forKey: requestKey),
              let request = try? JSONDecoder().decode(BackgroundSummarizationRequest.self, from: data)
        else { return nil }
        return request
    }

    /// Persists `request` (no-op when background continuation is disabled).
    static func save(_ request: BackgroundSummarizationRequest) {
        guard isEnabled, let data = try? JSONEncoder().encode(request) else { return }
        UserDefaults.standard.set(data, forKey: requestKey)
    }

    /// Removes any pending request (called when the scope is fully summarized,
    /// or the run is stopped).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: requestKey)
    }

    /// `true` when continuation is enabled and a request is pending.
    static var hasPending: Bool { isEnabled && load() != nil }
}
