// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Accessibility
import Foundation
import Testing

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
