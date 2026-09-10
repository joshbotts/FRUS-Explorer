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
import Foundation
@testable import ManifestGeneratorCore
import TEIHeaderKit

/// The two decisions the manifest builder makes about what a `revisionDesc` means.
///
/// The parser reports the header's own words; these pin the policy applied to them. Both rules
/// arrived with OH's release of `frus1981-88v16`, which states its publication date and its
/// partial status in `revisionDesc` and nowhere else.
///
/// Version history:
///   1.0 — Session 2026-09-09: initial implementation
@Suite("Manifest status and date policy")
struct ManifestStatusPolicyTests {

    private func header(printed: String? = nil,
                        publishedWhen: String? = nil,
                        status: String? = nil) -> ParsedTEIHeader {
        var h = ParsedTEIHeader()
        h.publicationDate = printed
        h.publishedWhen = publishedWhen
        h.publicationStatus = status
        return h
    }

    // MARK: - The date

    @Test("The printed year wins whenever the volume prints one")
    func printedYearWins() {
        // The fixture DISAGREES on purpose. 26 shipped volumes do — frus1950v01 prints 1977 and
        // was published digitally in 1998 — so a fixture where the two agree would pass against a
        // rule that preferred either one.
        let h = header(printed: "1977", publishedWhen: "1998")
        #expect(ManifestGeneratorRunner.publicationDate(from: h) == "1977")
    }

    @Test("The digital date is taken only when nothing is printed")
    func digitalDateFillsTheGap() {
        #expect(ManifestGeneratorRunner.publicationDate(from:
            header(publishedWhen: "2026-09-18")) == "2026-09-18")
        #expect(ManifestGeneratorRunner.publicationDate(from: header()) == nil,
                "a volume that states neither must stay silent rather than invent a year")
    }

    @Test("An empty printed year is not a printed year")
    func emptyPrintedYearIsTreatedAsAbsent() {
        // `TEIHeaderParser` leaves the field nil for an empty element, but a hand-built header or
        // a future parser change could deliver "" — and `"" ?? fallback` does not fire.
        #expect(ManifestGeneratorRunner.publicationDate(from:
            header(printed: "", publishedWhen: "2026-09-18")) == "2026-09-18")
    }

    // MARK: - The status

    @Test("The three words the shipped corpus actually uses")
    func mappedStatuses() {
        #expect(ManifestGeneratorRunner.status(from: header(status: "published"),
                                               volumeId: "v") == .published)
        #expect(ManifestGeneratorRunner.status(from: header(status: "partially-published"),
                                               volumeId: "v") == .partiallyPublished)
        #expect(ManifestGeneratorRunner.status(from: header(status: "planned"),
                                               volumeId: "v") == .planned)
    }

    @Test("Silence, and words nobody has shipped, both stay published")
    func unknownAndAbsentStayPublished() {
        // Absent: a guard, not a case — all 694 corpus files carry a revisionDesc — but a
        // side-loaded or hand-edited header has none, and demoting a volume the reader can see
        // would be worse than saying nothing.
        #expect(ManifestGeneratorRunner.status(from: header(), volumeId: "v") == .published)
        // In-progress: these four words exist in the corpus but only on the 141 files the app does
        // not ship. A volume that reached this listing has content, so `.planned` would contradict
        // the file just parsed. The mapping says so out loud instead.
        for word in ["being-cleared", "being-researched", "being-digitized", "not-a-real-status"] {
            #expect(ManifestGeneratorRunner.status(from: header(status: word),
                                                   volumeId: "v") == .published,
                    "\(word) must not silently demote a volume that is in the published listing")
        }
    }
}
