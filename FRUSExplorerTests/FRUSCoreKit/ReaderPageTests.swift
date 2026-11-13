// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
import SwiftUI
#endif
// SHA-256 is CryptoKit's on Apple platforms; on Linux the web edition supplies swift-crypto's Crypto.
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - ReaderPageTests

/// The reader's page (`ReaderPage.swift`), which the app's `HTMLTemplate.build` and
/// `FRUSTheme.cssVariables` forward to, and which FRUS Explorer Light serves.
///
/// Version history:
///   1.0 — Session 2026-10-05 (FRUS Explorer Light, S8a): initial implementation
///   1.1 — Session 2026-10-06 (FRUS Explorer Light, S9b): the heads are re-pinned for the AA palette
///          and the underlined links; every text colour is measured against WCAG 2.2 AA, and the
///          person and cross-reference links' underline is required
///   1.2 — Session 2026-10-08: the two links print without their underline (the owner's decision), so
///          the stylesheet is read by medium: a rule inside `@media print` is paper's alone, the
///          screen's underline test no longer reads it, and the heads are re-pinned for the block
///   1.3 — Session 2026-10-09: #1602 — the heads are re-pinned for the highlight text colour and
///          the footnote wash; every text colour is measured on the wash, and a highlight's text
///          colour over every tint. `CollectionExportContrastTests`, Xcode's alone, measures the
///          collection HTML export's own layer
///   1.4 — Session 2026-10-11: #1599 — the heads are re-pinned for the two lists below a document
///          that names its people and terms on `@ana`
///   1.5 — Session 2026-10-16: #1665 — the heads are re-pinned for `--reader-measure`, and
///          `theMeasureIsTheHosts` says what it does
///   1.6 — 2026-11-08: the heads are re-pinned for the index entry's arrival wash (Lane 2 of the
///          editors' annotations follow-ups plan), and the wash is drawn in four places
///   1.7 — 2026-11-11 (FRUS Explorer Light, S21b's follow-up): the heads are re-pinned for the
///          rule that makes the links of a list item of links alone boxes at least 24 px square
///          (WCAG 2.2's 2.5.8), which a test reads; `LinksAloneTargetRenderTests`, Xcode's alone,
///          measures the boxes in WebKit
///   1.8 — 2026-11-12 (FRUS Explorer Light, S21b's follow-up): the heads are re-pinned for the gloss
///          links, the named lists and the footnote markers the rule now boxes; the test reads the
///          four rules, and `LinksAloneTargetRenderTests` measures the new boxes in WebKit
@Suite("FRUSCoreKit — the reader's page")
struct ReaderPageTests {

    /// The page before its fragment, through `<body>\n`, for each palette and size: its SHA-256 and
    /// its length in UTF-8 bytes. It depends on the palette and the size alone, and both the app's
    /// reader and FRUS Explorer Light serve it, so a change to it is made on purpose and re-pins
    /// all eight here, saying why:
    /// - #1575 pinned the bytes the app's `HTMLTemplate.build` wrote on `v2` at `f69b4a0a`, before
    ///   the page moved into the kit, which showed the move changed nothing.
    /// - Session 2026-10-06 (FRUS Explorer Light, S9b) re-pinned them for WCAG 2.2 AA. The variables
    ///   give the light palette a darker secondary, accent and person-name colour and the dark one a
    ///   brighter accent and person-name colour, and the stylesheet underlines `a.pers-name` and
    ///   `a.cross-ref`. The stylesheet is in every head, so no pin kept its value. Each head grew by
    ///   519 bytes, all of them the stylesheet's (the link rules and their comment): every new colour
    ///   is as long as the one it replaced. Nothing else in the head moved: with the five colours and
    ///   the link rules put back, all eight heads were #1575's pins byte for byte when these were
    ///   taken. The WCAG tests below say what the colours and the link rules must do.
    /// - Session 2026-10-08 re-pinned them for the print block: on paper the two links print without
    ///   their underline, the owner's answer to the question #1578 left open. The stylesheet is in
    ///   every head, so no pin kept its value. Each head grew by 256 bytes, all of them the stylesheet's
    ///   (the `@media print` rule, its comment and a blank line). With the block taken out, all eight
    ///   heads were the 2026-10-06 pins byte for byte when these were taken: the suite passed on them
    ///   but for the print test, which failed.
    /// - Session 2026-10-09 re-pinned them for #1602, two of the places #1578 left under 4.5:1. The
    ///   variables gain `--color-highlight-text` and `--color-accent-wash`; the stylesheet draws all
    ///   text inside a `::highlight(frus-…)` in the first, names the palette's own wash where it had
    ///   named a variable no palette defined, and gains the two comments that say so. Each light head
    ///   grew by 679 bytes and each dark one by 683: the dark palette's two new values are four
    ///   characters longer than the light one's. The tests under "#1602" below say what the two
    ///   variables must do.
    /// - Session 2026-10-11 re-pinned them for #1599: the stylesheet gains `.named-references` and
    ///   `.named-list`, the two lists the reader writes below a document that names its people and
    ///   terms on `@ana`, with their comment. Each head grew by 537 bytes, all of them those rules.
    ///   No variable and no other rule changed: the lists take the footnote list's size and
    ///   colour and the footnotes section's rule and headings. `NamedReferencesTests`
    ///   (`ReaderRenderingTests.swift`) says what the reader writes there.
    /// - Session 2026-10-16 re-pinned them for #1665: the column's measure is the host's. The
    ///   variables gain `--reader-measure`, 70ch on a page built with no measure, as these are, and
    ///   the stylesheet's `.frus-document` reads it (`max-width: var(--reader-measure, 70ch)`) where
    ///   it had a fixed `70ch`, with its comment saying why. Each head grew by 125 bytes: 35 for the
    ///   variable's line and 90 for the stylesheet's rule and comment. Nothing else moved: with the
    ///   line taken out and the rule and comment put back, all eight heads were the 2026-10-11
    ///   pins byte for byte when these were taken. `theMeasureIsTheHosts` below says what the
    ///   variable must do, and `ReadingWidthTests` (Xcode's alone) what each measure holds.
    /// - 2026-11-08 re-pinned them for Lane 2 of `Planning/Editors-Annotations-Followups-2026-11-08.md`:
    ///   an index's "See" reference now scrolls to its entry within the index, and the stylesheet
    ///   gains the entry's arrival wash, `.frus-list > li` with the footnote entry's `scroll-margin-block`,
    ///   `.frus-list > li.ix-arrived` with the footnote's animation, the same rule under Reduce
    ///   Motion, and the comment that says so. Each head grew by 707 bytes, all of them that block;
    ///   no variable and no other rule changed, and the wash is the footnote's, so
    ///   `everyTextColourMeetsAAOnTheArrivalWash` below now finds it drawn in four places.
    /// - 2026-11-11 re-pinned them for WCAG 2.2's 2.5.8 (Target Size (Minimum)), which FRUS Explorer
    ///   Light's axe check found frus1961-63v06's index failing where its page numbers stand a
    ///   space apart with no comma between them: the stylesheet gains the rule that draws the
    ///   cross-reference and person links of a list item of links alone (`li.links-only`, which the
    ///   serializer writes) as boxes at least 24 px square on screen, with the comment that says why.
    ///   Each head grew by 1,683 bytes, all of them that block; no variable and no other rule
    ///   changed: with the block taken out, all eight heads were the 2026-11-08 pins byte for byte
    ///   when these were taken. `theLinksOfAnItemOfLinksAloneAre24PxTargets` below says what the rule
    ///   must be, and `LinksAloneTargetRenderTests` (Xcode's alone) what WebKit draws by it.
    /// - 2026-11-12 re-pinned them for what the 2026-11-11 block left small (FRUS Explorer Light's S21b
    ///   follow-up, #1898's leftovers): the block's box rule takes a list item's gloss links and the
    ///   two lists below a document that names its people and terms on `@ana` (`.named-list`), whose
    ///   lines stood about 22.6 px apart at Medium; a boxed gloss draws its dotted rule as a dotted
    ///   underline, which stays under the term, where its border would sit at the foot of the box;
    ///   and a footnote marker beside the links of such an item, whose box `line-height: 0` leaves
    ///   with no height, is a box 24 px square, its number at the top. Each head grew by 1,346 bytes,
    ///   all of them that block and its comment; no variable and no other rule changed: with the block
    ///   put back as it was, all eight heads were the 2026-11-11 pins byte for byte when these were
    ///   taken. `theLinksOfAnItemOfLinksAloneAre24PxTargets` below says what the rules must be, and
    ///   `LinksAloneTargetRenderTests` (Xcode's alone) what WebKit draws by them.
    static let heads: [String: (sha256: String, bytes: Int)] = [
        "light small": ("46b73fc5495b39b6945ef0be5b4aa1c7768d0cb4afb19b7e1640925bb8a663c5", 23603),
        "light medium": ("e6bf4902e19afc364e89844dbfdb9a7d176e5e0a87699f07b89f989d4f5b8f75", 23604),
        "light large": ("5619252f9c685bcf1cb05acd40ca6d2e41913cb4b45b6c900665965c086ae83c", 23604),
        "light extraLarge": ("4f0e7c854228fb5de04f9e432c6fdc995b353e694e0f8082ce82210921323eec", 23604),
        "dark small": ("9ef959c0ab12ae04fa072af098a03e133adef1fa095ba4bd4be3164daea4aaf5", 23633),
        "dark medium": ("b26a066df3f1a5fcfaa8aec644525af575a91a33bbaa32516b8007fed06cc3d9", 23634),
        "dark large": ("7195d8cf8007dd32187e5f5eefc0446984814ad74067c9028bbbde2c896cc2d1", 23634),
        "dark extraLarge": ("c79c2e9dc9acc445dc3e229cfa9153e8066d5d71c597f9a9d63185dd8cc8b6d5", 23634),
    ]

    /// `frus1946v01/d587`, whose three figures name images.
    private func model() async throws -> FRUSDocumentRenderModel {
        try await ListShapeFixtures.renderModel(FigureFixtures.d587,
                                                converter: ASTToRenderNodeConverter(volumeId: "frus1946v01"))
    }

    private static func sha256(_ bytes: some Sequence<UInt8>) -> String {
        SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
    }

    @Test("Around its fragment the page is byte for byte its pinned head, in both palettes at all four sizes")
    func thePageIsItsPinnedPage() async throws {
        let model = try await model()
        let body = Array((FRUSRenderNodeHTMLSerializer.reader.serialize(model) + "\n</body>\n</html>").utf8)
        for appearance in ReaderAppearance.allCases {
            for size in TextSizePreference.allCases {
                let key = "\(appearance.rawValue) \(size.rawValue)"
                let page = Array(ReaderPage.build(model: model, appearance: appearance, textSize: size).utf8)
                #expect(page.count > body.count && page.suffix(body.count).elementsEqual(body),
                        "\(key): the page does not end with the fragment, `</body>` and `</html>`")
                let head = page.dropLast(body.count)
                #expect(head.suffix(7).elementsEqual(Array("<body>\n".utf8)), "\(key): the fragment does not follow `<body>`")
                let expected = try #require(Self.heads[key])
                #expect(Self.sha256(head) == expected.sha256 && head.count == expected.bytes,
                        "\(key): the page's head is \(head.count) bytes with SHA-256 \(Self.sha256(head)), not its pin")
            }
        }
    }

    /// #1665: the column's measure is the host's. The app passes its Reading Width's (`ReadingWidth`,
    /// whose own suite measures each rung's characters a line); a page built with none keeps the
    /// 70ch it had, and so does the collection HTML export, which writes the variables with none.
    @Test("The host's measure is the page's --reader-measure, and a page that names none keeps 70ch (#1665)")
    func theMeasureIsTheHosts() async throws {
        #expect(ReaderMeasure.classic == ReaderMeasure(ch: 70))
        #expect(ReaderMeasure(ch: 87).css == "87ch")
        #expect(ReaderPage.cssVariables(appearance: .light).contains("--reader-measure:          70ch;"))
        #expect(ReaderPage.cssVariables(appearance: .dark, textSize: .large, measure: ReaderMeasure(ch: 120))
            .contains("--reader-measure:          120ch;"))
        #expect(ReaderPage.documentCSS.contains("max-width: var(--reader-measure, 70ch);"))
        #expect(!ReaderPage.documentCSS.contains("max-width: 70ch;"), "the column's measure is fixed again")
        let page = ReaderPage.build(model: try await model(), measure: ReaderMeasure(ch: 87))
        #expect(page.contains("--reader-measure:          87ch;"))
    }

    @Test("A host's head is added at the end of the page's head, and nothing else changes")
    func aHostsHeadIsAddedBeforeTheHeadsEnd() async throws {
        let model = try await model()
        let page = ReaderPage.build(model: model)
        #expect(page.components(separatedBy: "</head>").count == 2)
        let script = "<script src=\"/reader/host.js\" defer></script>\n"
        #expect(ReaderPage.build(model: model, head: script)
                == page.replacingOccurrences(of: "</head>", with: script + "</head>"))
    }

    @Test("A host's serializer writes the page's body, so its figures name the host's addresses")
    func aHostsSerializerWritesTheBody() async throws {
        let model = try await model()
        let page = ReaderPage.build(model: model, serializer: .reader(figureURL: { image in
            URL(string: "/api/v1/volumes/\(image.volumeId ?? "")/figures/\(image.fileName ?? "")")
        }))
        #expect(page.contains("<img class=\"figure-image\" src=\"/api/v1/volumes/frus1946v01/figures/figure_1162.png\" "))
        #expect(!page.contains("frusexplorer://figure/"))
        // With the app's own address for each image, a host's serializer writes the reader's bytes.
        #expect(FRUSRenderNodeHTMLSerializer.reader(figureURL: FRUSURLScheme.figureURL(for:)).serialize(model)
                == FRUSRenderNodeHTMLSerializer.reader.serialize(model))
        // An image the host cannot name prints the placeholder alone.
        let none = FRUSRenderNodeHTMLSerializer.reader(figureURL: { _ in nil }).serialize(model)
        #expect(!none.contains("<img") && none.contains("<span class=\"figure-missing\">[Figure]</span>"))
    }

    // MARK: - WCAG 2.2 AA

    /// The custom properties the stylesheet draws text in. The reader's text is small text for WCAG
    /// at every size, so each needs 4.5:1. The last is the colour of text inside a highlight (#1602).
    static let textColourVariables: Set<String> = ["color-primary", "color-secondary", "color-footnote-text",
                                                   "color-accent", "color-pers-name", "color-highlight-text"]

    /// A colour as `cssVariables` writes one, `rgb(r,g,b)` or `rgba(r,g,b,a)`: sRGB channels from 0
    /// to 255 and an alpha from 0 to 1.
    struct CSSColour {
        /// The red, green and blue channels, 0–255; a composite may carry fractions.
        var red, green, blue: Double
        /// The alpha, 1 for an opaque colour.
        var alpha: Double

        /// Parses `rgb(…)` or `rgba(…)`, or returns nil for anything else.
        init?(_ css: String) {
            let text = css.trimmingCharacters(in: .whitespaces)
            guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
            let values = text[text.index(after: open)..<text.index(before: text.endIndex)]
                .split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            switch (text[..<open], values.count) {
            case ("rgb", 3): self.init(red: values[0], green: values[1], blue: values[2], alpha: 1)
            case ("rgba", 4): self.init(red: values[0], green: values[1], blue: values[2], alpha: values[3])
            default: return nil
            }
        }

        /// A colour from its channels and alpha.
        init(red: Double, green: Double, blue: Double, alpha: Double) {
            (self.red, self.green, self.blue, self.alpha) = (red, green, blue, alpha)
        }

        /// An opaque colour from `#rgb` or `#rrggbb`, as the collection export's own stylesheet
        /// writes one, or nil for anything else. Apart from `init(_:)`, which must go on refusing
        /// a hex colour: `cssVariables` writes none.
        static func hex(_ css: String) -> CSSColour? {
            var digits = Substring(css.trimmingCharacters(in: .whitespaces))
            guard digits.hasPrefix("#") else { return nil }
            digits = digits.dropFirst()
            if digits.count == 3 { digits = Substring(digits.map { "\($0)\($0)" }.joined()) }
            guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
            return CSSColour(red: Double((value >> 16) & 0xFF), green: Double((value >> 8) & 0xFF),
                             blue: Double(value & 0xFF), alpha: 1)
        }

        /// The opaque colour this one makes laid over an opaque `ground` (source-over), as a
        /// browser draws text, or a tint, over what is beneath it.
        func over(_ ground: CSSColour) -> CSSColour {
            func mix(_ top: Double, _ bottom: Double) -> Double { top * alpha + bottom * (1 - alpha) }
            return CSSColour(red: mix(red, ground.red), green: mix(green, ground.green),
                             blue: mix(blue, ground.blue), alpha: 1)
        }

        /// WCAG 2.2's relative luminance of an opaque colour: each sRGB channel linearised, then
        /// weighted 0.2126, 0.7152 and 0.0722.
        var relativeLuminance: Double {
            func linear(_ channel: Double) -> Double {
                let c = channel / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        /// WCAG 2.2's contrast ratio between two opaque colours, (L1 + 0.05) / (L2 + 0.05) with L1
        /// the lighter's luminance: from 1 to 21.
        func contrast(with other: CSSColour) -> Double {
            let (a, b) = (relativeLuminance, other.relativeLuminance)
            return (max(a, b) + 0.05) / (min(a, b) + 0.05)
        }
    }

    /// The custom properties `cssVariables(appearance:)` writes, by name without the leading `--`.
    static func variables(_ appearance: ReaderAppearance) -> [String: String] {
        var variables: [String: String] = [:]
        for line in ReaderPage.cssVariables(appearance: appearance).split(separator: "\n") {
            let declaration = line.trimmingCharacters(in: .whitespaces)
            guard declaration.hasPrefix("--"), declaration.hasSuffix(";"),
                  let colon = declaration.firstIndex(of: ":") else { continue }
            let name = declaration[declaration.index(declaration.startIndex, offsetBy: 2)..<colon]
            variables[String(name)] = declaration[declaration.index(after: colon)...].dropLast()
                .trimmingCharacters(in: .whitespaces)
        }
        return variables
    }

    /// The rules of `css` in order, each its selector list, its declarations (property to value) and
    /// the at-rule it sits in, if any (`@media print`, `@keyframes …`). Comments are dropped, and a
    /// rule inside an at-rule is read with its own selector.
    static func rules(in css: String) -> [(selectors: [String], declarations: [String: String], atRule: String?)] {
        var text = css
        while let open = text.range(of: "/*"),
              let close = text.range(of: "*/", range: open.upperBound..<text.endIndex) {
            text.removeSubrange(open.lowerBound..<close.upperBound)
        }
        var found: [(selectors: [String], declarations: [String: String], atRule: String?)] = []
        var enclosing: [String] = []
        var prelude = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            index = text.index(after: index)
            switch character {
            case "{":
                let head = prelude.trimmingCharacters(in: .whitespacesAndNewlines)
                prelude = ""
                if head.hasPrefix("@") { enclosing.append(head); continue }
                // A style rule: its declarations run to the next `}`.
                let close = text[index...].firstIndex(of: "}") ?? text.endIndex
                var declarations: [String: String] = [:]
                for declaration in text[index..<close].split(separator: ";") {
                    let parts = declaration.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2 else { continue }
                    declarations[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)] =
                        parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                found.append((head.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                              declarations, enclosing.last))
                index = close < text.endIndex ? text.index(after: close) : close
            case "}":
                if !enclosing.isEmpty { enclosing.removeLast() }
                prelude = ""
            default:
                prelude.append(character)
            }
        }
        return found
    }

    /// Whether `atRule` is `@media print`: a block whose rules apply on paper and not on screen.
    static func isPrintOnly(_ atRule: String?) -> Bool {
        guard let atRule else { return false }
        return atRule.split(whereSeparator: \.isWhitespace).joined(separator: " ") == "@media print"
    }

    /// The declarations of every rule in `css` whose selector list names `selector` exactly, a later
    /// rule's winning, as in the cascade: on screen, where a rule inside `@media print` does not
    /// apply, or `onPaper`, where it does.
    static func declarations(of selector: String, in css: String, onPaper: Bool = false) -> [String: String] {
        rules(in: css).filter { $0.selectors.contains(selector) && (onPaper || !isPrintOnly($0.atRule)) }
            .reduce(into: [:]) { merged, rule in merged.merge(rule.declarations) { _, later in later } }
    }

    @Test("The contrast arithmetic gives WCAG's own figures, and fails the palette this one replaced")
    func theContrastArithmeticIsWCAGs() throws {
        let white = try #require(CSSColour("rgb(255,255,255)"))
        let black = try #require(CSSColour("rgb(0,0,0)"))
        #expect(abs(black.contrast(with: white) - 21) < 1e-9)
        #expect(abs(white.contrast(with: white) - 1) < 1e-9)
        // #767676 is the lightest grey to reach 4.5:1 on white (4.54); #777777 does not (4.48).
        let passing = try #require(CSSColour("rgb(118,118,118)"))
        let failing = try #require(CSSColour("rgb(119,119,119)"))
        #expect(passing.contrast(with: white) >= 4.5 && failing.contrast(with: white) < 4.5)
        // An alpha colour is measured where it lands: 50% black on white is rgb(127.5,127.5,127.5).
        let halfBlack = try #require(CSSColour("rgba(0,0,0,0.50)")).over(white)
        #expect(abs(halfBlack.red - 127.5) < 1e-9 && halfBlack.alpha == 1)
        // The light palette before this change: its accent, its person-name teal and its secondary.
        for old in ["rgb(0,122,255)", "rgb(0,150,136)", "rgba(0,0,0,0.50)"] {
            let ratio = try #require(CSSColour(old)).over(white).contrast(with: white)
            #expect(ratio < 4.5, "\(old) is \(ratio):1 on white")
        }
        #expect(CSSColour("#0066cc") == nil && CSSColour("rgb(0,102)") == nil)
    }

    @Test("Every text colour is at least 4.5:1 against the page and the editorial note's tint, in both palettes")
    func everyTextColourMeetsAA() throws {
        for appearance in ReaderAppearance.allCases {
            let variables = Self.variables(appearance)
            let page = try #require(CSSColour(variables["color-background"] ?? ""), "\(appearance): no background")
            #expect(page.alpha == 1, "\(appearance): the page's background is not opaque")
            let note = try #require(CSSColour(variables["color-editorial-bg"] ?? ""), "\(appearance): no editorial tint")
                .over(page)
            for name in Self.textColourVariables.sorted() {
                let colour = try #require(CSSColour(variables[name] ?? ""), "\(appearance): --\(name) is not a colour")
                let onPage = colour.over(page).contrast(with: page)
                let onNote = colour.over(note).contrast(with: note)
                #expect(onPage >= 4.5, "\(appearance): --\(name) is \(String(format: "%.2f", onPage)):1 on the page")
                #expect(onNote >= 4.5, "\(appearance): --\(name) is \(String(format: "%.2f", onNote)):1 in an editorial note")
            }
        }
        // The stylesheet draws text in these variables and in nothing else, so a rule that drew text
        // in the table border's grey, or in a literal colour, would fail here.
        let colours = Self.rules(in: ReaderPage.documentCSS).compactMap { $0.declarations["color"] }
        let drawn = Set(colours.compactMap { colour -> String? in
            guard colour.hasPrefix("var(--") else { return nil }
            return String(colour.dropFirst("var(--".count).prefix { $0 != "," && $0 != ")" })
        })
        #expect(colours.allSatisfy { $0.hasPrefix("var(--") }, "a rule draws text in a literal colour: \(colours)")
        #expect(drawn == Self.textColourVariables, "the stylesheet draws text in \(drawn.sorted())")
    }

    // MARK: - #1602: the highlight tints and the footnote wash

    /// The page and the editorial note's tint over it, the two grounds text is drawn on.
    private static func grounds(_ appearance: ReaderAppearance) throws -> (page: CSSColour, note: CSSColour) {
        let variables = variables(appearance)
        let page = try #require(CSSColour(variables["color-background"] ?? ""), "\(appearance): no background")
        let note = try #require(CSSColour(variables["color-editorial-bg"] ?? ""), "\(appearance): no editorial tint")
        return (page, note.over(page))
    }

    /// The reader's highlight rules, `::highlight(frus-…)`: each one's name and declarations.
    private static var highlightRules: [(name: String, declarations: [String: String])] {
        rules(in: ReaderPage.documentCSS).compactMap { rule in
            guard rule.selectors.count == 1, let selector = rule.selectors.first,
                  selector.hasPrefix("::highlight("), selector.hasSuffix(")") else { return nil }
            return (String(selector.dropFirst("::highlight(".count).dropLast()), rule.declarations)
        }
    }

    @Test("Text inside a highlight is drawn in the highlight text colour, at least 4.5:1 over every tint, on the page and in an editorial note")
    func textInsideAHighlightMeetsAA() throws {
        let rules = Self.highlightRules
        #expect(rules.map(\.name) == ["frus-yellow", "frus-green", "frus-blue", "frus-pink", "frus-stale"])
        var measured = 0
        var lowest = Double.infinity
        for appearance in ReaderAppearance.allCases {
            let variables = Self.variables(appearance)
            let grounds = try Self.grounds(appearance)
            let text = try #require(CSSColour(variables["color-highlight-text"] ?? ""),
                                    "\(appearance): --color-highlight-text is not a colour")
            let accent = try #require(CSSColour(variables["color-accent"] ?? ""))
            var linkUnder = 0
            for rule in rules {
                // The rule draws its text in the variable, which is what makes the tint's own
                // contrast the only one that matters: no link, footnote or secondary colour
                // reaches a highlight.
                #expect(rule.declarations["color"] == "var(--color-highlight-text)",
                        "::highlight(\(rule.name)) draws text in \(rule.declarations["color"] ?? "its own colour")")
                let tint = try #require(CSSColour(rule.declarations["background-color"] ?? ""),
                                        "::highlight(\(rule.name)) has no tint")
                for (name, ground) in [("the page", grounds.page), ("an editorial note", grounds.note)] {
                    let under = tint.over(ground)
                    let ratio = text.over(under).contrast(with: under)
                    #expect(ratio >= 4.5,
                            "\(appearance): text in a \(rule.name) highlight on \(name) is \(String(format: "%.2f", ratio)):1")
                    lowest = min(lowest, ratio)
                    measured += 1
                }
                // What #1602 reported: over the tint, a link in its own colour.
                let onPage = tint.over(grounds.page)
                if accent.over(onPage).contrast(with: onPage) < 4.5 { linkUnder += 1 }
            }
            // Four of the five tints in each palette put a link's own colour under 4.5:1 (all but
            // yellow in light, where it is 4.77; all five in dark). If this stops being true the
            // tints have changed, and the rule above may no longer be needed.
            #expect(linkUnder >= 4, "\(appearance): a link's own colour is under 4.5:1 on \(linkUnder) tints")
        }
        #expect(measured == 20, "two palettes, five tints, two grounds")
        // The lowest is white on a yellow highlight inside an editorial note, dark palette: 5.08.
        #expect(abs(lowest - 5.08) < 0.01, "the lowest ratio is \(String(format: "%.2f", lowest))")
    }

    @Test("Every text colour is at least 4.5:1 on the wash behind a footnote a cross-reference arrived at")
    func everyTextColourMeetsAAOnTheArrivalWash() throws {
        for appearance in ReaderAppearance.allCases {
            let variables = Self.variables(appearance)
            let page = try Self.grounds(appearance).page
            let wash = try #require(CSSColour(variables["color-accent-wash"] ?? ""),
                                    "\(appearance): --color-accent-wash is not defined").over(page)
            for name in Self.textColourVariables.sorted() {
                let colour = try #require(CSSColour(variables[name] ?? ""))
                let ratio = colour.over(wash).contrast(with: wash)
                #expect(ratio >= 4.5, "\(appearance): --\(name) is \(String(format: "%.2f", ratio)):1 on the footnote wash")
            }
            // The wash is still a wash: it differs from the page it is laid on.
            #expect(wash.contrast(with: page) >= 1.1, "\(appearance): the wash is the page's own colour")
            // The fallback both palettes drew until #1602, since the variable was never defined.
            let old = try #require(CSSColour("rgba(120, 170, 255, 0.35)")).over(page)
            let accent = try #require(CSSColour(variables["color-accent"] ?? ""))
            #expect(accent.over(old).contrast(with: old) < 4.5)
        }
        // The stylesheet draws the wash through the variable in all four places (the footnote's
        // three since #1602, and the index entry's Reduce Motion rule since Lane 2 of the editors'
        // annotations follow-ups), and its fallback is the light palette's value, so a host without
        // the variable gets a wash that passes on a white page.
        let css = ReaderPage.documentCSS
        let light = try #require(Self.variables(.light)["color-accent-wash"])
        let washes = Self.rules(in: css).compactMap { $0.declarations["background-color"] }
            .filter { $0.contains("--color-accent-wash") }
        #expect(washes.count == 4, "the wash is drawn in \(washes.count) places")
        for wash in washes {
            let fallback = wash.dropFirst("var(--color-accent-wash,".count).dropLast()
            #expect(CSSColour(String(fallback)).map { [$0.red, $0.green, $0.blue, $0.alpha] }
                    == CSSColour(light).map { [$0.red, $0.green, $0.blue, $0.alpha] },
                    "the wash's fallback is \(fallback), not the light palette's \(light)")
        }
    }

    @Test("A link inside an export's highlight is drawn in the highlight text colour, whichever element is outside")
    func exportHighlightsDrawLinksInTheHighlightTextColour() throws {
        let rules = Self.rules(in: FRUSRenderNodeHTMLSerializer.highlightCSS)
        let marks = ["mark.hl-yellow", "mark.hl-green", "mark.hl-blue", "mark.hl-pink"]
        let links = try #require(rules.first { $0.selectors.contains("mark.hl-yellow a") })
        // Both nestings the injector writes: the link inside the mark, and the mark inside the link.
        #expect(Set(links.selectors) == Set(marks.map { "\($0) a" } + marks.map { "a \($0)" }))
        let colour = try #require(links.declarations["color"])
        #expect(colour.hasPrefix("var(--color-highlight-text,"))
        let fallback = try #require(CSSColour(String(colour.dropFirst("var(--color-highlight-text,".count).dropLast())))
        // An export is drawn in the light palette, on white.
        let white = try #require(CSSColour("rgb(255,255,255)"))
        let variables = Self.variables(.light)
        let text = try #require(CSSColour(variables["color-highlight-text"] ?? ""))
        #expect([fallback.red, fallback.green, fallback.blue, fallback.alpha] == [text.red, text.green, text.blue, text.alpha])
        var linkUnder = 0
        for mark in marks {
            let tint = try #require(CSSColour(Self.declarations(of: mark, in: FRUSRenderNodeHTMLSerializer.highlightCSS)["background"] ?? ""),
                                    "\(mark) has no tint").over(white)
            #expect(text.over(tint).contrast(with: tint) >= 4.5)
            for link in ["color-accent", "color-pers-name"] {
                let own = try #require(CSSColour(variables[link] ?? ""))
                if own.over(tint).contrast(with: tint) < 4.5 { linkUnder += 1 }
            }
        }
        // Green, blue and pink put both link colours under 4.5:1; yellow neither.
        #expect(linkUnder == 6, "\(linkUnder) link-and-tint pairs are under 4.5:1 in their own colour")
    }

    @Test("Person and cross-reference links are underlined, so colour is not all that marks them, and a gloss keeps its dotted rule")
    func linksAreMarkedByMoreThanColour() {
        let css = ReaderPage.documentCSS
        for link in ["a.pers-name", "a.cross-ref"] {
            let rule = Self.declarations(of: link, in: css)
            #expect(rule["text-decoration"] == "underline" || rule["text-decoration-line"] == "underline",
                    "\(link) is not underlined: \(rule)")
            #expect(rule["text-decoration-thickness"] == "from-font" && rule["text-underline-offset"] != nil,
                    "\(link)'s underline is not the quiet one: \(rule)")
            // Hover stays distinct: the underline thickens.
            let hover = Self.declarations(of: "\(link):hover", in: css)
            #expect(hover["text-decoration-thickness"].map { $0 != "from-font" } == true,
                    "\(link):hover does not change the underline: \(hover)")
        }
        let gloss = Self.declarations(of: "a.gloss", in: css)
        #expect(gloss["border-bottom"]?.contains("dotted") == true, "a.gloss lost its dotted rule: \(gloss)")
        #expect(Self.declarations(of: "a.gloss:hover", in: css)["border-bottom-style"] == "solid")
        let broken = Self.declarations(of: "a.cross-ref-broken", in: css)
        #expect(broken["border-bottom"]?.contains("dotted") == true, "a.cross-ref-broken lost its dotted rule: \(broken)")
    }

    @Test("On paper the person and cross-reference links print without an underline and keep their colour, and on screen they keep the underline")
    func linksPrintPlain() {
        let css = ReaderPage.documentCSS
        let rules = Self.rules(in: css)
        // One print block, holding the one rule for the two links.
        let printRules = rules.filter { Self.isPrintOnly($0.atRule) }
        #expect(printRules.map(\.selectors) == [["a.pers-name", "a.cross-ref"]],
                "the print block holds \(printRules.map(\.selectors)), not the one rule for the two links")
        for link in ["a.pers-name", "a.cross-ref"] {
            let screen = Self.declarations(of: link, in: css)
            let paper = Self.declarations(of: link, in: css, onPaper: true)
            #expect(screen["text-decoration"] == "underline", "\(link) lost its underline on screen: \(screen)")
            #expect(paper["text-decoration"] == "none", "\(link) prints underlined: \(paper)")
            #expect(paper["color"] != nil && paper["color"] == screen["color"], "\(link) changes colour on paper: \(paper)")
        }
        // A gloss's dotted rule and a broken reference's are not underlines, and print as on screen.
        for other in ["a.gloss", "a.cross-ref-broken"] {
            #expect(Self.declarations(of: other, in: css, onPaper: true) == Self.declarations(of: other, in: css),
                    "\(other) prints differently from the screen")
        }
        // The reading attributes a rule to the at-rule it sits in, and leaves the block at its end:
        // without that, a print rule would be read as the screen's, or a later rule as paper's.
        let arrived = rules.first { $0.selectors == [".fn-list-item.fn-arrived"] && $0.atRule != nil }
        #expect(arrived?.atRule?.hasPrefix("@media (prefers-reduced-motion") == true,
                "the reduced-motion rule was not read inside its block: \(String(describing: arrived))")
        #expect(rules.contains { $0.selectors == [".fn-list-item"] && $0.atRule == nil },
                "the rule after the reduced-motion block was not read as a top-level rule")
    }

    // MARK: - WCAG 2.2's 2.5.8: the links of a list item of links alone

    /// The selectors of the rule that draws the links of a list item of links alone as boxes at least
    /// 24 px square: `li.links-only`, which the serializer writes for an item with no text beside its
    /// links (`FRUSRenderNodeHTMLSerializer.holdsLinksAlone(_:)`), as an index entry whose page numbers
    /// the TEI prints with no comma between them (FRUS Explorer Light's axe check, 2026-11-11). A link
    /// in formatting inside the item is one level down. Since 2026-11-12 the rule takes the item's
    /// gloss links too, and the links of the two lists below a document that names its people and
    /// terms on `@ana` (`.named-list`), one to a line at the footnotes' size.
    static let linksAloneSelectors = [
        ".frus-list > li.links-only > a.cross-ref", ".frus-list > li.links-only > a.pers-name",
        ".frus-list > li.links-only > a.gloss",
        ".frus-list > li.links-only > * > a.cross-ref", ".frus-list > li.links-only > * > a.pers-name",
        ".frus-list > li.links-only > * > a.gloss",
        ".named-list > li > a.pers-name", ".named-list > li > a.gloss",
    ]

    /// The glosses among `linksAloneSelectors`, whose dotted rule is drawn as an underline in a box.
    static let boxedGlossSelectors = [
        ".frus-list > li.links-only > a.gloss", ".frus-list > li.links-only > * > a.gloss",
        ".named-list > li > a.gloss",
    ]

    /// The footnote markers beside the links of a list item of links alone.
    static let boxedMarkerSelectors = [
        ".frus-list > li.links-only > button.fn-marker", ".frus-list > li.links-only > * > button.fn-marker",
    ]

    /// Such an item holds no text but its links, so the inline exception of WCAG 2.2's 2.5.8 (Target
    /// Size (Minimum)) does not reach them: each must be a target 24 px square, or stand 24 px clear
    /// of the next. Drawn inline they were neither, as axe found on frus1961-63v06's index. On paper
    /// there is nothing to follow, so the rules are the screen's alone, and their boxes sit at the top
    /// of their line, where a list's bullet stays beside a long title's first line. A gloss's dotted
    /// rule is a border, which in a box would sit at its foot and run its width, so a boxed gloss
    /// draws it as a dotted underline, solid on hover as the border is; and a footnote marker, whose
    /// `line-height: 0` gives its box no height, so that axe sees no target, is a box too, its number
    /// at the top, where a raised number sits. What the boxes measure in WebKit is
    /// `LinksAloneTargetRenderTests`' (Xcode's alone).
    @Test("On screen the links of a list item of links alone, glosses and footnote markers among them, and of the named lists are boxes at least 24 px square, and no other rule takes a link out of its line")
    func theLinksOfAnItemOfLinksAloneAre24PxTargets() throws {
        let rules = Self.rules(in: ReaderPage.documentCSS)
        func rule(_ selectors: [String]) throws -> (selectors: [String], declarations: [String: String], atRule: String?) {
            let matching = rules.filter { $0.selectors == selectors }
            #expect(matching.count == 1, "\(matching.count) rules for \(selectors)")
            let rule = try #require(matching.first)
            #expect(rule.atRule == "@media screen", "\(selectors) sits inside \(rule.atRule ?? "no at-rule")")
            return rule
        }
        #expect(try rule(Self.linksAloneSelectors).declarations
                == ["display": "inline-block", "min-width": "24px", "min-height": "24px", "vertical-align": "top"])
        #expect(try rule(Self.boxedGlossSelectors).declarations
                == ["border-bottom": "none", "text-decoration": "underline dotted", "text-decoration-thickness": "1px",
                    "text-underline-offset": "0.2em"])
        #expect(try rule(Self.boxedGlossSelectors.map { $0 + ":hover" }).declarations == ["text-decoration-style": "solid"])
        #expect(try rule(Self.boxedMarkerSelectors).declarations
                == ["display": "inline-flex", "align-items": "flex-start", "min-width": "24px", "min-height": "24px",
                    "line-height": "1", "vertical-align": "top"])
        // No colour of their own: the links keep their rules', which the tests above read, and the
        // gloss its dotted rule's colour, which is its text's. And no other rule sets how a link is
        // displayed.
        for selectors in [Self.linksAloneSelectors, Self.boxedGlossSelectors, Self.boxedMarkerSelectors] {
            #expect(try rule(selectors).declarations.keys.allSatisfy { !$0.contains("color") }, "\(selectors)")
        }
        let others = rules.filter { other in
            ![Self.linksAloneSelectors, Self.boxedMarkerSelectors].contains(other.selectors)
                && other.declarations["display"] != nil
                && other.selectors.contains { $0.contains("a.cross-ref") || $0.contains("a.pers-name") || $0.contains("a.gloss") }
        }
        #expect(others.isEmpty, "other rules set a link's display: \(others.map(\.selectors))")
    }

    #if !SWIFT_PACKAGE // HTMLTemplate and FRUSTheme are the app's
    @Test("The app's HTMLTemplate and FRUSTheme forward to the kit's page and variables")
    @MainActor
    func theAppsNamesForwardToTheKit() async throws {
        let model = try await model()
        for (scheme, appearance) in [(ColorScheme.light, ReaderAppearance.light), (.dark, .dark)] {
            for size in TextSizePreference.allCases {
                #expect(HTMLTemplate.build(model: model, colorScheme: scheme, textSize: size)
                        == ReaderPage.build(model: model, appearance: appearance, textSize: size))
                #expect(FRUSTheme.cssVariables(colorScheme: scheme, textSize: size)
                        == ReaderPage.cssVariables(appearance: appearance, textSize: size))
            }
        }
        #expect(HTMLTemplate.documentCSS == ReaderPage.documentCSS)
        #expect(HTMLTemplate.figureCSS == ReaderPage.figureCSS)
    }
    #endif
}

#if !SWIFT_PACKAGE // CollectionItemHTMLRenderer is the app's
// MARK: - CollectionExportContrastTests

/// The collection HTML export's own stylesheet layer, measured against WCAG 2.2 AA (#1602).
///
/// #1578 brought the reader's page to 4.5:1 and named this layer as left under it. The layer draws
/// its text in literal colours on literal backgrounds, so no test read them: `ReaderPageTests`
/// reads the kit's variables. Five rules were under 4.5:1, the three #1602 listed and two it did
/// not: the contents panel's page numbers, and the AI-attribution caption on its second ground.
///
/// Each text colour is listed with the element whose background it is drawn on, and a rule that
/// draws text and is not listed fails, so a new rule is measured or the suite says so.
///
/// Version history:
///   1.0 — Session 2026-10-09: #1602 — initial implementation
@Suite("The collection HTML export's own colours meet 4.5:1 (#1602)")
struct CollectionExportContrastTests {

    /// Each rule that draws text in a colour of its own, and the selector of every element it is
    /// drawn inside that sets a background. `body` is the page, white.
    static let grounds: [String: [String]] = [
        ".collection-note": ["body"], "nav h2": ["nav"], "nav a": ["nav"], ".toc-page": ["nav"],
        ".doc-url": ["body"],
        "aside.research-note strong": ["aside.research-note"], "aside.research-note p": ["aside.research-note"],
        ".summary-label": [".summary-block"], ".source-note": ["body"],
        ".collection-subtitle": ["body"], ".collection-author": ["body"], ".collection-project": ["body"],
        ".collection-project-question": ["body"],
        "footer.colophon": ["body"], "section.method-appendix": ["body"], "section.method-appendix h2": ["body"],
        ".headnote-label": [".headnote"], ".headnote em": [".headnote"], ".headnote-missing": [".headnote"],
        ".excerpt-block blockquote p": ["figure.excerpt-block"], "figcaption.excerpt-source": ["figure.excerpt-block"],
        ".see-also": ["body"], ".see-also strong": ["body"],
        // The caption closes a summary block and a filled headnote.
        ".ai-attribution": [".summary-block", ".headnote"],
        "ul.generated-rows a": ["body"], ".generated-secondary": ["body"],
        ".citation-card-citation": [".citation-card"], ".citation-card-note": [".citation-card"],
        ".summary-placeholder-note": [".summary-placeholder"],
    ]

    @Test("Every text colour of the export's own layer is at least 4.5:1 on each background it is drawn on")
    func everyOwnColourMeetsAA() throws {
        let css = CollectionItemHTMLRenderer.ownLayersCSS
        let rules = ReaderPageTests.rules(in: css).filter { !ReaderPageTests.isPrintOnly($0.atRule) }
        var measured = 0
        var seen: Set<String> = []
        for rule in rules {
            guard let value = rule.declarations["color"], value != "inherit" else { continue }
            let colour = try #require(ReaderPageTests.CSSColour.hex(value), "\(rule.selectors): \(value) is not a hex colour")
            for selector in rule.selectors {
                seen.insert(selector)
                let grounds = try #require(Self.grounds[selector],
                                           "\(selector) draws text in \(value) and is not listed with its background")
                for ground in grounds {
                    let background = try #require(
                        ReaderPageTests.CSSColour.hex(ReaderPageTests.declarations(of: ground, in: css)["background"] ?? ""),
                        "\(ground) sets no background")
                    let ratio = colour.contrast(with: background)
                    #expect(ratio >= 4.5, "\(selector) (\(value)) is \(String(format: "%.2f", ratio)):1 on \(ground)")
                    measured += 1
                }
            }
        }
        // Counted: a parser that read no rule, or a layer left out of `ownLayersCSS`, would pass
        // by measuring nothing. 29 rules draw text; one is drawn on two grounds.
        #expect(seen == Set(Self.grounds.keys), "listed and not found: \(Set(Self.grounds.keys).subtracting(seen).sorted())")
        #expect(measured == 30)
    }

    @Test("The five colours #1602 replaced were under 4.5:1 where they were drawn")
    func theReplacedColoursFailed() throws {
        let hex = ReaderPageTests.CSSColour.hex
        let pairs: [(String, String, Double)] = [
            ("#777", "#fff", 4.48), ("#888", "#f0f4ff", 3.22), ("#888", "#f7f7f5", 3.30), ("#a06a00", "#fdf8ee", 4.35),
        ]
        for (text, ground, expected) in pairs {
            let ratio = try #require(hex(text)).contrast(with: try #require(hex(ground)))
            #expect(abs(ratio - expected) < 0.005, "\(text) on \(ground) is \(ratio)")
        }
        #expect(hex("#0066cc").map { [$0.red, $0.green, $0.blue] } == [0, 102, 204])
        #expect(hex("#fff").map { [$0.red, $0.green, $0.blue] } == [255, 255, 255])
        #expect(hex("rgb(0,0,0)") == nil && hex("#12") == nil && hex("#gggggg") == nil)
    }
}
#endif

#if !SWIFT_PACKAGE // HTMLTemplate and the WebKit harness are the app's
// MARK: - LinksAloneTargetRenderTests

/// Measures in the app's own web view what `ReaderPageTests.theLinksOfAnItemOfLinksAloneAre24PxTargets`
/// can only read the rule for: the boxes of a list's links, drawn from the serializer's markup
/// through the reader's real stylesheet (FRUS Explorer Light's axe check, 2026-11-11).
///
/// WCAG 2.2's 2.5.8 (Target Size (Minimum)) asks a target to be 24 CSS px square, or to stand 24 px
/// clear of the next, unless it sits in a sentence or among text that sets its line. An index entry
/// such as "Davis, Richard H., 18n 24n 131n" (frus1961-63v06, whose TEI prints no comma between the
/// pages) holds no text but its links. Drawn inline they were 16 px tall at Medium and a space apart,
/// and axe found seven such links on that index's page in Chromium, where a link holding a note's
/// italic n is two boxes, the n's 8 px wide. Here, at every text size, in the reader's default
/// column and in one narrow enough to wrap an entry: each link of an item of links alone is a box at
/// least 24 px square; each link of an item with text beside its links, a comma included, is drawn
/// inline as before; no two links' boxes overlap; and a link longer than its line wraps inside its
/// box, with what follows it on the next line. Which entries are which is the fixture's, written out
/// below, not the serializer's reading of them.
///
/// Since 2026-11-12 the boxes take an item's glosses, whose dotted rule is then an underline, and
/// the footnote markers beside its links, whose number sits at the top of the box, and the links of
/// the two lists below a document that names its people and terms on `@ana`.
///
/// Version history:
///   1.0 — 2026-11-11 (FRUS Explorer Light, S21b's follow-up): initial implementation
///   1.1 — 2026-11-12 (FRUS Explorer Light, S21b's follow-up): glosses and footnote markers in an item
///          of links alone, a gloss beside text, and the named lists
@Suite("Reader lists — the links of an item of links alone are boxes at least 24 px square (WCAG 2.2, 2.5.8)")
@MainActor
struct LinksAloneTargetRenderTests {

    /// One link's boxes as the page draws them, in viewport coordinates; a footnote marker's too.
    private struct MeasuredLink: Decodable {
        /// The link's text, so a failure names what it measured.
        let text: String
        /// Which of the list's items holds it, from 0.
        let entry: Int
        /// The element and its first class: `a.cross-ref`, `a.pers-name`, `a.gloss` or `button.fn-marker`.
        let kind: String
        /// Computed `display`.
        let display: String
        /// The border box's width.
        let width: Double
        /// The border box's height.
        let height: Double
        /// The border box's top edge.
        let top: Double
        /// `getClientRects()`, each `[left, top, width, height]`.
        let rects: [[Double]]
        /// Computed `text-decoration-line` and `text-decoration-style`, and `border-bottom-style`.
        let decorationLine: String
        let decorationStyle: String
        let borderBottomStyle: String
        /// The top of the element's text, a range over its contents: where a marker draws its number.
        let textTop: Double
    }

    /// Twelve entries, in two lists. Links and spaces alone, whose links are boxes: frus1961-63v06's
    /// "Davis, Richard H.," with six pages, each a note's (0); two one-digit pages after a name (1); a
    /// contents line with its title in bold, as frus1961-63v10-12mSupp prints its own (2); a contents
    /// title too long for its line (3); a name and a page with no space between, as frus1955-57v12's
    /// "Armour, Norman, Sr.,365" (4); a name alone, as a list of participants prints one (5); a link
    /// alone in a paragraph (6); and, in a list of its own, a name beside its printed label, which
    /// floats in the margin (11). Text beside the links, which stay inline: a contents title that
    /// names a person, as frus1961-63v06's "List of Kennedy Administration Volumes", whose nested
    /// link the browser splits into two links and loose text (7); frus1961-63v06's "Adzhubei,
    /// Aleksei I.," whose pages run with and without commas (8); "Brezhnev, Leonid I., 2, 3" (9);
    /// and an entry whose name is text (10). In a third list: a gloss alone, as a list of offices
    /// prints one (12, frus1969-76v33), a gloss alone in italics (13), a name and its office's gloss
    /// (14, frus1952-54v13p1's "Bonsal PSA"), a signature with its footnote (15, frus1961-63v06's "L.
    /// Brezhnev" in d18), whose links and marker are boxes; and a gloss beside a word, which stays
    /// inline with its dotted border (16).
    static let index = """
    <div type="document" subtype="historical-document" n="1" xml:id="d1">
      <list>
        <item><persName corresp="#p_DRH2">Davis, Richard H.,</persName>
          <ref target="#pg_18">18<hi rend="italic">n</hi></ref>
          <ref target="#pg_24">24<hi rend="italic">n</hi></ref>
          <ref target="#pg_131">131<hi rend="italic">n</hi></ref>
          <ref target="#pg_142">142<hi rend="italic">n</hi></ref>
          <ref target="#pg_268">268<hi rend="italic">n</hi></ref>
          <ref target="#pg_288">288<hi rend="italic">n</hi></ref></item>
        <item><persName corresp="#p_FPJ1">Farley, Philip J.,</persName> <ref target="#pg_7">7</ref> <ref target="#pg_9">9</ref></item>
        <item><hi rend="strong"><ref target="#preface">Preface</ref></hi> <ref target="#pg_III">III</ref></item>
        <item><ref target="#ch1">The Foreign Ministers Meeting at Geneva and the Question of Berlin, May Through August 1959</ref> <ref target="#pg_1">1</ref></item>
        <item><persName corresp="#p_ANS1">Armour, Norman, Sr.,</persName><ref target="#pg_365">365</ref></item>
        <item><persName corresp="#p_PWJ1">William Porter</persName></item>
        <item><p><ref target="#d5">Memorandum of Conversation</ref></p></item>
        <item><ref target="#subseriesvols"><hi rend="strong">List of <persName corresp="#p_KJF1">Kennedy</persName> Administration Volumes</hi></ref> <ref target="#pg_XXV">XXV</ref></item>
        <item><persName corresp="#p_AAI1">Adzhubei, Aleksei I.,</persName>
          <ref target="#pg_26">26</ref>, <ref target="#pg_44">44<hi rend="italic">n</hi></ref>
          <ref target="#pg_65">65</ref></item>
        <item><persName corresp="#p_BLI1">Brezhnev, Leonid I.,</persName> <ref target="#pg_2">2</ref>, <ref target="#pg_3">3</ref></item>
        <item>Dean, Arthur H., <ref target="#pg_236">236</ref>, <ref target="#pg_238">238</ref>–<ref target="#pg_239">239</ref></item>
      </list>
      <list>
        <label>(c)</label>
        <item><persName corresp="#p_TPH1">Phil Talbot</persName></item>
      </list>
      <list>
        <item><gloss target="#t_SALT_1">SALT</gloss></item>
        <item><hi rend="italic"><gloss target="#t_S_1">S</gloss></hi></item>
        <item><persName corresp="#p_BPW1">Bonsal</persName> <gloss target="#t_PSA1">PSA</gloss></item>
        <item><persName corresp="#p_BLI1"><hi rend="strong">L. Brezhnev</hi></persName><note n="1" xml:id="d1fn1">Printed from a copy that bears these typed signatures.</note></item>
        <item><gloss target="#t_NATO_1">NATO</gloss> countries</item>
      </list>
    </div>
    """

    /// How many links each entry holds, a footnote marker counted as one, and which entries hold links
    /// and spaces alone.
    static let linksPerEntry = [7, 3, 2, 2, 2, 1, 1, 3, 4, 3, 3, 1, 1, 1, 2, 2, 1]
    static let linksAloneEntries: Set<Int> = [0, 1, 2, 3, 4, 5, 6, 11, 12, 13, 14, 15]

    /// Measures the page's list links and footnote markers, or `selector`'s elements: the entry each is
    /// in, its kind, its computed display, decoration and border, its boxes and where its text starts.
    private static func measuringScript(_ selector: String = ".frus-list a, .frus-list button.fn-marker") -> String {
        """
        (() => {
          const items = Array.from(document.querySelectorAll('.frus-list > li, .named-list > li'));
          return JSON.stringify(Array.from(document.querySelectorAll('\(selector)')).map((a) => {
            const box = a.getBoundingClientRect();
            const style = getComputedStyle(a);
            const text = document.createRange();
            text.selectNodeContents(a);
            return {
              text: a.textContent, entry: items.indexOf(a.closest('li')),
              kind: a.tagName.toLowerCase() + '.' + a.classList[0], display: style.display,
              width: box.width, height: box.height, top: box.top,
              rects: Array.from(a.getClientRects()).map((r) => [r.left, r.top, r.width, r.height]),
              decorationLine: style.textDecorationLine, decorationStyle: style.textDecorationStyle,
              borderBottomStyle: style.borderBottomStyle, textTop: text.getBoundingClientRect().top,
            };
          }));
        })()
        """
    }

    /// Whether two `[left, top, width, height]` rectangles share any area; edges that touch do not.
    private static func overlap(_ a: [Double], _ b: [Double]) -> Bool {
        a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3]
    }

    @Test("Each link of an item of links alone is a box at least 24 px square, a link beside text stays inline, and no two links overlap",
          arguments: TextSizePreference.allCases)
    func linksAloneAreBoxes24PxSquare(textSize: TextSizePreference) async throws {
        let model = try await ListShapeFixtures.renderModel(Self.index)
        let harness = OffsetEngineTestHarness()
        // The reader's default column, and one of 30ch, narrow enough to wrap Davis's entry.
        for measure in [ReaderMeasure.classic, ReaderMeasure(ch: 30)] {
            let key = "\(textSize.rawValue), \(measure.css)"
            let html = HTMLTemplate.build(model: model, colorScheme: .light, textSize: textSize, measure: measure)
            #expect(html.components(separatedBy: "<li class=\"links-only\">").count == Self.linksAloneEntries.count + 1,
                    "\(key): the serializer marks other items than the fixture's \(Self.linksAloneEntries.count) of links alone")
            try await harness.load(html)
            let raw = try #require(try await harness.evaluateString(Self.measuringScript()),
                                   "\(key): the measuring script returned nothing")
            let links = try JSONDecoder().decode([MeasuredLink].self, from: Data(raw.utf8))
            let counts = Self.linksPerEntry.indices.map { entry in links.filter { $0.entry == entry }.count }
            #expect(counts == Self.linksPerEntry, "\(key): the entries hold \(counts) links")
            for link in links {
                let label = "\(key): “\(link.text)” (\(link.kind), entry \(link.entry))"
                if Self.linksAloneEntries.contains(link.entry) {
                    let display = link.kind == "button.fn-marker" ? "inline-flex" : "inline-block"
                    #expect(link.display == display && link.width >= 23.95 && link.height >= 23.95,
                            "\(label) is \(link.display), \(link.width) × \(link.height) px")
                } else if link.kind != "button.fn-marker" {
                    #expect(link.display == "inline", "\(label), beside text, is drawn \(link.display)")
                }
                // A boxed gloss's dotted rule is an underline, under the term; beside text it keeps its border.
                if link.kind == "a.gloss" {
                    let boxed = Self.linksAloneEntries.contains(link.entry)
                    #expect(boxed ? link.borderBottomStyle == "none" && link.decorationLine.contains("underline")
                                    && link.decorationStyle == "dotted"
                                  : link.borderBottomStyle == "dotted" && !link.decorationLine.contains("underline"),
                            "\(label): border \(link.borderBottomStyle), decoration \(link.decorationLine) \(link.decorationStyle)")
                }
                // A boxed marker's number is at the top of its box, where a raised number sits: it starts
                // no more than 2 px below the box's top edge, and its glyph's box, taller than its
                // line-height of 1, rises a little above it (2.2 px in WebKit at Extra Large).
                if link.kind == "button.fn-marker" {
                    #expect(link.textTop <= link.top + 2 && link.textTop >= link.top - link.height / 4,
                            "\(label): its number starts at \(link.textTop), its box at \(link.top), \(link.height) px tall")
                }
            }
            // A target another overlaps is not its own size, and a tap there could land on either.
            for (index, link) in links.enumerated() {
                for other in links[(index + 1)...] {
                    let overlapping = link.rects.contains { mine in other.rects.contains { Self.overlap(mine, $0) } }
                    #expect(!overlapping, "\(key): “\(link.text)” and “\(other.text)” overlap")
                }
            }
            // In the narrow column Davis's entry wraps, so its boxes stack as well as stand in a row,
            // and the long contents title wraps inside its box, its page on the line after it.
            if measure != .classic {
                #expect(Set(links.filter { $0.entry == 0 }.map(\.top)).count > 1, "\(key): Davis's entry does not wrap")
                let contents = links.filter { $0.entry == 3 }
                if contents.count == 2 {
                    #expect(contents[1].top >= contents[0].top + contents[0].height - 0.5,
                            "\(key): the page \(contents[1].top) does not follow the title's box \(contents[0].top) + \(contents[0].height)")
                }
            }
        }
    }

    /// The persons and terms a document names on its `@ana`, which the reader lists below it, one to a
    /// line at the footnotes' size (#1599), each entry a link alone: drawn inline, about 22.6 px apart
    /// at Medium, they were neither 24 px square nor 24 px clear of the next.
    @Test("The links of the lists below a document that names its people and terms are boxes at least 24 px square, a term's dotted rule an underline, and no two overlap",
          arguments: TextSizePreference.allCases)
    func namedListsAreBoxes24PxSquare(textSize: TextSizePreference) async throws {
        var model = try await ListShapeFixtures.renderModel("""
            <div type="document" subtype="historical-document" n="1" xml:id="d1"><p>Text.</p></div>
            """)
        model.listedReferences = ListedReferences(
            persons: [PersonEntry(ref: "p_RD1", name: "Rusk, Dean"), PersonEntry(ref: "p_BMG1", name: "Bundy, McGeorge")],
            terms: [GlossEntry(ref: "t_S_1", term: "S", definition: "Secretary of State"),
                    GlossEntry(ref: "t_NATO_1", term: "NATO", definition: "North Atlantic Treaty Organization")])
        let html = HTMLTemplate.build(model: model, colorScheme: .light, textSize: textSize)
        #expect(html.components(separatedBy: "<ul class=\"named-list\">").count == 3,
                "\(textSize.rawValue): the reader did not write the two named lists")
        let harness = OffsetEngineTestHarness()
        try await harness.load(html)
        let raw = try #require(try await harness.evaluateString(Self.measuringScript(".named-list a")),
                               "\(textSize.rawValue): the measuring script returned nothing")
        let links = try JSONDecoder().decode([MeasuredLink].self, from: Data(raw.utf8))
        #expect(links.map(\.text) == ["Rusk, Dean", "Bundy, McGeorge", "S", "NATO"], "\(textSize.rawValue)")
        for link in links {
            let label = "\(textSize.rawValue): “\(link.text)” (\(link.kind))"
            #expect(link.display == "inline-block" && link.width >= 23.95 && link.height >= 23.95,
                    "\(label) is \(link.display), \(link.width) × \(link.height) px")
            if link.kind == "a.gloss" {
                #expect(link.borderBottomStyle == "none" && link.decorationLine.contains("underline")
                        && link.decorationStyle == "dotted",
                        "\(label): border \(link.borderBottomStyle), decoration \(link.decorationLine) \(link.decorationStyle)")
            }
        }
        for (index, link) in links.enumerated() {
            for other in links[(index + 1)...] {
                let overlapping = link.rects.contains { mine in other.rects.contains { Self.overlap(mine, $0) } }
                #expect(!overlapping, "\(textSize.rawValue): “\(link.text)” and “\(other.text)” overlap")
            }
        }
    }
}
#endif
