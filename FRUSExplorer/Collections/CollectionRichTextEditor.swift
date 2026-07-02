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
/// Version history:
///   1.0 — extracted from CollectionEditorView.swift (Session 2026-07-02, Collections Authoring Phase 1)
enum ProseRichText {

    /// The RTF payload to render at export time: the entry's stored `richText`, else its plain
    /// `text` encoded as RTF (so exporters always receive RTF).
    static func exportRTF(from entry: CollectionEntry) -> Data {
        if let rtf = entry.richText { return rtf }
        let ns = NSAttributedString(string: entry.text ?? "")
        return (try? ns.data(from: NSRange(location: 0, length: ns.length),
                             documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])) ?? Data()
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

    /// The initial attributed content — from RTF, else the plain fallback.
    fileprivate func initialAttributed() -> NSAttributedString {
        if let rtf = initialRTF,
           let ns = try? NSAttributedString(data: rtf,
                                            options: [.documentType: NSAttributedString.DocumentType.rtf],
                                            documentAttributes: nil) {
            return ns
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
