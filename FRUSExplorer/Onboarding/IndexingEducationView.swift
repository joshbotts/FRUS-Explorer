// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - IndexingEducationView

/// Multipage educational view shown while the index builds.
///
/// Eleven pages make up the guide: seven prose pages introduce FRUS and the
/// app, followed by four live "About the Series" dashboard pages
/// (`seriesProduction`, `seriesGeography`, `seriesSourcing`,
/// `seriesAdministrations`) that render `EducationDashboardView` in place of
/// prose. In the onboarding context the final page's call-to-action simply
/// dismisses the sheet so researchers can start exploring while the first
/// documents finish indexing.
///
/// ## Platform layouts
/// - **macOS**: Two-column document-browser layout. Left sidebar shows numbered
///   chapter titles for direct navigation; right column is a scrollable content
///   area. Navigation buttons sit below the content column.
/// - **iOS/iPadOS**: Tab-paged layout with swipe gesture, page dots, and
///   bottom navigation bar.
///
/// ## Content status
/// All page text reflects the editorially-reviewed copy approved 2026-06-06
/// (mirrored in `Docs/EditableContent.md`, the reviewed source copy). The view can also be opened
/// independently of indexing — as a standalone "Research Guide" — via the
/// `presentationContext` parameter; see the Settings entry point (iOS) and
/// the dedicated window scene reachable from the Help menu (macOS).
///
/// ## Scrolling assessment (2026-06-06)
/// The reviewed copy lengthened several pages relative to the placeholder
/// text it replaced. Both platform layouts already wrap their per-page
/// content in a `ScrollView` — `macContentArea` (macOS) and `iOSPageView`
/// (iOS/iPadOS) — so longer pages simply scroll; no layout change or
/// re-pagination was needed. Splitting long pages into additional pages
/// was considered and rejected: it would fragment topics that read better
/// as a single continuous narrative (e.g. "How FRUS Documents Are
/// Organized") and would complicate the `initialPageId` deep-link contract
/// used by contextual entry points.
///
/// Version history:
///   1.0 — Session 155: initial iOS implementation (4 pages)
///   1.1 — Session 155: added page 5 (App Feature Walkthrough);
///          macOS redesigned as two-column document browser
///   1.2 — Session 2026-06-06: replaced placeholder content with
///          reviewed copy; removed "AI Generated Placeholder" banners;
///          added standalone presentation support
///   1.3 — Authoring Phase 2b: Collections & Export walkthrough copy mentions the
///          live collection preview
///   1.4 — Authoring Phase 3: Collections & Export walkthrough copy mentions the
///          Add Documents sheet (search, browse, pasted citations, tags)
///   1.5 — Authoring Phase 4: Collections & Export walkthrough copy mentions nested
///          sections (3 levels, section moves) and title-page front matter
///   1.6 — Authoring Phase 5: Collections & Export walkthrough copy mentions excerpt
///          quotations, headnotes, and the inspector's per-document export overrides
///   1.7 — Authoring Phase 6: Collections & Export walkthrough copy mentions the five
///          generated apparatus blocks
///   1.8 — Session 2026-07-03 (AI attribution): AI Summaries copy notes that summaries
///          in exported collections are labeled as AI-generated content attributed to
///          Apple Intelligence
///   1.9 — Source Explorer Phase 5 (program docs pass): "Reading a Source Note" notes
///          all-era extraction coverage and the classification-markings chip;
///          "Source Explorer & NARA Catalog" describes the honest empty state for
///          Archival Neighbors, the per-source macOS neighbors window, and the
///          volume Sources list's local counts + cross-volume Collection view
///   1.10 — Analytics SA-1b: added the real "Production & Timeliness" dashboard
///          page (`.aboutTheSeries`), replacing the DEBUG-only Prep-A placeholder
///   1.11 — Analytics SA-2: added the "Geographic Emphasis" dashboard page,
///          second under "About the Series" (administration profiles deferred)
///   1.12 — Docs pass: page 6 gains Person Analytics + Cross-Reference Analytics
///          sections and a "% of documents" normalization note; page 7 Collections
///          notes the two Sort-by-Date modes; struct doc corrected to eleven pages
///          and the `Docs/EditableContent.md` mirror path
///   1.13 — 233–243 wave docs pass: page 3 gains "When a Cross-Reference Leads
///          Nowhere" (#240 validation, degraded links, OH report); page 5 gains
///          "Top Subjects on Volumes" and a person-index identity-curation
///          paragraph (#243); page 6 notes the unresolvable-reference exclusion
///          disclosure and the Administration presets (#236)
///   1.14 — Collections Composer redesign: page 7 "Collections & Export" copy
///          mentions the four one-tap composition presets (teaching reader /
///          briefing packet / source dossier / scholarly edition) and the
///          editable "key takeaway" headnote card (AI-seeded or user-written,
///          with authorship provenance)
///   1.15 — Build 33 docs pass: page 5 gains "Custom Volume Scopes" (#258) and
///          "Related Documents" (#308 Phase 2) sections, a scope/detected-topic
///          note in Full-Text Search, detected-topic framing + the reader's
///          "Subjects (this volume)" panel under Top Subjects on Volumes, and a
///          person-detail Subjects note; page 6 Corpus Analytics notes the
///          "My Volume Scopes" / "By Detected Topic" scope menus, Word Cloud
///          adds the detected-topic scope, Cross-Reference Graph notes macOS
///          scroll-wheel zoom + node context menus, and Source Explorer notes
///          the file-series name + HMS/MLR entry identifiers (#315)
///   1.16 — Analytics D3 (research-grade export): page 6 Corpus Analytics gains an
///          export paragraph (figure PNG/PDF vs. CSV, per-section Export in Person
///          and Cross-Reference Analytics, method travels in the CSV); Word Cloud
///          copy names the Options menu and the CSV's ranked terms, shares, and
///          hidden-word disclosure
///   1.19 — Docs pass (build 37): the Related Documents section now states that a "why related"
///          chip reports only what its signal can support (#643), and the citation section names
///          Settings → Connections rather than the retired Settings → Zotero.
///   1.18 — #597 PR 2 / #641: seven Query & Corpus Analysis sections (query inspector, result
///          facets, working corpora, reading results, keyness, quotation check, method appendix)
///          and the bulk-summarization honesty paragraph.
///   1.17 — Owner content revision (build 35): new "Your Data Stays Private" section on
///          page 7; page 4 intro frames the strategies as print-and-online practice the
///          app builds on; subject data and the shared-topics signal described as
///          experimental; broken-refs export and the per-chart analytics Export mention
///          dropped; subseries-scope comparability note added to cross-reference
///          analytics; HMS/MLR entry reframed as the value you will need; page 7
///          subtitle Americanized ("organizing")
struct IndexingEducationView: View {

    /// Distinguishes the two contexts in which these pages can appear, since
    /// the final page's call-to-action differs between them.
    enum PresentationContext {
        /// Shown while the first index builds (from the indexing banner via
        /// `WhileIndexingSheet`). The final page's call-to-action simply dismisses the
        /// sheet ("Start exploring") — the project/collection setup wizard that used to
        /// follow was removed in Session 163.
        case onboarding
        /// Opened independently as a "Research Guide" — from Settings (iOS)
        /// or a dedicated window (macOS). The final page simply offers to
        /// close the guide.
        case standalone
    }

    @State private var pageIndex: Int
    var presentationContext: PresentationContext
    var onComplete: () -> Void

    /// The link tapped most recently within page body text (`MacSectionView`/
    /// `iOSSectionView` render inline Markdown links via `markdownBody`) —
    /// presented in `InAppBrowserView` instead of the system browser, so
    /// following a reference link doesn't interrupt onboarding or pull the
    /// reader out of the standalone Research Guide. `URL` conforms to
    /// `Identifiable` (see `CollectionEditorView`), so it can drive
    /// `.sheet(item:)` directly.
    @State private var inAppBrowserURL: URL?

    /// - Parameters:
    ///   - initialPageId: Optional `EducationPage.id` to open directly to —
    ///     used by contextual deep links (e.g. "Reading a Source Note" from
    ///     the Source Explorer). Falls back to the first page if not found.
    ///   - presentationContext: Whether this is the onboarding flow or a
    ///     standalone "Research Guide" presentation; governs the final
    ///     page's call-to-action label and behavior.
    ///   - onComplete: Invoked when the user finishes the final page
    ///     (continues to setup, in `.onboarding`) or closes the guide
    ///     (in `.standalone`).
    init(
        initialPageId: String? = nil,
        presentationContext: PresentationContext = .onboarding,
        onComplete: @escaping () -> Void = {}
    ) {
        let startIndex = initialPageId.flatMap { id in
            EducationPage.all.firstIndex { $0.id == id }
        } ?? 0
        _pageIndex = State(initialValue: startIndex)
        self.presentationContext = presentationContext
        self.onComplete = onComplete
    }

    var body: some View {
        Group {
            #if os(macOS)
            macBody
            #else
            iOSBody
            #endif
        }
        // Route inline Markdown link taps in page body text into the
        // in-app browser instead of the system browser — keeps the reader
        // inside onboarding (or the standalone Research Guide window/sheet)
        // rather than launching Safari over it.
        .environment(\.openURL, OpenURLAction { url in
            inAppBrowserURL = url
            return .handled
        })
        .sheet(item: $inAppBrowserURL) { url in
            InAppBrowserView(url: url)
        }
    }

    // MARK: - macOS: two-column document browser

    #if os(macOS)
    /// Reference / Help-book layout: a topic sidebar grouped by category drives a plain
    /// scrolling content pane. No Back/Next wizard chrome — the sidebar is the navigation.
    private var macBody: some View {
        HStack(spacing: 0) {

            // ── Left sidebar: grouped topic list ───────────────────────────
            VStack(spacing: 0) {
                macSidebar
                // The first-run flow needs an explicit way out; the standalone window relies
                // on its close button, so the "Start exploring" affordance is onboarding-only.
                if presentationContext == .onboarding {
                    Divider()
                    Button {
                        onComplete()
                    } label: {
                        Text(finalPageButtonLabel)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(12)
                }
            }
            .frame(width: 210)

            Divider()

            // ── Right content column ───────────────────────────────────────
            macContentArea
        }
        .frame(minWidth: 780, minHeight: 520)
    }

    /// Topic list grouped into category sections ("About FRUS", "Using the app").
    private var macSidebar: some View {
        List(selection: Binding<Int?>(
            get: { pageIndex },
            set: { if let value = $0 { pageIndex = value } }
        )) {
            ForEach(Self.groupedPages, id: \.category) { group in
                Section(group.category.title) {
                    ForEach(group.items, id: \.index) { item in
                        Text(item.page.title)
                            .tag(item.index)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// `EducationPage.all` grouped by category, preserving order and carrying each page's
    /// global index (used as the sidebar selection tag and the `pageIndex`).
    private static var groupedPages: [(category: EducationCategory, items: [(index: Int, page: EducationPage)])] {
        let indexed = EducationPage.all.enumerated().map { (index: $0.offset, page: $0.element) }
        var order: [EducationCategory] = []
        for item in indexed where !order.contains(item.page.category) {
            order.append(item.page.category)
        }
        return order.map { category in
            (category, indexed.filter { $0.page.category == category })
        }
    }

    private var macContentArea: some View {
        let page = EducationPage.all[pageIndex]
        return ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 5) {
                    Text(page.title)
                        .font(.title3.bold())
                    if let subtitle = page.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 14)

                Divider()

                // Body: a live dashboard replaces the prose sections when the
                // page carries one (Analytics Prep-A); otherwise the usual
                // section stack.
                if let dashboard = page.dashboard {
                    EducationDashboardView(dashboard: dashboard,
                                           presentationContext: presentationContext)
                        .padding(28)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(page.sections) { section in
                            MacSectionView(section: section)
                        }
                    }
                    .padding(28)
                }
            }
            .padding(.bottom, 16)
        }
        .id(pageIndex) // reset scroll position when page changes
        .animation(.easeInOut(duration: 0.15), value: pageIndex)
    }

    #endif

    // MARK: - iOS: tab-paged layout

    private var iOSBody: some View {
        VStack(spacing: 0) {
            TabView(selection: $pageIndex) {
                ForEach(Array(EducationPage.all.enumerated()), id: \.offset) { idx, page in
                    iOSPageView(page: page, presentationContext: presentationContext)
                        .tag(idx)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: pageIndex)

            iOSNavigationBar
        }
    }

    private var iOSNavigationBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<EducationPage.all.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == pageIndex ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut, value: pageIndex)
                }
            }
            HStack {
                if pageIndex > 0 {
                    Button(String(localized: "education.nav.back", defaultValue: "Back")) {
                        withAnimation { pageIndex -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if pageIndex < EducationPage.all.count - 1 {
                    Button(String(localized: "education.nav.next", defaultValue: "Next")) {
                        withAnimation { pageIndex += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(finalPageButtonLabel) {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(.bar)
    }

    // MARK: - Shared

    /// Label for the call-to-action button on the final page, which differs
    /// depending on whether the guide leads into setup (`.onboarding`) or
    /// is being read independently (`.standalone`).
    private var finalPageButtonLabel: String {
        switch presentationContext {
        case .onboarding:
            return String(localized: "education.nav.startExploring",
                          defaultValue: "Start exploring")
        case .standalone:
            return String(localized: "education.nav.done",
                          defaultValue: "Done")
        }
    }
}

// MARK: - macOS section view

#if os(macOS)
private struct MacSectionView: View {

    let section: EducationSection

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let heading = section.heading {
                HStack(spacing: 8) {
                    if let symbol = section.systemImage {
                        Image(systemName: symbol)
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                    }
                    Text(heading)
                        .font(.headline)
                }
            }
            ForEach(section.paragraphs, id: \.self) { para in
                Text(AttributedString(markdownBody: para))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let bullets = section.bullets {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(AttributedString(markdownBody: bullet)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(.body)
                .padding(.leading, 4)
            }
        }
    }
}
#endif

// MARK: - iOS page view

private struct iOSPageView: View {

    let page: EducationPage

    /// Whether the guide is read mid-onboarding, forwarded to the live dashboards so the
    /// Archival Sourcing page can withhold its cross-link there (#798).
    var presentationContext: IndexingEducationView.PresentationContext = .standalone


    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(page.title)
                        .font(.title2.bold())
                    if let subtitle = page.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                // Body: a live dashboard replaces the prose sections when the
                // page carries one (Analytics Prep-A); otherwise the usual
                // section stack.
                if let dashboard = page.dashboard {
                    EducationDashboardView(dashboard: dashboard,
                                           presentationContext: presentationContext)
                        .padding(24)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(page.sections) { section in
                            iOSSectionView(section: section)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }
}

private struct iOSSectionView: View {

    let section: EducationSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading = section.heading {
                HStack(spacing: 8) {
                    if let symbol = section.systemImage {
                        Image(systemName: symbol)
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                    }
                    Text(heading).font(.headline)
                }
            }
            ForEach(section.paragraphs, id: \.self) { para in
                Text(AttributedString(markdownBody: para)).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if let bullets = section.bullets {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(AttributedString(markdownBody: bullet)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .font(.body)
                .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Content model

/// Top-level grouping used to organise the guide's pages into sections in the macOS
/// reference sidebar.
///
/// Version history:
///   1.0 — Session 163: initial implementation
///   1.1 — Analytics Prep-A: added `.aboutTheSeries` for the forthcoming live
///          Series Analytics dashboards (SA-1…SA-3)
enum EducationCategory: String {
    /// Background on the FRUS series and how to read its documents.
    case aboutFRUS
    /// Catalog of the app's features and how to reach them.
    case usingTheApp
    /// Live "About the Series" dashboards — production, organization, and
    /// sourcing analytics of the FRUS series itself. Populated by Series
    /// Analytics sessions SA-1…SA-3 (Prep-A stands the category up; it simply
    /// does not appear in the sidebar until a page adopts it, because
    /// `groupedPages` derives the visible categories from the pages present).
    case aboutTheSeries

    /// Localised sidebar section header.
    var title: String {
        switch self {
        case .aboutFRUS:      return String(localized: "education.category.about",    defaultValue: "About FRUS")
        case .usingTheApp:    return String(localized: "education.category.features", defaultValue: "Using the app")
        case .aboutTheSeries: return String(localized: "education.category.series",   defaultValue: "About the Series")
        }
    }
}

/// A single Research Guide page.
///
/// A page renders either static prose `sections` (the default) or — when
/// `dashboard` is non-`nil` — a live SwiftUI dashboard in their place (see
/// `EducationDashboardView`). The dashboard variant is the additive
/// content-model extension introduced by Analytics Prep-A so the Series
/// Analytics dashboards (SA-1…SA-3) can live inside the guide.
///
/// Version history:
///   1.0 — Session 163: initial implementation (prose sections only)
///   1.1 — Analytics Prep-A: added the optional `dashboard` body variant
///   1.2 — Analytics SA-1b: `all` now includes the unconditional
///          `seriesProduction` dashboard page (Prep-A's DEBUG placeholder removed)
///   1.3 — Analytics SA-2: `all` now also includes the `seriesGeography`
///          dashboard page, second under "About the Series"
///   1.4 — Analytics SA-3b: `all` now also includes the `seriesSourcing`
///          dashboard page, third under "About the Series"
///   1.5 — Analytics SA-2b: `all` now also includes the `administrationProfiles`
///          dashboard page, fourth under "About the Series"
///   1.6 — Session 2026-08-11: #835 — an Archival Analytics walkthrough section (the tool
///         appeared nowhere in the guide), and `presentationContext` forwarded to the
///         dashboards through `iOSPageView`
struct EducationPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    /// Sidebar grouping on macOS. Defaults to `.aboutFRUS` so the existing corpus-background
    /// pages need no change.
    let category: EducationCategory
    let sections: [EducationSection]
    /// When non-`nil`, the page renders this live dashboard in place of its
    /// prose `sections` (both platform renderers branch on it). `nil` for every
    /// existing prose page; defaulted to `nil` in the initializer so all prior
    /// page constructions stay byte-identical.
    let dashboard: EducationDashboard?

    init(
        id: String,
        title: String,
        subtitle: String?,
        category: EducationCategory = .aboutFRUS,
        sections: [EducationSection],
        dashboard: EducationDashboard? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.sections = sections
        self.dashboard = dashboard
    }

    /// All guide pages in display order.
    ///
    /// The final page is the live "Production & Timeliness" dashboard
    /// (`seriesProduction`), the first real "About the Series" dashboard
    /// (Analytics SA-1b). It is unconditional — shipped in both debug and
    /// release builds.
    static let all: [EducationPage] = [
        page1, page2, page3, page4, page5, page6, page7,
        seriesProduction, seriesGeography, seriesSourcing, seriesAdministrations,
    ]
}

struct EducationSection: Identifiable {
    let id: String
    let heading: String?
    /// The actual SF Symbol used for this feature's interface element (toolbar button,
    /// sidebar item, etc.), shown beside the heading so users recognise the on-screen
    /// control. `nil` for non-feature (corpus-background) sections.
    let systemImage: String?
    let paragraphs: [String]
    let bullets: [String]?

    init(id: String = UUID().uuidString,
         heading: String? = nil,
         systemImage: String? = nil,
         paragraphs: [String] = [],
         bullets: [String]? = nil) {
        self.id = id
        self.heading = heading
        self.systemImage = systemImage
        self.paragraphs = paragraphs
        self.bullets = bullets
    }
}

// MARK: - Page 1: What FRUS Is

private extension EducationPage {
    static let page1 = EducationPage(
        id: "what-frus-is",
        title: "The Official Record of American Foreign Policy",
        subtitle: "Foreign Relations of the United States",
        sections: [
            EducationSection(
                id: "intro",
                paragraphs: [
                    "Foreign Relations of the United States — FRUS — is the official documentary history of major U.S. foreign policy decisions and significant diplomatic activity, published continuously by the Department of State since 1861. It is one of the longest-running publication programs of the U.S. government and an indispensable source for the history of American diplomacy."
                ]
            ),
            EducationSection(
                id: "mandate",
                heading: "Congressionally-Mandated Historical Transparency",
                paragraphs: [
                    "Since 1991, FRUS is required by federal statute (Public Law 102-138, codified at [22 U.S.C. § 4351 et seq.](https://uscode.house.gov/view.xhtml?req=%22foreign+relations+of+the+United+States%22+series&f=treesort&fq=true&num=2&hl=true&edition=prelim&granuleId=USC-prelim-title22-section4351), amended 2021). The law establishes four binding commitments:"
                ],
                bullets: [
                    "The series must constitute \"a thorough, accurate, and reliable documentary record of major United States foreign policy decisions and significant United States diplomatic activity. Volumes of this publication shall include all records needed to provide a comprehensive documentation of the major foreign policy decisions and actions of the United States Government, including the facts which contributed to the formulation of policies and records providing supporting and alternative views to the policy position ultimately adopted\"",
                    "Volumes must be published within 30 years of the events they document",
                    "Government departments must grant historians full access to pertinent records at 20 years",
                    "An Advisory Committee on Historical Diplomatic Documentation comprised of representatives of major scholarly organizations and experts chosen by the Department of State must oversee the production and declassification process to validate the historical objectivity of the series"
                ]
            ),
            EducationSection(
                id: "ooh",
                heading: "Prepared by the Department of State's Office of the Historian",
                paragraphs: [
                    "FRUS volumes are compiled and edited by professional historians in the Office of the Historian at the Department of State. Historians in the compilation and review team identify the most important documents, provide context through editorial notes and annotations, and review draft volume manuscripts to ensure they provide \"thorough, accurate, and reliable\" coverage of the assigned topic(s). Historians in the declassification, publishing, and digital initiatives team coordinate the complex and thorough interagency declassification review required before release and then the detailed preparation of the manuscript required for publication."
                ]
            ),
            EducationSection(
                id: "sources",
                heading: "Breadth of Sources",
                paragraphs: [
                    "FRUS historians draw on still-classified records from the White House and National Security Council at Presidential Libraries as well as records from the Departments of State and Defense, the CIA, and other agencies, both at the National Archives and directly at those agencies. When needed, they also seek access to the private papers of key policymakers."
                ]
            ),
            EducationSection(
                id: "scope",
                heading: "Scope",
                paragraphs: [
                    "FRUS volumes produced today cover U.S. bilateral and regional relations across the globe, including U.S. policymakers' responses to unfolding crises; their engagement with global issues like human rights, terrorism, narcotics, health, and the environment; and thematic topics including national security policy, foreign economic policy, and foreign affairs organization and management. The series currently spans from 1861 through the early 1990s, with volumes covering the Clinton administration still in production."
                ]
            ),
        ]
    )
}

// MARK: - Page 2: How the Corpus Evolved

private extension EducationPage {
    static let page2 = EducationPage(
        id: "corpus-evolution",
        title: "163 Years in Progress",
        subtitle: "How FRUS changed — and why it matters for research",
        sections: [
            EducationSection(
                id: "origins",
                heading: "Origins: Diplomatic Correspondence (1861–1920s)",
                paragraphs: [
                    "At its birth, FRUS was an instrument of public affairs and congressional relations. The series began during the Civil War as a compilation of official diplomatic correspondence — despatches from diplomatic posts, instructions to U.S. ministers overseas, and notes to and from foreign governments. The volumes documented the operations of the State Department. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Because the volumes were produced by the same clerks who administered the Department's day-to-day business, principles of selection and editing standards reflected operational rather than historical purposes. By the early 20th century, the series had evolved to became a valuable knowledge management tool by providing ready access to key policy and precedent references for officials within the Department and its overseas posts and growing stakeholder constituencies in civil society."
                ]
            ),
            EducationSection(
                id: "professionalization",
                heading: "Professionalization in the Interwar Era (1924-1945)",
                paragraphs: [
                    "In the 1920s, the Department of State began recruiting professionally-trained historians to undertake the increasingly complex editorial work of producing FRUS. Because budget constraints in the early 1900s and operational considerations during World War I delayed publication throughout the previous two decades, those historians had an opportunity to select and edit the historical record of U.S. foreign policy with greater perspective and depth than their predecessors. They established formal editorial principles for FRUS that endured."
                ]
            ),
            EducationSection(
                id: "national-security",
                heading: "The National Security Turn (1945–1970s)",
                paragraphs: [
                    "The Cold War transformed FRUS. As more decision-makers outside the Department of State left their imprint on foreign policy and diplomacy, FRUS historians increasingly needed to complement State Department records with documents drawn from other agencies' files - especially presidential records. At the same time, United States expanded and intensified its engagement around the world. The perceived stakes of disclosure in FRUS grew. In the 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes. Over the following decades, FRUS historians and advisory committee experts maintained that balance and the series served as the Department of State's transparency engine. "
                ]
            ),
            EducationSection(
                id: "crisis",
                heading: "Crisis and Reform (1978–1991)",
                paragraphs: [
                    "By the 1980s, the gap between what FRUS had always claimed to be and what it could actually deliver grew painfully apparent. Historians inside the Office of the Historian struggled to achieve direct access to key CIA records. Academic historians appointed to the Department-chartered Historical Advisory Committee faced tightening security restrictions that made it harder to judge whether information withheld during the declassification process was marginal or essential to the historical integrity of publishable volumes. In 1989 and 1990, academic criticism of a volume documenting U.S. policy toward Iran in the early 1950s without any references to widely-known covert action attracted congressional scrutiny of the State Department's management of the series and its relationship with the advisory committee. In 1991, Congress intervened by establishing statutory mandates for long-standing norms: the mission of the series, the obligations of U.S. Government agencies to provide access to their historical records to the historians producing FRUS, and an advisory committee of academic historians to provide oversight to validate the historical integrity of the series."
                ]
            ),
            EducationSection(
                id: "contemporary",
                heading: "The Contemporary Series (1991–Present)",
                paragraphs: [
                    "Post-1991 volumes reflect the statute's empowerment of FRUS historians with broader sourcing, fuller coverage of intelligence activities, and more detailed acknowledgment of omissions. Even as some volumes are delayed by interagency declassification disagreements, the 30-year rule creates a rolling horizon; volumes covering the Reagan administration are now publishing, with the Bush 41 and Clinton eras in active production."
                ]
            ),
            EducationSection(
                id: "digital",
                heading: "The Digital Transition",
                paragraphs: [
                    "The Office of the Historian's shift to XML-encoded TEI files and digital publication in the 21st century has transformed how FRUS can be read and searched. All 552 volumes are now available as structured digital texts — the foundation for everything this app does. The TEI format preserves document structure (headings, datelines, footnotes, person references) in a form that makes programmatic analysis possible in ways printed volumes never allowed."
                ]
            ),
            EducationSection(
                id: "frus-history",
                paragraphs: [
                    "To dive deeper into the history of the series, see the Office of the Historian's [official history](https://history.state.gov/historicaldocuments/frus-history) of FRUS."
                ]
            ),
        ]
    )
}

// MARK: - Page 3: Understanding What You're Reading

private extension EducationPage {
    static let page3 = EducationPage(
        id: "understanding-documents",
        title: "Understanding What You're Reading",
        subtitle: "Documents, citations, and the archival record",
        sections: [
            EducationSection(
                id: "two-registers",
                paragraphs: [
                    "Every FRUS document is a transcribed and edited representation of an original, archival record. Understanding editorial annotation will help you make full use of FRUS."
                ]
            ),
            EducationSection(
                id: "types",
                heading: "Primary Documents, Editorial Notes, and Front Matter",
                paragraphs: [
                    "FRUS is a documentary history, which means it uses actual historical documents to tell the story of U.S. foreign policy. The historians who compile the volumes carefully select records that best document past decisions, diplomacy, and events. They also provide editorial annotation that adds more context and information from the archives than the documents themselves contain.",
                    "Primary documents are the actual historical records that were produced contemporaneously with the events they describe — cables, memoranda, meeting notes, intelligence assessments, letters. These are reproduced in FRUS (sometimes with excisions) from government files. Starting in the early 20th century, each document was published with a source note identifying its provenance, or where the original was found. Many documents also contain footnotes providing information about the historical context around the document or even offering specific archival citations to other documents, meetings, or events that are referenced in the printed document.",
                    "Many volumes also contain editorial notes written by Office of the Historian historians. They appear as numbered entries in the document sequence and serve several purposes: summarizing developments the editors judged too voluminous or sensitive to reproduce in full, explaining gaps in the record, providing context for surrounding documents, and noting where fuller documentation exists. An editorial note that says \"On [date], the NSC met to discuss…\" is telling you something happened that isn't fully reproduced here. Editorial notes provide additional archival citations to unpublished documents.",
                    "Volume front matter has evolved over time. Recent volumes include valuable information about the editor's research methodology and a listing the archival sources they consulted as they selected documents for inclusion. They also contain annotated lists of people who generated, received, or were mentioned in the documents and terms and abbreviations used in the documents."
                ]
            ),
            EducationSection(
                id: "source-note",
                heading: "Reading a Source Note",
                paragraphs: [
                    "Document source notes identify the archival provenance of the records published in FRUS. A source note for a document in the Reagan subseries might read:",
                    "\"Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Secret; Nodis.\"",
                    "This tells you: the original record was collected from the National Archives; it's in Record Group 59 (State Department records); it's part of the Central Foreign Policy File series; the reel identifier is P840114–1808; and it was classified Secret with a special handling caption.",
                    "One way this app helps researchers is by connecting archival citations detected in source notes directly to NARA's finding aids — so you can navigate from a FRUS document directly to the archive where the original record lives. Source notes are extracted for every era of the series, including the modern volumes whose notes are embedded in the document heading. This makes it easier than ever to follow the archival roadmap FRUS offers for deeper research.",
                    "When a source note records classification markings — \"Secret; Nodis\", or explicitly \"No classification marking\" — the app separates them from the archival citation and shows them as a small chip beside the source note in the reading view, in Source Explorer, and on search results. The markings describe how the original record was handled at the time; the published text has been declassified.",
                    "The app also ships a corpus-wide authority of the archival collections FRUS cites: from Source Explorer you can open any matched collection to see its variant citation forms, its National Archives catalog record, every volume across the series that cites it, and how many documents in your own indexed volumes came from it."
                ]
            ),
            EducationSection(
                id: "broken-references",
                heading: "When a Cross-Reference Leads Nowhere",
                paragraphs: [
                    "The printed volumes cite each other constantly — \"see page 700,\" \"see Document 42.\" Because pre-digital volumes were retyped from the printed books and their cross-references retroactively tagged, a small number cite a page, document, or volume that does not exist in the digital corpus. The app ships a corpus-wide validation of every cross-reference (about 2.7 million checked), so it knows exactly which ones cannot be followed.",
                    "A confirmed-unresolvable reference appears in muted grey with a dotted underline and a small dagger instead of looking like a working link; tapping it explains why it can't be followed and what it apparently meant to point at. These references are also excluded from the cross-reference graph and analytics (the analytics caption discloses how many)."
                ]
            ),
            EducationSection(
                id: "classifications",
                heading: "Excisions",
                paragraphs: [
                    "Most FRUS documents are published in full, but there are many that were published with excisions. Some of these excisions were editorial - the historians who compiled the volume judged that the excised material wasn't significant enough to warrant inclusion. Other excisions were made for policy considerations - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.",
                    "Before the 1920s, FRUS editors did not annotate excisions. Beginning in the 1920s, FRUS historians added ellipses (...) to indicate that material was omitted, but did not describe how much information was withheld or explain whether an excision was editorial in nature or an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for excised material, giving researchers a greater sense of how what is published compares to what had to be withheld."
                ]
            ),
            EducationSection(
                id: "omissions",
                heading: "What FRUS Leaves Out",
                paragraphs: [
                    "FRUS publishes thousands of documents for every administration's foreign policy, but it is just the tip of the iceberg for the entire historical record. Early volumes documented the implementation of foreign policy in the diplomacy conducted by the Department of State, but not the deliberative processes that set the course for U.S. foreign policy in Washington. Later volumes focused more and more on filling this gap by editorial prioritization of the decision-making process and inclusion of more and more records from beyond the State Department. This reversal of editorial focus means that the vast majority of diplomatic records that illustrate how foreign policy was implemented at U.S. embassies throughout the world are underrepresented in recent volumes compared to earlier ones."
                ]
            ),
        ]
    )
}

// MARK: - Page 4: Research Best Practices

private extension EducationPage {
    static let page4 = EducationPage(
        id: "research-practices",
        title: "Using FRUS for Research",
        subtitle: "Strategies for getting the most from the archive",
        sections: [
            EducationSection(
                id: "intro",
                paragraphs: [
                    "FRUS rewards researchers who read across documents, not just within them, and who squeeze valuable information about both historical and archival context from the editorial annotation added to documents. Here are strategies that experienced historians have used with printed and online volumes (later pages will address how this app builds on these tried-and-true methods)."
                ]
            ),
            EducationSection(
                id: "introduction",
                heading: "Read the Front Matter",
                paragraphs: [
                    "Every FRUS volume opens with a substantial editorial introduction that explains the volume's scope, the sources available (and unavailable), major gaps in the record, and key themes. Reading this Front Matter takes minutes but saves hours of confusion."
                ]
            ),
            EducationSection(
                id: "person",
                heading: "Follow the Person, Not Just the Topic",
                paragraphs: [
                    "Some of the richest insights come from tracking individual policymakers across documents. Secretary Kissinger's position in one cable often illuminates a memo written three weeks earlier. The person index in this app aggregates mentions across a volume; use it to trace who was driving decisions, not just what decisions were made."
                ]
            ),
            EducationSection(
                id: "dates",
                heading: "Use Date Ranges Pragmatically",
                paragraphs: [
                    "If your research topic is topical or thematic, you may find that queries across the entire FRUS corpus yield an unmanageably large number of search results. It can seem impossible to wade through page after page of hits. Date filtering lets you focus on reasonable slices of time. You can zero in on a particularly relevant time period or define more manageable chunks for a comprehensive review of results."
                ]
            ),
            EducationSection(
                id: "editorial",
                heading: "Editorial Notes as a Finding Aid",
                paragraphs: [
                    "When an editorial note summarizes a meeting or document rather than reproducing it, that's a research signal, not a dead end. The note includes archival citations to the underlying documentation. You can use the document-level Source Explorer or the free-text NARA Lookup tool to find the relevant finding aids and track down the relevant original records at NARA."
                ]
            ),
            EducationSection(
                id: "cross-volume",
                heading: "Cross Volume Boundaries",
                paragraphs: [
                    "The focus and scope of individual FRUS volumes embody decisions about how to slice a complex record. A decision made in a document on one page of a Latin America volume might have been shaped by simultaneous conversations documented in a Foreign Economic Policy volume. Searching, following cross-references, and building collections across subseries and time periods often reveals policy coherence (or contradiction) that single-volume reading misses."
                ]
            ),
            EducationSection(
                id: "omissions",
                heading: "Don't Forget What You're Not Reading",
                paragraphs: [
                    "FRUS tells the U.S. side of the history of foreign relations. The counterpart cable from a foreign ministry, the intelligence report shaping the other side's expectations and strategies, the domestic political pressures driving a foreign leader — these are absent. FRUS is indispensable for illuminating the thinking and actions of U.S. policymakers. As valuable as that often is, international history is an interactive story that requires understanding events from multiple perspectives to truly master. For many types of questions, researchers should treat FRUS as an entry point to a historical or policy question, not its answer."
                ]
            ),
        ]
    )
}

// MARK: - Page 5: App Feature Walkthrough

private extension EducationPage {
    // MARK: Page 5 — Finding documents

    static let page5 = EducationPage(
        id: "finding-documents",
        title: "Finding What You Need",
        subtitle: "Ways to locate documents across the corpus",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "search",
                heading: "Full-Text Search",
                systemImage: "magnifyingglass",
                paragraphs: [
                    "Search the full text of every downloaded and indexed volume at once. Results are ranked by relevance with English stemming, so searching \"negotiation\" also returns \"negotiate,\" \"negotiated,\" and \"negotiations.\" The search box understands Google-style syntax: wrap words in quotes for an exact phrase (\"missile crisis\"), use OR for either term, a leading minus to exclude a word (-Cuba), a trailing asterisk for prefix matching (negoti*), and NEAR for proximity — NEAR(\"military guarantee\" Europe, 30) finds documents where that phrase appears within thirty words of Europe, which is how you tell a genuine connection from two topics that merely share a volume. Because search is stemmed, \"containment\" also returns \"contain,\" \"containing\" and \"container\" — prefix a term with = to search the literal word only (=containment), and the result count narrows with it.",
                    "Open the advanced filters to narrow by date range, document type, a person mentioned, and the search scope (document text, summaries, notes). You can also limit a search to specific volumes or whole subseries, apply one of your named volume scopes (My Volume Scopes), or filter by a detected topic — either fills the volume picker with the matching indexed volumes, and warns you when a scope has none indexed yet. Search only covers indexed volumes — download and index more to widen the corpus.",
                    "Find it on the Search tab (iOS) or the search window, ⌘F (Mac)."
                ]
            ),
            EducationSection(
                id: "query-inspector",
                heading: "What Your Query Actually Searched For",
                systemImage: "eye.trianglebadge.exclamationmark",
                paragraphs: [
                    "Search rewrites what you type before it runs — stemming, implicit AND between words, the operators above. The Query Inspector shows the expression it compiled, so a search that returns something surprising can be read rather than guessed at.",
                    "It also warns where stemming widens a search past what you meant: type \u{201C}containment\u{201D} and the panel tells you it was searched as \u{201C}contain,\u{201D} which also matches \u{201C}contains\u{201D} and \u{201C}container.\u{201D} Prefix the word with = to search it literally. This matters most when you are about to report a count: an unexpectedly large number is usually a stem, not a finding."
                ]
            ),
            EducationSection(
                id: "result-facets",
                heading: "The Shape of a Result Set",
                systemImage: "square.grid.3x3",
                paragraphs: [
                    "Facets break a result set down by year, volume, person, document type and archival provenance, so you can see at a glance whether a term clusters in one administration, one country file, or one editor\u{2019}s volumes.",
                    "Read the denominator carefully, because it is deliberately not the list you are looking at: facets describe the whole match, before any narrowing you apply below them. That is what makes them comparable to each other — a breakdown that shifted every time you filtered would tell you about your filtering rather than about the corpus.",
                    "Facet rows are also controls. Tapping one narrows the search to that year, volume, or person, and the narrowing appears as a chip you can clear.",
                    "Each section can be re-sorted and paged. Years, volumes and people offer an ordering \u{2014} by count, or by label, which reads as oldest and newest on years and as alphabetical on people \u{2014} and a Show menu setting how many rows a page holds. Years, document type and provenance open showing everything they have; volumes and people open at the top 25 and add a filter field, because a single common-term search can span every volume in the corpus and more than sixteen thousand people."
                ]
            ),
            EducationSection(
                id: "working-corpora",
                heading: "Working Corpora",
                systemImage: "tray.full",
                paragraphs: [
                    "A working corpus is a fixed set of documents \u{2014} the results of one search, frozen. Save one with \u{201C}Save as Working Corpus\u{2026}\u{201D} and apply it from the advanced filters under My Working Corpora; every later search then runs only inside it.",
                    "This is different from a volume scope. A scope narrows to whole volumes; a corpus narrows to the particular documents you captured, which is what you want when the set you care about is \u{201C}the 240 documents that matched, minus the eleven I decided were irrelevant.\u{201D}",
                    "Each corpus records how it was made, and the app repeats it back where you apply one. If the search that produced it was capped, the corpus says so \u{2014} \u{201C}the highest-scoring 7,500 of 67,034 matches\u{201D} \u{2014} because a set that was truncated at capture is not the same evidence as a set that was complete, and you should not have to remember which was which."
                ]
            ),
            EducationSection(
                id: "volume-scopes",
                heading: "Custom Volume Scopes",
                systemImage: "square.stack.3d.up",
                paragraphs: [
                    "A volume scope is a named, reusable set of volumes — every volume covering a crisis, a region, or an administration. Build one in Settings \u{2192} Volume Scopes: the editor lists the whole series with a title filter, and Add Volumes By… gathers matches by detected subject, person, manifest tag, or coverage years and editor. Scopes sync to your other devices via iCloud, and volumes you haven't downloaded stay in a scope and take effect once indexed.",
                    "Apply a scope anywhere the corpus can be sliced: the search filters, the Corpus, Person, and Cross-Reference Analytics scope menus, the Word Cloud, and the About the Series dashboards. Each entry shows how many of the scope's volumes are indexed, and a scope with none indexed is called out honestly rather than silently searching nothing."
                ]
            ),
            EducationSection(
                id: "browser",
                heading: "Corpus Browser",
                systemImage: "books.vertical",
                paragraphs: [
                    "Browse the series the way it is published: corpus → subseries → volume → compilation → document, with a breadcrumb trail so you always know where you are. From here you also download and queue volumes for indexing.",
                    "Find it on the Browse tab (iOS) or the Corpus Browser window, ⇧⌘B (Mac)."
                ]
            ),
            EducationSection(
                id: "volume-subjects",
                heading: "Top Subjects on Volumes",
                systemImage: "tag",
                paragraphs: [
                    "Every volume shows a Top Subjects section — the subjects most characteristic of that volume, drawn from experimental subject data and grouped by category.",
                    "Tap a subject to see the other FRUS volumes covering it across the entire series — including volumes you haven't downloaded — and jump straight to one. It works before downloading, so it doubles as a way to decide which volumes are worth adding to your library.",
                    "These are automatically detected topics, not editorial subject headings, so treat them as experimental — a few may be mistagged. The same topics also work as filters: Filter by detected topic… in the search filters, and the By Detected Topic scope menus in Analytics, the Word Cloud, and the About the Series dashboards, all narrow to the volumes where a topic is most characteristic. The same chips also appear on each volume's page, in its Top Subjects section."
                ]
            ),
            EducationSection(
                id: "chronology",
                heading: "Chronology",
                systemImage: "calendar.day.timeline.left",
                paragraphs: [
                    "Pick a date range and browse every indexed document from that period, grouped by date — ideal for reconstructing how a crisis or summit unfolded day by day. A distribution chart shows where documents cluster across the range and which volumes they come from, and dense dates collapse so a busy day stays readable. Tap a chart bar to jump to that date; tap a volume in the legend to filter. Documents that span a wide range of dates (chiefly editorial notes) are listed separately rather than pinned to a single day. A Word Cloud for this range button turns whatever span you are viewing into a word cloud.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Chronology window (Mac)."
                ]
            ),
            EducationSection(
                id: "person-index",
                heading: "Person Index",
                systemImage: "person.2",
                paragraphs: [
                    "An alphabetical directory of everyone named across your indexed volumes. Select a person to see every document that mentions them — a fast way to follow an individual policymaker, diplomat, or foreign leader through the record.",
                    "The app groups a person's appearances across volumes automatically, but it is deliberately cautious — it won't merge two entries unless it is confident they are the same person, so some people appear more than once. You can finish the job by hand: merge two entries from a person's detail (or a row's context menu), and undo any merge or separation later from the Corrections list. Your corrections sync across your devices.",
                    "A person's detail also lists Subjects — detected topics characteristic of the volumes where they are mentioned (volume-level, not per-document tags). Tap one to see every volume covering it.",
                    "Find it in the Corpus Browser's People section."
                ]
            ),
            EducationSection(
                id: "citation-lookup",
                heading: "Find by Citation",
                systemImage: "text.magnifyingglass",
                paragraphs: [
                    "Have a FRUS citation from a footnote, a syllabus, or another book? Paste it into Find by Citation and the app helps you look for the right document — no manual hunting through volumes and document numbers.",
                    "Find it in the Search screen's overflow (More) menu (iOS) or under Find \u{25B8} Citation Lookup, \u{21E7}\u{2318}F (Mac)."
                ]
            ),
            EducationSection(
                id: "related-documents",
                heading: "Related Documents",
                systemImage: "doc.on.doc",
                paragraphs: [
                    "From any document, Related Documents ranks the indexed documents most connected to the one you are reading, blending five signals: archival provenance (drawn from the same file or collection), cross-references (cites or is cited by), closeness in date, corpus proximity, and shared people. Small icon chips on each result show why it matched, and each chip says only what its signal can support: a count of citations, or simply \"same provenance\", where a percentage would mean nothing.\n\nCorpus proximity reads the FRUS editors' own arrangement. Two documents printed side by side, or gathered into the same short chapter, score highest; the signal eases off as the container they share widens to a whole compilation and then the whole volume, and lower again for a different volume in the same subseries. It is a way of asking what the editors thought belonged together.",
                    "A scope control limits the list to This volume, This subseries, or All volumes, and Adjust weights opens a slider per signal so you can tune the blend — favor provenance for archival work, dates for reconstructing a week — and your tuning is remembered. A sixth signal, shared topics, is visible but stays disabled until experimental detected-topic document data is ready to include in the app.",
                    "Find it in the Research rail's Related tile. On the Mac — and on iPad with Stage Manager — it opens as its own window that stays open while you jump between results."
                ]
            ),
        ]
    )

    // MARK: Page 6 — Seeing the bigger picture

    static let page6 = EducationPage(
        id: "corpus-analysis",
        title: "Seeing the Bigger Picture",
        subtitle: "Tools for analysis across documents and volumes",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "analytics",
                heading: "Corpus Analytics",
                systemImage: "chart.bar.xaxis",
                paragraphs: [
                    "Chart how often a term or phrase appears across the indexed corpus, broken down by decade, year, month, day, subseries, or individual volume. Use it to see when a topic first enters FRUS, how coverage of a country or issue shifts over time, and which volumes are richest for a keyword. The By-Subseries and By-Volume views are interactive: tap a bar to open those exact documents in Search, with the counts shown so you know what to expect.",
                    "A caution: FRUS volumes are selective and evolving proxies for the underlying archival record — treat term-frequency trends as a finding aid, not as direct evidence of what policymakers were discussing. The \u{201C}% of documents\u{201D} toggle on the By-Year and By-Decade charts reads a term as a share of the corpus rather than a raw count \u{2014} the percentage of that period\u{2019}s documents that contain it \u{2014} so a term doesn\u{2019}t look like it is surging simply because the series published more in later decades.",
                    "An Export menu saves a chart as a figure (PNG or PDF) or as the data behind it (CSV) — the time-based charts offer all three; on By Subseries and By Volume the figure items are dimmed and only the CSV is available.",
                    "Analytics runs entirely on your local index; no network connection is required.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Corpus Analytics window (Mac)."
                ]
            ),
            EducationSection(
                id: "reading-results",
                heading: "Four Ways to Read a Search Result Set",
                systemImage: "binoculars",
                paragraphs: [
                    "Above your search results, four readings of the same search are available. Timeline places the matches by date. Concordance lines every occurrence up on your search term, so a page of hits can be read as usage rather than as a list. Collocates ranks the words that keep company with your term. Facets breaks the match down by year, volume, person and provenance.",
                    "They do not all count the same thing, and each panel names the set it used. The concordance shows the page you are on; facets read the whole match; the timeline and collocates cover the results retained for this search. Use Collocates for ideas for follow-on searches: the words your query travels with can help you reconstruct period-specific vocabulary you did not know to look for."
                ]
            ),
            EducationSection(
                id: "keyness",
                heading: "Distinctive Words, Not Just Frequent Ones",
                systemImage: "textformat.size",
                paragraphs: [
                    "The Word Cloud can size words two ways. By frequency, the biggest words in almost any FRUS scope are the ones that are big everywhere \u{2014} government, department, president. Switch \u{201C}Size words by\u{201D} to distinctiveness and the cloud instead ranks words by how much more they appear here than in the corpus as a whole, which is what makes one volume, decade or working corpus look different from every other.",
                    "The comparison is made against a reference built from the whole series and shipped with the app, so it works with no volumes downloaded. It is also honest about when it cannot run: change the tokenizing settings in a way the reference was not built for, or ask for a scope with too little text, and the app says the ranking is unavailable rather than showing you a number it cannot stand behind."
                ]
            ),
            EducationSection(
                id: "person-analytics",
                heading: "Person Analytics",
                systemImage: "person.2",
                paragraphs: [
                    "Where the Person Index is an alphabetical directory for looking someone up, Person Analytics charts how people that were tagged by Office of the Historian editors during production appear across the record over time. Trends mode ranks the most-mentioned people for a chosen era, lets you add up to five people and compare how often each is mentioned year by year (as raw counts or as a share of that period\u{2019}s dated documents), and \u{2014} when exactly two people are selected \u{2014} draws a relationship chart of how often the pair is mentioned together over time. Network mode centres a co-mention graph on one focus person, radiating out to the people most often named alongside them.",
                    "Mentions come only from more recent volumes produced when person tagging was part of the editorial workflow and then only for documents the app can place on a date. On top of that, remember that FRUS itself is a selective record \u{2014} read these as who the published documents foreground, not a full census of who mattered.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Person Analytics window (Mac)."
                ]
            ),
            EducationSection(
                id: "word-cloud",
                heading: "Word Cloud",
                systemImage: WordCloudGlyph.symbol,
                paragraphs: [
                    "See the most frequent terms across any slice of the corpus — a single document, a volume or subseries, a collection, a tag, a saved search, a custom volume scope, a detected topic, a date range, or the whole corpus — with each word sized by how often it appears. Semantic lenses narrow the cloud to people, places, organizations, topics, actions, descriptors, concepts, or sentiment, all recognised on-device.",
                    "Tap any word to chart its frequency across the whole series in Corpus Analytics, hide words you don\u{2019}t want to see, or compare two scopes side by side; from the Options menu, export the cloud as a PNG, PDF, or CSV, where the CSV ranks every visible term with its count and its share of the words counted and records your settings — including how many words you hid by hand. A date-range cloud and the Chronology browser hand off to each other — build a cloud from the dates you are viewing in Chronology, or jump from a date-range cloud back into Chronology for the same span. Tune the cloud\u{2019}s typeface and density in Settings.",
                    "Like Analytics, a word cloud reflects what FRUS editors chose to publish, not the full archival record — read it as a finding aid, not as direct evidence.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Word Cloud window (Mac), plus the word-cloud buttons on documents, volumes, subseries, collections, tags, saved searches, and your custom volume scopes (Settings → Volume Scopes)."
                ]
            ),
            EducationSection(
                id: "cross-reference-graph",
                heading: "Cross-Reference Graph",
                systemImage: "point.3.connected.trianglepath.dotted",
                paragraphs: [
                    "Visualise the web of footnote cross-references the editors drew between documents and volumes. Choose how far to expand the graph — direct connections only, or one or two degrees of neighbors — to trace how a decision was informed by, or fed into, the surrounding record.",
                    "Pinch to zoom and drag to pan — on the Mac the scroll wheel zooms too — and right-click (or long-press) a node to recenter the graph on that document or open it.",
                    "Find it from the Research rail's Graph tile (it opens in its own window on Mac and on iPad with Stage Manager)."
                ]
            ),
            EducationSection(
                id: "cross-reference-analytics",
                heading: "Cross-Reference Analytics",
                systemImage: "point.3.connected.trianglepath.dotted",
                paragraphs: [
                    "Where the graph traces one document\u{2019}s neighborhood, Cross-Reference Analytics steps back and treats the whole citation web as a statistical object. It surfaces the most-referenced documents (those the editors cite most often, by inbound-citation count), a degree-distribution histogram that shows the network\u{2019}s shape \u{2014} a few heavily-cited landmarks and a long tail \u{2014} a volume-to-volume heat matrix of which volumes cite which among the most-connected volumes, and a list of \u{201C}landmark\u{201D} documents ranked by an offline PageRank influence score. Every row is tappable to open the document or volume.",
                    "These are structural measures of how the editors linked documents, not a claim about historical importance. Note also that FRUS editorial practice toward cross-references has changed over time. In more recent volumes, editors were not required to exhaustively annotate previously cross-referenced documents within a volume. Analytics trends over time may reflect evolving editorial practices alongside changes in the archival record. Comparisons within subseries scopes are more likely to carry a historical signal than those that cross editorial eras.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Cross-Reference Analytics window (Mac)."
                ]
            ),
            EducationSection(
                id: "archival-analytics",
                heading: "Archival Analytics",
                systemImage: "archivebox",
                paragraphs: [
                    "Every published FRUS document carries a source note naming the archival file its original was found in. Read one at a time they are citations; clustered across the whole series they answer a question no volume states outright \u{2014} which bodies of records each era\u{2019}s editors actually worked in. Archival Analytics is where that clustering is shown: era-by-era rankings of the collections and filing-system classes the volumes drew on, a co-citation network of which collections were used together, the editors\u{2019} cross-reference flows between archival units, and an archival profile of your own indexed volumes.",
                    "Scope it to a subseries, a saved volume scope, a detected topic, or one president\u{2019}s volumes \u{2014} and note that it scopes over the whole series rather than over your library, so the same scope gives the same figures on any device, with nothing downloaded. Counts can be read as documents or as volumes; those are different questions and give different answers.",
                    "These figures show where the editors drew their documents, which is an editorial and archival signal rather than a census of the archives themselves. The rankings say what was cited, not what exists.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Archival Analytics window (Mac). The Archival Sourcing page of this guide also links straight to it once your first index has finished."
                ]
            ),
            EducationSection(
                id: "semantic-analytics",
                heading: "Semantic Analytics",
                systemImage: "point.3.filled.connected.trianglepath.dotted",
                paragraphs: [
                    "Every other analytics surface measures something the corpus states \u{2014} who is named, what cites what, where a document came from. Semantic Analytics measures how the language sits. Every document in the series is placed on one map by the shape of its wording, so documents that read alike land near each other whether or not they share a volume, a date, or a citation. Regions are named by the vocabulary that distinguishes them from the rest of the corpus.",
                    "You can colour the map four ways \u{2014} by region, by coverage era, by what is downloaded on this device, or by provenance: the archival category most of each volume\u{2019}s source notes name, which shows the State Department\u{2019}s central files giving way to the presidential libraries across the plane. A key under the map names the colours, except on Regions, where colour separates neighbouring regions and the names are drawn on the map itself. Tap a point to see which document it is and open it. Draw a lasso around an area to keep everything inside it as a working corpus, which you can then use to scope a search. Or tap two documents as poles and lay the whole series along the axis between them: the axis runs between the two documents\u{2019} volumes, so two documents from the same volume give no axis, and a slice replaces the vertical axis with each volume\u{2019}s coverage year.",
                    "You can also **scope** the map with the same control the other analytics surfaces use \u{2014} a subseries, one of your own volume scopes, a detected topic, or a president\u{2019}s volumes. Scoping does not shrink the map: the rest of the corpus stays on screen in grey, and the documents in scope keep their colour, so you can see where an editorial or political segment actually falls in the corpus\u{2019}s language. Region names re-rank to the regions the scope fills, and taps and lassos apply only to it. Note the grain: every scope here is a set of whole volumes, so a detected-topic scope lights every document in the volumes carrying that tag rather than only the documents on that subject.",
                    "This is a model\u{2019}s reading of the language, not an editorial fact, and it is experimental. Two cautions in particular. The map\u{2019}s plane preserves local similarity: neighbours are meaningfully near each other, but the distance between two far-apart regions means nothing. And the model was not measured on nineteenth-century prose, so placements in the earliest volumes are a declared unknown rather than a checked result.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Semantic Analytics window (Mac)."
                ]
            ),
            EducationSection(
                id: "source-explorer",
                heading: "Source Explorer & NARA Catalog",
                systemImage: "archivebox",
                paragraphs: [
                    "Open the Source Explorer from any document to read its source note broken into structured archival fields detected during indexing, and to follow citations into NARA's finding aids — the correct period-specific research page, relevant record groups, and related collections.",
                    "Not every FRUS citation points at the National Archives, and the Source Explorer no longer pretends otherwise. Where a note names the Library of Congress, the National Defense University, the Army\u{2019}s Center of Military History, a university library or a historical society, it names the institution that actually holds the records and links to its finding aids instead of running a catalog search that cannot succeed. Two of those repositories have been renamed since FRUS printed them \u{2014} the Naval Historical Center is now the Naval History and Heritage Command, and the U.S. Army Military History Institute\u{2019}s holdings are now the Army Heritage and Education Center \u{2014} so searching under the printed name finds nothing, and the app tells you so.",
                    "Some notes name a file series and nothing else: \u{201C}Roosevelt Papers\u{201D}, \u{201C}J.C.S. Files\u{201D}, \u{201C}Moscow Embassy Files\u{201D}. Where a volume\u{2019}s own front matter says where such a series is held, that answer appears with the editors\u{2019} sentence quoted beneath it, so you can weigh the claim rather than take it on trust. And a \u{201C}Paris Peace Conf.\u{201D} citation looks like a State Department decimal file but is not \u{2014} those records are Record Group 256, the American Commission to Negotiate Peace, and they now resolve there.",
                    "You can also select any text — a lot file number, a decimal file identifier, a collection name — and run a NARA Catalog Lookup directly: lot-file search, keyword search within a record group, or central-files period routing. Period routing needs no key; the other strategies rely on a free NARA Catalog API key you can request from the National Archives and then add in Settings.",
                    "From those same source notes, Archival Neighbors gathers other indexed documents drawn from the same detected archival source — the same lot file, central decimal file, record-group series, or presidential-library collection — so pieces of one file scattered across volumes come back together. Reach it from the Source Explorer, a document\u{2019}s row in a volume\u{2019}s sources list, a search result, or a node in the cross-reference graph; on the Mac each archival source opens its own Archival Neighbors window, so several can sit side by side. An empty list is an honest answer: no document in your indexed volumes cites that source — indexing more volumes may surface some.",
                    "More recent volumes contain a front matter section on sources that provides an annotated list of archival collections its editors drew on. If a volume has a Sources section, it has been enriched so that each collection that resolves — a record group or a lot file — links straight to its record in the National Archives Catalog, each recognized entry shows how many of your indexed documents cite it (a count, or an honest zero), and a collection the app\u{2019}s cross-volume authority tracks opens its full Collection view — aliases, catalog record, and every citing volume — so you can follow a body of records across the series. Resolved collections also show the archival file series name and the HMS/MLR entry number — the identifier NARA staff use to locate a series, and the value you will need when you request the original records."
                ]
            ),
            EducationSection(
                id: "timeline",
                heading: "Document Timeline",
                systemImage: "chart.bar",
                paragraphs: [
                    "Turn any set of results into a timeline. From a search result list or a collection, the timeline view charts those documents by year (and lists them chronologically) so you can see their distribution over time at a glance and spot gaps or concentrations."
                ]
            ),
        ]
    )

    // MARK: Page 7 — Working with documents

    static let page7 = EducationPage(
        id: "working-with-documents",
        title: "Working With Documents",
        subtitle: "Reading, annotating, organizing, and exporting",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "document",
                heading: "The Document Reader",
                systemImage: "doc.richtext",
                paragraphs: [
                    "Every document is rendered from its original TEI-encoded XML, preserving the published structure: headings, datelines, footnote markers, tables, and emphasis. Footnote markers open inline; person names link to the volume's biographical glossary. Read mode keeps the focus on the published text, while Research mode opens the Research rail — your notes, tags, collections, and AI summaries — alongside it."
                ]
            ),
            EducationSection(
                id: "annotations",
                heading: "Highlights, Notes & Tags",
                systemImage: "highlighter",
                paragraphs: [
                    "Create color-coded text highlights that persist across sessions, attach free-text research notes to a passage or a whole document, and apply your own tags to group documents by theme, actor, or analytical category. All of it is yours and travels with your account."
                ]
            ),
            EducationSection(
                id: "projects",
                heading: "Research Projects",
                systemImage: "folder",
                paragraphs: [
                    "A project is an activity lens on your work. Every note, highlight, summary, and collection you create is tagged with the active project, so you can keep separate research threads distinct and switch between them instantly — or work in the global context with no project selected. Switch or create projects from the project picker.",
                    "A default project is created for you; you never have to set one up before exploring."
                ]
            ),
            EducationSection(
                id: "collections",
                heading: "Collections & Export",
                systemImage: "tray.2",
                paragraphs: [
                    "Collections are curated sets you assemble for a purpose — a teaching reader, a briefing packet, a source dossier. The manager is where you shape the content: add documents from any volume, interleave your own section headings and rich-text prose (bold, italic, underline, colour), attach notes to a document, and inspect a document's notes, highlights, tags, summary, and archival source in place. Add Documents gathers documents without leaving the editor — search the index, browse a volume, paste citations or history.state.gov links (each line resolves to its document), or pull in everything carrying one of your tags. The composition lives on the collection itself — default body depth (full text, an AI summary, or a compact index), footnotes, table-of-contents style, and whether to include highlights, notes, or a word cloud — and any single document or whole section can override the body depth. Four one-tap presets — teaching reader, briefing packet, source dossier, scholarly edition — set the whole composition at once as a starting point, adding any apparatus they call for without disturbing what you have already placed. Sections nest up to three levels — indent or outdent a heading from its context menu, drag a heading to move its whole section as a block, and give the collection a subtitle, author line, rich-text introduction, and colophon for a true title page. Excerpt quotations freeze a highlighted or selected passage into the collection as a styled block quote with its citation, and each document's inspector is a per-document control surface — an editable \u{201C}key takeaway\u{201D} headnote above the body (seeded by on-device AI, or written in your own words, with a small chip noting which), per-document overrides for highlights, notes, source note, footnotes, and summary prompt, and a \u{201C}See also\u{201D} line citing cross-referenced documents inside the collection. Generated apparatus blocks — a bibliography, a chronology, a sources-and-archives list, a persons index, and a thematic index — are computed from the collection\u{2019}s documents at every export and in the preview, placeable anywhere like any other row. Sort by Date puts the documents in chronological order either across the whole collection in one sweep, or within each section only \u{2014} so documents stay under their own heading rather than crossing into a neighboring section. A live preview shows the collection exactly as its HTML export while you compose — side-by-side on iPad and Mac, a Preview toggle on iPhone.",
                    "Export is simply how you share it. Render the collection — section headings and prose included — as a PDF, HTML file, or Word document; produce a BibTeX or RIS file for a reference manager; or save a native \u{201C}.fruscollection\u{201D} file: an editable copy a colleague opens right back into their own FRUS Explorer, where the documents travel as references they can download. Import one with Import Collection or by opening the file. A smart collection driven by a saved search can be frozen into an editable copy with Create Static Snapshot.",
                    "Find it on the Collections tab (iOS) or the Collections window, ⇧⌘K (Mac)."
                ]
            ),
            EducationSection(
                id: "quotation-check",
                heading: "Checking Your Quotations",
                systemImage: "checkmark.seal",
                paragraphs: [
                    "An excerpt in a collection is a frozen quotation, captured whenever you captured it. Volumes get reindexed, removed and re-downloaded, so before a collection exports, the app checks every stored excerpt against the text of the document it cites.",
                    "The check is a deterministic comparison, not a judgement. It forgives everything about presentation \u{2014} line breaks, curly versus straight quotes, soft hyphens, capitalisation, and elisions marked with an ellipsis, whose fragments must still appear in order \u{2014} and forgives nothing about wording. A paraphrase does not pass.",
                    "It warns; it never blocks. A quotation from a volume you have since removed cannot be checked at all, and the app says that rather than calling it wrong \u{2014} being unable to verify something is not the same as finding it false."
                ]
            ),
            EducationSection(
                id: "method-appendix",
                heading: "The Query Log as a Method Appendix",
                systemImage: "list.bullet.rectangle.portrait",
                paragraphs: [
                    "The app records the searches you run, and exports them as a methods statement: every query with the scope it ran under, how many volumes were indexed at the time, and what it returned. Find it in Settings \u{2192} Data & Recovery, as a Markdown table and a CSV.",
                    "The reason to keep it is the zeros. \u{201C}I searched for this and found nothing\u{201D} is an assertion; the same sentence with a date, a scope and a denominator is evidence, and it is the only form of it a reader can check.",
                    "A count that hit the app\u{2019}s row ceiling is written as \u{201C}at least 7,500,\u{201D} never as 7,500 \u{2014} it is a floor, and the CSV carries a column saying so, because a spreadsheet will otherwise happily sum a column of floors into a total that was never measured. Searches recorded before the app kept this detail are printed and marked, not quietly dropped.",
                    "A collection can carry the same appendix, narrowed to the project it was exported under. That is off by default: it contains the text of every search you ran, which is exactly the thing not to attach to a shared PDF by accident."
                ]
            ),
            EducationSection(
                id: "citations",
                heading: "Citations & Bibliographic Export",
                systemImage: "quote.bubble",
                paragraphs: [
                    "Every document carries a correctly formatted citation in the history.state.gov style, ready to copy. You can also export citations — individually or for a whole collection — as BibTeX or RIS for your reference manager (RIS imports into Zotero on the desktop via File \u{2192} Import).",
                    "Sending to Zotero is one action: connect a Zotero account (Settings \u{2192} Connections) and Send to Zotero Library pushes a document — or an entire collection — straight into your library over the web, carrying your tags and research notes; without an account it falls back to an RIS file for desktop import."
                ]
            ),
            EducationSection(
                id: "ai",
                heading: "AI Summaries",
                systemImage: "sparkles",
                paragraphs: [
                    "Where Apple Intelligence is available, generate on-device summaries of individual documents using prompt templates — standard ones for different research purposes (analytical, chronological, actor-focused) or your own. Summaries are stored locally and can be used as first drafts of research notes that you revise or exported alongside documents in collections; every summary in an exported collection is labeled as AI-generated content attributed to Apple Intelligence. Treat them as orientation only: always read the primary document yourself for your actual research.",
                    "To summarize a large body of material at once, the background summarizer works through an entire subseries, volume, tag, saved search, date range, or one of your saved volume scopes unattended, reporting progress as it goes — so a stack of summaries is ready when you return.\n\nA large scope takes hours, not minutes, and the app tells you so before you start. Document length across the series varies enormously — a treaty text can run to a million characters — and a document that long is summarized in parts and recombined, so the progress line names the document and the part it is on rather than appearing to stall. The count is summaries actually written: a run that lost documents says so instead of reporting completion."
                ]
            ),
            EducationSection(
                id: "sync",
                heading: "Syncing Across Devices",
                systemImage: "icloud",
                paragraphs: [
                    "Your notes, highlights, tags, collections, and projects sync automatically through iCloud, so your research follows you between iPhone, iPad, and Mac. Downloaded volumes and the search index are stored per-device and are not synced."
                ]
            ),
            EducationSection(
                id: "privacy",
                heading: "Your Data Stays Private",
                systemImage: "lock.shield",
                paragraphs: [
                    "The app does not share any usage or research data with anyone. You can export and share anonymized diagnostic data with the developer for troubleshooting if and when you choose. You can also export all your research data."
                ]
            ),
        ]
    )
}

// MARK: - Series Production dashboard page (Analytics SA-1b)

private extension EducationPage {
    /// The live "About the Series" page that renders the Production &
    /// Timeliness dashboard (`EducationDashboard.seriesProduction`) in place of
    /// prose. Its `sections` are empty by design — the renderers show the
    /// dashboard, not sections — so it contributes no prose paragraph or
    /// Markdown link to scan. Unconditional (shipped in debug and release).
    static let seriesProduction = EducationPage(
        id: "series-production",
        title: String(localized: "education.series.production.page.title",
                      defaultValue: "Production & Timeliness"),
        subtitle: String(localized: "education.series.production.page.subtitle",
                         defaultValue: "How long the official record takes to reach print"),
        category: .aboutTheSeries,
        sections: [],
        dashboard: .seriesProduction
    )
}

// MARK: - Series Geography dashboard page (Analytics SA-2)

private extension EducationPage {
    /// The live "About the Series" page that renders the Geographic Emphasis
    /// dashboard (`EducationDashboard.seriesGeography`) in place of prose. Its
    /// `sections` are empty by design — the renderers show the dashboard, not
    /// sections — so it contributes no prose paragraph or Markdown link to scan.
    /// Placed second under "About the Series", after `seriesProduction`.
    /// Unconditional (shipped in debug and release).
    static let seriesGeography = EducationPage(
        id: "series-geography",
        title: String(localized: "education.series.geography.page.title",
                      defaultValue: "Geographic Emphasis"),
        subtitle: String(localized: "education.series.geography.page.subtitle",
                         defaultValue: "Which regions and countries the series covers most"),
        category: .aboutTheSeries,
        sections: [],
        dashboard: .seriesGeography
    )
}

// MARK: - Series Sourcing dashboard page (Analytics SA-3b)

private extension EducationPage {
    /// The live "About the Series" page that renders the Archival Sourcing Over
    /// Time dashboard (`EducationDashboard.seriesSourcing`) in place of prose. Its
    /// `sections` are empty by design — the renderers show the dashboard, not
    /// sections — so it contributes no prose paragraph or Markdown link to scan.
    /// Placed third under "About the Series", after `seriesGeography`.
    /// Unconditional (shipped in debug and release).
    static let seriesSourcing = EducationPage(
        id: "series-sourcing",
        title: String(localized: "education.series.sourcing.page.title",
                      defaultValue: "Archival Sourcing"),
        subtitle: String(localized: "education.series.sourcing.page.subtitle",
                         defaultValue: "Where the series drew its documents from, over time"),
        category: .aboutTheSeries,
        sections: [],
        dashboard: .seriesSourcing
    )
}

// MARK: - Series Administrations dashboard page (Analytics SA-2b)

private extension EducationPage {
    /// The live "About the Series" page that renders the Administration Profiles
    /// dashboard (`EducationDashboard.administrationProfiles`) in place of prose.
    /// Its `sections` are empty by design — the renderers show the dashboard, not
    /// sections — so it contributes no prose paragraph or Markdown link to scan.
    /// Placed fourth under "About the Series", after `seriesSourcing`.
    /// Unconditional (shipped in debug and release).
    static let seriesAdministrations = EducationPage(
        id: "series-administrations",
        title: String(localized: "education.series.administrations.page.title",
                      defaultValue: "Administration Profiles"),
        subtitle: String(localized: "education.series.administrations.page.subtitle",
                         defaultValue: "How the series' coverage is distributed across presidencies"),
        category: .aboutTheSeries,
        sections: [],
        dashboard: .administrationProfiles
    )
}
