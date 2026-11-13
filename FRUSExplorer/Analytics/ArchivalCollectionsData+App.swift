// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalCollectionsData over the app's stores

/// The app's `make`, over its bundled stores: FRUSCoreKit's `make` takes the three tables, and the stores
/// that decode them from the app's bundle are the app's.
///
/// Version history:
///   1.0 — 2026-11-12 (FRUS Explorer Light, S24c): the two store defaults of the kit's `make` and its
///          read of `SubjectNumericLabelStore`, when `ArchivalCollectionsData.swift` moved into
///          FRUSCoreKit; every call in the app reads as before
extension ArchivalCollectionsData {

    /// Builds the whole derivation in one pass over the two artifacts, against the app's bundled
    /// external-citation index and decimal-class table unless a caller passes its own, and its
    /// bundled subject-numeric table.
    ///
    /// The defaults are read where a call evaluates them, inside the detached task each view builds
    /// the derivation in, as `make`'s defaults were before it moved into the kit; the subject-numeric
    /// store is read at each class row's and leaf's reading, where `make`'s ranking read it before
    /// (`make(authority:usage:coverage:external:labels:readingSubjectNumericLabels:)`).
    ///
    /// - Parameters:
    ///   - authority: Every authority record.
    ///   - usage: The bundled usage index, or `nil` when it failed to load.
    ///   - coverage: Coverage spans by volume id.
    ///   - external: The external-citation index; the app's bundled one unless given.
    ///   - labels: The decimal-class label table; the app's bundled one unless given.
    static func make(authority: [AuthorityCollectionRecord],
                     usage: CollectionUsageIndex?,
                     coverage: [String: ArchivalVolumeCoverage],
                     external: ExternalCitationIndex? = ExternalCitationIndexStore.shared,
                     labels: DecimalClassLabelTable? = DecimalClassLabelStore.shared)
        -> ArchivalCollectionsData {
        make(authority: authority, usage: usage, coverage: coverage, external: external,
             labels: labels, readingSubjectNumericLabels: { SubjectNumericLabelStore.shared })
    }
}
