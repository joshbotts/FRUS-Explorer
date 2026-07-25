// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - BrokenRefExplanationSheet

/// Explains why a tapped cross-reference can't be followed. Presented when the reader activates a
/// dead `<ref>` (issue #240B): the printed FRUS volumes were retyped and their cross-references
/// retroactively tagged, so some point at documents, pages, or volumes that don't exist in the
/// corpus. A research app should say *why* rather than silently do nothing.
///
/// Shared by iOS `DocumentView` and macOS `MacDocumentView`.
struct BrokenRefExplanationSheet: View {

    /// The broken reference's detail (reason + apparent destination).
    let info: BrokenRefInfo

    @Environment(\.dismiss) private var dismiss

    /// The plain-language reason, by failure category. Worded volume-neutrally ("the cited
    /// volume") because ~half the broken refs point at a *different* volume than the one being
    /// read — the "Apparent destination" section names it precisely.
    private var reasonText: String {
        switch info.reason {
        case "unknownPage":
            return String(localized: "The page this reference cites could not be found in the cited volume.")
        case "unknownVolume":
            return String(localized: "The referenced volume isn't part of this collection.")
        case "emptyTarget":
            return String(localized: "This cross-reference has no destination.")
        default:   // unknownAnchor and any future reason
            return String(localized: "The document or section this reference cites no longer exists in the cited volume.")
        }
    }

    /// The apparent destination the editors seem to have intended, when known.
    private var intendedDestination: String? {
        guard let anchor = info.resolvedAnchor, !anchor.isEmpty else { return nil }
        if let volume = info.resolvedVolume, !volume.isEmpty {
            return "\(volume) · \(anchor)"
        }
        return anchor
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text(reasonText)
                    } icon: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                if let intendedDestination {
                    Section(String(localized: "Apparent destination")) {
                        Text(intendedDestination)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Text(String(localized: "Flagged by FRUS Explorer's corpus-wide cross-reference validation."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(String(localized: "Unresolved Reference"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        // macOS sheets collapse to intrinsic size without an explicit frame, leaving only the
        // title bar visible (mirrors GlossDetailSheet's sizing).
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }
}
