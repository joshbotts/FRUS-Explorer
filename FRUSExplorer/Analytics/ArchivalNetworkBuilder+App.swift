// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - ArchivalNetworkBuilder: the caption measure

/// The app's half of `ArchivalNetworkBuilder`, which is FRUSCoreKit's: the caption measure, which reads
/// UIKit's or AppKit's system font, and the layout the canvas draws with it.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24c): `measuredCaptionSize(_:)` out of
///          `ArchivalNetworkData.swift`, unchanged, when that file moved into FRUSCoreKit, whose
///          `layout(_:in:captionSize:)` takes the measure a host supplies; `layout(_:in:)` passes this
///          one, as that function's default argument did
extension ArchivalNetworkBuilder {

    /// The size a caption's text draws at — the system font at `captionPointSize` semibold, which
    /// the canvas's `captionFont` resolves to (`ArchivalNetworkCaptionTests` measures the two
    /// against each other) — rounded up to whole points.
    /// - Parameter text: The caption.
    /// - Returns: Its size.
    static func measuredCaptionSize(_ text: String) -> CGSize {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: captionPointSize, weight: .semibold)
        #else
        let font = NSFont.systemFont(ofSize: captionPointSize, weight: .semibold)
        #endif
        let size = (text as NSString).size(withAttributes: [.font: font])
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    /// Places every node in a canvas of the given size, and reserves the captions' space, measuring
    /// each caption in the system font the canvas draws it in: `layout(_:in:captionSize:)` with
    /// `measuredCaptionSize(_:)`.
    /// - Parameters:
    ///   - graph: The graph to lay out.
    ///   - size: The canvas.
    /// - Returns: The layout.
    static func layout(_ graph: ArchivalNetworkGraph, in size: CGSize) -> ArchivalNetworkLayout {
        layout(graph, in: size, captionSize: measuredCaptionSize)
    }
}
