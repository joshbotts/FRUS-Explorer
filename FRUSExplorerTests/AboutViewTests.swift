// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
import WebKit
@testable import FRUSExplorer

// MARK: - AboutViewTests

struct AboutViewTests {

    // MARK: - AboutScreenLinksTest

    @Test("AboutScreenLinksTest: all About screen URLs are well-formed https URLs")
    func aboutLinksAreWellFormed() {
        for urlString in AboutLinks.allURLStrings {
            let url = URL(string: urlString)
            #expect(url != nil, "Expected \(urlString) to be a valid URL")
            #expect(url?.scheme == "https",
                    "Expected \(urlString) to use https scheme")
            #expect(url?.host != nil,
                    "Expected \(urlString) to have a non-nil host")
        }
    }

    @Test("AboutScreenLinksTest: expected hosts are present")
    func aboutLinksContainExpectedHosts() {
        let hosts = AboutLinks.allURLStrings.compactMap { URL(string: $0)?.host }
        #expect(hosts.contains("history.state.gov"))
        #expect(hosts.contains("github.com"))
        #expect(hosts.contains("www.archives.gov"))
        #expect(hosts.contains("teipublisher.com"))
        // The on-device model's open-source row (B4) links its card; the Gemma Terms links
        // (ai.google.dev) retired with EmbeddingGemma 300m.
        #expect(hosts.contains("huggingface.co"))
        #expect(!hosts.contains("ai.google.dev"))
        // The privacy policy and the support page (#1917, ASR-2), and the quick starts since 2026-11-20.
        #expect(hosts.contains("frusexplorer.app"))
    }

    /// The two pages App Review looks for inside the app (#1917, ASR-2) are the addresses App Store
    /// Connect's Privacy Policy URL and Support URL give (`Planning/app-store-connect/
    /// App-Store-Connect-Entry.md`, §2 and §4): the in-app link and the listing's must be one page.
    /// No test reaches the pages themselves, which answer only once the site is public.
    @Test("AboutScreenLinksTest: the privacy policy and support links are the listing's two addresses")
    func privacyAndSupportAreTheListingsAddresses() {
        #expect(AboutLinks.privacyPolicy == "https://frusexplorer.app/privacy")
        #expect(AboutLinks.support == "https://frusexplorer.app/support")
        #expect(AboutLinks.allURLStrings.contains(AboutLinks.privacyPolicy))
        #expect(AboutLinks.allURLStrings.contains(AboutLinks.support))
    }

    /// About ▸ Legal, which both platforms show, and the Mac's Help menu each link both pages (#1917,
    /// ASR-2). Read from the source, since the rows are SwiftUI and the menu is the Mac's alone: the
    /// Legal section's body and the Help menu's group are each asked for the call that links each page.
    @Test("AboutScreenLinksTest: Legal and the Mac's Help menu link the privacy policy and the support page")
    func legalAndHelpMenuLinkBothPages() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
        let about = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Settings/AboutView.swift"),
                               encoding: .utf8)
        let legal = try #require(Self.slice(of: about, from: "private var legalSection: some View {",
                                            to: "private var legalRowLabel: some View {"))
        #expect(legal.contains("urlString: AboutLinks.privacyPolicy,"), "About ▸ Legal does not link the privacy policy")
        #expect(legal.contains("urlString: AboutLinks.support,"), "About ▸ Legal does not link the support page")
        let app = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/App/FRUSExplorerApp.swift"),
                             encoding: .utf8)
        let help = try #require(Self.slice(of: app, from: "CommandGroup(replacing: .help) {",
                                           to: "TextFormattingCommands()"))
        #expect(help.contains("urlString: AboutLinks.privacyPolicy)"), "the Help menu does not link the privacy policy")
        #expect(help.contains("urlString: AboutLinks.support)"), "the Help menu does not link the support page")
    }

    /// The text between the first `start` and the next `end` after it, or `nil` when either is missing.
    private static func slice(of text: String, from start: String, to end: String) -> Substring? {
        guard let lower = text.range(of: start),
              let upper = text.range(of: end, range: lower.upperBound..<text.endIndex) else { return nil }
        return text[lower.upperBound..<upper.lowerBound]
    }

    /// The manuals that About opens are files in this repository, read on GitHub at the default
    /// branch's head. A rename that left a link behind would open GitHub's 404 page. (The quick
    /// starts were too until 2026-11-20; `quickStartsAreTheWebsitesPages` holds them now.)
    @Test("AboutScreenLinksTest: every GitHub document it links is in the repository")
    func linkedDocumentsExist() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
        let prefix = "https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/"
        let documents = AboutLinks.allURLStrings.filter { $0.hasPrefix(prefix) }
        // The two manuals: fewer means the prefix no longer matches.
        #expect(documents.count >= 2)
        for link in documents {
            let path = root.appendingPathComponent(String(link.dropFirst(prefix.count))).path
            #expect(FileManager.default.fileExists(atPath: path), "\(link) names no file in the repository")
        }
    }

    /// The quick starts that About, the Research tab and the Mac's Help menu open are the website's
    /// pages (the owner's word of 2026-11-20, for 1.0 (1861)), which `Scripts/build_website_pages.py`
    /// writes from `Docs/iOS-Quick-Start.md` and `Docs/macOS-Quick-Start.md`. Each link is held to
    /// the address the script's `PAGES` gives its page, so a page moved to another address fails here
    /// before the app ships a link to the old one. No test reaches the pages themselves.
    @Test("AboutScreenLinksTest: the quick starts are the website's pages the script writes")
    func quickStartsAreTheWebsitesPages() throws {
        #expect(AboutLinks.iosQuickStart == "https://frusexplorer.app/quick-start-ios")
        #expect(AboutLinks.macQuickStart == "https://frusexplorer.app/quick-start-mac")
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests
            .deletingLastPathComponent()   // repo root
        let script = try String(contentsOf: root.appendingPathComponent("Scripts/build_website_pages.py"),
                                encoding: .utf8)
        for (source, link) in [("Docs/iOS-Quick-Start.md", AboutLinks.iosQuickStart),
                               ("Docs/macOS-Quick-Start.md", AboutLinks.macQuickStart)] {
            let entry = try #require(Self.slice(of: script, from: "source=\"\(source)\"", to: "slug="),
                                     "PAGES writes no page from \(source)")
            #expect(entry.contains("url=\"\(link)\""), "PAGES gives the page from \(source) another address than \(link)")
        }
    }

    // MARK: - EmptyStateTest

    @Test("EmptyStateTest: ProjectContextViewModel with no data has empty projects list")
    @MainActor
    func emptyProjectContextReportsZeroProjects() throws {
        let container = try makeContainer()
        let vm = ProjectContextViewModel()
        vm.load(context: container.mainContext)
        #expect(vm.projects.isEmpty)
    }

    // MARK: - DynamicTypeTest

    @Test("DynamicTypeTest: AboutLinks URL strings are non-empty and bounded in length")
    func aboutLinkStringsAreBounded() {
        for urlString in AboutLinks.allURLStrings {
            #expect(!urlString.isEmpty)
            // URLs should not be unreasonably long (no accidental whitespace/linebreaks)
            #expect(urlString.count < 256)
            #expect(!urlString.contains("\n"))
            #expect(!urlString.contains(" "))
        }
    }

    @Test("DynamicTypeTest: localized string keys produce non-empty default values")
    func localizedDefaultValuesAreNonEmpty() {
        let keys: [(String, String)] = [
            ("about.title", "About FRUS Explorer"),
            ("about.appName", "FRUS Explorer"),
            ("about.frus.header", "About FRUS"),
            ("about.resources.header", "Resources"),
            ("about.attribution.header", "Attribution"),
            ("about.openSource.header", "Open Source"),
            ("about.nara.header", "NARA Catalog API"),
        ]
        for (_, defaultValue) in keys {
            #expect(!defaultValue.isEmpty)
        }
    }

    // MARK: - Helper

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Project.self,
            ResearchNote.self,
            Collection.self,
            CollectionEntry.self,
            UserTag.self,
            ReadingHistoryEntry.self,
            GeneratedSummary.self,
            SummarizationPrompt.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }
}

// MARK: - InAppBrowserScopeTests

/// The in-app browser keeps to the site of the page it opened (#1917's ASR-3, decision 136): the
/// rule, decision by decision. `InAppBrowserCoordinatorTests` puts the same rule to WebKit.
struct InAppBrowserScopeTests {

    /// The Research tab's Quick Start, one of the browser's start pages.
    private static let quickStart = URL(string: AboutLinks.iosQuickStart)!

    /// A scope whose opening page committed where it was opened.
    private func opened(on url: URL = quickStart) -> InAppBrowserScope {
        var scope = InAppBrowserScope(openingURL: url)
        scope.didCommitMainFrame(at: url)
        return scope
    }

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    @Test("A link on the opening page's site is followed, with or without www.")
    func linksOnTheSiteAreFollowed() throws {
        let scope = opened()
        for link in ["https://frusexplorer.app/quick-start-mac",
                     "https://www.frusexplorer.app/support",
                     "http://frusexplorer.app/privacy",
                     "https://FRUSExplorer.app/quick-start-ios#searching"] {
            let destination = try url(link)
            #expect(scope.decision(for: destination, target: .mainFrame, followedByReader: true) == .allow,
                    "\(link)")
        }
    }

    @Test("A link to any other site goes to the system, a subdomain of the site included")
    func linksOffTheSiteGoOutside() throws {
        let scope = opened(on: try url(AboutLinks.officeOfHistorian))
        for link in ["https://static.history.state.gov/frus/frus1902app1/figure_0081.png",
                     "https://github.com/HistoryAtState/frus",
                     "https://www.archives.gov/research"] {
            let destination = try url(link)
            #expect(scope.decision(for: destination, target: .mainFrame, followedByReader: true)
                    == .openOutside(destination), "\(link)")
        }
    }

    @Test("The opening load's redirects are followed, and the host it commits on joins the site")
    func theOpeningLoadMayRedirect() throws {
        var scope = InAppBrowserScope(openingURL: try url(AboutLinks.claude))
        let landing = try url("https://www.anthropic.com/claude")
        #expect(scope.decision(for: landing, target: .mainFrame, followedByReader: false) == .allow)
        scope.didCommitMainFrame(at: landing)
        let news = try url("https://anthropic.com/news")
        let login = try url("https://claude.ai/login")
        #expect(scope.decision(for: news, target: .mainFrame, followedByReader: true) == .allow)
        #expect(scope.decision(for: login, target: .mainFrame, followedByReader: true) == .allow)
        let elsewhere = try url("https://example.org/")
        #expect(scope.decision(for: elsewhere, target: .mainFrame, followedByReader: true) == .openOutside(elsewhere))
        // A later commit adds nothing to the site.
        scope.didCommitMainFrame(at: elsewhere)
        #expect(scope.decision(for: elsewhere, target: .mainFrame, followedByReader: true) == .openOutside(elsewhere))
    }

    @Test("Once the opening page has committed, the page's own move to another site is stopped")
    func thePagesOwnMoveOffTheSiteIsStopped() throws {
        let scope = opened()
        let tracker = try url("https://example.org/tracker")
        #expect(scope.decision(for: tracker, target: .mainFrame, followedByReader: false) == .cancel)
        // Back, Forward, a reload or a redirect on the site go through.
        #expect(scope.decision(for: Self.quickStart, target: .mainFrame, followedByReader: false) == .allow)
    }

    @Test("From the quick start, the website's page, a manual on GitHub goes to the system")
    func theQuickStartsManualLinksGoOutside() throws {
        let scope = opened()
        for link in [AboutLinks.iosManual, AboutLinks.macManual] {
            let manual = try url(link)
            #expect(scope.decision(for: manual, target: .mainFrame, followedByReader: true) == .openOutside(manual),
                    "\(link)")
        }
    }

    @Test("A frame's own load is followed; a link followed inside a frame meets the site rule")
    func framesLoadButTheirLinksMeetTheRule() throws {
        let scope = opened()
        let embed = try url("https://www.youtube-nocookie.com/embed/x")
        #expect(scope.decision(for: embed, target: .subframe, followedByReader: false) == .allow)
        #expect(scope.decision(for: embed, target: .subframe, followedByReader: true) == .openOutside(embed))
        let onSite = try url("https://frusexplorer.app/support")
        #expect(scope.decision(for: onSite, target: .subframe, followedByReader: true) == .allow)
    }

    @Test("A new-window link on the site loads in this one; off the site it goes to the system")
    func newWindowLinks() throws {
        let scope = opened()
        let onSite = try url("https://www.frusexplorer.app/quick-start-mac")
        #expect(scope.decision(for: onSite, target: .newWindow, followedByReader: true) == .loadHere(onSite))
        let offSite = try url("https://docs.github.com/")
        #expect(scope.decision(for: offSite, target: .newWindow, followedByReader: true) == .openOutside(offSite))
        let blank = try url("about:blank")
        #expect(scope.decision(for: blank, target: .newWindow, followedByReader: false) == .cancel)
    }

    @Test("Mail goes to the system when the reader asks; the page's own addresses load; a file never does")
    func otherAddresses() throws {
        let scope = opened()
        let mail = try url("mailto:help@frusexplorer.app")
        #expect(scope.decision(for: mail, target: .mainFrame, followedByReader: true) == .openOutside(mail))
        #expect(scope.decision(for: mail, target: .mainFrame, followedByReader: false) == .cancel)
        let blank = try url("about:blank")
        let file = try url("file:///etc/hosts")
        #expect(scope.decision(for: blank, target: .subframe, followedByReader: false) == .allow)
        #expect(scope.decision(for: blank, target: .mainFrame, followedByReader: false) == .allow)
        #expect(scope.decision(for: file, target: .mainFrame, followedByReader: true) == .cancel)
        #expect(scope.decision(for: nil, target: .mainFrame, followedByReader: true) == .cancel)
    }

    @Test("From each page About opens, its own site is followed and another About page's site goes out")
    func everyStartPageKeepsToItsSite() {
        let pages = AboutLinks.allURLStrings.compactMap(URL.init(string:))
        #expect(pages.count == AboutLinks.allURLStrings.count)
        var crossings = 0
        for start in pages {
            let scope = opened(on: start)
            #expect(scope.decision(for: start, target: .mainFrame, followedByReader: true) == .allow, "\(start)")
            for other in pages
            where InAppBrowserScope.siteHost(of: other) != InAppBrowserScope.siteHost(of: start) {
                #expect(scope.decision(for: other, target: .mainFrame, followedByReader: true) == .openOutside(other),
                        "\(start) → \(other)")
                crossings += 1
            }
        }
        // Seven sites among the fourteen pages, so most pairs cross: a count of none would mean the
        // hosts compared equal.
        #expect(crossings > 100)
    }
}

// MARK: - InAppBrowserCoordinatorTests

/// WebKit asks the coordinator about each navigation, and the coordinator does what the scope decides
/// (#1917's ASR-3). A real `WKWebView`, on a page loaded from a string under a `.test` address that
/// never resolves, whose links are followed by script: the questions are WebKit's own, so a delegate
/// method WebKit never calls fails here, where `InAppBrowserScopeTests` would still pass.
@MainActor
struct InAppBrowserCoordinatorTests {

    /// What WebKit asked, what the coordinator decided, and what it handed to the system, in order.
    @MainActor
    private final class Log {
        var decisions: [(url: URL?, decision: InAppBrowserScope.Decision)] = []
        var handedOut: [URL] = []
    }

    private struct Timeout: Error {}

    private static let site = URL(string: "https://frus-explorer.test/start")!

    private static let page = """
        <!doctype html><html><body>
        <a id="off" href="https://example.org/elsewhere">off the site</a>
        <a id="mail" href="mailto:help@frusexplorer.app">mail</a>
        <a id="windowOff" target="_blank" href="https://example.org/window">a new window off the site</a>
        <a id="on" href="https://www.frus-explorer.test/next">on the site</a>
        <a id="windowOn" target="_blank" href="https://frus-explorer.test/window">a new window on the site</a>
        </body></html>
        """

    private static func waitFor(_ what: String, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(20)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for \(what)")
                throw Timeout()
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    @Test("WebKit asks the coordinator, which follows the site's links and hands any other to the system")
    func webKitAsksTheCoordinator() async throws {
        let log = Log()
        let coordinator = InAppBrowserCoordinator(navigator: InAppBrowserNavigator(),
                                                  openingURL: Self.site,
                                                  openOutside: { log.handedOut.append($0) })
        coordinator.onDecision = { log.decisions.append(($0, $1)) }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        webView.navigationDelegate = coordinator

        webView.loadHTMLString(Self.page, baseURL: Self.site)
        try await Self.waitFor("the opening page") { !webView.isLoading && webView.url == Self.site }
        let openingDecisions = log.decisions.map { $0.decision }
        #expect(openingDecisions.allSatisfy { $0 == .allow }, "the opening load was stopped: \(log.decisions)")

        /// Follows the link with this id as a click does, and returns the coordinator's first answer.
        func follow(_ id: String, answers: Int = 1) async throws -> InAppBrowserScope.Decision {
            let before = log.decisions.count
            _ = try await webView.evaluateJavaScript("document.getElementById('\(id)').click(); true")
            try await Self.waitFor("WebKit's question about #\(id)") { log.decisions.count >= before + answers }
            return log.decisions[before].decision
        }

        let elsewhere = try #require(URL(string: "https://example.org/elsewhere"))
        let mail = try #require(URL(string: "mailto:help@frusexplorer.app"))
        let window = try #require(URL(string: "https://example.org/window"))
        #expect(try await follow("off") == .openOutside(elsewhere))
        #expect(try await follow("mail") == .openOutside(mail))
        #expect(try await follow("windowOff") == .openOutside(window))
        #expect(log.handedOut == [elsewhere, mail, window])
        #expect(webView.url == Self.site, "a link off the site left the page")

        // On the site, www. or not: followed. Its load then fails, since `.test` never resolves,
        // and the page stays where it was.
        let next = try #require(URL(string: "https://www.frus-explorer.test/next"))
        #expect(try await follow("on") == .allow)
        #expect(log.decisions.last?.url == next)

        // A new-window link on the site loads in this window, and that load is asked about too.
        let onSite = try #require(URL(string: "https://frus-explorer.test/window"))
        #expect(try await follow("windowOn", answers: 2) == .loadHere(onSite))
        #expect(log.decisions.last?.url == onSite)
        #expect(log.decisions.last?.decision == .allow)
        #expect(log.handedOut.count == 3, "a link on the site went to the system: \(log.handedOut)")
    }
}
