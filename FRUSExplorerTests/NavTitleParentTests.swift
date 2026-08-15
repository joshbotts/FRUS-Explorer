// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FRUSExplorer

/// The principal title's parent line (UI review F-17).
///
/// ## What is worth testing here
/// Not the layout — that is `ViewThatFits`-adjacent geometry a unit test cannot see. What a test
/// can hold is **the string a VoiceOver reader hears**, which is the entire benefit of the parent
/// line for them and which is assembled by a `static` function precisely so it is reachable.
///
/// The sighted defect F-17 describes (a compilation screen that never names its volume) has an
/// exact non-sighted counterpart: two `Text`s inside a principal `VStack` are announced as two
/// unrelated labels unless the container claims them. `TwoLineNavTitleView` sets
/// `.accessibilityElement(children: .ignore)` and supplies one combined label, and these tests
/// pin the combination rather than trusting the modifier order.
///
/// Version history:
///   1.0 — CW-10 (UI review F-17)
@Suite("Nav title parent line")
struct NavTitleParentTests {

    @Test("with no parent the label is the bare title")
    func noParent() {
        #expect(TwoLineNavTitleView.accessibilityLabel(
            title: "Foreign Relations of the United States, 1969–1976, Volume XX",
            parent: nil) == "Foreign Relations of the United States, 1969–1976, Volume XX")
    }

    @Test("an empty parent is treated as absent, not spoken as a dangling 'in'")
    func emptyParent() {
        // `distilledVolumeLabel` cannot return empty for a real manifest row, but the property
        // feeding this is optional-chained off a manifest lookup that can miss — and ", in " with
        // nothing after it is worse than no parent at all.
        #expect(TwoLineNavTitleView.accessibilityLabel(title: "Chapter 3", parent: "")
                == "Chapter 3")
    }

    @Test("with a parent the ancestor is spoken after the title")
    func withParent() {
        #expect(TwoLineNavTitleView.accessibilityLabel(
            title: "Arab-Israeli Dispute",
            parent: "Soviet Union · 1969-76 v20") == "Arab-Israeli Dispute, in Soviet Union · 1969-76 v20")
    }

    @Test("the title leads, because it is what the screen is")
    func orderPutsTitleFirst() {
        let label = TwoLineNavTitleView.accessibilityLabel(title: "TITLE", parent: "PARENT")
        let titleIndex = label.range(of: "TITLE")
        let parentIndex = label.range(of: "PARENT")
        #expect(titleIndex != nil && parentIndex != nil)
        // A reader swiping through a bar wants the screen's own identity first; the ancestor is
        // context. Reversing these would make every compilation announce its volume first and
        // sound identical for a whole volume's worth of screens.
        #expect(titleIndex!.lowerBound < parentIndex!.lowerBound)
    }

    @Test("the short volume form is what rides the parent line, not the TEI title")
    func parentUsesDistilledForm() {
        // The regression this guards: passing `volume.title` would put the same
        // "Foreign Relations of the United States, …" boilerplate on the parent line that #237
        // built the two-line title to see past — so the ancestor line would be pure boilerplate
        // and name nothing.
        let distilled = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1969-76v20",
            subseries: "1969-76",
            title: "Foreign Relations of the United States, 1969–1976, Volume XX, Southeast Asia")
        #expect(!distilled.contains("Foreign Relations"))
        #expect(distilled.contains("1969-76"))
        #expect(distilled.contains("v20"))
    }
}
