// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RefDestination

/// The navigable destination of a TEI `<ref target>`: a case-for-case twin of the app's
/// `CrossRefDestination` (`FRUSCoreKit/TEI/FRUSURLScheme.swift`).
///
/// This is a Foundation-only twin of the app enum so the generators can reason about ref
/// navigation without linking the app. `CrossRefGrammar.resolveDestination` is written branch for
/// branch from `resolveCrossRefTarget`, and `CrossRefGrammarTests` pins it with a fixture table
/// drawn from the app's documented cases. The table is hard-coded and never calls the app, so
/// it cannot see the app's copy change: the twin had drifted on three branches — a footnote
/// anchor (`.footnote`, #988), a `mailto:` target and a whole volume (`.volume`, #1603) — until
/// #1693 brought it back. `CrossRefGrammarAppParityTests` (in `ResolvedEdgeIndexGeneratorTests`)
/// holds the two to each other over every branch, through FRUSCoreKit, which that target links.
///
/// > Note: Validation (`CrossRefGrammar.classifyForValidation`) does **not** use this type — a
/// > ref's navigability is a separate question from whether its target xml:id exists. A footnote
/// > anchor resolves to `.footnote` here yet is validated by anchor existence; a roman-numeral
/// > page is `.unresolved` here yet its `pg_` xml:id may exist and thus be a valid target.
///
/// Version history:
///   1.0 — Session 6 (#240A): `document`, `page`, `external` and `unresolved`
///   1.1 — #1693: `footnote` (the app's since #988) and `volume` (since #1603)
public enum RefDestination: Equatable, Sendable {
    /// A FRUS document.
    case document(volumeId: String?, documentId: String)
    /// A specific footnote inside a FRUS document (#988). `anchor` is the note's TEI `xml:id`
    /// (`d748fn3`); `documentId` is the document holding it, which is where the reader's link goes
    /// and what the app's index stores as the reference's target (#1613).
    case footnote(volumeId: String?, documentId: String, anchor: String)
    /// A printed page in a volume.
    case page(volumeId: String?, page: Int)
    /// A whole volume, not a document in it (#1603): a target with no `#` that is a volume's id
    /// (`frus1961-63v05`), as the target gives it. It may name a volume outside the catalogue.
    case volume(volumeId: String)
    /// A non-FRUS absolute URL, or a `mailto:` address — opens outside the reader.
    case external(URL)
    /// Nothing navigable: same-document footnote/figure/table anchors, roman-numeral page
    /// anchors, or an empty target.
    case unresolved

    /// The document this destination is a citation of, as the app's index stores it: a document,
    /// or the document holding a footnote (#1613, `SettledCrossReferenceTarget`); `nil` for a page,
    /// a whole volume, an address and nothing. `volumeId` is the destination's own: the target's
    /// prefix, else the volume it was resolved in, `nil` when that was `nil`.
    ///
    /// What the generators that count document-to-document references take, so the footnote case
    /// loses none of their edges: until #1693 the twin read a `dNfnM` anchor as `.document` of the
    /// note's document, and each kept only `.document`.
    public var citedDocument: (volumeId: String?, documentId: String)? {
        switch self {
        case .document(let volumeId, let documentId),
             .footnote(let volumeId, let documentId, _):
            return (volumeId, documentId)
        case .page, .volume, .external, .unresolved:
            return nil
        }
    }
}

// MARK: - CrossRefGrammar

/// The FRUS cross-reference target grammar, mirrored from the app so the offline generators
/// classify `<ref target>` values exactly as the reading view navigates them.
///
/// Two app functions are mirrored:
///   - `resolveDestination` ≡ `FRUSURLScheme.resolveCrossRefTarget` (render-time navigation; in
///     FRUSCoreKit, which `FRUSURLSchemeHandler` forwards to), branch for branch since #1693: a
///     `mailto:` target is external, a target with no `#` that is a volume's id is `.volume`, and
///     a footnote anchor is `.footnote` under the app's widened pattern.
///   - `parseVolumePrefix` ≡ `FRUSDocumentParser.parseRefTarget` (index-time volume-id split).
///
/// Both are pure string transformations with no app dependencies. The app keeps its own copies;
/// `CrossRefKit` carries parity-tested twins, so a generator can classify a target without linking
/// FRUSCoreKit (the validator and the provenance flow generator do not link it).
///
/// Version history:
///   1.0 — Session 6 (#240A): `resolveDestination`, `parseVolumePrefix`
///   1.1 — #1693: `resolveDestination` takes the app's three later branches — `mailto:` (external),
///          a whole volume (`.volume`, #1603, through `isVolumeId(_:)`) and a footnote anchor
///          (`.footnote`, #988, on the widened `.*d\d+[A-Za-z]?` + `fn[\w-]*` pattern) — where it
///          read the first two as a document named after the target, and a footnote anchor as its
///          document when it was `dNfnM` and as a document named after the note when it was not
public enum CrossRefGrammar {

    // MARK: Navigation parity (mirrors resolveCrossRefTarget)

    /// Resolves a raw `<ref target>` to its navigable destination — a branch-for-branch mirror of
    /// FRUSCoreKit's `FRUSURLScheme.resolveCrossRefTarget(_:volumeId:)`.
    ///
    /// - `vol#anchor` prefixes override `volumeId`; bare `#anchor` keeps it.
    /// - A target with no `#` that is a volume's id (`frus1961-63v05`) is `.volume`. Any other
    ///   target with no `#` (`pg_1602`, an anchor printed without its `#`) is read as an anchor in
    ///   `volumeId`.
    /// - A footnote anchor (`d748fn3`, `cr_d6fn4`, `d705fn-sym1`) is `.footnote`, naming the
    ///   document that holds the note.
    /// - `pg_313` / `pg313` / `page313` anchors resolve to a page number; roman-numeral pages
    ///   (`pg_XIII`, front matter) are `.unresolved`.
    /// - Bare `fn…`/`note…`/`fig…`/`tbl…` anchors point within the current document and are
    ///   `.unresolved`.
    /// - Absolute `http(s)` URLs and `mailto:` addresses are `.external`.
    ///
    /// - Parameters:
    ///   - rawTarget: The verbatim `target` attribute value.
    ///   - volumeId: The volume the ref lives in (the same-volume default when no `vol#` prefix).
    /// - Returns: The classified navigation destination.
    public static func resolveDestination(
        _ rawTarget: String,
        volumeId: String?
    ) -> RefDestination {
        let target = rawTarget.trimmingCharacters(in: .whitespaces)
        // `mailto:` alongside http(s), as the app's copy has it: the front matter's
        // "mailto:history@state.gov" is an address, not a document.
        if target.hasPrefix("http://") || target.hasPrefix("https://")
            || target.hasPrefix("mailto:") {
            return URL(string: target).map { .external($0) } ?? .unresolved
        }

        var vol = volumeId
        var anchor = target
        if let hash = target.firstIndex(of: "#") {
            let prefix = String(target[..<hash])
            if !prefix.isEmpty { vol = prefix }
            anchor = String(target[target.index(after: hash)...])
        } else if isVolumeId(target) {
            return .volume(volumeId: target)
        }
        guard !anchor.isEmpty else { return .unresolved }

        let lower = anchor.lowercased()
        if lower.hasPrefix("pg") || lower.hasPrefix("page") {
            let digits = anchor.drop { !$0.isNumber }
            if !digits.isEmpty, digits.allSatisfy(\.isNumber), let page = Int(digits) {
                return .page(volumeId: vol, page: page)
            }
            return .unresolved
        }
        if lower.hasPrefix("fn") || lower.hasPrefix("note")
            || lower.hasPrefix("fig") || lower.hasPrefix("tbl") {
            return .unresolved
        }
        // The app's pattern since #988: a section-prefixed or symbol-suffixed note id (`cr_d6fn4`,
        // `d705fn-sym1`) names its document as a plain one does. Anchored on `d\d+`, so a document
        // id that merely contains "fn" is not split.
        if let match = anchor.wholeMatch(of: /(.*d\d+[A-Za-z]?)fn[\w-]*/) {
            return .footnote(volumeId: vol, documentId: String(match.1), anchor: anchor)
        }
        return .document(volumeId: vol, documentId: anchor)
    }

    /// Whether `token` has the form of a volume's id: `frus` and then a digit, the year every
    /// volume id opens with (`frus1861`, `frus1969-76v41`, `frus1958-60v15-16mSupp1`) — a mirror
    /// of FRUSCoreKit's `FRUSURLScheme.isVolumeId(_:)`.
    ///
    /// - Parameter token: A target with no `#`.
    /// - Returns: `true` when the token has a volume id's form.
    static func isVolumeId(_ token: String) -> Bool {
        guard token.hasPrefix("frus") else { return false }
        return token.dropFirst(4).first?.isASCII == true && token.dropFirst(4).first?.isNumber == true
    }

    // MARK: Volume-prefix split (mirrors parseRefTarget)

    /// Extracts the leading `vol#` volume id from a raw target — a mirror of
    /// `FRUSDocumentParser.parseRefTarget(_:)` (index-time). Returns the original target unchanged
    /// plus the extracted volume id (`nil` for same-volume `#anchor` refs and `http…` URLs).
    ///
    /// - Parameter target: The verbatim `target` attribute value.
    /// - Returns: The original `target` and the extracted `volumeId`, if any.
    public static func parseVolumePrefix(_ target: String) -> (target: String, volumeId: String?) {
        guard !target.hasPrefix("#"), !target.hasPrefix("http") else {
            return (target, nil)
        }
        if let hashIndex = target.firstIndex(of: "#") {
            let volumeId = String(target[target.startIndex..<hashIndex])
            return (target, volumeId.isEmpty ? nil : volumeId)
        }
        return (target, nil)
    }
}
