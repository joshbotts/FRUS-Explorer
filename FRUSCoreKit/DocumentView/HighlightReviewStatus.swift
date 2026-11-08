// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HighlightReview

/// How a stored highlight stands against the text a reader would see now, after a volume update
/// (Volume-Update-Annotation-Integrity design §5.4, R-5 P3): the one fact the review surface states
/// about a highlight, read from the two values a highlight stores, so that a host outside the app
/// reviews its highlights by the app's rule.
///
/// The verbs a reader acts with stay in the app, over its `DocumentHighlight` model, in extensions of
/// this type: `status(of:currentVersion:)`, which reads the model's two values into this rule, with
/// **confirm** and **delete**, in `HighlightReview.swift`, and **modify** in `HighlightReanchor.swift`,
/// whose search is FRUSCoreKit's `HighlightReanchor`.
///
/// Version history:
///   1.0 — Session 2026-11-08 (FRUS Explorer Light, S21a): `Status` and the status rule moved into
///          FRUSCoreKit from the app's `HighlightReview.swift`, public; the rule takes a highlight's
///          `renderingVersion` and `selectedText` as values, where the app's
///          `status(of:currentVersion:)` read them off the model, and is otherwise unchanged
public enum HighlightReview {

    /// How a stored highlight stands against the text the reader would see now.
    public enum Status: Equatable, Sendable {
        /// Its `renderingVersion` is the document's current one: the offsets are exact.
        case aligned
        /// Made against an earlier rendering; positions may have moved. `hasPassage` says whether
        /// the highlight stored the words it covered — without them it can only be reviewed by eye.
        case stale(hasPassage: Bool)
        /// Nothing to compare against: no open render model and no revision row on this device.
        case unverifiable
    }

    /// The status of a highlight against `currentVersion` — the open document's
    /// `renderingVersion`, or the revision row's `bodyHash` (P1 pinned the two equal), or nil.
    ///
    /// - Parameters:
    ///   - renderingVersion: The highlight's stored `renderingVersion`.
    ///   - selectedText: The highlight's stored `selectedText`, the words it covered.
    ///   - currentVersion: The version to judge it by.
    public static func status(renderingVersion: String, selectedText: String,
                              currentVersion: String?) -> Status {
        guard let currentVersion, !currentVersion.isEmpty else { return .unverifiable }
        if renderingVersion == currentVersion { return .aligned }
        return .stale(hasPassage: !selectedText.isEmpty)
    }
}
