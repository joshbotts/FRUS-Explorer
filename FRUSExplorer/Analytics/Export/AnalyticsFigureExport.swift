// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics
import ImageIO

// MARK: - AnalyticsFigureFormat

/// The image formats an analytics figure can be exported in (D3).
///
/// Version history:
///   1.0 — D3 Phase 1: initial implementation
enum AnalyticsFigureFormat {
    /// A raster PNG at `AnalyticsFigureExporter.scale`× the canvas size.
    case png
    /// A vector PDF page at the canvas size.
    case pdf

    /// The file extension, without the dot.
    var pathExtension: String { self == .png ? "png" : "pdf" }
    /// The type for the macOS save panel.
    var contentType: UTType { self == .png ? .png : .pdf }
}

// MARK: - AnalyticsFigureCanvas

/// The fixed-size plate an analytics chart is rendered onto for export (D3).
///
/// `ImageRenderer` needs an intrinsic size, and the analytics charts deliberately have none — they
/// set `.frame(height:)` but let width follow the window — so rendering one as-is yields a blank or
/// clipped image. This wrapper supplies an explicit width and height.
///
/// Two further properties matter because exported content is **detached from the view hierarchy**:
///  - it inherits no environment, so the caller must pass **pre-resolved** strings and colors (any
///    label that reads `@Environment(AppState.self)` — a volume title, a source name — must already
///    have been resolved before it gets here);
///  - it resolves appearance from the renderer's default environment, so the plate paints an
///    explicit white background and forces `.colorScheme(.light)` rather than inheriting whatever
///    the user is running.
///
/// The caption strip is sized from the provenance's own line count, so the figure never crops its
/// own methods line.
///
/// Version history:
///   1.0 — D3 Phase 1: initial implementation
struct AnalyticsFigureCanvas<Content: View>: View {

    /// The methods statement printed beneath the chart.
    let provenance: AnalyticsProvenance
    /// The plate's width in points.
    var width: CGFloat = AnalyticsFigureExporter.defaultWidth
    /// The chart area's height in points (the caption strip is added below it).
    var chartHeight: CGFloat = 420
    /// The chart, already supplied with pre-resolved labels and explicit colors.
    @ViewBuilder var content: () -> Content

    /// Inset around the plate's contents.
    private let margin: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
                .frame(width: width - margin * 2, height: chartHeight)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                // ONE ForEach over `plateLines` and nothing else. The band used to be assembled
                // here — two caption lines plus a hardcoded sentence — which put the rule for what
                // a published figure says inside a view body, where no test could reach it. Every
                // line, and its order, is now the provenance's to state.
                ForEach(Array(provenance.plateLines.enumerated()), id: \.offset) { _, line in
                    Text(line.text)
                        .font(Self.font(for: line.role))
                        .foregroundStyle(Color.black.opacity(Self.opacity(for: line.role)))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, line.role == .caveat ? 0 : 2)
                }
            }
            .frame(width: width - margin * 2, alignment: .leading)
        }
        .padding(margin)
        .frame(width: width, alignment: .leading)
        .background(Color.white)
        // Detached content would otherwise resolve the renderer's default appearance; pin it so an
        // export looks the same regardless of the user's light/dark setting.
        .environment(\.colorScheme, .light)
    }

    // MARK: - Type

    /// The size each role is set at.
    ///
    /// Caveats are the smallest thing on the plate and there can be several long ones, so they are
    /// set at 10 pt — legible at the 2x raster this exports at, and small enough that complete
    /// disclosure does not overwhelm a 240 pt chart. The attribution is set at caveat size but
    /// darker, because it is a credit rather than a qualification.
    static func font(for role: AnalyticsPlateLine.Role) -> Font {
        switch role {
        case .title:       return .system(size: 15, weight: .semibold)
        case .facts:       return .system(size: 12)
        case .caveat:      return .system(size: 10)
        case .attribution: return .system(size: 10, weight: .medium)
        case .dataPointer: return .system(size: 10)
        }
    }

    /// How dark each role is set.
    static func opacity(for role: AnalyticsPlateLine.Role) -> Double {
        switch role {
        case .title:       return 1.0
        case .facts:       return 0.65
        case .caveat:      return 0.55
        case .attribution: return 0.75
        case .dataPointer: return 0.45
        }
    }
}

// MARK: - AnalyticsFigureExporter

/// Renders an `AnalyticsFigureCanvas` to PNG or PDF bytes (D3).
///
/// Returns **data**, not a file, so it composes with `AnalyticsExportDelivery` (macOS save panel /
/// iOS share sheet) rather than writing its own temp files. Unlike the word-cloud exporter, a
/// failure is reported rather than swallowed as `nil`.
///
/// Version history:
///   1.0 — D3 Phase 1: initial implementation
@MainActor
enum AnalyticsFigureExporter {

    /// The plate width used for exported figures; wide enough for a full-page journal figure.
    static let defaultWidth: CGFloat = 1200
    /// The raster scale — a 1200pt plate exports as a 2400px-wide PNG.
    static let scale: CGFloat = 2

    /// Renders `canvas` to bytes in `format`.
    ///
    /// - Parameters:
    ///   - canvas: The fixed-size figure plate.
    ///   - format: PNG or PDF.
    /// - Returns: The encoded bytes, or `nil` when the renderer produced nothing (the caller turns
    ///   that into a user-visible failure).
    static func render<Content: View>(_ canvas: AnalyticsFigureCanvas<Content>,
                                      format: AnalyticsFigureFormat) -> Data? {
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = scale
        // Belt-and-braces alongside the canvas's own `.frame`: propose the exact width so a chart
        // that would otherwise size to its container cannot collapse.
        renderer.proposedSize = ProposedViewSize(width: canvas.width, height: nil)
        switch format {
        case .png:  return pngData(renderer)
        case .pdf:  return pdfData(renderer)
        }
    }

    /// Encodes the renderer's `cgImage` as PNG.
    private static func pngData(_ renderer: ImageRenderer<some View>) -> Data? {
        guard let cgImage = renderer.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Draws the renderer's content into a single-page PDF.
    ///
    /// Whether Swift Charts' marks and axis labels survive as vectors here (rather than being
    /// rasterized into the page) is what the Phase-1 fidelity check exists to establish — the path
    /// is only proven against plain `Text` by the word-cloud exporter.
    private static func pdfData(_ renderer: ImageRenderer<some View>) -> Data? {
        let data = NSMutableData()
        var wrote = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            wrote = true
        }
        return wrote ? data as Data : nil
    }
}
