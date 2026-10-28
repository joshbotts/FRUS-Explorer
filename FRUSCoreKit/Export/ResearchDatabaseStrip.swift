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
/// The order is the whole correctness argument: have SQLite write zeros over whatever it frees,
/// null the columns, drop the tag names, empty your-content index, reclaim the freed pages, and
/// only then rebuild both external-content indexes against the rowids `VACUUM` may have
/// renumbered. Everything that held the writing is freed before the `VACUUM`, which drops it with
/// every other free page, and what the rebuilds free after it is written over. Why each step is
/// there, and why the rebuild is insurance rather than a demonstrated repair, is the app's
/// `IndexDatabaseExporter`'s notes 2 and 3.
///
/// The steps are values, not a function over a connection, so the kit needs no SQLite of its own
/// for them: the app's `IndexDatabaseExporter.strip(_:)` runs each with its own `exec`, naming the
/// step in its error by ``Step/action``, and a host outside the app runs them on its own
/// connection to strip an export before it serves it. They run on one connection, since the first
/// is a setting of the connection's, not of the file. It answers with a row, the setting it
/// leaves, which `sqlite3_exec`, as the app's `exec` calls it, passes over.
///
/// Version history:
///   1.0 — W-19 L-2: initial implementation, as `IndexDatabaseExporter.strip(_:)`
///   1.1 — FRUS Explorer Light: its statements moved into FRUSCoreKit, unchanged and in their order,
///          for a host that strips an export with the app's own sequence
///   1.2 — FRUS Explorer Light: `PRAGMA secure_delete = ON` first, and your-content index emptied
///          before `VACUUM`, so that a copy's free pages keep no word of the notes and summaries
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

    /// The strip's statements, to run in this order, all on one connection to a copy, never on a
    /// live index.
    public static let steps: [Step] = [
        // First, so that SQLite writes zeros over every page and cell freed after it while the
        // connection is open. At `FAST`, the default of macOS's SQLite, a freed page keeps what it
        // held, and nothing reclaims the pages the rebuilds free after the VACUUM. See
        // `IndexDatabaseExporter`'s note 3.
        Step(action: "preparing to overwrite freed space", sql: "PRAGMA secure_delete = ON"),
        Step(action: "removing your notes and summaries", sql: """
            UPDATE document_cache SET summary_text = NULL, note_text = NULL, user_tag_ids = NULL
            """),
        Step(action: "removing your tag names", sql: "DELETE FROM user_tags"),
        // Frees the pages of the notes' and summaries' index, which hold its terms, before the
        // VACUUM: left to the rebuild after it, they are freed where nothing reclaims them. After
        // the UPDATE, whose triggers would otherwise delete each row's old text from an index that
        // no longer holds it.
        Step(action: "emptying your-content index",
             sql: "INSERT INTO user_content(user_content) VALUES('delete-all')"),
        // Reclaims the freed pages, the live index's own among them, which the page copy brings.
        // Without this the words survive in the file even though no row and no index references
        // them any more.
        Step(action: "reclaiming freed pages", sql: "VACUUM"),
        // Both, and after the VACUUM. See `IndexDatabaseExporter`'s note 2.
        Step(action: "rebuilding the document index",
             sql: "INSERT INTO frus_documents(frus_documents) VALUES('rebuild')"),
        Step(action: "rebuilding your-content index",
             sql: "INSERT INTO user_content(user_content) VALUES('rebuild')"),
    ]
}
