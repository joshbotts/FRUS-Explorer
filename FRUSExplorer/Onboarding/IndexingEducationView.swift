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
///   1.20 — Owner content revision (build 43): pages 5–7 rewritten as CONTRACTS — what a reader
///          will be able to do, organized by research task, never where the buttons live; the
///          how moved to the User Manual, which each page's closing section points at, so the
///          per-feature "Find it …" convention is retired on these pages. Page 3 drops the
///          broken-references section; page 4 drops "Follow the Person", gains "Think of FRUS
///          as a Map of the Archives", and its subtitle says "volumes" rather than "archive".
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

    /// The bundled manifest's volume count, for the `{{volumes}}` token in the prose (R-3).
    @Environment(AppState.self) private var appState
    private var volumeCount: Int { appState.manifestStore.bundledEntries.count }

    /// Replaces `{{volumes}}` with the live count, and nothing else.
    ///
    /// The Research Guide's prose is a static table so the owner can edit it as text
    /// (`Docs/EditableContent.md` pins it by page and line). A count that is a fact about the
    /// bundle, not about the prose, cannot live in that table as a literal — `552` shipped there
    /// and became false on the day a 553rd volume did. One token, one substitution; anything
    /// more would make the table a template language.
    ///
    /// - Parameters:
    ///   - paragraph: a prose paragraph, possibly carrying the token.
    ///   - volumeCount: the count to print.
    /// - Returns: the paragraph with the token replaced.
    static func substituted(_ paragraph: String, volumeCount: Int) -> String {
        paragraph.replacingOccurrences(of: "{{volumes}}", with: volumeCount.formatted())
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
    /// The bundled manifest's volume count, for the `{{volumes}}` token (R-3). This struct is
    /// macOS-only, so the iOS build never compiled its render twin — the Mac build is the only
    /// thing that reaches this line, which is why it is the twin that was missed.
    @Environment(AppState.self) private var appState
    private var volumeCount: Int { appState.manifestStore.bundledEntries.count }

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
                Text(AttributedString(markdownBody: IndexingEducationView.substituted(para, volumeCount: volumeCount)))
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
    /// The bundled manifest's volume count, for the `{{volumes}}` token (R-3) — the same
    /// environment the outer view reads; this section view is a separate struct, so it must
    /// read it itself.
    @Environment(AppState.self) private var appState
    private var volumeCount: Int { appState.manifestStore.bundledEntries.count }

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
                Text(AttributedString(markdownBody: IndexingEducationView.substituted(para, volumeCount: volumeCount)))
                    .font(.body).fixedSize(horizontal: false, vertical: true)
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
///   1.7 — Session 2026-08-23: the Cross-Reference Graph section names the teal archival
///         layer (#837/#834) — the guide described the graph as documents-only after the
///         canvas had stopped being that
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
    /// Prose paragraphs. May carry `{{volumes}}`, which the renderer replaces with the bundled
    /// manifest's volume count — see `IndexingEducationView.substituted(_:volumeCount:)`.
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
                    "The series must constitute “a thorough, accurate, and reliable documentary record of major United States foreign policy decisions and significant United States diplomatic activity. Volumes of this publication shall include all records needed to provide a comprehensive documentation of the major foreign policy decisions and actions of the United States Government, including the facts which contributed to the formulation of policies and records providing supporting and alternative views to the policy position ultimately adopted”",
                    "Volumes must be published within 30 years of the events they document",
                    "Government departments must grant historians full access to pertinent records at 20 years",
                    "An Advisory Committee on Historical Diplomatic Documentation comprised of representatives of major scholarly organizations and experts chosen by the Department of State must oversee the production and declassification process to validate the historical objectivity of the series"
                ]
            ),
            EducationSection(
                id: "ooh",
                heading: "Prepared by the Department of State's Office of the Historian",
                paragraphs: [
                    "FRUS volumes are compiled and edited by professional historians in the Office of the Historian at the Department of State. Historians in the compilation and review team identify the most important documents, provide context through editorial notes and annotations, and review draft volume manuscripts to ensure they provide “thorough, accurate, and reliable” coverage of the assigned topic(s). Historians in the declassification, publishing, and digital initiatives team coordinate the complex and thorough interagency declassification review required before release and then the detailed preparation of the manuscript required for publication."
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
                    "FRUS volumes produced today cover U.S. bilateral and regional relations across the globe, including U.S. policymakers’ responses to unfolding crises; their engagement with global issues like human rights, terrorism, narcotics, health, and the environment; and thematic topics including national security policy, foreign economic policy, and foreign affairs organization and management. The series currently spans from 1861 through the early 1990s, with volumes covering the Clinton administration still in production."
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
                    "At its birth, FRUS was an instrument of public affairs and congressional relations. The series began during the Civil War as a compilation of official diplomatic correspondence — despatches from diplomatic posts, instructions to U.S. ministers overseas, and notes to and from foreign governments. The volumes documented the operations of the State Department. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Because the volumes were produced by the same clerks who administered the Department’s day-to-day business, principles of selection and editing standards reflected operational rather than historical purposes. By the early 20th century, the series had evolved to became a valuable knowledge management tool by providing ready access to key policy and precedent references for officials within the Department and its overseas posts and growing stakeholder constituencies in civil society."
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
                    "The Cold War transformed FRUS. As more decision-makers outside the Department of State left their imprint on foreign policy and diplomacy, FRUS historians increasingly needed to complement State Department records with documents drawn from other agencies’ files - especially presidential records. At the same time, United States expanded and intensified its engagement around the world. The perceived stakes of disclosure in FRUS grew. In the 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes. Over the following decades, FRUS historians and advisory committee experts maintained that balance and the series served as the Department of State’s transparency engine. "
                ]
            ),
            EducationSection(
                id: "crisis",
                heading: "Crisis and Reform (1978–1991)",
                paragraphs: [
                    "By the 1980s, the gap between what FRUS had always claimed to be and what it could actually deliver grew painfully apparent. Historians inside the Office of the Historian struggled to achieve direct access to key CIA records. Academic historians appointed to the Department-chartered Historical Advisory Committee faced tightening security restrictions that made it harder to judge whether information withheld during the declassification process was marginal or essential to the historical integrity of publishable volumes. In 1989 and 1990, academic criticism of a volume documenting U.S. policy toward Iran in the early 1950s without any references to widely-known covert action attracted congressional scrutiny of the State Department’s management of the series and its relationship with the advisory committee. In 1991, Congress intervened by establishing statutory mandates for long-standing norms: the mission of the series, the obligations of U.S. Government agencies to provide access to their historical records to the historians producing FRUS, and an advisory committee of academic historians to provide oversight to validate the historical integrity of the series."
                ]
            ),
            EducationSection(
                id: "contemporary",
                heading: "The Contemporary Series (1991–Present)",
                paragraphs: [
                    "Post-1991 volumes reflect the statute’s empowerment of FRUS historians with broader sourcing, fuller coverage of intelligence activities, and more detailed acknowledgment of omissions. Even as some volumes are delayed by interagency declassification disagreements, the 30-year rule creates a rolling horizon; volumes covering the Reagan administration are now publishing, with the Bush 41 and Clinton eras in active production."
                ]
            ),
            EducationSection(
                id: "digital",
                heading: "The Digital Transition",
                paragraphs: [
                    "The Office of the Historian’s shift to XML-encoded TEI files and digital publication in the 21st century has transformed how FRUS can be read and searched. All {{volumes}} volumes are now available as structured digital texts — the foundation for everything this app does. The TEI format preserves document structure (headings, datelines, footnotes, person references) in a form that makes programmatic analysis possible in ways printed volumes never allowed."
                ]
            ),
            EducationSection(
                id: "frus-history",
                paragraphs: [
                    "To dive deeper into the history of the series, see the Office of the Historian’s [official history](https://history.state.gov/historicaldocuments/frus-history) of FRUS."
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
                    "Many volumes also contain editorial notes written by Office of the Historian historians. They appear as numbered entries in the document sequence and serve several purposes: summarizing developments the editors judged too voluminous or sensitive to reproduce in full, explaining gaps in the record, providing context for surrounding documents, and noting where fuller documentation exists. An editorial note that says “On [date], the NSC met to discuss…” is telling you something happened that isn’t fully reproduced here. Editorial notes provide additional archival citations to unpublished documents.",
                    "Volume front matter has evolved over time. Recent volumes include valuable information about the editor’s research methodology and a listing the archival sources they consulted as they selected documents for inclusion. They also contain annotated lists of people who generated, received, or were mentioned in the documents and terms and abbreviations used in the documents."
                ]
            ),
            EducationSection(
                id: "source-note",
                heading: "Reading a Source Note",
                paragraphs: [
                    "Document source notes identify the archival provenance of the records published in FRUS. A source note for a document in the Reagan subseries might read:",
                    "“Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Secret; Nodis.”",
                    "This tells you: the original record was collected from the National Archives; it’s in Record Group 59 (State Department records); it’s part of the Central Foreign Policy File series; the reel identifier is P840114–1808; and it was classified Secret with a special handling caption.",
                    "One way this app helps researchers is by connecting archival citations detected in source notes directly to NARA’s finding aids — so you can navigate from a FRUS document directly to the archive where the original record lives. Source notes are extracted for every era of the series, including the modern volumes whose notes are embedded in the document heading. This makes it easier than ever to follow the archival roadmap FRUS offers for deeper research.",
                    "When a source note records classification markings — “Secret; Nodis”, or explicitly “No classification marking” — the app separates them from the archival citation and shows them as a small chip beside the source note in the reading view, in Source Explorer, and on search results. The markings describe how the original record was handled at the time; the published text has been declassified.",
                    "The app also ships a corpus-wide authority of the archival collections FRUS cites: from Source Explorer you can open any matched collection to see its variant citation forms, its National Archives catalog record, every volume across the series that cites it, and how many documents in your own indexed volumes came from it."
                ]
            ),
            EducationSection(
                id: "classifications",
                heading: "Excisions",
                paragraphs: [
                    "Most FRUS documents are published in full, but there are many that were published with excisions. Some of these excisions were editorial - the historians who compiled the volume judged that the excised material wasn’t significant enough to warrant inclusion. Other excisions were made for policy considerations - government officials judged that information could not be released without unacceptable risks to U.S. interests or security.",
                    "Before the 1920s, FRUS editors did not annotate excisions. Beginning in the 1920s, FRUS historians added ellipses (...) to indicate that material was omitted, but did not describe how much information was withheld or explain whether an excision was editorial in nature or an unfavorable declassification decision. The 1991 statutory mandate required more detailed editorial accounting for excised material, giving researchers a greater sense of how what is published compares to what had to be withheld."
                ]
            ),
            EducationSection(
                id: "omissions",
                heading: "What FRUS Leaves Out",
                paragraphs: [
                    "FRUS publishes thousands of documents for every administration’s foreign policy, but it is just the tip of the iceberg for the entire historical record. Early volumes documented the implementation of foreign policy in the diplomacy conducted by the Department of State, but not the deliberative processes that set the course for U.S. foreign policy in Washington. Later volumes focused more and more on filling this gap by editorial prioritization of the decision-making process and inclusion of more and more records from beyond the State Department. This reversal of editorial focus means that the vast majority of diplomatic records that illustrate how foreign policy was implemented at U.S. embassies throughout the world are underrepresented in recent volumes compared to earlier ones."
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
        subtitle: "Strategies for getting the most from the volumes",
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
                    "Every FRUS volume opens with a substantial editorial introduction that explains the volume’s scope, the sources available (and unavailable), major gaps in the record, and key themes. Reading this Front Matter takes minutes but saves hours of confusion."
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
                    "When an editorial note summarizes a meeting or document rather than reproducing it, that’s a research signal, not a dead end. The note includes archival citations to the underlying documentation. You can use the document-level Source Explorer or the free-text NARA Lookup tool to find the relevant finding aids and track down the relevant original records at NARA."
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
                id: "archival-road-map",
                heading: "Think of FRUS as a Map of the Archives",
                paragraphs: [
                    "Recent FRUS volumes can serve as a map of U.S. government agency archives in three ways. First, it publishes transcriptions of the most critical historical records that document the foreign policy decision-making process and key diplomatic meetings, making them directly available to researchers. Second, the source notes for the documents selected for publication tell researchers the archival collections they came from, pointing them toward other useful files. Third, the note on sources in volume front matter identifies the broad range of archival repositories and collections that FRUS historians consulted to identify candidate documents for selection and publication. The most sophisticated users of FRUS rely on the series not only for the records it delivers directly, but also for the documentary trail it offers to a wider and richer range of U.S. Government sources."
                ]
            ),
            EducationSection(
                id: "omissions",
                heading: "Don't Forget What You're Not Reading",
                paragraphs: [
                    "FRUS tells the U.S. side of the history of foreign relations. The counterpart cable from a foreign ministry, the intelligence report shaping the other side’s expectations and strategies, the domestic political pressures driving a foreign leader — these are absent. FRUS is indispensable for illuminating the thinking and actions of U.S. policymakers. As valuable as that often is, international history is an interactive story that requires understanding events from multiple perspectives to truly master. For many types of questions, researchers should treat FRUS as an entry point to a historical or policy question, not its answer."
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
        title: "Finding What You Need in FRUS Explorer",
        subtitle: "What you can start from, and what you can narrow to",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "starting-points",
                heading: "Start From Whatever You Have",
                paragraphs: [
                    "FRUS Explorer is designed to help you find what you need in the series, regardless of whether your starting point is a natural language question, a phrase you half-remember, a citation that caught your eye in someone’s footnote, a name that keeps appearing, a fateful date, a broad subject, or one good document. Each of those leads somewhere in this app. The full text of every volume you have downloaded and indexed is searchable at once. A citation resolves to the document it names. Many people can be followed through everything that mentions them. Any span of days can be laid out in order, as they unfolded. The topic index reaches subjects spread too thinly to find easily any other way. And one document you trust can lead you to the documents most connected to it — by shared archival file, citation, date, the editors’ own arrangement, shared people and topics, or, if you choose to turn it on, an AI model’s reading of the entire series for meaning."
                ]
            ),
            EducationSection(
                id: "narrowing",
                heading: "Narrow Without Losing Count",
                paragraphs: [
                    "Whatever a search returns, you can see its shape before you read a page of it: how the matches spread across years, volumes, people, document types, archival provenance and subjects. Most of those become a filter with one tap, and the subjects facet narrows a result set to a single topic area; archival provenance is the exception — it is descriptive only, because the search has no provenance filter to narrow to, and the panel says so where it is shown. When a set of volumes is the thing you keep coming back to — a crisis, a region, an administration — you can name it once and reuse it everywhere the series can be sliced. When the thing you care about is covered in a particular set of documents, you can freeze them into a working corpus and run every later search inside it. The app keeps track of these scopes so you can replicate and document your research method."
                ]
            ),
            EducationSection(
                id: "honest-arithmetic",
                heading: "Search That Shows Its Arithmetic",
                paragraphs: [
                    "The app treats counts against the series as a whole as evidence, and holds itself to that standard. The Query Inspector shows how the app translated what you typed into the keyword search box into the query that actually ran under the hood. This can be especially important when your results are surprising. For example, an unexpectedly large count may be related to how the app sweeps variants of your terms into searches by default. Capped results are reported as floors, never as totals, and the app offers tools to visualize matches it cannot list. And wherever a figure could describe either the whole series or only your indexed volumes, the app says which one it is counting."
                ]
            ),
            EducationSection(
                id: "whole-series",
                heading: "The Whole Series, Not Just Your Library",
                paragraphs: [
                    "Finding does not wait for downloading. Semantic similarity, subjects, people, series-wide figures, and every volume’s place in the corpus are all visible before you add any volume to your device. Discovery can run ahead of your library and tell you which volumes are worth adding to it. What needs the text itself — full-text search, reading documents, analysis of the words — works over what you have indexed, and the app is plain about that boundary rather than letting a small library masquerade as the series."
                ]
            ),
            EducationSection(
                id: "manual",
                heading: "Where the Controls Are",
                paragraphs: [
                    "To delve into the details about search screens, filters, and syntax, visit the User Manual — linked from the About screen. It will walk you through how the app delivers these capabilities."
                ]
            ),
        ]
    )

    // MARK: Page 6 — Seeing the bigger picture

    static let page6 = EducationPage(
        id: "corpus-analysis",
        title: "Seeing the Bigger Picture in FRUS Explorer",
        subtitle: "Questions you can put to the series as a whole",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "over-time",
                heading: "Change Over Time",
                paragraphs: [
                    "You can watch the record move. Any term or phrase can be charted across the series’ thirteen decades to see when it enters the record, when it surges, and which volumes carry it — as raw counts, or as a share of each period’s documents so a term does not look like it is surging just because the series grew. Any stretch of days can be reconstructed in sequence. And any set of documents you assemble — a search’s results, a collection — can be read as a timeline, so its gaps and concentrations show at a glance."
                ]
            ),
            EducationSection(
                id: "language",
                heading: "The Language Itself",
                paragraphs: [
                    "You can ask what any slice of the corpus sounds like — a document, a volume, a decade, a working corpus — and get more than a list of frequent words: the words most distinctive of that slice compared with the whole series, what other terms occur frequently with your own search term (its collocates), and every occurrence of a term lined up as a concordance, so a page of hits can be sorted by the term’s immediate context and not just skimmed as a list. A semantic map places every document in the series on one screen beside others that an AI model assessed as similar, whether or not they share a volume, a date, or a citation."
                ]
            ),
            EducationSection(
                id: "people",
                heading: "The People",
                paragraphs: [
                    "You can ask who the published record foregrounds: the most-mentioned figures of an era, one person’s presence traced year by year, two careers compared, pairs tracked together, and the network of who is named alongside whom. These readings reach the volumes whose editors tagged people during production — the more recent ones — and the app tells you so rather than letting an editorial gap read as a historical absence."
                ]
            ),
            EducationSection(
                id: "citation-web",
                heading: "The Web the Editors Drew",
                paragraphs: [
                    "FRUS editors stitched the series together with cross-references between printed documents and out to archival records. In FRUS Explorer, you can read that stitching at both scales: one document’s neighborhood as a graph — what informed it, what it fed into, including the archival material its footnotes cite but the series never printed — and the whole citation web as an aggregated network, with its most-cited landmarks and the volumes that lean on each other. These are measures of how the editors linked documents, not a ranking of historical importance."
                ]
            ),
            EducationSection(
                id: "archival-signal",
                heading: "Where the Documents Came From",
                paragraphs: [
                    "Every published document names the archival file its original was found in, and clustered across the series those source notes answer a question no volume states outright: which bodies of records each era’s editors actually worked in. Archival analytics offers source rankings, co-citation networks, and flows between archival units, era by era. Use this feature to see how FRUS highlights connections between discrete archival collections and repositories or scout out specific collections or central file classifications of interest from what FRUS prints from and about them."
                ]
            ),
            EducationSection(
                id: "finding-aid",
                heading: "Honest Evidence",
                paragraphs: [
                    "FRUS is a selective, evolving proxy for the archival record. To learn more about the app’s analytics features, see the User Manual — linked from the About screen — for the full tour."
                ]
            ),
        ]
    )

    // MARK: Page 7 — Working with documents

    static let page7 = EducationPage(
        id: "working-with-documents",
        title: "Working With Documents in FRUS Explorer",
        subtitle: "Reading, annotating, organizing, and exporting",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "reading",
                heading: "The Text, As Published",
                paragraphs: [
                    "The document you read is the document the volume printed: its structure, its datelines, its style, its footnotes in place, with the people it names linked to the volume’s own glossary. Reading stays clean until you ask for more — your notes, tags, and summaries sit in a rail you open when you want them and close when you don’t."
                ]
            ),
            EducationSection(
                id: "your-apparatus",
                heading: "Your Own Layer on the Record",
                paragraphs: [
                    "Everything you add — highlights, notes, tags, the projects that keep separate research threads distinct — is maintained as a distinct, private layer, kept apart from the published text and never blended into it. It follows you across your devices, and it stays private: the app shares nothing about your research with anyone, and everything you make can be exported so you can use it elsewhere."
                ]
            ),
            EducationSection(
                id: "outputs",
                heading: "From Reading List to Finished Output",
                paragraphs: [
                    "A set of documents can become a shaped thing: a teaching reader, a briefing packet, a source dossier — ordered, sectioned, curated in your own words, annotated, and exported in forms other people can actually use, from print-ready files to a working set that a colleague opens in their own FRUS Explorer. Every document carries a citation in the series’ own style, ready for your footnotes or your reference manager. And where on-device AI is available it can draft summaries for you that are always labeled as generated, never passed off as part of the record or as your own reading."
                ]
            ),
            EducationSection(
                id: "integrity",
                heading: "Claims That Survive Checking",
                paragraphs: [
                    "The app is built so that what you publish from it as a collection can be checked. Every quotation you freeze into a collection is re-verified against the text of the document it cites before export — presentation is forgiven, wording is not, and a paraphrase does not pass. Your searches can be exported as a method appendix: the query log records each query with its scope, its date, and how many volumes were indexed at the time. History isn’t science, but searches against a shared, trusted source like FRUS can and should provide reproducible results."
                ]
            ),
            EducationSection(
                id: "beyond",
                heading: "When the Trail Leaves the Series",
                paragraphs: [
                    "When you are ready to follow source notes or footnotes past the published series to the shelves at College Park or a presidential library, FRUS Explorer can help you plan research visits. By selecting documents, you can seed and triage a research plan and prepare for a visit. The app’s research trip packet resolves selected documents’ source notes and/or outward-pointing footnotes against National Archives data to flag access-restriction warnings for still-classified collections, help you draft advance inquiries to an archivist, and gather the collection-level information about records that NARA asks you to provide when you’re ready to request them."
                ]
            ),
            EducationSection(
                id: "manual",
                heading: "Where the Controls Are",
                paragraphs: [
                    "To learn more about what FRUS Explorer lets you do with documents, see the User Manual — linked from the About screen."
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
                         defaultValue: "How the series’ coverage is distributed across presidencies"),
        category: .aboutTheSeries,
        sections: [],
        dashboard: .administrationProfiles
    )
}
