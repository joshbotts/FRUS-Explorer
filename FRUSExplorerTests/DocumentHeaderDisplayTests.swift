// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
@testable import FRUSExplorer

/// The display-time repair for double-numbered rows and leaked source notes (UI review X-2).
///
/// Version history:
///   1.0 — UI review wave 1 (CW-2): initial implementation
@Suite("Document header display")
struct DocumentHeaderDisplayTests {

    @Test("A header opening with its own number makes the chip a duplicate")
    func repeatDetection() {
        #expect(DocumentHeaderDisplay.headerRepeatsNumber("251. Memorandum From…", number: "251"))
        #expect(DocumentHeaderDisplay.headerRepeatsNumber("372a. Letter From…", number: "372a"))
        #expect(DocumentHeaderDisplay.headerRepeatsNumber(" 251. Memo", number: "251"))
        // Exactness: "2510." does not repeat "251", and an unnumbered row never suppresses.
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("2510. Memo", number: "251"))
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("Memorandum 251", number: "251"))
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("251. Memo", number: nil))
        #expect(!DocumentHeaderDisplay.headerRepeatsNumber("251. Memo", number: ""))
    }

    @Test("A leaked source note is cut from the title, and a legitimate one is left alone")
    func sourceTrim() {
        #expect(DocumentHeaderDisplay.trimmedHeader(
            "376. Letter From Secretary Rogers Source: National Archives, RG 59, Central Files")
            == "376. Letter From Secretary Rogers")
        // Only a mid-string leak is cut: a header BEGINNING with the marker is content.
        let front = "Source: Abbreviations Used in This Volume"
        #expect(DocumentHeaderDisplay.trimmedHeader(front) == front)
        // No marker, no change.
        #expect(DocumentHeaderDisplay.trimmedHeader("134. Memorandum for the President")
            == "134. Memorandum for the President")
    }
}
