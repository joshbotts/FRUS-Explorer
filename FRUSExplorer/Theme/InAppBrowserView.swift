// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import WebKit

// MARK: - InAppBrowserView

/// Lightweight in-app browser sheet for opening external links without
/// leaving FRUS Explorer.
///
/// `AboutView` and `IndexingEducationView` embed a
/// handful of inline Markdown links (e.g. to `history.state.gov`, the GitHub
/// repository, or the federal statute establishing the FRUS series). Handing
/// those off to the system browser is a jarring context switch — especially
/// on macOS, where About and the Research Guide already live in their own
/// dedicated windows, and a Safari launch competes for the user's attention.
///
/// This view wraps a plain `WKWebView` in a minimal chrome: a navigation
/// title that tracks the loaded page, Back/Forward controls, a progress
/// indicator, a "Done" button, and an "Open in Browser" action that escapes
/// to the system browser via `UIApplication`/`NSWorkspace` for cases where
/// the embedded view can't help (e.g. sign-in flows, downloads).
///
/// **It keeps to the site of the page it opened** (decision 136, #1917's ASR-3): a link to any
/// other site, or to an address that is not a web page, goes to the system, and the sheet stays
/// where it was. `InAppBrowserScope` is the rule and `InAppBrowserCoordinator` applies it. The age
/// rating answers *Unrestricted Web Access* with *no*, which this keeps true.
///
/// ## Usage
/// Present as a sheet, supplying the destination URL:
/// ```swift
/// .sheet(item: $inAppBrowserURL) { url in
///     InAppBrowserView(url: url)
/// }
/// ```
/// Call sites intercept link taps by overriding `\.openURL`:
/// ```swift
/// .environment(\.openURL, OpenURLAction { url in
///     inAppBrowserURL = url
///     return .handled
/// })
/// ```
///
/// Version history:
///   1.0 — Session 2026-06-06: introduced so embedded links in About,
///         Onboarding, and Education content open in-app rather than
///         handing off to the system browser
///   1.1 — L17 (#1917, ASR-3; decision 136): follows a link only on the site of the page it opened,
///         and hands any other to the system; Open in Browser shares the coordinator's opener
struct InAppBrowserView: View {

    /// The destination URL to load.
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var navigator = InAppBrowserNavigator()

    var body: some View {
        NavigationStack {
            InAppBrowserWebView(url: url, navigator: navigator)
                .navigationTitle(navigator.pageTitle.isEmpty
                                 ? (url.host ?? url.absoluteString)
                                 : navigator.pageTitle)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "browser.close", defaultValue: "Close")) {
                            dismiss()
                        }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        navigationControls
                    }
                    #else
                    ToolbarItemGroup {
                        navigationControls
                        Button(String(localized: "browser.close", defaultValue: "Close")) {
                            dismiss()
                        }
                    }
                    #endif
                }
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 480)
        #endif
    }

    @ViewBuilder
    private var navigationControls: some View {
        Button {
            navigator.goBack()
        } label: {
            Label(String(localized: "browser.back", defaultValue: "Back"),
                  systemImage: "chevron.left")
        }
        .disabled(!navigator.canGoBack)

        Button {
            navigator.goForward()
        } label: {
            Label(String(localized: "browser.forward", defaultValue: "Forward"),
                  systemImage: "chevron.right")
        }
        .disabled(!navigator.canGoForward)

        if navigator.isLoading {
            ProgressView()
                #if os(macOS)
                .controlSize(.small)
                #endif
        }

        Button {
            openInSystemBrowser()
        } label: {
            Label(String(localized: "browser.openInBrowser", defaultValue: "Open in Browser"),
                  systemImage: "safari")
        }
    }

    /// Escapes to the system browser, bypassing the SwiftUI `openURL`
    /// environment (which call sites override to route into this view).
    private func openInSystemBrowser() {
        InAppBrowserCoordinator.openInSystem(navigator.currentURL ?? url)
    }
}

// MARK: - InAppBrowserNavigator

/// Observable bridge between SwiftUI controls and the underlying `WKWebView`.
///
/// `WKWebView` exposes navigation state (`canGoBack`, `canGoForward`,
/// `isLoading`, `title`, `url`) as KVO-observable properties on the view
/// instance itself rather than through Combine or async sequences. This
/// `@Observable` shim lets `InAppBrowserView`'s toolbar reflect that state
/// and issue navigation commands without holding a reference to the
/// platform-specific `WKWebView` directly.
@Observable
@MainActor
final class InAppBrowserNavigator {
    fileprivate(set) var canGoBack = false
    fileprivate(set) var canGoForward = false
    fileprivate(set) var isLoading = false
    fileprivate(set) var pageTitle = ""
    fileprivate(set) var currentURL: URL?

    /// Set by `InAppBrowserWebView.Coordinator` once the underlying
    /// `WKWebView` exists, so `goBack()`/`goForward()` can drive it.
    fileprivate weak var webView: WKWebView?

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
}

// MARK: - InAppBrowserScope

/// Where the in-app browser may go: the site of the page it opened, and nowhere else (decision 136,
/// #1917's ASR-3).
///
/// The browser opens a page the app chose (a Resources or Legal row in About, a link in the Research
/// Guide, the Research tab's Quick Start), and its start pages link anywhere: GitHub, Hugging Face,
/// claude.ai. Apple's age-rating question *Unrestricted Web Access* means a browser in which "users
/// can navigate to any webpage", and the app answers *no*. This is the rule that makes the answer
/// true. A value, so it is tested without a web view; `InAppBrowserCoordinator` applies it.
///
/// What it allows, and where everything else goes:
/// - **The opening load**, its redirects included: until the first page commits, any web address,
///   and the host it commits on joins the site (`didCommitMainFrame(at:)`).
/// - **A page on the site**, however it is reached: a link, a form, Back and Forward, a reload, a
///   redirect, the page's own script.
/// - **A link to another site**, in the page or in a frame of it, goes to the default browser, and
///   an address that is not a web page (`mailto:`, `tel:`) to the app the system gives it. The sheet
///   stays where it was.
/// - **The page's own move to another site**, which the reader did not ask for (a script, a
///   refresh), is stopped there: nothing opens.
/// - **A frame's own load** is one of the page's subresources, like its images, scripts and style
///   sheets, which never come here at all.
/// - **A link that asks for a new window** loads in this one when it is on the site, since the sheet
///   has one page, and goes to the system when it is not.
/// - `about:`, `data:` and `blob:` addresses are the page's own; a `file:` address is never followed.
///
/// A host is compared without a leading `www.`, so `www.frusexplorer.app` and `frusexplorer.app` are
/// one site; nothing else is: `static.history.state.gov` is not `history.state.gov`.
struct InAppBrowserScope {

    /// Which frame a navigation would load into.
    enum Target: Equatable {
        /// The page itself.
        case mainFrame
        /// A frame inside the page.
        case subframe
        /// A new window: a `target="_blank"` link, or `window.open`.
        case newWindow
    }

    /// What the browser does with one navigation.
    enum Decision: Equatable {
        /// Let WebKit load it.
        case allow
        /// Stop it, and load the address in this web view instead (a new-window link on the site).
        case loadHere(URL)
        /// Stop it, and hand the address to the system.
        case openOutside(URL)
        /// Stop it, and do nothing else.
        case cancel
    }

    /// The hosts that make up the site, each without a leading `www.`.
    private(set) var siteHosts: Set<String>

    /// Whether the opening page has committed. Until it has, a navigation is the opening load or
    /// one of its redirects.
    private(set) var openingPageCommitted = false

    /// A scope for a browser opened on `openingURL`.
    init(openingURL: URL) {
        siteHosts = Set([Self.siteHost(of: openingURL)].compactMap { $0 })
    }

    /// The host a site is known by: lowercased, without a leading `www.`; `nil` when there is none.
    static func siteHost(of url: URL) -> String? {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Records a commit in the main frame. The first one is the opening page's, whose host joins
    /// the site; later ones change nothing.
    mutating func didCommitMainFrame(at url: URL?) {
        guard !openingPageCommitted else { return }
        openingPageCommitted = true
        if let url, Self.isWeb(url), let host = Self.siteHost(of: url) {
            siteHosts.insert(host)
        }
    }

    /// Whether `url` is a web page on the site.
    func isOnSite(_ url: URL) -> Bool {
        guard Self.isWeb(url), let host = Self.siteHost(of: url) else { return false }
        return siteHosts.contains(host)
    }

    /// What to do with a navigation to `url` into `target`.
    ///
    /// - Parameter followedByReader: Whether the reader asked for it: a link followed or a form
    ///   sent (`WKNavigationType.linkActivated` or `.formSubmitted`). Anything else (a redirect, a
    ///   script, Back or Forward, a reload) is the page's own.
    func decision(for url: URL?, target: Target, followedByReader: Bool) -> Decision {
        guard let url, let scheme = url.scheme?.lowercased() else { return .cancel }
        if Self.pageOwnSchemes.contains(scheme) {
            // The page's own content: a blank or generated frame, never a site of its own. A new
            // window of it would replace this page with a blank one.
            return target == .newWindow ? .cancel : .allow
        }
        if scheme == "file" { return .cancel }
        guard Self.isWeb(url) else {
            // mailto:, tel: and the like: the system's, when the reader asked for one.
            return followedByReader || target == .newWindow ? .openOutside(url) : .cancel
        }
        switch target {
        case .newWindow:
            return isOnSite(url) ? .loadHere(url) : .openOutside(url)
        case .subframe:
            if !followedByReader || isOnSite(url) { return .allow }
            return .openOutside(url)
        case .mainFrame:
            if isOnSite(url) || !openingPageCommitted { return .allow }
            return followedByReader ? .openOutside(url) : .cancel
        }
    }

    /// The schemes whose content is the page's own.
    private static let pageOwnSchemes: Set<String> = ["about", "data", "blob"]

    private static func isWeb(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}

// MARK: - InAppBrowserWebView

#if os(iOS)
/// iOS `UIViewRepresentable` shell hosting the `WKWebView`.
private struct InAppBrowserWebView: UIViewRepresentable {
    let url: URL
    let navigator: InAppBrowserNavigator

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        navigator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> InAppBrowserCoordinator {
        InAppBrowserCoordinator(navigator: navigator, openingURL: url)
    }
}
#else
/// macOS `NSViewRepresentable` shell hosting the `WKWebView`.
private struct InAppBrowserWebView: NSViewRepresentable {
    let url: URL
    let navigator: InAppBrowserNavigator

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        navigator.webView = webView
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> InAppBrowserCoordinator {
        InAppBrowserCoordinator(navigator: navigator, openingURL: url)
    }
}
#endif

// MARK: - InAppBrowserCoordinator

/// `WKNavigationDelegate` that keeps the browser on its site and mirrors `WKWebView` navigation
/// state into an `InAppBrowserNavigator` after each navigation event settles.
///
/// `WKWebView`'s `canGoBack`/`canGoForward`/`title`/`url` are KVO properties
/// without a synchronous "did change" navigation-delegate callback, so this
/// coordinator re-reads them at the points where they're guaranteed to be
/// current: navigation start, commit, and finish/failure.
///
/// Every navigation is put to `InAppBrowserScope` first (`webView(_:decidePolicyFor:)`), and the
/// opening page's commit tells the scope which host it landed on (decision 136).
final class InAppBrowserCoordinator: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private let navigator: InAppBrowserNavigator

    /// The site the browser keeps to. Main-actor state: WebKit calls this delegate on the main
    /// thread, and each decision is made there.
    @MainActor private var scope: InAppBrowserScope

    /// Hands an address the browser does not follow to the system. A test passes its own, so that
    /// no test opens Safari or Mail.
    private let openOutside: @MainActor (URL) -> Void

    /// Called with each navigation's address and decision; `nil` in the app. A test reads WebKit's
    /// questions through it.
    @MainActor var onDecision: (@MainActor (URL?, InAppBrowserScope.Decision) -> Void)?

    /// - Parameters:
    ///   - navigator: The toolbar's state.
    ///   - openingURL: The page the browser opens on, whose site it keeps to.
    ///   - openOutside: Where an address the browser does not follow goes; the system by default.
    @MainActor
    init(navigator: InAppBrowserNavigator,
         openingURL: URL,
         openOutside: @escaping @MainActor (URL) -> Void = InAppBrowserCoordinator.openInSystem) {
        self.navigator = navigator
        self.scope = InAppBrowserScope(openingURL: openingURL)
        self.openOutside = openOutside
        super.init()
    }

    /// Opens `url` the way the system does: a web address in the default browser, `mailto:` in Mail.
    @MainActor
    static func openInSystem(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Puts each navigation to the scope: follows it, loads a new-window link here, hands it to the
    /// system, or stops it.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        let url = navigationAction.request.url
        let target: InAppBrowserScope.Target
        if let frame = navigationAction.targetFrame {
            target = frame.isMainFrame ? .mainFrame : .subframe
        } else {
            target = .newWindow
        }
        let followedByReader = navigationAction.navigationType == .linkActivated
            || navigationAction.navigationType == .formSubmitted
        return await MainActor.run(resultType: WKNavigationActionPolicy.self) {
            let decision = scope.decision(for: url, target: target, followedByReader: followedByReader)
            onDecision?(url, decision)
            switch decision {
            case .allow:
                return .allow
            case .loadHere(let destination):
                webView.load(URLRequest(url: destination))
                return .cancel
            case .openOutside(let destination):
                openOutside(destination)
                return .cancel
            case .cancel:
                return .cancel
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        sync(webView, isLoading: true)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Synchronously, so that the opening page's host is on the site before WebKit asks about
        // the page's next navigation. WebKit calls its delegate on the main thread.
        MainActor.assumeIsolated {
            scope.didCommitMainFrame(at: webView.url)
        }
        sync(webView, isLoading: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        sync(webView, isLoading: false)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        sync(webView, isLoading: false)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        sync(webView, isLoading: false)
    }

    /// `WKNavigationDelegate` callbacks land on the main thread but aren't
    /// `@MainActor`-isolated; hop over to the actor before touching the
    /// `@MainActor`-isolated navigator and re-reading the webView's KVO state.
    private func sync(_ webView: WKWebView, isLoading: Bool) {
        Task { @MainActor [navigator] in
            navigator.canGoBack = webView.canGoBack
            navigator.canGoForward = webView.canGoForward
            navigator.isLoading = isLoading
            navigator.pageTitle = webView.title ?? ""
            navigator.currentURL = webView.url
        }
    }
}
