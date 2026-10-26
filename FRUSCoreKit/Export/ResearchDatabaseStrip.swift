// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ResearchDatabaseStrip

/// The statements that remove the reader's own writing from a copy of the search index, in order:
/// what Export Research Database… runs on its copy when Include My Notes, Summaries, and Tags is
/// off.
///
/// The order is the whole correctness argument: null the columns, drop the tag names, reclaim
/// the freed pages, and only then rebuild both external-content indexes against the rowids
/// `VACUUM` may have renumbered. Why each step is there, and why the rebuild is insurance rather
/// than a demonstrated repair, is the app's `IndexDatabaseExporter`'s notes 2 and 3.
///
/// The steps are values, not a function over a connection, so the kit needs no SQLite of its own
/// for them: the app's `IndexDatabaseExporter.strip(_:)` runs each with its own `exec`, naming the
/// step in its error by ``Step/action``, and a host outside the app runs them on its own
/// connection to strip an export before it serves it.
///
/// Version history:
///   1.0 — W-19 L-2: initial implementation, as `IndexDatabaseExporter.strip(_:)`
///   1.1 — FRUS Explorer Light: its statements moved into FRUSCoreKit, unchanged and in their order,
///          for a host that strips an export with the app's own sequence
public enum ResearchDatabaseStrip {

    /// One statement of the strip.
    public struct Step: Equatable, Sendable {
        /// What the statement does, in the words an export's error names it by ("The export
        /// failed while removing your tag names: …").
        public let action: String
        /// The statement.
        public let sql: String

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(action: String, sql: String) {
            self.action = action
            self.sql = sql
        }
    }

    /// The strip's statements, to run in this order on a copy, never on a live index.
    public static let steps: [Step] = [
        Step(action: "removing your notes and summaries", sql: """
            UPDATE document_cache SET summary_text = NULL, note_text = NULL, user_tag_ids = NULL
            """),
        Step(action: "removing your tag names", sql: "DELETE FROM user_tags"),
        // Reclaims the freed pages. Without this the words survive in the file even though no row
        // and no index references them any more.
        Step(action: "reclaiming freed pages", sql: "VACUUM"),
        // Both, and after the VACUUM. See `IndexDatabaseExporter`'s note 2.
        Step(action: "rebuilding the document index",
             sql: "INSERT INTO frus_documents(frus_documents) VALUES('rebuild')"),
        Step(action: "rebuilding your-content index",
             sql: "INSERT INTO user_content(user_content) VALUES('rebuild')"),
    ]
}
