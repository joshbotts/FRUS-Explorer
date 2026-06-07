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
/// `AboutView`, `OnboardingIntroView`, and `IndexingEducationView` embed a
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
        let destination = navigator.currentURL ?? url
        #if os(iOS)
        UIApplication.shared.open(destination)
        #else
        NSWorkspace.shared.open(destination)
        #endif
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
        InAppBrowserCoordinator(navigator: navigator)
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
        InAppBrowserCoordinator(navigator: navigator)
    }
}
#endif

// MARK: - InAppBrowserCoordinator

/// `WKNavigationDelegate` that mirrors `WKWebView` navigation state into an
/// `InAppBrowserNavigator` after each navigation event settles.
///
/// `WKWebView`'s `canGoBack`/`canGoForward`/`title`/`url` are KVO properties
/// without a synchronous "did change" navigation-delegate callback, so this
/// coordinator re-reads them at the points where they're guaranteed to be
/// current: navigation start, commit, and finish/failure.
final class InAppBrowserCoordinator: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private let navigator: InAppBrowserNavigator

    init(navigator: InAppBrowserNavigator) {
        self.navigator = navigator
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        sync(webView, isLoading: true)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
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
