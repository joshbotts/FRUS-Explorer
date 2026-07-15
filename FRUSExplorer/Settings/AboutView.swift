// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - AboutLinks

/// URL strings used in the About screen. Internal so they are testable.
enum AboutLinks {
    static let officeOfHistorian = "https://history.state.gov/historicaldocuments"
    static let historyAtState    = "https://github.com/HistoryAtState"
    static let naraTermsOfUse    = "https://www.archives.gov/research/catalog/help/api"
    static let teiPublisher      = "https://teipublisher.com"
    static let claude            = "https://claude.ai"
    static let frusExplorerRepo  = "https://github.com/joshbotts/FRUS-Explorer"

    // Platform user manuals (rendered Markdown on GitHub; `HEAD` follows the default
    // branch so the link never goes stale across renames/merges).
    static let iosManual     = "https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/iOS-User-Manual.md"
    static let macManual     = "https://github.com/joshbotts/FRUS-Explorer/blob/HEAD/Docs/macOS-User-Manual.md"

    static let allURLStrings: [String] = [
        officeOfHistorian,
        historyAtState,
        naraTermsOfUse,
        teiPublisher,
        claude,
        frusExplorerRepo,
        iosManual,
        macManual,
    ]
}

// MARK: - AboutView

/// About screen displaying app identity, FRUS series description, attribution,
/// open-source acknowledgements, and NARA Catalog API disclaimers.
///
/// ## Sections
/// 1. **App** — icon, name, and version
/// 2. **About FRUS** — bundled series description prose
/// 3. **Resources** — links to history.state.gov and HistoryAtState on GitHub
/// 4. **Attribution** — code generation credit and contributor note
/// 5. **Open Source** — TEI Publisher Lib and Apache 2.0 licence statement
/// 6. **NARA Catalog API** — required disclaimers
///
/// ## Version history
///   1.0 — Session 26: initial implementation
///   1.1 — Session 55: wrap in NavigationStack with Done button and minimum frame on macOS
///          (previously relied on Esc to dismiss with no explicit close control)
///   1.2 — Session 61: macOS NavigationStack wrapper removed; About is now a Window scene
///          (standard close button replaces the Done toolbar button)
///   1.3 — Session 74: SF Symbol replaced with real app icon (NSApp.applicationIconImage on
///          macOS, UIImage named AppIcon on iOS, with RoundedRectangle clip on iOS);
///          asterisks removed from FRUS description; "Foreign Relations of the United States"
///          italicised via AttributedString.inlinePresentationIntent = .emphasized
struct AboutView: View {

    /// The link tapped most recently — presented in `InAppBrowserView`
    /// rather than handed to the system browser, so following a Resources
    /// or attribution link doesn't pull the user out of the app. Set by the
    /// `\.openURL` override applied to `content` below; `URL` conforms to
    /// `Identifiable` (see `CollectionEditorView`) so it can drive
    /// `.sheet(item:)` directly.
    @State private var inAppBrowserURL: URL?

    private var appIconImage: Image {
        #if os(macOS)
        Image(nsImage: NSApp.applicationIconImage)
        #else
        // UIImage(named: "AppIcon") returns nil for appiconset assets; the correct
        // approach is to look up the icon file name from the app's Info.plist and
        // load that image from the bundle directly.
        if let uiImage = Self.iOSAppIcon {
            Image(uiImage: uiImage)
        } else {
            Image(systemName: "doc.text.magnifyingglass")
        }
        #endif
    }

    #if os(iOS)
    /// Loads the app's primary icon at runtime using the CFBundleIconFiles key.
    ///
    /// `UIImage(named: "AppIcon")` cannot load `appiconset` assets — only `imageset`
    /// assets are accessible via that API. Reading the icon file name from
    /// `CFBundleIcons → CFBundlePrimaryIcon → CFBundleIconFiles` and loading the
    /// last (largest) entry is the standard workaround.
    static var iOSAppIcon: UIImage? {
        guard
            let icons   = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files   = primary["CFBundleIconFiles"] as? [String],
            let name    = files.last
        else { return nil }
        return UIImage(named: name)
    }
    #endif

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        content
        #if os(macOS)
        // Fixed minimum size; the Window scene's .windowResizability(.contentSize)
        // allows the user to enlarge but not shrink below this.
        .frame(minWidth: 500, minHeight: 460)
        #endif
    }

    // MARK: - Content

    private var content: some View {
        List {
            appHeaderSection
            frusDescriptionSection
            resourcesSection
            attributionSection
            openSourceSection
            naraDisclaimerSection
            dosDisclaimerSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "about.title", defaultValue: "About FRUS Explorer"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Route every link tap (the `Link` rows below and the inline
        // Markdown links in `frusDescription`) into the in-app browser
        // instead of the system browser.
        .environment(\.openURL, OpenURLAction { url in
            inAppBrowserURL = url
            return .handled
        })
        .sheet(item: $inAppBrowserURL) { url in
            InAppBrowserView(url: url)
        }
    }

    // MARK: - App Header

    @ViewBuilder
    private var appHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                appIconImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    #if os(iOS)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    #endif
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "about.appName", defaultValue: "FRUS Explorer"))
                        .font(.title2.bold())

                    Text(String(localized: "about.version",
                                defaultValue: "Version \(appVersion)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "about.appHeader.a11y",
                       defaultValue: "FRUS Explorer, version \(appVersion)")
            )
        }
    }

    // MARK: - FRUS Description

    @ViewBuilder
    private var frusDescriptionSection: some View {
        Section(String(localized: "about.frus.header",
                       defaultValue: "About FRUS")) {
            Text(frusDescription)
                .font(.callout)
        }
    }

    /// Raw Markdown source for the "About FRUS" description, including the
    /// inline `[1991 federal statute](...)` reference link.
    ///
    /// Exposed at `internal` access (rather than folded directly into
    /// `frusDescription` as `private`) so `EmbeddedMarkdownLinkTests` can
    /// validate the embedded link against the exact resolved string rendered
    /// on screen, without duplicating this prose block — mirroring the
    /// "Internal so they are testable" rationale documented on `AboutLinks`.
    static var frusDescriptionRaw: String {
        String(localized: "about.frus.description", defaultValue: """
The **Foreign Relations of the United States** (FRUS) series is the official \
documentary record of U.S. foreign policy. The Department of State has \
published FRUS continuously since 1861. The series now comprises more than \
550 volumes covering U.S. foreign policy from 1861 through the early 1990s.

While the content of the series has shifted over time, recent FRUS volumes \
cover U.S. bilateral and regional relations across the globe; U.S. \
policymakers' responses to unfolding crises; engagement with global issues \
like human rights, terrorism, narcotics, health, and the environment; and \
thematic topics including national security policy, foreign economic policy, \
and foreign affairs organization and management. It is an essential resource \
for scholars, policymakers, and citizens seeking to understand the origins of \
contemporary challenges and the United States's role in the world.
""")
    }

    private var frusDescription: AttributedString {
        AttributedString(markdownBody: Self.frusDescriptionRaw)
    }

    // MARK: - Resources

    /// One Resources-section link row (label + external-link chevron), opened in the
    /// in-app browser via the `\.openURL` override on `content`.
    @ViewBuilder
    private func resourceLink(_ title: String, urlString: String, systemImage: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(Text(verbatim: "\(title) — \(String(localized: "about.resources.opensInBrowser", defaultValue: "opens in browser"))"))
            .accessibilityAddTraits(.isLink)
        }
    }

    private var resourcesSection: some View {
        Section(String(localized: "about.resources.header",
                       defaultValue: "Resources")) {
            // Platform user manual(s) — rendered Markdown on GitHub.
            #if os(macOS)
            resourceLink(String(localized: "about.resources.manual.mac", defaultValue: "macOS User Manual"),
                         urlString: AboutLinks.macManual, systemImage: "book")
            #else
            resourceLink(String(localized: "about.resources.manual.ios", defaultValue: "iOS & iPadOS User Manual"),
                         urlString: AboutLinks.iosManual, systemImage: "book")
            #endif

            if let url = URL(string: AboutLinks.officeOfHistorian) {
                Link(destination: url) {
                    HStack {
                        Label(
                            String(localized: "about.resources.officeOfHistorian",
                                   defaultValue: "Office of the Historian"),
                            systemImage: "globe"
                        )
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    String(localized: "about.resources.officeOfHistorian.a11y",
                           defaultValue: "Office of the Historian — opens in browser")
                )
                .accessibilityAddTraits(.isLink)
            }

            if let url = URL(string: AboutLinks.historyAtState) {
                Link(destination: url) {
                    HStack {
                        Label(
                            String(localized: "about.resources.historyAtState",
                                   defaultValue: "HistoryAtState on GitHub"),
                            systemImage: "chevron.left.slash.chevron.right"
                        )
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    String(localized: "about.resources.historyAtState.a11y",
                           defaultValue: "HistoryAtState on GitHub — opens in browser")
                )
                .accessibilityAddTraits(.isLink)
            }
        }
    }

    // MARK: - Attribution

    @ViewBuilder
    private var attributionSection: some View {
        Section(String(localized: "about.attribution.header",
                       defaultValue: "Attribution")) {
            Text(attributionText).font(.callout)
        }
    }

    /// Attribution text with an inline hyperlink on "Claude".
    private var attributionText: AttributedString {
        var str = AttributedString(
            String(localized: "about.attribution.prefix",
                   defaultValue: "The code for FRUS Explorer was generated by ")
        )
        var claudeLink = AttributedString(
            String(localized: "about.attribution.claude", defaultValue: "Claude")
        )
        claudeLink.link = URL(string: AboutLinks.claude)
        str += claudeLink
        str += AttributedString(
            String(localized: "about.attribution.suffix",
                   defaultValue: ", an AI assistant made by Anthropic, at the direction of Joshua Botts. Josh thanks his colleagues for the inspiration, feature ideas, feedback, and enthusiasm they contributed to the app.")
        )
        return str
    }

    // MARK: - Open Source

    @ViewBuilder
    private var openSourceSection: some View {
        Section(String(localized: "about.openSource.header",
                       defaultValue: "Open Source")) {
            if let url = URL(string: AboutLinks.frusExplorerRepo) {
                Link(destination: url) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(
                                String(localized: "about.openSource.appLicense.title",
                                       defaultValue: "FRUS Explorer"),
                                systemImage: "chevron.left.slash.chevron.right"
                            )
                            .font(.callout.bold())
                            Text(String(localized: "about.openSource.appLicense.body",
                                        defaultValue: "Licensed under the Apache License, Version 2.0. View source and contribute on GitHub."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    String(localized: "about.openSource.appRepo.a11y",
                           defaultValue: "FRUS Explorer on GitHub — view source and contribute")
                )
                .accessibilityAddTraits(.isLink)
                .padding(.vertical, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "about.openSource.teiPublisher.title",
                            defaultValue: "TEI Publisher"))
                    .font(.callout.bold())
                if let url = URL(string: AboutLinks.teiPublisher) {
                    Link(destination: url) {
                        Text(String(localized: "about.openSource.teiPublisher.body",
                                    defaultValue: "TEI rendering approaches informed by the TEI Publisher project (teipublisher.com). Licensed under the Apache License, Version 2.0."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .accessibilityLabel(
                        String(localized: "about.openSource.teiPublisher.a11y",
                               defaultValue: "TEI Publisher website — opens in browser")
                    )
                    .accessibilityAddTraits(.isLink)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - NARA Disclaimer

    @ViewBuilder
    private var naraDisclaimerSection: some View {
        Section(String(localized: "about.nara.header",
                       defaultValue: "NARA Catalog API")) {
            Text(String(localized: "about.nara.disclaimer",
                        defaultValue: """
FRUS Explorer is not affiliated with, endorsed by, or sponsored by the \
National Archives and Records Administration (NARA). NARA Catalog data \
accessed through this app is provided by the National Archives and is subject \
to their terms of use.
"""))
            .font(.caption)
            .foregroundStyle(.secondary)

            if let url = URL(string: AboutLinks.naraTermsOfUse) {
                Link(destination: url) {
                    HStack {
                        Text(String(localized: "about.nara.termsLink",
                                    defaultValue: "NARA Catalog API Terms"))
                            .font(.caption)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    String(localized: "about.nara.termsLink.a11y",
                           defaultValue: "NARA Catalog API Terms — opens in browser")
                )
                .accessibilityAddTraits(.isLink)
            }
        }
    }

    // MARK: - DOS Disclaimer

    @ViewBuilder
    private var dosDisclaimerSection: some View {
        Section(String(localized: "about.dos.header",
                       defaultValue: "Department of State")) {
            Text(String(localized: "about.dos.disclaimer",
                        defaultValue: """
FRUS Explorer is an independently-developed research tool and is not an \
official product of the Office of the Historian or the U.S. Department of \
State. The FRUS series itself is a public domain resource.
"""))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
