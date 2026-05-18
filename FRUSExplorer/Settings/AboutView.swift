// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AboutLinks

/// URL strings used in the About screen. Internal so they are testable.
enum AboutLinks {
    static let officeOfHistorian = "https://history.state.gov/historicaldocuments"
    static let historyAtState    = "https://github.com/HistoryAtState"
    static let naraTermsOfUse    = "https://www.archives.gov/research/catalog/help/api"
    static let teiPublisher      = "https://teipublisher.com"

    static let allURLStrings: [String] = [
        officeOfHistorian,
        historyAtState,
        naraTermsOfUse,
        teiPublisher,
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
struct AboutView: View {

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
    }

    // MARK: - App Header

    @ViewBuilder
    private var appHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    // Cap at accessibility3 to prevent oversized rendering at extreme
                    // Dynamic Type settings (F-007). Icon is decorative (hidden from a11y).
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .foregroundStyle(.tint)
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
            Text(String(localized: "about.frus.description",
                        defaultValue: """
*Foreign Relations of the United States* (FRUS) is the official documentary \
record of U.S. foreign policy, published by the Department of State \
continuously since 1861. Prepared by the Office of the Historian under a \
federal statute, the series is required to be a thorough, accurate, and \
reliable record of major U.S. foreign policy decisions. Historians draw on \
records from the White House, National Security Council, Departments of State \
and Defense, the CIA, and other agencies, as well as the private papers of \
individual policymakers, to document how decisions were made and what they \
aimed to achieve.

The statute requires that editing be guided by historical objectivity: records \
may not be altered without acknowledgment, no fact of major importance in \
reaching a decision may be omitted, and nothing may be omitted to conceal a \
defect in policy. Volumes must be published within 30 years of the events they \
document.

FRUS covers U.S. bilateral and regional relations across the globe, as well as \
global issues — terrorism, narcotics, health, the environment — and topics \
including national security policy, foreign economic policy, and foreign policy \
organization. It is an essential resource for scholars, policymakers, and \
citizens seeking to understand the origins of contemporary challenges and the \
United States' role in the world.
"""))
            .font(.callout)
        }
    }

    // MARK: - Resources

    @ViewBuilder
    private var resourcesSection: some View {
        Section(String(localized: "about.resources.header",
                       defaultValue: "Resources")) {
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
            Text(String(localized: "about.attribution.body",
                        defaultValue: """
The source code for FRUS Explorer was generated by Claude, an AI assistant \
made by Anthropic. Contributor credits will be added in future versions.
"""))
            .font(.callout)
        }
    }

    // MARK: - Open Source

    @ViewBuilder
    private var openSourceSection: some View {
        Section(String(localized: "about.openSource.header",
                       defaultValue: "Open Source")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "about.openSource.appLicense.title",
                            defaultValue: "FRUS Explorer"))
                    .font(.callout.bold())
                Text(String(localized: "about.openSource.appLicense.body",
                            defaultValue: "Licensed under the Apache License, Version 2.0."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

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
}
