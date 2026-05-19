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
//   macOS — node-based renderer (no internal ScrollView; caller owns the scroll
//            container). Used by MacDocumentView and FootnoteSectionView. Interactive
//            elements (persName, gloss, crossRef, footnoteMarker) encoded as
//            frusexplorer:// link attributes in AttributedString; dispatched via a
//            single openURL handler on the root VStack.
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
//   1.5 — macOS: replaced FlowLayout with AttributedString inline rendering to fix
//          interactive elements appearing on a new row after long prose segments

#if os(macOS)

// ============================================================
// MARK: macOS Renderer
// ============================================================

/// Layer 3 of the TEI rendering pipeline (macOS).
///
/// Consumes `[FRUSRenderNode]` (Layer 2 output from `ASTToRenderNodeConverter`) and
/// produces SwiftUI views. Block nodes become `VStack` children; inline nodes are
/// rendered as `Text(AttributedString)` so that person names, gloss terms, and
/// cross-references remain semantically inline and word-wrap naturally with
/// surrounding prose.
///
/// ## Interactive Elements
/// Interactive nodes (`persNameLink`, `glossLink`, `crossRefLink`, `footnoteMarker`)
/// are encoded as `frusexplorer://` link attributes in the `AttributedString`. A
/// single `openURL` handler set on the renderer's root view dispatches each URL to
/// the appropriate callback closure:
/// - `persNameLink`   → `onPersonTap(PersonEntry?)`
/// - `glossLink`      → `onGlossTap(GlossEntry?)`
/// - `crossRefLink`   → `onCrossRefTap(target, volumeId)`
/// - `footnoteMarker` → `onFootnoteTap(displayLabel)`
///
/// No internal `ScrollView` — the caller owns the scroll container.
///
/// Version history:
///   1.5 — New UI: replaced FlowLayout with AttributedString inline rendering.
///          FlowLayout could not handle long text segments followed by interactive
///          inline elements: a multi-line prose text fills currentX=maxWidth, forcing
///          every subsequent element (persName, gloss, etc.) onto a new row instead
///          of flowing inline. AttributedString lets SwiftUI handle wrapping natively.
public struct FRUSDocumentRenderer: View {
    public let nodes: [FRUSRenderNode]
    public let onFootnoteTap: (String) -> Void
    public let onPersonTap: (PersonEntry?) -> Void
    public let onGlossTap: (GlossEntry?) -> Void
    public let onCrossRefTap: (String, String?) -> Void
    /// Vertical spacing between block-level nodes in the VStack.
    /// Pass a smaller value (e.g. 2) when rendering inside footnotes.
    private let blockSpacing: CGFloat

    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium

    public init(
        nodes: [FRUSRenderNode],
        onFootnoteTap: @escaping (String) -> Void,
        onPersonTap: @escaping (PersonEntry?) -> Void,
        onGlossTap: @escaping (GlossEntry?) -> Void,
        onCrossRefTap: @escaping (String, String?) -> Void,
        blockSpacing: CGFloat = 8
    ) {
        self.nodes = nodes
        self.onFootnoteTap = onFootnoteTap
        self.onPersonTap = onPersonTap
        self.onGlossTap = onGlossTap
        self.onCrossRefTap = onCrossRefTap
        self.blockSpacing = blockSpacing
    }

    public var body: some View {
        // Build lookup tables once so the openURL handler can resolve refs back to
        // model objects. LookupTables scans the node tree in O(n).
        let lookup = LookupTables(from: nodes)
        // Group consecutive inline nodes into paragraphs so block-level markers
        // (e.g. a footnoteMarker directly inside a <div>) don't get their own row.
        let normalizedNodes = blockOrInlineNodes(nodes)
        return VStack(alignment: .leading, spacing: blockSpacing) {
            ForEach(Array(normalizedNodes.enumerated()), id: \.offset) { _, node in
                AnyView(blockView(for: node))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "frusexplorer" else { return .discarded }
            // url.pathComponents always includes "/" as first element; filter it out.
            let parts = url.pathComponents.filter { $0 != "/" }
            switch url.host {
            case "person":
                onPersonTap(parts.first.flatMap { lookup.persons[$0] })
                return .handled
            case "gloss":
                onGlossTap(parts.first.flatMap { lookup.glosses[$0] })
                return .handled
            case "doc":
                guard parts.count >= 2 else { return .handled }
                let vol = parts[0]
                onCrossRefTap(parts[1], vol.isEmpty || vol == "_" ? nil : vol)
                return .handled
            case "footnote":
                if let label = parts.first { onFootnoteTap(label) }
                return .handled
            default:
                return .discarded
            }
        })
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
                .font(.system(size: textSize.bodyFontSize))

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
                .font(.system(size: textSize.bodyFontSize))

        case .editorialNoteBlock(let children):
            let normalizedEditorial = blockOrInlineNodes(children)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(normalizedEditorial.enumerated()), id: \.offset) { _, child in
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

        // lineBreak at block level: intentionally zero height.
        case .lineBreak:
            EmptyView()

        // Footnote bodies collected by FootnoteSectionView; not rendered inline.
        case .footnoteBody:
            EmptyView()

        case .pageBreak:
            EmptyView()

        // Unknown elements (e.g. <ab>, <div type="annex">) may contain block children.
        // Render them by iterating children through blockView so block structure is
        // preserved. Without this case, .unknown falls through to default and
        // extractInlineChildren flattens all block content into a single inline Text.
        case .unknown(_, let children):
            let normalized = blockOrInlineNodes(children)
            VStack(alignment: .leading, spacing: blockSpacing) {
                ForEach(Array(normalized.enumerated()), id: \.offset) { _, child in
                    AnyView(blockView(for: child))
                }
            }

        // Inline nodes at block level — wrap in a paragraph.
        default:
            inlineText([node])
                .font(.system(size: textSize.bodyFontSize))
        }
    }

    // MARK: - Inline Text

    /// Renders inline nodes as a single `Text` view backed by an `AttributedString`.
    ///
    /// Using a single `Text` view (rather than separate views in a `FlowLayout`) lets
    /// SwiftUI handle line-wrapping natively: interactive elements (persName, gloss,
    /// crossRef) remain semantically inline with surrounding prose regardless of where
    /// the line breaks fall.
    func inlineText(_ children: [FRUSRenderNode]) -> Text {
        Text(macAttrString(children))
    }

    // MARK: - AttributedString Builder

    func macAttrString(_ nodes: [FRUSRenderNode]) -> AttributedString {
        nodes.reduce(AttributedString()) { $0 + macAttrNode($1) }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func macAttrNode(_ node: FRUSRenderNode) -> AttributedString {
        switch node {
        case .plainText(let s):
            return AttributedString(s)

        case .boldText(let c):
            var a = macAttrString(c)
            a.font = .system(size: textSize.bodyFontSize).bold()
            return a

        case .italicText(let c):
            var a = macAttrString(c)
            a.font = .system(size: textSize.bodyFontSize).italic()
            return a

        case .smallCapsText(let c):
            // AttributedString has no direct small-caps variant; render as normal.
            return macAttrString(c)

        case .underlineText(let c):
            var a = macAttrString(c)
            a.underlineStyle = .single
            return a

        case .termText(let c):
            var a = macAttrString(c)
            a.font = .system(size: textSize.bodyFontSize).italic()
            a.foregroundColor = .secondary
            return a

        case .suppliedText(let c):
            return AttributedString("[") + macAttrString(c) + AttributedString("]")

        case .sicText(let c):
            var a = macAttrString(c)
            a.strikethroughStyle = .single
            return a

        case .corrText(let c):
            return macAttrString(c)

        case .formulaText(let s):
            var a = AttributedString(s)
            a.font = .system(size: textSize.bodyFontSize).italic()
            return a

        case .lineBreak:
            // Inline <lb/> carries no layout meaning in a reflowing window; skip.
            return AttributedString()

        case .footnoteMarker(_, let label):
            var a = AttributedString(label)
            a.font = .system(size: 10)
            a.baselineOffset = 6
            a.foregroundColor = .accentColor
            if let url = URL(string: "frusexplorer://footnote/\(label)") { a.link = url }
            return a

        case .persNameLink(let ref, let c, let person):
            var a = macAttrString(c)
            a.foregroundColor = .teal
            a.underlineStyle = Text.LineStyle(pattern: .dash)
            // Only make tappable when a ref is available; anonymous persName nodes
            // (no corresp, no resolved PersonEntry) are styled but not interactive.
            let rawRef = ref ?? person?.ref
            if let rawRef, !rawRef.isEmpty {
                let key = rawRef.hasPrefix("#") ? String(rawRef.dropFirst()) : rawRef
                if let url = URL(string: "frusexplorer://person/\(key)") { a.link = url }
            }
            return a

        case .glossLink(let ref, let c, let entry):
            var a = macAttrString(c)
            a.foregroundColor = Color.secondary
            a.font = .system(size: textSize.bodyFontSize).italic()
            let rawRef = ref ?? entry?.ref
            if let rawRef, !rawRef.isEmpty {
                let key = rawRef.hasPrefix("#") ? String(rawRef.dropFirst()) : rawRef
                if let url = URL(string: "frusexplorer://gloss/\(key)") { a.link = url }
            }
            return a

        case .crossRefLink(let target, let volumeId, let c):
            var a = macAttrString(c)
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

        case .pageBreak, .figureBlock:
            return AttributedString()

        default:
            // Block-level wrapper found in inline context: extract leaf children.
            return extractInlineChildren(node).reduce(AttributedString()) { $0 + macAttrNode($1) }
        }
    }

    // MARK: - Lookup Tables (for openURL dispatch)

    /// Maps normalised ref strings → resolved model objects so the `openURL` handler
    /// can pass a `PersonEntry?` / `GlossEntry?` to the tap callbacks.
    private struct LookupTables {
        var persons: [String: PersonEntry] = [:]
        var glosses: [String: GlossEntry] = [:]

        init(from nodes: [FRUSRenderNode]) {
            collect(nodes)
        }

        private mutating func collect(_ nodes: [FRUSRenderNode]) {
            for node in nodes {
                switch node {
                case .persNameLink(let ref, let c, let person):
                    if let person {
                        let rawRef = ref ?? person.ref
                        let key = rawRef.hasPrefix("#") ? String(rawRef.dropFirst()) : rawRef
                        persons[key] = person
                    }
                    collect(c)
                case .glossLink(let ref, let c, let entry):
                    if let entry {
                        let rawRef = ref ?? entry.ref
                        let key = rawRef.hasPrefix("#") ? String(rawRef.dropFirst()) : rawRef
                        glosses[key] = entry
                    }
                    collect(c)
                case .paragraph(let c), .heading(let c), .dateline(let c),
                     .salutation(let c), .letterOpener(let c), .letterCloser(let c),
                     .editorialNoteBlock(let c), .boldText(let c), .italicText(let c),
                     .smallCapsText(let c), .underlineText(let c), .termText(let c),
                     .suppliedText(let c), .sicText(let c), .corrText(let c),
                     .unknown(_, let c), .crossRefLink(_, _, let c):
                    collect(c)
                case .footnoteBody(_, _, _, _, _, let c):
                    collect(c)
                case .listBlock(_, let items):
                    items.forEach { collect($0) }
                case .tableBlock(let rows):
                    rows.forEach { row in row.forEach { collect($0.children) } }
                default:
                    break
                }
            }
        }
    }

    /// Extracts leaf inline nodes from a block-level wrapper so block nodes that
    /// appear in inline context can still contribute their text content.
    private func extractInlineChildren(_ node: FRUSRenderNode) -> [FRUSRenderNode] {
        switch node {
        case .paragraph(let c), .heading(let c), .dateline(let c),
             .letterOpener(let c), .letterCloser(let c), .salutation(let c),
             .boldText(let c), .italicText(let c), .smallCapsText(let c),
             .underlineText(let c), .termText(let c), .suppliedText(let c),
             .sicText(let c), .corrText(let c), .editorialNoteBlock(let c),
             .unknown(_, let c):
            return c.flatMap { extractInlineChildren($0) }
        case .footnoteBody:
            // Never inline footnote body content; it belongs in FootnoteSectionView.
            return []
        case .listBlock(_, let items):
            return items.flatMap { $0 }.flatMap { extractInlineChildren($0) }
        case .pageBreak, .figureBlock:
            return []
        default:
            return [node]
        }
    }

    private func isBlockNode(_ node: FRUSRenderNode) -> Bool {
        switch node {
        case .heading, .dateline, .letterOpener, .letterCloser, .salutation, .paragraph,
             .footnoteBody, .tableBlock, .listBlock, .editorialNoteBlock, .figureBlock,
             .pageBreak, .unknown:
            return true
        default:
            return false
        }
    }

    /// Groups consecutive inline nodes into `.paragraph` wrappers so they render as
    /// a single `Text` run rather than each getting their own VStack row.
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

    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium

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
                .font(.system(size: textSize.bodyFontSize))
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
                                    .font(.system(size: textSize.bodyFontSize))
                                    .frame(width: 24, alignment: .trailing)
                            } else {
                                Text(verbatim: "•")
                                    .font(.system(size: textSize.bodyFontSize))
                                    .frame(width: 16, alignment: .trailing)
                            }
                            inlineText(item).font(.system(size: textSize.bodyFontSize))
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
