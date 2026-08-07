// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SourceNoteKit

// MARK: - NumericLotTests

/// Old-style digits-only lot numbers (#353).
///
/// The shared corpus-wide lot grammar required a letter designator (`64 D 563`), so the 1940s
/// numeric lots — `Lot 122`, `Lot 110` — matched nothing. Measured: **89 documents**, 44 from
/// `unrecognized` and 45 from `namedFileSeries`, where a lot citation had been keyed by its
/// series name instead of by the lot.
///
/// ## The collision the issue asked about, measured
/// #353 asked for a guard against colliding with existing `lotFileNorm` keys. `122` and `60`
/// **do** already exist — and the merge is correct. The existing `122` holds `Secretariat
/// Files: Lot 122, Box 13148`; the newly-read ones are `Lot 122, Box 13107` and `Files of the
/// Policy Committee: Lot 122`. The same State Department lot, the same 131xx box range, cited
/// with and without its series prefix. The collision is the desired behaviour.
///
/// Version history:
///   1.0 — Session 2026-08-07: #353, digits-only lots
@Suite("Old-style numeric lots")
struct NumericLotTests {

    private let parser = SourceNoteParser()

    private func lot(_ note: String) -> String? {
        if case .lotFile(_, let lotNumber, _) = parser.parse(note) { return lotNumber }
        return nil
    }

    @Test("A digits-only lot is read")
    func digitsOnlyLotIsRead() {
        #expect(lot("Lot 122, Box 13107") == "122")
        #expect(lot("Files of the Policy Committee: Lot 122") == "122")
        #expect(lot("Files of the Secretary’s Staff Committee: Lot 110: Box 13143") == "110")
    }

    /// It keys to the same value as the already-recognized citations of that lot, which is the
    /// point — these documents join their file's neighbours.
    @Test("It keys to the same lot as the series-prefixed form")
    func keysWithTheExistingCitations() {
        #expect(lot("Lot 122, Box 13107") == lot("Secretariat Files: Lot 122, Box 13148"))
    }

    // MARK: - What the alternation order and lookahead protect

    /// The digits-only branch is **last**, so a lettered lot still keys whole. Were it first,
    /// `Lot 64 D 563` would reduce to `64` and 245 documents would leave their file.
    @Test("A lettered lot still keys whole")
    func letteredLotIsUnaffected() {
        #expect(lot("Source: Department of State, S/S Files: Lot 63 D 351, NSC Meetings.") == "63 D 351")
        #expect(lot("PPS files, lot 64 D 563, Chronological") == "64 D 563")
        #expect(lot("Lot 61 D 282A") == "61 D 282A")
    }

    /// The negative lookahead stops a lettered lot being cut at its digits.
    @Test("A trailing designator is not truncated")
    func trailingDesignatorIsNotTruncated() {
        #expect(lot("Lot 122A") != "122")
        #expect(lot("Lot 52–242") != "52")
    }
}
