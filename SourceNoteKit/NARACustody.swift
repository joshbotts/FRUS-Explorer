// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - NARACustody

/// Whether the National Archives can plausibly hold the records a citation names, and so
/// whether querying its catalogue for them can return a right answer at all (#681).
///
/// ## Why this exists
/// `LotResolutionAcceptance` (#674/#677) guards the **lot-file** route: measured, 14,487 of
/// 54,009 live-catalogue source notes, 26.8%. The other three quarters ran unguarded. The
/// worst of them is the presidential-library route, whose query is a free-text `q` built by
/// joining the library and collection names — no record-group filter, no identifier, no
/// constraint of any kind — rendered as up to three confident results.
///
/// An acceptance test cannot fix that route the way it fixed the lot route, because the lot
/// rule's decisive conjunct is *carries this control number* and library collections have no
/// equivalent identifier. But a large part of the exposure needs no acceptance test at all,
/// only the question this type asks: **is the cited repository even part of NARA?**
///
/// Measured over the corpus, **1,961 documents** name repositories that are not:
/// the Library of Congress (1,060), the National Defense University (242), the Center of
/// Military History (69), the Naval Historical Center (55), and a tail of universities and
/// state historical societies. For every one of those, the catalogue has no record to find, so
/// whatever the free-text query surfaces is noise presented as a finding. There is no right
/// answer to return and the honest response is to say so.
///
/// ## Why an allow-list rather than a deny-list
/// A deny-list only refuses the institutions someone thought to name, and the tail here is
/// long and open-ended — Minnesota Historical Society, Princeton, Yale, the University of
/// Montana, plus mis-parses like `"NSC 5906"` and `"National Security Council Files"` that are
/// not repositories at all. An allow-list refuses all of those by default, and the cost of
/// being wrong is bounded in the safe direction: a NARA repository missing from the list loses
/// a query that had no acceptance test anyway, while a non-NARA repository admitted by mistake
/// renders results that are wrong by construction.
///
/// ## What this deliberately does not claim
/// A `.nara` answer means only *the catalogue may hold this* — it is a precondition for
/// querying, not evidence about any result the query returns. The remaining free-text weakness
/// on that route is untouched here and is still the open part of #681.
///
/// Version history:
///   1.0 — Session 2026-08-06: #681, extracted so both platform views share one rule
public enum NARACustody: Sendable, Equatable {

    /// The National Archives administers this repository, so its catalogue may describe the
    /// records — a precondition for querying, not a judgement about the results.
    case nara
    /// The repository is not part of the National Archives, or is not a repository at all.
    /// A catalogue query cannot return a right answer for it.
    case outside

    /// The repositories whose records the National Archives actually holds: the fourteen
    /// NARA-administered presidential libraries, plus NARA itself.
    ///
    /// Compared against `CollectionKeying.canonicalRepository`, so the spellings FRUS uses
    /// (`Harry S. Truman Library`, `Nixon Presidential Materials`) reach the same entry.
    ///
    /// `hoover library` is the Herbert Hoover Presidential Library and is in the list; the
    /// **Hoover Institution** at Stanford is a different body with a confusingly similar name
    /// and is not. Matching the bare surname would silently admit it.
    private static let naraAdministered: Set<String> = [
        "hoover library", "roosevelt library", "truman library", "eisenhower library",
        "kennedy library", "johnson library", "nixon", "ford library", "carter library",
        "reagan library", "bush library", "clinton library", "obama library",
        "national archives",
    ]

    /// Whether the National Archives can hold what `repository` names.
    ///
    /// Unrecognised repositories answer `.outside`. That is the allow-list's whole point: the
    /// unrecognised set is dominated by institutions that genuinely are outside NARA, and by
    /// mis-parses that name no repository at all.
    public static func custody(ofRepository repository: String?) -> NARACustody {
        guard let repository, !repository.trimmingCharacters(in: .whitespaces).isEmpty,
              let canonical = CollectionKeying.canonicalRepository(repository)
        else { return .outside }
        let key = CollectionKeying.normalized(canonical)
        guard !key.isEmpty else { return .outside }
        // Equality, or a prefix ending at a word boundary — `truman library` must match
        // `truman library` but `hoover institution` must not match `hoover library`.
        return naraAdministered.contains(where: { key == $0 || key.hasPrefix($0 + " ") })
            ? .nara : .outside
    }

    /// Whether a catalogue query may be issued for a citation naming `repository`.
    public static func mayQueryCatalog(forRepository repository: String?) -> Bool {
        custody(ofRepository: repository) == .nara
    }
}
