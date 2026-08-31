// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

// MARK: - ResearchDataExportView

/// The **Contents** inventory and the export rows at the top of Settings ▸ System ▸
/// **Data & Recovery** (`DataRecoveryView`, which is where this is hosted on **both** platforms —
/// there is no separate macOS pane; the `SettingsDataPane` this comment used to name was folded
/// into `DataRecoveryView` by S-4b).
///
/// Offers three exports built from `ResearchDataExporter`:
/// - A single versioned JSON file containing notes, tags, highlights, collections, user-created
///   prompts, projects and the research trail (optionally including AI-generated summaries).
/// - One Markdown file per research note, with YAML front matter linking back
///   to the source document, for use with Obsidian-style tools.
/// - The query log as a **method appendix** (M-2) — a Markdown table and a CSV, each carrying the
///   scope every search ran under and the caveats a reader needs to weigh the counts.
///
/// All three exports are written to a temporary directory and shared via `ShareLink`.
///
/// ## Why the trail counts are not `@Query`
/// Every other row here is backed by a `@Query`, which is fine for notes and collections and
/// wrong for the trail: it grows without bound by design (Wave R contract D5 — nothing prunes
/// it), so a `@Query` would hold every recorded visit in memory on a Settings screen and re-run
/// on each iCloud sync. `ResearchDataExporter.trailCounts(modelContext:)` is three `fetchCount`s,
/// taken in the same pass that builds the file, so the numbers on screen and the file being
/// offered describe the same read.
///
/// The accepted cost is that these three rows are a **snapshot** rather than live: the `@Query`
/// rows re-render when a note is added in another window, and these do not until the pane is
/// re-entered or the summaries toggle flipped. That is the right trade — the alternative is
/// holding an unbounded table in memory to keep a number current on a screen the reader is about
/// to leave — and it is not misleading, because the file on offer was built from that same
/// snapshot. Making the numbers live would mean making the file live with them.
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   1.1 — Session 7 / #240B: "Broken Cross-References Report" section — CSV/JSON
///          ShareLinks re-serialized from the bundled broken-refs index.
///   1.2 — Wave R-5: the inventory accounts for the research trail, which it had been silent
///          about, and the JSON footer says so under a new key
///   1.3 — M-2: the "Method Appendix" section — the query log as Markdown + CSV, which is the
///          half of Wave R decision D5 that the JSON export alone never delivered
struct DataExportSections: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var notes: [ResearchNote]
    @Query private var tags: [UserTag]
    @Query private var tagAssignments: [DocumentTagAssignment]
    @Query private var highlights: [DocumentHighlight]
    @Query private var collections: [Collection]
    @Query private var prompts: [SummarizationPrompt]
    @Query private var projects: [Project]
    @Query private var summaries: [GeneratedSummary]
    @Query private var archiveVisits: [ArchiveVisitPlan]

    /// Row counts for the three research-trail tables — see the type's note on why these are not
    /// `@Query`. Refreshed by `prepareJSONExport()`, which is also what writes the file.
    @State private var trailCounts: (visits: Int, searches: Int, exports: Int) = (0, 0, 0)

    @State private var includeGeneratedSummaries = false
    @State private var jsonExportURL: URL?
    @State private var jsonExportError: String?
    @State private var markdownExportURLs: [URL] = []
    @State private var appendixExportURLs: [URL] = []
    @State private var isPreparingMarkdown = true

    // MARK: Index database export (W-19 row L-2), macOS only
    /// Per-export consent, deliberately `@State` and OFF on every entry rather than `@AppStorage`:
    /// what leaves the machine is a decision each time, not a remembered preference.
    @State private var includeMyWritingInDatabase = false
    @State private var databaseExportRunning = false
    @State private var databaseExportResult: String?
    @State private var databaseExportProblem: String?

    private var userPromptCount: Int {
        prompts.filter { !$0.isStandard }.count
    }

    var body: some View {
        Group {
            Section(String(localized: "settings.export.section.contents", defaultValue: "Contents")) {
                LabeledContent(String(localized: "settings.export.notes", defaultValue: "Research Notes"), value: "\(notes.count)")
                LabeledContent(String(localized: "settings.export.tags", defaultValue: "Tags & Assignments"), value: "\(tags.count + tagAssignments.count)")
                LabeledContent(String(localized: "settings.export.highlights", defaultValue: "Highlights"), value: "\(highlights.count)")
                LabeledContent(String(localized: "settings.export.collections", defaultValue: "Collections"), value: "\(collections.count)")
                LabeledContent(String(localized: "settings.export.prompts", defaultValue: "Custom Prompts"), value: "\(userPromptCount)")
                LabeledContent(String(localized: "settings.export.projects", defaultValue: "Projects"), value: "\(projects.count)")
                LabeledContent(String(localized: "settings.export.archiveVisits", defaultValue: "Archive Visits"), value: "\(archiveVisits.count)")
                // Wave R-5. The three trail rows are worded exactly as the History screen's
                // section headers, so the same recorded thing is not called two different names
                // in two places. New keys rather than reuse of the `history.section.*` ones: no
                // String Catalog ships, so sharing a key across features is a collision waiting
                // for the first translator who needs them to differ.
                LabeledContent(String(localized: "settings.export.readingHistory", defaultValue: "Documents Visited"), value: "\(trailCounts.visits)")
                LabeledContent(String(localized: "settings.export.searchHistory", defaultValue: "Searches Executed"), value: "\(trailCounts.searches)")
                LabeledContent(String(localized: "settings.export.exportHistory", defaultValue: "Collections Exported"), value: "\(trailCounts.exports)")
            }

            Section {
                Toggle(
                    String(localized: "settings.export.includeSummaries", defaultValue: "Include AI-Generated Summaries"),
                    isOn: $includeGeneratedSummaries
                )
            } footer: {
                Text(String(
                    localized: "settings.export.includeSummaries.footer",
                    defaultValue: "Adds all \(summaries.count) generated summaries to the JSON export. Off by default since AI output can be large."
                ))
            }

            Section {
                jsonExportRow
            } footer: {
                // New key for Wave R-5 (`…json.footer.trail`). The old text listed six things and
                // the file now carries seven; rewriting `settings.export.json.footer` in place
                // would be a silent collision without a String Catalog. The trail is named
                // explicitly rather than folded into "your research data" because it is the part
                // a reader would not assume was in there — and the part they may want to check
                // before sharing the file, since it includes the text of every search they ran.
                // Archive Visits Phase 2 mints the key anew once more (`…json.footer.visits`):
                // the file now carries archive visit plans, and a footer that under-states the
                // export's contents is the same fault as an erase screen that under-states its
                // reach.
                Text(String(
                    localized: "settings.export.json.footer.visits",
                    defaultValue: "One JSON file with your notes, tags, highlights, collections, custom prompts, projects, and archive visit plans. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported."
                ))
            }

            #if os(macOS)
            databaseExportSection
            #endif

            Section {
                markdownExportRow
            } footer: {
                Text(String(
                    localized: "settings.export.markdown.footer",
                    defaultValue: "One Markdown file per research note, with a citation and link back to the source document. Compatible with Obsidian and similar note-taking tools."
                ))
            }

            Section {
                appendixExportRow
            } footer: {
                Text(String(
                    localized: "settings.export.appendix.footer",
                    defaultValue: "Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time. Counts that hit the app's row ceiling appear as \"at least N\", so a partial result is never printed as a total."
                ))
            }

        }
        .task(id: includeGeneratedSummaries) {
            prepareJSONExport()
            prepareAppendixExport()
        }
        .task {
            await prepareMarkdownExports()
        }
    }

    // MARK: - Index Database Export (macOS)

    #if os(macOS)
    /// Copies the whole search index to a file the reader chooses — what
    /// `Docs/Agentic-Analysis-Guide.md` §2 teaches by hand, so that pointing an outside AI agent at
    /// the index does not start with getting a WAL-mode copy right from a terminal.
    ///
    /// macOS only, and that is the honest shape rather than a shortfall: the app declares no
    /// iTunes/Finder file sharing, the guide already tells readers to do this work on a Mac, and a
    /// multi-gigabyte share sheet on an iPhone would be a worse answer than saying so.
    @ViewBuilder
    private var databaseExportSection: some View {
        Section {
            Toggle(
                String(localized: "settings.export.database.includeWriting",
                       defaultValue: "Include My Notes, Summaries, and Tags"),
                isOn: $includeMyWritingInDatabase
            )
            .disabled(databaseExportRunning)

            Button {
                exportIndexDatabase()
            } label: {
                if databaseExportRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "settings.export.database.running",
                                    defaultValue: "Copying the index…"))
                    }
                } else {
                    Label(String(localized: "settings.export.database.action",
                                 defaultValue: "Export Research Database…"),
                          systemImage: "cylinder.split.1x2")
                }
            }
            // The same interlock Index Health applies to its integrity button: a copy taken
            // mid-index is a copy of a half-written index.
            .disabled(databaseExportRunning
                      || appState.indexingBatch != nil
                      || appState.databaseURL == nil)

            if let databaseExportResult {
                Label(databaseExportResult, systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            if let databaseExportProblem {
                Label(databaseExportProblem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        } footer: {
            Text(String(
                localized: "settings.export.database.footer",
                defaultValue: "A complete copy of the search index, for analysis with your own tools. With the switch off, your notes, summaries and tag names are removed from the copy and the freed space reclaimed, so the words are gone rather than merely unlinked. The copy is verified before it is handed over. It is roughly the size of the index on disk."
            ))
        }
    }

    /// Runs the export off the main actor and reports what actually happened.
    private func exportIndexDatabase() {
        guard let source = appState.databaseURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "frus-index.sqlite"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        databaseExportResult = nil
        databaseExportProblem = nil
        databaseExportRunning = true
        let includeWriting = includeMyWritingInDatabase

        Task.detached(priority: .userInitiated) {
            do {
                let report = try IndexDatabaseExporter.export(
                    from: source, to: destination, includeMyWriting: includeWriting)
                let size = ByteCountFormatter.string(fromByteCount: report.byteCount,
                                                     countStyle: .file)
                await MainActor.run {
                    databaseExportRunning = false
                    if report.integrityProblems.isEmpty {
                        databaseExportResult = String(
                            localized: "settings.export.database.done",
                            defaultValue: "Exported \(size).")
                    } else {
                        // A file that looks fine and is not is the one outcome worth shouting
                        // about, so the problems are surfaced rather than folded into success.
                        databaseExportProblem = String(
                            localized: "settings.export.database.integrity",
                            defaultValue: "Exported \(size), but the copy did not verify: \(report.integrityProblems.joined(separator: "; "))")
                    }
                }
            } catch {
                await MainActor.run {
                    databaseExportRunning = false
                    databaseExportProblem = error.localizedDescription
                }
            }
        }
    }
    #endif

    // MARK: - JSON Export Row

    @ViewBuilder
    private var jsonExportRow: some View {
        if let jsonExportURL {
            ShareLink(item: jsonExportURL) {
                Label(String(localized: "settings.export.json.action", defaultValue: "Export as JSON"), systemImage: "doc.badge.arrow.up")
            }
        } else if let jsonExportError {
            Label(jsonExportError, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        } else {
            HStack(spacing: 8) {
                ProgressView()
                Text(String(localized: "settings.export.preparing", defaultValue: "Preparing export…"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Markdown Export Row

    @ViewBuilder
    private var markdownExportRow: some View {
        if isPreparingMarkdown {
            HStack(spacing: 8) {
                ProgressView()
                Text(String(localized: "settings.export.preparing", defaultValue: "Preparing export…"))
                    .foregroundStyle(.secondary)
            }
        } else if markdownExportURLs.isEmpty {
            Text(String(localized: "settings.export.markdown.empty", defaultValue: "No research notes to export."))
                .foregroundStyle(.secondary)
        } else {
            ShareLink(items: markdownExportURLs) {
                Label(
                    String(localized: "settings.export.markdown.action", defaultValue: "Export Notes as Markdown (\(markdownExportURLs.count))"),
                    systemImage: "doc.text"
                )
            }
        }
    }


    // MARK: - Method Appendix Row

    /// The query log as a methods statement (M-2). Two files rather than one because they answer
    /// different questions: the Markdown is pasted into a paper, the CSV is re-derived from.
    @ViewBuilder
    private var appendixExportRow: some View {
        if appendixExportURLs.isEmpty {
            Text(String(localized: "settings.export.appendix.empty",
                        defaultValue: "No searches recorded yet."))
                .foregroundStyle(.secondary)
        } else {
            ShareLink(items: appendixExportURLs) {
                Label(
                    String(localized: "settings.export.appendix.action",
                           defaultValue: "Export Query Log as a Method Appendix"),
                    systemImage: "list.bullet.rectangle.portrait"
                )
            }
        }
    }

    // MARK: - Export Preparation

    /// Renders the appendix to a Markdown and a CSV file for `ShareLink`.
    ///
    /// Runs from the same `.task` as the JSON export so both files describe one read of a trail
    /// that is still growing while this screen is open.
    private func prepareAppendixExport() {
        let appendix = ResearchDataExporter.methodAppendix(
            modelContext: modelContext,
            activeProjectId: appState.activeProjectId
        )
        guard !appendix.rows.isEmpty else {
            appendixExportURLs = []
            return
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSQueryLog-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var urls: [URL] = []
        for (name, content) in [("frus-query-log.md", appendix.markdown),
                                ("frus-query-log.csv", appendix.csv)] {
            let url = directory.appendingPathComponent(name)
            if (try? content.write(to: url, atomically: true, encoding: .utf8)) != nil {
                urls.append(url)
            }
        }
        appendixExportURLs = urls

        #if DEBUG
        print("[DataExportSections] Appendix prepared: \(appendix.rows.count) row(s), \(urls.count) file(s)")
        #endif
    }

    /// Builds the JSON envelope and writes it to a temporary file for `ShareLink`, and refreshes
    /// the trail counts shown in **Contents** from the same read.
    private func prepareJSONExport() {
        jsonExportURL = nil
        jsonExportError = nil
        trailCounts = ResearchDataExporter.trailCounts(modelContext: modelContext)
        do {
            let envelope = try ResearchDataExporter.makeEnvelope(
                modelContext: modelContext,
                includeGeneratedSummaries: includeGeneratedSummaries,
                activeProjectId: appState.activeProjectId
            )
            let data = try ResearchDataExporter.exportJSONData(envelope)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("frus-research-export.json")
            try data.write(to: url, options: .atomic)
            jsonExportURL = url
        } catch {
            jsonExportError = String(
                localized: "settings.export.json.error",
                defaultValue: "Couldn't prepare the export: \(error.localizedDescription)"
            )
        }

        #if DEBUG
        print("[DataExportSections] JSON export prepared: \(jsonExportURL?.lastPathComponent ?? "failed")")
        #endif
    }

    /// Renders one Markdown file per note into a fresh temporary directory for `ShareLink`.
    private func prepareMarkdownExports() async {
        let exports = await ResearchDataExporter.markdownExports(notes: notes, tags: tags, appState: appState)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSResearchNotes-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var urls: [URL] = []
        for export in exports {
            let url = directory.appendingPathComponent(export.filename)
            if (try? export.content.write(to: url, atomically: true, encoding: .utf8)) != nil {
                urls.append(url)
            }
        }

        markdownExportURLs = urls
        isPreparingMarkdown = false

        #if DEBUG
        print("[DataExportSections] Markdown export prepared: \(urls.count) file(s)")
        #endif
    }
}
