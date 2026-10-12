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

// MARK: - PrintedFormsNote

/// The line a word cloud prints under its title when its words were counted as printed, or counted
/// and compared as printed (#1608), shown whole.
///
/// ## Why it is not a `Text` with a line limit
/// The line it replaces was one sentence held to two lines. The owner's condition for the fallback
/// is that a surface says three things: that it counted or compared printed forms, why, and that the
/// result can differ from a device whose language analysis reduces words to their dictionary forms.
/// That is two sentences or three, and a line limit would cut the last of them, which is the one
/// about other devices.
///
/// Nor can it simply take its own height. The cloud's header sits above a canvas or a list in a
/// column that does not scroll, and a caption that grows without limit there pushes them out at the
/// accessibility text sizes (`FeatureInfoButton` and `SearchView.resultsColumn` record two times
/// that shape was met). So it does what they do: the plain text where the column gives it room, and
/// the same text in a strip that scrolls where it does not. The plain text comes first, so
/// `ViewThatFits` takes it whenever its whole height fits.
///
/// It is drawn only for a cloud counted as printed, so a launch whose language analysis works has
/// no such view in its tree and lays out as it always did.
///
/// Version history:
///   1.0 — #1608: initial implementation
struct PrintedFormsNote: View {

    /// What to say: `WordCloudDisplayState.printedFormsNote(_:lens:ranking:)` or
    /// `countedAsPrintedNote(_:lens:)`.
    let text: String

    /// The tallest the scrolling strip is drawn. About six lines of the caption at the default text
    /// size, and two at the largest accessibility size, which leaves the cloud most of the column.
    static let scrollingHeight: CGFloat = 96

    /// The note's accessibility identifier, on whichever of the two forms is drawn.
    static let identifier = "wordcloud.printedFormsNote"

    var body: some View {
        ViewThatFits(in: .vertical) {
            label.fixedSize(horizontal: false, vertical: true)
            ScrollView { label }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: Self.scrollingHeight)
        }
        .accessibilityIdentifier(Self.identifier)
    }

    /// The text, in the header's caption style and at the header's width.
    private var label: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
