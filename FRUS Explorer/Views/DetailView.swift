// DetailView.swift
// Right column: renders FRUS documents and editorial notes matching the
// presentation style of history.state.gov.
//
// Rendering hierarchy:
//   DetailView
//     DocumentDetailView          — toolbar, summary card, scroll container
//       SummaryCard               — AI summary with profile badge + regenerate
//       FRUSDocumentView          — the full document rendering
//         DocumentHeaderBlock     — source line, doc number, headings, dateline, opener
//         DocumentBodyBlock       — paragraphs, sub-sections, closer (recursive)
//         FootnotesBlock          — all footnotes collected from the full tree
//
// White-space contract: all `.text` nodes coming from the parser are already
// normalised (internal whitespace collapsed, leading/trailing trimmed to at most
// one space). FRUSDocumentView does a final trim when composing AttributedStrings.

import SwiftUI

// MARK: - DetailView (router)

struct DetailView: View {
    @Environment(AppStore.self) private var store: AppStore

    private var selectedNode: (volume: LoadedVolume, division: Division)? {
        guard let volID = store.selectedVolumeID,
              let vol  = store.loadedVolumes[volID],
              let nodeID = store.selectedNodeID
        else { return nil }
        return findDivision(nodeID: nodeID, volume: vol).map { (vol, $0) }
    }

    var body: some View {
        Group {
            if let pair = selectedNode {
                DocumentDetailView(volume: pair.volume, division: pair.division)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48)).foregroundStyle(.tertiary)
            Text("Select a document or note in the outline to read its full content.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func findDivision(nodeID: String, volume: LoadedVolume) -> Division? {
        let vol = volume.volume
        let volID = volume.id
        return vol.text.body.divisions.findDivisionByNodeID(nodeID, volumeID: volID)
            ?? (vol.text.front?.divisions ?? []).findDivisionByNodeID(nodeID, volumeID: volID)
            ?? (vol.text.back?.divisions  ?? []).findDivisionByNodeID(nodeID, volumeID: volID)
    }
}

// MARK: - DocumentDetailView

struct DocumentDetailView: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(CollectionStore.self) private var collectionStore: CollectionStore
    let volume: LoadedVolume
    let division: Division
    var backgroundColor: Color {
#if os(macOS)
        return Color(NSColor.textBackgroundColor)
#else
        return Color(UIColor.systemBackground)
#endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // AI summary card
                if let state = store.summary(for: division) {
                    SummaryCard(state: state, division: division)
                        .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 8)
                }

                // Full document
                FRUSDocumentView(division: division, volumeID: volume.id)
                    .padding(.horizontal, 28).padding(.vertical, 16)

                Spacer(minLength: 48)
            }
        }
        .background(self.backgroundColor)
        .toolbar { detailToolbar }
        .task(id: division.id) { store.summarise(division) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if collectionStore.collections.isEmpty {
                    Button("Add to New Collection") { addToNewCollection() }
                } else {
                    ForEach(collectionStore.collections) { col in
                        Button(col.name) { addToCollection(col) }
                    }
                    Divider()
                    Button("New Collection…") { addToNewCollection() }
                }
            } label: {
                Label("Add to Collection", systemImage: "rectangle.stack.badge.plus")
            }
            .help("Add this document to a collection")
        }
    }

    private func addToCollection(_ collection: DocumentCollection) {
        guard let divID = division.id else { return }
        collectionStore.addItem(CollectionItem(
            volumeID: volume.id, divisionID: divID,
            cachedTitle: division.title ?? "(untitled)",
            cachedDateline: division.dateline.map { FRUSRenderer.plainText($0.content) },
            isEditorialNote: false
        ), to: collection)
    }

    private func addToNewCollection() {
        let col = collectionStore.create(name: division.title ?? "New Collection")
        addToCollection(col)
    }
}

// MARK: - SummaryCard

struct SummaryCard: View {
    @Environment(AppStore.self) private var store: AppStore
    @Environment(PromptProfileStore.self) private var profileStore: PromptProfileStore
    let state: SummaryState
    let division: Division

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.caption).foregroundStyle(.purple)
                Text("Apple Intelligence Summary")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.purple)
                Spacer()
                Text(profileStore.activeProfile.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.purple.opacity(0.8))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.purple.opacity(0.1), in: Capsule())
                Button {
                    store.regenerateSummary(for: division)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10)).foregroundStyle(.purple.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Regenerate summary using the current profile")
                .disabled(state == .generating)
            }
            switch state {
            case .generating:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Generating summary…")
                        .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
                }
            case .ready(let text):
                Text(text)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.primary).lineSpacing(4)
            case .failed(let err):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                    Text(err).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.purple.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.purple.opacity(0.18), lineWidth: 1))
        }
    }
}

// MARK: - FRUSDocumentView

/// Full document renderer: header + body + footnotes, matching history.state.gov layout.
struct FRUSDocumentView: View {
    let division: Division
    let volumeID: String

    /// All footnotes collected in document order from the entire division tree.
    private var footnotes: [Note] {
        FRUSRenderer.collectFootnotes(from: division)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DocumentHeaderBlock(division: division, volumeID: volumeID)
            DocumentBodyBlock(division: division, footnotes: footnotes, depth: 0)
                .padding(.top, 14)
            if !footnotes.isEmpty {
                FootnotesBlock(notes: footnotes)
                    .padding(.top, 20)
            }
        }
    }
}

// MARK: - DocumentHeaderBlock

/// Renders the FRUS document header: source line, document number, all headings,
/// dateline, and opener — matching history.state.gov exactly.
struct DocumentHeaderBlock: View {
    let division: Division
    let volumeID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Source / volume attribution (muted italic — matches HSG site)
            Text("Foreign Relations of the United States · \(volumeID)")
                .font(.system(size: 9, design: .serif))
                .foregroundStyle(.tertiary)
                .italic()

            // Document number badge
            if let n = division.number {
                Text("Document \(n)")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 2)
            }

            // All headings: first = type (largest), subsequent = subject
            ForEach(Array(division.headings.enumerated()), id: \.offset) { idx, heading in
                Text(FRUSRenderer.attributedString(heading.content))
                    .font(idx == 0
                          ? .system(size: 18, weight: .bold, design: .serif)
                          : .system(size: 14, weight: .semibold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, idx == 0 ? 4 : 0)
            }

            // Dateline
            if let dl = division.dateline, !dl.content.isEmpty {
                Text(FRUSRenderer.attributedString(dl.content))
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            // Opener (salutation, addressee line)
            if let op = division.opener, !op.content.isEmpty {
                Text(FRUSRenderer.attributedString(op.content))
                    .font(.system(size: 13, design: .serif))
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - DocumentBodyBlock

/// Renders body paragraphs, sub-sections, and closer recursively.
struct DocumentBodyBlock: View {
    let division: Division
    let footnotes: [Note]
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Body paragraphs
            ForEach(Array(division.paragraphs.enumerated()), id: \.offset) { _, para in
                ParagraphBlock(paragraph: para, footnotes: footnotes)
            }

            // Nested child divisions (annexes, enclosures, multi-part docs)
            ForEach(Array(division.children.enumerated()), id: \.offset) { _, child in
                VStack(alignment: .leading, spacing: 6) {
                    // Sub-section rule
                    if depth == 0 {
                        Divider().padding(.vertical, 4)
                    }
                    // Sub-section headings
                    ForEach(Array(child.headings.enumerated()), id: \.offset) { idx, heading in
                        Text(FRUSRenderer.attributedString(heading.content))
                            .font(idx == 0
                                  ? .system(size: 14, weight: .semibold, design: .serif)
                                  : .system(size: 13, weight: .medium, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Sub-section dateline
                    if let dl = child.dateline, !dl.content.isEmpty {
                        Text(FRUSRenderer.attributedString(dl.content))
                            .font(.system(size: 12, design: .serif))
                            .italic().foregroundStyle(.secondary)
                    }
                    // Sub-section opener
                    if let op = child.opener, !op.content.isEmpty {
                        Text(FRUSRenderer.attributedString(op.content))
                            .font(.system(size: 13, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Recurse
                    DocumentBodyBlock(division: child, footnotes: footnotes, depth: depth + 1)
                }
                .padding(.leading, depth > 0 ? 16 : 0)
            }

            // Closer (signature block)
            if let closer = division.closer, !closer.content.isEmpty {
                CloserBlock(closer: closer)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - ParagraphBlock

/// Renders a single `<p>` element. Lists and tables within a paragraph are
/// rendered as separate SwiftUI views rather than inside AttributedString
/// (AttributedString cannot express multi-column layouts or structured lists).
struct ParagraphBlock: View {
    let paragraph: Paragraph
    let footnotes: [Note]

    private var textAlignment: TextAlignment {
        switch paragraph.rend {
        case "center": return .center
        case "right":  return .trailing
        default:       return .leading
        }
    }

    private var stackAlignment: HorizontalAlignment {
        switch paragraph.rend {
        case "center": return .center
        case "right":  return .trailing
        default:       return .leading
        }
    }

    var body: some View {
        // Split the paragraph's inline content into runs separated by lists/tables,
        // rendering text runs as AttributedString and lists/tables as native views.
        VStack(alignment: stackAlignment, spacing: 6) {
            ForEach(Array(splitIntoRuns(paragraph.content).enumerated()), id: \.offset) { _, run in
                switch run {
                case .text(let inlines):
                    if !inlines.isEmpty {
                        Text(FRUSRenderer.attributedString(inlines, footnotes: footnotes))
                            .font(paragraph.rend == "italic"
                                  ? .system(size: 13, design: .serif).italic()
                                  : .system(size: 13, design: .serif))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(textAlignment)
                    }
                case .list(let l):
                    ListBlock(list: l, footnotes: footnotes)
                case .table(let t):
                    TableBlock(table: t, footnotes: footnotes)
                }
            }
        }
    }

    // MARK: Run splitting

    enum ContentRun {
        case text([InlineContent])
        case list(XMLList)
        case table(Table)
    }

    private func splitIntoRuns(_ content: [InlineContent]) -> [ContentRun] {
        var runs: [ContentRun] = []
        var textBuf: [InlineContent] = []

        func flushText() {
            // Trim leading/trailing whitespace-only text nodes
            var buf = textBuf
            while case .text(let s) = buf.first, s.trimmingCharacters(in: .whitespaces).isEmpty {
                buf.removeFirst()
            }
            while case .text(let s) = buf.last, s.trimmingCharacters(in: .whitespaces).isEmpty {
                buf.removeLast()
            }
            if !buf.isEmpty { runs.append(.text(buf)) }
            textBuf = []
        }

        for item in content {
            switch item {
            case .list(let l):
                flushText()
                runs.append(.list(l))
            case .table(let t):
                flushText()
                runs.append(.table(t))
            default:
                textBuf.append(item)
            }
        }
        flushText()
        return runs
    }
}

// MARK: - ListBlock

struct ListBlock: View {
    let list: XMLList
    let footnotes: [Note]

    private var isOrdered: Bool { list.type == "ordered" || list.type == "ol" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(isOrdered ? "\(idx + 1)." : "•")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    Text(FRUSRenderer.attributedString(item.content, footnotes: footnotes))
                        .font(.system(size: 13, design: .serif))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - TableBlock

struct TableBlock: View {
    let table: Table
    let footnotes: [Note]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        Text(FRUSRenderer.attributedString(cell.content, footnotes: footnotes))
                            .font(row.role == "label"
                                  ? .system(size: 12, weight: .semibold, design: .serif)
                                  : .system(size: 12, design: .serif))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(row.role == "label"
                                        ? Color.secondary.opacity(0.08)
                                        : Color.clear)
                            .overlay(Rectangle().strokeBorder(Color.secondary.opacity(0.2)))
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Color.secondary.opacity(0.25)))
        .padding(.vertical, 4)
    }
}

// MARK: - CloserBlock

struct CloserBlock: View {
    let closer: Closer

    var body: some View {
        Text(FRUSRenderer.attributedString(closer.content))
            .font(.system(size: 13, design: .serif))
            .italic()
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - FootnotesBlock

/// Renders all footnotes for a document, collected in document order.
/// Each entry has a numbered marker matching the inline superscript.
struct FootnotesBlock: View {
    let notes: [Note]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.bottom, 8)
            Text("Notes")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            ForEach(Array(notes.enumerated()), id: \.offset) { idx, note in
                HStack(alignment: .top, spacing: 8) {
                    // Marker
                    Text(note.n ?? "\(idx + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 22, alignment: .trailing)
                        .padding(.top, 2)

                    // Content: prefer paragraphs, fall back to inline content
                    let noteContent = noteText(note)
                    Text(FRUSRenderer.attributedString(noteContent))
                        .font(.system(size: 11, design: .serif))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)
            }
        }
    }

    private func noteText(_ note: Note) -> [InlineContent] {
        if !note.paragraphs.isEmpty {
            // Join paragraphs with a space separator
            return note.paragraphs.enumerated().flatMap { idx, para -> [InlineContent] in
                idx == 0 ? para.content : [.text(" ")] + para.content
            }
        }
        return note.content
    }
}

// MARK: - FRUSRenderer

/// Shared rendering utilities: AttributedString construction and footnote collection.
/// All methods are static so they can be called from any view without environment access.
enum FRUSRenderer {

    // MARK: - Footnote collection

    /// Collects all footnotes from the division tree in document order.
    /// This matches the order inline markers appear in the rendered text.
    static func collectFootnotes(from division: Division) -> [Note] {
        var result: [Note] = []
        collectFootnotesRecursive(from: division, into: &result)
        return result
    }

    private static func collectFootnotesRecursive(from div: Division, into result: inout [Note]) {
        // Inline notes within paragraphs
        for para in div.paragraphs {
            collectInlineNotes(from: para.content, into: &result)
        }
        // Opener
        if let op = div.opener {
            collectInlineNotes(from: op.content, into: &result)
        }
        // Closer
        if let cl = div.closer {
            collectInlineNotes(from: cl.content, into: &result)
        }
        // Direct child notes with place="bottom" or type="footnote"
        for note in div.notes where note.place == "bottom" || note.type == "footnote" || note.place == "end" {
            result.append(note)
        }
        // Recurse into children
        for child in div.children {
            collectFootnotesRecursive(from: child, into: &result)
        }
    }

    private static func collectInlineNotes(from content: [InlineContent], into result: inout [Note]) {
        for item in content {
            switch item {
            case .note(let n):
                result.append(n)
            case .hi(let h):
                collectInlineNotes(from: h.content, into: &result)
            case .list(let l):
                for listItem in l.items {
                    collectInlineNotes(from: listItem.content, into: &result)
                }
            default:
                break
            }
        }
    }

    // MARK: - Plain text

    static func plainText(_ content: [InlineContent]) -> String {
        content.map { item -> String in
            switch item {
            case .text(let s):            return s
            case .persName(let p):        return p.text
            case .placeName(let p):       return p.text
            case .orgName(let o):         return o.text
            case .date(let d):            return d.text
            case .ref(let r):             return r.text
            case .hi(let h):              return plainText(h.content)
            case .term(let t):            return t.text
            case .note(let n):            return n.n.map { "[\($0)]" } ?? ""
            case .pageBreak(let pb):      return pb.n.map { "[p.\($0)]" } ?? ""
            case .lineBreak:              return " "
            case .list(let l):
                return l.items.map { plainText($0.content) }.joined(separator: "; ")
            case .table:                  return ""
            case .unknown:                return ""
            }
        }.joined()
    }

    // MARK: - AttributedString construction

    /// Build an `AttributedString` from inline content, rendering footnote markers
    /// as superscript references matched against the provided footnote list.
    static func attributedString(
        _ content: [InlineContent],
        footnotes: [Note] = []
    ) -> AttributedString {
        var result = AttributedString()
        for item in content {
            result += fragment(item, footnotes: footnotes)
        }
        return result
    }

    private static func fragment(_ item: InlineContent, footnotes: [Note]) -> AttributedString {
        switch item {

        case .text(let s):
            // Normalize: collapse internal whitespace runs, preserving single spaces
            return AttributedString(normalizeWhitespace(s))

        case .persName(let p):
            return AttributedString(p.text)

        case .placeName(let p):
            return AttributedString(p.text)

        case .orgName(let o):
            return AttributedString(o.text)

        case .date(let d):
            return AttributedString(normalizeWhitespace(d.text))

        case .ref(let r):
            var a = AttributedString(r.text)
            if let target = r.target, target.hasPrefix("http"), let url = URL(string: target) {
                a.link = url
            }
            return a

        case .hi(let h):
            var a = AttributedString()
            for c in h.content { a += fragment(c, footnotes: footnotes) }
            let rend = h.rend ?? ""
            if rend.contains("italic") {
                a.font = .system(size: 13, design: .serif).italic()
            } else if rend.contains("bold") {
                a.font = .system(size: 13, weight: .bold, design: .serif)
            } else if rend.contains("smallcaps") {
                // Approximate small-caps by uppercasing + reducing font size
                var sc = AttributedString(a.characters.map { c in
                    c.isLowercase ? Character(extendedGraphemeClusterLiteral: c.uppercased().first ?? c) : c
                }.map(String.init).joined())
                sc.font = .system(size: 11, weight: .medium, design: .serif)
                return sc
            } else if rend.contains("underline") {
                a.underlineStyle = .single
            }
            return a

        case .term(let t):
            var a = AttributedString(t.text)
            a.font = .system(size: 13, design: .serif).italic()
            return a

        case .note(let n):
            // Render as superscript marker — look up in collected footnotes for
            // a stable sequential number; fall back to @n attribute.
            let marker: String
            if let idx = footnotes.firstIndex(where: { $0.id == n.id && n.id != nil }) {
                marker = "\(idx + 1)"
            } else if let nVal = n.n {
                marker = nVal
            } else {
                marker = "†"
            }
            var a = AttributedString(marker)
            a.font = .system(size: 9)
            a.baselineOffset = 4
            a.foregroundColor = .init(.systemOrange)
            return a

        case .pageBreak(let pb):
            guard let n = pb.n, !n.isEmpty else { return AttributedString() }
            var a = AttributedString(" [p.\(n)] ")
            a.font = .system(size: 9)
            a.foregroundColor = .init(.systemGray)
            return a

        case .lineBreak:
            return AttributedString("\n")

        case .list:
            // Lists are extracted and rendered separately by ParagraphBlock;
            // this branch handles lists that somehow appear nested in text runs.
            return AttributedString()

        case .table:
            return AttributedString()

        case .unknown:
            return AttributedString()
        }
    }

    // MARK: - Whitespace normalization

    /// Collapse internal whitespace runs to single spaces and strip purely-structural
    /// leading/trailing whitespace (but preserve a single space at boundaries to
    /// maintain word-spacing between adjacent inline elements).
    static func normalizeWhitespace(_ s: String) -> String {
        var result = s
        // Replace newlines and tabs with spaces
        result = result.replacingOccurrences(of: "\n", with: " ")
        result = result.replacingOccurrences(of: "\r", with: " ")
        result = result.replacingOccurrences(of: "\t", with: " ")
        // Collapse runs of spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result
    }
}

// MARK: - String extension

extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
