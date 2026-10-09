// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Accessibility
import Foundation
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif

@testable import FRUSExplorer

// MARK: - TransientToastTests

/// The confirmation toast tells VoiceOver what it says (#1594).
///
/// Three results are shown only as a toast: an Archives Visit duplicated, an inquiry topic
/// re-seeded, and documents added to a collection. The toast's comment said it was "announced to
/// VoiceOver" from the day it was written, and nothing posted an announcement, so a VoiceOver user
/// heard nothing and the capsule cleared in 2.6 seconds.
///
/// **What these tests do not hold: that the announcement is heard.** No test target can listen
/// to VoiceOver. They hold what is sent and that the one modifier every toast goes through sends
/// it. Whether it is spoken after a menu closes and after a sheet is dismissed needs VoiceOver
/// on an iPhone and on the Mac.
///
/// Version history:
///   1.0 — 2026-10-09: #1594 — initial implementation
@Suite("The confirmation toast is announced to VoiceOver (#1594)")
struct TransientToastTests {

    @Test("The announcement is the toast's own words, at high priority")
    func announcementIsTheMessageAtHighPriority() {
        let message = "Duplicated as “Kennan papers copy”"
        let announcement = TransientToast.announcement(message)
        #expect(String(announcement.characters) == message)
        // High, because a toast appears as a menu or a sheet closes, when VoiceOver is about to
        // speak the element its focus lands on: a default-priority announcement can be cut off.
        #expect(announcement.accessibilitySpeechAnnouncementPriority == .high)
    }

    @Test("The announcement is posted while the toast is up")
    func announcementFallsInsideTheToast() {
        #expect(TransientToast.duration == .seconds(2.6))
        #expect(TransientToast.announcementDelay > .zero)
        #expect(TransientToast.announcementDelay < TransientToast.duration)
    }

    /// The modifier is the one place a toast is drawn, so posting there covers every toast on both
    /// platforms. Read from the source: a view modifier's task cannot be run from a unit test.
    @Test("The toast's modifier posts the announcement, and a cancelled toast clears nothing")
    func modifierPostsTheAnnouncement() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("FRUSExplorer/Theme/ControlHelp.swift"),
                                encoding: .utf8)
        let start = try #require(source.range(of: "private struct TransientToastModifier: ViewModifier {"))
        let modifier = try #require(WindowTargetingTests.balancedBlock(in: source, from: start.lowerBound))

        let post = try #require(modifier.range(
            of: "AccessibilityNotification.Announcement(TransientToast.announcement(message)).post()"))
        let clear = try #require(modifier.range(of: "withAnimation { self.message = nil }"))
        #expect(post.lowerBound < clear.lowerBound, "the announcement is posted after the toast is cleared")
        // A toast replaced by another has its task cancelled. With `try?` on its sleeps the
        // cancelled task went on to clear the message, and so the toast that replaced it.
        #expect(!modifier.contains("try? await Task.sleep"))
        #expect(modifier.contains("} catch {\n                                return\n"))
    }

    /// Every toast in the app goes through `transientToast(_:)`. Measured 2026-10-09: three mounts.
    /// A fourth is welcome; none must draw its own capsule and skip the announcement.
    @Test("The three screens that show a toast mount the shared modifier")
    func everyToastIsTheSharedOne() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let mounts = [
            "FRUSExplorer/TripPacket/ArchiveVisitEditorView.swift": ".transientToast($toast)",
            "FRUSExplorer/Collections/CollectionEditorView.swift": ".transientToast($addDocumentsToast)",
            "FRUSExplorer/Collections/MacCollectionManagerView.swift": ".transientToast($addDocumentsToast)",
        ]
        for (path, call) in mounts {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            #expect(source.contains(call), "\(path) no longer mounts \(call)")
        }
    }
}

#if canImport(UIKit)
// MARK: - TransientToastLifetimeTests

/// A toast's own life in a window: it clears itself, and a toast that replaces it is left alone (#1594).
///
/// The modifier's task used `try?` on its sleep. Setting a second message cancels the first
/// toast's task, a cancelled sleep throws at once, and `try?` let that task carry on to
/// `message = nil`, which by then was the second toast. Found while adding the announcement, since
/// the task now has two sleeps and a cancellation between them must post nothing.
///
/// Hosted in the test host's window, because a modifier's `.task` runs only for a view on screen.
///
/// Version history:
///   1.0 — 2026-10-09: #1594 — initial implementation
@Suite("A confirmation toast clears itself, and not the toast that replaced it (#1594)", .serialized)
@MainActor
struct TransientToastLifetimeTests {

    /// Holds the message the modifier is bound to, and the window it is drawn in.
    @MainActor
    @Observable
    final class Host {
        /// The toast's message; the modifier sets it to nil when the toast is over.
        var message: String?
        @ObservationIgnored private var window: UIWindow?

        init() throws {
            let scene = try #require(
                UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
                "The test host has no window scene to host the toast in")
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(rootView: Probe(host: self))
            window.isHidden = false
            window.layoutIfNeeded()
            self.window = window
        }
    }

    /// A blank view with the toast mounted on it, as the three screens mount it.
    private struct Probe: View {
        @Bindable var host: Host
        var body: some View { Color.clear.transientToast($host.message) }
    }

    /// Waits until `condition` holds or `timeout` passes, and says which.
    private func wait(_ timeout: Duration, until condition: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            if ContinuousClock.now >= deadline { return false }
            try await Task.sleep(for: .milliseconds(50))
        }
        return true
    }

    @Test("A second toast set while the first is up stays up, and clears itself in its own time")
    func aReplacedToastDoesNotClearItsSuccessor() async throws {
        let host = try Host()
        host.message = "Duplicated as “Kennan papers copy”"
        try await Task.sleep(for: .milliseconds(400))
        #expect(host.message == "Duplicated as “Kennan papers copy”", "the first toast is up")

        // The second Duplicate, inside the first toast's 2.6 seconds.
        host.message = "Duplicated as “Kennan papers copy 2”"
        // The first toast's task is cancelled here. With `try?` on its sleep it cleared the
        // message on its next turn; the second toast's own clearing is 2.6 seconds away.
        try await Task.sleep(for: .milliseconds(800))
        #expect(host.message == "Duplicated as “Kennan papers copy 2”",
                "the toast that replaced the first was cleared by the first one's task")

        // And it clears itself.
        #expect(try await wait(.seconds(15)) { host.message == nil }, "the second toast never cleared")
    }

    @Test("A toast left alone clears itself, no sooner than it should")
    func aToastClearsItself() async throws {
        let host = try Host()
        host.message = "Added 3 documents"
        // Still up after the announcement's delay: posting it does not end the toast.
        try await Task.sleep(for: TransientToast.announcementDelay + .milliseconds(500))
        #expect(host.message == "Added 3 documents")
        #expect(try await wait(.seconds(15)) { host.message == nil }, "the toast never cleared")
    }
}
#endif
