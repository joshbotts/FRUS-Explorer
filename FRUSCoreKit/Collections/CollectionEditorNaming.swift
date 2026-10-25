// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionEditorNaming

/// The collection editor's rules about its collection's NAME (#1359): what the navigation bar reads, what a list row
/// reads, and when the editor's name field and the saved name say the same thing.
///
/// Pure, and public since FRUS Explorer Light's S18a, so `CollectionEditorNamingTests` calls the rules the views call. The iOS editor's
/// `iOSContent` and the macOS collection window (`CollectionDetailPane`) title through `navigationTitle`;
/// `fieldAgrees` decides both directions of the name in both editors — its commit (`CollectionEditorCommit.name`) and its
/// follow (`FrontMatterModelSync`) — in the iOS editor and, since MACCOL, in the macOS collection window's
/// `CollectionDetailPane`, which commits and follows its name through the same two and has no follow of its own.
/// Every row that lists a collection by name prints through `listName` (#1464): `CollectionPickerSheet`'s rows, the
/// Research rail's Collections section, the Collections list, the Mac window's picker label, Project Home's
/// Collections section and its Manage sheet, the Research sidebar, its list rows and its list title, the document
/// change review, and the word cloud's Collection scope and Compare menus (`GlobalContextView`'s rows went with the view).
/// So do the word cloud's collection scope heading (`WordCloudScopeResolver`), the Archives Visit picker's "from the
/// collection" line, and every export's title (`CollectionExportNaming.title`, #1463). The picker's search matches
/// through `listNameMatches`, and every list of them that sorts by name sorts by what its rows print —
/// `sortedByListName`, or `listOrder` where a list breaks ties its own way. `CollectionListNameTests` reads each site.
///
/// It is FRUSCoreKit's (FRUS Explorer Light, S18a), because the exporters' payloads read `listName`, and every rule
/// but one is pure; `sortedByListName`, which sorts SwiftData collections, stays beside the model in `Collection.swift`.
///
/// Version history:
///   1.0 — #1359: initial implementation
///   1.1 — #1359 review: `CollectionDetailPane`'s name follow uses `fieldAgrees` too
///   1.2 — #1359 review, round 2: `listName`, for the rows that printed a collection's name bare
///   1.3 — #1415 / #1413: the iOS editor's name commit moved from `FrontMatterModelSync` to `CollectionEditorCommit`
///   1.4 — #1463 review, round 1: moved unchanged from `CollectionEditorView.swift`, so `CollectionExportMetadata`
///          no longer reaches into a SwiftUI view file for its title
///   1.5 — #1464: eight more rows print through `listName`; `listNameMatches` for the picker's search; and
///          `untitledSection`, the name the inspector and the preview give a Section heading with no text (#1465)
///   1.6 — #1464 review, round 1: the word cloud's two menus, `GlobalContextView` and the Archives Visit line print
///          through `listName` too; `listOrder` and `sortedByListName`, so the lists that print `listName` sort by it
///   1.7 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public and otherwise unchanged, from
///          `Models/Collection.swift`, where `sortedByListName` stays
public enum CollectionEditorNaming {

    /// The navigation title for a collection saved under `savedName`: the name trimmed, when it has any text;
    /// otherwise "New Collection" for a collection the editor created and "Untitled Collection" for one it opened.
    ///
    /// The iOS editor passes the SAVED name, `collection.name`, not its name field, so a rename made elsewhere —
    /// another iPad window, another device through iCloud — retitles it as soon as the model changes. Otherwise the two
    /// differ only in whitespace, because a name edit is saved as it is typed. The macOS collection window passes its
    /// own name field, which follows the model on its own, with `isNewCollection: false`.
    public static func navigationTitle(savedName: String, isNewCollection: Bool) -> String {
        let trimmed = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return isNewCollection
            ? String(localized: "collection.editor.title.new", defaultValue: "New Collection")
            : String(localized: "collection.untitled.name", defaultValue: "Untitled Collection")
    }

    /// What a list row prints for a collection saved under `savedName`: the name trimmed, or "Untitled Collection" when
    /// it has no text — the reading an opened editor's title gives the same collection.
    ///
    /// A new collection is in the store from the moment its editor opens, and it is named only when the editor is
    /// dismissed. A tab switch does not dismiss the editor (`NewCollectionDismissal`), so while it waits in the
    /// Collections tab the collection has no name, and a document's Add to Collection picker on another tab lists it.
    /// Printed bare, it was a blank row reading "0 documents" (#1359 review, round 2).
    public static func listName(savedName: String) -> String {
        navigationTitle(savedName: savedName, isNewCollection: false)
    }

    /// How collections saved under `lhs` and `rhs` order in a list: by the names their rows print, `listName`, ignoring
    /// case. `.orderedSame` for two that print the same, which each caller breaks its own way.
    ///
    /// The lists that print `listName` sorted on the raw name, so an unnamed collection — saved as "" — sorted first
    /// while it read "Untitled Collection", and a padded name sorted by its leading space (#1464 review, round 1).
    public static func listOrder(_ lhs: String, _ rhs: String) -> ComparisonResult {
        listName(savedName: lhs).localizedCaseInsensitiveCompare(listName(savedName: rhs))
    }

    /// Whether a search for `searchText` finds a collection saved under `savedName`: the name its row prints,
    /// `listName`, contains the text, ignoring case.
    ///
    /// The Add to Collection picker's search read the raw name, so "untitled" found no unnamed collection though its
    /// row read "Untitled Collection", and a name padded with spaces matched a search for its padding (the 2026-09-28
    /// audit, from #1359's round 2). An empty search is the caller's to handle: it lists every collection.
    public static func listNameMatches(savedName: String, searchText: String) -> Bool {
        listName(savedName: savedName).localizedCaseInsensitiveContains(searchText)
    }

    /// What the app calls a Section heading saved with no text: the entry inspector's identity row, and the live
    /// preview, which shows the heading under this name so its author sees a section they made and have not named
    /// (#1465). Every export leaves such a heading out instead (`CollectionContentResolver`, decision D4), and the
    /// editor's own row keeps its "Section heading" prompt.
    public static var untitledSection: String {
        String(localized: "collection.inspector.section.untitled", defaultValue: "Untitled section")
    }

    /// Whether the name field's text and the saved name say the same thing: equal once both are trimmed, the way
    /// `CollectionEditorCommit.name` trims the field before it writes.
    ///
    /// Whitespace is the reason this is a function: the editor saves the name trimmed, so a field and a saved name that
    /// differ only in surrounding whitespace say the same thing. Compared untrimmed, a keystroke that adds only a space
    /// would save for nothing, and a save made while the field ends in whitespace — a pasted name, or an edit earlier in
    /// a name that ends in a space — would come back through `onChange` and delete that whitespace under the cursor.
    /// (Ordinary typing never reaches that second case: a trailing space does not change the trimmed name, so no save
    /// comes back while the field ends in one.)
    public static func fieldAgrees(_ fieldText: String, withSavedName savedName: String) -> Bool {
        fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
            == savedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
