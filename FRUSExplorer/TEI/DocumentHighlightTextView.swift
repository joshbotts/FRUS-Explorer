// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import AppKit
import SwiftUI

// MARK: - DocumentHighlightTextView

/// macOS `NSViewRepresentable` that displays a `FRUSDocumentRenderModel` as
/// selectable text inside an `NSTextView`, enabling the user to select a passage
/// and create a `DocumentHighlight`.
///
/// ## Why Not SwiftUI Text?
/// `FRUSDocumentRenderer` renders the document using SwiftUI `Text` views, which
/// do not expose text-selection events. `NSTextView` provides native macOS selection
/// with the system magnifier, context menu, and accessibility support.
///
/// ## Offset Compatibility
/// The `NSAttributedString` is built by a depth-first traversal of `bodyNodes` that
/// precisely follows the flat-text specification in
/// `Planning/102-DocumentHighlight-Architecture.md §1`:
///
/// - `.plainText(str)` and `.formulaText(str)` contribute characters.
/// - `.lineBreak` contributes `"\n"`.
/// - `.pageBreak`, `.footnoteMarker`, and `.figureBlock` contribute nothing.
/// - All container nodes recurse into their children in array order.
/// - No inter-block separators or formatting symbols (brackets, superscripts) are
///   added, so `NSRange.location` in the text view equals `startOffset` /
///   `endOffset` in `DocumentHighlight`.
///
/// ## Selection Binding
/// `selectionRange` is updated on every selection change via `NSTextViewDelegate`.
/// `MacDocumentView` reads this binding to enable the "Create Highlight" toolbar button.
///
/// Version history:
///   1.0 — Session 103: initial implementation
///   1.1 — Session 106: highlights overlay rendering + stale detection
struct DocumentHighlightTextView: NSViewRepresentable {

    let renderModel: FRUSDocumentRenderModel
    let highlights: [DocumentHighlight]
    @Binding var selectionRange: NSRange?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        // Horizontal inset matches MacDocumentView's .padding(.horizontal, 48).
        textView.textContainerInset = NSSize(width: 48, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: .greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let attrStr = Self.buildAttributedString(from: renderModel, highlights: highlights)
        textView.textStorage?.setAttributedString(attrStr)
    }

    func makeCoordinator() -> Coordinator { Coordinator(selectionRange: $selectionRange) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var selectionRange: NSRange?
        weak var textView: NSTextView?

        init(selectionRange: Binding<NSRange?>) { _selectionRange = selectionRange }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let range = tv.selectedRange()
            selectionRange = range.length > 0 ? range : nil
        }
    }

    // MARK: - Attributed String Builder

    /// Converts the render model body nodes to an `NSAttributedString` whose character
    /// positions correspond directly to the flat-text offset model.
    static func buildAttributedString(from model: FRUSDocumentRenderModel, highlights: [DocumentHighlight] = []) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for node in model.bodyNodes {
            appendNode(node, to: result)
        }
        if !highlights.isEmpty {
            let currentVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
            applyHighlights(highlights, currentVersion: currentVersion, to: result)
        }
        return result
    }

    // MARK: - DFS Traversal

    private static func appendNode(
        _ node: FRUSRenderNode,
        to result: NSMutableAttributedString,
        size: CGFloat = 14,
        bold: Bool = false,
        italic: Bool = false,
        color: NSColor = .textColor
    ) {
        switch node {

        // MARK: Leaf nodes — text contributions

        case .plainText(let str):
            result.append(NSAttributedString(
                string: str,
                attributes: textAttrs(size: size, bold: bold, italic: italic, color: color)
            ))

        case .formulaText(let str):
            result.append(NSAttributedString(
                string: str,
                attributes: textAttrs(size: size, bold: bold, italic: true, color: color)
            ))

        case .lineBreak:
            result.append(NSAttributedString(
                string: "\n",
                attributes: textAttrs(size: size, bold: bold, italic: italic, color: color)
            ))

        // MARK: Leaf nodes — no text contribution per offset model spec

        case .pageBreak:        break
        case .footnoteMarker:   break
        case .figureBlock:      break

        // MARK: Block containers — heading / dateline (size / color change)

        case .heading(let children):
            for c in children {
                appendNode(c, to: result, size: 18, bold: true, italic: italic, color: .labelColor)
            }

        case .dateline(let children):
            for c in children {
                appendNode(c, to: result, size: 12, bold: bold, italic: italic,
                           color: .secondaryLabelColor)
            }

        case .attachmentHeading(let children):
            for c in children {
                appendNode(c, to: result, size: 15, bold: true, italic: italic, color: .labelColor)
            }

        // MARK: Block containers — pass-through (same attributes)

        case .paragraph(let children),
             .letterOpener(let children),
             .letterCloser(let children),
             .salutation(let children),
             .editorialNoteBlock(let children),
             .titlePageBlock(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .attachmentBlock(_, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .unknown(_, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        // Footnote bodies appear in model.footnotes, not bodyNodes.
        // If encountered in bodyNodes (shouldn't happen), recurse gracefully.
        case .footnoteBody(_, _, _, _, _, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        // MARK: Table — row-major recursion per spec

        case .tableBlock(let rows):
            for row in rows {
                for cell in row {
                    for c in cell.children {
                        appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
                    }
                }
            }

        // MARK: List — item-order recursion per spec

        case .listBlock(_, let items):
            for item in items {
                for c in item {
                    appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
                }
            }

        // MARK: Inline style containers

        case .boldText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: true, italic: italic, color: color)
            }

        case .italicText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: true, color: color)
            }

        case .termText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: true, color: color)
            }

        // Small caps: no CoreText feature here; characters are unchanged (offset model preserved)
        case .smallCapsText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        // Underline: apply NSUnderlineStyle over the character range produced by children;
        // no extra characters → offsets unaffected.
        case .underlineText(let children):
            let start = result.length
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }
            let len = result.length - start
            if len > 0 {
                result.addAttribute(.underlineStyle,
                                    value: NSUnderlineStyle.single.rawValue,
                                    range: NSRange(location: start, length: len))
            }

        // Strikethrough for sic text; no extra characters.
        case .sicText(let children):
            let start = result.length
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }
            let len = result.length - start
            if len > 0 {
                result.addAttribute(.strikethroughStyle,
                                    value: NSUnderlineStyle.single.rawValue,
                                    range: NSRange(location: start, length: len))
            }

        // Per offset model spec: no brackets — recurse children only.
        case .suppliedText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .corrText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        // MARK: Interactive inline elements — recurse children; links inactive in selection mode

        case .persNameLink(_, let children, _):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: .linkColor)
            }

        case .glossLink(_, let children, _):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: .linkColor)
            }

        case .crossRefLink(_, _, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: .linkColor)
            }
        }
    }

    // MARK: - Attribute Helpers

    private static func textAttrs(
        size: CGFloat,
        bold: Bool,
        italic: Bool,
        color: NSColor
    ) -> [NSAttributedString.Key: Any] {
        [.font: makeFont(size: size, bold: bold, italic: italic),
         .foregroundColor: color]
    }

    private static func makeFont(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let base = NSFont.userFont(ofSize: size) ?? NSFont.systemFont(ofSize: size)
        var traits: NSFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        guard !traits.isEmpty else { return base }
        let desc = base.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: desc, size: size) ?? base
    }

    private static func applyHighlights(
        _ highlights: [DocumentHighlight],
        currentVersion: String,
        to result: NSMutableAttributedString
    ) {
        let totalLength = result.length
        for h in highlights {
            let len = h.endOffset - h.startOffset
            guard h.startOffset >= 0, len > 0, h.endOffset <= totalLength else { continue }
            let range = NSRange(location: h.startOffset, length: len)
            let isStale = h.renderingVersion != currentVersion
            let bgColor = highlightNSColor(for: h.color, isStale: isStale)
            result.addAttribute(.backgroundColor, value: bgColor, range: range)
        }
    }

    private static func highlightNSColor(for color: DocumentHighlight.Color, isStale: Bool) -> NSColor {
        if isStale { return NSColor.systemOrange.withAlphaComponent(0.3) }
        switch color {
        case .yellow: return NSColor.systemYellow.withAlphaComponent(0.4)
        case .green:  return NSColor.systemGreen.withAlphaComponent(0.4)
        case .blue:   return NSColor.systemBlue.withAlphaComponent(0.45)
        case .pink:   return NSColor.systemPink.withAlphaComponent(0.4)
        }
    }
}

#else // iOS

import UIKit
import SwiftUI

// MARK: - DocumentHighlightTextView (iOS)

/// iOS `UIViewRepresentable` counterpart to the macOS `NSViewRepresentable` above.
///
/// Wraps `UITextView` (which inherits from `UIScrollView`) and enables native
/// tap-and-hold text selection with the system magnifier. The same DFS traversal
/// rules apply: only `.plainText`, `.formulaText`, and `.lineBreak` leaf nodes
/// contribute characters, keeping `NSRange.location` aligned with
/// `DocumentHighlight.startOffset` / `endOffset`.
///
/// See the macOS section above for full documentation on the offset model and
/// the traversal algorithm.
///
/// Version history:
///   1.0 — Session 104: initial implementation
///   1.1 — Session 106: highlights overlay rendering + stale detection
struct DocumentHighlightTextView: UIViewRepresentable {

    let renderModel: FRUSDocumentRenderModel
    let highlights: [DocumentHighlight]
    @Binding var selectionRange: NSRange?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let attrStr = Self.buildAttributedString(from: renderModel, highlights: highlights)
        textView.attributedText = attrStr
    }

    func makeCoordinator() -> Coordinator { Coordinator(selectionRange: $selectionRange) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var selectionRange: NSRange?

        init(selectionRange: Binding<NSRange?>) { _selectionRange = selectionRange }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            selectionRange = range.length > 0 ? range : nil
        }
    }

    // MARK: - Attributed String Builder

    /// Converts body nodes to an `NSAttributedString` following the flat-text offset spec.
    /// After the DFS traversal, stored highlight background colors are applied over their
    /// character ranges. Stale highlights (version mismatch) are tinted amber.
    static func buildAttributedString(from model: FRUSDocumentRenderModel, highlights: [DocumentHighlight] = []) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for node in model.bodyNodes {
            appendNode(node, to: result)
        }
        if !highlights.isEmpty {
            let currentVersion = ASTToRenderNodeConverter.renderingVersion(for: model)
            applyHighlights(highlights, currentVersion: currentVersion, to: result)
        }
        return result
    }

    // MARK: - DFS Traversal

    private static func appendNode(
        _ node: FRUSRenderNode,
        to result: NSMutableAttributedString,
        size: CGFloat = 16,
        bold: Bool = false,
        italic: Bool = false,
        color: UIColor = .label
    ) {
        switch node {

        case .plainText(let str):
            result.append(NSAttributedString(
                string: str,
                attributes: textAttrs(size: size, bold: bold, italic: italic, color: color)
            ))

        case .formulaText(let str):
            result.append(NSAttributedString(
                string: str,
                attributes: textAttrs(size: size, bold: bold, italic: true, color: color)
            ))

        case .lineBreak:
            result.append(NSAttributedString(
                string: "\n",
                attributes: textAttrs(size: size, bold: bold, italic: italic, color: color)
            ))

        case .pageBreak: break
        case .footnoteMarker: break
        case .figureBlock: break

        case .heading(let children):
            for c in children {
                appendNode(c, to: result, size: 20, bold: true, italic: italic, color: .label)
            }

        case .dateline(let children):
            for c in children {
                appendNode(c, to: result, size: 13, bold: bold, italic: italic,
                           color: .secondaryLabel)
            }

        case .attachmentHeading(let children):
            for c in children {
                appendNode(c, to: result, size: 17, bold: true, italic: italic, color: .label)
            }

        case .paragraph(let children),
             .letterOpener(let children),
             .letterCloser(let children),
             .salutation(let children),
             .editorialNoteBlock(let children),
             .titlePageBlock(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .attachmentBlock(_, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .unknown(_, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .footnoteBody(_, _, _, _, _, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .tableBlock(let rows):
            for row in rows {
                for cell in row {
                    for c in cell.children {
                        appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
                    }
                }
            }

        case .listBlock(_, let items):
            for item in items {
                for c in item {
                    appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
                }
            }

        case .boldText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: true, italic: italic, color: color)
            }

        case .italicText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: true, color: color)
            }

        case .termText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: true, color: color)
            }

        case .smallCapsText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .underlineText(let children):
            let start = result.length
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }
            let len = result.length - start
            if len > 0 {
                result.addAttribute(.underlineStyle,
                                    value: NSUnderlineStyle.single.rawValue,
                                    range: NSRange(location: start, length: len))
            }

        case .sicText(let children):
            let start = result.length
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }
            let len = result.length - start
            if len > 0 {
                result.addAttribute(.strikethroughStyle,
                                    value: NSUnderlineStyle.single.rawValue,
                                    range: NSRange(location: start, length: len))
            }

        case .suppliedText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .corrText(let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: color)
            }

        case .persNameLink(_, let children, _):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: .link)
            }

        case .glossLink(_, let children, _):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: .link)
            }

        case .crossRefLink(_, _, let children):
            for c in children {
                appendNode(c, to: result, size: size, bold: bold, italic: italic, color: .link)
            }
        }
    }

    // MARK: - Attribute Helpers

    private static func textAttrs(
        size: CGFloat,
        bold: Bool,
        italic: Bool,
        color: UIColor
    ) -> [NSAttributedString.Key: Any] {
        [.font: makeFont(size: size, bold: bold, italic: italic),
         .foregroundColor: color]
    }

    private static func makeFont(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        var traits = UIFontDescriptor.SymbolicTraits()
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        let base = UIFont.systemFont(ofSize: size)
        guard !traits.isEmpty,
              let desc = base.fontDescriptor.withSymbolicTraits(traits)
        else { return base }
        return UIFont(descriptor: desc, size: size)
    }

    private static func applyHighlights(
        _ highlights: [DocumentHighlight],
        currentVersion: String,
        to result: NSMutableAttributedString
    ) {
        let totalLength = result.length
        for h in highlights {
            let len = h.endOffset - h.startOffset
            guard h.startOffset >= 0, len > 0, h.endOffset <= totalLength else { continue }
            let range = NSRange(location: h.startOffset, length: len)
            let isStale = h.renderingVersion != currentVersion
            let bgColor = highlightUIColor(for: h.color, isStale: isStale)
            result.addAttribute(.backgroundColor, value: bgColor, range: range)
        }
    }

    private static func highlightUIColor(for color: DocumentHighlight.Color, isStale: Bool) -> UIColor {
        if isStale { return UIColor.systemOrange.withAlphaComponent(0.3) }
        switch color {
        case .yellow: return UIColor.systemYellow.withAlphaComponent(0.4)
        case .green:  return UIColor.systemGreen.withAlphaComponent(0.4)
        case .blue:   return UIColor.systemBlue.withAlphaComponent(0.45)
        case .pink:   return UIColor.systemPink.withAlphaComponent(0.4)
        }
    }
}

#endif // os(macOS) / iOS
