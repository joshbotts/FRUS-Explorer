// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - AnchorShape

/// The surface shape of a `#anchor`, used only to pick a human-readable broken-reason label
/// (a missing page vs. a missing generic anchor). Validation itself is always xml:id existence,
/// never shape.
public enum AnchorShape: String, Sendable, Equatable {
    /// A printed-page anchor: `pg…` / `page…`.
    case page
    /// Any other anchor: document ids, footnotes, terms, index items, named divisions.
    case generic
}

// MARK: - RefClassification

/// The validation classification of a raw `<ref target>` — what a ref *points at*, so the
/// generator can decide whether it *resolves*.
///
/// This is deliberately distinct from `RefDestination` (navigation): validation asks "does the
/// target xml:id exist?", which the app's navigation grammar does not — the app sends a footnote
/// ref to the document holding the note, and marks roman-numeral pages unresolved even when their
/// `pg_` id exists. `classifyForValidation` answers the existence question for those while
/// `CrossRefGrammar.resolveDestination` stays a faithful navigation mirror.
public enum RefClassification: Equatable, Sendable {
    /// `http(s)://` or `mailto:` — an external resource, never existence-checked, so those refs are
    /// skipped, not reported broken. `resolveDestination` reads `mailto:` as external too, as the
    /// app's grammar does (#1693 brought the mirror to it; until then it routed them to a document
    /// anchor).
    case external

    /// An empty target: `""`, `"#"`, or `"vol#"` (no anchor after the hash).
    case empty

    /// No `#` fragment and not external — a bare token. A whole-volume link when the token is a
    /// known volume id, otherwise a malformed anchor missing its `#` (e.g. `pg_1602`). The
    /// generator disambiguates against the known-volume set.
    case wholeVolumeOrMalformed(token: String)

    /// An anchor within `volumeId` (`nil` = the source volume). Resolved iff the target volume's
    /// xml:id set contains **any** of `candidates`; `anchor` is the literal target for the report,
    /// and `shape` selects the broken-reason label.
    case anchor(volumeId: String?, anchor: String, candidates: [String], shape: AnchorShape)
}

// MARK: - Validation grammar

extension CrossRefGrammar {

    /// Classifies a raw `<ref target>` for existence validation.
    ///
    /// - Parameters:
    ///   - rawTarget: The verbatim `target` attribute value.
    ///   - sourceVolumeId: The volume the ref lives in (unused here — the caller supplies the
    ///     source volume's xml:id set when the result is `.anchor(volumeId: nil, …)` — but kept in
    ///     the signature so callers pass intent explicitly and future rules can use it).
    /// - Returns: The validation classification.
    public static func classifyForValidation(
        _ rawTarget: String,
        sourceVolumeId: String
    ) -> RefClassification {
        _ = sourceVolumeId
        let target = rawTarget.trimmingCharacters(in: .whitespaces)
        if target.isEmpty { return .empty }
        if target.hasPrefix("http://") || target.hasPrefix("https://") || target.hasPrefix("mailto:") {
            return .external
        }

        guard let hash = target.firstIndex(of: "#") else {
            // No fragment: bare token — whole-volume link or malformed anchor (caller decides).
            return .wholeVolumeOrMalformed(token: target)
        }
        let prefix = String(target[..<hash])
        let volumeId: String? = prefix.isEmpty ? nil : prefix
        let anchor = String(target[target.index(after: hash)...])
        guard !anchor.isEmpty else { return .empty }

        let lower = anchor.lowercased()
        let shape: AnchorShape = (lower.hasPrefix("pg") || lower.hasPrefix("page")) ? .page : .generic
        return .anchor(volumeId: volumeId,
                       anchor: anchor,
                       candidates: anchorCandidates(anchor),
                       shape: shape)
    }

    /// The ordered xml:id candidates a `#anchor` could resolve to, most-specific first. The
    /// validator treats the anchor as resolved when the target volume's xml:id set contains **any**
    /// candidate. This mirrors `resolveDestination`'s navigation intent so a ref is not flagged
    /// broken merely because its *literal* form differs from the id the app would land on:
    ///
    ///   1. the literal anchor — covers `dN`, `pg_N`, `dNfnM` (footnote elements carry their own
    ///      xml:id), `inN`, `t_X`, and named front/back-matter divisions;
    ///   2. the base document `dN` for a `dNfnM` footnote anchor — the app navigates footnote refs
    ///      to their document, so a ref to an existing document's footnote resolves even if the
    ///      footnote element id is absent. The navigation grammar's pattern is wider
    ///      (`cr_d6fn4`, `d705fn-sym1`, `d12fn5a`); this one is not widened with it, because each
    ///      of the 33 corpus references only the wider pattern reads names a note whose own
    ///      xml:id exists, so the literal candidate resolves it (corpus `6170e4b32`, #1693);
    ///   3. the canonical `pg_<arabic>` for a `pageN` / `pgN` page anchor written without the
    ///      underscore — the app resolves those by page number to the `<pb xml:id="pg_N">`.
    ///
    /// - Parameter anchor: The literal string after the `#`.
    /// - Returns: The candidate xml:id strings to test for membership.
    public static func anchorCandidates(_ anchor: String) -> [String] {
        var candidates = [anchor]

        if let match = anchor.wholeMatch(of: /(d\d+[A-Za-z]?)fn\d+/) {
            let base = String(match.1)
            if base != anchor { candidates.append(base) }
        }

        let lower = anchor.lowercased()
        if lower.hasPrefix("pg") || lower.hasPrefix("page") {
            let digits = anchor.drop { !$0.isNumber }
            if !digits.isEmpty, digits.allSatisfy(\.isNumber) {
                let canonical = "pg_\(digits)"
                if canonical != anchor { candidates.append(canonical) }
            }
        }

        return candidates
    }
}
