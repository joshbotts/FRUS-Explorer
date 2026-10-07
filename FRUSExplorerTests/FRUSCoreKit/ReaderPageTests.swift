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
    static let heads: [String: (sha256: String, bytes: Int)] = [
        "light small": ("44b16a5f1ab95da2d856f2c85bfab546cbd3181eb394e3d95d737efbcf20b3ce", 18270),
        "light medium": ("bc70e7e05909a6cac049e796068c211fa6af094b405d2b77d707c7f60e9f60f1", 18271),
        "light large": ("4da2c8b8f114fc47732749b3695f5e834b4ecef6d1596f70a749a9327f882ed7", 18271),
        "light extraLarge": ("704866f876dd2ea0849467127b385df9fa268c6253935a42acaf72b3248eb2b9", 18271),
        "dark small": ("c0cfb5f5ebf35ce8b13b86e4145892592924276bfa74b965193424bae163e712", 18296),
        "dark medium": ("c6be774220b72242bbfa879f28565d71366765f694d82319c7747568358828be", 18297),
        "dark large": ("ee1fcf2e362eb325fd68496bb2d12159367b386e4946bf387bc9e31e5b84cacb", 18297),
        "dark extraLarge": ("d60f90e487288f757bab1950f48231b10f4f53656db8e8af5e359e279ecfb0f9", 18297),
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
    /// at every size, so each needs 4.5:1.
    static let textColourVariables: Set<String> = ["color-primary", "color-secondary", "color-footnote-text",
                                                   "color-accent", "color-pers-name"]

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

    /// The rules of `css` in order, each its selector list and its declarations (property to
    /// value). Comments are dropped, and a rule inside `@media` or `@keyframes` is read with its
    /// own selector.
    static func rules(in css: String) -> [(selectors: [String], declarations: [String: String])] {
        var text = css
        while let open = text.range(of: "/*"),
              let close = text.range(of: "*/", range: open.upperBound..<text.endIndex) {
            text.removeSubrange(open.lowerBound..<close.upperBound)
        }
        return text.components(separatedBy: "}").compactMap { rule in
            guard let brace = rule.lastIndex(of: "{") else { return nil }
            var head = rule[..<brace]
            if let outer = head.lastIndex(of: "{") { head = head[head.index(after: outer)...] }
            var declarations: [String: String] = [:]
            for declaration in rule[rule.index(after: brace)...].split(separator: ";") {
                let parts = declaration.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                declarations[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)] =
                    parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return (head.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }, declarations)
        }
    }

    /// The declarations of every rule in `css` whose selector list names `selector` exactly, a later
    /// rule's winning, as in the cascade.
    static func declarations(of selector: String, in css: String) -> [String: String] {
        rules(in: css).filter { $0.selectors.contains(selector) }
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
