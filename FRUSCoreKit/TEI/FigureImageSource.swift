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

// MARK: - FigureImagePNG

/// What the start of a figure image's bytes says of it: whether it is a PNG, and the pixel size its
/// header states, which the Word export sizes an image by without decoding it.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): `FigureImageLibrary.isPNG(_:)` and `pngPixelSize(_:)`,
///          unchanged, from the app's `DownloadManager.swift`, which forward here, since the Word exporter
///          that reads them is FRUSCoreKit's
public enum FigureImagePNG {

    /// Whether `data` opens with the PNG signature. Every image the corpus names is served as
    /// `image/png`; anything else the transfer returned is not an image to keep.
    public static func isPNG(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    /// The pixel size a PNG states in its header, or `nil` when `data` is no PNG: what the Word
    /// export sizes an image by without decoding it.
    public static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard isPNG(data), data.count >= 24 else { return nil }
        let bytes = [UInt8](data.prefix(24))
        // The IHDR chunk is first: its width and height are big-endian at offsets 16 and 20.
        let width = bytes[16..<20].reduce(0) { $0 << 8 | Int($1) }
        let height = bytes[20..<24].reduce(0) { $0 << 8 | Int($1) }
        return width > 0 && height > 0 ? (width, height) : nil
    }
}
