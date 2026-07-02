// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - ProseRichText

/// Bridges a `prose` entry's stored body to/from RTF for the native editor and the exporters.
///
/// Rich text is persisted as **RTF** in `CollectionEntry.richText`. The native ``RichTextEditor``
/// produces *concrete* `NSFont`/`NSColor`/underline attributes, which RTF preserves and the
/// exporters can introspect — unlike SwiftUI's opaque `Font`, which cannot be resolved outside a
/// live view. `CollectionEntry.text` is kept in sync as the plain-text projection.
///
/// **Legacy Phase 3b blobs.** Before the RTF switch, `richText` held the `AttributedString`'s
/// own JSON `Codable` encoding (bold/italic as Foundation `inlinePresentationIntent`). Entries
/// written by a Phase 3b build — or synced via CloudKit from a device still running one — fail
/// the RTF decode, so treating the stored blob as RTF verbatim silently dropped their prose
/// from every export. All readers here now detect that encoding and convert it (formatting
/// preserved), and ``migrateLegacyJSONIfNeeded(_:)`` rewrites the entry in place so the store
/// converges on RTF.
///
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
///   1.1 — Session 2026-07-02 data-loss fix: `exportRTF` no longer returns the stored blob
///          verbatim — it validates RTF, converts legacy Phase 3b JSON `AttributedString`
///          blobs (migrating the entry in place), and falls back to the plain `text`
///          projection, so prose can never silently vanish from exports; added
///          `migrateLegacyJSONIfNeeded(_:)`, `decodedRTF(_:)`, `rtfData(from:)`, and the
///          legacy-decoding helpers shared with `CollectionProse` and the editor
enum ProseRichText {

    /// The RTF payload to render at export time — always *valid* RTF: the stored `richText`
    /// when it decodes as RTF, a legacy Phase 3b JSON blob converted to RTF (bold/italic
    /// preserved), else the plain `text` projection encoded as RTF. A legacy blob is also
    /// migrated to RTF on the entry itself (see ``migrateLegacyJSONIfNeeded(_:)``), so the
    /// first export heals the store even if the editor row never loads.
    static func exportRTF(from entry: CollectionEntry) -> Data {
        migrateLegacyJSONIfNeeded(entry)
        if let stored = entry.richText, decodedRTF(stored) != nil { return stored }
        let ns = NSAttributedString(string: entry.text ?? "")
        return rtfData(from: ns) ?? Data()
    }

    /// Rewrites a legacy Phase 3b JSON `richText` blob as RTF, in place. No-op when the blob
    /// is absent, already RTF, or unrecognizable (the latter is left untouched — `exportRTF`
    /// and the editor fall back to the plain `text` projection instead of destroying data).
    static func migrateLegacyJSONIfNeeded(_ entry: CollectionEntry) {
        guard let stored = entry.richText,
              decodedRTF(stored) == nil,
              let legacy = legacyNSAttributedString(fromJSON: stored),
              let rtf = rtfData(from: legacy)
        else { return }
        entry.richText = rtf
    }

    /// Decodes `data` as RTF, or `nil` when it is empty or not RTF (e.g. a legacy Phase 3b
    /// JSON blob).
    static func decodedRTF(_ data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return nil }
        return try? NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                                       documentAttributes: nil)
    }

    /// Encodes an attributed string as RTF, or `nil` when the encoder fails.
    static func rtfData(from attributed: NSAttributedString) -> Data? {
        try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    /// Decodes a legacy Phase 3b blob — the `AttributedString`'s own JSON `Codable` encoding —
    /// or `nil` when `data` is not that encoding. Callers should try ``decodedRTF(_:)`` first;
    /// the two formats never both decode, so the order is only a fast path.
    static func legacyJSONAttributedString(_ data: Data) -> AttributedString? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(AttributedString.self, from: data)
    }

    /// A legacy Phase 3b blob converted to a *concrete-font* `NSAttributedString` — bold/
    /// italic `inlinePresentationIntent` runs become font symbolic traits — that RTF
    /// round-trips and the exporters can introspect. `nil` when `data` is not the legacy
    /// encoding.
    static func legacyNSAttributedString(fromJSON data: Data) -> NSAttributedString? {
        guard let attributed = legacyJSONAttributedString(data) else { return nil }
        let result = NSMutableAttributedString()
        for run in attributed.runs {
            let text = String(attributed.characters[run.range])
            let intent = run.inlinePresentationIntent ?? []
            var attrs: [NSAttributedString.Key: Any] = [:]
            #if canImport(AppKit)
            var font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            var traits: NSFontDescriptor.SymbolicTraits = []
            if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
            if intent.contains(.emphasized) { traits.insert(.italic) }
            if !traits.isEmpty {
                font = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits),
                              size: font.pointSize) ?? font
            }
            attrs[.font] = font
            #elseif canImport(UIKit)
            var font = UIFont.preferredFont(forTextStyle: .callout)
            var traits: UIFontDescriptor.SymbolicTraits = []
            if intent.contains(.stronglyEmphasized) { traits.insert(.traitBold) }
            if intent.contains(.emphasized) { traits.insert(.traitItalic) }
            if !traits.isEmpty, let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                font = UIFont(descriptor: descriptor, size: font.pointSize)
            }
            attrs[.font] = font
            #endif
            result.append(NSAttributedString(string: text, attributes: attrs))
        }
        return result
    }
}

// MARK: - RichTextEditor

/// A native rich-text editor (`NSTextView` on macOS, `UITextView` on iOS) bound to an entry's
/// RTF body. Native text views produce concrete `NSFont`/`NSColor` attributes — bold/italic via
/// ⌘B/⌘I and the edit/format menu, colour via the macOS colour panel — which RTF round-trips and
/// the exporters can read. Edits are reported as `(rtf, plainText)` via `onChange`.
struct RichTextEditor {
    /// The entry's current RTF body (loaded once), or `nil` for an empty/plain prose block.
    let initialRTF: Data?
    /// Plain-text fallback used when `initialRTF` is `nil` (e.g. a pre-3b plain prose entry).
    let plainFallback: String
    /// Called on every edit with the new RTF and its plain-text projection.
    let onChange: (Data?, String) -> Void

    /// The initial attributed content — from RTF, else a legacy Phase 3b JSON blob (converted
    /// with its bold/italic intact, so pre-RTF prose loads faithfully and the first edit
    /// re-saves it as RTF), else the plain fallback.
    fileprivate func initialAttributed() -> NSAttributedString {
        if let stored = initialRTF {
            if let ns = ProseRichText.decodedRTF(stored) { return ns }
            if let legacy = ProseRichText.legacyNSAttributedString(fromJSON: stored) { return legacy }
        }
        return NSAttributedString(string: plainFallback)
    }

    /// Serialises the text view's storage to `(rtf, plainText)` and reports it.
    fileprivate func report(_ storage: NSAttributedString) {
        let rtf = try? storage.data(from: NSRange(location: 0, length: storage.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        onChange(rtf, storage.string)
    }
}

#if os(macOS)
extension RichTextEditor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.drawsBackground = false
        textView.textStorage?.setAttributedString(initialAttributed())

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Rebind the coordinator's callback to the CURRENT entry. The row (and its text view)
        // may have been reused for a different entry after a reorder/delete — the managers use
        // an index-based `$sortedEntries[idx]` binding — so a make-time closure would write to
        // the wrong entry (or trap on a stale index).
        context.coordinator.report = report
    }

    func makeCoordinator() -> Coordinator { Coordinator(report: report) }

    /// Forwards `NSTextView` edits back to the entry.
    final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate var report: (NSAttributedString) -> Void
        init(report: @escaping (NSAttributedString) -> Void) { self.report = report }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
            report(storage)
        }
    }
}
#elseif os(iOS)
extension RichTextEditor: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.allowsEditingTextAttributes = true   // Bold / Italic / Underline in the edit menu
        textView.isEditable = true
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .callout)
        textView.delegate = context.coordinator
        textView.attributedText = initialAttributed()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Rebind the coordinator's callback to the CURRENT entry (see the macOS note above).
        context.coordinator.report = report
    }

    func makeCoordinator() -> Coordinator { Coordinator(report: report) }

    /// Forwards `UITextView` edits back to the entry.
    final class Coordinator: NSObject, UITextViewDelegate {
        fileprivate var report: (NSAttributedString) -> Void
        init(report: @escaping (NSAttributedString) -> Void) { self.report = report }
        func textViewDidChange(_ textView: UITextView) {
            report(textView.attributedText ?? NSAttributedString())
        }
    }
}
#endif
