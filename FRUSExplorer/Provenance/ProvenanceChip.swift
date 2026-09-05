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

/// The one chip that says where a displayed value came from.
///
/// **Declared once and mounted by both platforms, because this repo's record is that the twins
/// drift on exactly this kind of edit.** `SourceExplorerView` and `MacSourceExplorerView` differ by
/// four spaces of indentation in places, which is enough to make a scripted patch no-op on one of
/// them; `ConfidenceChip` exists because the same capsule had already been written into both. A
/// provenance vocabulary written twice is two places for it to diverge, and a reader comparing the
/// Mac and iPad screens would have no way to tell which one was right.
///
/// ## Three channels, and colour is the one that may be ignored
///
/// The chip states its source in **shape**, in **words**, and in a **VoiceOver sentence**. The tint
/// is a fourth channel and it is never the only one — that line holds unconditionally, not only
/// when the reader has asked for it. `ConfidenceChip` set the precedent ("the *word* is the
/// signal") and it is the right one.
///
/// ``glyph(for:)`` is therefore **not** switched on
/// `accessibilityDifferentiateWithoutColor`. `WordCloudView` — the only other reader of that key in
/// the tree — swaps a neutral `circle.fill` for `plus.circle.fill`/`minus.circle.fill`, because
/// there the shape carries nothing until the key is set. Here the shape always carries the tier, so
/// switching on the key would be theatre.
///
/// What the key does change is the **tint**, which is dropped for the label colour. That is a real
/// improvement rather than a gesture: under protanopia the ruby and the graphite converge, so three
/// washes a reader cannot tell apart are noise, and a neutral label sits far above the ~6.7:1 the
/// tinted one measures. ``ProvenanceChipTests`` pins the property directly — under the key all
/// three tiers share one foreground while their glyphs stay distinct.
///
/// ## What each part is worth, measured
///
/// Text, against `#F2F2F7` light and `#1C1C1E` dark: **6.67/6.10** (FRUS), **7.09/6.97** (joined),
/// **6.74/7.54** (computed) — all above the 4.5:1 this size requires.
///
/// The 12% wash sits at **1.19–1.25:1** against the page, so what a reader perceives is the chip's
/// *text*, not its fill. The hairline is what makes the capsule read as an object, exactly as
/// `headnotePurpleBorder` does for the headnote card — and it is **decorative at 1.63–1.94:1**,
/// deliberately short of WCAG 1.4.11's 3:1. 1.4.11 governs visuals *required to identify a
/// component*, and nothing here rests on the ring: the label identifies the chip at 6.1:1 or better
/// and the glyph beside it does too. Reaching 3:1 would take ~0.70 alpha, which at `.caption2` is a
/// heavy outline and abandons the app's own border idiom for no gain a reader can use.
///
/// ## Two things a mounting row can do to this chip
///
/// **A container accessibility label silently swallows it.** `SearchView`'s result rows are the
/// live example: a `Button` wrapping `SearchResultRow` sets `.accessibilityLabel(result.header)`,
/// and every chip inside — `ClassificationChip`'s label, `SemanticScoreChip`'s text — goes
/// unannounced. ``accessibilityLabel(for:)`` is deliberately callable on its own so a row in that
/// shape can fold the sentence into its own label instead of losing it.
///
/// **The glyph is an `HStack`, not a `Label`, on purpose.** `Label` renders icon-only in a macOS
/// toolbar unless `.labelStyle(.titleAndIcon)` is forced, and `labelStyle` is an environment value
/// this chip cannot see from where it is declared — so a caller could turn its words off from
/// outside. `WordCloudView` has to force the style for exactly this reason, and the sibling
/// `headnoteProvenanceChip` in `CollectionEntryInspector` is an unpinned `Label` today. The words
/// are one of the three channels; nothing outside this file may switch them off.
///
/// ## Two properties of the API that are prohibitions, not features
///
/// **The caller names the source; the chip never looks one up from an artifact filename.**
/// `BundledArtifactProvenance` holds one `Entry` per file, and the boundary this wave exists to
/// draw runs *inside* a row: one `AuthorityCollectionRecord` carries `name`, `aliases` and
/// `volumeIds` (FRUS-derived) beside `naId` and `catalogURL` (NARA's). A filename-keyed
/// `ProvenanceChip(artifact:)` would hand one answer to both halves — and it cannot be fixed in
/// the table either, since flipping that row to `.frusText` under the §1a field exemption would
/// then claim Tier 1 for the NARA identifier the collection detail screen renders.
///
/// **The chip is a fixed-intrinsic-size leaf.** No `frame`, no `Spacer()`, no alignment of its
/// own. All twelve `ConfidenceChip` mounts across the two Source Explorer twins are
/// leading-packed `HStack(spacing: 6)`s with the claim's title first and the chip last, and a
/// greedy chip in one of those would stretch its capsule across the row and truncate the title
/// beside it.
///
/// Version history:
///   1.0 — PV-2: initial implementation
struct ProvenanceChip: View {

    /// Where the value beside this chip came from.
    ///
    /// Chosen by the caller, per **claim** — see the type's note on why this is never derived from
    /// the artifact a value was read out of.
    let source: ProvenanceSource

    /// Whether the reader has asked for meaning to be carried by something other than colour.
    ///
    /// Read from the environment here rather than passed in, so that no call site can forget it —
    /// and every rule it feeds is a static function below, so the behaviour is testable without a
    /// view host.
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: Self.glyph(for: source.tier))
                .imageScale(.small)
            Text(source.label)
        }
        .font(.caption2)
        .foregroundStyle(Self.foreground(for: source.tier,
                                         differentiateWithoutColor: differentiateWithoutColor))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Self.fill(for: source.tier,
                              differentiateWithoutColor: differentiateWithoutColor),
                    in: Capsule())
        .overlay(Capsule().strokeBorder(
            Self.border(for: source.tier, differentiateWithoutColor: differentiateWithoutColor),
            // **0.5, not 1.** Every capsule stroke in the app that names a width uses a half
            // point — `ClassificationChip`, which shares a Source Explorer screen with this one
            // under PV-3, and both of `SearchSheet`'s. The 1-point ring belongs to the headnote
            // *card*. At `.caption2` the difference reads as a different component class.
            lineWidth: 0.5))
        // **`.ignore`, not `.combine`, and it must precede the label.** `Image(systemName:)` is
        // itself an accessibility element and speaks its SF Symbol name, so combining would read
        // "square fill, FRUS text" — the glyph is a sighted reader's channel and saying it aloud
        // gives a VoiceOver user nothing to act on. (`LensChip` can use `.combine` because its
        // glyph is a bare `Circle()`, a Shape that contributes nothing.) Order matters too:
        // `.ignore` discards the inner content's accessibility, so a label applied above it is
        // dropped rather than kept.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: source))
    }

    // MARK: - The shape channel

    /// Square for the volumes, triangle for a join, circle for a computation.
    ///
    /// Filled rather than outlined, because at `.caption2` an outlined triangle and an outlined
    /// circle are two thin rings. Unconditional — see the type's note.
    ///
    /// **These two shapes are already spoken for on one screen, and a chip must never be mounted
    /// there.** `ArchivalNetworkView`'s legend reads `circle.fill` as *Collection* and
    /// `square.fill` as *Central-file class*, at the same `.caption2`/`.secondary` weight — so on
    /// that graph a provenance chip would say "computed" with the collection glyph and "FRUS only"
    /// with the class glyph. The wave already refuses graph surfaces (the plan's §6: hue *is* the
    /// data there), which is why the shapes stand; the refusal now has a second reason and it is
    /// recorded here rather than left to be rediscovered by whoever proposes badging that view.
    static func glyph(for tier: ProvenanceTier) -> String {
        switch tier {
        case .frusOnly: return "square.fill"
        case .joined:   return "triangle.fill"
        case .computed: return "circle.fill"
        }
    }

    // MARK: - The colour channel, which is never load-bearing

    /// The label colour: the tier's tint, or the ordinary label colour when the reader has asked
    /// for no colour coding.
    static func foreground(for tier: ProvenanceTier, differentiateWithoutColor: Bool) -> Color {
        differentiateWithoutColor ? .primary : tint(for: tier)
    }

    /// The wash behind the capsule.
    ///
    /// Both variants go through ``FRUSTheme/provenanceFill(_:)`` rather than spelling `0.12`
    /// twice: the 12% wash and the 32% hairline are one decision about how a chip sits on the
    /// page, and a retune that reached the tinted chip while leaving the neutral one behind is a
    /// drift nothing would report.
    static func fill(for tier: ProvenanceTier, differentiateWithoutColor: Bool) -> Color {
        FRUSTheme.provenanceFill(differentiateWithoutColor ? .secondary : tint(for: tier))
    }

    /// The hairline that makes the capsule an object rather than a stain.
    static func border(for tier: ProvenanceTier, differentiateWithoutColor: Bool) -> Color {
        FRUSTheme.provenanceBorder(differentiateWithoutColor ? .secondary : tint(for: tier))
    }

    /// The tier's hue. Not called when the reader has asked for no colour coding.
    static func tint(for tier: ProvenanceTier) -> Color {
        switch tier {
        case .frusOnly: return FRUSTheme.provenanceFRUS
        case .joined:   return FRUSTheme.provenanceJoined
        case .computed: return FRUSTheme.provenanceComputed
        }
    }

    // MARK: - The VoiceOver channel

    /// What VoiceOver reads in place of the glyph and the label.
    ///
    /// **Four sentences, where the plan wrote three.** The plan gave one per tier, and
    /// ``ProvenanceSource/yourReading`` sits in the computed tier while being deliberately outside
    /// the provenance family. Reading "computed by this app" over a reader's own highlight would be
    /// false in the one direction that matters — it would attribute their work to the software.
    static func accessibilityLabel(for source: ProvenanceSource) -> String {
        switch source {
        case .frusText:
            return String(localized: "provenance.chip.a11y.frusOnly",
                          defaultValue: "Source: the FRUS volumes only.")
        case .naraCatalog, .ohPeopleRegister, .ohSubjects, .stateDeptSchedule:
            return String(format: String(localized: "provenance.chip.a11y.joined %@",
                                         defaultValue: "Source: FRUS joined to %@."),
                          source.partnerName)
        case .appWordLists, .appModel:
            return String(localized: "provenance.chip.a11y.computed",
                          defaultValue: "Source: computed by this app.")
        case .yourReading:
            return String(localized: "provenance.chip.a11y.yourReading",
                          defaultValue: "Source: your own reading.")
        }
    }
}
