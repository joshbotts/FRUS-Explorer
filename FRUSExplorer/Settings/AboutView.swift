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

    // The Gemma licence surfaces (V-5 s2, compliance runbook §4). Both URLs are load-bearing:
    // the notice sentence names the first, and the Prohibited Use Policy is incorporated into
    // the terms by reference through the second.
    static let gemmaTerms        = "https://ai.google.dev/gemma/terms"
    static let gemmaProhibitedUse = "https://ai.google.dev/gemma/prohibited_use_policy"
    static let llamaCpp          = "https://github.com/ggml-org/llama.cpp"

    static let allURLStrings: [String] = [
        officeOfHistorian,
        historyAtState,
        naraTermsOfUse,
        teiPublisher,
        claude,
        frusExplorerRepo,
        iosManual,
        macManual,
        gemmaTerms,
        gemmaProhibitedUse,
        llamaCpp,
    ]
}

// MARK: - AboutView

/// About screen displaying app identity, FRUS series description, attribution,
/// open-source acknowledgements, and NARA Catalog API disclaimers.
///
/// ## Sections
/// 1. **App** — icon, name, and version
/// 2. **About FRUS** — bundled series description prose
/// 3. **Resources** — the FRUS Research Guide, the platform manual, history.state.gov, and
///    HistoryAtState on GitHub
/// 4. **Attribution** — code generation credit and contributor note
/// 5. **Legal** — one row to `FullNoticesView` (open-source licenses + the two disclaimers)
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
///   1.4 — S-5: one About on both platforms (the macOS `SettingsAboutPane` is gone). The
///          Research Guide moves here from its own Settings row; the three legal essays move
///          behind one Legal row into `FullNoticesView` — a push on iOS, a sheet on macOS,
///          because the Settings detail column has no back button of its own.
struct AboutView: View {

    @Environment(AppState.self) private var appState
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    /// The link tapped most recently — presented in `InAppBrowserView`
    /// rather than handed to the system browser, so following a Resources
    /// or attribution link doesn't pull the user out of the app. Set by the
    /// `\.openURL` override applied to `content` below; `URL` conforms to
    /// `Identifiable` (see `CollectionEditorView`) so it can drive
    /// `.sheet(item:)` directly.
    @State private var inAppBrowserURL: URL?

    #if os(macOS)
    /// Whether the Legal row's full-notices sheet is up. macOS only — iOS pushes instead.
    @State private var showsFullNotices = false
    #else
    /// Whether the Research Guide sheet is up. iOS only — macOS opens a window scene instead.
    ///
    /// Scene-local `@State`, not a flag on `AppState` (#752 / L-43): the row that sets it and the
    /// sheet that reads it are the same view in the same window, and the app-wide flag it replaces
    /// was bound by *every* open iPad window's Settings tab at once.
    @State private var showsResearchGuide = false
    #endif

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
            legalSection
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
        #if os(iOS)
        // The Research Guide presents from the row that asked for it, in this window (#752 / L-43).
        // It used to present from `SettingsView` off an `AppState` flag, which every open window's
        // Settings tab was bound to. `.environment(appState)` is explicit because a sheet starts a
        // fresh environment.
        .sheet(isPresented: $showsResearchGuide) {
            ResearchGuideView()
                .environment(appState)
        }
        #endif
        #if os(macOS)
        // The full notices arrive as a sheet here, not a push — see `legalSection`.
        .sheet(isPresented: $showsFullNotices) {
            VStack(spacing: 0) {
                FullNoticesView()
                Divider()
                HStack {
                    Spacer()
                    Button(String(localized: "about.legal.done", defaultValue: "Done")) {
                        showsFullNotices = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .frame(minWidth: 520, minHeight: 460)
        }
        #endif
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
The **Foreign Relations of the United States** (FRUS) series is the official documentary \
record of U.S. foreign policy, published continually by the Department of State since 1861. \
The series now runs to more than 550 volumes, covering 1861 through the early 1990s. Recent \
volumes document U.S. bilateral and regional relations around the world, and how U.S. \
policymakers responded to unfolding crises. They cover global issues such as human rights, \
terrorism, narcotics, health, and the environment. They also follow thematic topics such as \
national security policy, foreign economic policy, and foreign affairs organization and \
management. Scholars, policymakers, and citizens use FRUS to trace the origins of today's \
challenges and the United States's role in the world.
""")
    }

    private var frusDescription: AttributedString {
        AttributedString(markdownBody: Self.frusDescriptionRaw)
    }

    // MARK: - Research Guide

    /// The in-app Research Guide, rehomed from a Settings root row into Resources (S-5).
    ///
    /// It is content, not a setting — a root row for it made the Settings list carry an essay
    /// alongside its controls. It opens as a sheet on iOS and its own window on macOS, which is
    /// where each platform already put it.
    @ViewBuilder
    private var researchGuideRow: some View {
        Button {
            #if os(macOS)
            // The guide is a VALUE-based WindowGroup(for: ResearchGuideWindowID.self), not an
            // id-based one — `openWindow(id:)` silently does nothing against it. Same call the
            // Help ▸ FRUS Research Guide menu item makes (#363 #7).
            openWindow(value: ResearchGuideWindowID())
            #else
            showsResearchGuide = true
            #endif
        } label: {
            HStack {
                Label(String(localized: "about.resources.researchGuide",
                             defaultValue: "FRUS Research Guide"), systemImage: "book")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    // MARK: - Legal

    /// One Legal row leading to the full notices (S-5).
    ///
    /// The open-source licenses and the two disclaimers used to be three prose sections at the
    /// bottom of About — three essays a reader scrolled past every time they came here for a
    /// version number. Every word is preserved, one tap away.
    ///
    /// A push on iOS, a sheet on macOS: the Settings window's detail column has no navigation
    /// chrome, so a `NavigationLink` there pushes to a screen with no back button. Same shape
    /// `DataRecoveryView.link(_:)` uses for the recovery sub-screens (S-4b).
    @ViewBuilder
    private var legalSection: some View {
        Section {
            #if os(macOS)
            Button {
                showsFullNotices = true
            } label: {
                HStack {
                    legalRowLabel
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            #else
            NavigationLink {
                FullNoticesView()
            } label: {
                legalRowLabel
            }
            #endif
        } header: {
            Text(String(localized: "about.legal.header", defaultValue: "Legal"))
        }
    }

    /// The Legal row's text, shared by the two presentations above.
    private var legalRowLabel: some View {
        SettingsNavRow(
            label: String(localized: "about.legal.full", defaultValue: "Full Notices"),
            detail: String(localized: "about.legal.detail",
                           defaultValue: "Open-source licenses, and the two disclaimers this app is required to make")
        )
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
            researchGuideRow
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
}

// MARK: - FullNoticesView

/// Licences and the two disclaimers, on their own screen (S-5).
///
/// The wording is exactly what used to sit at the bottom of About — these are statements the app
/// is obliged to make, and not mine to rewrite. What changed is where they live: a reader coming
/// to About for a version number no longer scrolls past three essays to reach it, and a reader who
/// wants the notices gets them whole rather than as a tail.
///
/// Version history:
///   1.0 — S-5: extracted from `AboutView`
struct FullNoticesView: View {

    /// Links open in the in-app browser, as they did inside About.
    @State private var inAppBrowserURL: URL?

    /// Presents the bundled Gemma Terms on macOS, where this view has no NavigationStack to push
    /// into (it arrives as a sheet from both hosts) — see `onDeviceModelSection`.
    @State private var showingGemmaTerms = false

    var body: some View {
        List {
            openSourceSection
            onDeviceModelSection
            naraDisclaimerSection
            dosDisclaimerSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(String(localized: "about.legal.full", defaultValue: "Full Notices"))
        .environment(\.openURL, OpenURLAction { url in
            inAppBrowserURL = url
            return .handled
        })
        .sheet(item: $inAppBrowserURL) { url in
            InAppBrowserView(url: url)
        }
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

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "about.openSource.llamaCpp.title",
                            defaultValue: "llama.cpp"))
                    .font(.callout.bold())
                if let url = URL(string: AboutLinks.llamaCpp) {
                    Link(destination: url) {
                        Text(String(localized: "about.openSource.llamaCpp.body",
                                    defaultValue: "The natural-language search feature runs its on-device model through llama.cpp (github.com/ggml-org/llama.cpp), © 2023–2026 The ggml authors, licensed under the MIT License."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .accessibilityLabel(
                        String(localized: "about.openSource.llamaCpp.a11y",
                               defaultValue: "llama.cpp on GitHub — opens in browser")
                    )
                    .accessibilityAddTraits(.isLink)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - On-Device Model (V-5 s2)

    /// The Gemma notice section the compliance runbook (§4) specifies: whose model the optional
    /// download is, the exact notice sentence, and the terms one tap away — both as live links
    /// and as the bundled copy (`GemmaTermsView`), which is what satisfies the licence's
    /// copy-of-the-terms-to-every-recipient condition.
    @ViewBuilder
    private var onDeviceModelSection: some View {
        Section(String(localized: "about.modelLicense.header",
                       defaultValue: "On-Device Model")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "about.modelLicense.gemma.title",
                            defaultValue: "EmbeddingGemma (Google)"))
                    .font(.callout.bold())
                Text(String(localized: "about.modelLicense.gemma.body",
                            defaultValue: "When you enable natural-language search, the app downloads Google’s EmbeddingGemma model (229 MB) and runs it on this device to convert your search queries into vectors. The model is used unmodified. Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms, including its Prohibited Use Policy."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 2)

            if let url = URL(string: AboutLinks.gemmaTerms) {
                Link(destination: url) {
                    HStack {
                        Text(String(localized: "about.modelLicense.termsLink",
                                    defaultValue: "Gemma Terms of Use"))
                            .font(.caption)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    String(localized: "about.modelLicense.termsLink.a11y",
                           defaultValue: "Gemma Terms of Use — opens in browser")
                )
                .accessibilityAddTraits(.isLink)
            }

            if let url = URL(string: AboutLinks.gemmaProhibitedUse) {
                Link(destination: url) {
                    HStack {
                        Text(String(localized: "about.modelLicense.pupLink",
                                    defaultValue: "Gemma Prohibited Use Policy"))
                            .font(.caption)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(
                    String(localized: "about.modelLicense.pupLink.a11y",
                           defaultValue: "Gemma Prohibited Use Policy — opens in browser")
                )
                .accessibilityAddTraits(.isLink)
            }

            // The bundled copy. iOS pushes (FullNoticesView lives in the Settings stack);
            // macOS reaches FullNoticesView as a SHEET with no NavigationStack, where a bare
            // NavigationLink is inert — so it opens a second sheet, the DataRecoveryView.link
            // dual-pattern this file's legalSection already follows.
            #if os(macOS)
            Button {
                showingGemmaTerms = true
            } label: {
                HStack {
                    Text(String(localized: "about.modelLicense.bundledTerms",
                                defaultValue: "Read the Terms (included copy)"))
                        .font(.caption)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingGemmaTerms) {
                VStack(spacing: 0) {
                    GemmaTermsView()
                    Divider()
                    HStack {
                        Spacer()
                        Button(String(localized: "about.modelLicense.done",
                                      defaultValue: "Done")) {
                            showingGemmaTerms = false
                        }
                        .keyboardShortcut(.cancelAction)
                        .padding()
                    }
                }
                .frame(minWidth: 520, minHeight: 460)
            }
            #else
            NavigationLink {
                GemmaTermsView()
            } label: {
                Text(String(localized: "about.modelLicense.bundledTerms",
                            defaultValue: "Read the Terms (included copy)"))
                    .font(.caption)
            }
            #endif
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
FRUS Explorer is an independent research tool. It is not an official product of the Office of \
the Historian or the U.S. Department of State. Any commentary, advice, or guidance about the \
FRUS series in this app reflects personal views. Those views are not necessarily those of the \
Department of State or the U.S. Government. The FRUS series itself is in the public domain.
"""))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - GemmaTermsView

/// The bundled copy of the Gemma Terms of Use (V-5 s2) — the surface that satisfies the licence's
/// "copy of the Terms to every recipient" condition, so it must not degrade silently.
///
/// The text is `gemma-terms-of-use.txt`, captured verbatim from the live page (the capture header
/// inside the file states the date; the page states its own last-modified date). If the resource
/// ever fails to load, the screen says so and shows the live link instead of rendering empty —
/// a licence-obligation surface that quietly showed nothing would look wired and be dark.
struct GemmaTermsView: View {

    /// The bundled text, loaded once. `nil` means the resource is missing from the build.
    private static let bundledText: String? = {
        guard let url = Bundle.main.url(forResource: "gemma-terms-of-use", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            #if DEBUG
            print("[About] gemma-terms-of-use.txt missing from the bundle")
            #endif
            return nil
        }
        return text
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let text = Self.bundledText {
                    Text(text)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(String(localized: "about.gemmaTerms.missing",
                                defaultValue: "The included copy of the terms could not be loaded. The authoritative text is at the link below."))
                        .font(.callout)
                    if let url = URL(string: AboutLinks.gemmaTerms) {
                        // Its own key, not `about.modelLicense.termsLink` — reusing another
                        // view's key is the silent i18n collision the repo has been burned by.
                        Link(String(localized: "about.gemmaTerms.liveLink",
                                    defaultValue: "Gemma Terms of Use"), destination: url)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "about.gemmaTerms.title",
                                defaultValue: "Gemma Terms of Use"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
