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
    /// Every spelling this row answers to, folded through the shared normalizers at lookup.
    ///
    /// **The packet has two key spaces and this is what reconciles them.** Chapter 2 heads its
    /// sections by FACILITY (`ResearchFacilityResolver.collegePark`), while
    /// `TripPacketModel.Group.facts` looks a row up by the raw REPOSITORY string the corpus cites
    /// (`Nixon Presidential Materials`). A single `id` compared with `==` served one and silently
    /// missed the other — measured over the export sample, 43 of 126 presidential-library records
    /// do not equal any canonical form, including the corpus's commonest Nixon spelling, which
    /// alone rides ~7,000 notes.
    let matchKeys: [String]
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

    /// Memberwise, with ``matchKeys`` defaulting to the row's own id.
    ///
    /// Written out rather than synthesised so a row that answers to only one spelling — the common
    /// case — does not have to repeat it.
    init(id: String, matchKeys: [String]? = nil, displayName: String,
         address: VerifiedFact<String>, inquiryEmail: VerifiedFact<String>,
         appointmentPolicy: VerifiedFact<String>, links: [RepositoryLink]) {
        self.id = id
        self.matchKeys = matchKeys ?? [id]
        self.displayName = displayName
        self.address = address
        self.inquiryEmail = inquiryEmail
        self.appointmentPolicy = appointmentPolicy
        self.links = links
    }

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

    /// The curated rows.
    let rows: [RepositoryFactRow]

    /// Folded spelling → row, built once.
    ///
    /// Uses `CollectionKeying.canonicalRepository` + `normalized`, the pair
    /// `ManuscriptRepositoryGuidance` and `NARACustody` already use — so a row keyed here matches
    /// the same corpus spellings those surfaces match, rather than a second, subtly different set.
    private let byKey: [String: RepositoryFactRow]

    /// Builds the table and its folded index.
    init(rows: [RepositoryFactRow]) {
        self.rows = rows
        var table: [String: RepositoryFactRow] = [:]
        for row in rows {
            for spelling in row.matchKeys {
                guard let canonical = CollectionKeying.canonicalRepository(spelling) else { continue }
                let key = CollectionKeying.normalized(canonical)
                guard !key.isEmpty else { continue }
                table[key] = row
            }
        }
        byKey = table
    }

    /// Equality ignores the derived index — it is a function of `rows`.
    static func == (lhs: RepositoryFactTable, rhs: RepositoryFactTable) -> Bool {
        lhs.rows == rhs.rows
    }

    /// The row for a repository or facility name, or `nil`.
    func row(for repository: String) -> RepositoryFactRow? {
        guard let canonical = CollectionKeying.canonicalRepository(repository) else { return nil }
        return byKey[CollectionKeying.normalized(canonical)]
    }

    // MARK: - The shipping table

    /// The shipping table: College Park plus the ten presidential libraries the corpus cites.
    ///
    /// ## Ten libraries, and why the number is data rather than a constant
    /// Measured by joining `collection-usage-index.json` to `collection-authority.json`: Nixon
    /// 7,971 documents, Johnson 4,628, Carter 4,618, Eisenhower 3,220, Kennedy 2,353, Ford 1,922,
    /// Reagan 1,339, Roosevelt 405, Truman 104, Bush 10 — 28,570 documents across ten repositories.
    ///
    /// **Hoover and Clinton are absent, for two different reasons, and neither is permanent.**
    /// `hoover library` occurs zero times in the authority (the corpus cites the Hoover
    /// *Institution* at Stanford, a different place). Clinton occurs zero times because the corpus
    /// ends at **1991** and he took office in 1993 — the owner reports those volumes are in
    /// declassification now and will publish within a few years. So this is a "not yet", and
    /// nothing here may encode "ten": a row with no cited documents simply never gets looked up,
    /// which is why adding Clinton later is one row and no other change (D14).
    ///
    /// ## One link per library today, not the two D16 asks for
    /// D16 wants a visit-planning page (*what you must do to get access*) beside a finding aid
    /// (*what kinds of records are held*). Only the first ships. The finding-aid URLs the app
    /// already carries in `NARACatalogClient` were re-checked on 2026-08-22 and **five of six
    /// answer 404** — the hosts discriminate (their roots and the visit pages answer 200, invented
    /// paths answer 404), so those are genuinely dead rather than a fetch artefact. Printing a
    /// verified-dead link is worse than printing none, and guessing replacements would be exactly
    /// the unverified institutional fact D7 exists to prevent.
    static let current = RepositoryFactTable(rows: [nacp] + presidentialLibraries)

    /// The owner's confirmation date for every fact in this table.
    ///
    /// The owner's date, never the build date: D7's stamp answers "when was this last known true",
    /// and tying it to a build would refresh itself without anyone checking.
    static let confirmed: Date? = DateComponents(
        calendar: .init(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026, month: 8, day: 22).date

    /// National Archives at College Park.
    ///
    /// **`appointmentPolicy` is deliberately never verified, and that is now a finding rather than
    /// a gap.** The owner reports the policy is *in flux* and that researchers should check NARA's
    /// site for current guidance (D15), so there is no stable sentence to stamp — the fact was
    /// negated into a link rather than left pending. `printable` returns nil, the exporter prints
    /// the link instead, and no undated claim reaches the reader.
    static let nacp: RepositoryFactRow = RepositoryFactRow(
        id: ResearchFacilityResolver.collegePark,
        matchKeys: [ResearchFacilityResolver.collegePark, "National Archives"],
        displayName: ResearchFacilityResolver.collegePark,
        address: VerifiedFact(value: "8601 Adelphi Road\nCollege Park, MD 20740",
                              verifiedDate: confirmed),
        inquiryEmail: VerifiedFact(value: "Archives2reference@nara.gov", verifiedDate: confirmed),
        appointmentPolicy: .unverified("in flux — see NARA's current guidance"),
        links: [
            RepositoryLink(url: "https://www.archives.gov/research/start/research-visit-faqs",
                           label: "Planning a research visit (NARA)", verifiedDate: confirmed),
            RepositoryLink(url: "https://www.archives.gov/dc-metro/college-park/civilian-textual.html",
                           label: "Before you visit College Park", verifiedDate: confirmed),
            // D16's OTHER half, which College Park lacked. The two links above answer "what must I
            // do to get access"; this one answers "what is actually held" — the same pairing every
            // library row carries, and the distinction the labels exist to draw. Verified
            // 2026-08-22: 200, titled "Records of the Department of State | National Archives".
            RepositoryLink(url: "https://www.archives.gov/research/foreign-policy/state-dept/agency-records",
                           label: "Records of the Department of State", verifiedDate: confirmed),
        ])

    /// The ten presidential libraries the corpus cites, most-cited first.
    ///
    /// Keys are the canonical forms `CollectionKeying.repositoryKeywords` produces, so the corpus's
    /// own variants (`Nixon Presidential Materials`, `Gerald R. Ford Presidential Library`) fold
    /// onto them without a hand-written alias list.
    static let presidentialLibraries: [RepositoryFactRow] = [
        library("Nixon", "Richard Nixon Presidential Library",
                "https://www.nixonlibrary.gov/research/research-frequently-asked-questions-faqs"),
        library("Johnson Library", "Lyndon B. Johnson Presidential Library",
                "https://www.lbjlibrary.org/research/plan-your-visit"),
        library("Carter Library", "Jimmy Carter Presidential Library",
                "https://www.jimmycarterlibrary.gov/research/archives/onsite-services"),
        library("Eisenhower Library", "Dwight D. Eisenhower Presidential Library",
                "https://www.eisenhowerlibrary.gov/research-overview"),
        library("Kennedy Library", "John F. Kennedy Presidential Library",
                "https://www.jfklibrary.org/archives/plan-a-research-visit"),
        library("Ford Library", "Gerald R. Ford Presidential Library",
                "https://www.fordlibrarymuseum.gov/digital-research-room/frequently-asked-questions"),
        library("Reagan Library", "Ronald Reagan Presidential Library",
                "https://www.reaganlibrary.gov/archives/plan-research-visit"),
        library("Roosevelt Library", "Franklin D. Roosevelt Presidential Library",
                "https://www.fdrlibrary.org/research-visit"),
        library("Truman Library", "Harry S. Truman Presidential Library",
                "https://www.trumanlibrary.gov/library/researching-our-holdings"),
        library("Bush Library", "George H.W. Bush Presidential Library",
                "https://www.bush41library.gov/digital-research-room/request-textual-research-appointment"),
    ]

    /// One presidential-library row: a visit-planning link and nothing else.
    ///
    /// Address, inquiry email and appointment policy are all left unverified — D11 reduced the
    /// library chapter from a drafted letter to a confirm-before-you-travel prompt precisely
    /// because at collection grain the packet can name neither a series nor a NAID, and 33
    /// institutional facts collapsed to a set of URLs. Each of these was fetched on 2026-08-22 and
    /// answered without a redirect.
    private static func library(_ key: String, _ name: String, _ url: String) -> RepositoryFactRow {
        RepositoryFactRow(
            id: key, matchKeys: [key], displayName: name,
            address: .unverified(""), inquiryEmail: .unverified(""),
            appointmentPolicy: .unverified(""),
            links: [RepositoryLink(url: url, label: "Plan a research visit",
                                   verifiedDate: confirmed)])
    }
}
