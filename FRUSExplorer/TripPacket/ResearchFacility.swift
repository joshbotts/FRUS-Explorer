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
///   It is data. Measured across that index, **697 of 698 series** name "National Archives at
///   College Park — Textual Reference", which is what let D2 scope hand-curation down to the tail.
/// - ``servedAt`` is a citation naming a **creating agency**, not a place. *Department of State*
///   and *Central Intelligence Agency* are agencies; the records are consulted at College Park.
///   D3's rule is that the agency is named as **provenance and never as a destination** — CIA-cited
///   material is read as CREST at NACP, not at CIA.
/// - ``curated`` is a repository the owner has curated a row for in ``RepositoryFactTable`` — in
///   practice one of the ten presidential libraries the corpus cites. It is named by the ROW's
///   display name, never by the citation's own spelling, so the heading is a place the owner
///   confirmed exists and the heading looks the same row up again for its links.
/// - ``confirmBeforeTravelling`` is a records CENTRE, whose holdings may since have been
///   accessioned. Staff must confirm. D3: it is never a chapter heading a researcher could travel to.
/// - ``unknown`` is the answer for everything else, and it is a real answer. **No chapter in this
///   packet may be headed with a string that names no place a researcher can be served** — so when
///   the app cannot name a facility it says so rather than reprinting the citation as if it were an
///   address.
///
/// ## A presidential library is a repository (#1458, #1459)
/// D2 scoped hand-curation to the presidential libraries and the non-NARA tail, and T-1 may not
/// print an institutional fact the owner has not confirmed, so at T-1 a library resolved to
/// ``unknown`` and the packet printed it under "Confirm before you travel". That outlived its
/// reason: `RepositoryFactTable.current` has carried ten library rows, links verified, since
/// 2026-08-28, and the plan editor already filed a library target under its row's name while the
/// packet still called it unplaceable — "6 targets across 1 repository" above three sections, and a
/// packet header counting 2 of the 6. The owner decided on 2026-09-25 that a presidential library
/// IS a repository, everywhere, so the rule changed here, at its source, and every surface reads
/// it through ``chapterHeading``. D3 is untouched: an agency is still provenance, a records centre
/// still heads nothing. What a library's row does NOT hold — an address, an inquiry email — stays
/// unprinted, and the packet's draft for a library says so (`TripPacketExporter.inquiryDrafts`).
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

    /// The cited repository has a curated row in ``RepositoryFactTable`` — in practice one of the
    /// presidential libraries — and is named by that row's display name (#1458, #1459).
    ///
    /// - Parameter repository: the row's `displayName`, which heads the chapter.
    case curated(repository: String)

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
        case .curated(let repository):      return repository
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
///   1.1 — 2026-09-25: #1458/#1459 — a citation naming a curated repository (a presidential
///          library) resolves to ``ResearchFacility/curated(repository:)`` instead of `unknown`
enum ResearchFacilityResolver {

    /// The one place a researcher is served for records whose citation names an agency rather than
    /// a place (D3). Not a curated institutional fact: it is the reference unit NARA itself states
    /// for 697 of the 698 series in `series-facts-index.json`, and the string is the same one.
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
    ///   - table: the curated repository rows — the same table `TripPacketModel.build` looks each
    ///     target's `facts` up in, so a target's heading and its links come from one row.
    /// - Returns: the facility, or ``ResearchFacility/unknown`` — never a guess.
    static func facility(
        naId: String?,
        category: SourceProvenanceCategory?,
        repository: String?,
        facts: (String) -> SeriesFactsIndex.Facts? = { SeriesFactsIndexStore.shared?.facts(forNaId: $0) },
        table: RepositoryFactTable = .current
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

        // 3. A foreign government's archive is never curated. The table's fold reads ANY string
        //    containing "National Archives" as College Park (`CollectionKeying.canonicalRepository`
        //    matches that keyword first), so without this a "National Archives of Australia"
        //    citation would head College Park's chapter and join its inquiry to NARA.
        if category == .foreignArchive {
            return .unknown
        }

        // 4. A presidential library is a repository when the owner has curated its row (#1459) —
        //    and only then: a library the table does not hold (Clinton, not yet; D14) is `unknown`,
        //    because only a row the owner confirmed may name a place.
        if category == .presidentialLibrary {
            return curated(repository, in: table) ?? .unknown
        }

        // 5. NARA record-group material IS College Park material, whether or not the citation
        //    resolved to a series.
        //
        //    **The distinction this encodes is between not knowing the SERIES and not knowing the
        //    BUILDING**, and conflating them makes the packet worse in both directions. A State
        //    Department lot file is RG 59 whether or not the app could resolve it — the audit
        //    measured 71.6% of notes resolving to a record group "and stopping", and a record group
        //    is already enough to place a researcher. Sending those to `unknown` would file them
        //    under "confirm where these are", which is the wrong advice: their location is not in
        //    doubt, only their series is, and THAT is what the A4 unresolved-lot flag already tells
        //    them to raise in the inquiry.
        //
        //    Central files are the 72.9% case and reach here without a repository string at all,
        //    which is why this keys on the category rather than on parsed text.
        if category == .centralDecimalFile || category == .centralForeignPolicyFile
            || category == .lotFile || category == .naraCollection
            || category == .namedFileSeries {
            return .servedAt(facility: collegePark, provenance: "Department of State")
        }
        if category == .intelligence {
            return .servedAt(facility: collegePark, provenance: "Central Intelligence Agency")
        }

        // 6. A citation of no recognised category — an unparsed note, a legacy row with no
        //    citation era — that nevertheless names a curated repository is filed there. This is the
        //    plan editor's fallback from before #1458 (a section keyed on the target's curated row),
        //    kept at the source so the editor and the packet cannot disagree about it.
        return curated(repository, in: table) ?? .unknown
    }

    /// The curated facility for a repository string, or `nil` when the table holds no row for it.
    private static func curated(_ repository: String?,
                                in table: RepositoryFactTable) -> ResearchFacility? {
        guard let repository, let row = table.row(for: repository) else { return nil }
        return .curated(repository: row.displayName)
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
