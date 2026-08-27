// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

/// The published-source outbound link table (W-11): for each publication family
/// `PublishedCitationGrammar` recognizes, one verified destination where a researcher
/// can find the publication's digitized run.
///
/// **Family-level landings, deliberately.** A per-item deep link (this *Bulletin*
/// issue, that Treaty Series pamphlet) cannot be constructed deterministically from a
/// citation and cannot be verified at 916 items — an unverifiable deep link is exactly
/// what D12's stamp discipline exists to refuse. So each row lands on the collection or
/// finding aid, and the panel prints the extracted designation (`No. 592`,
/// `September 5, 1948, p. 300`) as the thing to look for once there — the
/// `CuratedLibraryResolutions` finding-aid-first philosophy.
///
/// **Destination choices, each verified 2026-08-27 under the link checker's own fetch
/// semantics (final URL == declared URL, HTTP 200):**
/// - *Treaty Series* and *Executive Agreement Series* share the Law Library of
///   Congress research guide — the numbered pamphlet series have no single digitized
///   collection, and the guide is the canonical map of where each print lives (Bevans,
///   Statutes at Large, HathiTrust). HathiTrust itself is ruled out as a destination:
///   it 403s every automated fetch, so a HathiTrust row could never pass the checker.
/// - The *Department of State Bulletin* run on the Internet Archive
///   (`pub_department-of-state-bulletin`) is browsable by year and issue date, which is
///   exactly the designation the grammar extracts. The details page is a JS shell, so
///   an automated fetch sees a generic title — the item's existence was confirmed via
///   the metadata API, and archive.org can answer a first fetch with a transient TLS
///   handshake timeout (measured), so a one-off `error` verdict in a checker run is
///   worth a retry before it is read as dead.
/// - *Public Papers of the Presidents* on GovInfo, the GPO's own digitization,
///   organized president-then-year — the grammar's designation order.
///
/// Rows reuse `RepositoryLink` so the stamp discipline is the trip packet's own: an
/// unstamped link does not print, and `Scripts/check_repository_links.py` reads the
/// literal `RepositoryLink(url:label:)` initializers below and rewrites `confirmed`
/// with `--stamp` on a clean pass over this table.
enum PublishedSourceLinkTable {

    /// The confirmation date for every link in this table — the date the checker (or
    /// its fetch semantics, run by hand) last saw each URL answer 200 at its declared
    /// address. One date for the whole table, per D12: a partial pass stamps nothing.
    static let confirmed: Date? = DateComponents(
        calendar: .init(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026, month: 8, day: 27).date

    /// The verified destination for one publication family.
    static func link(for publication: PublishedPublication) -> RepositoryLink {
        switch publication {
        case .treatySeries, .executiveAgreementSeries:
            return RepositoryLink(
                url: "https://guides.loc.gov/researching-treaties-and-international-agreements",
                label: "U.S. treaties research guide (Library of Congress)",
                verifiedDate: confirmed)
        case .stateBulletin:
            return RepositoryLink(
                url: "https://archive.org/details/pub_department-of-state-bulletin",
                label: "Department of State Bulletin (Internet Archive)",
                verifiedDate: confirmed)
        case .publicPapers:
            return RepositoryLink(
                url: "https://www.govinfo.gov/app/collection/PPP",
                label: "Public Papers of the Presidents (GovInfo)",
                verifiedDate: confirmed)
        }
    }
}

/// The published-source guidance block, shared by the iOS panel and the macOS
/// GroupBox so the two surfaces cannot drift (the `SemanticStorageSection` rule:
/// hand-maintained twins mount one view). Parses the stored citation at display
/// time — no index involvement — and renders the publication's name, the extracted
/// designation as search guidance, and the table's verified link. When the grammar
/// declines the citation (the honest tail — Miller, the *Official Bulletin*,
/// congressional prints), it renders the generic consult-the-publication copy both
/// platforms previously duplicated.
struct PublishedSourceGuidanceView: View {
    /// The classifier's citation string, exactly as stored.
    let citation: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let parsed = PublishedCitationGrammar.parse(citation) {
            VStack(alignment: .leading, spacing: 6) {
                Text(parsed.publication.displayName)
                    .font(.callout.weight(.medium))
                if let designation = parsed.designation {
                    Text(String(localized: "source.explorer.published.lookFor",
                                defaultValue: "Look for \(designation) in this publication."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let link = PublishedSourceLinkTable.link(for: parsed.publication)
                if link.isPrintable, let url = URL(string: link.url) {
                    Button {
                        openURL(url)
                    } label: {
                        Label(Self.buttonTitle(for: parsed.publication),
                              systemImage: "arrow.up.right.square")
                            .font(.callout)
                    }
                    .padding(.top, 2)
                    if link.isStale(), let checked = link.verifiedDate {
                        Text(String(localized: "source.explorer.published.linkStale",
                                    defaultValue: "Link last verified \(checked.formatted(date: .abbreviated, time: .omitted))."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text(String(localized: "source.explorer.published.note",
                        defaultValue: "This document was previously published. Consult the cited publication for the original source."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The link button's localized title, naming the destination so the researcher
    /// knows where the tap goes before taking it. The table row's `label` is the
    /// checker's report vocabulary, not UI copy.
    private static func buttonTitle(for publication: PublishedPublication) -> String {
        switch publication {
        case .treatySeries, .executiveAgreementSeries:
            return String(localized: "source.explorer.published.link.treaties",
                          defaultValue: "Open the U.S. treaties research guide (Library of Congress)")
        case .stateBulletin:
            return String(localized: "source.explorer.published.link.bulletin",
                          defaultValue: "Browse the Bulletin on the Internet Archive")
        case .publicPapers:
            return String(localized: "source.explorer.published.link.publicPapers",
                          defaultValue: "Browse the Public Papers on GovInfo")
        }
    }
}

extension PublishedPublication {
    /// The publication's display name for the provenance panel.
    var displayName: String {
        switch self {
        case .treatySeries:
            return String(localized: "source.explorer.published.family.treatySeries",
                          defaultValue: "Treaty Series (Department of State)")
        case .executiveAgreementSeries:
            return String(localized: "source.explorer.published.family.eas",
                          defaultValue: "Executive Agreement Series (Department of State)")
        case .stateBulletin:
            return String(localized: "source.explorer.published.family.bulletin",
                          defaultValue: "Department of State Bulletin")
        case .publicPapers:
            return String(localized: "source.explorer.published.family.publicPapers",
                          defaultValue: "Public Papers of the Presidents")
        }
    }
}
