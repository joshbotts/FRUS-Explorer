// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - EducationDashboardTests

/// Pure model tests for the "About the Series" content-model dashboards: the
/// optional `EducationPage.dashboard` variant, the `.aboutTheSeries` category,
/// and the real dashboard pages — `.seriesProduction` (Analytics SA-1b),
/// `.seriesGeography` (Analytics SA-2), `.seriesSourcing` (Analytics SA-3b), and
/// `.administrationProfiles` (Analytics SA-2b).
///
/// These assert the content model only — no SwiftUI view is instantiated — so
/// they run without an `AppState` environment. They guard against: a missing or
/// duplicated dashboard page, a stray `dashboard` on a prose page (which must be
/// `.aboutTheSeries` with empty sections), and a broken deep-link contract for
/// the page ids.
///
/// Version history:
///   1.0 — Analytics Prep-A: initial implementation
///   1.1 — Analytics SA-1b: retargeted from the DEBUG placeholder to the real,
///          unconditional `series-production` page
///   1.2 — Analytics SA-2: now covers BOTH dashboard pages
///          (`series-production`, `series-geography`); the guard is kept general
///   1.3 — Analytics SA-3b: now covers ALL THREE dashboard pages
///          (`series-production`, `series-geography`, `series-sourcing`); the
///          guard is kept general
///   1.4 — Analytics SA-2b: now covers ALL FOUR dashboard pages, adding
///          `series-administrations`; the guard is kept general
///   1.5 — 2026-09-23: #1352 — `ResearchGuideDeepLinkTests` below, the guard for every
///          contextual link INTO the guide, not only the dashboard pages
@MainActor
struct EducationDashboardTests {

    /// The four dashboard page ids paired with their expected dashboard case.
    private static let dashboardPages: [(id: String, dashboard: EducationDashboard)] = [
        ("series-production", .seriesProduction),
        ("series-geography", .seriesGeography),
        ("series-sourcing", .seriesSourcing),
        ("series-administrations", .administrationProfiles),
    ]

    /// The category carries a non-empty localised title.
    @Test("EducationDashboard: aboutTheSeries category has a non-empty title")
    func aboutTheSeriesTitleNonEmpty() {
        #expect(!EducationCategory.aboutTheSeries.title.isEmpty)
    }

    /// Each dashboard case is carried by exactly one page, with the expected id,
    /// category, dashboard, and empty sections; and each id is unique.
    @Test("EducationDashboard: each dashboard page is well-formed and unique")
    func dashboardPagesAreWellFormed() {
        for expected in Self.dashboardPages {
            let matches = EducationPage.all.filter { $0.dashboard == expected.dashboard }
            #expect(matches.count == 1, "Expected exactly one page for \(expected.dashboard)")

            guard let page = matches.first else { continue }
            #expect(page.id == expected.id)
            #expect(page.category == .aboutTheSeries)
            #expect(page.dashboard == expected.dashboard)
            #expect(page.sections.isEmpty)

            // The id is unique across all pages.
            let sameId = EducationPage.all.filter { $0.id == expected.id }
            #expect(sameId.count == 1)
        }
    }

    /// All four dashboard pages exist and are distinct.
    @Test("EducationDashboard: all dashboard pages are present and distinct")
    func allDashboardPagesPresent() {
        let dashboards = EducationPage.all.compactMap(\.dashboard)
        #expect(dashboards.contains(.seriesProduction))
        #expect(dashboards.contains(.seriesGeography))
        #expect(dashboards.contains(.seriesSourcing))
        #expect(dashboards.contains(.administrationProfiles))
        // Exactly four pages carry a dashboard.
        #expect(EducationPage.all.filter { $0.dashboard != nil }.count == 4)
    }

    /// The deep-link contract resolves each dashboard page by id.
    @Test("EducationDashboard: each dashboard page resolves via the deep-link firstIndex lookup")
    func dashboardsResolveViaDeepLink() {
        for expected in Self.dashboardPages {
            let index = EducationPage.all.firstIndex { $0.id == expected.id }
            #expect(index != nil, "Deep link failed to resolve \(expected.id)")
        }
    }

    /// Every page that carries a dashboard is an `.aboutTheSeries` page with
    /// empty sections, and every non-dashboard page carries a `nil` dashboard —
    /// the general guard against a prose page sprouting a dashboard, or a
    /// dashboard page carrying prose that would break the Markdown-link scan.
    @Test("EducationDashboard: only aboutTheSeries pages carry a dashboard, with empty sections")
    func onlyAboutTheSeriesPagesCarryDashboards() {
        for page in EducationPage.all {
            if page.dashboard != nil {
                #expect(page.category == .aboutTheSeries,
                        "Page \(page.id) carries a dashboard but is not .aboutTheSeries")
                #expect(page.sections.isEmpty,
                        "Dashboard page \(page.id) must have empty sections")
            } else {
                #expect(page.dashboard == nil, "Page \(page.id) unexpectedly carries a dashboard")
            }
        }
    }
}

// MARK: - ResearchGuideDeepLinkTests

/// Every contextual link into the Research Guide names a page that exists (#1352).
///
/// `IndexingEducationView` opens at `EducationPage.index(ofDeepLink:)` and falls back to the
/// first page when that returns `nil`. The fallback is right for a plain "open the guide" and
/// silent for a NAMED page that was renamed: NARA Lookup's **Learn About NARA Lookup** named
/// `"app-features"` from Session 163 (`d4e9e96a`, 2026-06-16, when that page became
/// `"finding-documents"`) until #1352, and every tap opened *The Official Record of American
/// Foreign Policy*. Nothing failed, because the literal lived in a view and the ids in a model.
///
/// So this reads the literals out of the app source — every `ResearchGuideLinkButton(…)` call's
/// `pageId:` and every `IndexingEducationView(…)` call's `initialPageId:` — walking each call's
/// balanced parentheses rather than a text window, and resolves each through the same function the
/// view calls. A `ResearchGuideLinkButton` whose `pageId:` is not a string literal fails too: a
/// link this test cannot read is a link nothing checks.
///
/// Version history:
///   1.0 — 2026-09-23: #1352
@MainActor
struct ResearchGuideDeepLinkTests {

    /// One contextual link into the guide, as written in the app source.
    struct Site: CustomStringConvertible {
        /// The source file's name.
        let file: String
        /// The 1-based line the call begins on.
        let line: Int
        /// The page id the call names, or `nil` when its argument is not a string literal.
        let pageId: String?
        /// `file:line → "id"`, the form a failure names a site in.
        var description: String {
            "\(file):\(line) → " + (pageId.map { "\"\($0)\"" } ?? "<not a string literal>")
        }
    }

    /// The app's source tree, resolved from this file's own path.
    private static let sourceRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("FRUSExplorer")

    /// The two ways the app names a guide page: the callee, its argument label, and whether a
    /// non-literal argument fails. `ResearchGuideView` forwards `AppState`'s value into
    /// `IndexingEducationView`, which is the pass-through rather than a named page, so only the
    /// button is held to a literal.
    private static let entryPoints: [(callee: String, label: String, requiresLiteral: Bool)] = [
        ("ResearchGuideLinkButton(", "pageId:", true),
        ("IndexingEducationView(", "initialPageId:", false),
    ]

    /// Scans every Swift file under `FRUSExplorer/` for the guide's entry points.
    ///
    /// - Returns: the number of files read and every site found, literal or not.
    static func scan() throws -> (filesRead: Int, sites: [Site]) {
        let paths = try FileManager.default.subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        // A string literal directly after the label, ending at a comma or the end of the line.
        let literal = try NSRegularExpression(pattern: #"\A\s*"([^"\\]*)"\s*(,|$)"#,
                                              options: .anchorsMatchLines)
        var sites: [Site] = []

        for path in paths {
            let url = sourceRoot.appendingPathComponent(path)
            let content = try String(contentsOf: url, encoding: .utf8)
            for entry in entryPoints {
                var cursor = content.startIndex
                while let match = content.range(of: entry.callee, range: cursor..<content.endIndex) {
                    cursor = match.upperBound
                    // `MyResearchGuideLinkButton(` is a different callee.
                    if match.lowerBound > content.startIndex {
                        let previous = content[content.index(before: match.lowerBound)]
                        if previous.isLetter || previous.isNumber || previous == "_" { continue }
                    }
                    // Walk from the "(" to its partner, so a call broken across lines reads whole.
                    let open = content.index(before: match.upperBound)
                    var depth = 0
                    var index = open
                    var close: String.Index?
                    while index < content.endIndex {
                        if content[index] == "(" {
                            depth += 1
                        } else if content[index] == ")" {
                            depth -= 1
                            if depth == 0 { close = index; break }
                        }
                        index = content.index(after: index)
                    }
                    guard let close else {
                        Issue.record("Unbalanced \(entry.callee) in \(path)")
                        break
                    }
                    let arguments = String(content[content.index(after: open)..<close])
                    let line = content[content.startIndex..<match.lowerBound]
                        .reduce(into: 1) { total, character in if character == "\n" { total += 1 } }
                    cursor = close

                    // No page named: a plain "open the guide", which falls back to page 0 by design.
                    guard let label = arguments.range(of: entry.label) else { continue }
                    let afterLabel = String(arguments[label.upperBound...])
                    let id = literal
                        .firstMatch(in: afterLabel, range: NSRange(afterLabel.startIndex..., in: afterLabel))
                        .flatMap { Range($0.range(at: 1), in: afterLabel) }
                        .map { String(afterLabel[$0]) }
                    if id == nil && !entry.requiresLiteral { continue }
                    sites.append(Site(file: url.lastPathComponent, line: line, pageId: id))
                }
            }
        }
        return (paths.count, sites)
    }

    /// Every named guide page resolves through the same lookup the guide opens with.
    @Test("ResearchGuideDeepLink: every page id a view names resolves to an EducationPage")
    func everyNamedGuidePageExists() throws {
        let (filesRead, sites) = try Self.scan()

        // A moved directory or a renamed button would make the sweep vacuously green. The app
        // tree held 5 `ResearchGuideLinkButton` calls in 479 Swift files when this was written.
        #expect(filesRead > 400,"Read only \(filesRead) Swift file(s): the scan is broken, not the tree clean.")
        #expect(sites.count >= 5, "Found only \(sites.count) guide link(s): the scan is broken, not the tree clean.")

        let dead = sites.filter { $0.pageId.flatMap(EducationPage.index(ofDeepLink:)) == nil }
        #expect(dead.isEmpty, """
            Guide link(s) naming no EducationPage.all id, so the guide opens at page 0 instead \
            (live ids: \(EducationPage.all.map(\.id).joined(separator: ", "))): \
            \(dead.map(\.description).joined(separator: "; "))
            """)
    }

    /// NARA Lookup's two **Learn About NARA Lookup** links open a page whose own text names the
    /// tool. Resolving is not enough: the target #1352 first proposed, `"finding-documents"`,
    /// exists and never mentions NARA, the National Archives or the lookup.
    @Test("ResearchGuideDeepLink: Learn About NARA Lookup opens a page that describes NARA Lookup")
    func naraLookupLinksOpenThePageThatDescribesIt() throws {
        let lookupSites = try Self.scan().sites.filter { $0.file == "NARACatalogLookupView.swift" }
        // One on the macOS title row, one in the iOS sheet's toolbar.
        #expect(lookupSites.count == 2, "Expected 2 NARA Lookup guide links, found \(lookupSites)")

        for site in lookupSites {
            let page = site.pageId
                .flatMap(EducationPage.index(ofDeepLink:))
                .map { EducationPage.all[$0] }
            let text = (page?.sections ?? []).flatMap { section in
                [section.heading ?? ""] + section.paragraphs + (section.bullets ?? [])
            }.joined(separator: "\n")
            #expect(text.localizedCaseInsensitiveContains("NARA Lookup"),
                    "\(site) opens a page whose sections never mention NARA Lookup")
        }
    }
}
