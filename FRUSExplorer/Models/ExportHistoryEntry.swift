// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ExportHistoryEntry

/// Records a single collection export — the third and last typed member of the research trail
/// (Wave R contract, decision **D1**).
///
/// ## Why exports survive when note-saves do not
/// `SessionEvent` carried four event kinds. Three of them duplicated something the app already
/// stored: `.documentOpen` had a matching ``ReadingHistoryEntry``, `.searchSubmit` a matching
/// ``SearchHistoryEntry`` (on macOS from the start, on iOS since Wave R-4), and `.noteSave` a
/// `ResearchNote` that timestamps itself. `.export` had no counterpart at all. The collection
/// persists, but nothing else recorded *that you exported it, when, in what format, or how many
/// documents went out*.
///
/// The Zotero API push is the decisive case: `ExportSheetView.sendToZoteroLibrary` has a real
/// external side effect — items land in the user's live Zotero library — and this row is the app's
/// only memory that it happened. Losing it in the retirement of `SessionEvent` would have been the
/// one place where collapsing to one trail actually lost information.
///
/// ## Attribution
/// `projectId` is stamped at **write** time, exactly like its two siblings, so the same
/// ``HistoryScope`` predicates apply and project merge re-points it. Rows migrated from legacy
/// `SessionEvent`s carry `nil`: the old event type had no `projectId` at all — which is one of the
/// reasons the wave retired it — so there is nothing to recover and inventing one would be a
/// fabricated attribution.
///
/// ## No `lastModified`
/// Export entries are immutable historical records, like ``ReadingHistoryEntry`` and
/// ``SearchHistoryEntry``. A re-export is a new row, not an edit.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation, replacing `SessionEvent`'s `.export` kind
@Model final class ExportHistoryEntry {

    // MARK: - Identity

    /// The entry's stable identifier.
    ///
    /// For a row written live this is a fresh `UUID`. For a row produced by
    /// ``ResearchTrailMigration`` it is **the migrated `SessionEvent`'s own id**, which is what
    /// makes the migration idempotent: re-running it finds the row already present and does
    /// nothing. See that type for the full argument.
    var id: UUID = UUID()

    // MARK: - What was exported

    /// The export format, as `ExportFormat.rawValue` — plus the one value that is not a member of
    /// that enum, `"zotero-api"`, which the Web-API send used in the legacy event payload and
    /// which is kept verbatim so migrated rows and live rows read the same.
    var format: String = ""

    /// How many documents the export carried. For the Zotero API push this is the count the server
    /// accepted (`ZoteroSendResult.addedItems`), not the count attempted — the legacy event
    /// recorded the same thing.
    var documentCount: Int = 0

    /// The collection's name at export time, or `nil`.
    ///
    /// Optional for CloudKit schema compatibility, and genuinely absent on migrated rows: the
    /// legacy `.export` payload carried only the format and the document count, so a migrated row
    /// can say *what* left the app but not *which collection* it came from.
    var collectionName: String?

    // MARK: - Project Context

    /// The project active when the export ran. `nil` for global context, and always `nil` on
    /// migrated rows (see the type's Attribution note).
    var projectId: UUID?

    // MARK: - Timestamp

    /// When the export completed. Optional for CloudKit schema compatibility — always non-nil in
    /// practice.
    var exportedAt: Date?

    // MARK: - Initializer

    /// Creates an export record.
    ///
    /// - Parameters:
    ///   - id: The entry's identifier. Defaults to a fresh `UUID`; ``ResearchTrailMigration``
    ///     passes the source event's id so a second migration pass is a no-op.
    ///   - format: `ExportFormat.rawValue`, or `"zotero-api"` for the Web-API send.
    ///   - documentCount: How many documents went out.
    ///   - collectionName: The collection's name, or `nil` when it is not known.
    ///   - projectId: The active project, or `nil`.
    ///   - exportedAt: When it happened. Defaults to now; the migration passes the source event's
    ///     timestamp so the trail keeps its real chronology.
    init(
        id: UUID = UUID(),
        format: String,
        documentCount: Int = 0,
        collectionName: String? = nil,
        projectId: UUID? = nil,
        exportedAt: Date = .now
    ) {
        self.id = id
        self.format = format
        self.documentCount = documentCount
        self.collectionName = collectionName
        self.projectId = projectId
        self.exportedAt = exportedAt

        #if DEBUG
        print("[SwiftData] ExportHistoryEntry created: \(format) docs=\(documentCount) " +
              "project=\(projectId?.uuidString ?? "nil")")
        #endif
    }
}

// MARK: - ExportHistoryRecorder

/// The one gated writer of ``ExportHistoryEntry``.
///
/// ## Why this is not four inline inserts
/// `ExportSheetView` finishes an export in four places (the rendered-format path, the native
/// `.fruscollection` file, the Zotero RIS file, and the Zotero Web-API push). Each used to call
/// `AppState.logEvent(.export(…))`, which carried the research-logging gate inside it. Re-pointing
/// them at a bare `context.insert(ExportHistoryEntry(…))` would have put four copies of the gate in
/// a view — and `ResearchLoggingGateTests.noUngatedHistoryWriterExists` exists precisely because
/// this app has already shipped a trail writer with no gate at all.
///
/// So the gate lives here, once, in the same shape as
/// `DocumentViewModel.recordReadingHistory(projectId:in:defaults:)` and the two
/// `recordSearchHistory` writers: read `AppState.isResearchLoggingEnabled(in:)` **before**
/// inserting, take the defaults store as a parameter so tests need not touch global state.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
enum ExportHistoryRecorder {

    /// Records one completed export, unless research logging is off.
    ///
    /// - Parameters:
    ///   - format: `ExportFormat.rawValue`, or `"zotero-api"` for the Web-API send.
    ///   - documentCount: How many documents went out.
    ///   - collectionName: The collection's name; trimmed, and dropped when empty.
    ///   - projectId: The active project, or `nil`.
    ///   - context: The context the entry is inserted into.
    ///   - defaults: The store the research-logging gate is read from. Defaults to `.standard`;
    ///     overridden only by tests.
    /// - Returns: `true` when a row was written, `false` when the gate suppressed it. Returned
    ///   rather than discarded so the behaviour is assertable without a fetch.
    @MainActor
    @discardableResult
    static func record(format: String,
                       documentCount: Int,
                       collectionName: String?,
                       projectId: UUID?,
                       in context: ModelContext,
                       defaults: UserDefaults = .standard) -> Bool {
        guard AppState.isResearchLoggingEnabled(in: defaults) else {
            #if DEBUG
            print("[ExportHistory] ExportHistoryEntry suppressed (research logging off): \(format)")
            #endif
            return false
        }
        let name = collectionName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = ExportHistoryEntry(
            format: format,
            documentCount: documentCount,
            collectionName: (name?.isEmpty ?? true) ? nil : name,
            projectId: projectId
        )
        context.insert(record)
        #if DEBUG
        print("[ExportHistory] ExportHistoryEntry recorded: \(format) docs=\(documentCount)")
        #endif
        return true
    }
}
