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
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// MARK: - FootnoteLandingTests

/// The script that lands the reader on a footnote a cross-reference named (#988), as the kit builds
/// it. `FRUSOffsetEngineTests` runs it in WebKit through the app's reader; here its text is held.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, with the script moved into the kit
@Suite("Footnote landing (#988)")
struct FootnoteLandingTests {

    private static func sha256(_ bytes: some Sequence<UInt8>) -> String {
        SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
    }

    @Test("A note's script finds its entry by the DOM key the serializer writes, JSON-encoded")
    func scriptNamesTheEntry() throws {
        let script = try #require(FootnoteLanding.script(anchor: "d16fn2"))
        #expect(script.contains(#"document.getElementById("fnote-" + "x-d16fn2")"#))
        #expect(script == FootnoteLanding.script(keyExpression: #""x-d16fn2""#))
    }

    @Test("A key is encoded, never interpolated: a non-ASCII id stays itself, and a quotation mark cannot end it")
    func keysAreEncoded() throws {
        let nonASCII = try #require(FootnoteLanding.script(anchor: "d89fnǁ"))
        #expect(nonASCII.contains(#"("fnote-" + "x-d89fnǁ")"#))
        let quoted = try #require(FootnoteLanding.script(anchor: #"a"b"#))
        #expect(quoted.contains(#"("fnote-" + "x-a\"b")"#))
    }

    @Test("The script sets the global the app's figure retry reads, and washes the entry for 2.4 seconds")
    func globalAndWash() {
        let script = FootnoteLanding.script(keyExpression: "key")
        #expect(FootnoteLanding.revealedGlobal == "FRUSRevealedFootnote")
        #expect(script.contains("window.FRUSRevealedFootnote = li.id;"))
        #expect(script.contains(#"li.classList.add("fn-arrived");"#))
        #expect(script.contains(#"setTimeout(() => li.classList.remove("fn-arrived"), 2400);"#))
    }

    /// Two readers run this script, the app's and FRUS Explorer Light's, so a change to it is a
    /// change to both. Pinned as the reader's page is (`ReaderPageTests`): re-take the pin from the
    /// failure message, and say in the version history why the script changed.
    @Test("The script's text is pinned")
    func scriptIsPinned() {
        let bytes = Array(FootnoteLanding.script(keyExpression: "KEY").utf8)
        let pin = (sha256: "64c1196cf748765d9d06680911f882b4781076372731107aa7df074495d4f512", bytes: 811)
        #expect(Self.sha256(bytes) == pin.sha256 && bytes.count == pin.bytes,
                "the script is \(bytes.count) bytes with SHA-256 \(Self.sha256(bytes)), not its pin")
    }
}
