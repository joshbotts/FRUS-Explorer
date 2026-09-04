// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AxisWeights @AppStorage support

/// Persists the weight vector as a compact `axis:weight,…` string so it can back an `@AppStorage`
/// default — the user's preferred tuning, remembered across find-related invocations.
///
/// ## The encoding stores DEPARTURES from the default, not the vector (#1021)
/// An axis whose weight equals its current `defaultWeight` is omitted; `init?(rawValue:)` fills
/// every absent axis back in from `defaultWeight`. That is one change on paper and the whole point
/// of the conformance in practice.
///
/// The old encoding wrote every axis unconditionally. So the moment a reader released any slider,
/// their stored string pinned `sharedSubjects:0.0` — and when #308 Phase 3 raised that axis's
/// default to 0.5, the new default reached nobody who had ever touched the tuning. Worse than a
/// stale number: `RelatedDocumentsEngine` skips a zero-weighted axis outright at three sites, so
/// the stale string did not merely mis-weight the feature, it *disabled* it. The `??
/// axis.defaultWeight` fallback in `ProjectLeadsService.effectiveWeights` exists for exactly this
/// and could never fire, because the serializer guaranteed the key was present.
///
/// The consequence to hold on to: **a tuning now tracks defaults for every axis the reader has not
/// moved.** That is the fix working. Its accepted cost is that a reader who deliberately set an
/// axis to exactly today's default is indistinguishable from one who never touched it, and will
/// follow a future change to that default. There is no encoding that both tracks defaults and
/// preserves a deliberate value identical to one.
///
/// ## Why the backfill is in `init`, not in the subscript
/// Three surfaces read this preference straight out of `@AppStorage`
/// (`RelatedDocumentsContent`, `DocumentView`, `ResearchRailView`) and the macOS window payload
/// decodes it, all feeding `AxisWeights` to the engine through `subscript`, which reads a missing
/// axis as **0**. Only `ProjectLeadsService` overlays defaults. Sparse output with the old
/// subscript would therefore have zeroed every unmentioned axis on those four paths — turning a
/// compaction into a far worse version of the bug it fixes. Backfilling at the persistence
/// boundary fixes all four at once and leaves `AxisWeights(weights:)`'s sparse-dictionary
/// semantics — and everything built on them — untouched.
///
/// ## Two things about the conformance itself
///
/// 1. **The encoding is manual, not `JSONEncoder().encode(self)`, on purpose.** Adding
///    `RawRepresentable` (with `RawValue: Codable`) to a type that already synthesises `Codable`
///    makes the standard library **re-route `Equatable`, `Hashable`, and `Codable` through
///    `rawValue`** (verified empirically — `AxisWeights([.a:0.9]) == AxisWeights([.a:0.9, …:0])` is
///    now `true`, and `JSONEncoder` emits the string, not an object). A `rawValue` that called
///    `JSONEncoder().encode(self)` would therefore recurse into itself and stack-overflow at runtime.
///    Encoding each `axis.rawValue:weight` pair directly breaks that cycle.
///
/// 2. **The re-routing is intentional and safe here.** The encoding is faithful, full-precision,
///    deterministic and locale-independent — Swift's `"\(Double)"` always uses `.` and never emits
///    `:`/`,`, and axis raw values are camelCase, so no separator collision. Two vectors with the
///    same *effective* weights compare equal, which is a normalisation and arguably more correct
///    than a raw-dictionary compare. Note the sparse encoding keeps that property exactly: both
///    sides omit the same axes for the same reason.
///
/// ## The empty string is the default tuning, and that is load-bearing
/// Under this encoding `AxisWeights.default.rawValue` is `""`. `RelatedDocumentsRequest` is
/// `Codable` **through** `rawValue`, and `RawRepresentable`'s synthesised `Codable` throws
/// `.dataCorrupted` when `init?` returns nil — so a `nil` for `""` would mean a restored macOS
/// Related window saved at default weights **fails to decode and never reappears**. `""` therefore
/// decodes as `.default`. A non-empty string that yields no pairs is still malformed and still
/// returns nil, so the documented "a bad stored value falls back at the read site" contract holds
/// for genuine garbage.
extension AxisWeights: RawRepresentable {

    /// The default vectors earlier versions wrote for an **untouched** tuning.
    ///
    /// A stored string equal to one of these is treated as unconfigured, so its axes are refilled
    /// from today's defaults. Without this, #1021's fix would reach only readers who had never
    /// opened "Adjust weights" — the old serializer spelled the whole vector out, so the readers
    /// who most need the repair are precisely the ones a forward-only fix cannot see.
    ///
    /// **There are two rows, not one, and the second is easy to miss.** The semantic axis shipped
    /// in #868, so a tuning last written before it exists with only six axes; #308 Phase 3 then
    /// raised `sharedSubjects` from 0 to 0.5. An amnesty written against the seven-axis vector
    /// alone would strand everyone whose last slider release predates the semantic axis.
    ///
    /// This is safe rather than merely convenient: through both of those eras the shared-subject
    /// axis had **no bundled index behind it** (#308 Phase 3 gated on #261), so a reader could move
    /// its slider but not observe an effect. A vector identical to the era's defaults is therefore
    /// not evidence of a preference about it. A reader who set it to anything else — 0.3, say — has
    /// a vector that matches no row here and is preserved untouched.
    private static let legacyDefaultVectors: [[SimilarityAxis: Double]] = [
        // Before the semantic axis (#868): six axes.
        [.archivalProvenance: 1.0, .crossReference: 1.0, .dateProximity: 0.5,
         .subseries: 0.3, .sharedPersons: 0.7, .sharedSubjects: 0.0],
        // #868 through #308 Phase 3: seven axes, both new ones off.
        [.archivalProvenance: 1.0, .crossReference: 1.0, .dateProximity: 0.5,
         .subseries: 0.3, .sharedPersons: 0.7, .sharedSubjects: 0.0, .semanticSimilarity: 0.0],
    ]

    init?(rawValue: String) {
        var parsed: [SimilarityAxis: Double] = [:]
        for pair in rawValue.split(separator: ",") {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let axis = SimilarityAxis(rawValue: String(parts[0])),
                  let weight = Double(parts[1]) else { continue }
            parsed[axis] = weight
        }
        // `""` is the default tuning under this encoding; anything else that parses to nothing is
        // malformed and falls back at the read site.
        guard !parsed.isEmpty || rawValue.isEmpty else { return nil }

        // Amnesty before backfill: it compares against the vector AS STORED.
        if Self.legacyDefaultVectors.contains(parsed) { parsed = [:] }

        var complete: [SimilarityAxis: Double] = [:]
        for axis in SimilarityAxis.allCases {
            complete[axis] = parsed[axis] ?? axis.defaultWeight
        }
        self.init(weights: complete)
    }

    var rawValue: String {
        // Sorted by axis rawValue for a stable, deterministic string; axes at their default are
        // omitted so the reader inherits future changes to them (#1021).
        SimilarityAxis.allCases
            .sorted { $0.rawValue < $1.rawValue }
            .filter { self[$0] != $0.defaultWeight }
            .map { "\($0.rawValue):\(self[$0])" }
            .joined(separator: ",")
    }
}

// MARK: - RelatedDocumentsContent

/// The shared **core** of every find-related presentation: the tuning bar (scope + per-axis weight
/// sliders), the pipeline-readiness / loading / honest-empty states, the ranked list with its
/// overflow hint, and row-tap navigation. Chrome stays with the callers — `RelatedDocumentsSheet`
/// wraps it in a `NavigationStack` with a Done button (iOS), and `RelatedDocumentsWindowView` shows
/// it under window title chrome (macOS + iPad Stage Manager). Mirrors `ArchivalNeighborsContent`
/// (design §6.3): the pipeline-ready placeholder + `.task(id:)` duplicate-fire guard are copied
/// verbatim because the same restore-races-boot race applies.
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
struct RelatedDocumentsContent: View {

    /// Shared app state — resolves the scope, runs the ranking, and receives the row-tap hand-off.
    let appState: AppState
    /// The restorable query this view opened at (anchor + initial weights + scope + limit).
    let request: RelatedDocumentsRequest
    /// Invoked after a row tap posts its navigation hand-off. The sheet passes `dismiss`; the window
    /// passes `nil` so the list stays open beside the reading window (the value of a work list).
    var onNavigate: (() -> Void)? = nil

    /// When set, a row opens the document INSIDE the presenting sheet instead of handing it to the
    /// Browse tab and dismissing (#757 / audit L-41). The window presentation leaves this nil and
    /// keeps its existing routing.
    var onOpenInSheet: ((DocumentBrowserEntry) -> Void)? = nil

    /// The user's persisted default tuning, updated whenever a slider settles so the *next* fresh
    /// open inherits it. The live per-view tuning is `@State` (seeded from `request.weights`), so a
    /// restored macOS window keeps its own tuning independent of this global default.
    @AppStorage(SettingsKeys.relatedAxisWeights) private var persistedWeights = AxisWeights.default

    #if os(macOS)
    /// Mint tail for `AppState.openDocument` — when no document host is live, a row tap
    /// lands in a fresh standalone document window instead of being dropped.
    @Environment(\.openWindow) private var openWindow
    #endif

    /// #338 step 4: the scene this list renders in (iOS sheet), so a row tap's open-document hand-off
    /// addresses the presenting window. Injected at the sheet site; nil on macOS (uses `openDocument`).
    @Environment(\.sceneID) private var sceneID

    @State private var weights: AxisWeights
    @State private var scope: NeighborScope
    @State private var rows: [RelatedDocumentRow] = []
    @State private var totalBeforeLimit = 0

    /// When a generator's candidate pool was cut, how many candidates it had (#645).
    @State private var poolCutFrom: Int?
    @State private var isLoading = true
    /// Bumped when a weight slider settles, to re-fire the load without putting the continuously
    /// changing weight values directly in the `.task` id (which would re-rank on every drag tick).
    @State private var weightReloadToken = 0
    /// Guards the load task against the documented Group-modifier duplicate fire (a branch swap
    /// re-fires `.task(id:)`); `nil` until the first load completes.
    @State private var lastLoadedKey: String?

    /// Designated initializer — seeds the live tuning + scope from the request.
    init(appState: AppState, request: RelatedDocumentsRequest,
         onNavigate: (() -> Void)? = nil,
         onOpenInSheet: ((DocumentBrowserEntry) -> Void)? = nil) {
        self.appState = appState
        self.request = request
        self.onNavigate = onNavigate
        self.onOpenInSheet = onOpenInSheet
        _weights = State(initialValue: request.weights)
        _scope = State(initialValue: request.scope)
    }

    /// Whether the live index exists to query — `false` during app boot. Reading the `@Observable`
    /// property re-evaluates the view (and re-fires the load) when the pipeline becomes available, so
    /// a restored window never renders the honest-empty verdict as a lie.
    private var pipelineReady: Bool { appState.indexingPipeline != nil }

    var body: some View {
        VStack(spacing: 0) {
            tuningBar
            Divider()
            Group {
                if !pipelineReady {
                    ProgressView(String(localized: "related.preparingIndex",
                                        defaultValue: "Preparing your index…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rows.isEmpty {
                    ContentUnavailableView(
                        String(localized: "related.empty", defaultValue: "No Related Documents"),
                        systemImage: "doc.on.doc",
                        description: Text(emptyDetail))
                } else {
                    List {
                        ForEach(rows) { row in
                            Button { open(row) } label: { rowLabel(row) }
                                .buttonStyle(.plain)
                                // The semantic axis shipped without the quality gate its design
                                // specified, on the understanding that testers would judge it
                                // instead. This is where they do that. Only rows the semantic axis
                                // actually scored carry the menu — a verdict on a row it did not
                                // produce would be evidence about a different axis.
                                .contextMenu {
                                    if row.axisScores[.semanticSimilarity] != nil {
                                        semanticFeedbackButtons(for: row)
                                    }
                                }
                        }
                        if totalBeforeLimit > rows.count {
                            Text(String(
                                format: String(localized: "related.overflow %lld",
                                               defaultValue: "%lld more related — raise a weight or narrow the scope to refine."),
                                Int64(totalBeforeLimit - rows.count)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        // #645: the line above counts what scored inside the fetched pool, and the
                        // pool itself may have been cut. Saying so is the house rule — a truncated
                        // total is never presented as a complete one — and it matters here because
                        // ranking can only surface a document the pool contained: an anchor with
                        // 1,063 neighbours and a 120-row pool has 943 the scorers never saw.
                        if let poolCutFrom, poolCutFrom > totalBeforeLimit {
                            Text(String(
                                format: String(localized: "related.poolCut %lld %lld",
                                               defaultValue: "Ranked from the first %1$lld of %2$lld documents that share this anchor’s archival container. The rest were not scored. Narrow the scope to reach them."),
                                Int64(totalBeforeLimit), Int64(poolCutFrom)))
                                .font(.caption2).foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .task(id: reloadKey) {
            let claimedKey = reloadKey
            guard pipelineReady, lastLoadedKey != claimedKey else { return }
            lastLoadedKey = claimedKey
            isLoading = true
            let result = await RelatedDocumentsEngine.rank(
                anchor: request.anchor,
                anchorYear: request.anchorYear,
                weights: weights,
                scopeVolumeIds: scope.resolveVolumeIds(appState: appState),
                limit: request.limit,
                appState: appState)
            // A scope switch / slider release / window hide cancels this task; a cancelled
            // load must not resume here and overwrite a newer task's results. Release the
            // claim (unless a newer task already re-claimed the guard) so a re-fire for the
            // SAME key — e.g. the window re-appearing — reloads instead of showing the
            // spinner this task never got to clear; and clear the spinner this task set
            // (when the claim is still ours, no newer task owns `isLoading` — leaving it
            // true could strand the spinner if a same-key re-fire raced this resume).
            guard !Task.isCancelled else {
                if lastLoadedKey == claimedKey {
                    lastLoadedKey = nil
                    isLoading = false
                }
                return
            }
            rows = result.rows
            totalBeforeLimit = result.totalBeforeLimit
            poolCutFrom = result.poolCutFrom
            isLoading = false

            // The semantic axis's "why related" evidence, computed AFTER ranking and only for the
            // rows actually on screen — the design's §6.1 shape. Doing it in the generator would
            // tokenise candidates the ranker then discarded, and would still miss rows another axis
            // promoted into view. The rows are already displayed with a percentage while this runs,
            // so a slow pass degrades to the interim chip rather than delaying the list.
            attachSubjectEvidence()
            await attachSemanticEvidence(claimedKey: claimedKey)
        }
    }

    /// The tester-feedback controls for one semantic row.
    ///
    /// A context menu rather than an inline control because the row is already a `Button`, and a
    /// button inside a button is a hit-testing argument nobody wins.
    ///
    /// - Parameter row: The ranked row being judged.
    @ViewBuilder
    private func semanticFeedbackButtons(for row: RelatedDocumentRow) -> some View {
        Button {
            recordSemanticFeedback(row: row, verdict: .helpful)
        } label: {
            Label(String(localized: "related.semantic.helpful",
                         defaultValue: "Semantic match: helpful"),
                  systemImage: "hand.thumbsup")
        }
        Button {
            recordSemanticFeedback(row: row, verdict: .notHelpful)
        } label: {
            Label(String(localized: "related.semantic.notHelpful",
                         defaultValue: "Semantic match: not useful"),
                  systemImage: "hand.thumbsdown")
        }
    }

    /// Records a tester's verdict on a semantic row.
    ///
    /// Captures the anchor's era, because that is the question the retired blind panel existed to
    /// answer and a verdict without it cannot answer it. The era comes from the app's own
    /// `CoverageEra` banding rather than a second one, so this feedback is comparable with every
    /// other era-split surface in the app.
    ///
    /// - Parameters:
    ///   - row: The row being judged.
    ///   - verdict: The tester's verdict.
    private func recordSemanticFeedback(
        row: RelatedDocumentRow, verdict: SemanticFeedbackEntry.Verdict
    ) {
        let entry = SemanticFeedbackEntry(
            recordedAt: Date(),
            anchor: request.anchor.compositeString,
            neighbour: row.key.compositeString,
            verdict: verdict,
            cosine: row.axisScores[.semanticSimilarity],
            era: request.anchorYear.map { CoverageEra.bucket(year: $0).rawValue.description },
            sameVolume: row.key.volumeId == request.anchor.volumeId,
            provenanceDigest: BundledSemanticVectors.provenance?.digestHex)
        Task { await SemanticFeedbackLog.shared.record(entry) }
    }

    /// Fills in the shared-distinctive-terms chip for the displayed semantic rows.
    ///
    /// Guarded on `claimedKey` the same way the load is: a scope switch or a weight change starts a
    /// new load, and a late-arriving evidence pass must not write terms computed for the previous
    /// anchor onto the current rows. Terms are joined with a unit separator because
    /// `axisEvidenceLabel` is the `[SimilarityAxis: String]` the engine already carries — adding a
    /// parallel `[SimilarityAxis: [String]]` for one axis would be a second thing to keep in step.
    ///
    /// Names the detected topics each row shares with the anchor, for the `sharedSubjects` chip
    /// (#1020).
    ///
    /// Synchronous, unlike its semantic sibling below: the subject index is an in-memory dictionary,
    /// so there is nothing to await and no cancellation window to guard. It therefore needs no
    /// `claimedKey` — it cannot outlive the reload that scheduled it.
    ///
    /// Runs over the ROWS, not the candidate pool, for the same reason the semantic pass does: this
    /// is display evidence, and a row nobody sees needs none.
    private func attachSubjectEvidence() {
        guard let store = DocumentSubjectStore.shared else { return }
        let scored = rows.indices.filter { rows[$0].axisScores[.sharedSubjects] != nil }
        guard !scored.isEmpty else { return }
        let names = store.sharedSubjectNames(anchor: request.anchor,
                                             candidates: scored.map { rows[$0].key })
        guard !names.isEmpty else { return }
        for index in scored {
            guard let found = names[rows[index].key], !found.isEmpty else { continue }
            rows[index].axisEvidenceLabel[.sharedSubjects] = found.joined(separator: "\u{1F}")
        }
    }

    /// - Parameter claimedKey: The reload identity this pass belongs to.
    ///
    /// Covers BOTH vocabulary-evidenced axes since W-17 session 2: the lexical axis's chip
    /// wants exactly the same thing — the distinctive terms the pair actually shares, in
    /// the anchor's own spelling — so one `SemanticSharedTerms` call over the union of
    /// scored rows serves both, and the label is written under each axis that scored the
    /// row. A second terms machine would be a second vocabulary to drift.
    private func attachSemanticEvidence(claimedKey: String) async {
        let vocabularyAxes: [SimilarityAxis] = [.semanticSimilarity, .lexicalSimilarity]
        let scoredRows = rows.filter { row in
            vocabularyAxes.contains { row.axisScores[$0] != nil }
        }
        guard !scoredRows.isEmpty else { return }
        let terms = await SemanticSharedTerms.sharedTerms(
            anchor: request.anchor, candidates: scoredRows.map(\.key), appState: appState)
        guard !terms.isEmpty, !Task.isCancelled, lastLoadedKey == claimedKey else { return }
        for index in rows.indices {
            guard let found = terms[rows[index].key], !found.isEmpty else { continue }
            for axis in vocabularyAxes where rows[index].axisScores[axis] != nil {
                rows[index].axisEvidenceLabel[axis] = found.joined(separator: "\u{1F}")
            }
        }
    }

    /// Reload identity: re-runs when the pipeline becomes ready, the scope changes, a weight
    /// slider settles (via `weightReloadToken`), or the read-only stores are recreated after an
    /// in-session reindex (`readOnlyStoresGeneration`, the #275 convention — the engine's
    /// cross-reference and person axes read those stores, so a ranking computed against the
    /// pre-refresh connections must re-run once the stores are reopened).
    private var reloadKey: String {
        let scopeKey: String
        switch scope {
        case .allIndexed:          scopeKey = "all"
        case .volume(let v):       scopeKey = "vol:\(v)"
        case .subseries(let k, _): scopeKey = "sub:\(k)"
        }
        return "\(pipelineReady)|\(scopeKey)|\(weightReloadToken)|\(appState.readOnlyStoresGeneration)"
    }

    /// The empty-state detail, scope-aware so a scoped empty invites widening.
    private var emptyDetail: String {
        switch scope {
        case .allIndexed:
            return String(localized: "related.empty.detail",
                defaultValue: "No indexed documents share this document’s archival provenance or cross-references — indexing more volumes may surface some.")
        case .volume, .subseries:
            return String(localized: "related.empty.detail.scoped",
                defaultValue: "No related documents in this scope — switch to All volumes to search the whole index.")
        }
    }

    // MARK: Tuning

    /// The scope picker (when the anchor has a volume) plus a collapsible per-axis weight panel.
    @ViewBuilder
    private var tuningBar: some View {
        VStack(spacing: 8) {
            if availableScopes.count > 1 {
                Picker(selection: $scope) {
                    ForEach(availableScopes, id: \.self) { option in
                        Text(scopeLabel(option)).tag(option)
                    }
                } label: {
                    Text(String(localized: "related.scope.label", defaultValue: "Scope"))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            DisclosureGroup(String(localized: "related.weights.label", defaultValue: "Adjust weights")) {
                VStack(spacing: 6) {
                    ForEach(SimilarityAxis.allCases) { axis in
                        AxisWeightRow(
                            axis: axis,
                            value: Binding(get: { weights[axis] }, set: { weights[axis] = $0 }),
                            // Only this surface explains the semantic axis — see AxisWeightRow.caption.
                            caption: axisCaption(for: axis),
                            onCommit: {
                                persistedWeights = weights   // one write per drag, not per tick
                                weightReloadToken += 1       // re-rank once the drag settles
                            })
                    }
                    resetRow
                }
                .padding(.top, 4)
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// "Reset to app defaults" — the global tier of the same affordance the per-project panel has
    /// carried since #377 (#1029).
    ///
    /// ## It CLEARS the key, it does not write defaults into it
    /// Writing `AxisWeights.default` would pin today's numbers as an explicit tuning and re-create
    /// #1021 for the next axis anyone adds: `rawValue` spells out every axis, and
    /// `effectiveWeights` only falls back to a default when the axis is ABSENT, so a written-out
    /// value is indistinguishable from a deliberate one. Removing the key makes the reader genuinely
    /// unconfigured, which is the state every future default change can reach.
    ///
    /// Reset returns EVERY axis, `semanticSimilarity` included — back to its deliberate
    /// experimental 0.0 (owner decision 2026-08-12). One meaning of "default"; the sliders visibly
    /// moving is the disclosure that the opt-in was switched off.
    @ViewBuilder
    private var resetRow: some View {
        HStack {
            Spacer()
            Button(String(localized: "related.weights.reset", defaultValue: "Reset to app defaults")) {
                UserDefaults.standard.removeObject(forKey: SettingsKeys.relatedAxisWeights)
                weights = .default          // re-seed the live sliders
                weightReloadToken += 1      // and re-rank against them
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(UserDefaults.standard.object(forKey: SettingsKeys.relatedAxisWeights) == nil)
        }
    }

    /// What the semantic axis is, said where the reader actually meets it.
    ///
    /// **This axis was the only one nobody could learn about from its own surface.** Every other
    /// axis names itself adequately — "Shared people", "Close in date", "Archival provenance" — but
    /// "Semantically similar (experimental)" says nothing about what it matches on, and it ships at
    /// weight 0, so a reader who never drags this slider never sees a single semantic result. The
    /// only prose describing it lived in Settings ▸ Data & Recovery ▸ Semantic Match Feedback, a
    /// screen reached for an entirely different purpose. The app's most usable semantic feature was
    /// its least discoverable.
    ///
    /// Two states, because the useful sentence differs. At zero the reader needs to know what
    /// turning it on would buy and what it costs in confidence; above zero they need to know that
    /// their judgement of the results is the thing being collected.
    /// The per-axis explanatory caption, or `nil` for the axes that need none. The two
    /// experimental axes carry theirs where the slider is — the V-3 rule.
    private func axisCaption(for axis: SimilarityAxis) -> String? {
        switch axis {
        case .semanticSimilarity: return semanticAxisCaption
        case .lexicalSimilarity: return lexicalAxisCaption
        default: return nil
        }
    }

    /// The lexical axis's on-surface cost disclosure (W-17 §0.12): the query runs over
    /// the LOCAL index, so what it can find depends on what this device has indexed.
    private var lexicalAxisCaption: String {
        weights[.lexicalSimilarity] == 0
            ? String(localized: "related.weights.lexical.off",
                     defaultValue: "Off. Raise it to also match documents that reuse this one’s distinctive wording. Experimental; searches only the volumes indexed on this device, so results vary with your library.")
            : String(localized: "related.weights.lexical.on",
                     defaultValue: "Matches share this document’s distinctive wording. Searches only the volumes indexed on this device, so results vary with your library.")
    }

    private var semanticAxisCaption: String {
        weights[.semanticSimilarity] == 0
            ? String(localized: "related.weights.semantic.off",
                     defaultValue: "Off. Raise it to also match documents whose wording reads alike, even when they share no words, citations or archive. Experimental, and untested on nineteenth-century prose.")
            : String(localized: "related.weights.semantic.on",
                     defaultValue: "Matches carry a “Semantic match” score. Press and hold one — or right-click on a Mac — to say whether it helped. Those verdicts are how this axis gets judged.")
    }

    /// The scopes offered: this volume, this subseries (when it has more than one known member), all
    /// volumes. The anchor always has a volume, so the picker always offers at least volume + all.
    private var availableScopes: [NeighborScope] {
        let anchorVolumeId = request.anchorVolumeId
        var scopes: [NeighborScope] = [.volume(anchorVolumeId)]
        if let key = anchorSubseriesKey, subseriesMemberCount(key) > 1 {
            scopes.append(.subseries(key: key, anchorVolumeId: anchorVolumeId))
        }
        scopes.append(.allIndexed)
        return scopes
    }

    /// The anchor volume's non-empty subseries key, or `nil`.
    private var anchorSubseriesKey: String? {
        guard let key = appState.manifestStore.entry(forVolumeId: request.anchorVolumeId)?.subseries,
              !key.isEmpty else { return nil }
        return key
    }

    /// How many known volumes share a subseries key.
    private func subseriesMemberCount(_ key: String) -> Int {
        let entries = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return entries.filter { $0.subseries == key }.count
    }

    /// The short segmented-control label for a scope.
    private func scopeLabel(_ scope: NeighborScope) -> String {
        switch scope {
        case .allIndexed: return String(localized: "related.scope.all", defaultValue: "All volumes")
        case .volume:     return String(localized: "related.scope.volume", defaultValue: "This volume")
        case .subseries:  return String(localized: "related.scope.subseries", defaultValue: "This subseries")
        }
    }

    // MARK: Rows

    /// One related-document row: header, volume + dateline, a context snippet, and the "why
    /// related" axis chips with their scores.
    @ViewBuilder
    private func rowLabel(_ row: RelatedDocumentRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(row.record.header.isEmpty ? row.documentId : row.record.header)
                .font(.body).lineLimit(2)
            HStack(spacing: 6) {
                Text(row.volumeId).font(.caption).foregroundStyle(.secondary)
                if let dateline = row.record.dateline, !dateline.isEmpty {
                    Text(verbatim: "·").font(.caption).foregroundStyle(.tertiary)
                    Text(dateline).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            // A leading excerpt (or on-device summary) so the reader can judge relevance without
            // opening the document (#362).
            if let snippet = row.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            whyRelated(row)
        }
        .padding(.vertical, 2)
    }

    /// Small chips naming the axes that contributed to this row, strongest first — the "why
    /// related" affordance (#362).
    ///
    /// Generator axes state their **evidence** and scorer axes state their **score**, because a
    /// generator score is normalised by that anchor's own strongest candidate and so is not a
    /// quantity worth printing: archival provenance emits a constant, so its chip read exactly
    /// "100%" on every row it ever rendered, and an identical single citation read "100%" beside a
    /// lone partner but as little as "21%" beside a 48×-cited one. See ``WhyRelatedChip``.
    @ViewBuilder
    private func whyRelated(_ row: RelatedDocumentRow) -> some View {
        let chips = row.whyRelatedChips
        if !chips.isEmpty {
            HStack(spacing: 8) {
                ForEach(chips, id: \.axis) { axis, chip in
                    // One computed string drives both the visible chip and the a11y label, so they
                    // can never disagree.
                    let display: String = {
                        switch chip {
                        case .citations(let count):
                            return String(format: String(localized: "related.why.cited %lld",
                                                         defaultValue: "cited %lld×"), Int64(count))
                        case .cohort(let container, let size):
                            // Names the container and how big it is: sharing a 6-document lot is
                            // a finding, sharing one of 7,056 is a filing-cabinet coincidence, and
                            // "same provenance" said the same thing for both (#644).
                            return String(format: String(localized: "related.why.cohort %@ %lld",
                                                         defaultValue: "%@ · 1 of %lld"),
                                          container, Int64(size))
                        case .presence:
                            return String(localized: "related.why.sameProvenance",
                                          defaultValue: "same provenance")
                        case .sharedTerms(let terms):
                            // The anchor's own spelling, never a lemma — see SemanticSharedTerms.
                            return String(format: String(localized: "related.why.sharedTerms %@",
                                                         defaultValue: "shares: %@"),
                                          terms.joined(separator: ", "))
                        case .sharedSubjects(let names):
                            // "topics", not "shares" — the semantic chip already owns that verb on
                            // the same row, and these are detected topics rather than the
                            // document's own words.
                            return String(format: String(localized: "related.why.sharedSubjects %@",
                                                         defaultValue: "topics: %@"),
                                          names.joined(separator: ", "))
                        case .percent(let pct):
                            // A real but sub-1% contribution reads as "<1%", never "0%".
                            return pct == 0
                                ? String(localized: "related.why.subOnePercent", defaultValue: "<1%")
                                : String(format: String(localized: "related.why.percent %lld",
                                                        defaultValue: "%lld%%"), Int64(pct))
                        }
                    }()
                    HStack(spacing: 2) {
                        Image(systemName: axis.systemImage)
                        // The shared-terms chip is far wider than a percentage and this row is a
                        // single non-wrapping HStack, so it is allowed to truncate rather than
                        // squeeze the axes beside it out of the row.
                        Text(display).monospacedDigit().lineLimit(1).truncationMode(.tail)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(axis.displayName), \(display)"))
                }
            }
        }
    }

    /// Navigates to the tapped document (Browse tab on iOS; this window's provenance host on macOS
    /// via `AppState.openDocument(_:from: .tool(.relatedDocuments(request)))`), then invokes
    /// `onNavigate` (dismiss for the sheet, nothing for the window).
    private func open(_ row: RelatedDocumentRow) {
        let entry = DocumentBrowserEntry(
            documentId: row.documentId,
            volumeId: row.volumeId,
            header: row.record.header.isEmpty ? row.documentId : row.record.header)
        // #757 (L-41): the sheet reads in place, so the ranked list is still there on Back.
        if let onOpenInSheet {
            onOpenInSheet(entry)
            return
        }
        #if os(macOS)
        appState.openDocument(entry, from: .tool(.relatedDocuments(request)), using: openWindow)
        #else
        appState.openBrowseDocument(entry, from: sceneID)
        appState.openTab(.browse, from: sceneID)
        #endif
        onNavigate?()
    }
}

// MARK: - RelatedDocumentsSheet

/// The iOS sheet presentation of find-related — the shared content core wrapped in a
/// `NavigationStack` with a Done button. Presented where windows are unavailable (iPhone, iPads
/// without Stage Manager); where they exist, callers open `RelatedDocumentsWindowView` instead.
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
struct RelatedDocumentsSheet: View {

    /// Shared app state.
    let appState: AppState
    /// The query to present.
    let request: RelatedDocumentsRequest

    @Environment(\.dismiss) private var dismiss

    /// Documents opened from the ranked list, pushed INSIDE this sheet (#757 / audit L-41).
    @State private var navigationPath: [DocumentBrowserEntry] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            listContent
                .navigationTitle(String(localized: "related.title", defaultValue: "Related Documents"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 420)
        #endif
    }

    /// The ranked list, and — on iOS — the in-sheet reader it pushes into (#757 / audit L-41).
    ///
    /// The row used to hand the document to the Browse tab and then `dismiss()`, so stepping through
    /// a ranked work list meant re-opening the sheet after every document, re-running the query and
    /// re-scrolling from the top; Back landed in the Browse stack, not the list. The *window*
    /// presentation keeps its list alive (`onNavigate: nil`) — only this iPhone fallback threw it
    /// away.
    ///
    /// Simply dropping the dismiss would be #750's H-5 defect: the document lands invisibly beneath
    /// the still-presented sheet. Pushing inside the sheet is the shape Chronology, Citation Lookup
    /// and the graph sheet already use. Extracted into its own builder because a `#if` inside the
    /// body detaches the trailing modifier chain.
    ///
    /// macOS keeps the old routing: `DocumentView` is an iOS type, and there this sheet is only a
    /// fallback for a window that already preserves its list.
    @ViewBuilder
    private var listContent: some View {
        #if os(iOS)
        RelatedDocumentsContent(appState: appState, request: request,
                                onOpenInSheet: { navigationPath.append($0) })
            .navigationDestination(for: DocumentBrowserEntry.self) { entry in
                DocumentView(entry: entry, onNavigateToDocument: pushInSheet)
            }
        #else
        RelatedDocumentsContent(appState: appState, request: request, onNavigate: { dismiss() })
        #endif
    }

    /// Follows a cross-reference or page-turn inside this sheet, honouring #751's push/replace.
    private func pushInSheet(_ entry: DocumentBrowserEntry, _ jump: DocumentJump) {
        jump.apply(to: &navigationPath, appending: entry)
    }
}

// MARK: - RelatedDocumentsWindowView

/// The macOS (and iPad Stage Manager) window presentation of find-related: the shared content core
/// under window chrome. A window, not a sheet, because the ranked list is a work list the researcher
/// steps through — a row tap hands the document to the main window and this window stays open beside
/// it, exactly like the Archival Neighbors window (design §6.3, the C2/#317 value-based pattern).
///
/// Version history:
///   1.0 — #308 Phase 2b: initial implementation
struct RelatedDocumentsWindowView: View {

    /// The restorable query this window presents.
    let request: RelatedDocumentsRequest

    @Environment(AppState.self) private var appState

    var body: some View {
        #if os(iOS)
        // `.auxWindowOrigin` republishes the launching window's scene so a row-tap document routes
        // back to it (#338 aux-window origin).
        NavigationStack { content }
            .auxWindowOrigin(appState)
        #else
        content
        #endif
    }

    /// The shared content core under its title chrome, container-agnostic. The window stays open on a
    /// row tap (`onNavigate: nil`).
    private var content: some View {
        RelatedDocumentsContent(appState: appState, request: request, onNavigate: nil)
            .navigationTitle(String(localized: "related.title", defaultValue: "Related Documents"))
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 420)
            #endif
    }
}
