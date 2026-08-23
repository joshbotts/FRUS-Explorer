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

// MARK: - VerifiedFact

/// One institutional claim, with the date the owner confirmed it — or `nil` (#830 T-1, decision D7).
///
/// ## Why the stamp is per fact and not per card
/// D7 is the gate's own correction to the design: artboard 1k draws ONE aggregate stamp per
/// repository card, where the honesty rule asks for a stamp per volatile fact. An address and an
/// appointment policy age at completely different rates, and a single card-level date would either
/// overstate the freshness of the policy or understate the address.
///
/// ## Why `nil` omits rather than prints undated
/// **An unverified fact is not printed at all.** Not greyed, not marked provisional, not shown with
/// a "last checked: unknown" — omitted. A researcher reading a packet is deciding whether to fly
/// somewhere, and a plausible-looking address with a caveat beside it is more dangerous than a gap,
/// because the caveat is the part people skim.
///
/// This nullability is also what makes the T-0 gate incremental: T-1 and T-2 build against a table
/// with **zero** confirmed rows, and each fact the owner confirms lights up one line rather than the
/// whole feature waiting on one sitting.
struct VerifiedFact<Value: Equatable & Sendable>: Equatable, Sendable {

    /// The claim itself.
    let value: Value
    /// When the owner confirmed it; `nil` means unconfirmed.
    let verifiedDate: Date?

    /// The value, or `nil` when it has never been verified — the only accessor a printer may use.
    ///
    /// Deliberately the *only* way out. `value` is `let` and readable, but a call site that reaches
    /// past this to print an unverified claim is doing so visibly rather than by accident.
    var printable: Value? { verifiedDate == nil ? nil : value }

    /// Creates an unverified fact — the state every row starts in.
    static func unverified(_ value: Value) -> VerifiedFact<Value> {
        VerifiedFact(value: value, verifiedDate: nil)
    }
}

// MARK: - RepositoryFactRow

/// A repository's owner-confirmable facts (#830 T-1, decisions D2 and D7).
///
/// Scoped by D2 to what the catalogue cannot answer: the 11 presidential libraries and the non-NARA
/// tail. The NARA side is derived from `series-facts-index.json` instead — see
/// ``ResearchFacilityResolver`` — which is what shrank hand-curation to the rows where a wrong
/// sentence is possible at all.
struct RepositoryFactRow: Equatable, Sendable, Identifiable {

    /// Stable key — the repository string as the corpus cites it.
    let id: String
    /// What the packet calls this place.
    let displayName: String
    /// Postal address. One of the four claims still owner-only.
    let address: VerifiedFact<String>
    /// Reference inquiry address. Also owner-only.
    let inquiryEmail: VerifiedFact<String>
    /// Whether an appointment is required — A1 distinguishes DC-area from other facilities, and
    /// which applies is per-facility policy, hence per-row and owner-confirmed.
    let appointmentPolicy: VerifiedFact<String>
    /// Links, each independently stamped (D12).
    let links: [RepositoryLink]

    /// Whether this row can print anything at all.
    ///
    /// A row whose every fact is unverified renders nothing — which is the normal state at T-1 and
    /// must not read as a bug.
    var hasAnythingToPrint: Bool {
        address.printable != nil || inquiryEmail.printable != nil
            || appointmentPolicy.printable != nil || links.contains { $0.isPrintable }
    }
}

// MARK: - RepositoryLink

/// A link with its own freshness stamp (#830 T-1, decision D12).
///
/// ## Staleness degrades the sentence, never the build
/// D12 makes URL freshness a release-checklist step rather than a per-fact sitting, because a link
/// is the one fact class that is *mechanically* checkable. When a link's stamp is old the packet
/// says so in the sentence around it; it never withholds the link or fails to render.
///
/// The checker itself is an owner-run tool and needs no app code — but the redirect rule is worth
/// recording where the type lives: **a dead NARA deep link characteristically 301s to a section
/// index that answers 200**, so a status-code grep calls it a pass. A checker must follow redirects
/// and compare the destination.
struct RepositoryLink: Equatable, Sendable, Identifiable {

    /// The URL.
    let url: String
    /// What it is.
    let label: String
    /// When it was last checked; `nil` means never.
    let verifiedDate: Date?
    var id: String { url }

    /// A link with no stamp is not printed — it is an unverified institutional fact like any other.
    var isPrintable: Bool { verifiedDate != nil }

    /// How long a stamp stays fresh before the surrounding sentence hedges.
    static let freshnessWindow: TimeInterval = 180 * 24 * 60 * 60   // ~6 months

    /// Whether the sentence around this link should hedge, given `now`.
    func isStale(asOf now: Date = Date()) -> Bool {
        guard let verifiedDate else { return true }
        return now.timeIntervalSince(verifiedDate) > Self.freshnessWindow
    }
}

// MARK: - RepositoryFactTable

/// The curated repository table (#830 T-1, decisions D2 / D7 / D12).
///
/// **Ships with zero rows, deliberately.** T-1 may not print an institutional fact the owner has
/// not confirmed, and the empty-table-that-still-builds shape is what makes that separation
/// enforceable rather than aspirational: every consumer must already handle "no row", so the day
/// the first curated row lands, nothing else has to change.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
struct RepositoryFactTable: Equatable, Sendable {

    /// The curated rows. Empty at T-1.
    let rows: [RepositoryFactRow]

    /// The shipping table.
    ///
    /// ## One row, two verified facts — and the incrementality D7 designed for
    /// The owner confirmed the NACP postal address and the NACP inquiry email on 2026-08-22. §3.2
    /// calls that pair "the highest-value verification in the whole gate", because A2's
    /// send-to-one-address rule is the inquiry mechanic and a generated draft must have a
    /// recipient.
    ///
    /// **`appointmentPolicy` is still unverified and therefore still unprintable.** A1 distinguishes
    /// the DC-area rooms ("strongly encouraged") from other facilities ("required"), and which
    /// applies is per-row policy the owner has not confirmed — so the packet asks the researcher to
    /// check rather than asserting. That is D7 working as intended: two facts light up, the third
    /// stays dark, and no sitting had to complete for the first two to ship.
    ///
    /// The presidential libraries and the non-NARA tail are still absent entirely (D2, D11).
    static let current = RepositoryFactTable(rows: [nacp])

    /// National Archives at College Park — the only row with confirmed facts today.
    ///
    /// The date is the owner's confirmation, not the build date: D7's stamp answers "when was this
    /// last known true", and tying it to a build would refresh itself without anyone checking.
    static let nacp: RepositoryFactRow = {
        let confirmed = DateComponents(calendar: .init(identifier: .gregorian),
                                       timeZone: TimeZone(secondsFromGMT: 0),
                                       year: 2026, month: 8, day: 22).date
        return RepositoryFactRow(
            id: ResearchFacilityResolver.collegePark,
            displayName: ResearchFacilityResolver.collegePark,
            address: VerifiedFact(value: "8601 Adelphi Road\nCollege Park, MD 20740",
                                  verifiedDate: confirmed),
            inquiryEmail: VerifiedFact(value: "Archives2reference@nara.gov", verifiedDate: confirmed),
            // Unverified: see the note on `current`.
            appointmentPolicy: .unverified("strongly encouraged for College Park"),
            links: [])
    }()

    /// The row for a repository, or `nil` — which is every lookup at T-1.
    func row(for repository: String) -> RepositoryFactRow? {
        let key = repository.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.first { $0.id.lowercased() == key }
    }
}
