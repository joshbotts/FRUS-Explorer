// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// The rules `SourceExplorerView`'s panels read while they draw, under the names the Mac twin, the lookup sheet
// and the suites read them by (FRUS Explorer Light, S22c). They are FRUSCoreKit's
// (`FRUSCoreKit/SourceExplorer/SourceExplorerPanels.swift`), moved out of `SourceExplorerView.swift` unchanged;
// these forward there. They sit in a file of their own so that the scans of the view's source, which count its
// call sites, read the view's own calls alone.

extension SourceExplorerView {

    /// The honesty line that rides with every resolved scan: FRUSCoreKit's (`SourceExplorerPanels`).
    static let scanCaveat = SourceExplorerPanels.scanCaveat
    /// All State Dept. central-file filing periods: FRUSCoreKit's (`SourceExplorerPanels`). Internal
    /// (not private) so `MacSourceExplorerView` and `NARACatalogLookupView` can reference the same list.
    static let allFilingPeriods: [FilingPeriod] = SourceExplorerPanels.allFilingPeriods
    /// What Source Explorer shows for a Subject-Numeric citation (#1543): FRUSCoreKit's.
    typealias SubjectNumericCitation = SourceExplorerPanels.SubjectNumericCitation
    /// The Subject-Numeric reading of a note: FRUSCoreKit's (`SourceExplorerPanels`).
    static func subjectNumericCitation(parsed: ParsedSourceNote?, note: String,
                                       documentDay: DecimalFileSegment.DocumentDay?) -> SubjectNumericCitation? {
        SourceExplorerPanels.subjectNumericCitation(parsed: parsed, note: note, documentDay: documentDay)
    }
    /// The segment of the Subject-Numeric File a day falls in: FRUSCoreKit's (`SourceExplorerPanels`).
    static func subjectNumericBlock(for day: DecimalFileSegment.DocumentDay?) -> String? {
        SourceExplorerPanels.subjectNumericBlock(for: day)
    }
    /// The basis line under Archival Neighbors: FRUSCoreKit's (`SourceExplorerPanels`).
    static func archivalNeighborBasis(for parsed: ParsedSourceNote?, note: String, documentYear: Int?,
                                      documentDay: DecimalFileSegment.DocumentDay?) -> String? {
        SourceExplorerPanels.archivalNeighborBasis(for: parsed, note: note, documentYear: documentYear,
                                                   documentDay: documentDay)
    }
    /// What the "Matching archival source" line names: FRUSCoreKit's (`SourceExplorerPanels`).
    static func relatedMatchKey(for parsed: ParsedSourceNote?, note: String) -> String? {
        SourceExplorerPanels.relatedMatchKey(for: parsed, note: note)
    }
    /// Why an Archival Neighbors list is empty: FRUSCoreKit's (`SourceExplorerPanels`).
    typealias RelatedEmptyState = SourceExplorerPanels.RelatedEmptyState
    /// Which sentence an empty Archival Neighbors list prints: FRUSCoreKit's (`SourceExplorerPanels`).
    static func relatedEmptyState(for parsed: ParsedSourceNote?, note: String) -> RelatedEmptyState {
        SourceExplorerPanels.relatedEmptyState(for: parsed, note: note)
    }
}
