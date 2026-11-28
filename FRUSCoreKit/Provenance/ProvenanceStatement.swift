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

import Foundation

/// The sources sentence an export carries, built from what the export actually contains.
///
/// **This is the only part of wave PV that reaches a footnote**, which is why PV-1 comes before the
/// on-screen chips: a reader citing something from this app is reading an exported file, not a
/// screen, and a chip cannot travel into a PDF someone else opens. The owner's Q-1 decision keeps
/// the residual here too — the method block is where a method belongs.
///
/// **It states only the sources the export used.** An export that reciting all eight would train a
/// reader to skip the block, which is the failure the method appendix's own caveat note describes;
/// so the set is derived from the content and the sentences follow it.
///
/// Version history:
///   1.0 — PV-1: initial implementation
///   1.1 — PV §5 / Q-1: the parse residual, conditional on an archival-sources block
///   1.2 — Session 2026-10-25 (FRUS Explorer Light, S17b and S18a): moved into FRUSCoreKit, public, unchanged, for the
///          sources blocks of the web edition's method appendix and collection colophon
///   1.3 — L58 (#2005; the Collections design's §3.7): `compilersLinesSentence`, a collection's own sentence for the
///          lines its compiler wrote, which follows the sources where a collection export prints one
public enum ProvenanceStatement {

    /// The heading the sources block sits under, in every format that has headings.
    public static var heading: String {
        String(localized: "provenance.block.heading", defaultValue: "Where this came from")
    }

    /// The lines an export prints, ordered from the volumes outward.
    ///
    /// Ordering is by tier and then by the label, so two exports listing the same sources read in
    /// the same sequence — the property `plateCaveatLines` protects for caveats, for the same
    /// reason: a reader comparing two artifacts should not have to re-find the sentence.
    ///
    /// - Parameters:
    ///   - sources: What the exported content actually drew on.
    ///   - includesCuratedResolutions: Whether any archival identifier in it was matched by hand.
    ///   - restsOnSourceNoteParse: Whether it carries a block parsed from the volumes' source notes.
    ///   - printsCompilersLines: Whether it is a collection that prints a line its compiler wrote: a title, a date line
    ///     or a headnote of theirs (L58). Only a collection's export passes it.
    /// - Returns: One sentence per source, plus the curated disclosure when it applies. Empty when
    ///   `sources` is empty, so a caller need not guard.
    public static func lines(for sources: Set<ProvenanceSource>,
                             includesCuratedResolutions: Bool = false,
                             restsOnSourceNoteParse: Bool = false,
                             printsCompilersLines: Bool = false) -> [String] {
        guard !sources.isEmpty else { return [] }
        var out = sources
            .sorted { a, b in
                a.tier == b.tier ? a.label < b.label : a.tier < b.tier
            }
            .map(\.methodSentence)
        // Q-3: the owner's own archival judgement is disclosed where it applies, rather than
        // taking a ninth label for twenty lot files. It follows the sources it qualifies.
        if includesCuratedResolutions { out.append(ProvenanceSource.curatedDisclosure) }
        // PV §5 / Q-1: an archival-sources block is a PARSE of the volumes' own source notes, and
        // the parse has a measured residual. Conditional for the reason `parseResidualDisclosure`
        // gives — it belongs to that block type, not to `.frusText`, which every export carries.
        if restsOnSourceNoteParse { out.append(ProvenanceSource.parseResidualDisclosure) }
        // L58 (#2005; the design's §3.7): the compiler's own lines are the outermost of all, so they come last. The
        // two shared sentences stay as the analytics exports, the packet and the method appendix print them.
        if printsCompilersLines { out.append(compilersLinesSentence) }
        return out
    }

    /// The block with its heading, for a format that wants one.
    public static func block(for sources: Set<ProvenanceSource>,
                             includesCuratedResolutions: Bool = false,
                             restsOnSourceNoteParse: Bool = false,
                             printsCompilersLines: Bool = false) -> [String] {
        let body = lines(for: sources, includesCuratedResolutions: includesCuratedResolutions,
                         restsOnSourceNoteParse: restsOnSourceNoteParse,
                         printsCompilersLines: printsCompilersLines)
        return body.isEmpty ? [] : [heading] + body
    }

    /// A collection's own sentence for the lines its compiler wrote (L58; #2005; the Collections design's §3.7): that
    /// a title, a date line or a headnote of theirs stands apart from the volumes' text and is named. A collection's
    /// export prints it after its sources wherever it prints such a line, so the statement no longer reads as though the
    /// volumes and the app's model had written every word.
    public static var compilersLinesSentence: String {
        String(localized: "provenance.collection.compilersLines",
               defaultValue: "Titles, date lines and headnotes of the compiler’s own stand apart from the volumes’ text: a title and the date line under it stand above the words “As published:”, and a headnote names its writer.")
    }
}
