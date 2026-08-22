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

import Foundation

// MARK: - ResearchFacility

/// Where a researcher would actually go to read a cited record — or an honest statement that the
/// app cannot say (#830 T-1, decisions D2 and D3).
///
/// ## Why this is a sum type and not a `String?`
/// The four outcomes are not degrees of confidence in one answer, they are different KINDS of
/// answer, and a packet that flattened them would print each in the same voice:
///
/// - ``derived`` is NARA's own reference unit for a series, read out of `series-facts-index.json`.
///   It is data. Measured across that index, **694 of 695 series** name "National Archives at
///   College Park — Textual Reference", which is what let D2 scope hand-curation down to the tail.
/// - ``servedAt`` is a citation naming a **creating agency**, not a place. *Department of State*
///   and *Central Intelligence Agency* are agencies; the records are consulted at College Park.
///   D3's rule is that the agency is named as **provenance and never as a destination** — CIA-cited
///   material is read as CREST at NACP, not at CIA.
/// - ``confirmBeforeTravelling`` is a records CENTRE, whose holdings may since have been
///   accessioned. Staff must confirm. D3: it is never a chapter heading a researcher could travel to.
/// - ``unknown`` is the answer for everything else, and it is a real answer. **No chapter in this
///   packet may be headed with a string that names no place a researcher can be served** — so when
///   the app cannot name a facility it says so rather than reprinting the citation as if it were an
///   address.
///
/// ## The curated tail is deliberately absent here
/// D2 scopes hand-curation to the 11 presidential libraries and the non-NARA tail. Those rows are
/// institutional facts the owner has not yet confirmed, and T-1 **may not print one**. So this type
/// models the curated case by *not resolving it* — a library returns ``unknown`` today and will
/// return a curated facility when the table exists. The packet builds either way, with a chapter
/// that is honestly empty rather than one filled with a guess. That is the "empty table that still
/// builds" shape the T-0 gate requires, expressed in the type rather than promised in prose.
enum ResearchFacility: Equatable, Sendable {

    /// NARA's own reference unit for the series, from `series-facts-index.json`.
    case derived(facility: String)

    /// The citation names a creating agency; the records are served somewhere else.
    ///
    /// - Parameters:
    ///   - facility: where the researcher goes.
    ///   - provenance: the agency named in the citation, carried so the packet can say whose
    ///     records these are without implying it is a destination.
    case servedAt(facility: String, provenance: String)

    /// A records centre: staff must confirm where the records now are.
    case confirmBeforeTravelling(named: String)

    /// The app cannot name a facility. Not a failure to render — a fact about the citation.
    case unknown

    /// The heading a packet chapter may use, or `nil` when there is no visitable place to head it
    /// with.
    ///
    /// `nil` for both ``unknown`` and ``confirmBeforeTravelling``, and the second is the one worth
    /// stating: a records centre is a real institution, and heading a chapter with it would still
    /// send a researcher somewhere the records may no longer be.
    var chapterHeading: String? {
        switch self {
        case .derived(let facility):        return facility
        case .servedAt(let facility, _):    return facility
        case .confirmBeforeTravelling:      return nil
        case .unknown:                      return nil
        }
    }
}

// MARK: - ResearchFacilityResolver

/// Derives a ``ResearchFacility`` from what the app already knows about a cited record (#830 T-1).
///
/// Pure and synchronous: every input is either passed in or read from a bundled artifact, so this
/// is unit-testable without an index, a network, or a container.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1, per D2 and D3
enum ResearchFacilityResolver {

    /// The one place a researcher is served for records whose citation names an agency rather than
    /// a place (D3). Not a curated institutional fact: it is the reference unit NARA itself states
    /// for 694 of the 695 series in `series-facts-index.json`, and the string is the same one.
    static let collegePark = "National Archives at College Park"

    /// Repository strings that name a creating agency, not a visitable place (D3).
    ///
    /// Matched on a normalised form, because the corpus spells these several ways across 150 years
    /// of editorial practice. The VALUE is what the packet prints as provenance; the destination is
    /// always ``collegePark``.
    private static let agencyStrings: [String: String] = [
        "department of state": "Department of State",
        "state department": "Department of State",
        "central intelligence agency": "Central Intelligence Agency",
        "cia": "Central Intelligence Agency",
    ]

    /// Repository strings naming a records centre whose holdings may since have moved (D3).
    private static let recordsCentreStrings: Set<String> = [
        "washington national records center",
        "wnrc",
    ]

    /// Resolves the facility for one cited record.
    ///
    /// - Parameters:
    ///   - naId: the series NAID, when the citation resolved to one. This is the only route to a
    ///     DERIVED answer, because NARA's reference unit is a property of the series.
    ///   - category: the parsed provenance category, which decides whether a curated row would be
    ///     wanted at all.
    ///   - repository: the repository string from the source note, when one was parsed.
    ///   - facts: the series-facts lookup; injected so tests drive the real rule against fixtures.
    /// - Returns: the facility, or ``ResearchFacility/unknown`` — never a guess.
    static func facility(
        naId: String?,
        category: SourceProvenanceCategory?,
        repository: String?,
        facts: (String) -> SeriesFactsIndex.Facts? = { SeriesFactsIndexStore.shared?.facts(forNaId: $0) }
    ) -> ResearchFacility {
        // 1. NARA's own answer, when the citation reached a series. Data beats every rule below.
        if let naId, let unit = facts(naId)?.referenceUnit, !unit.isEmpty {
            return .derived(facility: normalisedReferenceUnit(unit))
        }

        // 2. The repository string, when the citation named one.
        let key = (repository ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !key.isEmpty {
            if recordsCentreStrings.contains(key) {
                return .confirmBeforeTravelling(named: repository ?? "")
            }
            if let agency = agencyStrings[key] {
                return .servedAt(facility: collegePark, provenance: agency)
            }
        }

        // 3. A presidential library or a non-NARA repository wants a CURATED row, and none exists
        //    yet — T-1 may not print an institutional fact the owner has not confirmed. `unknown`
        //    is the honest answer, and the packet's library chapter is a confirm-before-you-travel
        //    prompt rather than a drafted letter precisely because of this (D11).
        if category == .presidentialLibrary || category == .foreignArchive {
            return .unknown
        }

        // 4. State's central files ARE College Park records, and the citation names the department
        //    as the creating agency even when no repository string was parsed. This is the 72.9%
        //    case, so getting it from the category rather than from a string matters.
        if category == .centralDecimalFile || category == .centralForeignPolicyFile {
            return .servedAt(facility: collegePark, provenance: "Department of State")
        }
        if category == .intelligence {
            return .servedAt(facility: collegePark, provenance: "Central Intelligence Agency")
        }

        return .unknown
    }

    /// NARA's reference units carry a service suffix — "National Archives at College Park —
    /// Textual Reference" — which names a reading room rather than a building.
    ///
    /// The packet heads a chapter with the PLACE, so the suffix is dropped. Dropped rather than
    /// mapped, because the two units in the index (Textual Reference, Motion Pictures) both serve
    /// at the same address, and inventing a distinction the data does not carry is exactly the
    /// fabrication this workstream is trying to avoid.
    static func normalisedReferenceUnit(_ unit: String) -> String {
        guard let separator = unit.range(of: " - ") else { return unit }
        return String(unit[unit.startIndex..<separator.lowerBound])
    }
}
