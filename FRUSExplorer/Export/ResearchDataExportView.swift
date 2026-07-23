// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResearchDataExportView

/// Settings → Data → "Export Research Data…".
///
/// Offers two exports built from `ResearchDataExporter`:
/// - A single versioned JSON file containing notes, tags, highlights,
///   collections, user-created prompts, and projects (optionally including
///   AI-generated summaries).
/// - One Markdown file per research note, with YAML front matter linking back
///   to the source document, for use with Obsidian-style tools.
///
/// Both exports are written to a temporary directory and shared via `ShareLink`.
/// The macOS equivalent is `SettingsDataPane` (`NSSavePanel`-based).
///
/// Version history:
///   1.0 — Session 154: initial implementation
///   1.1 — Session 7 / #240B: "Broken Cross-References Report" section — CSV/JSON
///          ShareLinks re-serialized from the bundled broken-refs index.
struct ResearchDataExportView: View {

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

    @State private var includeGeneratedSummaries = false
    @State private var jsonExportURL: URL?
    @State private var jsonExportError: String?
    @State private var markdownExportURLs: [URL] = []
    @State private var isPreparingMarkdown = true
    @State private var brokenRefsCSVURL: URL?
    @State private var brokenRefsJSONURL: URL?

    private var userPromptCount: Int {
        prompts.filter { !$0.isStandard }.count
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.export.section.contents", defaultValue: "Contents")) {
                LabeledContent(String(localized: "settings.export.notes", defaultValue: "Research Notes"), value: "\(notes.count)")
                LabeledContent(String(localized: "settings.export.tags", defaultValue: "Tags & Assignments"), value: "\(tags.count + tagAssignments.count)")
                LabeledContent(String(localized: "settings.export.highlights", defaultValue: "Highlights"), value: "\(highlights.count)")
                LabeledContent(String(localized: "settings.export.collections", defaultValue: "Collections"), value: "\(collections.count)")
                LabeledContent(String(localized: "settings.export.prompts", defaultValue: "Custom Prompts"), value: "\(userPromptCount)")
                LabeledContent(String(localized: "settings.export.projects", defaultValue: "Projects"), value: "\(projects.count)")
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
                Text(String(
                    localized: "settings.export.json.footer",
                    defaultValue: "A single JSON file containing your notes, tags, highlights, collections, custom prompts, and projects."
                ))
            }

            Section {
                markdownExportRow
            } footer: {
                Text(String(
                    localized: "settings.export.markdown.footer",
                    defaultValue: "One Markdown file per research note, with a citation and link back to the source document. Compatible with Obsidian and similar note-taking tools."
                ))
            }

            if BrokenRefsIndexStore.shared != nil {
                Section {
                    brokenRefsCSVExportRow
                    brokenRefsJSONExportRow
                } header: {
                    Text(String(localized: "settings.export.brokenRefs.header", defaultValue: "Broken Cross-References Report"))
                } footer: {
                    Text(String(
                        localized: "settings.export.brokenRefs.footer",
                        defaultValue: "The corpus-wide list of cross-references in the printed FRUS volumes that point to a document, page, or volume not present in the corpus — for reporting to the Office of the Historian. The CSV lists distinct broken targets; the fuller per-occurrence spreadsheet with source line numbers is generated offline."
                    ))
                }
            }
        }
        .navigationTitle(String(localized: "settings.export.title", defaultValue: "Export Research Data"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: includeGeneratedSummaries) {
            prepareJSONExport()
        }
        .task {
            await prepareMarkdownExports()
        }
        .task {
            prepareBrokenRefsExports()
        }
    }

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

    // MARK: - Broken Cross-References Export Rows

    @ViewBuilder
    private var brokenRefsCSVExportRow: some View {
        if let brokenRefsCSVURL {
            ShareLink(item: brokenRefsCSVURL) {
                Label(String(localized: "settings.export.brokenRefs.csv", defaultValue: "Export as CSV"), systemImage: "tablecells")
            }
        } else {
            preparingRow
        }
    }

    @ViewBuilder
    private var brokenRefsJSONExportRow: some View {
        if let brokenRefsJSONURL {
            ShareLink(item: brokenRefsJSONURL) {
                Label(String(localized: "settings.export.brokenRefs.json", defaultValue: "Export as JSON"), systemImage: "doc.badge.arrow.up")
            }
        } else {
            preparingRow
        }
    }

    @ViewBuilder
    private var preparingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(String(localized: "settings.export.preparing", defaultValue: "Preparing export…"))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Export Preparation

    /// Writes the bundled broken-refs index to temporary CSV + JSON files for `ShareLink`.
    private func prepareBrokenRefsExports() {
        guard let index = BrokenRefsIndexStore.shared else { return }
        do {
            let csv = BrokenRefsReportExporter.csv(from: index)
            let csvURL = FileManager.default.temporaryDirectory.appendingPathComponent("frus-broken-cross-references.csv")
            try Data(csv.utf8).write(to: csvURL, options: .atomic)
            brokenRefsCSVURL = csvURL

            let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent("frus-broken-cross-references.json")
            try BrokenRefsReportExporter.jsonData().write(to: jsonURL, options: .atomic)
            brokenRefsJSONURL = jsonURL
        } catch {
            #if DEBUG
            print("[ResearchDataExportView] broken-refs export prep failed — \(error)")
            #endif
        }
    }

    /// Builds the JSON envelope and writes it to a temporary file for `ShareLink`.
    private func prepareJSONExport() {
        jsonExportURL = nil
        jsonExportError = nil
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
        print("[ResearchDataExportView] JSON export prepared: \(jsonExportURL?.lastPathComponent ?? "failed")")
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
        print("[ResearchDataExportView] Markdown export prepared: \(urls.count) file(s)")
        #endif
    }
}
