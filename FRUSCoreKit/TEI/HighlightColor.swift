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
enum HighlightColor: String, CaseIterable, Sendable {
    case yellow
    case green
    case blue
    case pink
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
