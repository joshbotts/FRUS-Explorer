// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - SaveSearchRequest

/// What Save this search names and saves, fixed when the reader chooses it.
///
/// The item both Search screens present the Save Search sheet from, with `.sheet(item:)`: iPhone and iPad's
/// `SearchView` from More ▸ Save this search, the Mac's `MacSearchWindowView` from its bookmark button. Each used to
/// keep the name in one `@State` and a Bool for the sheet in another, set both in the command's action, and build the
/// sheet from a computed property that read the name. Their bodies read neither, so setting them did not re-run the
/// body, and the sheet was built from the closure made before the tap. Its field showed the search's words, since a
/// binding reads the stored value, and its Save stayed off, worked out from the name as it was before the tap: a probe
/// on an iPhone 17 (iOS 27.0, 2026-10-18) logged the sheet's content reading the name as empty and its own Bool as
/// false, with no body run between the tap and the sheet. The Mac check copy showed the same Save, dimmed, ignoring a
/// click. #1590's `NewPromptRequest` records the same shape.
///
/// Version history:
///   1.0 — 2026-10-18: initial implementation
struct SaveSearchRequest: Identifiable {
    /// A new identity for each request, so two requests in a row are two presentations.
    let id = UUID()
    /// The search's words as the search field holds them, which the sheet shows under the name.
    let words: String
    /// The search the sheet saves.
    let parameters: SearchParameters

    /// The name the sheet offers: the words, without the spaces around them.
    var offeredName: String { words.trimmingCharacters(in: .whitespaces) }

    /// The name a search is saved under: `text` without the spaces around it, or `nil` when nothing is left, which is
    /// when the sheet's Save is off.
    ///
    /// Here and not on the sheet, which is a `View` and so main-actor isolated, statics included.
    static func savedName(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - SaveSearchSheet

/// The Save Search sheet on iPhone, iPad and the Mac: a name for the search, offered as its words, and Save.
///
/// The name is this view's own `@State`, set from the request as the sheet is made, so Save is worked out from the name
/// the field shows (``SaveSearchRequest`` says what this replaces). Save is off while the name is empty or only spaces,
/// and the name is saved trimmed. One view, where each Search screen had its own, with each platform's layout as it
/// was: a form under a navigation bar on iPhone and iPad, a dialog with a button bar on the Mac.
///
/// The sheet carries no notice about the volume scope. #258's said the scope was not saved, which was true while
/// `SavedSearch` flattened `SearchParameters` into columns and dropped eight of its twenty fields; #756 archives the
/// whole value, so the scope is saved, and #756 retired the notice as a false warning.
///
/// Version history:
///   1.0 — 2026-10-18: one sheet for both Search screens, which holds its own name (initial implementation)
struct SaveSearchSheet: View {

    // MARK: - Input

    /// What the sheet names and saves.
    let request: SaveSearchRequest
    /// Saves the request's search under the name given, which is trimmed and never empty. The sheet closes after.
    let onSave: (String) -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// The name as the field holds it.
    @State private var name: String

    /// A sheet that offers `request`'s words as the name, and hands the name chosen to `onSave`.
    init(request: SaveSearchRequest, onSave: @escaping (String) -> Void) {
        self.request = request
        self.onSave = onSave
        _name = State(initialValue: request.offeredName)
    }

    // MARK: - Body

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    /// Saves the search under the name in the field, trimmed, and closes the sheet; does nothing while the name is empty.
    private func save() {
        guard let saved = SaveSearchRequest.savedName(from: name) else { return }
        onSave(saved)
        dismiss()
    }

    // MARK: - iOS body

    #if os(iOS)
    /// iPhone and iPad: a form under a navigation bar, which holds Cancel and Save.
    private var iOSBody: some View {
        NavigationStack {
            Form {
                Section(String(localized: "search.saveSearch.section",
                               defaultValue: "Name")) {
                    TextField(
                        String(localized: "search.saveSearch.placeholder",
                               defaultValue: "Name this search"),
                        text: $name
                    )
                }
                if !request.offeredName.isEmpty {
                    Section(String(localized: "search.saveSearch.query",
                                   defaultValue: "Query")) {
                        Text(request.words)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "search.saveSearch.title",
                                    defaultValue: "Save Search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "search.saveSearch.save",
                                  defaultValue: "Save")) {
                        save()
                    }
                    .disabled(SaveSearchRequest.savedName(from: name) == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "search.saveSearch.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    #endif // os(iOS)

    // MARK: - macOS body

    #if os(macOS)
    /// The Mac: a dialog, its two rows above a button bar with Cancel at the left and Save, the default, at the right.
    ///
    /// A `VStack` rather than `NavigationStack { Form }`, whose 44 pt navigation bar and toolbar chrome do not suit a
    /// two-field confirmation on the Mac. Return in the name field saves, as Save does.
    private var macBody: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "search.saveSearch.title",
                            defaultValue: "Save Search"))
                    .font(.headline)

                LabeledContent(String(localized: "search.saveSearch.section",
                                      defaultValue: "Name")) {
                    TextField(
                        String(localized: "search.saveSearch.placeholder",
                               defaultValue: "Name this search"),
                        text: $name
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                }

                LabeledContent(String(localized: "search.saveSearch.query",
                                      defaultValue: "Query")) {
                    Text(request.words)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)

            Divider()

            HStack {
                Button(String(localized: "search.saveSearch.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "search.saveSearch.save",
                              defaultValue: "Save")) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(SaveSearchRequest.savedName(from: name) == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 360, idealWidth: 400, minHeight: 180, idealHeight: 200)
    }
    #endif // os(macOS)
}
