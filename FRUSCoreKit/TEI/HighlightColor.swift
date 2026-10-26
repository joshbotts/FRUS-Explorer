// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - HighlightColor

/// The four supported highlight colors. The app names it `DocumentHighlight.Color`, a typealias of
/// this: the SwiftData model that stores a highlight's color, as `colorTag`, cannot leave the app,
/// and the serializer that paints a highlight needs the color without it.
///
/// Version history:
///   1.0 — FRUSCoreKit, part 1: moved from `DocumentHighlight.Color`
///   1.1 — Session 2026-10-24 (FRUS Explorer Light, S15a): public, for the web edition's reader
public enum HighlightColor: String, CaseIterable, Sendable {
    case yellow
    case green
    case blue
    case pink
}

// MARK: - ReaderHighlight

/// Serialisable snapshot of a single highlight, injected into `WKWebView` as JSON
/// so the CSS Custom Highlight API renderer (`kHighlightsJS`) can paint
/// highlight ranges using the `FRUSOffsets.charToNode` map.
///
/// `isStale` is computed at call time from the `renderingVersion` mismatch so the
/// web layer doesn't need to know the current document version.
///
/// It is the shape `window.FRUSHighlights.render` reads (`kHighlightsJS`), which paints a stale
/// highlight in the amber `frus-stale` class and skips it for a tap. The app names it
/// `DocumentHighlight.HighlightDTO`, a typealias of this, and builds one from a `DocumentHighlight`
/// with `init(_:currentVersion:)`, beside the model; a host outside the app builds one from the
/// values it stores.
///
/// Version history:
///   1.0 — Session 2026-10-24 (FRUS Explorer Light, S15a): moved from `DocumentHighlight.HighlightDTO`,
///          public, with its stale rule as `isStale(renderingVersion:currentVersion:)` and an
///          initialiser that takes the highlight's values
public struct ReaderHighlight: Encodable, Sendable {
    /// UTF-16 start offset, matching `DocumentHighlight.startOffset`.
    public let startOffset: Int
    /// UTF-16 end offset (exclusive), matching `DocumentHighlight.endOffset`.
    public let endOffset: Int
    /// Highlight color name — one of `"yellow"`, `"green"`, `"blue"`, `"pink"`.
    public let color: String
    /// `true` when the stored `renderingVersion` does not match the document's
    /// current version. Stale highlights are rendered in amber by `::highlight(frus-stale)`.
    public let isStale: Bool

    /// A highlight's values, with `isStale` computed from its stored version.
    ///
    /// - Parameters:
    ///   - startOffset:      The stored start offset.
    ///   - endOffset:        The stored end offset (exclusive).
    ///   - color:            The stored color tag, passed through as it is stored.
    ///   - renderingVersion: The rendering version the highlight stored when it was made or last
    ///                       confirmed.
    ///   - currentVersion:   The rendering version for the currently displayed document,
    ///                       from `ASTToRenderNodeConverter.renderingVersion(for:)`.
    public init(startOffset: Int, endOffset: Int, color: String,
                renderingVersion: String, currentVersion: String) {
        self.startOffset = startOffset
        self.endOffset   = endOffset
        self.color       = color
        self.isStale     = Self.isStale(renderingVersion: renderingVersion, currentVersion: currentVersion)
    }

    /// The stale rule: a highlight is stale when the rendering version it stored is not the
    /// page's. Its offsets may no longer align with the text they were made over.
    public static func isStale(renderingVersion: String, currentVersion: String) -> Bool {
        renderingVersion != currentVersion
    }
}

// MARK: - ExportHighlight

/// A snapshot of one `DocumentHighlight` used by exporters to annotate the
/// document body. Carries flat-text character offsets (same coordinate space as
/// `DocumentHighlight.startOffset`/`endOffset`) and the highlight colour.
///
/// Version history:
///   1.0 — Session 153: initial implementation
///   1.1 — FRUSCoreKit, part 1: moved from `CollectionExporter.swift`; `color` is the kit's
///          `HighlightColor`, which `DocumentHighlight.Color` names
struct ExportHighlight: Sendable {
    let startOffset: Int
    let endOffset:   Int
    let color:       HighlightColor
}
