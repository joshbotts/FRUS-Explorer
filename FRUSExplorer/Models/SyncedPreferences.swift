// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

/// A single CloudKit-synced record holding the user preferences that are worth
/// carrying across devices: word-cloud filtering criteria and stop lists, the
/// citation style, the default document mode, and the research-logging toggle.
///
/// This is conceptually a singleton, but SwiftData + CloudKit cannot enforce a
/// unique constraint, so two offline devices may each create one. `SettingsSyncCoordinator`
/// resolves that by treating the earliest-created record as canonical and deleting
/// the rest — the same strategy `DuplicateRecordCleanup` uses for other models.
///
/// Whether a device actually reads from or writes to this record is governed by a
/// **device-local** toggle (never synced), so a user can keep distinct settings on
/// different devices simply by leaving sync off there. The record itself always
/// participates in container-wide CloudKit sync; sync-off devices just ignore it.
///
/// All properties have defaults (a CloudKit requirement). The two stop lists are
/// stored as JSON strings so the shape matches regardless of platform array support.
///
/// > Important: Adding this model type means the CloudKit schema must be redeployed
/// > to Production before an App Store build can sync it (see `frusModelTypes`).
///
/// Version history:
///   1.0 — Optional iCloud settings sync
@Model
final class SyncedPreferences {

    /// Creation timestamp; the earliest record wins when duplicates exist.
    var createdAt: Date = Date.now
    /// Last write timestamp, bumped on every push (informational / future merge use).
    var updatedAt: Date = Date.now

    // MARK: - Word cloud criteria

    /// Minimum surviving token length.
    var wcMinLength: Int = 3
    /// Minimum total occurrence count.
    var wcMinCount: Int = 1
    /// Whether plural-folding is enabled.
    var wcFoldPlurals: Bool = true
    /// Whether classification markings are filtered.
    var wcFilterMarkings: Bool = true
    /// Whether diplomatic boilerplate is hidden.
    var wcExcludeBoilerplate: Bool = true
    /// JSON-encoded `[String]` of global custom stopwords.
    var wcGlobalStopwordsJSON: String = ""
    /// JSON-encoded `[lensRawValue: [String]]` of per-lens custom stopwords.
    var wcLensStopwordsJSON: String = ""

    // MARK: - Other synced preferences

    /// Persisted citation-style raw value (empty means "unset / use default").
    var citationStyleRaw: String = ""
    /// Persisted default-document-mode raw value (empty means "unset / use default").
    var defaultDocumentModeRaw: String = ""
    /// Whether research sessions are logged.
    var researchLoggingEnabled: Bool = true

    /// Creates an empty preferences record with default values.
    init() {}
}
