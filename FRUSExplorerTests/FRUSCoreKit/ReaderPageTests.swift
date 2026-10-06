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
@Suite("FRUSCoreKit — the reader's page")
struct ReaderPageTests {

    /// The page before its fragment, through `<body>\n`, for each palette and size: its SHA-256 and
    /// its length in UTF-8 bytes, as the app's `HTMLTemplate.build` wrote it on `v2` at `f69b4a0a`,
    /// before the page moved into the kit. It depends on the palette and the size alone.
    static let headsBeforeTheMove: [String: (sha256: String, bytes: Int)] = [
        "light small": ("874be75da2d5278b2d1d59d296073e4088330c064ae2ade9f12f49a7d48f6c96", 17751),
        "light medium": ("6ffe08fc2fef04ed65151092a7aba82c33bbcef1685f6b7bb41ace09b8cbe9f5", 17752),
        "light large": ("fa881da8e234e8d456b3b441646e72a111fa486190c176230f45d073255b335b", 17752),
        "light extraLarge": ("a3f421ef4ffd2a140c51c7860528a81ee187e3c1cd0be2c1fffb8525c964e349", 17752),
        "dark small": ("ccadac28e619b296c981b38c70766e10ee526e0686cfe3eb43be4e54a8696e60", 17777),
        "dark medium": ("722055ca006e6966b3da3d2ccd9fea4494167ff4b2618d221e45c49ce3c089d2", 17778),
        "dark large": ("930c1ea391e62e465cfe547bd17bec347fb605d2716eb6c0d2a4cf0af304c77b", 17778),
        "dark extraLarge": ("a684c27b97efb55290edff19d3a06229e3988b14591008ca0fd10d983c8a19fd", 17778),
    ]

    /// `frus1946v01/d587`, whose three figures name images.
    private func model() async throws -> FRUSDocumentRenderModel {
        try await ListShapeFixtures.renderModel(FigureFixtures.d587,
                                                converter: ASTToRenderNodeConverter(volumeId: "frus1946v01"))
    }

    private static func sha256(_ bytes: some Sequence<UInt8>) -> String {
        SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
    }

    @Test("Around its fragment the page is byte for byte what the app wrote before the move, in both palettes at all four sizes")
    func thePageIsTheAppsPage() async throws {
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
                let expected = try #require(Self.headsBeforeTheMove[key])
                #expect(Self.sha256(head) == expected.sha256 && head.count == expected.bytes,
                        "\(key): the page's head is \(head.count) bytes with SHA-256 \(Self.sha256(head)), not the app's")
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
