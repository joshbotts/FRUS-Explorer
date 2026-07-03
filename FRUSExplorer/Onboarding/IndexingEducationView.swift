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
/// Five pages introduce FRUS and the app, then transition to
/// `IndexingSetupWizardView` so researchers can configure their context
/// before the first documents finish indexing.
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
/// (see `Docs/2026-06-06 EditableContent.md`). The view can also be opened
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

                // Sections
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(page.sections) { section in
                        MacSectionView(section: section)
                    }
                }
                .padding(28)
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
                    iOSPageView(page: page)
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
enum EducationCategory: String {
    /// Background on the FRUS series and how to read its documents.
    case aboutFRUS
    /// Catalog of the app's features and how to reach them.
    case usingTheApp

    /// Localised sidebar section header.
    var title: String {
        switch self {
        case .aboutFRUS:   return String(localized: "education.category.about",    defaultValue: "About FRUS")
        case .usingTheApp: return String(localized: "education.category.features", defaultValue: "Using the app")
        }
    }
}

struct EducationPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    /// Sidebar grouping on macOS. Defaults to `.aboutFRUS` so the existing corpus-background
    /// pages need no change.
    let category: EducationCategory
    let sections: [EducationSection]

    init(
        id: String,
        title: String,
        subtitle: String?,
        category: EducationCategory = .aboutFRUS,
        sections: [EducationSection]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.sections = sections
    }

    static let all: [EducationPage] = [page1, page2, page3, page4, page5, page6, page7]
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
                    "FRUS volumes are compiled and edited by professional historians in the Office of the Historian at the Department of State. Historians in the compilation and review team identify the most important documents, provide context through editorial notes and introductions, and review draft volume manuscripts to ensure they provide \"thorough, accurate, and reliable\" coverage of the assigned topic(s). Historians in the declassification, publishing, and digital initiatives team coordinate the complex and thorough interagency declassification review required before release and then the detailed preparation of the manuscript required for publication. An Advisory Committee on Historical Diplomatic Documentation comprised of representatives of major scholarly organizations and experts chosen by the Department of State oversee this production process to validate the historical objectivity of the series."
                ]
            ),
            EducationSection(
                id: "sources",
                heading: "Breadth of Sources",
                paragraphs: [
                    "FRUS historians draw on records from the White House and National Security Council at Presidential Libraries as well as records from the Departments of State and Defense, the CIA, and other agencies, both at the National Archives and directly at those agencies. When needed, they also seek access to the private papers of key policymakers.",
                    "Deletions required for national security must be acknowledged in the published text; major facts leading to policy decisions cannot be omitted."
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
                    "The series began during the Civil War as a compilation of official diplomatic correspondence — despatches from diplomatic posts, instructions to U.S. ministers overseas, and notes to and from foreign governments. The volumes documented the operations of the State Department. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Because the volumes were produced by the same clerks who administered the Department's day-to-day business, principles of selection and editing standards were inconsistent and reflected operational rather than historical purposes."
                ]
            ),
            EducationSection(
                id: "professionalization",
                heading: "Professionalization in the Interwar Era (1924-1945)",
                paragraphs: [
                    "In the 1920s, the Department of State began recruiting professionally-trained historians to undertake the increasingly complex editorial work of producing FRUS. Because budget constraints and operational considerations involved in waging World War I had imposed delays in publication during the previous two decades, those historians had an opportunity to select and edit the historical record of U.S. foreign policy with greater perspective and depth than their predecessors. They established formal editorial principles for FRUS that endured."
                ]
            ),
            EducationSection(
                id: "national-security",
                heading: "The National Security Turn (1945–1970s)",
                paragraphs: [
                    "The Cold War transformed FRUS. As more and more decision-makers outside the Department of State left their imprint on foreign policy and diplomacy, FRUS historians increasingly needed to complement State Department records with documents drawn from other agencies' files. As the United States became more engaged in more places around the world, the perceived stakes of disclosure grew. Volumes in this period often reflect what could be declassified rather than what historians judged most important. In the 1957, the Department established a Historical Advisory Committee of outside academic experts to provide editorial advice about how to balance timeliness and comprehensiveness and to vouch for the integrity of published volumes."
                ]
            ),
            EducationSection(
                id: "crisis",
                heading: "Crisis and Reform (1978–1991)",
                paragraphs: [
                    "By the 1980s, the gap between what FRUS had always claimed to be and what it could actually deliver grew painfully apparent. Historians inside the Office of the Historian fought — sometimes bitterly — for genuine access to CIA, NSC, and White House records. Academic historians appointed to the Department-chartered Historical Advisory Committee struggled against increasingly restrictive security restrictions to understand whether declassification decisions across the government withheld information essential to the integrity of the historical record from publishable volumes. In 1989 and 1990, criticism of omissions of any hint of a major historical covert action from a volume documenting U.S. policy toward Iran in the early 1950s coupled with the fallout from the Department's deteriorating relationship with the Historical Advisory Committee to create a crisis for the series.",
                    "In 1991, Congress intervened by establishing statutory mandates for the mission of the series, the obligations of U.S. Government agencies to provide access to their historical records to the historians producing FRUS, and an advisory committee of academic historians to provide oversight to validate the historical integrity of the series."
                ]
            ),
            EducationSection(
                id: "contemporary",
                heading: "The Contemporary Series (1991–Present)",
                paragraphs: [
                    "Post-1991 volumes reflect a substantially different editorial philosophy: broader sourcing, fuller coverage of intelligence activities, and more detailed acknowledgment of omissions. Even as some volumes are delayed by interagency declassification disagreements, the 30-year rule creates a rolling horizon; volumes covering the Reagan administration are now publishing, with the Bush 41 and Clinton eras in active production."
                ]
            ),
            EducationSection(
                id: "digital",
                heading: "The Digital Transition",
                paragraphs: [
                    "The shift to XML-encoded TEI files and digital publication in the 21st century has transformed how FRUS can be read and searched. All 552 volumes are now available as structured digital texts — the foundation for everything this app does. The TEI format preserves document structure (headings, datelines, footnotes, person references) in a form that makes programmatic analysis possible in ways printed volumes never allowed."
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
                    "Every FRUS document is an edited representation of the original record in an archive somewhere. Understanding editorial annotation will help you make full use of FRUS."
                ]
            ),
            EducationSection(
                id: "types",
                heading: "Primary Documents, Editorial Notes, and Front Matter",
                paragraphs: [
                    "FRUS is a documentary history, which means it primarily tells the story of U.S. foreign policy directly through actual historical documents. However, the historians who compiled the volumes also provided editorial annotation to convey more information from the archives.",
                    "Primary documents are the actual historical records — cables, memoranda, meeting notes, intelligence assessments, letters. These are reproduced (sometimes with excisions) from government files. Each document has a source note that identifies where the original was found. Many documents also contain footnotes providing information about the surrounding historical context or even specific archival citations to other referenced documents, meetings, or events.",
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
                    "One way this app helps researchers is by connecting archival citations detected in source notes directly to NARA's finding aids — so you can navigate from a FRUS document directly to the archive where the original record lives. This makes it easier than ever to follow the archival roadmap FRUS offers for deeper research."
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
                    "FRUS rewards researchers who read across documents, not just within them, and who squeeze valuable information about both historical and archival context from the editorial annotation added to documents. Here are strategies that experienced historians use."
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
                    "Search the full text of every downloaded and indexed volume at once. Results are ranked by relevance with English stemming, so searching \"negotiation\" also returns \"negotiate,\" \"negotiated,\" and \"negotiations.\" The search box understands Google-style syntax: wrap words in quotes for an exact phrase (\"missile crisis\"), use OR for either term, a leading minus to exclude a word (-Cuba), and a trailing asterisk for prefix matching (negoti*).",
                    "Open the advanced filters to narrow by date range, document type, a person mentioned, and the search scope (document text, summaries, notes). You can also limit a search to specific volumes or whole subseries. Search only covers indexed volumes — download and index more to widen the corpus.",
                    "Find it on the Search tab (iOS) or the search window, ⌘F (Mac)."
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
                    "Find it in the Corpus Browser's People section."
                ]
            ),
            EducationSection(
                id: "citation-lookup",
                heading: "Find by Citation",
                systemImage: "text.magnifyingglass",
                paragraphs: [
                    "Have a FRUS citation from a footnote, a syllabus, or another book? Paste it into Find by Citation and the app resolves it straight to the document — no manual hunting through volumes and document numbers.",
                    "Find it in the Search screen's overflow (More) menu."
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
                    "A caution: FRUS volumes are selective, uneven proxies for the underlying archival record — treat term-frequency trends as a finding aid, not as direct evidence of what policymakers were discussing. Analytics runs entirely on your local index; no network connection is required.",
                    "The By-Year and By-Decade charts colour-code each period by its top source volumes; you can choose how many volumes get a distinct colour (per chart, or as a default in Display settings) before the rest fold into \u{201C}Other.\u{201D}",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Corpus Analytics window (Mac)."
                ]
            ),
            EducationSection(
                id: "word-cloud",
                heading: "Word Cloud",
                systemImage: WordCloudGlyph.symbol,
                paragraphs: [
                    "See the most frequent terms across any slice of the corpus — a single document, a volume or subseries, a collection, a tag, a saved search, a date range, or the whole corpus — with each word sized by how often it appears. Semantic lenses narrow the cloud to people, places, organizations, topics, actions, descriptors, concepts, or sentiment, all recognised on-device.",
                    "Tap any word to chart its frequency across the whole series in Corpus Analytics, hide words you don\u{2019}t want to see, or compare two scopes side by side; export the cloud as a PNG, PDF, or CSV. A date-range cloud and the Chronology browser hand off to each other — build a cloud from the dates you are viewing in Chronology, or jump from a date-range cloud back into Chronology for the same span. Tune the cloud\u{2019}s typeface and density in Settings.",
                    "Like Analytics, a word cloud reflects what FRUS editors chose to publish, not the full archival record — read it as a finding aid, not as direct evidence.",
                    "Find it from the Browse tab\u{2019}s Analysis Tools menu (iOS) or the Word Cloud window (Mac), plus the word-cloud buttons on documents, volumes, subseries, collections, tags, and saved searches."
                ]
            ),
            EducationSection(
                id: "cross-reference-graph",
                heading: "Cross-Reference Graph",
                systemImage: "point.3.connected.trianglepath.dotted",
                paragraphs: [
                    "Visualise the web of footnote cross-references the editors drew between documents and volumes. Choose how far to expand the graph — direct connections only, or one or two degrees of neighbors — to trace how a decision was informed by, or fed into, the surrounding record.",
                    "Find it from a document's toolbar (iOS) or the Graph window (Mac)."
                ]
            ),
            EducationSection(
                id: "source-explorer",
                heading: "Source Explorer & NARA Catalog",
                systemImage: "archivebox",
                paragraphs: [
                    "Open the Source Explorer from any document to read its source note broken into structured archival fields, and to follow detected citations into NARA's finding aids — the correct period-specific research page, relevant record groups, and related collections.",
                    "You can also select any text — a lot file number, a decimal file identifier, a collection name — and run a NARA Catalog Lookup directly: lot-file search, keyword search within a record group, or central-files period routing. Period routing needs no key; the other strategies use a free NARA Catalog API key you add in Settings.",
                    "From those same source notes, Archival Neighbors gathers other indexed documents drawn from the same archival source — the same lot file, central decimal file, record-group series, or presidential-library collection — so pieces of one file scattered across volumes come back together. Reach it from the Source Explorer, a document\u{2019}s row in a volume\u{2019}s sources list, a search result, or a node in the cross-reference graph.",
                    "A volume\u{2019}s front matter names the archival collections its editors drew on. In the volume\u{2019}s Sources section, each collection that resolves — a record group or a lot file — links straight to its record in the National Archives Catalog, and a major collection cited by more than one volume shows how many, opening the list of those volumes so you can follow a body of records across the series."
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
        subtitle: "Reading, annotating, organising, and exporting",
        category: .usingTheApp,
        sections: [
            EducationSection(
                id: "document",
                heading: "The Document Reader",
                systemImage: "doc.richtext",
                paragraphs: [
                    "Every document is rendered from its original TEI-encoded XML, preserving the published structure: headings, datelines, footnote markers, tables, and emphasis. Footnote markers open inline; person names link to the volume's biographical glossary. Reader mode keeps the focus on the published text, while research mode brings your notes, tags, and AI summaries alongside it."
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
                    "Collections are curated sets you assemble for a purpose — a teaching reader, a briefing packet, a source dossier. The manager is where you shape the content: add documents from any volume, interleave your own section headings and rich-text prose (bold, italic, underline, colour), attach notes to a document, and inspect a document's notes, highlights, tags, summary, and archival source in place. Add Documents gathers documents without leaving the editor — search the index, browse a volume, paste citations or history.state.gov links (each line resolves to its document), or pull in everything carrying one of your tags. The composition lives on the collection itself — default body depth (full text, an AI summary, or a compact index), footnotes, table-of-contents style, and whether to include highlights, notes, or a word cloud — and any single document or whole section can override the body depth. Sections nest up to three levels — indent or outdent a heading from its context menu, drag a heading to move its whole section as a block, and give the collection a subtitle, author line, rich-text introduction, and colophon for a true title page. Excerpt quotations freeze a highlighted or selected passage into the collection as a styled block quote with its citation, and each document's inspector is a per-document control surface — a headnote abstract above the body, per-document overrides for highlights, notes, source note, footnotes, and summary prompt, and a \u{201C}See also\u{201D} line citing cross-referenced documents inside the collection. Generated apparatus blocks — a bibliography, a chronology, a sources-and-archives list, a persons index, and a thematic index — are computed from the collection\u{2019}s documents at every export and in the preview, placeable anywhere like any other row. A live preview shows the collection exactly as its HTML export while you compose — side-by-side on iPad and Mac, a Preview toggle on iPhone.",
                    "Export is simply how you share it. Render the collection — section headings and prose included — as a PDF, HTML file, or Word document; produce a BibTeX or RIS file for a reference manager; or save a native \u{201C}.fruscollection\u{201D} file: an editable copy a colleague opens right back into their own FRUS Explorer, where the documents travel as references they can download. Import one with Import Collection or by opening the file. A smart collection driven by a saved search can be frozen into an editable copy with Create Static Snapshot.",
                    "Find it on the Collections tab (iOS) or the Collections window, ⇧⌘K (Mac)."
                ]
            ),
            EducationSection(
                id: "citations",
                heading: "Citations & Bibliographic Export",
                systemImage: "quote.bubble",
                paragraphs: [
                    "Every document carries a correctly formatted citation in the history.state.gov style, ready to copy. You can also export citations — individually or for a whole collection — as BibTeX or RIS for your reference manager (RIS imports into Zotero on the desktop via File \u{2192} Import).",
                    "Sending to Zotero is one action: connect a Zotero account (Settings \u{2192} Zotero) and Send to Zotero Library pushes a document — or an entire collection — straight into your library over the web, carrying your tags and research notes; without an account it falls back to an RIS file for desktop import."
                ]
            ),
            EducationSection(
                id: "ai",
                heading: "AI Summaries",
                systemImage: "sparkles",
                paragraphs: [
                    "Where Apple Intelligence is available, generate on-device summaries of individual documents using prompt templates — standard ones for different research purposes (analytical, chronological, actor-focused) or your own. Summaries are stored locally and can be exported alongside documents in collections; every summary in an exported collection is labeled as AI-generated content attributed to Apple Intelligence. Treat them as orientation only: always read the primary document yourself for your actual research.",
                    "To summarize a large body of material at once, the background summarizer works through an entire subseries, volume, tag, saved search, or date range unattended, reporting progress as it goes — so a stack of summaries is ready when you return."
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
        ]
    )
}
