// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - Document Renderer (Layer 3)

/// Layer 3 of the TEI rendering pipeline: consumes a `FRUSDocumentRenderModel`
/// and produces a SwiftUI view hierarchy.
///
/// This view is intentionally thin — all parsing and semantic logic lives in Layers 1 and 2.
/// `FRUSDocumentRenderer` only translates `FRUSRenderNode` cases into SwiftUI primitives.
///
/// ## Platform Adaptation
/// macOS and iPadOS/iOS layout differences are handled here via `#if os(macOS)` guards.
/// Typography uses Dynamic Type on all platforms.
///
/// ## Footnotes
/// Inline `footnoteMarker` nodes render as superscript numbers. Footnote bodies from
/// `model.footnotes` are rendered as a separate section below the document body.
///
/// ## Session 12 Note
/// This Session 06 renderer provides functional output for testing and the Search index
/// pipeline. The full Document view (typography, toolbar, citation, tags, persName popovers)
/// is built in Session 12. Replace the ContentView usage of this with Session 12's view
/// once available.
///
/// Version history:
///   1.0 — Session 06: initial implementation (functional, not final UI)
///   1.x — Session 42: footnote bodies and markers use `displayLabel`
///   1.1 — Session 54: `inlineAttributedString` path for paragraphs/footnotes that
///          contain `crossRefLink` nodes; links encoded as `frusexplorer://doc/…` URLs
///   1.2 — Session 63: crash fix — `.pageBreak` and `.figureBlock` added as explicit
///          cases in `inlineTextNode`, `inlineAttributedStringNode`, and
///          `extractInlineContent` to break the mutual-recursion stack overflow that
///          occurred when either node appeared inside an inline context (EXC_BAD_ACCESS)
///   1.3 — Session 65: `embedInScrollView` parameter added (default `true`) so the
///          caller can suppress the internal `ScrollView` when it provides its own;
///          `containsCrossRef` renamed to `containsInteractiveInline` and extended to
///          also trigger the `AttributedString` path for `persNameLink`/`glossLink`
///          nodes, with `frusexplorer://person/` and `frusexplorer://gloss/` link
///          attributes so taps route through the caller's `\.openURL` environment
public struct FRUSDocumentRenderer: View {

    public let model: FRUSDocumentRenderModel

    /// When `true` (the default), the renderer wraps its content in a `ScrollView`.
    /// Pass `false` when the parent view already owns a scroll container — nested
    /// `ScrollView`s on macOS capture both scroll and click events, breaking link
    /// taps and preventing scrolling back to the document top.
    private let embedInScrollView: Bool

    // Callbacks for interactive elements — invoked via the `\.openURL` environment
    // action (cross-ref, persName, gloss) rather than directly, so taps work in
    // both the `Text`-concat and `AttributedString` rendering paths.
    public var onFootnoteTap: ((Int) -> Void)?
    public var onPersNameTap: ((PersonEntry?) -> Void)?
    public var onGlossTap: ((GlossEntry?) -> Void)?
    public var onCrossRefTap: ((String, String?) -> Void)?

    public init(model: FRUSDocumentRenderModel,
                embedInScrollView: Bool = true,
                onFootnoteTap: ((Int) -> Void)? = nil,
                onPersNameTap: ((PersonEntry?) -> Void)? = nil,
                onGlossTap: ((GlossEntry?) -> Void)? = nil,
                onCrossRefTap: ((String, String?) -> Void)? = nil) {
        self.model = model
        self.embedInScrollView = embedInScrollView
        self.onFootnoteTap = onFootnoteTap
        self.onPersNameTap = onPersNameTap
        self.onGlossTap = onGlossTap
        self.onCrossRefTap = onCrossRefTap
    }

    /// The document body and footnotes as a vertically stacked content view,
    /// without a scroll container.  Factored out so `body` can conditionally
    /// wrap it in a `ScrollView` depending on `embedInScrollView`.
    private var contentStack: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(model.bodyNodes.enumerated()), id: \.offset) { _, node in
                blockView(node)
            }
            if !model.footnotes.isEmpty {
                Divider().padding(.vertical, 8)
                ForEach(Array(model.footnotes.enumerated()), id: \.offset) { _, fn in
                    blockView(fn)
                }
            }
        }
        .padding()
    }

    public var body: some View {
        if embedInScrollView {
            ScrollView { contentStack }
        } else {
            contentStack
        }
    }

    // MARK: - Block Rendering

    // Returns AnyView to break the recursive opaque-type inference cycle:
    // letterOpener/letterCloser/unknown all call blockView on their children,
    // which prevents Swift from resolving a concrete `some View` type.
    private func blockView(_ node: FRUSRenderNode) -> AnyView {
        switch node {
        case .heading(let children):
            AnyView(
                inlineText(children)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.bottom, 2)
            )

        case .dateline(let children):
            AnyView(
                inlineText(children)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            )

        case .letterOpener(let children):
            AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(blockOrInlineNodes(children).enumerated()), id: \.offset) { _, child in
                        blockView(child)
                    }
                }
            )

        case .letterCloser(let children):
            AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(blockOrInlineNodes(children).enumerated()), id: \.offset) { _, child in
                        blockView(child)
                    }
                }
            )

        case .salutation(let children):
            AnyView(inlineText(children).italic())

        case .paragraph(let children):
            AnyView(
                Group {
                    if containsInteractiveInline(children) {
                        Text(inlineAttributedString(children))
                    } else {
                        inlineText(children)
                    }
                }
                .font(.body)
            )

        case .footnoteBody(_, let type, _, _, let displayLabel, let children):
            AnyView(
                HStack(alignment: .top, spacing: 6) {
                    Text("\(displayLabel).")
                        .font(.footnote)
                        .foregroundStyle(footnoteColor(type))
                    Group {
                        if containsInteractiveInline(children) {
                            Text(inlineAttributedString(children))
                        } else {
                            inlineText(children)
                        }
                    }
                    .font(.footnote)
                }
            )

        case .pageBreak:
            // Not rendered visually; present for Session 30 citation lookup.
            AnyView(EmptyView())

        case .tableBlock(let rows):
            AnyView(
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                inlineText(cell.children)
                                    .font(.footnote)
                                    .padding(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(Rectangle().stroke(.separator, lineWidth: 0.5))
                            }
                        }
                    }
                }
                .overlay(Rectangle().stroke(.separator, lineWidth: 0.5))
                .padding(.vertical, 4)
            )

        case .listBlock(let type, let items):
            AnyView(
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 6) {
                            if type == "ordered" {
                                Text(verbatim: "\(index + 1).")
                                    .font(.body)
                                    .frame(width: 24, alignment: .trailing)
                            } else {
                                Text(verbatim: "•")
                                    .font(.body)
                                    .frame(width: 16, alignment: .trailing)
                            }
                            inlineText(item).font(.body)
                        }
                    }
                }
            )

        case .editorialNoteBlock(let children):
            AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(blockOrInlineNodes(children).enumerated()), id: \.offset) { _, child in
                        blockView(child)
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 3)
                }
            )

        case .figureBlock(let altText):
            AnyView(
                Text(verbatim: altText.map { "[Figure: \($0)]" } ?? "[Figure]")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.vertical, 2)
            )

        case .unknown(_, let children):
            AnyView(
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    blockView(child)
                }
            )

        default:
            // Inline nodes that appear at block level: render as a text run.
            AnyView(inlineText([node]))
        }
    }

    // MARK: - Inline Rendering

    /// Builds a SwiftUI `Text` from an array of inline render nodes.
    /// Uses `Text` string interpolation (the iOS 26+ replacement for `Text` concatenation via `+`).
    private func inlineText(_ nodes: [FRUSRenderNode]) -> Text {
        nodes.reduce(Text(verbatim: "")) { acc, node in
            Text("\(acc)\(inlineTextNode(node))")
        }
    }

    private func inlineTextNode(_ node: FRUSRenderNode) -> Text {
        switch node {
        case .plainText(let s):
            return Text(verbatim: s)

        case .boldText(let children):
            return inlineText(children).bold()

        case .italicText(let children):
            return inlineText(children).italic()

        case .smallCapsText(let children):
            return inlineText(children)

        case .underlineText(let children):
            return inlineText(children).underline()

        case .termText(let children):
            return inlineText(children).italic()

        case .footnoteMarker(_, let displayLabel):
            return Text(verbatim: displayLabel)
                .font(.system(size: 9))
                .baselineOffset(6)

        case .persNameLink(_, let children, _):
            return inlineText(children).foregroundColor(.accentColor)

        case .glossLink(_, let children, _):
            return inlineText(children).foregroundColor(.accentColor).underline()

        case .crossRefLink(_, _, let children):
            return inlineText(children).foregroundColor(.accentColor)

        case .suppliedText(let children):
            return Text("[\(inlineText(children))]")

        case .sicText(let children):
            return inlineText(children).strikethrough()

        case .corrText(let children):
            return inlineText(children)

        case .formulaText(let s):
            return Text(verbatim: s).italic()

        case .lineBreak:
            return Text(verbatim: "\n")

        case .unknown(_, let children):
            return inlineText(children)

        case .pageBreak:
            // Page breaks carry no visible text; suppress silently in inline context.
            return Text(verbatim: "")

        case .figureBlock(let altText):
            // Figures appear at block level; when encountered inline (e.g. inside a
            // paragraph) render the alt text in brackets as a graceful fallback.
            return altText.map { Text(verbatim: "[\($0)]").italic() } ?? Text(verbatim: "")

        default:
            // Block nodes within an inline context: extract text content.
            // NOTE: every case that `extractInlineContent` does NOT handle explicitly
            // (i.e. leaf-like nodes whose default returns [node]) MUST be handled above
            // to avoid infinite mutual recursion:
            //   inlineTextNode(X) → extractInlineContent(X) → [X] → inlineTextNode(X) → ∞
            return inlineText(extractInlineContent(node))
        }
    }

    // MARK: - Helpers

    /// Separates a mixed children array: block nodes stay as blocks, pure inline
    /// nodes are grouped into a single paragraph node for rendering.
    private func blockOrInlineNodes(_ nodes: [FRUSRenderNode]) -> [FRUSRenderNode] {
        var result: [FRUSRenderNode] = []
        var inlineBuffer: [FRUSRenderNode] = []
        for node in nodes {
            if isBlockNode(node) {
                if !inlineBuffer.isEmpty {
                    result.append(.paragraph(inlineBuffer))
                    inlineBuffer = []
                }
                result.append(node)
            } else {
                inlineBuffer.append(node)
            }
        }
        if !inlineBuffer.isEmpty { result.append(.paragraph(inlineBuffer)) }
        return result
    }

    private func isBlockNode(_ node: FRUSRenderNode) -> Bool {
        switch node {
        case .heading, .dateline, .letterOpener, .letterCloser, .salutation, .paragraph, .footnoteBody,
             .tableBlock, .listBlock, .editorialNoteBlock, .figureBlock, .pageBreak:
            return true
        default:
            return false
        }
    }

    /// Recursively extracts inline text content from a node (used for graceful degradation).
    private func extractInlineContent(_ node: FRUSRenderNode) -> [FRUSRenderNode] {
        switch node {
        case .paragraph(let c), .heading(let c), .dateline(let c),
             .letterOpener(let c), .letterCloser(let c), .salutation(let c),
             .boldText(let c), .italicText(let c), .smallCapsText(let c),
             .underlineText(let c), .termText(let c),
             .persNameLink(_, let c, _), .glossLink(_, let c, _), .crossRefLink(_, _, let c),
             .editorialNoteBlock(let c), .suppliedText(let c), .sicText(let c), .corrText(let c),
             .unknown(_, let c):
            return c.flatMap { extractInlineContent($0) }
        case .footnoteBody(_, _, _, _, _, let c):
            return c.flatMap { extractInlineContent($0) }
        case .listBlock(_, let items):
            return items.flatMap { $0 }.flatMap { extractInlineContent($0) }
        case .tableBlock(let rows):
            return rows.flatMap { $0 }.flatMap { $0.children }.flatMap { extractInlineContent($0) }
        case .pageBreak:
            // No text content; omit from inline extraction.
            return []
        case .figureBlock:
            // Figure alt text is handled by inlineTextNode/inlineAttributedStringNode
            // directly; returning [] here prevents the node from being re-entered.
            return []
        default:
            // Leaf nodes (.plainText, .formulaText, .lineBreak, .footnoteMarker, etc.)
            // are returned as-is; inlineTextNode handles them with explicit cases.
            return [node]
        }
    }

    private func footnoteColor(_ type: FootnoteType) -> Color {
        switch type {
        case .source: return .secondary
        case .editorial: return .accentColor
        default: return .primary
        }
    }

    // MARK: - Test hooks

    /// Exposes `inlineAttributedString` for unit testing via `@testable import`.
    func testInlineAttributedString(_ nodes: [FRUSRenderNode]) -> AttributedString {
        inlineAttributedString(nodes)
    }

    // MARK: - Interactive-inline AttributedString path

    /// Returns `true` when a node array contains any element that needs the
    /// `AttributedString` rendering path to be interactive.
    ///
    /// Triggers on:
    /// - `crossRefLink` — always interactive (encoded as `frusexplorer://doc/…`).
    /// - `persNameLink` with a non-nil ref or embedded entry — interactive
    ///   (encoded as `frusexplorer://person/{ref}`).
    /// - `glossLink` with a non-nil ref or embedded entry — interactive
    ///   (encoded as `frusexplorer://gloss/{ref}`).
    ///
    /// Only paragraphs that contain such nodes incur the `AttributedString`
    /// allocation; all other paragraphs use the faster `Text`-concat path.
    private func containsInteractiveInline(_ nodes: [FRUSRenderNode]) -> Bool {
        nodes.contains { node in
            switch node {
            case .crossRefLink:
                return true
            case .persNameLink(let ref, _, let person):
                return ref != nil || person != nil
            case .glossLink(let ref, _, let entry):
                return ref != nil || entry != nil
            case .boldText(let c), .italicText(let c), .smallCapsText(let c),
                 .underlineText(let c), .termText(let c),
                 .suppliedText(let c), .sicText(let c), .corrText(let c),
                 .paragraph(let c), .unknown(_, let c):
                return containsInteractiveInline(c)
            default: return false
            }
        }
    }

    /// Builds an `AttributedString` from inline render nodes.
    ///
    /// Cross-ref nodes embed a `frusexplorer://doc/{volumeId}/{documentId}` link
    /// attribute so that `Text(attributedString)` makes them tappable via SwiftUI's
    /// standard `openURL` environment action.
    ///
    /// All other styling (bold, italic, color) is applied through
    /// `AttributedString` container attributes so the result can be concatenated
    /// with `+` without losing attributes.
    private func inlineAttributedString(_ nodes: [FRUSRenderNode]) -> AttributedString {
        nodes.reduce(AttributedString()) { acc, node in
            acc + inlineAttributedStringNode(node)
        }
    }

    private func inlineAttributedStringNode(_ node: FRUSRenderNode) -> AttributedString {
        switch node {
        case .plainText(let s):
            return AttributedString(s)

        case .boldText(let c):
            var a = inlineAttributedString(c)
            a.font = .body.bold()
            return a

        case .italicText(let c):
            var a = inlineAttributedString(c)
            a.font = .body.italic()
            return a

        case .smallCapsText(let c):
            return inlineAttributedString(c)

        case .underlineText(let c):
            var a = inlineAttributedString(c)
            a.underlineStyle = .single
            return a

        case .termText(let c):
            var a = inlineAttributedString(c)
            a.font = .body.italic()
            return a

        case .persNameLink(let ref, let c, let person):
            var a = inlineAttributedString(c)
            a.foregroundColor = .accentColor
            // Encode as frusexplorer://person/{ref} so the parent's \.openURL
            // handler can look up the PersonEntry and open the detail sheet.
            let personRef = ref ?? person?.ref
            if let personRef, !personRef.isEmpty,
               let url = URL(string: "frusexplorer://person/\(personRef)") {
                a.link = url
            }
            return a

        case .glossLink(let ref, let c, let entry):
            var a = inlineAttributedString(c)
            a.foregroundColor = .accentColor
            a.underlineStyle = .single
            // Encode as frusexplorer://gloss/{ref} so the parent's \.openURL
            // handler can look up the GlossEntry and open the detail sheet.
            let glossRef = ref ?? entry?.ref
            if let glossRef, !glossRef.isEmpty,
               let url = URL(string: "frusexplorer://gloss/\(glossRef)") {
                a.link = url
            }
            return a

        case .crossRefLink(let target, let volumeId, let c):
            var a = inlineAttributedString(c)
            a.foregroundColor = .accentColor
            // Encode as frusexplorer://doc/{volumeId}/{documentId}
            // volumeId uses "_" as sentinel when absent (resolved at tap time).
            let docId = target.hasPrefix("#") ? String(target.dropFirst()) : target
            let vol   = volumeId ?? "_"
            if let url = URL(string: "frusexplorer://doc/\(vol)/\(docId)") {
                a.link = url
            }
            return a

        case .suppliedText(let c):
            return AttributedString("[") + inlineAttributedString(c) + AttributedString("]")

        case .sicText(let c):
            var a = inlineAttributedString(c)
            a.strikethroughStyle = .single
            return a

        case .corrText(let c):
            return inlineAttributedString(c)

        case .footnoteMarker(_, let label):
            var a = AttributedString(label)
            a.font = .system(size: 9)
            // Superscript is not directly expressible in AttributedString on SwiftUI;
            // fall back to plain small text. The Text path handles baseline offset.
            return a

        case .formulaText(let s):
            var a = AttributedString(s)
            a.font = .body.italic()
            return a

        case .pageBreak:
            // No text content in inline context.
            return AttributedString()

        case .figureBlock(let altText):
            // Graceful fallback: show bracketed alt text when a figure appears inside
            // a paragraph that uses the AttributedString rendering path.
            var a = AttributedString(altText.map { "[\($0)]" } ?? "")
            a.font = .body.italic()
            return a

        default:
            // Graceful degradation: extract plain text for any unhandled node type.
            // Same recursion guard as inlineTextNode: every case whose
            // extractInlineContent default returns [node] must be explicit here.
            let children = extractInlineContent(node)
            return inlineAttributedString(children)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct FRUSDocumentRenderer_Previews: PreviewProvider {
    static var previews: some View {
        FRUSDocumentRenderer(model: FRUSDocumentRenderModel(
            documentId: "preview",
            bodyNodes: [
                .heading([.plainText("1. Memorandum From the President's Special Assistant for National Security Affairs")]),
                .dateline([.plainText("Washington, January 20, 1969.")]),
                .paragraph([
                    .plainText("The President met with "),
                    .persNameLink(ref: "Kissinger", children: [.plainText("Dr. Kissinger")], person: nil),
                    .plainText(" to discuss "),
                    .italicText([.plainText("détente")]),
                    .plainText(" policy."),
                    .footnoteMarker(id: "fn1", displayLabel: "1")
                ])
            ],
            footnotes: [
                .footnoteBody(id: "fn1", type: .footnote, printedNumber: nil, sequentialNumber: 1, displayLabel: "1", children: [
                    .plainText("Source: National Security Council Files, Box 1.")
                ])
            ]
        ))
    }
}
#endif
