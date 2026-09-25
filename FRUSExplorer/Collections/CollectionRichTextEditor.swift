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
///   1.4 — #1360: an opt-in ``RichTextRestingCap``. An editor that passes one sizes itself —
///          at rest its opening lines, the last ending in an ellipsis wherever the cap falls
///          (its paragraph breaks are drawn as line breaks, ``RichTextRestingText``); while
///          editing a scrolling editor as tall as its text up to the cap's editing height, and
///          never shorter than it rested — and returns to its opening lines when editing ends,
///          but not while the iOS formatting bar's colour picker or link alert has taken focus.
///          Adopted by the collection note block and both introduction editors; the research
///          note body does not opt in and is unchanged. On macOS the text view is now a
///          ``RichTextFocusTextView``, which reports focus and width.
///   1.5 — #1360 review, round 2: every report puts back the paragraph breaks a resting
///          block draws as line breaks, so a change the macOS formatting bar makes to a
///          block at rest is saved with its paragraphs; and a resting macOS block keeps its
///          selection.
struct RichTextEditor: View {
    /// The entry's current RTF body (loaded once), or `nil` for an empty/plain prose block.
    let initialRTF: Data?
    /// Plain-text fallback used when `initialRTF` is `nil` (e.g. a pre-3b plain prose entry).
    let plainFallback: String
    /// The resting cap this editor opts into (#1360) — see ``RichTextRestingCap`` — or `nil` for a scrolling editor
    /// its caller sizes with a frame. An editor that opts in sizes itself, so its caller gives it no height frame.
    var restingCap: RichTextRestingCap? = nil
    /// Called on every edit with the new RTF and its plain-text projection.
    let onChange: (Data?, String) -> Void

    /// Bumped when an opted-in editor's height may have changed — editing began or ended, or a line was gained or
    /// lost while editing — so that SwiftUI asks the representable for its size again (#1360).
    @State private var sizingRevision = 0

    #if os(macOS)
    /// Bridges the SwiftUI toolbar to the live `NSTextView` (selection state + actions).
    @StateObject private var controller = RichTextEditorController()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            RichTextFormattingBar(controller: controller)
            RichTextPlatformEditor(initialRTF: initialRTF, plainFallback: plainFallback,
                                   restingCap: restingCap, sizingRevision: sizingRevision,
                                   invalidateSizing: invalidateSizing,
                                   onChange: onChange, controller: controller)
        }
    }
    #else
    var body: some View {
        RichTextPlatformEditor(initialRTF: initialRTF, plainFallback: plainFallback,
                               restingCap: restingCap, sizingRevision: sizingRevision,
                               invalidateSizing: invalidateSizing, onChange: onChange)
    }
    #endif

    /// Asks SwiftUI to size the editor again: ``sizingRevision``'s only writer.
    private func invalidateSizing() {
        sizingRevision &+= 1
    }
}

// MARK: - RichTextRestingCap

/// How a ``RichTextEditor`` that opts in sizes itself (#1360). At rest — when nobody is editing it — it does not
/// scroll, it is as tall as its text up to ``lines`` lines, and a longer text's last line ends in an ellipsis. While it
/// is being edited the cap lifts: it scrolls to follow the caret and is as tall as its text between ``minHeight`` and
/// ``editingMaxHeight`` — but never shorter than it rested (``editingHeight(fitting:resting:)``). Ending the edit
/// restores the cap, scrolled back to the top. Before #1360 the scrolling editor sat at its frame's least height while
/// it was edited; it now grows with its text.
///
/// **Why.** A collection's note block used to be a scrolling text view in a fixed 60–220 pt frame. A long block was cut
/// through a line at the frame's edge with no ellipsis, and one typed in place was left scrolled to its END, because a
/// text view follows the caret and nothing scrolled it back. No scroll indicator said there was more.
///
/// **Why a cap on the same text view, not a read-only preview.** A tap on a resting block puts the caret where it
/// lands and the formatting stays in view, with no second surface: no inspector edits prose, and the Mac leaves prose
/// out of its entry inspector on purpose. The spike that preceded #1360 measured tail truncation in an EDITABLE
/// TextKit 2 text view on both platforms — the ellipsis draws, the fitting height honours the line cap, and both
/// survive lifting and restoring the cap. Nothing here reads `layoutManager`, which would drop the view to TextKit 1.
///
/// **Paragraphs.** A text view's tail truncation draws its ellipsis only when the cut falls INSIDE a paragraph. Where
/// the last line allowed is a blank line between paragraphs, or a paragraph's own last line, it draws those lines
/// clean, with nothing to say there is more — measured on both platforms in review of #1360's first build, over the
/// blank-line-separated paragraphs a real block holds. So at rest the block is drawn as one paragraph:
/// see ``RichTextRestingText``.
///
/// **The cap is layout only.** The text storage keeps every character — at rest a paragraph break is swapped for a
/// line break, one character for one, and swapped back before editing begins — so VoiceOver reads the whole block,
/// editing starts on the text as stored, and the editor reports the text as stored, never the line breaks it draws.
/// That holds for a change made while the block rests, too, which the Mac's formatting bar can make: the report puts
/// the breaks back on a copy (``RichTextRestingText/withBreaksRestored(_:)``).
///
/// Version history:
///   1.0 — #1360: initial implementation
///   1.1 — #1360 review, round 1: ``editingHeight(fitting:resting:)``. At an accessibility text size six resting lines
///          outgrow the editing height (292 pt at AX3 against 220), and beginning to edit used to SHRINK the block; it
///          now keeps at least its resting height.
struct RichTextRestingCap: Equatable, Sendable {
    /// The most lines drawn at rest; a text that runs past them ends its last line in an ellipsis.
    let lines: Int
    /// The editor's least height, at rest and while editing — the tap target an empty block keeps.
    let minHeight: CGFloat
    /// The editor's greatest height while editing, past which it scrolls to follow the caret.
    let editingMaxHeight: CGFloat

    /// A note block in the collection outline (``CollectionProseRow``): six lines at rest, and while editing the
    /// 60–220 pt bounds of the frame its row used to carry.
    static let proseBlock = RichTextRestingCap(lines: 6, minHeight: 60, editingMaxHeight: 220)
    /// A collection's introduction in Collection settings (the iPad sheet, the iPhone screen, and the macOS sheet
    /// editor): six lines at rest, and while editing the 80–200 pt bounds of its old frame.
    static let introduction = RichTextRestingCap(lines: 6, minHeight: 80, editingMaxHeight: 200)
    /// A collection's introduction in the macOS manager's ⚙ Collection popover, which is shorter: six lines at rest,
    /// and while editing the 80–180 pt bounds of its old frame.
    static let introductionInPopover = RichTextRestingCap(lines: 6, minHeight: 80, editingMaxHeight: 180)

    /// The editor's height while it is edited, from its text's full height at some width (`fitting`) and the height it
    /// rests at at the same width (`resting`): `fitting`, no less than ``minHeight`` and no more than
    /// ``editingMaxHeight`` — or than `resting`, when that is taller. The cap counts LINES and the editing height POINTS,
    /// so at an accessibility text size the resting lines outgrow the editing height, and without the second bound
    /// beginning to edit would make the block SHORTER, the opposite of lifting its cap.
    func editingHeight(fitting: CGFloat, resting: CGFloat) -> CGFloat {
        min(max(fitting, minHeight), max(editingMaxHeight, resting))
    }
}

// MARK: - RichTextRestingText

/// The text a resting editor DRAWS (#1360): its paragraph breaks swapped for line breaks (U+2028), so the whole block
/// lays out as one paragraph and tail truncation — which draws its ellipsis only for a cut inside a paragraph — draws
/// it wherever the cap falls. Lines break where they did and blank lines stay blank, and each swap is one UTF-16 unit
/// for one, so every character keeps its index and its attributes. A break after the text's last visible character is
/// left alone: past it there is nothing more to mark. Where the cap falls on a blank line the ellipsis ends the line
/// above it, one line short of the cap: iOS lays the text out that way itself, and the Mac is made to (see the macOS
/// ``RichTextRestingLayout``).
///
/// Each swapped character carries ``replacedBreak``, holding the break it replaced, and ``restoreBreaks(in:)`` puts
/// back exactly those — a line break the reader typed or pasted is never touched. The swap is made on the text storage
/// directly, never through the text view's editing path, so the swap itself is not reported and cannot be undone. A
/// CR-LF pair is left as it is, so a block holding one can still rest on a clean line at that break.
///
/// **A resting block can still be changed, and what it reports must not carry the swap.** The Mac's formatting bar sits
/// above every block and its buttons take no focus, so Bold, Italic, Underline, Link or a colour applies to the text
/// view's kept selection while the block rests, and the change is reported from a storage holding line breaks. Before
/// review round 2 it was reported as drawn, the block's paragraphs were saved as one, and every export merged them.
/// So the editor reports ``withBreaksRestored(_:)``: the breaks back, on a copy, and the resting block left as drawn.
///
/// Version history:
///   1.0 — #1360 review, round 1: initial implementation
///   1.1 — #1360 review, round 2: ``withBreaksRestored(_:)``, which the editor's report goes through
enum RichTextRestingText {
    /// Marks a paragraph break drawn as a line break; its value is the break it replaced, as a `String`.
    static let replacedBreak = NSAttributedString.Key("FRUSRestingParagraphBreak")
    /// LINE SEPARATOR: it ends a line without ending the paragraph.
    private static let lineSeparator: unichar = 0x2028

    /// Swaps every paragraph break before `text`'s last visible character for a line break, in place. Swapping a text
    /// already swapped changes nothing.
    static func drawBreaksAsLines(in text: NSMutableAttributedString) {
        restoreBreaks(in: text)
        let string = text.string as NSString
        let visible = string.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted, options: .backwards)
        guard visible.location != NSNotFound else { return }
        var breaks: [(index: Int, original: String)] = []
        for index in 0..<visible.location {
            let unit = string.character(at: index)
            let isBreak: Bool
            switch unit {
            case 0x0A: isBreak = index == 0 || string.character(at: index - 1) != 0x0D
            case 0x0D: isBreak = string.character(at: index + 1) != 0x0A
            case 0x2029, 0x0085: isBreak = true
            default: isBreak = false
            }
            if isBreak { breaks.append((index, String(utf16CodeUnits: [unit], count: 1))) }
        }
        guard !breaks.isEmpty else { return }
        let separator = String(utf16CodeUnits: [lineSeparator], count: 1)
        text.beginEditing()
        for (index, original) in breaks {
            let range = NSRange(location: index, length: 1)
            text.replaceCharacters(in: range, with: separator)
            text.addAttribute(replacedBreak, value: original, range: range)
        }
        text.endEditing()
    }

    /// Puts back every paragraph break ``drawBreaksAsLines(in:)`` swapped, in place, and clears their marks.
    static func restoreBreaks(in text: NSMutableAttributedString) {
        var swapped: [(range: NSRange, original: String)] = []
        text.enumerateAttribute(replacedBreak, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let original = value as? String, (original as NSString).length == 1 { swapped.append((range, original)) }
        }
        guard !swapped.isEmpty else { return }
        text.beginEditing()
        for (range, original) in swapped {
            text.removeAttribute(replacedBreak, range: range)
            for index in range.location..<NSMaxRange(range)
            where (text.string as NSString).character(at: index) == lineSeparator {
                text.replaceCharacters(in: NSRange(location: index, length: 1), with: original)
            }
        }
        text.endEditing()
    }

    /// A copy of `text` as it rests — to measure the resting height of a text that is being edited.
    static func withBreaksDrawnAsLines(_ text: NSAttributedString) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: text)
        drawBreaksAsLines(in: copy)
        return copy
    }

    /// `text` as it is stored: a copy with every paragraph break ``drawBreaksAsLines(in:)`` swapped put back, or `text`
    /// itself when it holds no swapped break. What the editor reports, so a change made to a RESTING block is saved
    /// with its paragraphs, and the block goes on drawing its breaks as lines.
    static func withBreaksRestored(_ text: NSAttributedString) -> NSAttributedString {
        var swapped = false
        text.enumerateAttribute(replacedBreak, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            if value != nil {
                swapped = true
                stop.pointee = true
            }
        }
        guard swapped else { return text }
        let copy = NSMutableAttributedString(attributedString: text)
        restoreBreaks(in: copy)
        return copy
    }
}

#if os(iOS)
// MARK: - RichTextRestingLayout (iOS)

/// The two layouts an opted-in iOS editor moves between (#1360), and the size it hands SwiftUI in each. The
/// representable's coordinator calls ``rest(_:cap:)`` and ``lift(_:)`` when editing ends and begins, and its
/// `sizeThatFits` calls ``size(for:of:cap:editing:)``; the representable is private, so this is where tests reach the
/// arithmetic it uses.
@MainActor
enum RichTextRestingLayout {
    /// Puts `textView` at rest under `cap`: its paragraph breaks drawn as line breaks (``RichTextRestingText``),
    /// scrolling off, at most `cap.lines` lines with the last ending in an ellipsis, and scrolled back to the top —
    /// where following the caret may have left it scrolled to the end.
    static func rest(_ textView: UITextView, cap: RichTextRestingCap) {
        RichTextRestingText.drawBreaksAsLines(in: textView.textStorage)
        textView.textContainer.maximumNumberOfLines = cap.lines
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.isScrollEnabled = false
        textView.setContentOffset(CGPoint(x: -textView.adjustedContentInset.left,
                                          y: -textView.adjustedContentInset.top), animated: false)
    }

    /// Lifts the cap for editing: the paragraph breaks back, every line, word-wrapped, and scrolling on. The selection
    /// the reader's tap placed is kept, and the resting mark is kept out of what they type next.
    static func lift(_ textView: UITextView) {
        let selection = textView.selectedRange
        RichTextRestingText.restoreBreaks(in: textView.textStorage)
        if textView.typingAttributes[RichTextRestingText.replacedBreak] != nil {
            textView.typingAttributes[RichTextRestingText.replacedBreak] = nil
        }
        if textView.selectedRange != selection, NSMaxRange(selection) <= textView.textStorage.length {
            textView.selectedRange = selection
        }
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.isScrollEnabled = true
    }

    /// The editor's height at `width`: its text's height under the container's current cap, rounded up and no less than
    /// `cap.minHeight` — and while `editing`, bounded by ``RichTextRestingCap/editingHeight(fitting:resting:)``, so
    /// never under the height the text rests at.
    static func height(of textView: UITextView, width: CGFloat, cap: RichTextRestingCap, editing: Bool) -> CGFloat {
        let fitting = max(fittingHeight(of: textView, width: width), cap.minHeight)
        guard editing, fitting > cap.editingMaxHeight else { return fitting }
        return cap.editingHeight(fitting: fitting, resting: restingHeight(of: textView, width: width, cap: cap))
    }

    /// The height `textView`'s text would rest at under `cap` at `width`, asked while the live view is being edited and
    /// its text has outgrown the editing height. Measured on ``probe`` given the resting text, because the live view's
    /// cap is lifted, and capping it to measure would lay out again the text the reader is typing into.
    static func restingHeight(of textView: UITextView, width: CGFloat, cap: RichTextRestingCap) -> CGFloat {
        probe.textContainerInset = textView.textContainerInset
        probe.textContainer.lineFragmentPadding = textView.textContainer.lineFragmentPadding
        probe.attributedText = RichTextRestingText.withBreaksDrawnAsLines(textView.attributedText ?? NSAttributedString())
        probe.isScrollEnabled = false
        probe.textContainer.maximumNumberOfLines = cap.lines
        probe.textContainer.lineBreakMode = .byTruncatingTail
        return max(fittingHeight(of: probe, width: width), cap.minHeight)
    }

    /// The text view ``restingHeight(of:width:cap:)`` measures on. Never on screen.
    private static let probe = UITextView()

    /// `textView`'s text height at `width` under its container's current settings, rounded up.
    private static func fittingHeight(of textView: UITextView, width: CGFloat) -> CGFloat {
        textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height.rounded(.up)
    }

    /// The size the representable hands SwiftUI: the offered width and ``height(of:width:cap:editing:)``,
    /// whatever height is offered, since a capped editor is as tall as its lines. `nil` — SwiftUI's own sizing —
    /// when no finite width is offered, because text laid out at an unbounded width would be one line long.
    static func size(for proposal: ProposedViewSize, of textView: UITextView,
                     cap: RichTextRestingCap, editing: Bool) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        return CGSize(width: width, height: height(of: textView, width: width, cap: cap, editing: editing))
    }
}
#endif

#if os(macOS)
// MARK: - RichTextRestingLayout (macOS)

/// The two layouts an opted-in macOS editor moves between (#1360), and the size it hands SwiftUI in each — the twin of
/// the iOS type of the same name, over the `NSScrollView` that holds the text view. At rest the scroller is hidden and
/// the text view is exactly as tall as its capped lines, so there is nothing to scroll.
///
/// **One case the Mac needs that iOS does not.** Even with the paragraph breaks drawn as line breaks
/// (``RichTextRestingText``), a cap that falls on a BLANK line draws no ellipsis on the Mac: TextKit drops the blank line
/// and draws the line above it clean, where iOS draws the ellipsis on it (both measured, TextKit 2, macOS 27 and iOS
/// 26.5). So the Mac rests one line short in that case — ``restingLines(of:width:cap:)`` — and counts again when its
/// width changes, since a new width moves every line.
@MainActor
enum RichTextRestingLayout {
    /// Puts the editor at rest under `cap`: its paragraph breaks drawn as line breaks, at most
    /// ``restingLines(of:width:cap:)`` lines with the last ending in an ellipsis, no scroller, and scrolled back to the
    /// top. The selection is kept, as `NSTextView` keeps it when focus goes: swapping the breaks moved a selection
    /// lying between two of them to a caret after the last (measured, TextKit 2 on macOS 27), where one before the
    /// first or after the last stayed put.
    static func rest(_ scrollView: NSScrollView, cap: RichTextRestingCap) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let selection = textView.selectedRanges
        if let storage = textView.textStorage { RichTextRestingText.drawBreaksAsLines(in: storage) }
        if textView.selectedRanges != selection { textView.selectedRanges = selection }
        textView.textContainer?.lineBreakMode = .byTruncatingTail
        textView.textContainer?.maximumNumberOfLines = restingLines(of: textView, width: scrollView.frame.width,
                                                                    cap: cap)
        scrollView.hasVerticalScroller = false
        textView.sizeToFit()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Counts again the lines a resting editor draws, at its current width.
    static func recount(_ scrollView: NSScrollView, cap: RichTextRestingCap) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let lines = restingLines(of: textView, width: scrollView.frame.width, cap: cap)
        guard textView.textContainer?.maximumNumberOfLines != lines else { return }
        textView.textContainer?.maximumNumberOfLines = lines
        // A new line count alone does not lay out again the lines already laid out at this width, and neither does
        // invalidating them: measured, both kept the old truncation and drew no ellipsis until the viewport was laid
        // out again.
        if let layout = textView.textLayoutManager {
            layout.invalidateLayout(for: layout.documentRange)
            layout.textViewportLayoutController.layoutViewport()
        }
        textView.sizeToFit()
    }

    /// Lifts the cap for editing: the paragraph breaks back, every line, word-wrapped, with the scroller back. The
    /// selection the reader's click placed is kept, and the resting mark is kept out of what they type next.
    static func lift(_ scrollView: NSScrollView) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let selection = textView.selectedRanges
        if let storage = textView.textStorage { RichTextRestingText.restoreBreaks(in: storage) }
        if textView.typingAttributes[RichTextRestingText.replacedBreak] != nil {
            textView.typingAttributes[RichTextRestingText.replacedBreak] = nil
        }
        if textView.selectedRanges != selection { textView.selectedRanges = selection }
        textView.textContainer?.maximumNumberOfLines = 0
        textView.textContainer?.lineBreakMode = .byWordWrapping
        scrollView.hasVerticalScroller = true
        textView.sizeToFit()
    }

    /// The editor's height at `width`: its text's height — capped at `cap.lines` at rest — no less than `cap.minHeight`,
    /// and while `editing` bounded by ``RichTextRestingCap/editingHeight(fitting:resting:)``, so never under the height
    /// the text rests at.
    static func height(of textView: NSTextView, width: CGFloat, cap: RichTextRestingCap, editing: Bool) -> CGFloat {
        let text = textView.attributedString()
        guard editing else {
            return max(textHeight(of: text, like: textView, width: width, lines: cap.lines), cap.minHeight)
        }
        let fitting = max(textHeight(of: text, like: textView, width: width, lines: 0), cap.minHeight)
        guard fitting > cap.editingMaxHeight else { return fitting }
        let resting = textHeight(of: RichTextRestingText.withBreaksDrawnAsLines(text), like: textView, width: width,
                                 lines: cap.lines)
        return cap.editingHeight(fitting: fitting, resting: max(resting, cap.minHeight))
    }

    /// The lines a resting editor draws at `width`: `cap.lines`, or fewer when the cap would fall on a blank line —
    /// which the Mac draws no ellipsis on. A blank last line adds no height to the capped layout, so the count steps
    /// back while one line fewer is just as tall. Only when the text runs past the cap: a text that fits has no
    /// ellipsis to draw.
    static func restingLines(of textView: NSTextView, width: CGFloat, cap: RichTextRestingCap) -> Int {
        let text = RichTextRestingText.withBreaksDrawnAsLines(textView.attributedString())
        let capped = textHeight(of: text, like: textView, width: width, lines: cap.lines)
        guard capped < textHeight(of: text, like: textView, width: width, lines: 0) else { return cap.lines }
        var lines = cap.lines
        while lines > 1, textHeight(of: text, like: textView, width: width, lines: lines - 1) == capped {
            lines -= 1
        }
        return lines
    }

    /// The height `text` takes laid out as in `textView` at `width` in at most `lines` lines (`0`: every line), insets
    /// included. Measured on a scratch TextKit 2 stack over a copy of the text, so asking for a size never lays out,
    /// resizes or downgrades the live text view.
    static func textHeight(of text: NSAttributedString, like textView: NSTextView, width: CGFloat,
                           lines: Int) -> CGFloat {
        let inset = textView.textContainerInset
        let content = NSTextContentStorage()
        content.attributedString = text
        let layout = NSTextLayoutManager()
        content.addTextLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: max(width - 2 * inset.width, 1),
                                                     height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = textView.textContainer?.lineFragmentPadding ?? container.lineFragmentPadding
        container.maximumNumberOfLines = lines
        container.lineBreakMode = lines > 0 ? .byTruncatingTail : .byWordWrapping
        layout.textContainer = container
        layout.ensureLayout(for: layout.documentRange)
        return (layout.usageBoundsForTextContainer.height + 2 * inset.height).rounded(.up)
    }

    /// The size the representable hands SwiftUI: the offered width and ``height(of:width:cap:editing:)``, or `nil` —
    /// SwiftUI's own sizing — when no finite width is offered.
    static func size(for proposal: ProposedViewSize, of scrollView: NSScrollView,
                     cap: RichTextRestingCap, editing: Bool) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0,
              let textView = scrollView.documentView as? NSTextView else { return nil }
        return CGSize(width: width, height: height(of: textView, width: width, cap: cap, editing: editing))
    }
}

// MARK: - RichTextFocusTextView (macOS)

/// The macOS editor's text view: an `NSTextView` that says when it takes and gives up focus, which is when an editor
/// with a resting cap (#1360) lifts the cap and restores it. AppKit's own `textDidBeginEditing` arrives with the first
/// CHANGE, not with focus, so a reader who clicked into a resting block and moved the caret down would have walked into
/// lines the cap was hiding. It also says when its width changes, which is when a resting editor counts its lines again.
final class RichTextFocusTextView: NSTextView {
    /// Called with `true` when the view takes focus and `false` when it gives it up.
    var onFocusChange: ((Bool) -> Void)?
    /// Called when the view's width changes.
    var onWidthChange: (() -> Void)?

    /// Resizes as `NSTextView` does, then reports a change of width.
    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = abs(newSize.width - frame.width) > 0.5
        super.setFrameSize(newSize)
        if widthChanged { onWidthChange?() }
    }

    /// Takes focus as `NSTextView` does, then reports it when it took.
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocusChange?(true) }
        return became
    }

    /// Gives up focus as `NSTextView` does, then reports it when it went.
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }
}
#endif

// MARK: - RichTextPlatformEditor

/// The platform representable behind ``RichTextEditor``: wraps `NSTextView` (macOS) /
/// `UITextView` (iOS) and serialises every edit back to `(rtf, plainText)`.
private struct RichTextPlatformEditor {
    /// The entry's current RTF body (loaded once), or `nil` for an empty/plain prose block.
    let initialRTF: Data?
    /// Plain-text fallback used when `initialRTF` is `nil` (e.g. a pre-3b plain prose entry).
    let plainFallback: String
    /// The resting cap (#1360), or `nil` for an editor that always scrolls and is sized by its caller.
    let restingCap: RichTextRestingCap?
    /// ``RichTextEditor``'s sizing revision. Read nowhere: it is carried so that a bump is a change to this view, and
    /// SwiftUI asks it for its size again.
    let sizingRevision: Int
    /// Bumps ``sizingRevision``.
    let invalidateSizing: () -> Void
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

    /// Serialises the text view's storage to `(rtf, plainText)` and reports it — every report, on both platforms.
    ///
    /// A resting editor's storage draws its paragraph breaks as line breaks (#1360); they are put back here, on a copy,
    /// before anything is serialised (``RichTextRestingText/withBreaksRestored(_:)``). A block can be changed while it
    /// rests — the Mac's formatting bar acts on a text view without focus — and reporting the storage as drawn saved
    /// its paragraphs as one.
    ///
    /// On iOS the display fonts carry `UIFontMetrics`-scaled point sizes (see
    /// ``initialAttributed()``); they are normalised back to their base size here so the stored
    /// RTF never bakes in the reader's current Dynamic Type setting. Bold/italic/underline/colour/
    /// link — everything the exporters and the plain projection read — is preserved, so exports
    /// and `CollectionProse` are unaffected by the display scaling.
    fileprivate func report(_ storage: NSAttributedString) {
        let stored = RichTextRestingText.withBreaksRestored(storage)
        #if os(iOS)
        let toStore = Self.baseNormalizedForStorage(stored)
        #else
        let toStore = stored
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
/// The bar's buttons take no focus, so an action can reach a block RESTING under a cap
/// (#1360), whose storage draws its paragraph breaks as line breaks; the report puts them
/// back (``RichTextRestingText/withBreaksRestored(_:)``).
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
        let textView = RichTextFocusTextView()
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

        // #1360: focus lifts and restores a resting cap, and a new width counts its lines again. An editor that opts
        // in starts at rest.
        let coordinator = context.coordinator
        textView.onFocusChange = { [weak coordinator, weak scroll] focused in
            guard let coordinator, let scroll else { return }
            coordinator.focusChanged(focused, in: scroll)
        }
        textView.onWidthChange = { [weak coordinator, weak scroll] in
            guard let coordinator, let scroll else { return }
            coordinator.widthChanged(in: scroll)
        }
        if let restingCap { RichTextRestingLayout.rest(scroll, cap: restingCap) }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Rebind the coordinator's callback to the CURRENT entry. The row (and its text view)
        // may have been reused for a different entry after a reorder/delete — the managers use
        // an index-based `$sortedEntries[idx]` binding — so a make-time closure would write to
        // the wrong entry (or trap on a stale index).
        context.coordinator.report = report
        context.coordinator.controller = controller
        context.coordinator.restingCap = restingCap
        context.coordinator.invalidateSizing = invalidateSizing
    }

    /// The size of an editor that opts into a resting cap (#1360) — see ``RichTextRestingLayout``. `nil`, SwiftUI's
    /// own sizing under the caller's frame, for one that does not.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let restingCap else { return nil }
        return RichTextRestingLayout.size(for: proposal, of: nsView, cap: restingCap,
                                          editing: context.coordinator.isEditing)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(report: report, controller: controller, restingCap: restingCap,
                    invalidateSizing: invalidateSizing)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        // Drop the shared colour panel's target if it still points at this editor's
        // controller (v1.2) — otherwise the panel outlives the collection editor with
        // a dangling target.
        coordinator.controller.releaseColorPanel()
    }

    /// Forwards `NSTextView` edits back to the entry and selection changes to the toolbar,
    /// and hands the shared colour panel to this editor whenever it gains focus (v1.2). For an
    /// editor with a resting cap it also lifts the cap on focus and restores it when focus goes
    /// (#1360). Main-actor isolated, as every call into it is: `NSTextViewDelegate` isolates its
    /// requirements but not a conformer's own methods, and the focus handler reaches the text view.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate var report: (NSAttributedString) -> Void
        /// The toolbar bridge whose published state follows this text view.
        fileprivate var controller: RichTextEditorController
        /// The resting cap (#1360), or `nil` for an editor that always scrolls.
        fileprivate var restingCap: RichTextRestingCap?
        /// Asks SwiftUI to size the editor again.
        fileprivate var invalidateSizing: () -> Void
        /// Whether the text view has focus and its cap is lifted, as the text view last reported.
        fileprivate private(set) var isEditing = false
        /// The height last asked of SwiftUI for a text change, so a change asks again only when a line comes or goes.
        private var reportedHeight: CGFloat?

        init(report: @escaping (NSAttributedString) -> Void,
             controller: RichTextEditorController,
             restingCap: RichTextRestingCap?,
             invalidateSizing: @escaping () -> Void) {
            self.report = report
            self.controller = controller
            self.restingCap = restingCap
            self.invalidateSizing = invalidateSizing
        }

        /// Lifts the cap when the text view takes focus and restores it, scrolled to the top, when focus goes. A no-op
        /// for an editor with no cap.
        fileprivate func focusChanged(_ focused: Bool, in scrollView: NSScrollView) {
            guard let restingCap else { return }
            if focused {
                RichTextRestingLayout.lift(scrollView)
            } else {
                RichTextRestingLayout.rest(scrollView, cap: restingCap)
            }
            isEditing = focused
            reportedHeight = nil
            requestSizing()
        }

        /// Counts again the lines a resting editor draws once its width has changed — after the layout pass that
        /// changed it, which is no time to change the container. A no-op for an editor with no cap or one being edited.
        fileprivate func widthChanged(in scrollView: NSScrollView) {
            guard restingCap != nil, !isEditing else { return }
            Task { @MainActor [weak self, weak scrollView] in
                guard let self, let scrollView, let restingCap = self.restingCap, !self.isEditing else { return }
                RichTextRestingLayout.recount(scrollView, cap: restingCap)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
            report(storage)
            controller.refreshSelectionState()
            // A capped editor follows its text's height — up to the editing height while it is edited (#1360).
            guard let restingCap else { return }
            let width = tv.enclosingScrollView?.frame.width ?? tv.frame.width
            let height = RichTextRestingLayout.height(of: tv, width: width, cap: restingCap, editing: isEditing)
            if height != reportedHeight {
                reportedHeight = height
                requestSizing()
            }
        }

        /// Asks SwiftUI for the editor's size again once this callback has returned: focus can change while SwiftUI is
        /// updating (a row torn down while it has focus), and state written during an update is refused.
        private func requestSizing() {
            Task { @MainActor [weak self] in self?.invalidateSizing() }
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
        // #1360: an editor that opts into a resting cap starts at rest.
        if let restingCap { RichTextRestingLayout.rest(textView, cap: restingCap) }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Rebind the coordinator's callback to the CURRENT entry (see the macOS note above).
        context.coordinator.report = report
        context.coordinator.restingCap = restingCap
        context.coordinator.invalidateSizing = invalidateSizing
    }

    /// The size of an editor that opts into a resting cap (#1360) — see ``RichTextRestingLayout``. `nil`, SwiftUI's
    /// own sizing under the caller's frame, for one that does not.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let restingCap else { return nil }
        return RichTextRestingLayout.size(for: proposal, of: uiView, cap: restingCap,
                                          editing: context.coordinator.isEditing)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(report: report, restingCap: restingCap, invalidateSizing: invalidateSizing)
    }

    /// Forwards `UITextView` edits back to the entry and hosts the keyboard-attached
    /// formatting toolbar (Bold, Italic, Underline, text colour, Link). For an editor with a
    /// resting cap it also lifts the cap when editing begins and restores it when editing
    /// ends (#1360) — but not while the colour picker or link alert it put up has taken focus.
    final class Coordinator: NSObject, UITextViewDelegate, UIColorPickerViewControllerDelegate {
        fileprivate var report: (NSAttributedString) -> Void
        /// The live text view the toolbar drives.
        fileprivate weak var textView: UITextView?
        /// The Link toolbar item — enabled only while a non-empty range is selected.
        private weak var linkItem: UIBarButtonItem?
        /// The selection captured when the colour picker was presented (the picker can take
        /// focus from the text view — its own fields do — so the range is applied back afterwards).
        private var colorTargetRange: NSRange?
        /// The resting cap (#1360), or `nil` for an editor that always scrolls.
        fileprivate var restingCap: RichTextRestingCap?
        /// Asks SwiftUI to size the editor again.
        fileprivate var invalidateSizing: () -> Void
        /// Whether the text view is being edited and its cap is lifted, as the delegate last heard.
        fileprivate private(set) var isEditing = false
        /// The height last asked of SwiftUI for a text change, so a change asks again only when a line comes or goes.
        private var reportedHeight: CGFloat?
        /// The formatting sheet — the colour picker or the link alert — this editor put up and has not yet heard is
        /// done (#1360). Either can take focus from the text view — the alert's field at once, the picker's own fields
        /// once the reader types a value (opening the picker does not, measured on iOS 26.5) — which ENDS editing while
        /// the reader is still formatting. While one is up, a capped block stays open behind it rather than collapsing
        /// to its resting lines, scrolled to the top, over the range being formatted. Weak, and read through its
        /// `presentingViewController`, so a sheet that has gone no longer stops the next end of editing from resting
        /// the block. It does not rest the block itself: a sheet that took focus and went without saying it was done
        /// — no `colorPickerViewControllerDidFinish`, no alert action — leaves the block open without focus until the
        /// reader next edits it and that edit ends.
        private weak var formattingSheet: UIViewController?

        init(report: @escaping (NSAttributedString) -> Void,
             restingCap: RichTextRestingCap?,
             invalidateSizing: @escaping () -> Void) {
            self.report = report
            self.restingCap = restingCap
            self.invalidateSizing = invalidateSizing
        }

        func textViewDidChange(_ textView: UITextView) {
            report(textView.attributedText ?? NSAttributedString())
            // A capped editor follows its text's height — up to the editing height while it is edited (#1360).
            guard let restingCap else { return }
            let height = RichTextRestingLayout.height(of: textView, width: textView.bounds.width,
                                                      cap: restingCap, editing: isEditing)
            if height != reportedHeight {
                reportedHeight = height
                requestSizing()
            }
        }

        /// Lifts a resting cap for editing (#1360). A no-op for an editor with no cap, and for one still open — focus
        /// coming back from a formatting sheet, which never closed it.
        func textViewDidBeginEditing(_ textView: UITextView) {
            guard restingCap != nil, !isEditing else { return }
            RichTextRestingLayout.lift(textView)
            isEditing = true
            reportedHeight = nil
            requestSizing()
        }

        /// Restores a resting cap when editing ends, scrolled back to the top (#1360): the text view followed the
        /// caret while it was being typed in, and would otherwise be left showing the block's end. A no-op for an
        /// editor with no cap, and while a formatting sheet this editor put up has the focus it took — the reader is
        /// mid-format, not done.
        func textViewDidEndEditing(_ textView: UITextView) {
            guard restingCap != nil, formattingSheet?.presentingViewController == nil else { return }
            restAfterEditing(textView)
        }

        /// Puts the block at rest, scrolled to the top, and asks SwiftUI for its resting size.
        private func restAfterEditing(_ textView: UITextView) {
            guard let restingCap else { return }
            RichTextRestingLayout.rest(textView, cap: restingCap)
            isEditing = false
            reportedHeight = nil
            requestSizing()
        }

        /// Called when a formatting sheet this editor put up is done. If focus has come back to the text view the block
        /// stays open; if not, the edit the sheet interrupted ended with it, and on the next turn the block is put at
        /// rest. Measured on iOS 26.5, closing the colour picker from one of its own fields does not hand focus back,
        /// and the link alert's Cancel does (in the unit tests' host, where the alert is dismissed and its handler then
        /// run as a tap does), so after the alert the block stays open.
        private func formattingSheetEnded() {
            formattingSheet = nil
            Task { @MainActor [weak self] in
                guard let self, self.isEditing, let textView = self.textView, !textView.isFirstResponder else { return }
                self.restAfterEditing(textView)
            }
        }

        /// Asks SwiftUI for the editor's size again once this callback has returned: editing can end while SwiftUI is
        /// updating (a row torn down while its text view has focus), and state written during an update is refused.
        private func requestSizing() {
            Task { @MainActor [weak self] in self?.invalidateSizing() }
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
            // put the keyboard away. Appending here is the fix, and it reaches every iOS mount
            // site — the collection Introduction, CollectionProseRow, and (since #1281) the
            // research note's body — because all three funnel through this one representable.
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
            //
            // `.prominent`, which is what `.done` was renamed to in iOS 26 — a rename, not a
            // behaviour change, and unconditional because the deployment target is 26.0. It is
            // the emphasised style, which is the point: Done is this bar's confirming action and
            // reads heavier than the five formatting controls beside it.
            let done = UIBarButtonItem(
                title: String(localized: "common.keyboard.done", defaultValue: "Done"),
                style: .prominent, target: self, action: #selector(dismissKeyboard))
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
            formattingSheet = picker
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
                    self?.formattingSheetEnded()
                })
            if !existingURL.isEmpty {
                alert.addAction(UIAlertAction(
                    title: String(localized: "collection.richtext.link.remove",
                                  defaultValue: "Remove Link"),
                    style: .destructive) { [weak self] _ in
                        self?.applyLink("", range: range)
                        self?.formattingSheetEnded()
                    })
            }
            alert.addAction(UIAlertAction(
                title: String(localized: "collection.richtext.link.cancel", defaultValue: "Cancel"),
                style: .cancel) { [weak self] _ in
                    self?.formattingSheetEnded()
                })
            formattingSheet = alert
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

        /// Applies the picked colour to the captured selection (or typing attributes), and ends the picker's hold on
        /// a capped block (#1360).
        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            applyColor(viewController.selectedColor)
            formattingSheetEnded()
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
