// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// The collection's settings in two steps (L44; the Collections design's §4.3 and §5.2, decision 153): *Documents*, how
// each document is presented, then *Apparatus*, what is added around the documents. The settings open on ten controls
// (a row for each step, the title page's five fields, *Citation style*, *Wording* and the linked saved search), and
// each step holds its templates and, under them, its own controls. The views here are placed by the iPhone's pushed
// Collection settings, the iPad's settings sheet and the Mac's ⚙ popover; the Mac's New Collection form takes the two
// steps as menus (`CollectionDocumentsMenu`, `CollectionApparatusMenu`).
//
// Version history of the file, which held `CollectionCompositionRows` and `CollectionAttributesRows` until L44:
//   1.0 — Collections rework Phase 1a: composition moved out of the ephemeral export sheet
//   1.1 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
//   1.2 — Authoring Phase 5: the footnote tri-state picker replaced by two toggles bound
//          to `effectiveIncludeFootnotes`/`effectiveIncludeSourceNote`
//   1.3 — Composer redesign Phase 1: three labeled `Section`s (Document content / Your annotations / Analysis &
//          apparatus)
//   1.4 — 2026-11-18 (L25, decision 139): six templates in place of four
//   1.5 — L43: the collection's own facts, each a plain control that L44 then trims
//   1.6 — L58: the Note on the Text's line in Analysis & apparatus
//   2.0 — L44: the two steps. `CollectionCompositionRows`, whose one tap overwrote eight settings with no line and no
//          way back, is step 1 (`CollectionDocumentsStep`) and step 2 (`CollectionApparatusStep`) behind their rows
//          (`CollectionSettingsSteps`); `CollectionAttributesRows`, which put the collection's description, subtitle,
//          author line and three switches in a section's sheet under other names, is gone with that sheet's copy of
//          them; the template cards' type follows the reader's text size and goes to one column at the accessibility
//          sizes (#2006); the cards are a grid of two in the iPad's sheet as on the Mac (`collectionTemplatesInGrid`)

// MARK: - collectionTemplatesInGrid

extension EnvironmentValues {
    /// Whether step 1 draws its templates as the design's grid of two (§5.4: on the iPad as on the Mac), set by an
    /// editor of regular width where it shows the settings in a sheet. The sheet's own size class is compact on the
    /// iPad, so the step cannot read the grid from it (L44).
    @Entry var collectionTemplatesInGrid: Bool = false
}

// MARK: - CollectionSettingsPresentation

/// How the collection's settings open their two steps, *Wording*, and a setting's list of the rows that set their own
/// (L44; the design's §5.4).
enum CollectionSettingsPresentation {
    /// Each opens as a screen pushed in the settings' own stack: the iPhone's pushed Collection settings and the iPad's
    /// settings sheet.
    case pushed
    /// Each opens in place, under its row: the Mac's ⚙ popover, which has no stack to push in.
    case inPlace
}

// MARK: - CollectionSettingsHost

/// What the collection's settings need of the editor that shows them (L44): a row's name, its way of changing the
/// apparatus rows through its own outline, which it keeps in step with its rows (#1416), and the three export switches
/// it commits as it commits its other fields (#1415). The settings read the rows themselves, from the model
/// (`CollectionApparatusRows.liveOutline`), so a step pushed in a stack reads them live.
struct CollectionSettingsHost {
    /// A row's name in the list of the rows that set their own: a section's heading, a document's title or heading.
    var name: (CollectionEntry) -> String
    /// Applies a whole apparatus through the host's entry management, renumbers and saves, and returns what *Undo*
    /// needs (`CollectionApparatusRows.apply`).
    var applyApparatus: (CollectionApparatusSettings) -> CollectionApparatusRows.Undo
    /// Puts an apparatus change back (`CollectionApparatusRows.undo`), renumbers and saves.
    var undoApparatus: (CollectionApparatusRows.Undo) -> Void
    /// *Include colophon*, under step 2 (decision 170), committed by the host.
    var colophon: Binding<Bool>
    /// *Stamp active project on export*, under step 2.
    var projectStamp: Binding<Bool>
    /// *Append the query log*, under step 2.
    var queryLog: Binding<Bool>
}

// MARK: - CollectionSettingsSteps

/// The two step rows of the collection's settings (L44; the design's §5.2): *1 · Documents*, which says what is set
/// (*Like Full text as printed · 2 differ*), and *2 · Apparatus*, which lists what is added. Pushed, each row opens its
/// step as a screen; in place, under the rows.
///
/// **Step 2's row is two controls** (the third review's J30): the row, which opens step 2, and under it, where the
/// documents are a template's and the collection lacks some of its suggested set, a button that adds that set and
/// names every block it adds (J14). The tap only adds, so it takes away nothing the author placed; its line and *Undo*
/// then stand where the button stood, which is where the change shows: the row above lists what is added. VoiceOver
/// reads the row and the button as two elements, and a keyboard reaches each in turn.
///
/// Version history:
///   1.0 — L44: initial implementation
struct CollectionSettingsSteps: View {
    /// The collection whose settings these are.
    @Bindable var collection: Collection
    /// The editor showing them.
    let host: CollectionSettingsHost
    /// How the steps open.
    let presentation: CollectionSettingsPresentation

    /// The step open in place, on the Mac.
    @State private var openStep: Step?
    /// The one tap's *Undo*, while the screen that took it is open.
    @State private var offerUndo: CollectionApparatusRows.Undo?

    /// One of the two steps.
    enum Step {
        /// Step 1, Documents.
        case documents
        /// Step 2, Apparatus.
        case apparatus
    }

    var body: some View {
        let documents = CollectionDocumentsState(collection.documentSettings)
        let apparatus = CollectionApparatusRows.settings(of: collection, outline: CollectionApparatusRows.liveOutline(of: collection))
        Section {
            stepRow(.documents, number: 1, title: CollectionSettingsSteps.documentsTitle,
                    value: documents.summary, identifier: "collection.settings.documents.row")
            stepRow(.apparatus, number: 2, title: CollectionSettingsSteps.apparatusTitle,
                    value: apparatus.summary, identifier: "collection.settings.apparatus.row")
            if let offerUndo {
                CollectionChangeLine(sentence: offerUndo.change.sentence, identifier: "collection.settings.offer.change") {
                    host.undoApparatus(offerUndo)
                    self.offerUndo = nil
                }
            } else if let offer = CollectionApparatusSettings.offer(documents: collection.documentSettings,
                                                                    apparatus: apparatus) {
                Button {
                    offerUndo = host.applyApparatus(offer.adding)
                } label: {
                    Label(CollectionApparatusChange(from: apparatus, to: offer.adding).addLabel,
                          systemImage: "plus.circle")
                }
                .accessibilityHint(String(format: String(localized: "collection.settings.offer.hint %@",
                                                         defaultValue: "Suggested for %@. Adds and removes nothing else."),
                                          offer.preset.displayName))
                .accessibilityIdentifier("collection.settings.offer")
            }
        } header: {
            Text(String(localized: "collection.settings.steps.header", defaultValue: "Template"))
        } footer: {
            Text(String(localized: "collection.settings.steps.footer",
                        defaultValue: "Choose how each document is presented, then what is added around the documents. Each step can be opened by itself."))
        }
        if presentation == .inPlace, let openStep {
            switch openStep {
            case .documents:
                CollectionDocumentsStep(collection: collection, host: host, presentation: .inPlace,
                                        onNext: { self.openStep = .apparatus })
            case .apparatus:
                CollectionApparatusStep(collection: collection, host: host, presentation: .inPlace)
            }
        }
    }

    /// The step's name: *Documents*.
    static var documentsTitle: String {
        String(localized: "collection.settings.documents", defaultValue: "Documents")
    }

    /// The step's name: *Apparatus*, the editor's own word for its blocks' menu (the design's §4.6).
    static var apparatusTitle: String {
        String(localized: "collection.settings.apparatus", defaultValue: "Apparatus")
    }

    /// One step's row: its number and name over what it holds. Pushed, a link to the step's screen; in place, a button
    /// that opens the step under the rows, and closes it.
    @ViewBuilder
    private func stepRow(_ step: Step, number: Int, title: String, value: String, identifier: String) -> some View {
        let label = VStack(alignment: .leading, spacing: 2) {
            Text(String(format: String(localized: "collection.settings.step %lld %@", defaultValue: "%lld · %@"),
                        Int64(number), title))
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        switch presentation {
        case .pushed:
            NavigationLink {
                stepScreen(step)
            } label: {
                label
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: String(localized: "collection.settings.step.accessibility %lld %@",
                                                      defaultValue: "Step %lld, %@"), Int64(number), title))
            .accessibilityValue(value)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(identifier)
        case .inPlace:
            Button {
                openStep = openStep == step ? nil : step
            } label: {
                HStack {
                    label
                    Spacer(minLength: 8)
                    Image(systemName: openStep == step ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: String(localized: "collection.settings.step.accessibility %lld %@",
                                                      defaultValue: "Step %lld, %@"), Int64(number), title))
            .accessibilityValue(value)
            .accessibilityAddTraits(openStep == step ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier(identifier)
        }
    }

    /// A step's pushed screen.
    @ViewBuilder
    private func stepScreen(_ step: Step) -> some View {
        switch step {
        case .documents:
            CollectionStepScreen(title: Self.documentsTitle) { scroll in
                CollectionDocumentsStep(collection: collection, host: host, presentation: .pushed, scroll: scroll)
            }
        case .apparatus:
            CollectionStepScreen(title: Self.apparatusTitle) { scroll in
                CollectionApparatusStep(collection: collection, host: host, presentation: .pushed, scroll: scroll)
            }
        }
    }
}

// MARK: - CollectionStepScreen

/// A step's screen, pushed in the settings' own stack (L44): its sections in a `Form` that can bring a line into view,
/// so that the line a choice writes, and its *Undo*, are in view where the choice was made at every text size (the
/// third review's J17).
struct CollectionStepScreen<Content: View>: View {
    /// The screen's title: the step's name.
    let title: String
    /// The step's sections, handed the call that brings a row into view by its id.
    @ViewBuilder let content: (_ scroll: @escaping (String) -> Void) -> Content

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                content { id in
                    // A turn later, so the row the choice adds is in the list to scroll to.
                    Task { @MainActor in withAnimation { proxy.scrollTo(id) } }
                }
            }
            .formStyle(.grouped)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - CollectionChangeLine

/// The line a choice writes where it was made, and its *Undo* (L44; the design's §4.3): what changed, old to new, for as
/// long as the screen is open. VoiceOver says it when it appears, and *Undo* is the element after it (the design's §9).
struct CollectionChangeLine: View {
    /// What changed.
    let sentence: String
    /// The line's identifier, for the UI suites.
    let identifier: String
    /// Puts the change back.
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sentence)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            Button(String(localized: "collection.settings.undo", defaultValue: "Undo"), systemImage: "arrow.uturn.backward",
                   action: onUndo)
                .accessibilityIdentifier("\(identifier).undo")
        }
        .padding(.vertical, 2)
        .onAppear { AccessibilityNotification.Announcement(sentence).post() }
        .onChange(of: sentence) { _, new in AccessibilityNotification.Announcement(new).post() }
    }
}

// MARK: - CollectionDocumentsStep

/// Step 1, *Documents* (L44; the design's §4.3): the six document templates and, under them, the seven settings a
/// template sets and the summary prompt, with *See also*, which no template sets. Choosing a template writes the seven,
/// in view, and a line under the card says what changed, with *Undo*. A setting a section or a document sets for itself
/// says how many do, and the count opens the list of them, with *Clear*. It ends with *Next: Apparatus*.
///
/// The templates are a grid of two on the iPad and the Mac and rows on the iPhone, each card with its line (the design's
/// §5.4): a grid where the editor is of regular width (`collectionTemplatesInGrid`, since the iPad's sheet is compact
/// itself), and one column at the accessibility sizes, whose type follows the reader's text size (#2006).
///
/// Version history:
///   1.0 — L44: initial implementation, from `CollectionCompositionRows`' preset grid and its first two sections
struct CollectionDocumentsStep: View {
    /// The collection whose settings these are.
    @Bindable var collection: Collection
    /// The editor showing them.
    let host: CollectionSettingsHost
    /// How *Next: Apparatus* and the counts' lists open.
    let presentation: CollectionSettingsPresentation
    /// In place: opens step 2 under the rows.
    var onNext: (() -> Void)? = nil
    /// Pushed: brings a row into view by its id.
    var scroll: ((String) -> Void)? = nil

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.collectionTemplatesInGrid) private var templatesInGrid
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// The last template chosen while the screen is open, and the fields before it, for the line and *Undo*.
    @State private var lastChoice: Choice?
    /// In place: the setting whose list of the rows that set their own is open.
    @State private var openOwnList: CollectionSetting?

    /// A template chosen, and what it changed.
    private struct Choice {
        /// The template.
        let preset: CollectionPreset
        /// The stored fields before it, which *Undo* writes back.
        let before: Collection.DocumentFields
        /// What changed.
        let sentence: String
    }

    /// The id of the line a choice writes, which the screen brings into view.
    static let changeLineID = "collection.documents.change"

    var body: some View {
        let settings = collection.documentSettings
        let state = CollectionDocumentsState(settings)
        Section {
            ForEach(Array(templateRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(row) { preset in
                        CollectionTemplateCard(preset: preset, isInForce: state == .template(preset)) {
                            choose(preset)
                        }
                    }
                    if row.count < columns {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
                if let lastChoice, row.contains(lastChoice.preset) {
                    CollectionChangeLine(sentence: lastChoice.sentence, identifier: Self.changeLineID) {
                        collection.documentFields = lastChoice.before
                        try? collection.modelContext?.save()
                        self.lastChoice = nil
                    }
                    .id(Self.changeLineID)
                }
            }
            if lastChoice == nil, let line = state.differencesSentence(settings) {
                Text(line)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("collection.documents.differences")
            }
        } header: {
            Text(String(localized: "collection.documents.templates.header", defaultValue: "Templates"))
        } footer: {
            Text(String(localized: "collection.documents.templates.footer",
                        defaultValue: "A template sets the seven settings below and nothing else: not the apparatus, nor what a section or a document sets for itself."))
        }

        Section {
            Picker(CollectionSetting.opening.displayName, selection: opening) {
                ForEach([CollectionDocumentPlan.Opening.volumeHeading, .citation], id: \.self) {
                    Text(CollectionDocumentSettings.openingName($0)).tag($0)
                }
            }
            .accessibilityIdentifier("composition.opening.picker")

            Picker(CollectionSetting.bodyDepth.displayName, selection: bodyDepth) {
                ForEach(bodyDepthOptions) { Text($0.displayName).tag($0) }
            }
            ownCount(.bodyDepth)

            if bodyDepth.wrappedValue == .summaryOnly {
                Picker(CollectionSetting.summaryPrompt.displayName,
                       selection: Binding(get: { collection.summaryPromptId },
                                          set: { collection.summaryPromptId = $0 })) {
                    Text(String(localized: "composition.summaryPrompt.none", defaultValue: "Select…"))
                        .tag(UUID?.none)
                    ForEach(allPrompts) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Text(String(localized: "composition.summaryPrompt.hint",
                            defaultValue: "Summaries are generated on demand for documents that don’t already have one for this prompt. Requires Apple Intelligence."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ownCount(.summaryPrompt)
            }

            // Phase 5: the footnote tri-state picker became two independent toggles, so "all footnotes AND the source
            // note" is expressible.
            Toggle(CollectionSetting.footnotes.displayName, isOn: Binding(
                get: { collection.effectiveIncludeFootnotes }, set: { collection.effectiveIncludeFootnotes = $0 }))
            ownCount(.footnotes)

            Toggle(CollectionSetting.sourceNote.displayName, isOn: Binding(
                get: { collection.effectiveIncludeSourceNote }, set: { collection.effectiveIncludeSourceNote = $0 }))
            ownCount(.sourceNote)

            // L43: See also for the collection (decision 164's sixth candidate), which no template sets.
            Toggle(isOn: $collection.defaultIncludeRelatedDocuments) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CollectionSetting.seeAlso.displayName)
                    Text(String(localized: "composition.seeAlso.subtitle",
                                defaultValue: "Under each document, the documents it cites that are also in this collection."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("composition.seeAlso.toggle")
            ownCount(.seeAlso)
        } header: {
            Text(String(localized: "composition.group.documentContent", defaultValue: "Document content"))
        }

        Section {
            Toggle(CollectionSetting.notes.displayName, isOn: $collection.includeNotes)
            ownCount(.notes)

            Toggle(CollectionSetting.highlights.displayName, isOn: $collection.applyHighlights)
                .disabled(bodyDepth.wrappedValue != .full)
            ownCount(.highlights)

            // Documents at Follow inherit this; a document's headnote card sets its own.
            Toggle(CollectionSetting.headnotes.displayName, isOn: $collection.defaultIncludeHeadnote)
            ownCount(.headnotes)
        } header: {
            Text(String(localized: "composition.group.annotations", defaultValue: "Your annotations"))
        }

        Section {
            switch presentation {
            case .pushed:
                NavigationLink {
                    CollectionStepScreen(title: CollectionSettingsSteps.apparatusTitle) { scroll in
                        CollectionApparatusStep(collection: collection, host: host, presentation: .pushed, scroll: scroll)
                    }
                } label: {
                    Text(String(localized: "collection.documents.next", defaultValue: "Next: Apparatus"))
                }
                .accessibilityIdentifier("collection.documents.next")
            case .inPlace:
                Button(String(localized: "collection.documents.next", defaultValue: "Next: Apparatus")) {
                    onNext?()
                }
                .accessibilityIdentifier("collection.documents.next")
            }
        }
    }

    // MARK: Choosing a template

    /// Writes the template's seven, keeps what was there for *Undo*, and brings the line into view.
    private func choose(_ preset: CollectionPreset) {
        let before = collection.documentFields
        let old = collection.documentSettings
        collection.applyDocuments(preset.documents)
        try? collection.modelContext?.save()
        lastChoice = Choice(preset: preset, before: before, sentence: old.changeSentence(to: preset.documents))
        scroll?(Self.changeLineID)
    }

    /// How many cards a row holds: two at regular width, one at compact width and at the accessibility sizes.
    private var columns: Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        #if os(iOS)
        return templatesInGrid || horizontalSizeClass == .regular ? 2 : 1
        #else
        return 2
        #endif
    }

    /// The templates in the grid's rows, in `CollectionPreset.allCases`' order.
    private var templateRows: [[CollectionPreset]] {
        let all = CollectionPreset.allCases
        return stride(from: 0, to: all.count, by: columns).map { Array(all[$0..<min($0 + columns, all.count)]) }
    }

    // MARK: Bindings

    private var bodyDepth: Binding<CollectionBodyDepth> {
        Binding(get: { CollectionBodyDepth(rawValue: collection.defaultBodyDepth) ?? .full },
                set: { collection.defaultBodyDepth = $0.rawValue })
    }

    /// Body-depth choices: those available on this device, plus the stored value even where it is not otherwise
    /// offered here. A `"summaryOnly"` collection synced from a device with Apple Intelligence must still show a chosen
    /// row, and stay editable, on a device without it.
    private var bodyDepthOptions: [CollectionBodyDepth] {
        let available = CollectionBodyDepth.available
        let current = bodyDepth.wrappedValue
        return available.contains(current) ? available : available + [current]
    }

    /// Which line leads a document with no title of the author's (L43): the citation, which an unset collection's reads
    /// as, or the volume's heading.
    private var opening: Binding<CollectionDocumentPlan.Opening> {
        Binding(get: { collection.opening == CollectionDocumentPlan.Opening.volumeHeading.rawValue
                        ? .volumeHeading : .citation },
                set: { collection.opening = $0.rawValue })
    }

    // MARK: n set their own

    /// *2 set their own*, under a setting some of the collection's rows set for themselves: a button with that name,
    /// which opens the list of them (the design's §4.2). Nothing where no row sets its own.
    @ViewBuilder
    private func ownCount(_ setting: CollectionSetting) -> some View {
        let rows = CollectionOwnSettings.rows(setting: setting, in: CollectionApparatusRows.liveOutline(of: collection))
        if !rows.isEmpty {
            let phrase = CollectionOwnSettings.countPhrase(rows.count)
            switch presentation {
            case .pushed:
                NavigationLink {
                    Form {
                        CollectionOwnSettingsList(collection: collection, setting: setting, host: host)
                    }
                    .formStyle(.grouped)
                    .navigationTitle(setting.displayName)
                } label: {
                    Text(phrase).font(.callout).foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(phrase)
                .accessibilityHint(String(format: String(localized: "collection.setting.ownCount.hint %@",
                                                         defaultValue: "Lists the sections and documents that set %@ for themselves."),
                                          setting.displayName))
                .accessibilityIdentifier("collection.setting.\(setting.rawValue).own")
            case .inPlace:
                Button(phrase) {
                    openOwnList = openOwnList == setting ? nil : setting
                }
                .font(.callout)
                .accessibilityIdentifier("collection.setting.\(setting.rawValue).own")
                if openOwnList == setting {
                    CollectionOwnSettingsList(collection: collection, setting: setting, host: host)
                }
            }
        }
    }
}

// MARK: - CollectionTemplateCard

/// One document template's card (L44): its name, its line of what the documents print, and what it needs, in text
/// styles that follow the reader's text size (#2006, which found them fixed at 14, 11.5, 13 and 10 points), drawn chosen
/// while the template is in force.
private struct CollectionTemplateCard: View {
    /// The template.
    let preset: CollectionPreset
    /// Whether its seven settings are the collection's.
    let isInForce: Bool
    /// Chooses it.
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isInForce ? Color.accentColor : .primary)
                Text(preset.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let needs = preset.needs {
                    Text(needs)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(isInForce ? Color.accentColor.opacity(0.07) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isInForce ? Color.accentColor : Color.secondary.opacity(0.25),
                              lineWidth: isInForce ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preset.displayName)
        .accessibilityValue(isInForce
            ? String(localized: "composition.presets.active", defaultValue: "Active")
            : [preset.subtitle, preset.needs].compactMap { $0 }.joined(separator: ". "))
        .accessibilityHint(String(localized: "collection.template.hint",
                                  defaultValue: "Sets the seven settings below. Undo stays offered while this screen is open."))
        .accessibilityAddTraits(isInForce ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("collection.template.\(preset.rawValue)")
    }
}

// MARK: - CollectionOwnSettingsList

/// The rows of a collection that set one setting for themselves (L44; the design's §4.2), each with its value, and
/// *Clear*, which returns the ones chosen to following: the way back for many documents at once.
struct CollectionOwnSettingsList: View {
    /// The collection whose rows these are.
    let collection: Collection
    /// The setting.
    let setting: CollectionSetting
    /// The editor showing the settings.
    let host: CollectionSettingsHost

    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    /// The rows chosen for *Clear*.
    @State private var chosen: Set<UUID> = []

    var body: some View {
        let rows = CollectionOwnSettings.rows(setting: setting, in: CollectionApparatusRows.liveOutline(of: collection))
        ForEach(rows, id: \.id) { entry in
            Button {
                if chosen.contains(entry.id) { chosen.remove(entry.id) } else { chosen.insert(entry.id) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: chosen.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(chosen.contains(entry.id) ? Color.accentColor : .secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(host.name(entry))
                        Text(CollectionOwnSettings.valueName(setting, of: entry, promptName: promptName))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(chosen.contains(entry.id) ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("collection.setting.own.row")
        }
        HStack {
            Button(chosen.count == rows.count && !rows.isEmpty
                   ? String(localized: "collection.setting.own.chooseNone", defaultValue: "Choose None")
                   : String(localized: "collection.setting.own.chooseAll", defaultValue: "Choose All")) {
                chosen = chosen.count == rows.count ? [] : Set(rows.map(\.id))
            }
            Spacer()
            Button(String(localized: "collection.setting.own.clear", defaultValue: "Clear")) {
                CollectionOwnSettings.clear(setting, of: rows.filter { chosen.contains($0.id) })
                try? collection.modelContext?.save()
                chosen = []
            }
            .disabled(chosen.isEmpty)
            .accessibilityHint(String(localized: "collection.setting.own.clear.hint",
                                      defaultValue: "The chosen sections and documents follow the collection again."))
            .accessibilityIdentifier("collection.setting.own.clear")
        }
        .buttonStyle(.borderless)
    }

    /// A prompt's name, by its id.
    private func promptName(_ id: UUID) -> String {
        allPrompts.first { $0.id == id }?.name
            ?? String(localized: "collection.inspector.override.prompt.none", defaultValue: "None")
    }
}

// MARK: - CollectionApparatusStep

/// Step 2, *Apparatus* (L44; the design's §4.3): the three shortcuts (decision 168), the contents list's style and the
/// word cloud (decision 169), a tick for each block, and under them the colophon, the project stamp and the query log,
/// which no shortcut sets (decision 170). A shortcut both adds and removes, in view, and the line under the shortcuts
/// says what changed, with *Undo*. A tick is not a setting: it says the outline has that block's row.
///
/// Version history:
///   1.0 — L44: initial implementation, with `CollectionCompositionRows`' Analysis & apparatus section and L58's line,
///          which says under the Note's tick what the Note would say
struct CollectionApparatusStep: View {
    /// The collection whose settings these are.
    @Bindable var collection: Collection
    /// The editor showing them.
    let host: CollectionSettingsHost
    /// How the step is shown.
    let presentation: CollectionSettingsPresentation
    /// Pushed: brings a row into view by its id.
    var scroll: ((String) -> Void)? = nil

    /// The last shortcut's *Undo*, while the screen is open.
    @State private var lastChange: CollectionApparatusRows.Undo?

    /// The id of the line a shortcut writes, which the screen brings into view.
    static let changeLineID = "collection.apparatus.change"

    var body: some View {
        let current = CollectionApparatusRows.settings(of: collection, outline: CollectionApparatusRows.liveOutline(of: collection))
        Section {
            Menu {
                ForEach(CollectionPreset.suggestionOrder(for: collection.documentSettings)) { preset in
                    Button(CollectionApparatusShortcut.suggested(preset).title) { apply(.suggested(preset), to: current) }
                }
            } label: {
                Text(String(localized: "collection.apparatus.shortcut.suggestedMenu", defaultValue: "Suggested for…"))
            }
            .accessibilityIdentifier("collection.apparatus.suggested")
            Button(CollectionApparatusShortcut.all.title) { apply(.all, to: current) }
                .accessibilityIdentifier("collection.apparatus.all")
            Button(CollectionApparatusShortcut.none.title) { apply(.none, to: current) }
                .accessibilityIdentifier("collection.apparatus.none")
            if let lastChange {
                CollectionChangeLine(sentence: lastChange.change.sentence, identifier: Self.changeLineID) {
                    host.undoApparatus(lastChange)
                    self.lastChange = nil
                }
                .id(Self.changeLineID)
            }
        } header: {
            Text(String(localized: "collection.apparatus.shortcuts.header", defaultValue: "Shortcuts"))
        } footer: {
            Text(String(localized: "collection.apparatus.shortcuts.footer",
                        defaultValue: "A shortcut sets the contents list, the word cloud and the blocks below, adding and removing. It leaves the three switches at the end as they are."))
        }

        Section {
            Picker(String(localized: "composition.tocStyle", defaultValue: "Contents list"),
                   selection: Binding(get: { CollectionToCStyle(rawValue: collection.tocStyle) ?? .citation },
                                      set: { collection.tocStyle = $0.rawValue })) {
                ForEach(CollectionToCStyle.allCases) { Text($0.displayName).tag($0) }
            }
            Toggle(String(localized: "composition.includeWordCloud", defaultValue: "Word-cloud overview"),
                   isOn: $collection.includeWordCloud)
        } header: {
            Text(String(localized: "collection.apparatus.contents.header", defaultValue: "Contents and overview"))
        }

        Section {
            ForEach(CollectionGeneratedBlockType.allCases) { type in
                Toggle(isOn: Binding(
                    get: { current.blocks.contains(type) },
                    set: { on in
                        var target = current
                        if on { target.blocks.insert(type) } else { target.blocks.remove(type) }
                        _ = host.applyApparatus(target)
                    })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(type.displayName, systemImage: type.systemImage)
                        if type == .noteOnTheText, !current.blocks.contains(type),
                           CollectionApparatusStep.wantsNoteOnTheText(collection) {
                            // L58 (the design's §3.6): what the Note would say, where the collection has none.
                            Text(String(localized: "composition.noteOnTheText.line",
                                        defaultValue: "This collection’s export changes what its volumes print: it adds your titles or headnotes, or leaves something out. A Note on the Text would say so."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityIdentifier("collection.apparatus.block.\(type.rawValue)")
            }
        } header: {
            Text(String(localized: "collection.apparatus.blocks.header", defaultValue: "Blocks"))
        } footer: {
            Text(String(localized: "collection.apparatus.blocks.footer",
                        defaultValue: "A ticked block has its row in the outline, a Chronology first and the others at the end. Unticking removes the row; the outline’s Apparatus menu still adds one."))
        }

        Section {
            Toggle(String(localized: "collection.frontmatter.colophon.toggle", defaultValue: "Include colophon"),
                   isOn: host.colophon)
                .accessibilityIdentifier("collection.editor.colophon.toggle")
            Toggle(String(localized: "collection.frontmatter.projectProvenance.toggle",
                          defaultValue: "Stamp active project on export"),
                   isOn: host.projectStamp)
                .accessibilityIdentifier("collection.editor.projectProvenance.toggle")
            // M-2. The subtitle is not decoration: this is the one export toggle that puts the text of the researcher's
            // searches into a document they may be about to publish, and that has to be legible at the moment of the tap.
            Toggle(isOn: host.queryLog) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "collection.frontmatter.methodAppendix.toggle",
                                defaultValue: "Append the query log"))
                    Text(String(localized: "collection.frontmatter.methodAppendix.subtitle",
                                defaultValue: "Every search you ran under the active project, with its scope and result count."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("collection.editor.methodAppendix.toggle")
        } header: {
            Text(String(localized: "collection.apparatus.export.header", defaultValue: "On export"))
        }
    }

    /// Applies a shortcut, keeps its *Undo*, and brings its line into view.
    private func apply(_ shortcut: CollectionApparatusShortcut, to current: CollectionApparatusSettings) {
        lastChange = host.applyApparatus(shortcut.applied(to: current))
        scroll?(Self.changeLineID)
    }

    /// Whether step 2 says under the Note's tick what the Note would say (L58; the design's §3.6): a static collection with
    /// no Note, whose Note would have something to say by the rule its export reads
    /// (`CollectionContentAssembly.noteOnTheText(over:collection:options:headnote:)`). The headnotes are looked up only
    /// where nothing else would be said, so the line costs no store read for most collections. A smart collection's
    /// documents come from its saved search, which these settings do not run, so it is not said there.
    static func wantsNoteOnTheText(_ collection: Collection) -> Bool {
        guard collection.savedSearchId == nil else { return false }
        let models = (collection.documentEntries ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard !models.contains(where: {
            $0.entryKind == .generated
                && $0.generatedBlockType == CollectionGeneratedBlockType.noteOnTheText.rawValue
        }) else { return false }
        let values = models.map(CollectionEntryExport.init)
        let export = CollectionExport(collection, entries: values)
        let options = CollectionExportOptions(composing: export)
        let entries = values.map { CollectionContentAssembly.Entry($0, proseParagraphs: nil) }
        if CollectionContentAssembly.noteOnTheText(over: entries, collection: export, options: options,
                                                   headnote: { _, _ in nil }).hasSomethingToSay {
            return true
        }
        guard let context = collection.modelContext else { return false }
        return CollectionContentAssembly.noteOnTheText(over: entries, collection: export, options: options) { entry, promptId in
            NativeCollectionSerializer.headnoteForFile(
                volumeId: entry.volumeId, documentId: entry.documentId, summaryId: entry.headnoteSummaryId,
                preferredPromptId: promptId, authorLine: collection.authorLine, in: context)
                .map { CollectionHeadnoteWriter(authorship: $0.summaryAuthorship ?? .aiGenerated,
                                                storedName: $0.writerName ?? CollectionHeadnoteWriter.unnamed,
                                                authorLine: nil) }
        }.hasSomethingToSay
    }
}

// MARK: - CollectionCitationsRows

/// *Citation style* and *Wording* (L43, in the place L44 gives them): the style every citation in the collection's
/// exports prints in, and a row that opens the collection's own words for the ten labels its exports print. Pushed, the
/// row opens a screen of the ten fields; in place, they open under it.
struct CollectionCitationsRows: View {
    /// The collection whose settings these are.
    @Bindable var collection: Collection
    /// How *Wording* opens.
    let presentation: CollectionSettingsPresentation

    /// In place: whether the ten fields are open.
    @State private var wordingOpen = false

    var body: some View {
        Section {
            Picker(String(localized: "composition.citationStyle", defaultValue: "Citation style"),
                   selection: Binding(get: { collection.citationStyle.flatMap(CitationStyle.init(rawValue:)) ?? .historyAtState },
                                      set: { collection.citationStyle = $0.rawValue })) {
                ForEach(CitationStyle.allCases) { Text($0.displayName).tag($0) }
            }
            .accessibilityIdentifier("composition.citationStyle.picker")

            switch presentation {
            case .pushed:
                NavigationLink {
                    Form {
                        Section {
                            CollectionWordingFields(collection: collection)
                        } footer: {
                            Text(wordingSubtitle)
                        }
                    }
                    .formStyle(.grouped)
                    .navigationTitle(wordingTitle)
                } label: {
                    wordingLabel
                }
                .accessibilityIdentifier("composition.wording.group")
            case .inPlace:
                DisclosureGroup(isExpanded: $wordingOpen) {
                    CollectionWordingFields(collection: collection)
                } label: {
                    wordingLabel
                        // A click on a Mac disclosure group's label toggles nothing by itself (#1860).
                        #if os(macOS)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation { wordingOpen.toggle() } }
                        #endif
                        // On the label alone: on the group, SwiftUI gives it to the fields inside, in place of their own.
                        .accessibilityIdentifier("composition.wording.group")
                }
            }
        } header: {
            Text(String(localized: "composition.group.citations", defaultValue: "Citations & wording"))
        }
    }

    private var wordingTitle: String {
        String(localized: "composition.wording", defaultValue: "Wording")
    }

    private var wordingSubtitle: String {
        String(localized: "composition.wording.subtitle",
               defaultValue: "Your own words for the labels an export prints. A word left empty prints the app’s.")
    }

    private var wordingLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wordingTitle)
            Text(wordingSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - CollectionWordingFields

/// The ten labels' fields of a collection's *Wording* (L43): the app's word, and a field for the collection's own, which
/// shows the app's word until one is typed. VoiceOver reads the label's name and the word the export prints.
struct CollectionWordingFields: View {
    /// The collection whose words these are.
    @Bindable var collection: Collection

    var body: some View {
        ForEach(CollectionWording.Label.allCases, id: \.self) { label in
            HStack {
                Text(label.appWord)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(text: wording(label), prompt: Text(label.appWord)) {
                    Text(label.appWord)
                }
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(String(format: String(localized: "composition.wording.field.accessibility %@",
                                                          defaultValue: "%@, printed as"), label.appWord))
                .accessibilityValue(CollectionWording(json: collection.labelsJSON).text(for: label))
                .accessibilityIdentifier("composition.wording.field.\(label.rawValue)")
            }
        }
    }

    /// One label's word (L43): the collection's own, or empty, which the field shows as the app's word. Writing the
    /// stored map keeps every other pair, a later build's among them.
    private func wording(_ label: CollectionWording.Label) -> Binding<String> {
        Binding(get: { CollectionWording(json: collection.labelsJSON).ownWord(for: label) ?? "" },
                set: { collection.labelsJSON = CollectionWording.updating(collection.labelsJSON, label: label, with: $0) })
    }
}

// MARK: - The Mac's New Collection form: the two steps as menus

/// Step 1 as a menu (L44; the design's §5.2), for the Mac's New Collection form, which Add to Collection opens: the six
/// templates, the one in force marked, under a label that says what is set, *Like Full text as printed · 2 differ* for a
/// new collection, which equals none (decision 159; the third review's J26).
struct CollectionDocumentsMenu: View {
    /// The new collection.
    @Bindable var collection: Collection

    var body: some View {
        let state = CollectionDocumentsState(collection.documentSettings)
        LabeledContent(CollectionSettingsSteps.documentsTitle) {
            Menu {
                ForEach(CollectionPreset.allCases) { preset in
                    Button {
                        collection.applyDocuments(preset.documents)
                    } label: {
                        if state == .template(preset) {
                            Label(preset.displayName, systemImage: "checkmark")
                        } else {
                            Text(preset.displayName)
                        }
                        Text(preset.subtitle)
                    }
                }
            } label: {
                Text(state.summary)
            }
            .fixedSize()
            .accessibilityIdentifier("collection.newCollection.documents")
        }
        if let line = state.differencesSentence(collection.documentSettings) {
            Text(line)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Step 2 as a menu (L44), for the Mac's New Collection form: *Suggested for…* each template, the one for these documents
/// first, *All* and *None*, under a label that lists what is added.
struct CollectionApparatusMenu: View {
    /// The new collection.
    @Bindable var collection: Collection
    /// The form's outline and its way of changing the apparatus rows.
    let host: CollectionSettingsHost

    var body: some View {
        let current = CollectionApparatusRows.settings(of: collection, outline: CollectionApparatusRows.liveOutline(of: collection))
        LabeledContent(CollectionSettingsSteps.apparatusTitle) {
            Menu {
                Section(String(localized: "collection.apparatus.shortcut.suggestedMenu", defaultValue: "Suggested for…")) {
                    ForEach(CollectionPreset.suggestionOrder(for: collection.documentSettings)) { preset in
                        Button(preset.displayName) {
                            _ = host.applyApparatus(CollectionApparatusShortcut.suggested(preset).applied(to: current))
                        }
                    }
                }
                Divider()
                Button(CollectionApparatusShortcut.all.title) {
                    _ = host.applyApparatus(CollectionApparatusShortcut.all.applied(to: current))
                }
                Button(CollectionApparatusShortcut.none.title) {
                    _ = host.applyApparatus(CollectionApparatusShortcut.none.applied(to: current))
                }
            } label: {
                Text(current.summary)
            }
            .fixedSize()
            .accessibilityIdentifier("collection.newCollection.apparatus")
        }
    }
}
