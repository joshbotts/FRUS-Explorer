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
/// Four pages introduce FRUS and the app, then transition to
/// `IndexingSetupWizardView` so researchers can configure their context
/// before the first documents finish indexing.
///
/// ## Content status
/// All page text is AI-generated placeholder content, clearly labelled
/// at the top and bottom of each page, pending editorial review.
///
/// Version history:
///   1.0 — Session 155: initial implementation
struct IndexingEducationView: View {

    // MARK: - State

    @State private var pageIndex: Int = 0
    var onComplete: () -> Void = {}

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $pageIndex) {
                ForEach(Array(EducationPage.all.enumerated()), id: \.offset) { idx, page in
                    EducationPageView(page: page)
                        .tag(idx)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: pageIndex)

            // Navigation controls
            navigationBar
        }
        #if os(macOS)
        .frame(minWidth: 580, minHeight: 540)
        #endif
    }

    // MARK: - Navigation bar

    private var navigationBar: some View {
        VStack(spacing: 8) {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<EducationPage.all.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == pageIndex ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut, value: pageIndex)
                }
            }

            // Prev / Next
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
                    #if os(macOS)
                    .controlSize(.regular)
                    #endif
                } else {
                    Button(String(localized: "education.nav.setup",
                                  defaultValue: "Set Up My Research →")) {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    #if os(macOS)
                    .controlSize(.regular)
                    #endif
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(.bar)
    }
}

// MARK: - EducationPageView

/// A single page: placeholder watermark at top and bottom, scrollable content in between.
private struct EducationPageView: View {

    let page: EducationPage
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Top placeholder marker ─────────────────────────────────
                placeholderBanner

                // ── Page header ────────────────────────────────────────────
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

                // ── Page sections ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(page.sections) { section in
                        EducationSectionView(section: section, openURL: openURL)
                    }
                }
                .padding(24)

                // ── Bottom placeholder marker ──────────────────────────────
                placeholderBanner
                    .padding(.bottom, 12)
            }
        }
    }

    private var placeholderBanner: some View {
        Text(String(localized: "education.placeholder.label",
                    defaultValue: "AI Generated Placeholder"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.18))
    }
}

// MARK: - EducationSectionView

private struct EducationSectionView: View {

    let section: EducationSection
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let heading = section.heading {
                Text(heading)
                    .font(.headline)
            }
            ForEach(section.paragraphs, id: \.self) { para in
                Text(para)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let bullets = section.bullets {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(bullet).fixedSize(horizontal: false, vertical: true)
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

    static let all: [EducationPage] = [page1, page2, page3, page4]
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
                    "Foreign Relations of the United States — FRUS — is the official documentary historical record of major U.S. foreign policy decisions and significant diplomatic activity, published continuously by the Department of State since 1861. It is one of the longest-running publication programs of the U.S. government and the primary published source for the history of American diplomacy."
                ]
            ),
            EducationSection(
                id: "ooh",
                heading: "Prepared by the Office of the Historian",
                paragraphs: [
                    "FRUS volumes are compiled and edited by professional historians in the Office of the Historian, Bureau of Public Affairs, Department of State. Editors identify the most important documents, provide context through editorial notes and introductions, and coordinate the declassification review required before publication."
                ]
            ),
            EducationSection(
                id: "mandate",
                heading: "A Statutory Mandate, Not a Courtesy",
                paragraphs: [
                    "Since 1991, FRUS is required by federal statute (Public Law 102-138, codified at 22 U.S.C. § 4351 et seq., amended 2021). The law establishes three binding commitments:"
                ],
                bullets: [
                    "Volumes must be published within 30 years of the events they document",
                    "Government departments must grant historians full access to pertinent records at 20 years",
                    "The series must constitute a \"thorough, accurate, and reliable\" record — \"nothing should be omitted for the purposes of concealing a defect in policy\""
                ]
            ),
            EducationSection(
                id: "sources",
                heading: "Breadth of Sources",
                paragraphs: [
                    "FRUS draws on records from the White House, National Security Council, Departments of State and Defense, the CIA, and other agencies — as well as the private papers of individual policymakers. Deletions required for national security must be acknowledged in the published text; major facts leading to policy decisions cannot be omitted."
                ]
            ),
            EducationSection(
                id: "scope",
                heading: "Scope",
                paragraphs: [
                    "FRUS covers U.S. bilateral and regional relations across the globe, as well as global issues — terrorism, narcotics, arms control, international economics — and topics including national security policy and foreign policy organization. The series currently spans from 1861 through the early 1990s, with volumes covering the Clinton administration still in production."
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
                    "The series began during the Civil War as a compilation of official diplomatic correspondence — dispatches, instructions to ministers, treaty negotiations. The emphasis was on formal State Department channels. Coverage was often contemporaneous: volumes sometimes appeared within a year of events, prioritizing currency over comprehensiveness. Editing standards were inconsistent, and the perspective was almost entirely that of the State Department."
                ]
            ),
            EducationSection(
                id: "national-security",
                heading: "The National Security Turn (1945–1970s)",
                paragraphs: [
                    "The Cold War transformed what FRUS needed to be. Diplomacy had moved decisively out of the State Department and into the NSC, the CIA, and the White House. But the series continued to rely primarily on State Department records, leaving critical decision-making poorly documented. Classification pressure intensified as the stakes of disclosure grew. Volumes in this period often reflect what could be declassified rather than what historians judged most important."
                ]
            ),
            EducationSection(
                id: "crisis",
                heading: "Crisis and Reform (1978–1991)",
                paragraphs: [
                    "By the 1980s, the gap between what FRUS claimed to be and what it actually contained had become a serious professional problem. Historians inside the Office of the Historian fought — sometimes bitterly — for genuine access to CIA, NSC, and White House records. The controversy over the Iran volumes (which omitted the 1953 coup) became a breaking point.",
                    "In 1991, Congress intervened with the Foreign Relations Authorization Act, which established the statutory mandate still in force today, created the Historical Advisory Committee (HAC) to provide independent oversight, and required genuinely multi-agency sourcing."
                ]
            ),
            EducationSection(
                id: "contemporary",
                heading: "The Contemporary Series (1991–Present)",
                paragraphs: [
                    "Post-1991 volumes reflect a substantially different editorial philosophy: broader sourcing, fuller coverage of intelligence and NSC deliberations, and frank acknowledgment of omissions. The 30-year rule creates a rolling horizon; volumes covering the Reagan administration are now publishing, with the Bush 41 and Clinton eras in active production. Some volumes remain delayed by declassification disputes, particularly those involving the CIA."
                ]
            ),
            EducationSection(
                id: "digital",
                heading: "The Digital Transition",
                paragraphs: [
                    "The shift to XML-encoded TEI files and digital publication has transformed how FRUS can be read and searched. All 552 volumes are now available as structured digital texts — the foundation for everything this app does. The encoding preserves document structure (headings, datelines, footnotes, person references) in a form that makes programmatic analysis possible in ways printed volumes never allowed."
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
                    "Every FRUS document exists in two registers: the published text you read here, and the original record in an archive somewhere. Understanding the relationship between them is essential for using FRUS effectively."
                ]
            ),
            EducationSection(
                id: "types",
                heading: "Primary Documents and Editorial Notes",
                paragraphs: [
                    "Most of what you'll read in FRUS falls into one of two categories.",
                    "Primary documents are the actual historical records — cables, memoranda, meeting notes, intelligence assessments, letters. These are reproduced (sometimes with excisions) from government files. The source note at the bottom of each document identifies where the original lives.",
                    "Editorial notes are written by Office of the Historian historians. They appear as numbered entries in the document sequence and serve several purposes: summarizing developments the editors judged too voluminous or sensitive to reproduce in full, explaining gaps in the record, providing context for surrounding documents, and noting where fuller documentation exists. An editorial note that says \"On [date], the NSC met to discuss…\" is telling you something happened that isn't fully reproduced here."
                ]
            ),
            EducationSection(
                id: "source-note",
                heading: "Reading a Source Note",
                paragraphs: [
                    "The source note identifies the archival provenance of a primary document. A typical note might read:",
                    "\"Source: National Archives, RG 59, Central Foreign Policy File, P840114–1808. Secret; Exdis.\"",
                    "This tells you: the original is at the National Archives; it's in Record Group 59 (State Department records); it's part of the Central Foreign Policy File series from 1973–1979; the reel identifier is P840114–1808; and it was classified Secret with Exclusive Distribution handling.",
                    "The Source Explorer in this app reads these notes and connects them to NARA's finding aids — so you can navigate from a FRUS document directly to the archive where the original record lives."
                ]
            ),
            EducationSection(
                id: "omissions",
                heading: "What FRUS Omits",
                paragraphs: [
                    "FRUS is comprehensive by intention but not by content. Three categories of material are routinely absent:"
                ],
                bullets: [
                    "Excised passages: text removed during declassification review, indicated by brackets — [text not declassified]. The brackets at least signal the gap.",
                    "Omitted documents: entire records judged too sensitive for inclusion. Editorial notes often signal where records were not included.",
                    "Agency gaps: despite post-1991 reform, some agencies — particularly the CIA — remain less fully represented than the statute envisions. HAC reports note this periodically."
                ]
            ),
            EducationSection(
                id: "classifications",
                heading: "Classification Markings",
                paragraphs: [
                    "Source notes often include the document's original classification (Secret, Top Secret, Confidential) and handling caveats (Exdis, Nodis, Eyes Only). These markings are historical — the documents have been declassified — but they tell you how sensitive the material was considered at the time and often why it took decades to publish."
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
                    "FRUS rewards researchers who read across documents, not just within them. Here are strategies that experienced historians use."
                ]
            ),
            EducationSection(
                id: "introduction",
                heading: "Read the Volume Introduction First",
                paragraphs: [
                    "Every FRUS volume opens with a substantial editorial introduction that explains the volume's scope, the sources available (and unavailable), major gaps in the record, and key themes. Reading it takes fifteen minutes and saves hours of confusion. The introduction also names the editors — useful when you want to assess interpretive choices."
                ]
            ),
            EducationSection(
                id: "person",
                heading: "Follow the Person, Not Just the Topic",
                paragraphs: [
                    "Some of the richest insights come from tracking individual policymakers across documents. Secretary Kissinger's position in one cable often illuminates a memo written three weeks earlier. The person index in this app aggregates mentions across a volume; use it to build a picture of who was driving decisions, not just what decisions were made."
                ]
            ),
            EducationSection(
                id: "dates",
                heading: "Use Date Ranges Aggressively",
                paragraphs: [
                    "Foreign policy crises have phases. Filtering to a narrow window — the two weeks around a particular event — often surfaces the most revealing material: the intelligence assessments that preceded a decision, the cable traffic immediately after, the after-action reviews. Broad topic searches miss this texture."
                ]
            ),
            EducationSection(
                id: "editorial",
                heading: "Editorial Notes as a Finding Aid",
                paragraphs: [
                    "When an editorial note summarizes a meeting or document rather than reproducing it, that's a research signal, not a dead end. The note usually identifies the record group or collection where the omitted material lives. You can request the original from NARA or use Source Explorer to navigate directly to the relevant finding aids."
                ]
            ),
            EducationSection(
                id: "cross-volume",
                heading: "Cross the Volume Boundaries",
                paragraphs: [
                    "FRUS volumes are defined by the editors' judgment about how to slice a complex record. The decision on one page of a Latin America volume was shaped by conversations happening simultaneously in an Arms Control volume. Building collections across subseries — linking related documents from different volumes — reveals policy coherence (or contradiction) that single-volume reading misses."
                ]
            ),
            EducationSection(
                id: "omissions",
                heading: "Understand What You're Not Reading",
                paragraphs: [
                    "FRUS documents the American side of foreign policy. The counterpart cable from a foreign ministry, the intelligence report the American delegation didn't know about, the domestic political pressures driving a foreign leader — these are absent. FRUS is indispensable but never sufficient. Treat it as your entry point to a policy question, not its answer."
                ]
            ),
        ]
    )
}
