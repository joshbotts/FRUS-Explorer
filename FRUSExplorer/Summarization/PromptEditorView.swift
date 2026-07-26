// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - PromptEditorView

/// Sheet-based editor for creating or editing a user `SummarizationPrompt`.
///
/// ## Modes
/// - Create: `promptToEdit == nil`. Template picker shown on first appear.
/// - Edit: `promptToEdit` is an existing user prompt. Fields pre-populated.
///
/// Standard prompts (`isStandard == true`) are read-only and cannot be opened
/// in this editor.
///
/// ## Template Picker
/// A "Use Template" button opens `TemplatePickerSheet`, which pre-populates
/// the prompt text and schema fields from one of the seven standard templates.
/// In edit mode the button is available as a "Reset to Template" action.
///
/// ## Schema Builder
/// When Output Format is set to Structured, a `SchemaBuilderSection` appears
/// allowing the user to add, remove, and rename fields.
///
/// Version history:
///   1.0 — Session 20: initial implementation
struct PromptEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let promptToEdit: SummarizationPrompt?
    /// When set and `promptToEdit == nil`, pre-populates the editor from this template
    /// without showing the template picker sheet (used by "Use as Template" flows).
    let initialTemplate: PromptTemplate?

    // MARK: - Editor State

    @State private var name: String = ""
    @State private var promptText: String = ""
    @State private var isStructured: Bool = false
    @State private var schemaFields: [EditableField] = []

    @State private var showTemplatePicker: Bool = false

    // MARK: - Init

    init(promptToEdit: SummarizationPrompt? = nil, initialTemplate: PromptTemplate? = nil) {
        self.promptToEdit = promptToEdit
        self.initialTemplate = initialTemplate
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body
    // NavigationStack inside a macOS sheet can push Form content outside the visible
    // bounds. Use a plain VStack with explicit button bar instead.

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(promptToEdit == nil
                     ? String(localized: "prompt.editor.title.new", defaultValue: "New Prompt")
                     : String(localized: "prompt.editor.title.edit", defaultValue: "Edit Prompt"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                nameSection
                templateSection
                promptTextSection
                outputFormatSection
                if isStructured {
                    SchemaBuilderSection(fields: $schemaFields)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(String(localized: "prompt.editor.toolbar.cancel", defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "prompt.editor.toolbar.save", defaultValue: "Save")) {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 560, minHeight: 460)
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(onSelect: applyTemplate)
        }
        .onAppear {
            if let p = promptToEdit {
                name = p.name
                promptText = p.promptText
                if case .structured(let schema) = p.responseFormat {
                    isStructured = true
                    schemaFields = schema.fields.map {
                        EditableField(name: $0.name, description: $0.description)
                    }
                }
            } else if let template = initialTemplate {
                applyTemplate(template)
            } else {
                showTemplatePicker = true
            }
        }
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            Form {
                nameSection
                templateSection
                promptTextSection
                outputFormatSection
                if isStructured {
                    SchemaBuilderSection(fields: $schemaFields)
                }
            }
            .navigationTitle(
                promptToEdit == nil
                    ? String(localized: "prompt.editor.title.new",
                             defaultValue: "New Prompt")
                    : String(localized: "prompt.editor.title.edit",
                             defaultValue: "Edit Prompt")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { editorToolbar }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(onSelect: applyTemplate)
            }
        }
        .onAppear {
            if let p = promptToEdit {
                name = p.name
                promptText = p.promptText
                if case .structured(let schema) = p.responseFormat {
                    isStructured = true
                    schemaFields = schema.fields.map {
                        EditableField(name: $0.name, description: $0.description)
                    }
                }
            } else if let template = initialTemplate {
                applyTemplate(template)
            } else {
                showTemplatePicker = true
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nameSection: some View {
        Section(String(localized: "prompt.editor.name.header", defaultValue: "Name")) {
            TextField(
                String(localized: "prompt.editor.name.placeholder",
                       defaultValue: "Prompt name"),
                text: $name
            )
            .accessibilityLabel(
                String(localized: "prompt.editor.name.a11y", defaultValue: "Prompt name")
            )
        }
    }

    @ViewBuilder
    private var templateSection: some View {
        Section {
            Button {
                showTemplatePicker = true
            } label: {
                Label(
                    promptToEdit == nil
                        ? String(localized: "prompt.editor.template.use",
                                 defaultValue: "Use Template")
                        : String(localized: "prompt.editor.template.reset",
                                 defaultValue: "Reset to Template"),
                    systemImage: "doc.on.doc"
                )
            }
        }
    }

    @ViewBuilder
    private var promptTextSection: some View {
        Section(String(localized: "prompt.editor.promptText.header",
                       defaultValue: "Prompt Text")) {
            TextEditor(text: $promptText)
                .frame(minHeight: 140)
                .font(.body.monospaced())
                .accessibilityLabel(
                    String(localized: "prompt.editor.promptText.a11y",
                           defaultValue: "Prompt text")
                )
            Text(String(localized: "prompt.editor.promptText.hint",
                        defaultValue: "Use {{DOCUMENT}} where the document text should be inserted."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var outputFormatSection: some View {
        Section(String(localized: "prompt.editor.format.header",
                       defaultValue: "Output Format")) {
            Picker(
                String(localized: "prompt.editor.format.picker.label",
                       defaultValue: "Format"),
                selection: $isStructured
            ) {
                Text(String(localized: "prompt.editor.format.general",
                            defaultValue: "General (prose)"))
                    .tag(false)
                Text(String(localized: "prompt.editor.format.structured",
                            defaultValue: "Structured (fields)"))
                    .tag(true)
            }
            // .radioGroup on macOS is the HIG-correct control for mutually exclusive
            // dialog choices; .segmented is correct for toolbars and control strips.
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.segmented)
            #endif
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "prompt.editor.toolbar.cancel",
                          defaultValue: "Cancel")) {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "prompt.editor.toolbar.save",
                          defaultValue: "Save")) {
                save()
                dismiss()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions

    private func applyTemplate(_ template: PromptTemplate) {
        promptText = template.promptText
        isStructured = !template.fields.isEmpty
        schemaFields = template.fields.map {
            EditableField(name: $0.name, description: $0.description)
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = template.name
        }
    }

    private func save() {
        let format: ResponseFormat
        let schema: StructuredSummarySchema?
        if isStructured {
            let validFields = schemaFields
                .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { StructuredSummarySchema.Field(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                     description: $0.description.trimmingCharacters(in: .whitespacesAndNewlines)) }
            let s = StructuredSummarySchema(fields: validFields)
            format = .structured(schema: s)
            schema = s
        } else {
            format = .general
            schema = nil
        }

        if let p = promptToEdit {
            p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            p.promptText = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            p.responseFormat = format
            p.schema = schema
        } else {
            let prompt = SummarizationPrompt(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                promptText: promptText.trimmingCharacters(in: .whitespacesAndNewlines),
                responseFormat: format,
                isStandard: false,
                schema: schema
            )
            modelContext.insert(prompt)
        }
        #if DEBUG
        print("[SummarizationUI] Saved prompt '\(name)'")
        #endif
    }
}

// MARK: - SchemaBuilderSection

/// Inline form section for adding, removing, and renaming structured schema fields.
private struct SchemaBuilderSection: View {
    @Binding var fields: [EditableField]

    var body: some View {
        Section(String(localized: "prompt.editor.schema.header",
                       defaultValue: "Schema Fields")) {
            ForEach($fields) { $field in
                SchemaFieldRow(field: $field)
            }
            .onDelete { indices in fields.remove(atOffsets: indices) }
            .onMove { source, dest in fields.move(fromOffsets: source, toOffset: dest) }
            Button {
                fields.append(EditableField(name: "", description: ""))
            } label: {
                Label(
                    String(localized: "prompt.editor.schema.addField",
                           defaultValue: "Add Field"),
                    systemImage: "plus"
                )
            }
        }
    }
}

// MARK: - SchemaFieldRow

private struct SchemaFieldRow: View {
    @Binding var field: EditableField

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                String(localized: "prompt.editor.schema.field.namePlaceholder",
                       defaultValue: "Field name"),
                text: $field.name
            )
            .font(.body)
            TextField(
                String(localized: "prompt.editor.schema.field.descPlaceholder",
                       defaultValue: "Description (optional)"),
                text: $field.description
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - TemplatePickerSheet

/// Half-sheet listing all standard templates. Includes a "Start from Scratch" option.
struct TemplatePickerSheet: View {
    let onSelect: (PromptTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        iOSBody
        #else
        macBody
        #endif
    }

    // MARK: - macOS body

    #if os(macOS)
    /// macOS-native layout: header row + list + no NavigationStack chrome.
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "prompt.template.picker.title",
                            defaultValue: "Choose a Template"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "prompt.template.picker.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            List {
                Section(String(localized: "prompt.template.picker.section.templates",
                               defaultValue: "Templates")) {
                    ForEach(SummarizationPromptSeeder.standardTemplates.dropFirst()) { template in
                        Button {
                            onSelect(template)
                            dismiss()
                        } label: {
                            TemplateRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    Button {
                        dismiss()
                    } label: {
                        Label(
                            String(localized: "prompt.template.picker.scratch",
                                   defaultValue: "Start from Scratch"),
                            systemImage: "square.and.pencil"
                        )
                    }
                }
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 420, minHeight: 340)
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            List {
                Section(String(localized: "prompt.template.picker.section.templates",
                               defaultValue: "Templates")) {
                    ForEach(SummarizationPromptSeeder.standardTemplates.dropFirst()) { template in
                        Button {
                            onSelect(template)
                            dismiss()
                        } label: {
                            TemplateRow(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    Button {
                        dismiss()
                    } label: {
                        Label(
                            String(localized: "prompt.template.picker.scratch",
                                   defaultValue: "Start from Scratch"),
                            systemImage: "square.and.pencil"
                        )
                    }
                }
            }
            .navigationTitle(
                String(localized: "prompt.template.picker.title",
                       defaultValue: "Choose a Template")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "prompt.template.picker.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    #endif
}

// MARK: - TemplateRow

private struct TemplateRow: View {
    let template: PromptTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(template.name)
                .font(.body)
            Text(fieldSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        // #312 follow-up: full-row tap target — both modifiers, in this order (frame widens this
        // VStack to the row, contentShape makes the widened area hit-testable).
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var fieldSummary: String {
        template.fields.isEmpty
            ? String(localized: "prompt.template.row.general",
                     defaultValue: "General prose")
            : template.fields.map(\.name).joined(separator: ", ")
    }
}

// MARK: - EditableField

/// Mutable representation of a `StructuredSummarySchema.Field` used during editing.
struct EditableField: Identifiable {
    let id: UUID = UUID()
    var name: String
    var description: String
}

