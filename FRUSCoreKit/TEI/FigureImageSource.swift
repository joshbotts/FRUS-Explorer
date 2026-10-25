// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FigureImageSource

/// Where an export finds a figure's image (#1516): its bytes, or `nil` when it is not to hand.
///
/// The collection exporters embed each image a document's figures name — the HTML export as a
/// `data:` URL, the Word export as a part of the package — and print the figure's placeholder for
/// one that is missing. The app's source is its `FigureImageStore`, the device's figure images,
/// which conforms in the app; a host outside the app passes its own, and a test passes a library of
/// its own making.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): the figure images the HTML and Word exporters
///          read from the app's `FigureImageStore.shared`, passed in now that the exporters are
///          FRUSCoreKit's
public protocol FigureImageSource: Sendable {
    /// `image`'s bytes, or `nil` when it is not to hand.
    func data(for image: FigureImageName) -> Data?
}

/// No figure images: every figure prints its placeholder. What an exporter uses unless it is
/// given a source.
public struct NoFigureImages: FigureImageSource {
    /// Creates the empty source.
    public init() {}

    /// Always `nil`.
    public func data(for image: FigureImageName) -> Data? { nil }
}
