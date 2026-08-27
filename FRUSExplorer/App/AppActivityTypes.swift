// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

/// Handoff / NSUserActivity type identifiers.
///
/// The activity type strings must be registered in each target's `Info.plist`
/// under `NSUserActivityTypes` for Handoff to route activities to this app.
enum AppActivityTypes {
    /// A user is viewing a FRUS document. Carries `volumeId` and `documentId`
    /// in `userInfo` so the receiving device can navigate directly to it.
    static let document = "com.joshbotts.frus-explorer.document"

    /// A user is looking at the semantic map (UI review F-28). Carries the scope and the colour
    /// lens in `userInfo`, so the map the reader built on one device opens the same way on
    /// another.
    ///
    /// **The slice poles are carried since W-2, and the deferral that makes it safe exists.**
    /// They were deliberately excluded before that: `setPole` before the artifact loaded would
    /// half-apply — roll back the pole it had just set and post `semanticMap.axis.noSummary`, a
    /// confident diagnosis of the wrong cause — leaving a half-drawn axis card with no retry.
    /// `SemanticMapModel` now remembers an early pole in `requestedPoles`, exactly as `setScope`
    /// remembers a scope, and the view re-applies it after `prepare()` beside its deferred-reveal
    /// retry — so a continued map arrives sliced along the same axis the sender built.
    static let semanticMap = "com.joshbotts.frus-explorer.semanticMap"
}

// MARK: - SemanticMapRequest

/// A semantic map, in the terms a Handoff payload can carry (UI review F-28).
///
/// The map's own state is mostly not portable — the camera is a live projection, the lasso path is
/// view points at the sender's surface size, and `SemanticAxis` carries a 256-float direction that
/// is rebuilt from two volume centroids anyway. What survives a trip between devices is the part
/// the reader chose: **which volumes are in scope, what to call that scope, and the colour lens.**
///
/// `Codable` so it can round-trip through `NSUserActivity.userInfo`, which the app's other
/// analytics request types are not — none of `AnalyticsParameters`, `ChronologyParameters`,
/// `WordCloudScope` or `ArchivalScopeRequest` is, because none of them has ever needed to leave the
/// device.
///
/// `Hashable` so the same value can key a `WindowGroup(for:)` (CW-9a). That conformance is what
/// made the iPad map window nearly free: `openWindow(value:)` and `AppState.openAuxWindow` both
/// require `Codable & Hashable`, and this type was already `Codable` for Handoff — so the window
/// reuses the identity Handoff had already been given rather than inventing a second one. The
/// equality semantics are the useful ones here too: `openWindow(value:)` focuses an existing
/// window for an equal request and opens a new one otherwise, so two different scopes get two
/// windows and re-opening the same scope raises the one already showing it.
///
/// Version history:
///   1.0 — CW-7c: initial implementation (scope + lens; see `AppActivityTypes.semanticMap` for
///         why the slice poles are excluded)
///   1.1 — CW-9a: `Hashable`, so it can key the iPad/macOS map window scene
struct SemanticMapRequest: Codable, Equatable, Hashable, Sendable {

    /// The volumes the map is scoped to, or `nil` for the whole series.
    var volumeIDs: [String]?

    /// What to call the scope on screen, or `nil` when unscoped.
    var scopeLabel: String?

    /// The colour lens's raw value. Stored as the raw string rather than the enum so an older
    /// build receiving a lens it does not have falls back rather than failing to decode.
    var lensRawValue: String

    /// A document to reveal when the map opens, as `"volumeId/documentId"`.
    ///
    /// **Part of the identity, deliberately.** `SemanticMapRequest` keys the map's window scene, so
    /// including this means revealing a second document opens a second window rather than silently
    /// re-pointing the first — which is the behaviour this type already documents for scopes ("two
    /// different scopes get two windows"). Excluding it would be worse than either: `openWindow`
    /// would treat the two requests as equal, focus the existing window, and leave `continued`
    /// carrying the *first* document, so the control would appear to do nothing.
    ///
    /// Optional, and absent from every payload written before this field existed — an older
    /// Handoff activity decodes with `nil` and behaves exactly as it did.
    var focusDocumentKey: String?

    /// A cluster to focus when the map opens (#1051 B-7 — Browse's "See on the semantic
    /// map"), by the ARTIFACT's cluster id — meaningful only against the generation that
    /// minted it, which is why ``focusClusterDigest`` always travels with it.
    ///
    /// Part of the window identity for the same reason `focusDocumentKey` is. Optional and
    /// absent from every older payload, so old restorations decode with `nil` unchanged.
    var focusClusterID: Int?

    /// The provenance digest of the artifact ``focusClusterID`` was minted against.
    ///
    /// Cluster ids re-mint per artifact generation (the never-persist rule), and this
    /// request can outlive one — it rides window restoration across launches, and an app
    /// update between them can regenerate the artifact. The map applies the focus only
    /// when this digest matches the loaded artifact's; a stale request opens the map
    /// unfocused rather than landing on whatever re-minted cluster now wears the number.
    var focusClusterDigest: String?

    /// The volume at the axis's low end, when the sender had laid the corpus along a slice
    /// (W-2 — the F-28 remainder). Volume ids are stable across builds and artifact
    /// generations, unlike cluster ids, so no digest travels with them.
    ///
    /// Part of the window identity like every other field: two maps sliced along different
    /// axes are two windows. Optional and absent from every older payload, so old
    /// restorations decode with `nil` unchanged.
    var axisNegativeVolumeID: String?

    /// The volume at the axis's high end. Meaningful only beside
    /// ``axisNegativeVolumeID`` — the receiver applies poles only when both are present,
    /// because a lone pole draws a half-finished axis card and no slice.
    var axisPositiveVolumeID: String?

    /// Creates a request.
    /// - Parameters:
    ///   - volumeIDs: Scope, or `nil` for the whole series.
    ///   - scopeLabel: The scope's name.
    ///   - lensRawValue: The colour lens's raw value.
    init(volumeIDs: [String]?, scopeLabel: String?, lensRawValue: String,
         focusDocumentKey: String? = nil,
         focusClusterID: Int? = nil, focusClusterDigest: String? = nil,
         axisNegativeVolumeID: String? = nil, axisPositiveVolumeID: String? = nil) {
        self.volumeIDs = volumeIDs
        self.scopeLabel = scopeLabel
        self.lensRawValue = lensRawValue
        self.focusDocumentKey = focusDocumentKey
        self.focusClusterID = focusClusterID
        self.focusClusterDigest = focusClusterDigest
        self.axisNegativeVolumeID = axisNegativeVolumeID
        self.axisPositiveVolumeID = axisPositiveVolumeID
    }

    /// The unscoped whole-series map at the default lens — what the Browse menu's Semantic
    /// Analytics item means (CW-9a).
    ///
    /// A named value rather than a defaulted `init`, because this is the request that keys the
    /// window: `openWindow(value:)` focuses an existing window for an **equal** request, so every
    /// caller meaning "the whole corpus" has to produce the *same* value or the app opens a
    /// second identical map. Spelling it once is what guarantees that.
    ///
    /// `lensRawValue` tracks `SemanticMapSpikeView`'s own default (`.cluster`); the view falls
    /// back to `.cluster` anyway when handed a lens its build does not have, so a drift here
    /// degrades to the same map rather than to a broken one.
    static let wholeCorpus = SemanticMapRequest(volumeIDs: nil,
                                                scopeLabel: nil,
                                                lensRawValue: SemanticMapLens.cluster.rawValue)

    // MARK: - userInfo

    /// Keys used in the activity's `userInfo`.
    private enum Key {
        static let volumeIDs = "volumeIds"
        static let scopeLabel = "scopeLabel"
        static let lens = "lens"
        static let axisNegative = "axisNegative"
        static let axisPositive = "axisPositive"
    }

    /// The payload to hand to `NSUserActivity.userInfo`.
    ///
    /// Plist-safe types only — `[String]` and `String`. A `nil` scope is expressed by omitting the
    /// key rather than by encoding `NSNull`, because the receiver reads with `as?` and an absent
    /// key and a null both have to mean "whole series" anyway.
    var userInfo: [String: Any] {
        var info: [String: Any] = [Key.lens: lensRawValue]
        if let volumeIDs { info[Key.volumeIDs] = volumeIDs }
        if let scopeLabel { info[Key.scopeLabel] = scopeLabel }
        // Both poles or neither: a lone pole cannot draw a slice, only a half-finished card.
        if let axisNegativeVolumeID, let axisPositiveVolumeID {
            info[Key.axisNegative] = axisNegativeVolumeID
            info[Key.axisPositive] = axisPositiveVolumeID
        }
        return info
    }

    /// Rebuilds a request from an activity's `userInfo`.
    ///
    /// Returns `nil` only when the lens is missing, which is the one field with no sensible
    /// default: everything else legitimately absent means "whole series". An unknown lens string
    /// is kept rather than rejected — resolving it is the receiver's job, and a build that does
    /// not know the lens should still open the scoped map.
    ///
    /// - Parameter userInfo: The activity's payload.
    /// - Returns: The request, or `nil` if it carries no lens.
    static func from(userInfo: [AnyHashable: Any]?) -> SemanticMapRequest? {
        guard let lens = userInfo?[Key.lens] as? String else { return nil }
        return SemanticMapRequest(
            volumeIDs: userInfo?[Key.volumeIDs] as? [String],
            scopeLabel: userInfo?[Key.scopeLabel] as? String,
            lensRawValue: lens,
            axisNegativeVolumeID: userInfo?[Key.axisNegative] as? String,
            axisPositiveVolumeID: userInfo?[Key.axisPositive] as? String)
    }
}
