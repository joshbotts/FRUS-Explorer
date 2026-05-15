// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SummarizationProvider

/// Interface any AI summarization backend must satisfy.
///
/// ## Adding a new provider
/// 1. Create a new `actor` that conforms to `SummarizationProvider`.
/// 2. Add a case to your provider-selection settings enum.
/// 3. Instantiate the actor and assign it to `AppState.summarizationService`
///    (or pass it directly to `SummarizationService.summarize`) in `FRUSExplorerApp`.
/// No call sites in the app need to change — all callers depend on this protocol.
///
/// ## Chunking
/// The chunking-and-synthesis pipeline lives in `SummarizationService`, one layer
/// above this protocol. All providers receive pre-chunked text and benefit from the
/// pipeline automatically. Use `request.isSynthesisPass` to distinguish a synthesis
/// call (which receives partial summaries as its chunks) from a normal content call.
///
/// Version history:
///   1.0 — Session 19: initial implementation
protocol SummarizationProvider: Actor {

    /// Performs a single summarization call against this provider's model.
    ///
    /// - Throws: `SummarizationError.providerUnavailable` if `isAvailable == false`.
    func summarize(
        request: SummarizationRequest,
        prompt: SummarizationPromptSnapshot
    ) async throws -> SummarizationResult

    /// Whether this provider can currently accept requests.
    ///
    /// `false` on devices that lack the required hardware or model assets.
    /// When `false`, `summarize` must throw `SummarizationError.providerUnavailable`.
    /// The UI should hide summarization entry points when `isAvailable == false`.
    var isAvailable: Bool { get }

    /// Conservative token budget available for document content in a single request.
    ///
    /// `SummarizationService` uses this value to decide whether to chunk a document.
    /// The limit should reserve capacity for the system prompt and response overhead —
    /// it represents usable document budget, not the raw model context window.
    var contextWindowTokenLimit: Int { get }
}
