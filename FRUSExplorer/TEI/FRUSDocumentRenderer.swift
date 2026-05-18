// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - FRUSDocumentRenderer
//
// Platform-conditional implementation:
//
//   macOS — new node-based renderer (no internal ScrollView; caller owns the scroll
//            container). Used by MacDocumentView and FootnoteSectionView. Supports
//            interactive elements (persName, gloss, crossRef, footnoteMarker) via
//            Button overlays arranged by FlowLayout.
//
//   iOS   — original model-based renderer with optional internal ScrollView and
//            AttributedString cross-ref / persName / gloss encoding via frusexplorer://
//            deep-link URLs. Preserved unchanged from Session 66.
//
// Version history:
//   1.0 — Session 06: initial implementation (functional, not final UI)
//   1.x — Session 42: footnote bodies and markers use `displayLabel`
//   1.1 — Session 54: `inlineAttributedString` path for paragraphs/footnotes that
//          contain `crossRefLink` nodes; links encoded as `frusexplorer://doc/…` URLs
//   1.2 — Session 63: crash fix — `.pageBreak` and `.figureBlock` added as explicit
//          cases in `inlineTextNode`, `inlineAttributedStringNode`, and
//          `extractInlineContent` to break the mutual-recursion stack overflow
//   1.3 — Session 65: `embedInScrollView` parameter added (iOS); nested-scroll fix
//   1.4 — Session 66: URL encoding fix for `#` in persName/gloss/crossRef refs
//   1.5 — New UI scaffolding: macOS renderer replaced with new FlowLayout-based
//          node-array interface; iOS renderer preserved unchanged

#if os(macOS)

// ============================================================
// MARK: macOS Renderer
// ============================================================

/// Layer 3 of the TEI rendering pipeline (macOS).
///
/// Consumes `[FRUSRenderNode]` (Layer 2 output from `ASTToRenderNodeConverter`) and
/// produces SwiftUI views. Block nodes become `VStack` children; inline nodes are
/// accumulated into segments within a `FlowLayout`.
///
/// ## Footnote Handling
/// `footnoteMarker` nodes trigger `onFootnoteTap(displayLabel)` which the parent
/// (`MacDocumentView`) uses to highlight the corresponding footnote in
/// `FootnoteSectionView`. Footnote bodies are rendered by `FootnoteSectionView`,
/// not here — callers should pass only `model.bodyNodes`, not `model.footnotes`.
///
/// ## Interactive Elements
/// - `persNameLink` → `onPersonTap(PersonEntry?)`
/// - `glossLink`    → `onGlossTap(GlossEntry?)`
/// - `crossRefLink` → `onCrossRefTap(target, volumeId)`
///
/// No internal `ScrollView` — the caller (`MacDocumentView`) owns the scroll container.
public struct FRUSDocumentRenderer: View {
    public let nodes: [FRUSRenderNode]
    public let onFootnoteTap: (String) -> Void
    public let onPersonTap: (PersonEntry?) -> Void
    public let onGlossTap: (GlossEntry?) -> Void
    public let onCrossRefTap: (String, String?) -> Void

    public init(
        nodes: [FRUSRenderNode],
        onFootnoteTap: @escaping (String) -> Void,
        onPersonTap: @escaping (PersonEntry?) -> Void,
        onGlossTap: @escaping (GlossEntry?) -> Void,
        onCrossRefTap: @escaping (String, String?) -> Void
    ) {
        self.nodes = nodes
        self.onFootnoteTap = onFootnoteTap
        self.onPersonTap = onPersonTap
        self.onGlossTap = onGlossTap
        self.onCrossRefTap = onCrossRefTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                AnyView(blockView(for: node))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Block Dispatch

    @ViewBuilder
    func blockView(for node: FRUSRenderNode) -> some View {
        switch node {
        case .heading(let children):
            inlineText(children)
                .font(.system(size: 18, weight: .medium))
                .padding(.bottom, 2)

        case .dateline(let children):
            inlineText(children)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

        case .paragraph(let children):
            inlineText(children)
                .font(.body)

        case .letterOpener(let children):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    AnyView(blockView(for: child))
                }
            }

        case .letterCloser(let children):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    AnyView(blockView(for: child))
                }
            }
            .padding(.top, 8)

        case .salutation(let children):
            inlineText(children)
                .font(.body)

        case .editorialNoteBlock(let children):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    AnyView(blockView(for: child))
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )

        case .tableBlock(let rows):
            TableBlockView(rows: rows)

        case .listBlock(let type, let items):
            ListBlockView(type: type, items: items, renderer: self)

        case .figureBlock(let altText):
            HStack {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
                if let alt = altText {
                    Text(alt)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 4))

        case .lineBreak:
            Divider().opacity(0)

        // Footnote bodies collected by FootnoteSectionView; not rendered inline
        case .footnoteBody:
            EmptyView()

        case .pageBreak:
            EmptyView()

        // Inline nodes at block level — wrap in a paragraph
        default:
            inlineText([node])
                .font(.body)
        }
    }

    // MARK: - Inline Text Accumulation

    @ViewBuilder
    func inlineText(_ children: [FRUSRenderNode]) -> some View {
        FlowLayout(spacing: 0) {
            ForEach(Array(inlineSegments(children).enumerated()), id: \.offset) { _, segment in
                inlineSegmentView(segment)
            }
        }
    }

    @ViewBuilder
    private func inlineSegmentView(_ segment: InlineSegment) -> some View {
        switch segment {
        case .text(let s, let attrs):
            Text(s)
                .applyInlineAttributes(attrs)

        case .footnoteMarker(let label):
            Button {
                onFootnoteTap(label)
            } label: {
                Text(label)
                    .font(.system(size: 10))
                    .baselineOffset(6)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

        case .persName(let text, let person):
            Button {
                onPersonTap(person)
            } label: {
                Text(text)
                    .underline(true, pattern: .dash)
                    .foregroundStyle(.teal)
            }
            .buttonStyle(.plain)

        case .gloss(let text, let entry):
            Button {
                onGlossTap(entry)
            } label: {
                Text(text)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            .buttonStyle(.plain)

        case .crossRef(let text, let target, let volumeId):
            Button {
                onCrossRefTap(target, volumeId)
            } label: {
                Text(text)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Inline Segment Extraction

    enum InlineAttributes {
        case bold, italic, smallCaps, underline, supplied, sic, corr, term
    }

    enum InlineSegment {
        case text(String, Set<InlineAttributes>)
        case footnoteMarker(String)
        case persName(String, PersonEntry?)
        case gloss(String, GlossEntry?)
        case crossRef(String, String, String?)
    }

    func inlineSegments(_ nodes: [FRUSRenderNode], attrs: Set<InlineAttributes> = []) -> [InlineSegment] {
        var result: [InlineSegment] = []
        for node in nodes {
            switch node {
            case .plainText(let s):
                result.append(.text(s, attrs))

            case .boldText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.bold])))

            case .italicText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.italic])))

            case .smallCapsText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.smallCaps])))

            case .underlineText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.underline])))

            case .termText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.term])))

            case .suppliedText(let c):
                result.append(.text("[", attrs))
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.supplied])))
                result.append(.text("]", attrs))

            case .sicText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs.union([.sic])))

            case .corrText(let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs))

            case .formulaText(let s):
                result.append(.text(s, attrs.union([.italic])))

            case .lineBreak:
                result.append(.text("\n", attrs))

            case .footnoteMarker(_, let label):
                result.append(.footnoteMarker(label))

            case .persNameLink(_, let children, let person):
                let text = children.compactMap {
                    if case .plainText(let s) = $0 { return s } else { return nil }
                }.joined(separator: "")
                result.append(.persName(text, person))

            case .glossLink(_, let children, let entry):
                let text = children.compactMap {
                    if case .plainText(let s) = $0 { return s } else { return nil }
                }.joined(separator: "")
                result.append(.gloss(text, entry))

            case .crossRefLink(let target, let volumeId, let children):
                let text = children.compactMap {
                    if case .plainText(let s) = $0 { return s } else { return nil }
                }.joined(separator: "")
                result.append(.crossRef(text.isEmpty ? target : text, target, volumeId))

            case .pageBreak:
                break

            case .unknown(_, let c):
                result.append(contentsOf: inlineSegments(c, attrs: attrs))

            // Block elements inside inline context — skip gracefully
            default:
                break
            }
        }
        return result
    }
}

// MARK: - Text Attribute Application (macOS)

extension Text {
    /// Applies inline formatting attributes and returns a new `Text`.
    /// Uses only `Text`-returning modifiers so the return type stays `Text`,
    /// avoiding `@ViewBuilder` incompatibility with imperative mutation.
    func applyInlineAttributes(_ attrs: Set<FRUSDocumentRenderer.InlineAttributes>?) -> Text {
        let a = attrs ?? []
        var t = self
        if a.contains(.bold)      { t = t.bold() }
        if a.contains(.italic)    { t = t.italic() }
        if a.contains(.underline) { t = t.underline() }
        if a.contains(.sic)       { t = t.strikethrough() }
        // Small-caps: use lowercaseSmallCaps font variant (returns Text).
        if a.contains(.smallCaps) { t = t.font(Font.system(.body).lowercaseSmallCaps()) }
        // Term: secondary foreground colour via foregroundColor (returns Text; foregroundStyle does not).
        if a.contains(.term)      { t = t.foregroundColor(.secondary) }
        return t
    }
}

// MARK: - TableBlockView (macOS)

private struct TableBlockView: View {
    let rows: [[TableCell]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rIdx, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { cIdx, cell in
                        VStack(alignment: .leading) {
                            Text(cell.children.map { plainText($0) }.joined())
                                .font(.system(size: 12))
                                .padding(6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .trailing) {
                            if cIdx < row.count - 1 { Divider() }
                        }
                    }
                }
                .background(rIdx == 0 ? Color.secondary.opacity(0.06) : Color.clear)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private func plainText(_ node: FRUSRenderNode) -> String {
        if case .plainText(let s) = node { return s } else { return "" }
    }
}

// MARK: - ListBlockView (macOS)

private struct ListBlockView: View {
    let type: String?
    let items: [[FRUSRenderNode]]
    let renderer: FRUSDocumentRenderer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(type == "ordered" ? "\(idx + 1)." : "•")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 18, alignment: .trailing)
                    renderer.inlineText(item)
                }
            }
        }
    }
}

// MARK: - FlowLayout (macOS)

/// Left-to-right flow layout for inline text segments.
/// Wraps to the next line when the available width is exhausted.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#else

// ============================================================
// MARK: iOS Renderer (preserved from Session 66)
// ============================================================

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
///   1.4 — Session 66: fix URL encoding for FRUS XML ID-reference "#" prefix:
///          `persName@ref="#p1"` and `gloss@ref="#t1"` had the `#` treated as a
///          URL fragment delimiter, making pathComponents empty in the openURL
///          handler; cross-volume `target="vol#docId"` had the same issue when the
///          full string (including "#") was used as the URL path segment
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
            AnyView(inlineText([node]))
        }
    }

    // MARK: - Inline Rendering

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
            return Text(verbatim: "")
        case .figureBlock(let altText):
            return altText.map { Text(verbatim: "[\($0)]").italic() } ?? Text(verbatim: "")
        default:
            return inlineText(extractInlineContent(node))
        }
    }

    // MARK: - Helpers

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
            return []
        case .figureBlock:
            return []
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

    // MARK: - Test hooks

    func testInlineAttributedString(_ nodes: [FRUSRenderNode]) -> AttributedString {
        inlineAttributedString(nodes)
    }

    // MARK: - Interactive-inline AttributedString path

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
            var a = inlineAttributedString(c); a.font = .body.bold(); return a
        case .italicText(let c):
            var a = inlineAttributedString(c); a.font = .body.italic(); return a
        case .smallCapsText(let c):
            return inlineAttributedString(c)
        case .underlineText(let c):
            var a = inlineAttributedString(c); a.underlineStyle = .single; return a
        case .termText(let c):
            var a = inlineAttributedString(c); a.font = .body.italic(); return a
        case .persNameLink(let ref, let c, let person):
            var a = inlineAttributedString(c)
            a.foregroundColor = .accentColor
            let rawPersonRef = ref ?? person?.ref
            let personRef = rawPersonRef.map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            if let personRef, !personRef.isEmpty,
               let url = URL(string: "frusexplorer://person/\(personRef)") {
                a.link = url
            }
            return a
        case .glossLink(let ref, let c, let entry):
            var a = inlineAttributedString(c)
            a.foregroundColor = .accentColor; a.underlineStyle = .single
            let rawGlossRef = ref ?? entry?.ref
            let glossRef = rawGlossRef.map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
            if let glossRef, !glossRef.isEmpty,
               let url = URL(string: "frusexplorer://gloss/\(glossRef)") {
                a.link = url
            }
            return a
        case .crossRefLink(let target, let volumeId, let c):
            var a = inlineAttributedString(c)
            a.foregroundColor = .accentColor
            let docId: String
            if target.hasPrefix("#") {
                docId = String(target.dropFirst())
            } else if let hashIdx = target.firstIndex(of: "#") {
                docId = String(target[target.index(after: hashIdx)...])
            } else {
                docId = target
            }
            let vol = volumeId ?? "_"
            if let url = URL(string: "frusexplorer://doc/\(vol)/\(docId)") { a.link = url }
            return a
        case .suppliedText(let c):
            return AttributedString("[") + inlineAttributedString(c) + AttributedString("]")
        case .sicText(let c):
            var a = inlineAttributedString(c); a.strikethroughStyle = .single; return a
        case .corrText(let c):
            return inlineAttributedString(c)
        case .footnoteMarker(_, let label):
            var a = AttributedString(label); a.font = .system(size: 9); return a
        case .formulaText(let s):
            var a = AttributedString(s); a.font = .body.italic(); return a
        case .pageBreak:
            return AttributedString()
        case .figureBlock(let altText):
            var a = AttributedString(altText.map { "[\($0)]" } ?? "")
            a.font = .body.italic()
            return a
        default:
            return inlineAttributedString(extractInlineContent(node))
        }
    }
}

// MARK: - Preview Support (iOS)

#if DEBUG
struct FRUSDocumentRenderer_Previews: PreviewProvider {
    static var previews: some View {
        FRUSDocumentRenderer(model: FRUSDocumentRenderModel(
            documentId: "preview",
            bodyNodes: [
                .heading([.plainText("1. Memorandum From the President's Special Assistant")]),
                .dateline([.plainText("Washington, January 20, 1969.")]),
                .paragraph([
                    .plainText("The President met with "),
                    .persNameLink(ref: "Kissinger", children: [.plainText("Dr. Kissinger")], person: nil),
                    .plainText(" to discuss policy."),
                    .footnoteMarker(id: "fn1", displayLabel: "1")
                ])
            ],
            footnotes: [
                .footnoteBody(id: "fn1", type: .footnote, printedNumber: nil, sequentialNumber: 1,
                              displayLabel: "1",
                              children: [.plainText("Source: NSC Files, Box 1.")])
            ]
        ))
    }
}
#endif

#endif // !os(macOS)
