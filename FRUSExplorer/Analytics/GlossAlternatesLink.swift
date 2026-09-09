// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - GlossAlternatesLink

/// The trailing “and others” link that names the rest of a shared class code (#1257).
///
/// ## What it is for
/// The Department filed a territory under the number of the power holding it, so one code carries
/// a parent and its dependencies: `44e` is the Bahamas *and twenty-one of its cays*, `11f` the
/// Panama Canal Zone *and four islands in it*. The label table can vend one name, and measured
/// over the shipped corpus **a quarter of the documents a schedule can gloss sit on a code with
/// more than one claimant**. A single name is therefore an assertion the table cannot support,
/// and this is the disclosure that makes it honest.
///
/// It is a DISCLOSURE and not a picker: nothing here changes the row, the count, or the drill.
/// The vended name stays the reading; this says the code names other places too.
///
/// Version history:
///   1.0 — #1257: initial implementation
struct GlossAlternatesLink: View {

    /// The other names the code files, alphabetically. The link hides itself when empty.
    let alternates: [String]
    /// The class key, so the popover can say what is being disambiguated.
    let key: String

    @State private var showing = false

    var body: some View {
        if !alternates.isEmpty {
            Button {
                showing = true
            } label: {
                Text(String(format: String(localized: "archival.gloss.andOthers %lld",
                                           defaultValue: "and %lld others"),
                            Int64(alternates.count)))
                .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel(Text(String(
                format: String(localized: "archival.gloss.andOthers.a11y %@ %lld",
                               defaultValue: "%1$@ also names %2$lld other places"),
                key, Int64(alternates.count))))
            .popover(isPresented: $showing) {
                alternatesList
                    // The app's own pattern for this: without it a popover becomes a sheet in
                    // compact width, which for a five-line list is the wrong weight entirely.
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    @ViewBuilder
    private var alternatesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: String(localized: "archival.gloss.alsoNames %@",
                                       defaultValue: "%@ also names"), key))
            .font(.caption.weight(.semibold))
            // The list can run to twenty-one names — `44e` is the Bahamas and its cays — so it
            // scrolls rather than growing a popover taller than the window.
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(alternates, id: \.self) { name in
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            Text(String(localized: "archival.gloss.alsoNames.why",
                        defaultValue: """
                            The Department filed a territory under the number of the power \
                            holding it, so one code can carry a parent and its dependencies.
                            """))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 260)
    }
}
