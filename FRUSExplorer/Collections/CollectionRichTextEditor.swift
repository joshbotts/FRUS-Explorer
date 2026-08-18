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
///   1.2 — Authoring Phase 4: `exportRTF(richText:plainText:)` — the field-level variant
///          for standalone rich-text fields following the plain-projection pattern
///          (`Collection.introductionRichText`/`introductionText`)
enum ProseRichText {

    /// The RTF payload for a standalone rich-text field that follows the plain-projection
    /// pattern (rich `Data` + plain `String`), e.g. the collection introduction (Authoring
    /// Phase 4). Returns the stored data when it decodes as non-empty RTF, else the plain
    /// text encoded as RTF, else `nil` when the field is effectively empty — callers emit
    /// nothing rather than an empty block, preserving pre-Phase-4 output exactly.
    static func exportRTF(richText: Data?, plainText: String?) -> Data? {
        if let stored = richText, let decoded = decodedRTF(stored), decoded.length > 0 {
            return stored
        }
        guard let plain = plainText,
              !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return rtfData(from: NSAttributedString(string: plain))
    }

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
/// RTF body, with a **visible formatting toolbar** (Bold, Italic, Underline, text colour, and
/// Link) so formatting is discoverable without the system context/format menus. Native text
/// views produce concrete `NSFont`/`NSColor`/`.link` attributes which RTF round-trips and the
/// exporters can read. Edits are reported as `(rtf, plainText)` via `onChange`.
///
/// - macOS: a compact SF Symbols button bar above the text view; Bold/Italic/Underline
///   reflect the current selection's state, colour opens the shared `NSColorPanel`, and
///   Link edits the selection's `.link` attribute via a popover.
/// - iOS: the same controls as an `inputAccessoryView` toolbar on the keyboard, driving
///   the standard `toggleBoldface`/`toggleItalics`/`toggleUnderline` actions, a
///   `UIColorPickerViewController`, and a link alert.
///
/// **Why no bulleted/numbered lists.** `NSTextList` paragraph styles do round-trip through
/// RTF, but the list *markers* are layout-generated, not stored characters — the plain
/// projection and `CollectionProse`'s inline span model (paragraphs split on blank lines,
/// spans carrying bold/italic/underline/colour/link only) would render list items as
/// marker-less tab-indented lines in HTML, PDF, and DOCX. Real support needs paragraph-level
/// list metadata in `ProseFormattedSpan`'s container, `<ul>`/`<ol>` nesting in the HTML
/// renderer, a `numbering.xml` part + `<w:numPr>` in DOCX, marker drawing in the PDF flow,
/// and hand-built list editing UI on iOS (`UITextView` has none). Until that model exists,
/// shipping a Lists button would silently lose list semantics on every export — so it is
/// deliberately absent (owner decision rule, Session 2026-07-03).
///
/// Version history:
///   1.0 — PR #127: native representable replacing SwiftUI `TextEditor` (opaque `Font`
///          attributes cannot be introspected outside a live view; concrete
///          `NSFont`/`NSColor` can)
///   1.1 — Session 2026-07-03: visible formatting toolbar on both platforms (bold, italic,
///          underline, colour, link) — formatting no longer reachable only through the
///          system context menus; `.link` attributes ride the existing RTF persistence
///   1.2 — Session 2026-07-03 review fix (macOS): the shared `NSColorPanel` follows
///          keyboard focus across coexisting editors (the manager shows several prose
///          rows plus the introduction editor at once) instead of staying targeted at
///          whichever editor's palette button was clicked last — a pick after switching
///          editors used to silently recolor (and persist) the previous editor's entry;
///          the panel's target is also cleared on editor teardown
///   1.3 — Dynamic Type A2 (iOS): `UITextView.adjustsFontForContentSizeCategory` is enabled
///          so newly typed text tracks the reader's text-size setting, and prose loaded from
///          RTF (which round-trips *concrete* fonts the flag can't rescale) is remapped
///          through `UIFontMetrics` for display. The scaling is display-only — edits are
///          normalised back to a canonical base size before serialising, so stored RTF stays
///          byte-identical across content-size categories and exports/plain-projection are
///          unaffected. macOS `NSTextView` does not Dynamic-Type the same way and is unchanged.
struct RichTextEditor: View {
    /// The entry's current RTF body (loaded once), or `nil` for an empty/plain prose block.
    let initialRTF: Data?
    /// Plain-text fallback used when `initialRTF` is `nil` (e.g. a pre-3b plain prose entry).
    let plainFallback: String
    /// Called on every edit with the new RTF and its plain-text projection.
    let onChange: (Data?, String) -> Void

    #if os(macOS)
    /// Bridges the SwiftUI toolbar to the live `NSTextView` (selection state + actions).
    @StateObject private var controller = RichTextEditorController()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            RichTextFormattingBar(controller: controller)
            RichTextPlatformEditor(initialRTF: initialRTF, plainFallback: plainFallback,
                                   onChange: onChange, controller: controller)
        }
    }
    #else
    var body: some View {
        RichTextPlatformEditor(initialRTF: initialRTF, plainFallback: plainFallback,
                               onChange: onChange)
    }
    #endif
}

// MARK: - RichTextPlatformEditor

/// The platform representable behind ``RichTextEditor``: wraps `NSTextView` (macOS) /
/// `UITextView` (iOS) and serialises every edit back to `(rtf, plainText)`.
private struct RichTextPlatformEditor {
    /// The entry's current RTF body (loaded once), or `nil` for an empty/plain prose block.
    let initialRTF: Data?
    /// Plain-text fallback used when `initialRTF` is `nil` (e.g. a pre-3b plain prose entry).
    let plainFallback: String
    /// Called on every edit with the new RTF and its plain-text projection.
    let onChange: (Data?, String) -> Void
    #if os(macOS)
    /// The toolbar bridge — given the live text view once it exists.
    let controller: RichTextEditorController
    #endif

    /// The initial attributed content — from RTF, else a legacy Phase 3b JSON blob (converted
    /// with its bold/italic intact, so pre-RTF prose loads faithfully and the first edit
    /// re-saves it as RTF), else the plain fallback.
    ///
    /// On iOS the loaded fonts are additionally remapped through `UIFontMetrics` for **display**
    /// (see ``displayScaledForDynamicType(_:)``): RTF round-trips *concrete* fonts (e.g.
    /// `systemFont(ofSize: 13)`), which `adjustsFontForContentSizeCategory` cannot rescale on
    /// its own, so without this step existing prose ignores the reader's text-size setting. The
    /// scaling is display-only — ``report(_:)`` normalises fonts back to their base size before
    /// serialising, so stored RTF stays independent of the content-size category.
    fileprivate func initialAttributed() -> NSAttributedString {
        let base: NSAttributedString = {
            if let stored = initialRTF {
                if let ns = ProseRichText.decodedRTF(stored) { return ns }
                if let legacy = ProseRichText.legacyNSAttributedString(fromJSON: stored) { return legacy }
            }
            return NSAttributedString(string: plainFallback)
        }()
        #if os(iOS)
        return Self.displayScaledForDynamicType(base)
        #else
        return base
        #endif
    }

    /// Serialises the text view's storage to `(rtf, plainText)` and reports it.
    ///
    /// On iOS the display fonts carry `UIFontMetrics`-scaled point sizes (see
    /// ``initialAttributed()``); they are normalised back to their base size here so the stored
    /// RTF never bakes in the reader's current Dynamic Type setting. Bold/italic/underline/colour/
    /// link — everything the exporters and the plain projection read — is preserved, so exports
    /// and `CollectionProse` are unaffected by the display scaling.
    fileprivate func report(_ storage: NSAttributedString) {
        #if os(iOS)
        let toStore = Self.baseNormalizedForStorage(storage)
        #else
        let toStore = storage
        #endif
        let rtf = try? toStore.data(from: NSRange(location: 0, length: toStore.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        onChange(rtf, toStore.string)
    }
}

#if os(iOS)
extension RichTextPlatformEditor {
    /// The text style whose `UIFontMetrics` drives display scaling. `.body` is the idiomatic
    /// reference style for scaling arbitrary body prose and tracks the editor's `.callout`
    /// typing font closely.
    fileprivate static var proseMetricsStyle: UIFont.TextStyle { .body }

    /// The canonical point size all fonts collapse to for storage. The exporters and
    /// `CollectionProse` read only *traits* (bold/italic), underline, colour, and link from a
    /// run's font — never its point size — so pinning a single base size for storage is
    /// semantically lossless and makes the serialised RTF fully deterministic (identical bytes
    /// at every Dynamic Type setting). 13 pt is the historical body size these entries were
    /// authored at.
    fileprivate static var storageBaseSize: CGFloat { 13 }

    /// A copy of `attributed` with every `.font` run remapped through `UIFontMetrics` so the
    /// concrete point sizes RTF stored become Dynamic-Type responsive. Symbolic traits (bold/
    /// italic) and every other attribute are preserved; only the point size changes. Runs
    /// without a `.font` are given the metrics-scaled base font so plain-text prose scales too.
    fileprivate static func displayScaledForDynamicType(_ attributed: NSAttributedString) -> NSAttributedString {
        let metrics = UIFontMetrics(forTextStyle: proseMetricsStyle)
        let baseFont = UIFont.preferredFont(forTextStyle: .callout)
        let result = NSMutableAttributedString(attributedString: attributed)
        let full = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            let source = (value as? UIFont) ?? baseFont
            result.addAttribute(.font, value: metrics.scaledFont(for: source), range: range)
        }
        return result
    }

    /// Strips display scaling for storage: every `.font` run is reset to ``storageBaseSize``
    /// while its symbolic traits are preserved, so the serialised RTF is byte-identical
    /// regardless of the reader's Dynamic Type setting. All non-font attributes (underline,
    /// colour, link) are untouched. Point size carries no semantics the exporters read, so this
    /// collapse is lossless for every downstream consumer.
    fileprivate static func baseNormalizedForStorage(_ attributed: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributed)
        let full = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            guard let font = value as? UIFont else { return }
            let traits = font.fontDescriptor.symbolicTraits
            let base = UIFont.systemFont(ofSize: storageBaseSize)
            if traits.isEmpty {
                result.addAttribute(.font, value: base, range: range)
            } else if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
                result.addAttribute(.font, value: UIFont(descriptor: descriptor, size: storageBaseSize), range: range)
            } else {
                result.addAttribute(.font, value: base, range: range)
            }
        }
        return result
    }
}
#endif

#if os(macOS)

// MARK: - RichTextEditorController (macOS)

/// Bridges the SwiftUI formatting bar to the live `NSTextView`: publishes the current
/// selection's formatting state and drives the formatting actions. All text mutations
/// are bracketed with `shouldChangeText`/`didChangeText`, so undo works and the edit
/// flows back through the coordinator's `textDidChange` → RTF persistence unchanged.
@MainActor
final class RichTextEditorController: NSObject, ObservableObject {
    /// The live text view, set by the representable on creation.
    weak var textView: NSTextView?
    /// `true` when the selection (or the caret's typing attributes) is bold.
    @Published private(set) var isBold = false
    /// `true` when the selection (or the caret's typing attributes) is italic.
    @Published private(set) var isItalic = false
    /// `true` when the selection (or the caret's typing attributes) is underlined.
    @Published private(set) var isUnderline = false
    /// `true` when a non-empty range is selected (required to apply a link).
    @Published private(set) var hasSelection = false
    /// The `.link` URL at the selection start, empty when the selection carries no link.
    @Published private(set) var selectionLink = ""

    /// Toggles bold on the selection (or the typing attributes at the caret).
    func toggleBold() { toggleTrait(.boldFontMask) }

    /// Toggles italic on the selection (or the typing attributes at the caret).
    func toggleItalic() { toggleTrait(.italicFontMask) }

    /// Toggles underline via the text view's native action (undo-aware).
    func toggleUnderline() {
        guard let tv = textView else { return }
        tv.underline(nil)
        refreshSelectionState()
    }

    /// The controller the shared colour panel currently targets. `NSColorPanel` exposes
    /// no getter for its target, so ownership is tracked here to let a newly focused
    /// editor adopt the panel and a torn-down editor release it (v1.2) — without this,
    /// a pick after switching editors silently recolored the previous editor's entry.
    private static weak var colorPanelOwner: RichTextEditorController?

    /// Opens the shared system colour panel targeted at this editor; picked colours apply
    /// to the current selection (or the typing attributes at the caret).
    func showColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidPick(_:)))
        Self.colorPanelOwner = self
        panel.makeKeyAndOrderFront(nil)
    }

    /// Retargets the visible shared colour panel at this editor when its text view has
    /// keyboard focus — the standard follow-focus behaviour of the system colour panel,
    /// which the explicit target/action in ``showColorPanel()`` otherwise defeats.
    /// Called on every selection change / editing start; a no-op when the panel is
    /// closed, this editor already owns it, or the text view is not first responder.
    func adoptColorPanelIfActive() {
        guard Self.colorPanelOwner !== self else { return }
        let panel = NSColorPanel.shared
        guard panel.isVisible,
              let tv = textView, tv.window?.firstResponder === tv else { return }
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidPick(_:)))
        Self.colorPanelOwner = self
    }

    /// Clears the shared colour panel's target/action when this editor still owns it —
    /// called on editor teardown so the panel never keeps a dangling target after the
    /// collection editor (or one of its rows) goes away.
    func releaseColorPanel() {
        guard Self.colorPanelOwner === self else { return }
        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
        Self.colorPanelOwner = nil
    }

    /// Applies (or, for an empty string, removes) a `.link` attribute over the selection.
    /// No-op without a non-empty selection — a link needs visible text to attach to.
    func applyLink(_ urlString: String) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        guard range.length > 0, tv.shouldChangeText(in: range, replacementString: nil) else { return }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            storage.removeAttribute(.link, range: range)
        } else {
            storage.addAttribute(.link, value: URL(string: trimmed) ?? trimmed, range: range)
        }
        tv.didChangeText()
        refreshSelectionState()
    }

    /// Recomputes the published formatting state from the current selection — from the
    /// first selected character when a range is selected, else the typing attributes.
    ///
    /// Every `@Published` assignment is change-guarded (`if x != new { x = new }`) so a
    /// no-op refresh publishes NOTHING (v1.3). This matters because a make-time delegate
    /// callback (initial content load) can reach the nil-`textView` else-branch while the
    /// SwiftUI view update is in flight; guarding turns that already-at-defaults case into
    /// zero publishes, silencing "Publishing changes from within view updates" — and it
    /// cuts redundant `ObservableObject` churn on every caret move generally.
    func refreshSelectionState() {
        guard let tv = textView else {
            if isBold { isBold = false }
            if isItalic { isItalic = false }
            if isUnderline { isUnderline = false }
            if hasSelection { hasSelection = false }
            if !selectionLink.isEmpty { selectionLink = "" }
            return
        }
        let range = tv.selectedRange()
        let newHasSelection = range.length > 0
        if hasSelection != newHasSelection { hasSelection = newHasSelection }
        let attrs: [NSAttributedString.Key: Any]
        if let storage = tv.textStorage, range.length > 0, range.location < storage.length {
            attrs = storage.attributes(at: range.location, effectiveRange: nil)
        } else {
            attrs = tv.typingAttributes
        }
        let traits = (attrs[.font] as? NSFont).map { NSFontManager.shared.traits(of: $0) } ?? []
        let newIsBold = traits.contains(.boldFontMask)
        if isBold != newIsBold { isBold = newIsBold }
        let newIsItalic = traits.contains(.italicFontMask)
        if isItalic != newIsItalic { isItalic = newIsItalic }
        let newIsUnderline = (attrs[.underlineStyle] as? Int ?? 0) != 0
        if isUnderline != newIsUnderline { isUnderline = newIsUnderline }
        let newSelectionLink: String
        if let link = attrs[.link] {
            newSelectionLink = (link as? URL)?.absoluteString ?? (link as? String ?? "")
        } else {
            newSelectionLink = ""
        }
        if selectionLink != newSelectionLink { selectionLink = newSelectionLink }
    }

    /// Applies the colour-panel colour to the selection (undo-aware) or, at a bare
    /// caret, to the typing attributes.
    @objc private func colorPanelDidPick(_ sender: Any?) {
        guard let tv = textView else { return }
        let color = NSColorPanel.shared.color
        let range = tv.selectedRange()
        if range.length > 0, let storage = tv.textStorage {
            guard tv.shouldChangeText(in: range, replacementString: nil) else { return }
            storage.addAttribute(.foregroundColor, value: color, range: range)
            tv.didChangeText()
        } else {
            tv.typingAttributes[.foregroundColor] = color
        }
    }

    /// Toggles one font trait over the selection (undo-aware) or, at a bare caret, on the
    /// typing attributes — based on the state at the selection start, so a mixed selection
    /// converges rather than flipping run-by-run.
    private func toggleTrait(_ trait: NSFontTraitMask) {
        guard let tv = textView else { return }
        let manager = NSFontManager.shared
        let range = tv.selectedRange()
        let baseFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let currentlyOn = (trait == .boldFontMask) ? isBold : isItalic
        func converted(_ font: NSFont) -> NSFont {
            currentlyOn ? manager.convert(font, toNotHaveTrait: trait)
                        : manager.convert(font, toHaveTrait: trait)
        }
        if range.length > 0, let storage = tv.textStorage {
            guard tv.shouldChangeText(in: range, replacementString: nil) else { return }
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: range) { value, runRange, _ in
                storage.addAttribute(.font, value: converted((value as? NSFont) ?? baseFont),
                                     range: runRange)
            }
            storage.endEditing()
            tv.didChangeText()
        } else {
            var attrs = tv.typingAttributes
            attrs[.font] = converted((attrs[.font] as? NSFont) ?? baseFont)
            tv.typingAttributes = attrs
        }
        refreshSelectionState()
    }
}

// MARK: - RichTextFormattingBar (macOS)

/// The compact visible formatting bar above each macOS rich-text editor: Bold, Italic,
/// Underline (reflecting the selection's state), text colour (system colour panel), and
/// Link (popover URL field applying the `.link` attribute to the selection).
private struct RichTextFormattingBar: View {
    /// The bridge to the live text view.
    @ObservedObject var controller: RichTextEditorController
    /// Whether the link popover is showing.
    @State private var showingLinkPopover = false
    /// The link popover's URL field text.
    @State private var linkURLText = ""

    var body: some View {
        HStack(spacing: 2) {
            formatButton("bold", active: controller.isBold,
                         help: String(localized: "collection.richtext.bold.help",
                                      defaultValue: "Bold")) { controller.toggleBold() }
            formatButton("italic", active: controller.isItalic,
                         help: String(localized: "collection.richtext.italic.help",
                                      defaultValue: "Italic")) { controller.toggleItalic() }
            formatButton("underline", active: controller.isUnderline,
                         help: String(localized: "collection.richtext.underline.help",
                                      defaultValue: "Underline")) { controller.toggleUnderline() }
            formatButton("paintpalette", active: false,
                         help: String(localized: "collection.richtext.color.help",
                                      defaultValue: "Text Color")) { controller.showColorPanel() }
            formatButton("link", active: !controller.selectionLink.isEmpty,
                         help: String(localized: "collection.richtext.link.help",
                                      defaultValue: "Link selected text to a URL")) {
                linkURLText = controller.selectionLink
                showingLinkPopover = true
            }
            .disabled(!controller.hasSelection)
            .popover(isPresented: $showingLinkPopover, arrowEdge: .bottom) { linkPopover }
            Spacer()
        }
    }

    /// The link popover: a URL field plus Apply / Remove Link buttons.
    private var linkPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "collection.richtext.link.title",
                        defaultValue: "Link selection to URL"))
                .font(.caption.weight(.semibold))
            TextField(String(localized: "collection.richtext.link.placeholder",
                             defaultValue: "https://…"),
                      text: $linkURLText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { applyLink() }
            HStack {
                if !controller.selectionLink.isEmpty {
                    Button(String(localized: "collection.richtext.link.remove",
                                  defaultValue: "Remove Link"), role: .destructive) {
                        controller.applyLink("")
                        showingLinkPopover = false
                    }
                }
                Spacer()
                Button(String(localized: "collection.richtext.link.apply",
                              defaultValue: "Apply")) { applyLink() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }

    /// Applies the popover's URL to the selection and dismisses.
    private func applyLink() {
        controller.applyLink(linkURLText)
        showingLinkPopover = false
    }

    /// One toolbar button: an SF Symbol with an "active" tint/background when the
    /// selection already carries the attribute.
    private func formatButton(_ symbol: String, active: Bool, help: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 18)
                .foregroundStyle(active ? Color.accentColor : Color.primary)
                .background(active ? Color.accentColor.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

extension RichTextPlatformEditor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.drawsBackground = false
        textView.textStorage?.setAttributedString(initialAttributed())

        // Hand the toolbar its text view, THEN wire the delegate last (v1.3): loading the
        // initial content above must not fire a delegate callback (textDidChange /
        // textViewDidChangeSelection → refreshSelectionState) while `controller.textView`
        // is still nil, which published @Published state during the SwiftUI view update
        // ("Publishing changes from within view updates"). Once the delegate is installed
        // here, user-driven selection changes still refresh the toolbar live.
        controller.textView = textView
        textView.delegate = context.coordinator
        // Defer the initial state publish out of the current view update.
        let controller = self.controller
        Task { @MainActor in controller.refreshSelectionState() }

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
        context.coordinator.controller = controller
    }

    func makeCoordinator() -> Coordinator { Coordinator(report: report, controller: controller) }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        // Drop the shared colour panel's target if it still points at this editor's
        // controller (v1.2) — otherwise the panel outlives the collection editor with
        // a dangling target.
        coordinator.controller.releaseColorPanel()
    }

    /// Forwards `NSTextView` edits back to the entry and selection changes to the toolbar,
    /// and hands the shared colour panel to this editor whenever it gains focus (v1.2).
    final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate var report: (NSAttributedString) -> Void
        /// The toolbar bridge whose published state follows this text view.
        fileprivate var controller: RichTextEditorController
        init(report: @escaping (NSAttributedString) -> Void,
             controller: RichTextEditorController) {
            self.report = report
            self.controller = controller
        }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
            report(storage)
            controller.refreshSelectionState()
        }
        func textViewDidChangeSelection(_ notification: Notification) {
            controller.refreshSelectionState()
            controller.adoptColorPanelIfActive()
        }
        func textDidBeginEditing(_ notification: Notification) {
            controller.adoptColorPanelIfActive()
        }
    }
}
#elseif os(iOS)
extension RichTextPlatformEditor: UIViewRepresentable {
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.allowsEditingTextAttributes = true   // Bold / Italic / Underline in the edit menu
        textView.isEditable = true
        textView.backgroundColor = .clear
        // Dynamic Type (A2): `.preferredFont(forTextStyle:)` is a metrics-scaled font, and
        // `adjustsFontForContentSizeCategory` re-derives newly typed text's size when the reader
        // changes their text-size setting. Existing prose loaded from RTF carries *concrete*
        // fonts that this flag can't rescale, so `initialAttributed()` remaps those runs through
        // `UIFontMetrics` for display; `report(_:)` normalises them back to a base size for
        // storage (see those methods).
        textView.font = .preferredFont(forTextStyle: .callout)
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.attributedText = initialAttributed()
        context.coordinator.textView = textView
        textView.inputAccessoryView = context.coordinator.makeFormattingToolbar()
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Rebind the coordinator's callback to the CURRENT entry (see the macOS note above).
        context.coordinator.report = report
    }

    func makeCoordinator() -> Coordinator { Coordinator(report: report) }

    /// Forwards `UITextView` edits back to the entry and hosts the keyboard-attached
    /// formatting toolbar (Bold, Italic, Underline, text colour, Link).
    final class Coordinator: NSObject, UITextViewDelegate, UIColorPickerViewControllerDelegate {
        fileprivate var report: (NSAttributedString) -> Void
        /// The live text view the toolbar drives.
        fileprivate weak var textView: UITextView?
        /// The Link toolbar item — enabled only while a non-empty range is selected.
        private weak var linkItem: UIBarButtonItem?
        /// The selection captured when the colour picker was presented (the picker takes
        /// first-responder focus, so the range is applied back afterwards).
        private var colorTargetRange: NSRange?

        init(report: @escaping (NSAttributedString) -> Void) { self.report = report }

        func textViewDidChange(_ textView: UITextView) {
            report(textView.attributedText ?? NSAttributedString())
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            linkItem?.isEnabled = textView.selectedRange.length > 0
        }

        // MARK: Formatting toolbar

        /// Builds the keyboard `inputAccessoryView`: Bold, Italic, Underline (the text
        /// view's standard toggle actions), text colour, and Link.
        func makeFormattingToolbar() -> UIToolbar {
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
            func item(_ symbol: String, label: String, action: Selector) -> UIBarButtonItem {
                let item = UIBarButtonItem(image: UIImage(systemName: symbol),
                                           style: .plain, target: self, action: action)
                item.accessibilityLabel = label
                return item
            }
            let bold = item("bold",
                            label: String(localized: "collection.richtext.bold.help",
                                          defaultValue: "Bold"),
                            action: #selector(toggleBold))
            let italic = item("italic",
                              label: String(localized: "collection.richtext.italic.help",
                                            defaultValue: "Italic"),
                              action: #selector(toggleItalic))
            let underline = item("underline",
                                 label: String(localized: "collection.richtext.underline.help",
                                               defaultValue: "Underline"),
                                 action: #selector(toggleUnderline))
            let color = item("paintpalette",
                             label: String(localized: "collection.richtext.color.help",
                                           defaultValue: "Text Color"),
                             action: #selector(pickColor))
            let link = item("link",
                            label: String(localized: "collection.richtext.link.help",
                                          defaultValue: "Link selected text to a URL"),
                            action: #selector(promptLink))
            link.isEnabled = false
            linkItem = link
            let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                        target: nil, action: nil)
            // The Done this toolbar owes the reader (#861/#928).
            //
            // `inputAccessoryView` and `ToolbarItemGroup(placement: .keyboard)` occupy the SAME
            // slot, so `.keyboardDismissBar()` structurally cannot appear over a rich-text
            // editor — #928 recorded that limit and left the two prose editors with no way to
            // put the keyboard away. Appending here is the fix, and it reaches both iOS mount
            // sites (the collection Introduction and CollectionProseRow) because both funnel
            // through this one representable.
            //
            // Titled, not an image: `item(_:label:action:)` above builds icon-only buttons with
            // an accessibilityLabel, and "Done" is the platform's own word for this control —
            // the same argument KeyboardDismissBar makes for not renaming its own button. The
            // key is shared with it deliberately; keys here are inline, with no catalog to
            // collide in.
            //
            // A FRESH flexible space, not a fifth reuse of `space`: that single instance is
            // already shared by the four separators, and making it five would leave "pin Done
            // trailing" indistinguishable from "distribute six items evenly".
            let doneSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                            target: nil, action: nil)
            let done = UIBarButtonItem(
                title: String(localized: "common.keyboard.done", defaultValue: "Done"),
                style: .done, target: self, action: #selector(dismissKeyboard))
            toolbar.items = [bold, space, italic, space, underline, space, color, space, link,
                             doneSpace, done]
            toolbar.sizeToFit()
            return toolbar
        }

        /// Puts the keyboard away from the formatting bar's Done.
        ///
        /// Resigns on the text view directly rather than routing through
        /// `KeyboardDismissBar.dismiss()`: that is what the shared helper does anyway, and this
        /// keeps the Coordinator free of an actor-isolated call it does not need.
        @objc private func dismissKeyboard() {
            textView?.resignFirstResponder()
        }

        /// Toggles bold on the selection via the standard text-view action and persists.
        @objc private func toggleBold() {
            textView?.toggleBoldface(nil)
            reportCurrent()
        }

        /// Toggles italic on the selection via the standard text-view action and persists.
        @objc private func toggleItalic() {
            textView?.toggleItalics(nil)
            reportCurrent()
        }

        /// Toggles underline on the selection via the standard text-view action and persists.
        @objc private func toggleUnderline() {
            textView?.toggleUnderline(nil)
            reportCurrent()
        }

        /// Presents the system colour picker; the chosen colour applies to the selection
        /// captured at presentation time (or the typing attributes at a bare caret).
        @objc private func pickColor() {
            guard let tv = textView, let presenter = presentingViewController(for: tv) else { return }
            colorTargetRange = tv.selectedRange
            let picker = UIColorPickerViewController()
            picker.supportsAlpha = false
            if let current = tv.typingAttributes[.foregroundColor] as? UIColor {
                picker.selectedColor = current
            }
            picker.delegate = self
            presenter.present(picker, animated: true)
        }

        /// Prompts for a URL (prefilled with the selection's existing link) and applies —
        /// or removes — the `.link` attribute over the selected range.
        @objc private func promptLink() {
            guard let tv = textView, let presenter = presentingViewController(for: tv) else { return }
            let range = tv.selectedRange
            guard range.length > 0 else { return }
            let existing = tv.textStorage.attribute(.link, at: range.location, effectiveRange: nil)
            let existingURL = (existing as? URL)?.absoluteString ?? (existing as? String ?? "")

            let alert = UIAlertController(
                title: String(localized: "collection.richtext.link.title",
                              defaultValue: "Link selection to URL"),
                message: nil, preferredStyle: .alert)
            alert.addTextField { field in
                field.placeholder = String(localized: "collection.richtext.link.placeholder",
                                           defaultValue: "https://…")
                field.keyboardType = .URL
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
                field.text = existingURL
            }
            alert.addAction(UIAlertAction(
                title: String(localized: "collection.richtext.link.apply", defaultValue: "Apply"),
                style: .default) { [weak self, weak alert] _ in
                    let url = alert?.textFields?.first?.text ?? ""
                    self?.applyLink(url, range: range)
                })
            if !existingURL.isEmpty {
                alert.addAction(UIAlertAction(
                    title: String(localized: "collection.richtext.link.remove",
                                  defaultValue: "Remove Link"),
                    style: .destructive) { [weak self] _ in
                        self?.applyLink("", range: range)
                    })
            }
            alert.addAction(UIAlertAction(
                title: String(localized: "collection.richtext.link.cancel", defaultValue: "Cancel"),
                style: .cancel))
            presenter.present(alert, animated: true)
        }

        /// Applies (or, for an empty string, removes) a `.link` attribute over `range`
        /// and persists the change.
        private func applyLink(_ urlString: String, range: NSRange) {
            guard let tv = textView, range.location + range.length <= tv.textStorage.length else { return }
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                tv.textStorage.removeAttribute(.link, range: range)
            } else {
                tv.textStorage.addAttribute(.link, value: URL(string: trimmed) ?? trimmed, range: range)
            }
            reportCurrent()
        }

        /// Applies the picked colour to the captured selection (or typing attributes).
        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            applyColor(viewController.selectedColor)
        }

        /// Live colour updates while the picker is open (non-continuous events only).
        func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                       didSelect color: UIColor, continuously: Bool) {
            guard !continuously else { return }
            applyColor(color)
        }

        /// Applies `color` to the range captured when the picker was presented, else to
        /// the typing attributes, and persists.
        private func applyColor(_ color: UIColor) {
            guard let tv = textView else { return }
            if let range = colorTargetRange, range.length > 0,
               range.location + range.length <= tv.textStorage.length {
                tv.textStorage.addAttribute(.foregroundColor, value: color, range: range)
                reportCurrent()
            } else {
                tv.typingAttributes[.foregroundColor] = color
            }
        }

        /// Serialises the text view's current storage back to the entry.
        private func reportCurrent() {
            guard let tv = textView else { return }
            report(tv.attributedText ?? NSAttributedString())
        }

        /// The nearest view controller up the responder chain — used to present the
        /// colour picker and link alert from a plain representable.
        private func presentingViewController(for view: UIView) -> UIViewController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let vc = current as? UIViewController { return vc }
                responder = current.next
            }
            return nil
        }
    }
}
#endif
