// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SelectionVerb

/// One of the reader's actions on a text selection: a highlight in one of the four colours, Excerpt,
/// Look Up in NARA, or Note (#1540).
///
/// Two surfaces offer these, one per platform. On the Mac it is the `FloatingSelectionBar`. On
/// iPhone and iPad it is the system edit menu, which leads with them (`SelectionEditMenu`): the bar
/// was retired there because UIKit can draw its menu where the bar was, covering it. Each verb's name
/// is written once, in the app's extension of this type beside the bar, so the two surfaces cannot
/// call one action by two names.
///
/// Version history:
///   1.0 — #1540: initial implementation; "Look Up" becomes "Look Up in NARA" on both platforms,
///          since the system menu has a Look Up of its own (the dictionary)
///   1.1 — Session 2026-10-24 (FRUS Explorer Light, S15a): moved here from the app's
///          `FloatingSelectionBar.swift`, public, with `allInOrder` and `needsDocumentOffsets`, for
///          the web edition's selection bar; `title` and `systemImage` stay in the app
public enum SelectionVerb: Hashable, Sendable {
    /// Highlights the selection in `color`.
    case highlight(HighlightColor)
    /// Freezes the selection into a collection excerpt.
    case excerpt
    /// Hands the selected text to the NARA Catalog lookup.
    case lookUpInNARA
    /// Opens the note composer (a document-level note).
    case note

    /// Every verb in the order both surfaces offer them: the four colours, then Excerpt, Look Up in
    /// NARA and Note.
    public static var allInOrder: [SelectionVerb] {
        HighlightColor.allCases.map(SelectionVerb.highlight) + [.excerpt, .lookUpInNARA, .note]
    }

    /// Whether the verb needs a selection inside the document body, which has text offsets. A
    /// footnote selection has none, so it offers only Look Up in NARA and Note.
    public var needsDocumentOffsets: Bool {
        switch self {
        case .highlight, .excerpt: true
        case .lookUpInNARA, .note: false
        }
    }
}
