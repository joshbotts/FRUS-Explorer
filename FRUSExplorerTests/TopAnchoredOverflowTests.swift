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

import SwiftUI
import Testing
import UIKit
@testable import FRUSExplorer

// MARK: - TopAnchoredOverflowTests

/// Content taller than its room runs out at the bottom, and the bars attached above and below it
/// stay at their edges (#1576 lane 3).
///
/// These lay the Search screen's arrangement out in small, in a real hosting controller in a
/// window of the test host's scene: content with one bar attached above it and one below as
/// safe-area insets. What the layout is for is what SwiftUI does with a view that is too tall,
/// which no value-level test can see. On the Search screen itself the list gives way before
/// this layout has anything to do, so the one test of it there is the Collocates reading at the
/// largest text size (`ResultSelectionBarFitTests`); this suite is the part that runs with the
/// unit target.
///
/// The window is 320 × 480 at the screen's origin. Each test reads the host's own safe-area
/// insets and measures from them, so a simulator left on its side by another suite, where the
/// insets are at the sides and the foot, does not fail these falsely.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Top-anchored overflow (#1576 lane 3)")
@MainActor
struct TopAnchoredOverflowTests {

    /// Where the hosted views were laid out, in the window.
    @Observable
    final class Probe {
        var topBar: CGRect = .null
        var bottomBar: CGRect = .null
        var content: CGRect = .null
    }

    /// What the content asks for.
    enum Content {
        /// A block that insists on a height.
        case fixed(CGFloat)
        /// A view that takes the room it is offered, as a list does.
        case filling
    }

    private nonisolated static let size = CGSize(width: 320, height: 480)
    private nonisolated static let barHeight: CGFloat = 40

    /// The arrangement: content, a bar above it and a bar below it.
    private struct Screen: View {
        let probe: Probe
        let content: Content
        /// Whether the content is inside the layout. `false` is the control.
        let anchored: Bool

        var body: some View {
            base
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.blue.frame(height: TopAnchoredOverflowTests.barHeight)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                            probe.topBar = $0
                        }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.green.frame(height: TopAnchoredOverflowTests.barHeight)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                            probe.bottomBar = $0
                        }
                }
        }

        @ViewBuilder
        private var base: some View {
            if anchored {
                TopAnchoredOverflow { block }
            } else {
                block
            }
        }

        @ViewBuilder
        private var block: some View {
            switch content {
            case .fixed(let height):
                Color.red.frame(height: height)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        probe.content = $0
                    }
            case .filling:
                Color.red
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        probe.content = $0
                    }
            }
        }
    }

    /// What one arrangement measured.
    struct Measured {
        let topBar: CGRect
        let bottomBar: CGRect
        let content: CGRect
        /// The host's safe-area insets: the status bar's at the top of an upright iPhone.
        let safe: UIEdgeInsets

        /// Where the top bar's head belongs.
        var top: CGFloat { safe.top }
        /// Where the bottom bar's foot belongs.
        var foot: CGFloat { TopAnchoredOverflowTests.size.height - safe.bottom }
        /// The room between the two bars.
        var room: CGFloat { foot - top - 2 * TopAnchoredOverflowTests.barHeight }
    }

    /// Whether two lengths are the same to within half a point.
    private func same(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= 0.5 }

    /// Hosts the arrangement in a window and answers where its three views were laid out.
    private func measure(_ content: Content, anchored: Bool) async throws -> Measured {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to lay out in")
        let probe = Probe()
        let controller = UIHostingController(rootView: Screen(probe: probe, content: content, anchored: anchored))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: Self.size)
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        // The frames are reported on a later turn of the main queue than the layout.
        for _ in 0..<150 where probe.topBar.isNull || probe.bottomBar.isNull || probe.content.isNull {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(!probe.topBar.isNull && !probe.bottomBar.isNull && !probe.content.isNull,
                     "the arrangement was not laid out in three seconds")
        // One more turn, so that a frame still moving is read where it came to rest.
        try await Task.sleep(for: .milliseconds(100))
        return Measured(topBar: probe.topBar, bottomBar: probe.bottomBar, content: probe.content,
                        safe: controller.view.safeAreaInsets)
    }

    @Test("Content taller than its room leaves both bars at their edges and starts under the top one")
    func tallContentLeavesTheBarsWhereTheyAre() async throws {
        let measured = try await measure(.fixed(900), anchored: true)
        try #require(measured.room < 900, "the fixture's content must be taller than the room")
        #expect(same(measured.topBar.minY, measured.top),
                "the top bar is at \(measured.topBar), not at the top of the safe area (\(measured.top))")
        #expect(same(measured.bottomBar.maxY, measured.foot),
                "the bottom bar is at \(measured.bottomBar), not at the foot of the safe area (\(measured.foot))")
        #expect(same(measured.content.minY, measured.topBar.maxY),
                "the content starts at \(measured.content.minY), not under the top bar (\(measured.topBar.maxY))")
        #expect(same(measured.content.height, 900), "the content keeps the height it needs: \(measured.content)")
    }

    /// The control, and the reason the layout exists. If this stops failing the bars, SwiftUI no
    /// longer centres a view that is too tall, and `TopAnchoredOverflow` can go.
    @Test("Control: without the layout the same content moves both bars off their edges")
    func withoutTheLayoutTheBarsMove() async throws {
        let measured = try await measure(.fixed(900), anchored: false)
        #expect(measured.topBar.minY < measured.top - 0.5,
                "the top bar stayed at \(measured.topBar): the premise of TopAnchoredOverflow no longer holds")
        #expect(measured.bottomBar.maxY > measured.foot + 0.5,
                "the bottom bar stayed at \(measured.bottomBar): the premise of TopAnchoredOverflow no longer holds")
    }

    @Test("Content that fits is laid out exactly where it is without the layout")
    func fittingContentIsNotMoved() async throws {
        let with = try await measure(.fixed(100), anchored: true)
        let without = try await measure(.fixed(100), anchored: false)
        try #require(with.room > 100, "the fixture's content must fit the room")
        #expect(with.content == without.content)
        #expect(with.topBar == without.topBar)
        #expect(with.bottomBar == without.bottomBar)
        #expect(same(with.content.height, 100))
    }

    @Test("Content that fills its room is given the room between the bars")
    func fillingContentGetsTheRoom() async throws {
        let measured = try await measure(.filling, anchored: true)
        #expect(same(measured.content.minY, measured.top + Self.barHeight)
                && same(measured.content.height, measured.room),
                "the content is at \(measured.content), not the \(measured.room) pt between the bars")
        #expect(same(measured.content.minX, measured.safe.left)
                && same(measured.content.width, Self.size.width - measured.safe.left - measured.safe.right),
                "the content is not as wide as the safe area: \(measured.content)")
        #expect(same(measured.topBar.minY, measured.top))
        #expect(same(measured.bottomBar.maxY, measured.foot))
    }

    @Test("The height reported is the content's where it fits and the room's where it does not")
    func reportedHeightIsNeverMoreThanTheRoom() {
        #expect(TopAnchoredOverflow.reportedHeight(needed: 500, offered: 300) == 300)
        #expect(TopAnchoredOverflow.reportedHeight(needed: 200, offered: 300) == 200)
        #expect(TopAnchoredOverflow.reportedHeight(needed: 300, offered: 300) == 300)
        // Asked for its ideal size, or offered everything, the content's own.
        #expect(TopAnchoredOverflow.reportedHeight(needed: 500, offered: nil) == 500)
        #expect(TopAnchoredOverflow.reportedHeight(needed: 500, offered: .infinity) == 500)
        // Asked for its smallest size, none at all: the layout can always give way.
        #expect(TopAnchoredOverflow.reportedHeight(needed: 500, offered: 0) == 0)
    }
}

// MARK: - SearchResultsColumnWiringTests

/// The Search screen's results are one column that gives way, inside the layout that keeps its
/// overflow from moving the bars (#1576 lane 3). Source scans, matched on the call.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
@Suite("Search results column, the wiring (#1576 lane 3)")
struct SearchResultsColumnWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// `source` without its comment lines and with every run of whitespace removed.
    private static func squeezedCode(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
            .filter { !$0.isWhitespace }
    }

    private static func squeezed(_ text: String) -> String { text.filter { !$0.isWhitespace } }

    /// The declaration that opens with `header`, to the line that closes it at the header's own
    /// indentation.
    private static func declaration(_ header: String, in source: String) throws -> String {
        let start = try #require(source.range(of: header), "\(header) is gone: moved or renamed?")
        let lineStart = source[..<start.lowerBound].lastIndex(of: "\n").map(source.index(after:)) ?? source.startIndex
        let indent = source[lineStart..<start.lowerBound]
        let close = try #require(source.range(of: "\n\(indent)}\n", range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<close.upperBound])
    }

    private static let view = "FRUSExplorer/Search/SearchView.swift"

    @Test("The navigation root's content is inside the layout, and every bar is attached outside it")
    func rootIsInsideTheLayout() throws {
        let source = try Self.source(Self.view)
        let code = Self.squeezedCode(source)
        #expect(code.contains(Self.squeezed("""
            NavigationStack(path: $vm.navigationPath) {
                TopAnchoredOverflow { resultsSection }
                    .background {
            """)), "the results must be the layout's content, with the modifiers on the layout")
        // Every inset is attached after the layout closes, so the bars are outside it.
        let body = try Self.declaration("var body: some View {", in: source)
        let layout = try #require(body.range(of: "TopAnchoredOverflow { resultsSection }"))
        #expect(!body[..<layout.lowerBound].contains(".safeAreaInset(edge:"),
                "an inset is attached before the layout")
        let insets = body[layout.upperBound...].components(separatedBy: ".safeAreaInset(edge:").count - 1
        #expect(insets >= 2, "the body attaches the banners and the bars: found \(insets) insets")
    }

    /// The layout lays each of its views from the top over the others, so a branch of two
    /// siblings would be drawn one on the other. This holds the results branch, which was three
    /// siblings, to one view; the other branches were each one view already and are not checked.
    @Test("The results branch is one view: the column")
    func resultsBranchIsTheColumn() throws {
        let section = Self.squeezedCode(try Self.declaration("private var resultsSection: some View {",
                                                             in: try Self.source(Self.view)))
        #expect(section.contains(Self.squeezed("""
            } else if !vm.results.isEmpty {
                resultsColumn
            } else {
                initialPromptView
            }
            """)))
        #expect(!section.contains("resultCountHeader") && !section.contains("checklistHiddenBanner"),
                "the header and the strip belong to the column, not to the section's own stack")
    }

    @Test("The fixed rows take their height where they fit half the column, and scroll where they do not")
    func fixedRowsGiveWay() throws {
        let source = try Self.source(Self.view)
        let column = Self.squeezedCode(try Self.declaration("private var resultsColumn: some View {", in: source))
        #expect(column.contains(Self.squeezed("""
            let rows = resultsFixedRows
            return VStack {
                ViewThatFits(in: .vertical) {
                    rows
                    ScrollView { rows }
                        .scrollBounceBehavior(.basedOnSize)
                        .id(vm.bulkOutcomeSerial)
                }
                resultsReading
            }
            """)), "the rows built once; the plain rows first, then the same rows in a scroll view, above the reading")
        let rows = Self.squeezedCode(try Self.declaration("private var resultsFixedRows: some View {", in: source))
        #expect(rows.contains(Self.squeezed("""
                resultCountHeader
                checklistHiddenBanner
            }
            """)), "the count header and the checklist's strip are among the rows that give way")
        let reading = try Self.declaration("private var resultsReading: some View {", in: source)
        #expect(reading.contains("resultsList"), "the list is the reading under the fixed rows")
        #expect(!reading.contains("resultCountHeader") && !reading.contains("checklistHiddenBanner"))
    }
}
