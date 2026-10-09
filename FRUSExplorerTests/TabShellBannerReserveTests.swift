// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import FRUSExplorer

/// The tab shell's banner is drawn in room its host sets aside, and a list inside a navigation stack ends above it
/// (#1565).
///
/// These drive `View.tabShellBanner` itself, in a real hosting controller in a window of the test host's scene: the
/// defect was in what UIKit does with an inset, which no value-level test can see. `TabShellBannerClearanceTests`
/// measures the same thing on the app's own screens; this suite is the part that runs with the unit target.
///
/// The window is 320 × 480 at the screen's origin, so its bottom edge is clear of the home indicator and the only
/// bottom safe-area inset in it is the one the banner's reserve adds.
///
/// Version history:
///   1.0 — #1565: initial implementation
@Suite("Tab shell banner — the room its host sets aside (#1565)")
@MainActor
struct TabShellBannerReserveTests {

    /// What a hosted view reports back, and the banner height it is told to draw.
    @Observable
    final class Probe {
        /// The banner's height. Zero draws no banner at all, as while the keyboard is up.
        var bannerHeight: CGFloat = 0
        /// The banner's frame in the window, once it has been laid out.
        var bannerFrame: CGRect = .null
        /// Whether the hosted view carries the banner's modifier at all. See ``Removable``.
        var hasShell = true
    }

    /// A view that carries the shell's banner until the probe says otherwise, for the test that takes it away.
    private struct Removable: View {
        let probe: Probe

        var body: some View {
            if probe.hasShell {
                Color.white.tabShellBanner { ProbeBanner(probe: probe) }
            } else {
                Color.white
            }
        }
    }

    /// The banner the suite draws: a block of the probe's height, or nothing.
    private struct ProbeBanner: View {
        let probe: Probe

        var body: some View {
            if probe.bannerHeight > 0 {
                Color.red
                    .frame(height: probe.bannerHeight)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        probe.bannerFrame = frame
                    }
            }
        }
    }

    private static let size = CGSize(width: 320, height: 480)

    /// Hosts `content` under the banner in a window, and removes the window when `body` returns.
    private func withHost<Content: View>(
        _ probe: Probe, @ViewBuilder content: () -> Content,
        body: (UIHostingController<AnyView>, UIWindow) async throws -> Void
    ) async throws {
        try await withHost(root: content().tabShellBanner { ProbeBanner(probe: probe) }, body: body)
    }

    /// Hosts `root` as it is in a window, and removes the window when `body` returns.
    private func withHost<Root: View>(
        root: Root, body: (UIHostingController<AnyView>, UIWindow) async throws -> Void
    ) async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to lay out in")
        let controller = UIHostingController(rootView: AnyView(root))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        try await body(controller, window)
    }

    /// Waits up to three seconds for `condition`, letting the main queue run between looks. The reserve is applied
    /// on a later turn of the main queue than the update that asked for it, so nothing here can be read at once.
    private func settles(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<150 {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    /// The first collection view under `view`: the UIKit list a SwiftUI `List` is drawn by.
    private func collectionView(in view: UIView) -> UICollectionView? {
        if let found = view as? UICollectionView { return found }
        for subview in view.subviews {
            if let found = collectionView(in: subview) { return found }
        }
        return nil
    }

    @Test("The host's bottom inset follows the banner's height, up, down and back to nothing")
    func hostInsetFollowsTheBanner() async throws {
        let probe = Probe()
        probe.bannerHeight = 40
        try await withHost(probe) {
            Color.white
        } body: { controller, _ in
            // Each height in turn. Zero is no banner at all, as while the keyboard is up (#1070): the room goes back.
            for height in [40, 64, 0, 40] as [CGFloat] {
                probe.bannerHeight = height
                let reserved = try await settles { controller.additionalSafeAreaInsets.bottom == height }
                #expect(reserved, """
                    a banner \(height) points tall left the host reserving                     \(controller.additionalSafeAreaInsets.bottom) points
                    """)
            }
        }
    }

    @Test("The banner is drawn in exactly the room set aside, at the bottom of the window")
    func bannerFillsTheReservedRoom() async throws {
        let probe = Probe()
        probe.bannerHeight = 40
        try await withHost(probe) {
            Color.white
        } body: { controller, _ in
            let expected = CGRect(x: 0, y: Self.size.height - 40, width: Self.size.width, height: 40)
            let placed = try await settles {
                controller.additionalSafeAreaInsets.bottom == 40 && probe.bannerFrame == expected
            }
            #expect(placed, "the banner is at \(probe.bannerFrame), not \(expected)")
        }
    }

    @Test("The room is given back when the view that drew the banner goes away")
    func roomIsGivenBackWithTheView() async throws {
        let probe = Probe()
        probe.bannerHeight = 40
        try await withHost(root: Removable(probe: probe)) { controller, _ in
            let reserved = try await settles { controller.additionalSafeAreaInsets.bottom == 40 }
            #expect(reserved, "a 40-point banner reserved \(controller.additionalSafeAreaInsets.bottom) points")
            probe.hasShell = false
            let givenBack = try await settles { controller.additionalSafeAreaInsets.bottom == 0 }
            #expect(givenBack, """
                with the banner's view gone the host still reserves \(controller.additionalSafeAreaInsets.bottom) \
                points
                """)
        }
    }

    @Test("A list inside a navigation stack is inset by the banner's height")
    func listInsideAStackEndsAboveTheBanner() async throws {
        let probe = Probe()
        try await withHost(probe) {
            NavigationStack {
                List(0..<60, id: \.self) { Text(verbatim: "Row \($0)") }
            }
        } body: { controller, window in
            // The control first, with no banner: the list's own bottom inset in this window.
            let drawn = try await settles { self.collectionView(in: window) != nil }
            #expect(drawn, "the hosted List drew no collection view")
            let list = try #require(collectionView(in: window))
            let bare = list.adjustedContentInset.bottom
            #expect(controller.additionalSafeAreaInsets.bottom == 0)

            probe.bannerHeight = 40
            let inset = try await settles { list.adjustedContentInset.bottom == bare + 40 }
            #expect(inset, """
                under a 40-point banner the list's bottom inset is \(list.adjustedContentInset.bottom), not                 \(bare + 40): the stack did not pass the reserve on to it
                """)
        }
    }
}
#endif
