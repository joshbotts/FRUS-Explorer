// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - MacDocumentTitle

/// What the standalone reading window's toolbar centre says (UI review M-8).
///
/// ## The finding is wrong, and the correction is what makes this worth doing
/// M-8 says the document's *title* is "relegated to `.help` hover". It is not:
/// `MacDocumentView` sets `.navigationTitle` to the document's header, under a comment that says
/// so — "Window/tab title — the document's heading, falling back to its id." A reader has always
/// had the human title, in the window's own title bar.
///
/// The real defect is narrower. The `.principal` toolbar item — the centre of the window chrome,
/// the most valuable strip it has — carried `Text(currentEntry.documentId)` in monospace: a raw
/// `frus1946v06/d475` that **repeats identity the title already gives in human form**, with a
/// `.help` that repeats the title a third time. Three renderings of the same fact, one of them in
/// a form addressed to whoever maintains the app rather than whoever reads the documents.
///
/// So the fix is not "show the title". It is to make the centre say **what the title does not**:
/// which volume this is, and where in it. That is complementary rather than redundant, and it is
/// the one piece of orientation a standalone document window otherwise lacks entirely — it has no
/// breadcrumb, no back button, and no sidebar.
///
/// ## Why `distilledVolumeLabel`
/// The volume's own TEI title begins with the constant "Foreign Relations of the United States,
/// …", so printing it here would fill the strip with boilerplate — the exact problem #237 built
/// the iOS two-line title to see past. `ChronologyViewModel.distilledVolumeLabel` is the app's
/// existing short form, already rendered by Chronology, Cross-Reference Analytics, and the
/// compilation parent line, and its tag half is globally unique so two windows never read alike.
///
/// Version history:
///   1.0 — CW-10 (UI review M-8)
enum MacDocumentTitle {

    /// The toolbar centre's text.
    ///
    /// Falls back to the document id when the volume is not in the manifest — a window restored
    /// for a volume that has since been removed still has to say something, and the id is what
    /// this strip showed before. That is a degraded state, not the normal one, so it keeps the
    /// old behaviour rather than inventing a placeholder.
    ///
    /// - Parameters:
    ///   - volumeLabel: The short volume form, or `nil` when the manifest has no entry.
    ///   - documentNumber: The document's number within its volume, if it has one. Editorial
    ///     notes and front-matter sections do not.
    ///   - documentId: The raw id, used only as the fallback.
    /// - Returns: The label to render.
    static func principalLabel(volumeLabel: String?,
                               documentNumber: String?,
                               documentId: String) -> String {
        guard let volumeLabel, !volumeLabel.isEmpty else { return documentId }
        guard let documentNumber, !documentNumber.isEmpty else { return volumeLabel }
        return String(format: String(localized: "macDocument.principal %@ %@",
                                     defaultValue: "%1$@ · Doc %2$@"),
                      volumeLabel, documentNumber)
    }

    /// Whether the label is the raw-id fallback rather than a resolved location.
    ///
    /// The view uses this to keep the monospaced face for an id and drop it for prose: a
    /// monospaced "Soviet Union · 1969-76 v20 · Doc 475" reads as machine output, which is half
    /// of what M-8 is actually complaining about.
    ///
    /// - Parameter volumeLabel: The short volume form, or `nil`.
    /// - Returns: `true` when the label will be the bare document id.
    static func isFallback(volumeLabel: String?) -> Bool {
        volumeLabel?.isEmpty ?? true
    }
}
