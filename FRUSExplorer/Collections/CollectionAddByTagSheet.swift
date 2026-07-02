// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AddByTagSheet

/// Sheet that lets the user pick a `UserTag` then appends all tagged documents.
///
/// ## Platform layout
/// On macOS, `NavigationStack { List }` inside a `.sheet()` renders as a split-column
/// layout — the list becomes a collapsed sidebar and the detail area appears blank.
/// The macOS body uses a plain `VStack` with an explicit button bar (the same pattern
/// used by `CollectionEditorView.macBody`) so all controls are always visible.
///
/// Version history:
///   1.0 — Session 88: initial implementation
///   1.1 — Session 129: split macOS / iOS bodies; macOS uses VStack + button-bar
///          pattern to prevent NavigationStack sidebar from hiding list content
///   1.2 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
struct AddByTagSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allTags: [UserTag]
    let allNotes: [ResearchNote]
    let onAdd: ([(documentId: String, volumeId: String)]) -> Void

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(String(localized: "collection.addByTag.nav.title",
                            defaultValue: "Add by Tag"))
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            // Tag list
            List(allTags) { tag in
                Button {
                    let pairs = allNotes
                        .filter { $0.userTagIds.contains(tag.id) }
                        .map { (documentId: $0.documentId, volumeId: $0.volumeId) }
                    onAdd(pairs)
                    dismiss()
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        let count = allNotes.filter { $0.userTagIds.contains(tag.id) }.count
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)

            Divider()

            // Button bar
            HStack {
                Spacer()
                Button(String(localized: "collection.addByTag.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 320, minHeight: 260)
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            List(allTags) { tag in
                Button {
                    let pairs = allNotes
                        .filter { $0.userTagIds.contains(tag.id) }
                        .map { (documentId: $0.documentId, volumeId: $0.volumeId) }
                    onAdd(pairs)
                    dismiss()
                } label: {
                    HStack {
                        Text(tag.name)
                        Spacer()
                        let count = allNotes.filter { $0.userTagIds.contains(tag.id) }.count
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(String(localized: "collection.addByTag.nav.title",
                                    defaultValue: "Add by Tag"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "collection.addByTag.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
