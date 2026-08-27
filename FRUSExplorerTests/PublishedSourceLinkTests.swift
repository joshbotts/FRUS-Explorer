// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

/// Structural pins for the W-11 published-source link table and its join to the
/// citation grammar. The grammar's own extraction fixtures live in
/// `SourceNoteKitTests/PublishedCitationGrammarTests` (SPM); these tests pin the app
/// side — every publication family the grammar can emit must resolve to a stamped,
/// well-formed link, because an unstamped row silently withholds the button and
/// nothing else would notice.
@Suite("PublishedSourceLinkTable")
struct PublishedSourceLinkTests {

    @Test("Every publication family resolves to a printable https link")
    func everyFamilyHasAPrintableLink() {
        for publication in PublishedPublication.allCases {
            let link = PublishedSourceLinkTable.link(for: publication)
            #expect(link.isPrintable,
                    "An unstamped link withholds the panel button for a whole family")
            #expect(link.url.hasPrefix("https://"))
            #expect(URL(string: link.url) != nil)
            #expect(!link.label.isEmpty)
        }
    }

    @Test("The table's confirmation date exists and is checker-shaped")
    func confirmationDateExists() {
        // The checker's --stamp rewrites `year: N, month: N, day: N` in this file; a
        // `confirmed` that fails to compose to a Date means the stamp shape broke.
        #expect(PublishedSourceLinkTable.confirmed != nil)
    }

    @Test("Links are fresh as of the stamp date")
    func linksFreshAtStamp() throws {
        let confirmed = try #require(PublishedSourceLinkTable.confirmed)
        // Pinned clock: freshness is measured against the stamp, not the wall clock,
        // so this test cannot rot as the stamp ages.
        let dayAfter = confirmed.addingTimeInterval(24 * 60 * 60)
        for publication in PublishedPublication.allCases {
            #expect(!PublishedSourceLinkTable.link(for: publication).isStale(asOf: dayAfter))
        }
    }

    @Test("Treaty Series and EAS share the LoC guide; the other families differ")
    func destinationVocabulary() {
        let ts = PublishedSourceLinkTable.link(for: .treatySeries)
        let eas = PublishedSourceLinkTable.link(for: .executiveAgreementSeries)
        let bulletin = PublishedSourceLinkTable.link(for: .stateBulletin)
        let papers = PublishedSourceLinkTable.link(for: .publicPapers)
        #expect(ts.url == eas.url,
                "The numbered pamphlet series share one finding aid by design")
        #expect(Set([ts.url, bulletin.url, papers.url]).count == 3,
                "Three distinct destinations — a copy-paste duplicate would send two families to one place")
    }

    @Test("A real corpus citation joins grammar to table end to end")
    func grammarToTableJoin() throws {
        let parsed = try #require(PublishedCitationGrammar.parse(
            "Source: Department of State Bulletin , May 5, 1946, pp. 778–779."))
        #expect(parsed.publication == .stateBulletin)
        #expect(parsed.designation == "May 5, 1946, pp. 778–779")
        let link = PublishedSourceLinkTable.link(for: parsed.publication)
        #expect(link.url.contains("archive.org"))
        #expect(!parsed.publication.displayName.isEmpty)
    }
}
