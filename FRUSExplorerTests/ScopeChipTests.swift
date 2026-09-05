// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import SwiftUI
import Foundation
@testable import FRUSExplorer

// MARK: - ScopeChipTests

/// The three chips that decide which FTS5 columns the macOS Search window queries.
///
/// **The headline test is `stateSurvivesTheLossOfColour`.** The chip shipped with `isOn` driving
/// its fill, its foreground and its stroke colour and **nothing else** — same text, same font, same
/// padding, no glyph — under a `.buttonStyle(.plain)` that suppresses any system selected chrome,
/// and with no accessibility traits, value or label, so VoiceOver read "Documents, button" whether
/// the scope was searched or not. Since all three off makes `performSearch` refuse the query
/// outright, that was a reachable dead end with nothing on screen explaining it.
///
/// **These call the chip's own rules, not a copy of them.** Every assertion below drives a `static
/// func` that ``ScopeChip``'s `body` calls — which is the whole reason the chip was lifted out of
/// `SearchSheet.swift`'s `#if os(macOS)` block, since a macOS-only type would leave the iOS suite
/// nothing to test but a source scan, and this repo's record with those is that they stay green
/// against deleted code (see `ColorIndependenceTests`' note on `tagBackground`). The one scan that
/// remains here is deliberately narrow: it pins that the `body` renders *through* those rules
/// rather than spelling its own, which is the single thing calling the functions cannot prove.
///
/// Version history:
///   1.0 — the scope chip gains a non-colour channel
@Suite("Search scope chip")
struct ScopeChipTests {

    // MARK: - The property this suite exists for

    /// Strip the colour and the state is still readable — in shape, and in words.
    ///
    /// One test rather than three because it is one claim: the two states differ in the glyph a
    /// sighted reader sees and in the value VoiceOver speaks, and neither of those is a hue.
    @Test("On and off survive the loss of colour")
    func stateSurvivesTheLossOfColour() {
        // The shape channel: two states, two glyphs.
        #expect(ScopeChip.glyph(isOn: true) != ScopeChip.glyph(isOn: false),
                "both states draw the same glyph, so the only thing left is the tint")
        #expect(!ScopeChip.glyph(isOn: true).isEmpty)
        #expect(!ScopeChip.glyph(isOn: false).isEmpty,
                "the off state draws no glyph, so its state is legible only as an absence")

        // The spoken channel: two states, two sentences.
        #expect(ScopeChip.accessibilityValue(isOn: true)
                != ScopeChip.accessibilityValue(isOn: false),
                "VoiceOver reads the same value in both states")
        for isOn in [true, false] {
            let spoken = ScopeChip.accessibilityValue(isOn: isOn)
            #expect(!spoken.isEmpty)
            #expect(!spoken.contains("%@"), "unsubstituted format in the \(isOn) value")
        }
    }

    // MARK: - The shape channel

    /// A checkbox, in the two states a checkbox has.
    ///
    /// The exact symbols are pinned because the pair is a decision rather than a detail: both are
    /// circle-based, so the two states have the same metric width and a row of three chips does not
    /// reflow as the pointer toggles one.
    @Test("The glyph is a checkbox: filled when searched, empty when not")
    func glyphIsACheckbox() {
        #expect(ScopeChip.glyph(isOn: true) == "checkmark.circle.fill")
        #expect(ScopeChip.glyph(isOn: false) == "circle")
    }

    /// The glyph does **not** switch on `accessibilityDifferentiateWithoutColor`.
    ///
    /// Same rule `ProvenanceChip` states: the shape always carries the state, so producing it only
    /// for readers who set the key would be theatre — and would imply that everyone else was being
    /// asked to read a hue. `glyph(isOn:)`'s own signature is half the assertion — it cannot see
    /// the environment — and the other half is that the chip never reads the key at all, since a
    /// `body` holding the property could still pick the symbol itself.
    @Test("The glyph is unconditional")
    func glyphDoesNotDependOnTheEnvironment() throws {
        let source = try Self.chipSource()
        #expect(!source.contains("@Environment(\\.accessibilityDifferentiateWithoutColor)"),
                "the chip reads the differentiate-without-colour key, so its non-colour channel risks being conditional on a setting most readers never touch")
    }

    // MARK: - The spoken channel

    /// The value says what the control does, not merely that it is on.
    @Test("The spoken value names the searching, not the switch")
    func spokenValueNamesTheSearching() {
        #expect(ScopeChip.accessibilityValue(isOn: true) == "Searched")
        #expect(ScopeChip.accessibilityValue(isOn: false) == "Not searched")
    }

    // MARK: - The colour channel, which may be present but never alone

    /// The tint still moves — this is an addition, not a swap.
    ///
    /// Without this the suite would pass over a chip that had traded its colour channel for a
    /// glyph, which is not the fix: a sighted reader scanning the row at a glance reads the wash
    /// first.
    @Test("The tint still distinguishes the two states")
    func tintStillMoves() {
        #expect(ScopeChip.foreground(isOn: true) != ScopeChip.foreground(isOn: false))
        #expect(ScopeChip.fill(isOn: true) != ScopeChip.fill(isOn: false))
        #expect(ScopeChip.border(isOn: true) != ScopeChip.border(isOn: false))
    }

    // MARK: - Wiring

    /// The chip's source, for the two checks that cannot be made by calling a function.
    private static func chipSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/App/ScopeChip.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The body must render the shared rules rather than spelling its own.
    ///
    /// A narrow scan of the calls, not of the file: every rule above is a `static func`, which a
    /// `body` could ignore entirely while this suite stayed green.
    @Test("The body renders through the shared rules")
    func bodyCallsTheSharedRules() throws {
        let source = try Self.chipSource()
        guard let body = source.range(of: "var body: some View {") else {
            Issue.record("ScopeChip has no body")
            return
        }
        let rendered = String(source[body.lowerBound...])
        for call in ["Self.glyph(isOn: isOn)",
                     "Self.accessibilityValue(isOn: isOn)",
                     "Self.foreground(isOn: isOn)",
                     "Self.fill(isOn: isOn)",
                     "Self.border(isOn: isOn)"] {
            #expect(rendered.contains(call), "body does not call \(call)")
        }

        // The trait is the platform's own idiom for a chip in a selectable set, and it is the half
        // of the spoken channel a function cannot return.
        #expect(rendered.contains("accessibilityAddTraits(isOn ? AccessibilityTraits.isSelected"),
                "the chip does not mark its on state as selected")
        #expect(rendered.contains("accessibilityLabel(label)"),
                "the chip does not name itself, so its value has nothing to qualify")

        // **The glyph must be hidden from VoiceOver.** `Image(systemName:)` is an accessibility
        // element that speaks its SF Symbol name, so left visible it reads "checkmark circle fill"
        // — a shape, where the reader asked for the state.
        guard let glyphAt = rendered.range(of: "Image(systemName: Self.glyph(isOn: isOn))"),
              let hiddenAt = rendered.range(of: "accessibilityHidden(true)") else {
            Issue.record("the chip does not hide its glyph from VoiceOver")
            return
        }
        #expect(glyphAt.lowerBound < hiddenAt.lowerBound,
                "the hidden modifier does not apply to the glyph")
    }

    /// The chip names are localized at the mount site.
    ///
    /// The three labels were raw literals — `ScopeChip(label: "Documents", …)` — beside `.help`
    /// strings that were not, in a file the coding standards require to hold no raw user-facing
    /// text. This reads the mount site rather than trusting the fix to stay applied.
    @Test("Every scope chip is mounted with a localized name")
    func chipLabelsAreLocalized() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/App/SearchSheet.swift")
        let sheet = try String(contentsOf: url, encoding: .utf8)

        var mounted = 0
        for line in sheet.components(separatedBy: .newlines) where line.contains("ScopeChip(") {
            // **Prose that names the type is not a mount.** This scan and
            // `MacChromeHonestyTests.everyScopeChipIsWired` both key on the type name followed by
            // an open paren, and the first run of this test failed against a doc comment in the
            // scope row that spelled the pair while explaining that very scan. The comment has
            // been reworded; the filter is here so the next one does not have to be.
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            guard let range = line.range(of: "label: ") else {
                Issue.record("a ScopeChip is mounted with no label: \(line)")
                continue
            }
            let argument = line[range.upperBound...].drop { $0 == " " }
            #expect(!argument.hasPrefix("\""),
                    "a scope chip's name is a raw literal, which ships unlocalized: \(line.trimmingCharacters(in: .whitespaces))")
            mounted += 1
        }
        // Guard against a vacuous pass: with no chips parsed every assertion above is trivially
        // true and this test would go green having measured nothing.
        #expect(mounted == 3, "expected the three scope chips, parsed \(mounted)")

        // The names themselves resolve through the localization machinery, and the wording is the
        // one that shipped — no String Catalog exists, so each `defaultValue:` *is* the string on
        // screen.
        for key in ["search.scope.documents.label",
                    "search.scope.notes.label",
                    "search.scope.summaries.label",
                    "search.scope.searchIn"] {
            #expect(sheet.contains("String(localized: \"\(key)\""), "\(key) is not declared")
        }
        #expect(sheet.contains("defaultValue: \"Documents\""))
        #expect(sheet.contains("defaultValue: \"Notes\""))
        #expect(sheet.contains("defaultValue: \"Summaries\""))
        #expect(sheet.contains("defaultValue: \"Search in\""))
    }
}
