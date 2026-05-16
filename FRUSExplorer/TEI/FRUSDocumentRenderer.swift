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
public struct FRUSDocumentRenderer: View {

    public let model: FRUSDocumentRenderModel

    // Callbacks for interactive elements — wired up in Session 12.
    public var onFootnoteTap: ((Int) -> Void)?
    public var onPersNameTap: ((PersonEntry?) -> Void)?
    public var onGlossTap: ((GlossEntry?) -> Void)?
    public var onCrossRefTap: ((String, String?) -> Void)?

    public init(model: FRUSDocumentRenderModel,
                onFootnoteTap: ((Int) -> Void)? = nil,
                onPersNameTap: ((PersonEntry?) -> Void)? = nil,
                onGlossTap: ((GlossEntry?) -> Void)? = nil,
                onCrossRefTap: ((String, String?) -> Void)? = nil) {
        self.model = model
        self.onFootnoteTap = onFootnoteTap
        self.onPersNameTap = onPersNameTap
        self.onGlossTap = onGlossTap
        self.onCrossRefTap = onCrossRefTap
    }

    public var body: some View {
        ScrollView {
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
                inlineText(children)
                    .font(.body)
            )

        case .footnoteBody(_, let type, _, _, let displayLabel, let children):
            AnyView(
                HStack(alignment: .top, spacing: 6) {
                    Text("\(displayLabel).")
                        .font(.footnote)
                        .foregroundStyle(footnoteColor(type))
                    inlineText(children).font(.footnote)
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

        default:
            // Block nodes within an inline context: extract text content.
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
        default:
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
