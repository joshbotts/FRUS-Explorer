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

/// One of the three chips in the macOS Search window's "Search in" row: Documents, Notes,
/// Summaries.
///
/// ## Why this chip is not decoration
///
/// The three chips bind to `MacSearchViewModel.scopeDocuments` / `scopeNotes` / `scopeSummaries`,
/// which project into `SearchParameters.includeDocumentText` / `includeNotes` / `includeSummaries`
/// and so decide **which FTS5 columns are searched**. Turn all three off and
/// `MacSearchViewModel.performSearch` short-circuits with an error instead of querying. A reader
/// who cannot see which chips are on can reach that error with no way to work out why — which is
/// the difference between this and a chip that merely tints a label.
///
/// ## The state is in the glyph, not in the tint
///
/// Until this file existed, `isOn` drove exactly three things — the fill, the foreground and the
/// stroke colour — and nothing else. Same `Text`, same font, same padding, no glyph, no shape
/// change; `.buttonStyle(.plain)` suppresses whatever selected chrome the system would otherwise
/// draw. So the on/off distinction was **hue alone on screen and nothing at all to VoiceOver**,
/// which announced "Documents, button" in both states.
///
/// It now carries a checkbox glyph — `checkmark.circle.fill` filled when on, an empty `circle`
/// when off — which separates the two states in greyscale, under any colour vision, and at any
/// tint the accent colour happens to be. The sibling `FilterChip` in `SearchSheet.swift` already
/// held this line (its active state shows the value plus a clear button, its inactive an italic
/// "any"); this chip was the outlier, and `ProvenanceChip` is the pattern being followed —
/// **shape, words, and a spoken sentence, with the colour never load-bearing**.
///
/// **Both glyphs are circle-based on purpose.** SF Symbols in one family share a metric width, so
/// toggling a chip does not resize it and the row of three does not reflow under the pointer.
///
/// **The glyph is unconditional — it does not switch on
/// `accessibilityDifferentiateWithoutColor`.** Same reasoning as `ProvenanceChip`: the shape
/// always carries the state, so making it appear only when a reader has set that key would be
/// theatre, and would imply the unswitched chip needed colour. Nor is the *tint* dropped under
/// that key, which is where this chip departs from `ProvenanceChip` and the reason is measured
/// rather than preferred: the provenance chip asks a reader to tell three hues apart, where this
/// one contrasts the accent colour with `.secondary` — a difference in lightness as much as in
/// hue, and binary rather than three-way. Neutralising it would remove a cue that works and
/// replace it with nothing.
///
/// ## Two channels for VoiceOver, deliberately
///
/// ``accessibilityValue(isOn:)`` supplies the word, and `.isSelected` supplies the trait. The
/// trait is the platform's own idiom for a chip that is part of a selectable set and is what a
/// VoiceOver user hears as "selected"; the value is what survives a host that flattens traits, and
/// it is the only one of the two that a test can read back. Neither is the visible channel — that
/// is the glyph — so a change to one is not a licence to drop the other.
///
/// **The glyph is `.accessibilityHidden`.** `Image(systemName:)` is an accessibility element that
/// speaks its SF Symbol name, so left visible it would read "checkmark circle fill, Documents" and
/// give a VoiceOver user a shape they cannot act on in place of the state they asked for.
///
/// ## Why the chip lives here rather than in `SearchSheet.swift`
///
/// It was a `private struct` inside that file, which is wrapped whole in `#if os(macOS)`. The
/// rules below would then not exist on iOS, so the only test the iOS suite could run against them
/// would be a source scan — and this repo's record with those is that they go green against code
/// that has been deleted. Declared here, unguarded, the static rules compile into both targets and
/// ``ScopeChipTests`` calls them directly. The view is still mounted only from the macOS Search
/// window.
///
/// Version history:
///   1.0 — extracted from `SearchSheet.swift`; the state gains a glyph and a spoken value
struct ScopeChip: View {

    /// The scope's visible name — "Documents", "Notes", "Summaries".
    ///
    /// Localized by the caller rather than here, because the row that mounts these chips is also
    /// what pairs each one with its `.help` text, and splitting one scope's two strings across two
    /// files is how they come to disagree.
    let label: String

    /// Whether this scope is searched. Bound to the view model property that projects into
    /// `SearchParameters`.
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: Self.glyph(isOn: isOn))
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(label)
            }
            .font(.subheadline)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Self.fill(isOn: isOn))
            .foregroundStyle(Self.foreground(isOn: isOn))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Self.border(isOn: isOn), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(Self.accessibilityValue(isOn: isOn))
        .accessibilityAddTraits(isOn ? AccessibilityTraits.isSelected : [])
    }

    // MARK: - The shape channel

    /// A filled checkmark when the scope is searched, an empty ring when it is not.
    ///
    /// Unconditional — see the type's note on why this does not switch on
    /// `accessibilityDifferentiateWithoutColor`.
    static func glyph(isOn: Bool) -> String {
        isOn ? "checkmark.circle.fill" : "circle"
    }

    // MARK: - The spoken channel

    /// What VoiceOver reads as the chip's value.
    ///
    /// "Searched" rather than "On", because what the control decides is whether the query reaches
    /// this body of text — the same thing the neighbouring `.help` prose says in longer form.
    static func accessibilityValue(isOn: Bool) -> String {
        isOn
            ? String(localized: "search.scope.chip.value.on", defaultValue: "Searched")
            : String(localized: "search.scope.chip.value.off", defaultValue: "Not searched")
    }

    // MARK: - The colour channel, which is never the only one

    /// The label and glyph colour.
    static func foreground(isOn: Bool) -> Color {
        isOn ? Color.accentColor : Color.secondary
    }

    /// The wash behind the chip.
    ///
    /// The four opacities here and in ``border(isOn:)`` are the ones this chip shipped with and are
    /// deliberately unchanged: adding the glyph is a fix to the *channel count*, and a simultaneous
    /// retune would make it impossible to tell which half of the diff moved the screen.
    static func fill(isOn: Bool) -> Color {
        isOn ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)
    }

    /// The hairline that makes the chip read as an object rather than a stain.
    static func border(isOn: Bool) -> Color {
        isOn ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2)
    }
}
