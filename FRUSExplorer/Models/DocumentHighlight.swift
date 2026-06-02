// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import SwiftUI

// MARK: - DocumentHighlight

/// A user-created text highlight within a FRUS document.
///
/// ## Offset Model
/// `startOffset` and `endOffset` are Unicode scalar positions (0-based, half-open
/// `[start, end)`) within the **flat text string** produced by a deterministic
/// depth-first traversal of `FRUSDocumentRenderModel.bodyNodes`. The traversal
/// concatenates `.plainText`, `.formulaText`, and `.lineBreak` leaf nodes; all
/// other leaf types (`.pageBreak`, `.footnoteMarker`, `.figureBlock`) contribute
/// no characters. Container nodes recurse into their children in array order.
/// Footnote bodies (`FRUSDocumentRenderModel.footnotes`) are excluded from the
/// body offset space.
///
/// See `Planning/102-DocumentHighlight-Architecture.md` for the complete
/// traversal specification, offset unit definition, and determinism analysis.
///
/// ## renderingVersion
/// A 16-character hex prefix of `SHA-256(rawXMLBytes ++ converterVersionBytes)`.
/// When `renderingVersion` does not match the value computed from the current
/// document source, the highlight is **stale** — its offsets may no longer align
/// with the correct text range. Stale highlights are displayed with a warning
/// indicator (Session 103) rather than being silently dropped.
///
/// ## CloudKit Compatibility
/// All stored properties have default values (CloudKit requires no non-optional
/// stored properties without defaults). `noteId` is stored as a plain `UUID?`
/// rather than a `@Relationship` to avoid cascading delete side effects across
/// the CloudKit record graph; the linked note is fetched at display time.
///
/// ## Conflict Resolution
/// Each highlight has a unique `id` — inserts from multiple devices are additive.
/// Concurrent edits to `colorTag` or `noteId` resolve by last-write-wins (CloudKit
/// default). See `Planning/102-DocumentHighlight-Architecture.md §3` for details.
///
/// ## Color Tags
/// Valid values for `colorTag`: `"yellow"`, `"green"`, `"blue"`, `"pink"`.
/// The rendering layer (Session 103) maps these strings to SwiftUI colors.
///
/// Version history:
///   1.0 — Session 102: initial implementation
@Model final class DocumentHighlight {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Binding

    var volumeId: String = ""
    var documentId: String = ""

    // MARK: - Text Range

    /// Unicode scalar position of the first selected character (0-based, inclusive).
    var startOffset: Int = 0

    /// Unicode scalar position one past the last selected character (exclusive).
    var endOffset: Int = 0

    // MARK: - Annotation

    /// Highlight color. Valid values: `"yellow"`, `"green"`, `"blue"`, `"pink"`.
    var colorTag: String = "yellow"

    /// Optional reference to the UUID of an associated `ResearchNote`.
    /// Stored as a plain `UUID?` (not a `@Relationship`) for CloudKit safety.
    var noteId: UUID? = nil

    // MARK: - Excerpt

    /// The verbatim text the user selected when creating this highlight.
    ///
    /// Stored at creation time so the Research window can display highlight
    /// excerpts without re-parsing the full TEI XML for each document.
    /// Empty string for highlights created before Session 131.
    var selectedText: String = ""

    // MARK: - Versioning

    /// 16-character hex prefix of SHA-256(rawXMLBytes ++ converterVersionBytes).
    /// Used to detect stale highlights after source or converter updates.
    var renderingVersion: String = ""

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date? = nil

    // MARK: - Initialiser

    init(
        volumeId: String,
        documentId: String,
        startOffset: Int,
        endOffset: Int,
        colorTag: String = "yellow",
        noteId: UUID? = nil,
        selectedText: String = "",
        renderingVersion: String
    ) {
        self.id = UUID()
        self.volumeId = volumeId
        self.documentId = documentId
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.colorTag = colorTag
        self.noteId = noteId
        self.selectedText = selectedText
        self.renderingVersion = renderingVersion
        self.createdAt = .now
    }
}

// MARK: - Color Tag

extension DocumentHighlight {

    /// The four supported highlight colors.
    enum Color: String, CaseIterable, Sendable {
        case yellow
        case green
        case blue
        case pink
    }

    /// Convenience accessor for the typed color.
    var color: Color { Color(rawValue: colorTag) ?? .yellow }
}

// MARK: - Color display helpers

extension DocumentHighlight.Color {

    /// Localised display name for use in the Research sidebar and color pickers.
    var displayName: String {
        switch self {
        case .yellow: return String(localized: "highlight.color.yellow", defaultValue: "Yellow")
        case .green:  return String(localized: "highlight.color.green",  defaultValue: "Green")
        case .blue:   return String(localized: "highlight.color.blue",   defaultValue: "Blue")
        case .pink:   return String(localized: "highlight.color.pink",   defaultValue: "Pink")
        }
    }

    /// SwiftUI `Color` matching this highlight color at full opacity.
    var swiftUIColor: SwiftUI.Color {
        switch self {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        }
    }

    /// SF Symbol name for use in the Research sidebar icon column.
    var symbolName: String { "highlighter" }
}
