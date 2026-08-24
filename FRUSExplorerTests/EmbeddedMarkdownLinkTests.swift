// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - EmbeddedMarkdownLinkTests

/// Validates inline Markdown links — `[text](url)` spans parsed by
/// `AttributedString.init(markdownBody:)` — embedded directly in static
/// prose strings.
///
/// `AboutView.frusDescriptionRaw`, `OnboardingViewModel.bundledIntroText`,
/// and the `IndexingEducationView` page content (`EducationPage.all`) all
/// embed hand-written reference links inline in their prose, rather than
/// listing them in a centralized `URLStrings` registry the way `AboutLinks`
/// does for the standalone `Link` rows (`frusDescriptionRaw` is exposed at
/// `internal` access for exactly this reason — see its doc comment). A typo
/// in one of these — a missing `https://`, a stray space, an unencoded
/// character that breaks `URL` parsing — would silently render as plain
/// text or produce a dead link, and would only surface to a human by
/// actually tapping through every page. This suite extracts every such
/// link with a regular expression and asserts each resolves to a
/// well-formed `https` URL with a non-nil host, mirroring
/// `AboutViewTests.aboutLinksAreWellFormed` for the centralized
/// `AboutLinks` registry.
///
/// Version history:
///   1.0 — Session 2026-06-06: introduced alongside the in-app browser sheet
///         (`InAppBrowserView`) for these same embedded links
///   1.1 — Build-43 content pass: the feature-catalog test re-pinned to the contracts
///         convention (pages 5–7 organized by task, closing with a User Manual pointer;
///         the per-feature section ids and per-section glyphs were the retired convention)
struct EmbeddedMarkdownLinkTests {

    // MARK: - Link extraction

    /// Matches inline Markdown link spans `[link text](url)`, capturing the
    /// URL portion. Mirrors the `interpretedSyntax: .inlineOnlyPreservingWhitespace`
    /// parsing `AttributedString.init(markdownBody:)` performs at render time —
    /// this regex only needs to *find* candidate URLs, not fully replicate
    /// CommonMark link parsing.
    private static let markdownLinkPattern = try! NSRegularExpression(
        pattern: #"\[[^\]]+\]\(([^)\s]+)\)"#
    )

    /// Returns every URL string captured from `[text](url)` spans in `text`.
    private static func markdownLinkURLStrings(in text: String) -> [String] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = markdownLinkPattern.matches(in: text, range: nsRange)
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text)
            else { return nil }
            return String(text[range])
        }
    }

    /// Every prose string in the app that embeds inline Markdown links and is
    /// rendered through `AttributedString.init(markdownBody:)`:
    ///  - `AboutView.frusDescriptionRaw` ("About FRUS" section)
    ///  - `OnboardingViewModel.bundledIntroText` (onboarding intro)
    ///  - every paragraph and bullet across all `EducationPage.all` pages
    ///    (shown during onboarding indexing and in the standalone
    ///    "Research Guide" — see `ResearchGuideView`)
    /// `OnboardingViewModel.bundledIntroText` is `@MainActor`-isolated (the
    /// type itself is `@MainActor @Observable`), so this aggregator — and
    /// everything that depends on it — must hop to the main actor too.
    @MainActor
    private static var allMarkdownBodyStrings: [String] {
        var strings: [String] = [
            AboutView.frusDescriptionRaw,
            OnboardingViewModel.bundledIntroText,
        ]
        for page in EducationPage.all {
            for section in page.sections {
                strings.append(contentsOf: section.paragraphs)
                strings.append(contentsOf: section.bullets ?? [])
            }
        }
        return strings
    }

    /// Every URL embedded as a Markdown link across all of the above strings.
    @MainActor
    private static var allEmbeddedLinkURLStrings: [String] {
        allMarkdownBodyStrings.flatMap(markdownLinkURLStrings(in:))
    }

    // MARK: - Tests

    @Test("EmbeddedLinkTest: at least one inline Markdown link is present to validate")
    @MainActor
    func atLeastOneEmbeddedLinkExists() {
        // Guards against the regex silently matching nothing (e.g. after a
        // future copy rewrite removes all inline links) and this suite
        // becoming a vacuously-passing no-op.
        #expect(!Self.allEmbeddedLinkURLStrings.isEmpty)
    }

    @Test("EmbeddedLinkTest: every embedded Markdown link is a well-formed https URL")
    @MainActor
    func embeddedLinksAreWellFormed() {
        for urlString in Self.allEmbeddedLinkURLStrings {
            let url = URL(string: urlString)
            #expect(url != nil, "Expected \(urlString) to be a valid URL")
            #expect(url?.scheme == "https",
                    "Expected \(urlString) to use https scheme")
            #expect(url?.host != nil,
                    "Expected \(urlString) to have a non-nil host")
        }
    }

    @Test("EmbeddedLinkTest: embedded link strings contain no stray whitespace or line breaks")
    @MainActor
    func embeddedLinkStringsAreClean() {
        for urlString in Self.allEmbeddedLinkURLStrings {
            #expect(!urlString.isEmpty)
            #expect(!urlString.contains("\n"))
            #expect(!urlString.contains(" "))
        }
    }

    @Test("EmbeddedLinkTest: AttributedString(markdownBody:) successfully parses every source string")
    @MainActor
    func markdownBodyStringsParseToAttributedStrings() {
        // A parsing failure falls back to verbatim plain text (see
        // `AttributedString.init(markdownBody:)`), which would silently
        // turn `[text](url)` into literal bracket-and-parenthesis text in
        // the rendered UI. Comparing the parsed result's plain-text form
        // against the raw source — for strings that contain a link — is a
        // cheap way to detect that fallback: a successful Markdown parse
        // drops the `[`, `]`, `(`, `)` link syntax from the rendered text,
        // while the verbatim fallback preserves it character-for-character.
        for raw in Self.allMarkdownBodyStrings where !Self.markdownLinkURLStrings(in: raw).isEmpty {
            let parsed = AttributedString(markdownBody: raw)
            let renderedText = String(parsed.characters)
            #expect(renderedText != raw,
                    "Expected Markdown link syntax to be parsed out of: \(raw.prefix(80))…")
        }
    }

    @Test("Research Guide keeps its three using-the-app pages, as contracts")
    @MainActor
    func featureCatalogPagesPresent() {
        // Build-43 content pass: the owner rewrote pages 5–7 as CONTRACTS — organized by
        // research task (finding, seeing the bigger picture, working with documents), never by
        // feature. So this test no longer pins the per-feature section catalog ("search",
        // "browser", "chronology", …) or a per-section interface glyph: both were the retired
        // convention, and the manual now carries the how. What still holds: the three pages
        // exist, each is organized as task contracts that close by pointing at the User Manual,
        // and the sidebar grouping is unchanged.
        let pageIDs = Set(EducationPage.all.map(\.id))
        #expect(pageIDs.isSuperset(of: ["finding-documents", "corpus-analysis", "working-with-documents"]),
                "The three feature pages must be present")

        // Pages are grouped for the macOS reference sidebar: 4 background + 3 feature pages.
        #expect(EducationPage.all.filter { $0.category == .aboutFRUS }.count == 4)
        #expect(EducationPage.all.filter { $0.category == .usingTheApp }.count == 3)

        // The contract shape: every using-the-app page ends by handing the reader to the manual
        // for the how — the pointer is what licenses these pages to stop spelling out controls.
        for page in EducationPage.all where page.category == .usingTheApp {
            #expect(!page.sections.isEmpty, "\(page.id) has no sections")
            let closing = page.sections.last
            #expect(closing?.paragraphs.joined().contains("User Manual") == true,
                    "\(page.id) must close by pointing at the User Manual")
        }
    }
}
