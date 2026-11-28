// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// Import from JSON's screen (#1915, L24): the report of what a file will do, then the import, on the
// Mac and on iOS alike. Settings ▸ System ▸ Data & Recovery offers it (`DataExportSections`' row) and
// presents it (`DataRecoveryView`, which holds the file picker and the sheet on its `Form`). The
// writes are `ResearchDataImporter`'s; the rules are FRUSCoreKit's `ResearchImportPlan`.

// MARK: - ResearchImportRequest

/// The sheet's item: the file the reader picked, or why the picker gave none. One item carries
/// every fact the sheet reads, so nothing beside it can be stale when the sheet appears.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
struct ResearchImportRequest: Identifiable {
    /// What the picker returned.
    enum Source {
        /// The file the reader picked.
        case file(URL)
        /// The picker's failure, described.
        case problem(String)
    }

    let id = UUID()
    let source: Source
}

// MARK: - ResearchImportSheet

/// Import from JSON: reads the picked file, shows what importing it does before anything is
/// written, imports it on **Import**, and says what it did.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
struct ResearchImportSheet: View {

    let request: ResearchImportRequest

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .reading

    /// Where the sheet is.
    enum Phase {
        /// The file is being read and planned.
        case reading
        /// The file could not be read or planned; nothing was written.
        case failed(String)
        /// The report, before anything is written.
        case review(fileName: String, file: ResearchImportFile, plan: ResearchImportPlan)
        /// The import is writing.
        case importing(written: Int, total: Int)
        /// The import is done.
        case done(ResearchImportOutcome)
        /// The import stopped part-way.
        case stopped(String)
    }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            form
                .formStyle(.grouped)
            Divider()
            HStack(spacing: 12) {
                Spacer()
                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 540, idealWidth: 600, minHeight: 500, idealHeight: 660)
        .interactiveDismissDisabled(isImporting)
        .task { await read() }
        #else
        NavigationStack {
            form
                .navigationTitle(ResearchImportCopy.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .interactiveDismissDisabled(isImporting)
        .task { await read() }
        #endif
    }

    // MARK: Content

    @ViewBuilder
    private var form: some View {
        Form {
            switch phase {
            case .reading:
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(ResearchImportCopy.reading)
                            .foregroundStyle(.secondary)
                    }
                }
            case .failed(let message):
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                } header: {
                    Text(ResearchImportCopy.failedHeader)
                }
            case .review(let fileName, let file, let plan):
                ResearchImportReport(fileName: fileName, file: file, plan: plan,
                                     syncsSettings: appState.settingsSync?.isEnabled == true)
            case .importing(let written, let total):
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(written), total: Double(max(total, 1)))
                        Text(ResearchImportCopy.progress(written: written, total: total))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            case .done(let outcome):
                ResearchImportDone(outcome: outcome, syncsToICloud: appState.cloudKitSyncEnabled)
            case .stopped(let message):
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                } header: {
                    Text(ResearchImportCopy.stoppedHeader)
                }
            }
        }
    }

    // MARK: Actions

    /// Whether the import is writing, when the sheet may not be closed.
    private var isImporting: Bool {
        if case .importing = phase { return true }
        return false
    }

    /// The plan the report shows, while it waits for **Import**.
    private var pendingImport: (file: ResearchImportFile, plan: ResearchImportPlan)? {
        if case .review(_, let file, let plan) = phase { return (file, plan) }
        return nil
    }

    #if os(macOS)
    /// The Mac's buttons, at the foot of the sheet.
    @ViewBuilder
    private var actions: some View {
        switch phase {
        case .reading:
            cancelButton
        case .review:
            cancelButton
            importButton
        case .importing:
            importButton
        case .failed, .done, .stopped:
            doneButton
        }
    }
    #else
    /// iOS's buttons, in the navigation bar.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        switch phase {
        case .reading, .review:
            ToolbarItem(placement: .cancellationAction) { cancelButton }
            ToolbarItem(placement: .confirmationAction) { importButton }
        case .importing:
            ToolbarItem(placement: .confirmationAction) { importButton }
        case .failed, .done, .stopped:
            ToolbarItem(placement: .confirmationAction) { doneButton }
        }
    }
    #endif

    private var cancelButton: some View {
        Button(ResearchImportCopy.cancel, role: .cancel) { dismiss() }
            .keyboardShortcut(.cancelAction)
    }

    private var doneButton: some View {
        Button(ResearchImportCopy.done) { dismiss() }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("researchImport.done")
    }

    /// **Import**: enabled while the report waits and the plan writes something.
    private var importButton: some View {
        Button(ResearchImportCopy.importAction) {
            if let pendingImport { runImport(pendingImport.file) }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(pendingImport.map { $0.plan.report.added + $0.plan.report.replaced == 0 } ?? true)
        .accessibilityIdentifier("researchImport.import")
    }

    // MARK: Work

    /// Reads and plans the picked file. Nothing is written: the plan is made over a read of the
    /// library, after the main context's pending edits are saved.
    private func read() async {
        guard case .reading = phase else { return }
        switch request.source {
        case .problem(let message):
            phase = .failed(ResearchImportCopy.unreadable(message))
        case .file(let url):
            let read = await Task.detached(priority: .userInitiated) {
                Result { try ResearchDataImporter.readFile(at: url) }
            }.value
            do {
                let file = try read.get()
                let plan = try ResearchDataImporter.plan(file, mainContext: modelContext).plan
                phase = .review(fileName: url.lastPathComponent, file: file, plan: plan)
            } catch {
                phase = .failed(ResearchImportCopy.problem(error))
            }
        }
    }

    /// Imports the file: plans it again against the library as it is now, writes the plan in
    /// batches with the progress shown, and says what it did.
    private func runImport(_ file: ResearchImportFile) {
        phase = .importing(written: 0, total: 0)
        Task {
            do {
                let outcome = try await ResearchDataImporter.importFile(
                    file, mainContext: modelContext, pipeline: appState.indexingPipeline,
                    settingsSync: appState.settingsSync) { written, total in
                        phase = .importing(written: written, total: total)
                    }
                if outcome.reviewLedgerChanged { appState.revisionReviewToken += 1 }
                phase = .done(outcome)
            } catch {
                phase = .stopped(ResearchImportCopy.stopped(error.localizedDescription))
            }
        }
    }
}

// MARK: - ResearchImportReport

/// The report a file's plan makes before anything is written: the file, what FRUS Explorer Light's
/// key says, what becomes of each type's records, and what an earlier export did not say.
///
/// Emits sections into the sheet's `Form`, and carries no presentation or task modifier, which a
/// view of several sections would repeat on each.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
struct ResearchImportReport: View {

    let fileName: String
    let file: ResearchImportFile
    let plan: ResearchImportPlan
    /// Whether this device syncs its settings, which decides when a file's synced settings apply.
    let syncsSettings: Bool

    private var report: ResearchImportPlan.Report { plan.report }

    var body: some View {
        Section {
            LabeledContent(ResearchImportCopy.fileNameLabel, value: fileName)
            LabeledContent(ResearchImportCopy.exportedLabel,
                           value: report.exportedAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(ResearchImportCopy.versionLabel, value: "\(report.formatVersion)")
            if let project = file.envelope.exportedForProjectName, !project.isEmpty {
                LabeledContent(ResearchImportCopy.projectLabel, value: project)
            }
        } header: {
            Text(ResearchImportCopy.fileHeader)
        } footer: {
            if let footer = ResearchImportCopy.olderFileFooter(report) {
                Text(footer)
            }
        }

        if let key = report.webKey {
            Section {
                LabeledContent(ResearchImportCopy.webSummariesLabel,
                               value: ResearchImportCopy.webValue(key.includesGeneratedSummaries))
                LabeledContent(ResearchImportCopy.webCorrectionsLabel,
                               value: ResearchImportCopy.webValue(key.includesCorrections))
            } header: {
                Text(ResearchImportCopy.webHeader)
            } footer: {
                Text(ResearchImportCopy.webFooter)
            }
        }

        Section {
            if report.added + report.replaced == 0 {
                Text(ResearchImportCopy.nothingToDo)
                    .foregroundStyle(.secondary)
            }
            ForEach(report.types.filter { $0.inFile > 0 }, id: \.model) { count in
                LabeledContent(ResearchImportCopy.typeName(count.model),
                               value: ResearchImportCopy.counts(count))
            }
            LabeledContent(ResearchImportCopy.totalLabel,
                           value: ResearchImportCopy.counts(added: report.added,
                                                            replaced: report.replaced,
                                                            kept: report.kept))
                .fontWeight(.semibold)
        } header: {
            Text(ResearchImportCopy.recordsHeader)
        } footer: {
            Text(ResearchImportCopy.recordsFooter(settings: settingsLine))
        }

        if hasReadings {
            Section {
                if report.inertEntries > 0 {
                    LabeledContent(ResearchImportCopy.inertLabel, value: report.inertEntries.formatted())
                }
                if report.summariesWithoutAuthorship > 0 {
                    LabeledContent(ResearchImportCopy.noAuthorshipLabel,
                                   value: report.summariesWithoutAuthorship.formatted())
                }
                if showsHeadnoteDrafts {
                    LabeledContent(ResearchImportCopy.headnotesLabel, value: report.headnoteDrafts.formatted())
                }
                if !report.unlinkedCollections.isEmpty {
                    LabeledContent(ResearchImportCopy.unlinkedLabel,
                                   value: report.unlinkedCollections.map(\.name)
                                       .formatted(.list(type: .and)))
                }
            } header: {
                Text(ResearchImportCopy.readingsHeader)
            } footer: {
                Text(ResearchImportCopy.readingsFooter(
                    inert: report.inertEntries > 0, noAuthorship: report.summariesWithoutAuthorship > 0,
                    headnotes: showsHeadnoteDrafts, unlinked: !report.unlinkedCollections.isEmpty))
            }
        }
    }

    /// The headnote drafts are a reading only before version 7, which flags them itself.
    private var showsHeadnoteDrafts: Bool {
        report.headnoteDrafts > 0 && report.formatVersion < 7
    }

    /// Whether the report has a reading of what an earlier export did not say.
    private var hasReadings: Bool {
        report.inertEntries > 0 || report.summariesWithoutAuthorship > 0 || showsHeadnoteDrafts
            || !report.unlinkedCollections.isEmpty
    }

    /// What the import does with the file's synced settings, when it writes them.
    private var settingsLine: String? {
        let count = report.count(of: .syncedPreferences)
        guard count.added + count.replaced > 0 else { return nil }
        return syncsSettings ? ResearchImportCopy.settingsApplied : ResearchImportCopy.settingsKept
    }
}

// MARK: - ResearchImportDone

/// What an import did: the records it added and replaced and those it found already here, and what
/// an earlier export's new text made of a note's formatting or a summary's author.
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
struct ResearchImportDone: View {

    let outcome: ResearchImportOutcome
    /// Whether the library syncs through iCloud, so the import reaches the reader's other devices.
    let syncsToICloud: Bool

    var body: some View {
        Section {
            LabeledContent(ResearchImportCopy.addedLabel, value: outcome.added.formatted())
            LabeledContent(ResearchImportCopy.replacedLabel, value: outcome.replaced.formatted())
            LabeledContent(ResearchImportCopy.keptLabel, value: outcome.kept.formatted())
            if outcome.notesMadePlain > 0 {
                LabeledContent(ResearchImportCopy.plainNotesLabel, value: outcome.notesMadePlain.formatted())
            }
            if outcome.summariesMadeAIGenerated > 0 {
                LabeledContent(ResearchImportCopy.aiSummariesLabel,
                               value: outcome.summariesMadeAIGenerated.formatted())
            }
        } header: {
            Text(ResearchImportCopy.doneHeader)
        } footer: {
            Text(ResearchImportCopy.doneFooter(
                textChanged: outcome.notesMadePlain + outcome.summariesMadeAIGenerated > 0,
                syncsToICloud: syncsToICloud && outcome.added + outcome.replaced > 0))
        }
    }
}

// MARK: - ResearchImportCopy

/// Every string Import from JSON shows, each with its key and its default, in one place
/// (`Docs/EditableContent/09-Settings-and-App.md` has a block for each).
///
/// Version history:
///   1.0 — #1915 (L24): initial implementation
enum ResearchImportCopy {

    // MARK: The row

    /// The row in Data & Recovery.
    static var rowAction: String {
        String(localized: "settings.import.json.action", defaultValue: "Import from JSON…")
    }

    /// The row's footer.
    static var rowFooter: String {
        String(localized: "settings.import.json.footer",
               defaultValue: "Brings back a file from Export as JSON, written by this app on any device or by FRUS Explorer Light. Before anything is written, you see what importing it will add and replace.")
    }

    // MARK: The sheet

    /// The sheet's title.
    static var title: String {
        String(localized: "settings.import.title", defaultValue: "Import from JSON")
    }

    /// While the file is read and planned.
    static var reading: String {
        String(localized: "settings.import.reading", defaultValue: "Reading the file…")
    }

    static var importAction: String {
        String(localized: "settings.import.action.import", defaultValue: "Import")
    }

    static var cancel: String {
        String(localized: "settings.import.action.cancel", defaultValue: "Cancel")
    }

    static var done: String {
        String(localized: "settings.import.action.done", defaultValue: "Done")
    }

    // MARK: The file

    static var fileHeader: String {
        String(localized: "settings.import.file.header", defaultValue: "File")
    }

    static var fileNameLabel: String {
        String(localized: "settings.import.file.name", defaultValue: "Name")
    }

    static var exportedLabel: String {
        String(localized: "settings.import.file.exported", defaultValue: "Exported")
    }

    static var versionLabel: String {
        String(localized: "settings.import.file.version", defaultValue: "Format version")
    }

    static var projectLabel: String {
        String(localized: "settings.import.file.project", defaultValue: "Exported under the project")
    }

    /// Under the file, for a file of an earlier format version: what it cannot carry, of the fields
    /// and of the types, and what the import does about it. `nil` for a file of the current version.
    static func olderFileFooter(_ report: ResearchImportPlan.Report) -> String? {
        var lines: [String] = []
        let fields = report.fieldsNotCarried
        if !fields.isEmpty {
            let list = fields.map(fieldsName).formatted(.list(type: .and))
            lines.append(String(localized: "settings.import.fieldsNotCarried",
                                defaultValue: "This file is from an earlier version of the export, which cannot carry \(list). A record the import replaces keeps them as they are here, and a new record takes the app’s defaults."))
        }
        let types = report.types.filter { !$0.carried }.map { typeName($0.model) }
        if !types.isEmpty {
            let list = types.formatted(.list(type: .and))
            lines.append(String(localized: "settings.import.typesNotCarried",
                                defaultValue: "An export of this version cannot hold \(list), so the file brings none."))
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    /// What an earlier export cannot carry of a type it holds.
    static func fieldsName(_ fields: ResearchImportPlan.Fields) -> String {
        switch fields {
        case .noteFormatting:
            return String(localized: "settings.import.field.noteFormatting",
                          defaultValue: "a note’s formatting")
        case .collectionSettings:
            return String(localized: "settings.import.field.collectionSettings",
                          defaultValue: "a collection’s front matter and export settings")
        case .collectionEntryContent:
            return String(localized: "settings.import.field.collectionEntryContent",
                          defaultValue: "a collection entry’s kind, text and own settings")
        case .projectFocus:
            return String(localized: "settings.import.field.projectFocus",
                          defaultValue: "a project’s focus tags and Suggested Next weights")
        case .searchCaptureProvenance:
            return String(localized: "settings.import.field.searchCaptureProvenance",
                          defaultValue: "a recorded search’s scope and counts")
        case .summaryAuthorship:
            return String(localized: "settings.import.field.summaryAuthorship",
                          defaultValue: "who wrote a summary")
        // L43: the fields of format version 8.
        case .collectionCitationStyle:
            return String(localized: "settings.import.field.collectionCitationStyle",
                          defaultValue: "a collection’s citation style")
        case .collectionOpening:
            return String(localized: "settings.import.field.collectionOpening",
                          defaultValue: "which line leads a collection’s documents")
        case .collectionWording:
            return String(localized: "settings.import.field.collectionWording",
                          defaultValue: "a collection’s own words for its labels")
        case .collectionSeeAlso:
            return String(localized: "settings.import.field.collectionSeeAlso",
                          defaultValue: "a collection’s See also setting")
        case .entryDateLine:
            return String(localized: "settings.import.field.entryDateLine",
                          defaultValue: "a document’s date line in a collection")
        case .sectionHeadnoteDefault:
            return String(localized: "settings.import.field.sectionHeadnoteDefault",
                          defaultValue: "a section’s headnote setting")
        case .headnoteWriter:
            return String(localized: "settings.import.field.headnoteWriter",
                          defaultValue: "who wrote a headnote")
        }
    }

    // MARK: FRUS Explorer Light's key

    static var webHeader: String {
        String(localized: "settings.import.web.header", defaultValue: "Made by FRUS Explorer Light")
    }

    static var webSummariesLabel: String {
        String(localized: "settings.import.web.summaries", defaultValue: "Summaries")
    }

    static var webCorrectionsLabel: String {
        String(localized: "settings.import.web.corrections", defaultValue: "Corrections")
    }

    /// What the key says of one choice.
    static func webValue(_ included: Bool?) -> String {
        switch included {
        case true?:
            return String(localized: "settings.import.web.included", defaultValue: "Included")
        case false?:
            return String(localized: "settings.import.web.leftOut", defaultValue: "Left out")
        case nil:
            return String(localized: "settings.import.web.unsaid", defaultValue: "Not said")
        }
    }

    static var webFooter: String {
        String(localized: "settings.import.web.footer",
               defaultValue: "FRUS Explorer Light says what its export leaves out by choice. Its corrections come only in a curator’s export.")
    }

    // MARK: The records

    static var recordsHeader: String {
        String(localized: "settings.import.records.header", defaultValue: "What the Import Does")
    }

    static var totalLabel: String {
        String(localized: "settings.import.total", defaultValue: "In all")
    }

    static var nothingToDo: String {
        String(localized: "settings.import.nothingToDo",
               defaultValue: "This library already holds every record in the file, as new or newer, so importing it would change nothing.")
    }

    /// Under the records: newer wins, nothing is deleted and a deleted record comes back, and, when
    /// the import writes synced settings, when this device takes them.
    static func recordsFooter(settings: String?) -> String {
        let rule = String(localized: "settings.import.records.footer",
                          defaultValue: "A record already here is replaced only by a newer copy, and only in what this file’s version can carry. Nothing here is deleted, so a record you have deleted since this file was made comes back.")
        guard let settings else { return rule }
        return "\(rule) \(settings)"
    }

    /// The file's synced settings, on a device that syncs its settings.
    static var settingsApplied: String {
        String(localized: "settings.import.settings.applied",
               defaultValue: "This device takes the file’s synced settings as they are imported, since Sync Settings Across Devices is on.")
    }

    /// The file's synced settings, on a device that does not.
    static var settingsKept: String {
        String(localized: "settings.import.settings.kept",
               defaultValue: "The file’s synced settings are kept with your library. This device takes them when Sync Settings Across Devices is turned on.")
    }

    /// One type's count, its non-zero parts.
    static func counts(_ count: ResearchImportPlan.TypeCount) -> String {
        var parts: [String] = []
        if count.added > 0 { parts.append(added(count.added)) }
        if count.replaced > 0 { parts.append(replaced(count.replaced)) }
        if count.kept > 0 { parts.append(kept(count.kept)) }
        if count.setAside > 0 {
            parts.append(String(localized: "settings.import.count.setAside",
                                defaultValue: "\(count.setAside) set aside"))
        }
        if count.repeated > 0 {
            parts.append(String(localized: "settings.import.count.repeated",
                                defaultValue: "\(count.repeated) repeated"))
        }
        return parts.formatted(.list(type: .and))
    }

    /// The whole file's count, every part.
    static func counts(added: Int, replaced: Int, kept: Int) -> String {
        [Self.added(added), Self.replaced(replaced), Self.kept(kept)].formatted(.list(type: .and))
    }

    private static func added(_ count: Int) -> String {
        String(localized: "settings.import.count.add", defaultValue: "\(count) to add")
    }

    private static func replaced(_ count: Int) -> String {
        String(localized: "settings.import.count.replace", defaultValue: "\(count) to replace")
    }

    private static func kept(_ count: Int) -> String {
        String(localized: "settings.import.count.keep", defaultValue: "\(count) already here")
    }

    /// A model type, as the report names it: the words of Data & Recovery's **Contents** where it
    /// has a row for the type.
    static func typeName(_ model: ResearchImportPlan.ModelType) -> String {
        switch model {
        case .researchNote:
            return String(localized: "settings.import.type.researchNote", defaultValue: "Research Notes")
        case .userTag:
            return String(localized: "settings.import.type.userTag", defaultValue: "Tags")
        case .documentTagAssignment:
            return String(localized: "settings.import.type.documentTagAssignment", defaultValue: "Tag Assignments")
        case .documentHighlight:
            return String(localized: "settings.import.type.documentHighlight", defaultValue: "Highlights")
        case .collection:
            return String(localized: "settings.import.type.collection", defaultValue: "Collections")
        case .collectionEntry:
            return String(localized: "settings.import.type.collectionEntry", defaultValue: "Collection Entries")
        case .summarizationPrompt:
            return String(localized: "settings.import.type.summarizationPrompt", defaultValue: "Custom Prompts")
        case .project:
            return String(localized: "settings.import.type.project", defaultValue: "Projects")
        case .generatedSummary:
            return String(localized: "settings.import.type.generatedSummary", defaultValue: "Summaries")
        case .readingHistoryEntry:
            return String(localized: "settings.import.type.readingHistoryEntry", defaultValue: "Documents Visited")
        case .searchHistoryEntry:
            return String(localized: "settings.import.type.searchHistoryEntry", defaultValue: "Searches Executed")
        case .exportHistoryEntry:
            return String(localized: "settings.import.type.exportHistoryEntry", defaultValue: "Collections Exported")
        case .archiveVisitPlan:
            return String(localized: "settings.import.type.archiveVisitPlan", defaultValue: "Archives Visits")
        case .archiveVisitDocument:
            return String(localized: "settings.import.type.archiveVisitDocument", defaultValue: "Archives Visit Documents")
        case .archiveVisitTarget:
            return String(localized: "settings.import.type.archiveVisitTarget", defaultValue: "Archives Visit Targets")
        case .savedSearch:
            return String(localized: "settings.import.type.savedSearch", defaultValue: "Saved Searches")
        case .workingCorpus:
            return String(localized: "settings.import.type.workingCorpus", defaultValue: "Working Corpora")
        case .customVolumeScope:
            return String(localized: "settings.import.type.customVolumeScope", defaultValue: "Volume Scopes")
        case .documentClassificationOverride:
            return String(localized: "settings.import.type.documentClassificationOverride", defaultValue: "Classification Corrections")
        case .personClusterOverride:
            return String(localized: "settings.import.type.personClusterOverride", defaultValue: "Person Corrections")
        case .annotationReview:
            return String(localized: "settings.import.type.annotationReview", defaultValue: "Reviewed Changes")
        case .projectLeadEntry:
            return String(localized: "settings.import.type.projectLeadEntry", defaultValue: "Suggested Next Leads")
        case .syncedPreferences:
            return String(localized: "settings.import.type.syncedPreferences", defaultValue: "Synced Settings")
        }
    }

    // MARK: What an earlier export did not say

    static var readingsHeader: String {
        String(localized: "settings.import.readings.header", defaultValue: "From an Earlier Export")
    }

    static var inertLabel: String {
        String(localized: "settings.import.inert", defaultValue: "Collection entries with no document")
    }

    static var noAuthorshipLabel: String {
        String(localized: "settings.import.noAuthorship", defaultValue: "Summaries that name no author")
    }

    static var headnotesLabel: String {
        String(localized: "settings.import.headnotes", defaultValue: "Headnote drafts")
    }

    static var unlinkedLabel: String {
        String(localized: "settings.import.unlinked", defaultValue: "Collections whose saved search is not here")
    }

    /// Under the readings: a sentence for each row the section shows.
    static func readingsFooter(inert: Bool, noAuthorship: Bool, headnotes: Bool, unlinked: Bool) -> String {
        var lines: [String] = []
        if inert {
            lines.append(String(localized: "settings.import.inert.detail",
                                defaultValue: "An earlier export wrote a heading, a prose block and a section block alike, without saying which, so these come in as entries the collection editor leaves untouched and no export prints."))
        }
        if noAuthorship {
            lines.append(String(localized: "settings.import.noAuthorship.detail",
                                defaultValue: "A summary that names no author comes in as AI-generated, as the app reads any such summary."))
        }
        if headnotes {
            lines.append(String(localized: "settings.import.headnotes.detail",
                                defaultValue: "A headnote draft is a summary a collection keeps for a headnote, which no list or search shows; an earlier export marks it by its prompt."))
        }
        if unlinked {
            lines.append(String(localized: "settings.import.unlinked.detail",
                                defaultValue: "A collection keeps its link to a saved search this library does not hold, and shows it as it shows a link to a deleted search."))
        }
        return lines.joined(separator: " ")
    }

    // MARK: Importing and done

    /// The progress line, its noun agreeing with the records to write (`CountCopy`).
    static func progress(written: Int, total: Int) -> String {
        CountCopy.phrase(
            total,
            one: String(localized: "settings.import.progress.one %@ %@",
                        defaultValue: "Importing %2$@ of %1$@ record…"),
            many: String(localized: "settings.import.progress.many %@ %@",
                         defaultValue: "Importing %2$@ of %1$@ records…"),
            then: [written.formatted(.number)])
    }

    static var doneHeader: String {
        String(localized: "settings.import.done.header", defaultValue: "Imported")
    }

    static var addedLabel: String {
        String(localized: "settings.import.done.added", defaultValue: "Added")
    }

    static var replacedLabel: String {
        String(localized: "settings.import.done.replaced", defaultValue: "Replaced")
    }

    static var keptLabel: String {
        String(localized: "settings.import.done.kept", defaultValue: "Already here")
    }

    static var plainNotesLabel: String {
        String(localized: "settings.import.done.plainNotes", defaultValue: "Notes now in plain text")
    }

    static var aiSummariesLabel: String {
        String(localized: "settings.import.done.aiSummaries", defaultValue: "Summaries now AI-generated")
    }

    /// Under the done line: what an earlier export's new text did, and that the records sync.
    static func doneFooter(textChanged: Bool, syncsToICloud: Bool) -> String {
        var lines: [String] = []
        if textChanged {
            lines.append(String(localized: "settings.import.done.textChanged",
                                defaultValue: "An earlier export cannot carry a note’s formatting or say who wrote a summary, so a note or summary whose text it replaced reads as plain text or as AI-generated."))
        }
        if syncsToICloud {
            lines.append(String(localized: "settings.import.done.sync",
                                defaultValue: "The imported records reach your other devices through iCloud, as your own changes do."))
        }
        return lines.joined(separator: " ")
    }

    // MARK: Problems

    static var failedHeader: String {
        String(localized: "settings.import.failed.header", defaultValue: "Can’t Import This File")
    }

    static var stoppedHeader: String {
        String(localized: "settings.import.stopped.header", defaultValue: "Import Stopped")
    }

    /// Why a file could not be read or planned.
    static func problem(_ error: Error) -> String {
        switch error {
        case ResearchImportFile.FormatError.newerFormatVersion(let version):
            return String(localized: "settings.import.error.newer",
                          defaultValue: "This file was exported by a newer version of FRUS Explorer, at format version \(version). Update the app to import it.")
        case ResearchImportFile.FormatError.unknownFormatVersion(let version):
            return String(localized: "settings.import.error.unknownVersion",
                          defaultValue: "This file names format version \(version), which no version of FRUS Explorer has written.")
        case ResearchDataImporter.ReadError.unreadable(let detail):
            return unreadable(detail)
        case is DecodingError:
            return String(localized: "settings.import.error.notAnExport",
                          defaultValue: "This file is not a research export from Export as JSON, or it is damaged.")
        default:
            return unreadable(error.localizedDescription)
        }
    }

    /// A file that could not be opened.
    static func unreadable(_ detail: String) -> String {
        String(localized: "settings.import.error.unreadable", defaultValue: "The file could not be read: \(detail)")
    }

    /// An import that stopped part-way.
    static func stopped(_ detail: String) -> String {
        String(localized: "settings.import.error.stopped",
               defaultValue: "The import stopped: \(detail) What it saved before it stopped is kept, and importing the file again adds the rest.")
    }
}
