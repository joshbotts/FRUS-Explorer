// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ArchivalCounts

/// Count phrases the Archival Analytics screen and its export both print (#1374).
///
/// Version history:
///   1.0 — 2026-09-25: #1374
enum ArchivalCounts {

    /// "1 source note" / "59,973 source notes" — an era's denominator.
    ///
    /// It went through a `%lld`, so every band printed ungrouped: #1374 measured 150,764 / 59,973 /
    /// 22,737 / 18,381 / 12,697 notes across the five.
    ///
    /// - Parameter count: How many source notes.
    /// - Returns: The phrase.
    static func sourceNotes(_ count: Int) -> String {
        CountCopy.phrase(count,
                         one: String(localized: "archival.count.sourceNotes.one",
                                     defaultValue: "%@ source note"),
                         many: String(localized: "archival.count.sourceNotes.many",
                                      defaultValue: "%@ source notes"))
    }
}

// MARK: - ArchivalWeight count phrases

extension ArchivalWeight {

    /// `count` of this weight as a phrase — "12,067 documents", "1 volume" — in the segment's own
    /// words, for the umbrella caveat on screen and in the export (#1374).
    ///
    /// Those sentences set a `%lld` beside the lower-cased segment title, which printed "accounts
    /// for 12067 documents in the 1948–1960 volumes"; and since the title is plural, a count of one
    /// could not be said at all.
    ///
    /// - Parameter count: How many.
    /// - Returns: The phrase, grouped and singular at one.
    func countPhrase(_ count: Int) -> String {
        switch self {
        case .documents:
            return CountCopy.documents(count)
        case .volumes:
            return CountCopy.volumes(count)
        case .unprintedPointers:
            return CountCopy.phrase(count,
                                    one: String(localized: "archival.weight.count.unprintedPointers.one",
                                                defaultValue: "%@ unprinted pointer"),
                                    many: String(localized: "archival.weight.count.unprintedPointers.many",
                                                 defaultValue: "%@ unprinted pointers"))
        }
    }
}
