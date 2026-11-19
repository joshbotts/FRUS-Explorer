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
import UniformTypeIdentifiers
#endif

// MARK: - ResearchDataExportView

/// The **Contents** inventory and the export rows at the top of Settings ▸ System ▸
/// **Data & Recovery** (`DataRecoveryView`, which is where this is hosted on **both** platforms —
/// there is no separate macOS pane; the `SettingsDataPane` this comment used to name was folded
/// into `DataRecoveryView` by S-4b).
///
/// Offers three exports built from `ResearchDataExporter`:
/// - A single versioned JSON file containing notes, tags, highlights, collections, user-created
///   prompts, projects, archive visit plans, saved searches, working corpora, volume scopes, the
///   two kinds of correction, reviewed changes, Suggested Next leads, synced settings and the
///   research trail (optionally including AI-generated summaries).
/// - One Markdown file per research note, with YAML front matter linking back
///   to the source document, for use with Obsidian-style tools.
/// - The query log as a **method appendix** (M-2) — a Markdown table and a CSV, each carrying the
///   scope every search ran under and the caveats a reader needs to weigh the counts.
///
/// All three exports are written to a temporary directory and shared via `ShareLink`. On the Mac each
/// is also saved where the reader chooses (R6a, F3): the JSON in a save panel, and the notes and the
/// query log in a new folder inside a folder chosen in an open panel (`ExportDestinationWriter`).
///
/// ## Why the trail counts are not `@Query`
/// Every other row here is backed by a `@Query`, which is fine for notes and collections and
/// wrong for the trail: it grows without bound by design (Wave R contract D5 — nothing prunes
/// it), so a `@Query` would hold every recorded visit in memory on a Settings screen and re-run
/// on each iCloud sync. `ResearchDataExporter.trailCounts(modelContext:)` counts the three tables'
/// distinct ids, taken in the same pass that builds the file, so the numbers on screen and the file being
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
///   1.4 — FRUS Explorer Light: the inventory counts the eight types the JSON export carries from
///          format version 7, and the JSON footer names them under a new key
///   1.5 — #1791: every **Contents** count is of distinct ids, the records the export writes
///   1.6 — #1910: on the Mac, a line under Export Research Database… names the index version the
///          copy will carry, or says the index is being updated, and the done line names it too
///          (`DatabaseExportIndexVersion`)
///   1.7 — #1915 (L24): an **Import from JSON…** row beside Export as JSON, which asks the host to
///          open the file picker (`DataRecoveryView` presents it and the report,
///          `ResearchImportSheet`); a closed import prepares the export again
///   1.8 — R6a (F3): on the Mac the three file exports are saved where the reader chooses, beside
///          the share menu, with a line saying where they went
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
    @Query private var summaryCopies: [GeneratedSummary]
    @Query private var archiveVisits: [ArchiveVisitPlan]

    /// Row counts for the three research-trail tables — see the type's note on why these are not
    /// `@Query`. Refreshed by `prepareJSONExport()`, which is also what writes the file.
    @State private var trailCounts: (visits: Int, searches: Int, exports: Int) = (0, 0, 0)

    /// Row counts for the eight types format version 7 added, refreshed with the trail's.
    @State private var inventoryCounts = ResearchDataExporter.InventoryCounts()

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
    #if os(macOS)
    /// The line under the export the Mac last saved (R6a, F3): where it went, or why it did not.
    @State private var saveLine: ExportSaveLine?
    #endif
    #if os(macOS)
    /// The installed index version (#1910), observed, so the line under the button moves when a
    /// re-index raises it (`IndexingPipeline.markDateReindexComplete()`), which may be after the
    /// indexing batch has ended. Read only; the pipeline writes it.
    @AppStorage(IndexingPipeline.dateIndexVersionKey) private var installedIndexVersion = 0
    #endif

    /// Opens Import from JSON's file picker, which the host holds (#1915): a view of several
    /// sections carries no presentation modifier, since each section would repeat it.
    private let onImportJSON: () -> Void

    /// How many imports the host has closed. A change prepares the export again, so **Contents**
    /// and the file on offer count what an import brought.
    private let importGeneration: Int

    /// The sections, with the host's Import from JSON… action and its count of closed imports.
    init(onImportJSON: @escaping () -> Void = {}, importGeneration: Int = 0) {
        self.onImportJSON = onImportJSON
        self.importGeneration = importGeneration
    }

    private var userPromptCount: Int {
        DuplicateCopies.count(prompts.filter { !$0.isStandard }, id: \.id)
    }

    var body: some View {
        Group {
            Section(String(localized: "settings.export.section.contents", defaultValue: "Contents")) {
                LabeledContent(String(localized: "settings.export.notes", defaultValue: "Research Notes"), value: "\(DuplicateCopies.count(notes, id: \.id))")
                LabeledContent(String(localized: "settings.export.tags", defaultValue: "Tags & Assignments"), value: "\(DuplicateCopies.count(tags, id: \.id) + DuplicateCopies.count(tagAssignments, id: \.id))")
                LabeledContent(String(localized: "settings.export.highlights", defaultValue: "Highlights"), value: "\(DuplicateCopies.count(highlights, id: \.id))")
                LabeledContent(String(localized: "settings.export.collections", defaultValue: "Collections"), value: "\(DuplicateCopies.count(collections, id: \.id))")
                LabeledContent(String(localized: "settings.export.prompts", defaultValue: "Custom Prompts"), value: "\(userPromptCount)")
                LabeledContent(String(localized: "settings.export.projects", defaultValue: "Projects"), value: "\(DuplicateCopies.count(projects, id: \.id))")
                LabeledContent(String(localized: "settings.export.archiveVisits", defaultValue: "Archives Visits"), value: "\(DuplicateCopies.count(archiveVisits, id: \.id))")
                // Format version 7. Each row takes its words from the screen or setting that keeps
                // those records, and is counted like the trail rows below, from the read that
                // writes the file.
                LabeledContent(String(localized: "settings.export.savedSearches", defaultValue: "Saved Searches"), value: "\(inventoryCounts.savedSearches)")
                LabeledContent(String(localized: "settings.export.workingCorpora", defaultValue: "Working Corpora"), value: "\(inventoryCounts.workingCorpora)")
                LabeledContent(String(localized: "settings.export.volumeScopes", defaultValue: "Volume Scopes"), value: "\(inventoryCounts.volumeScopes)")
                LabeledContent(String(localized: "settings.export.classificationCorrections", defaultValue: "Classification Corrections"), value: "\(inventoryCounts.classificationCorrections)")
                LabeledContent(String(localized: "settings.export.personCorrections", defaultValue: "Person Corrections"), value: "\(inventoryCounts.personCorrections)")
                LabeledContent(String(localized: "settings.export.reviewedChanges", defaultValue: "Reviewed Changes"), value: "\(inventoryCounts.reviewedChanges)")
                LabeledContent(String(localized: "settings.export.suggestedNext", defaultValue: "Suggested Next Leads"), value: "\(inventoryCounts.suggestedLeads)")
                LabeledContent(String(localized: "settings.export.syncedSettings", defaultValue: "Synced Settings"), value: "\(inventoryCounts.syncedSettings)")
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
                // reach. Format version 7 mints it again (`…json.footer.searches`), for the eight
                // types the file now carries, saved searches first.
                Text(String(
                    localized: "settings.export.json.footer.searches",
                    defaultValue: "One JSON file with your notes, tags, highlights, collections, custom prompts, projects, archive visit plans, saved searches, working corpora, volume scopes, corrections, reviewed changes, Suggested Next leads, and synced settings. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported."
                ))
            }

            // #1915 (L24): the way back in, beside the way out. The host presents the picker and
            // the report (`DataRecoveryView`).
            Section {
                Button {
                    onImportJSON()
                } label: {
                    Label(ResearchImportCopy.rowAction, systemImage: "arrow.down.doc")
                }
                .accessibilityIdentifier("settings.import.json")
            } footer: {
                Text(ResearchImportCopy.rowFooter)
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
                    defaultValue: "Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time. Counts that hit the app’s row ceiling appear as “at least N”, so a partial result is never printed as a total."
                ))
            }

        }
        .task(id: ExportPreparation(includeGeneratedSummaries: includeGeneratedSummaries,
                                    importGeneration: importGeneration)) {
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

            // #1910: the index version the copy will carry, which FRUS Explorer Light checks an
            // export against before it serves one, so a reader can check it before copying
            // gigabytes. While a batch runs the button is disabled, and the line says why.
            Text(DatabaseExportIndexVersion.line(installed: installedIndexVersion,
                                                 current: IndexingPipeline.currentDateIndexVersion,
                                                 isUpdating: appState.indexingBatch != nil))
                .foregroundStyle(.secondary)

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
        // Taken here, on the main actor and before the copy starts, so the stamp inside the file
        // describes the index at the moment it was read rather than whenever the copy finished.
        let stamp = ResearchStateRecord.make(
            pipeline: appState.indexingPipeline,
            semanticDigest: BundledSemanticVectors.provenance?.digestHex)

        Task.detached(priority: .userInitiated) {
            do {
                let report = try IndexDatabaseExporter.export(
                    from: source, to: destination, includeMyWriting: includeWriting, stamp: stamp)
                let size = ByteCountFormatter.string(fromByteCount: report.byteCount,
                                                     countStyle: .file)
                await MainActor.run {
                    databaseExportRunning = false
                    if report.integrityProblems.isEmpty {
                        // The version the stamp inside the copy records, taken before the copy.
                        databaseExportResult = DatabaseExportIndexVersion.doneLine(
                            size: size, version: stamp.installedIndexVersion)
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

    // MARK: - Saving an export on the Mac (R6a, F3)

    #if os(macOS)
    /// Saves the prepared JSON file where the reader names it, in a save panel (R6a, F3).
    ///
    /// A Mac's share menu offers only places to send a file, so before R6a the JSON could not be
    /// saved to a folder: the owner shared it to Mail and saved it from the draft (R6, X1). The share
    /// menu stays beside the row; iOS keeps its share sheet, which has Save to Files.
    private func saveJSONExport(_ file: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = file.lastPathComponent
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try ExportDestinationWriter.save(file, to: destination)
            saveLine = ExportSaveLine(export: .json, text: ExportDestinationWriter.savedFileLine(destination),
                                      failed: false)
        } catch {
            saveLine = ExportSaveLine(export: .json, text: ExportDestinationWriter.failedLine(error), failed: true)
        }
    }

    /// Saves an export of several files into a new folder inside the folder the reader chooses, in an
    /// open panel (R6a, F3): the notes, one file per note, and the query log's Markdown and CSV.
    private func saveFolderExport(_ files: [URL], folderName: String, message: String, export: SavedExport) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "settings.export.folder.prompt", defaultValue: "Export Here")
        panel.message = message
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        do {
            let folder = try ExportDestinationWriter.saveFolder(of: files, named: folderName, in: parent)
            saveLine = ExportSaveLine(export: export,
                                      text: ExportDestinationWriter.savedFolderLine(folder, count: files.count),
                                      failed: false)
        } catch {
            saveLine = ExportSaveLine(export: export, text: ExportDestinationWriter.failedLine(error), failed: true)
        }
    }

    /// The line under the export the Mac last saved: where it went, or why it did not.
    @ViewBuilder
    private func saveLineRow(for export: SavedExport) -> some View {
        if let saveLine, saveLine.export == export {
            Label(saveLine.text, systemImage: saveLine.failed ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(saveLine.failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        }
    }

    /// The share menu kept beside each Mac export.
    private static var shareTitle: String {
        String(localized: "settings.export.share", defaultValue: "Share…")
    }
    #endif

    // MARK: - JSON Export Row

    @ViewBuilder
    private var jsonExportRow: some View {
        if let jsonExportURL {
            #if os(macOS)
            HStack {
                Button {
                    saveJSONExport(jsonExportURL)
                } label: {
                    Label(String(localized: "settings.export.json.action.mac", defaultValue: "Export as JSON…"),
                          systemImage: "doc.badge.arrow.up")
                }
                Spacer()
                ShareLink(item: jsonExportURL) {
                    Label(Self.shareTitle, systemImage: "square.and.arrow.up")
                }
            }
            saveLineRow(for: .json)
            #else
            ShareLink(item: jsonExportURL) {
                Label(String(localized: "settings.export.json.action", defaultValue: "Export as JSON"), systemImage: "doc.badge.arrow.up")
            }
            #endif
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
            #if os(macOS)
            HStack {
                Button {
                    saveFolderExport(
                        markdownExportURLs,
                        folderName: String(localized: "settings.export.markdown.folderName",
                                           defaultValue: "FRUS Research Notes"),
                        message: String(localized: "settings.export.markdown.panelMessage",
                                        defaultValue: "Choose a folder. Your notes are saved in a new folder inside it, “FRUS Research Notes”, one Markdown file per note."),
                        export: .markdown)
                } label: {
                    Label(
                        String(localized: "settings.export.markdown.action.mac",
                               defaultValue: "Export Notes as Markdown (\(markdownExportURLs.count))…"),
                        systemImage: "doc.text"
                    )
                }
                Spacer()
                ShareLink(items: markdownExportURLs) {
                    Label(Self.shareTitle, systemImage: "square.and.arrow.up")
                }
            }
            saveLineRow(for: .markdown)
            #else
            ShareLink(items: markdownExportURLs) {
                Label(
                    String(localized: "settings.export.markdown.action", defaultValue: "Export Notes as Markdown (\(markdownExportURLs.count))"),
                    systemImage: "doc.text"
                )
            }
            #endif
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
            #if os(macOS)
            HStack {
                Button {
                    saveFolderExport(
                        appendixExportURLs,
                        folderName: String(localized: "settings.export.appendix.folderName",
                                           defaultValue: "FRUS Query Log"),
                        message: String(localized: "settings.export.appendix.panelMessage",
                                        defaultValue: "Choose a folder. The query log is saved in a new folder inside it, “FRUS Query Log”, as a Markdown table and a CSV."),
                        export: .appendix)
                } label: {
                    Label(
                        String(localized: "settings.export.appendix.action.mac",
                               defaultValue: "Export Query Log as a Method Appendix…"),
                        systemImage: "list.bullet.rectangle.portrait"
                    )
                }
                Spacer()
                ShareLink(items: appendixExportURLs) {
                    Label(Self.shareTitle, systemImage: "square.and.arrow.up")
                }
            }
            saveLineRow(for: .appendix)
            #else
            ShareLink(items: appendixExportURLs) {
                Label(
                    String(localized: "settings.export.appendix.action",
                           defaultValue: "Export Query Log as a Method Appendix"),
                    systemImage: "list.bullet.rectangle.portrait"
                )
            }
            #endif
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
    /// the trail counts and format version 7's counts shown in **Contents** from the same read.
    private func prepareJSONExport() {
        jsonExportURL = nil
        jsonExportError = nil
        trailCounts = ResearchDataExporter.trailCounts(modelContext: modelContext)
        inventoryCounts = ResearchDataExporter.inventoryCounts(modelContext: modelContext)
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
                defaultValue: "Couldn’t prepare the export: \(error.localizedDescription)"
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

// MARK: - The index version an export carries (#1910)

/// What Export Research Database… says about the index version its copy will carry (#1910).
///
/// FRUS Explorer Light serves an export only at its own index version, and refuses any other once
/// the copy has been made and imported: "This export is index version N; this server serves index
/// version M". So the Mac names the version under the button, before the reader copies an index of
/// several gigabytes: the installed one, the version the copy's `research_provenance` records as
/// `installed_index_version`. While an indexing batch runs the button is disabled, and the line
/// says the index is being updated, to the version this build writes when the installed one is
/// older.
///
/// Pure, so a test reads every case without an index; only the Mac shows it, beside the button.
///
/// Version history:
///   1.0 — 2026-11-17 (#1910): initial implementation
enum DatabaseExportIndexVersion {

    /// The line under the button.
    ///
    /// - Parameters:
    ///   - installed: The installed index version (`IndexingPipeline.dateIndexVersionKey`), `0`
    ///     before any was recorded.
    ///   - current: The version this build writes (`IndexingPipeline.currentDateIndexVersion`).
    ///   - isUpdating: Whether an indexing batch is running (`AppState.indexingBatch`).
    static func line(installed: Int, current: Int, isUpdating: Bool) -> String {
        if isUpdating {
            if installed < current {
                return String(localized: "settings.export.database.indexVersion.updatingTo",
                              defaultValue: "The index is being updated to version \(current). You can export it when the update is done.")
            }
            return String(localized: "settings.export.database.indexVersion.updating",
                          defaultValue: "The index is being updated. You can export it when the update is done.")
        }
        if installed <= 0 {
            return String(localized: "settings.export.database.indexVersion.none",
                          defaultValue: "The index has no version recorded yet.")
        }
        if installed < current {
            return String(localized: "settings.export.database.indexVersion.older",
                          defaultValue: "The copy will carry index version \(installed), not this build’s \(current).")
        }
        return String(localized: "settings.export.database.indexVersion",
                      defaultValue: "The copy will carry index version \(installed).")
    }

    /// The line a copy that verified shows when it is done: its size and the index version the
    /// stamp inside it records.
    static func doneLine(size: String, version: Int) -> String {
        guard version > 0 else {
            return String(localized: "settings.export.database.done", defaultValue: "Exported \(size).")
        }
        return String(localized: "settings.export.database.done.withVersion",
                      defaultValue: "Exported \(size), index version \(version).")
    }
}

// MARK: - What prepares the export again (#1915)

extension DataExportSections {
    /// The preparation task's identity: the summaries switch, and the count of imports the host has
    /// closed, so an import's records reach **Contents** and the file on offer.
    struct ExportPreparation: Equatable {
        var includeGeneratedSummaries: Bool
        var importGeneration: Int
    }
}

// MARK: - One copy of each summary (#1791)

extension DataExportSections {
    /// The generated summaries, one copy of each however many are stored under its id
    /// (`DuplicateCopies`): the count the summaries switch's footer gives is the count the file
    /// writes.
    private var summaries: [GeneratedSummary] { DuplicateCopies.oneEach(summaryCopies, id: \.id) }
}

// MARK: - Saving an export where the reader chooses (R6a, F3)

/// Which of Data & Recovery's file exports the Mac saved (R6a, F3).
enum SavedExport: Hashable, Sendable {
    /// Export as JSON.
    case json
    /// Export Notes as Markdown, one file per note.
    case markdown
    /// Export Query Log as a Method Appendix, a Markdown table and a CSV.
    case appendix
}

/// The line under an export the Mac saved: where its file or folder went, or why it did not.
struct ExportSaveLine: Equatable, Sendable {
    /// The export the line is about.
    let export: SavedExport
    /// What the line says.
    let text: String
    /// Whether the save failed.
    let failed: Bool
}

/// Copies an export's prepared files to where the reader chose on the Mac (R6a, F3).
///
/// Data & Recovery prepares each export in a temporary directory, for the share sheet. A Mac's share
/// menu offers only places to send a file, so the Mac also saves it: one file where a save panel
/// names it, and several into a new folder inside the folder an open panel chooses, numbered when
/// that folder already holds one of the name, so an export never writes over an earlier one. Foundation
/// only, so the iOS test target holds it to its rules.
///
/// Version history:
///   1.0 — R6a (F3): initial implementation
enum ExportDestinationWriter {

    /// Copies `file` to `destination`, replacing a file there, which the save panel has already asked
    /// the reader about.
    static func save(_ file: URL, to destination: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.copyItem(at: file, to: destination)
    }

    /// Copies `files` into a new folder named `folderName` inside `parent`, or `folderName 2`, `3` and
    /// on when one of the name is there, and returns the new folder.
    static func saveFolder(of files: [URL], named folderName: String, in parent: URL) throws -> URL {
        let manager = FileManager.default
        var folder = parent.appendingPathComponent(folderName, isDirectory: true)
        var number = 2
        while manager.fileExists(atPath: folder.path) {
            folder = parent.appendingPathComponent("\(folderName) \(number)", isDirectory: true)
            number += 1
        }
        try manager.createDirectory(at: folder, withIntermediateDirectories: false)
        for file in files {
            try manager.copyItem(at: file, to: folder.appendingPathComponent(file.lastPathComponent))
        }
        return folder
    }

    /// The line under an export saved as one file: its name, and the folder it went into.
    static func savedFileLine(_ destination: URL) -> String {
        let name = destination.lastPathComponent
        let folder = destination.deletingLastPathComponent().lastPathComponent
        return String(localized: "settings.export.saved.file",
                      defaultValue: "Saved “\(name)” in \(folder).")
    }

    /// The line under an export saved as a folder of files: how many, the new folder's name, and the
    /// folder it went into, the count through `CountCopy` so that one note reads "1 file".
    static func savedFolderLine(_ folder: URL, count: Int) -> String {
        let name = folder.lastPathComponent
        let parent = folder.deletingLastPathComponent().lastPathComponent
        return CountCopy.phrase(
            count,
            one: String(localized: "settings.export.saved.folder.one %@",
                        defaultValue: "Saved %1$@ file in a new folder, “%2$@”, in %3$@."),
            many: String(localized: "settings.export.saved.folder.many %@",
                         defaultValue: "Saved %1$@ files in a new folder, “%2$@”, in %3$@."),
            then: [name, parent])
    }

    /// The line under an export that could not be saved.
    static func failedLine(_ error: any Error) -> String {
        String(localized: "settings.export.saveFailed",
               defaultValue: "Couldn’t save the export: \(error.localizedDescription)")
    }
}
