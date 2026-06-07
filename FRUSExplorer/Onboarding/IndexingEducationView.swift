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
struct IndexingEducationView: View {

    /// Distinguishes the two contexts in which these pages can appear, since
    /// the final page's call-to-action differs between them.
    enum PresentationContext {
        /// Shown while the first index builds, immediately followed by
        /// `IndexingSetupWizardView`. The final page invites the user to
        /// continue into that wizard.
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
    private var macBody: some View {
        HStack(spacing: 0) {

            // ── Left sidebar: chapter list ─────────────────────────────────
            VStack(spacing: 0) {
                List(selection: Binding(
                    get: { pageIndex },
                    set: { pageIndex = $0 }
                )) {
                    ForEach(Array(EducationPage.all.enumerated()), id: \.offset) { idx, page in
                        MacSidebarRow(number: idx + 1, title: page.title, isSelected: idx == pageIndex)
                            .tag(idx)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 190)
            }

            Divider()

            // ── Right content column ───────────────────────────────────────
            VStack(spacing: 0) {
                macContentArea
                Divider()
                macNavigationBar
            }
        }
        .frame(minWidth: 760, minHeight: 520)
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

    private var macNavigationBar: some View {
        HStack {
            // Back
            if pageIndex > 0 {
                Button(String(localized: "education.nav.back", defaultValue: "Back")) {
                    withAnimation(.easeInOut(duration: 0.15)) { pageIndex -= 1 }
                }
                .keyboardShortcut(.cancelAction)
            } else {
                // Invisible spacer to keep layout stable
                Button("Back") {}.opacity(0)
            }

            Spacer()

            // Page indicator
            Text("\(pageIndex + 1) of \(EducationPage.all.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            // Next / Complete
            if pageIndex < EducationPage.all.count - 1 {
                Button(String(localized: "education.nav.next", defaultValue: "Next")) {
                    withAnimation(.easeInOut(duration: 0.15)) { pageIndex += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Button(finalPageButtonLabel) {
                    onComplete()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
            return String(localized: "education.nav.setup",
                          defaultValue: "Set Up My Research →")
        case .standalone:
            return String(localized: "education.nav.done",
                          defaultValue: "Done")
        }
    }
}

// MARK: - macOS sidebar row

#if os(macOS)
private struct MacSidebarRow: View {
    let number: Int
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 16, alignment: .trailing)
                .padding(.top, 1)
            Text(title)
                .font(.system(size: 13))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - macOS section view

private struct MacSectionView: View {

    let section: EducationSection

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let heading = section.heading {
                Text(heading)
                    .font(.headline)
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
                Text(heading).font(.headline)
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

struct EducationPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let sections: [EducationSection]

    static let all: [EducationPage] = [page1, page2, page3, page4, page5]
}

struct EducationSection: Identifiable {
    let id: String
    let heading: String?
    let paragraphs: [String]
    let bullets: [String]?

    init(id: String = UUID().uuidString,
         heading: String? = nil,
         paragraphs: [String] = [],
         bullets: [String]? = nil) {
        self.id = id
        self.heading = heading
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
    static let page5 = EducationPage(
        id: "app-features",
        title: "What This App Can Do",
        subtitle: "Key features and how to use them",
        sections: [
            EducationSection(
                id: "search",
                heading: "Full-Text Search",
                paragraphs: [
                    "Search the full text of all downloaded and indexed volumes simultaneously. Results are ranked by relevance with English stemming — searching \"negotiation\" will also return documents containing \"negotiate,\" \"negotiated,\" and \"negotiations.\" Narrow results further by date range and other filters. Note that search only knows about documents from indexed volumes. Downloading and indexing more volumes expands your search corpus."
                ]
            ),
            EducationSection(
                id: "document",
                heading: "Document View",
                paragraphs: [
                    "Each document is rendered from its original TEI-encoded XML, preserving structure: headings, datelines, footnote markers, tables, and emphasis as they appear in the published volume. Footnote markers open inline popups; person names are highlighted and link to the volume's biographical glossary. You can create color-coded text highlights that persist across sessions, attach research notes to specific passages or the entire document, and apply user tags to label documents according to your own needs. Reader mode keeps user focus on the published document while research mode makes notes, tags, and AI summaries immediately accessible alongside the document."
                ]
            ),
            EducationSection(
                id: "cross-reference-graph",
                heading: "Cross-Reference Graphs",
                paragraphs: [
                    "The Cross-Reference Graph allows users to visually investigate relationships among documents and volumes that were explicitly captured explicit as footnote cross-references. Users can choose from three scopes for the graph: direct connections only or add one or two degree neighbors as well."
                ]
            ),
            EducationSection(
                id: "source-explorer",
                heading: "Source Explorer",
                paragraphs: [
                    "The Source Explorer, accessible from any document, tries to detect archival citations in source notes and connects them to NARA's finding aids — routing you to the correct period-specific research page, filing manual PDFs, and related collections. When the index is complete, this will also surface other documents that came from the same archival collection."
                ]
            ),
            EducationSection(
                id: "nara-lookup",
                heading: "NARA Catalog Lookup",
                paragraphs: [
                    "Select any text in a document — a lot file number, a decimal file identifier, a collection name — and use the NARA Catalog Lookup tool (in the toolbar's More menu, or the research strip on Mac) to query the NARA Catalog directly. Choose from several strategies: lot file search, keyword search within a specific record group, or central-files period routing. No API key is required for period routing; other strategies require a free NARA Catalog API key, available from Settings."
                ]
            ),
            EducationSection(
                id: "collections",
                heading: "Collections",
                paragraphs: [
                    "Collections are curated document sets you assemble for a purpose. Add documents from any volume, attach research notes to individual entries, and export the finished collection as a PDF, HTML file, or Word document. Export options include body depth (full text, AI summary only, or index only), footnote inclusion, highlight annotation, and whether to include research notes. Collections are a great way to build a teaching reader, assemble background materials for a policy brief, or produce a document dossier."
                ]
            ),
            EducationSection(
                id: "research-tools",
                heading: "Research Notes, Tags, and Projects",
                paragraphs: [
                    "Annotate documents with free-text research notes that are stored in iCloud and synced across your devices. Apply user tags to group documents by theme, actor, or analytical category. Organize everything under named research projects — a project is an activity lens that tags your notes, collections, and reading history so you can keep multiple research threads separate. All annotation data is yours and travels with your account."
                ]
            ),
            EducationSection(
                id: "ai",
                heading: "AI Summaries",
                paragraphs: [
                    "When Apple Intelligence is available on your device, you can generate AI summaries of individual documents using customizable prompt templates. Summaries are stored locally and can be exported alongside documents in collections. The app provides standard prompt templates for different research purposes (analytical, chronological, actors-focused) and lets you create your own. Summaries are tools for orientation — always read the primary document yourself for your actual research."
                ]
            ),
            EducationSection(
                id: "analytics",
                heading: "Corpus Analytics",
                paragraphs: [
                    "The Analytics window charts how often a term or phrase appears across the indexed corpus over time, broken down by decade, subseries, year, month, or even day. Use it to identify when a topic first appears in FRUS, how coverage of a country or issue changed across the series, or which volumes are most relevant to a specific keyword. Note that FRUS volumes are incomplete and inconsistent proxies for the underlying archival record - do not treat FRUS ngrams as direct evidence of the evolving interests and/or discourse of contemporaneous policymakers and diplomats. Analytics operates entirely on the local index — no network connection required."
                ]
            ),
        ]
    )
}
