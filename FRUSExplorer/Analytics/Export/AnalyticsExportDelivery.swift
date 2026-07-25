// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// MARK: - AnalyticsExportFile

/// A file produced for export, ready to be shared (D3).
///
/// A fresh `id` per instance so `.sheet(item:)` re-presents when the same chart is exported twice.
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
struct AnalyticsExportFile: Identifiable, Hashable {
    let id = UUID()
    /// The written file.
    let url: URL
    /// The file's display name.
    let filename: String
}

// MARK: - AnalyticsExportOutcome

/// What happened when an export was delivered (D3).
///
/// Unlike the word-cloud exporter — which returns `nil` on failure, so a write error silently
/// presents nothing — every outcome here is explicit, so a caller can surface a failure.
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
enum AnalyticsExportOutcome {
    /// iOS: the file is written and should be presented in a share sheet.
    case share(AnalyticsExportFile)
    /// macOS: the file was written to the destination the user chose.
    case saved(URL)
    /// The user dismissed the save panel.
    case cancelled
    /// The export failed; the payload is a human-readable reason.
    case failed(String)
}

// MARK: - AnalyticsExportDelivery

/// Writes an analytics export to disk and hands it to the platform's delivery affordance (D3).
///
/// - **macOS** presents `NSSavePanel` and writes straight to the chosen destination, matching the
///   Collections exporters — a historian saving a figure wants a filename and a folder, and a
///   temp-directory file can be purged out from under them.
/// - **iOS** writes into a per-export subdirectory of the temporary directory (so two exports of the
///   same chart cannot overwrite each other) and returns it for a `ShareLink` sheet.
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
@MainActor
enum AnalyticsExportDelivery {

    /// Delivers UTF-8 text (a provenance-stamped CSV) as `filename`.
    ///
    /// - Parameters:
    ///   - text: The file's contents.
    ///   - filename: The suggested name, extension included.
    ///   - contentType: The file's type, for the macOS save panel.
    /// - Returns: What happened — a file to share, a saved destination, a cancellation, or a failure.
    static func deliver(text: String, filename: String, contentType: UTType = .commaSeparatedText) -> AnalyticsExportOutcome {
        guard let data = text.data(using: .utf8) else {
            return .failed(String(localized: "analytics.export.error.encode",
                                  defaultValue: "The export could not be encoded as text."))
        }
        return deliver(data: data, filename: filename, contentType: contentType)
    }

    /// Delivers raw bytes (an image or PDF) as `filename`. See `deliver(text:filename:contentType:)`.
    ///
    /// - Parameters:
    ///   - data: The file's contents.
    ///   - filename: The suggested name, extension included.
    ///   - contentType: The file's type, for the macOS save panel.
    /// - Returns: What happened — a file to share, a saved destination, a cancellation, or a failure.
    static func deliver(data: Data, filename: String, contentType: UTType) -> AnalyticsExportOutcome {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return .cancelled }
        do {
            try data.write(to: url, options: .atomic)
            return .saved(url)
        } catch {
            return .failed(error.localizedDescription)
        }
        #else
        // A per-export subdirectory keeps same-named exports from clobbering one another, which the
        // word-cloud exporter's flat temp-directory writes do.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("analytics-export", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return .share(AnalyticsExportFile(url: url, filename: filename))
        } catch {
            return .failed(error.localizedDescription)
        }
        #endif
    }

    /// A filesystem-safe filename stem built from a chart title, with a date stamp so repeat exports
    /// of the same chart are distinguishable in a download folder.
    ///
    /// - Parameters:
    ///   - title: The chart's title.
    ///   - date: The export date (injected for testability).
    /// - Returns: A sanitized stem, e.g. `FRUS-Analytics-sovereignty-by-Year-2026-07-24`.
    nonisolated static func filenameStem(title: String, date: Date = Date()) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = title.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        var stem = String(cleaned)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "-")
        if stem.isEmpty { stem = "chart" }
        let stamp = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "FRUS-Analytics-\(stem)-\(stamp)"
    }
}

// MARK: - AnalyticsExportShareSheet

/// The iOS delivery sheet: names the written file and offers the system share sheet (D3).
///
/// Version history:
///   1.0 — D3 Phase 0: initial implementation
struct AnalyticsExportShareSheet: View {
    /// The file to share.
    let item: AnalyticsExportFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "tablecells")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(item.filename)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                ShareLink(item: item.url) {
                    Label(String(localized: "analytics.export.share.button", defaultValue: "Share"),
                          systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(String(localized: "analytics.export.share.title", defaultValue: "Export"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
    }
}
