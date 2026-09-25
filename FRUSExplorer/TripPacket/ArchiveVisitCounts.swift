// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchiveVisitCounts

/// A plan's two summary counts, worded once for the plan editor and the plans list (#1374).
///
/// The list row read "8 targets · 1 repositories" and the editor "8 targets across
/// 1 repositories." while the trip packet built from the same plan said "1 repository"
/// (`TripPacketExporter` branches on the count itself). Both screens now take these, which group
/// and singularise through `CountCopy`.
///
/// Version history:
///   1.0 — 2026-09-25: #1374
enum ArchiveVisitCounts {

    /// "1 target" / "N targets".
    ///
    /// - Parameter count: How many research targets the plan derives.
    /// - Returns: The phrase.
    static func targets(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archiveVisit.count.targets.one", defaultValue: "%@ target"),
                         many: String(localized: "archiveVisit.count.targets.many", defaultValue: "%@ targets"))
    }

    /// "1 repository" / "N repositories".
    ///
    /// - Parameter count: How many distinct repositories hold those targets.
    /// - Returns: The phrase.
    static func repositories(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archiveVisit.count.repositories.one",
                                     defaultValue: "%@ repository"),
                         many: String(localized: "archiveVisit.count.repositories.many",
                                      defaultValue: "%@ repositories"))
    }
}
