// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - RefDestination

/// The navigable destination of a TEI `<ref target>`, mirroring the app's
/// `CrossRefDestination` (`FRUSExplorer/TEI/FRUSURLSchemeHandler.swift`).
///
/// This is a Foundation-only twin of the app enum so `CrossRefValidationGenerator` can
/// reason about ref navigation without linking the app. `CrossRefGrammar.resolveDestination`
/// reproduces `resolveCrossRefTarget` branch-for-branch; `CrossRefGrammarTests` locks the two
/// together with a byte-parity fixture table drawn from the app's documented cases, so any drift
/// in either copy fails a test.
///
/// > Note: Validation (`CrossRefGrammar.classifyForValidation`) does **not** use this type — a
/// > ref's navigability is a separate question from whether its target xml:id exists. A footnote
/// > anchor resolves to `.document` here yet is validated by anchor existence; a roman-numeral
/// > page is `.unresolved` here yet its `pg_` xml:id may exist and thus be a valid target.
public enum RefDestination: Equatable, Sendable {
    /// A FRUS document (footnote-suffixed ids are normalised to the base doc).
    case document(volumeId: String?, documentId: String)
    /// A printed page in a volume.
    case page(volumeId: String?, page: Int)
    /// A non-FRUS absolute URL — opens in the browser.
    case external(URL)
    /// Nothing navigable: same-document footnote/figure/table anchors, roman-numeral page
    /// anchors, or an empty target.
    case unresolved
}

// MARK: - CrossRefGrammar

/// The FRUS cross-reference target grammar, mirrored from the app so the offline validator
/// classifies `<ref target>` values exactly as the reading view navigates them.
///
/// Two app functions are mirrored:
///   - `resolveDestination` ≡ `FRUSURLSchemeHandler.resolveCrossRefTarget` (render-time navigation).
///   - `parseVolumePrefix` ≡ `FRUSDocumentParser.parseRefTarget` (index-time volume-id split).
///
/// Both are pure string transformations with no app dependencies. The app keeps its own copies
/// (unchanged this session); `CrossRefKit` carries parity-tested twins. When `CrossRefKit` is later
/// wired into the app targets (a follow-up session), the app functions can forward here for a
/// single source of truth.
public enum CrossRefGrammar {

    // MARK: Navigation parity (mirrors resolveCrossRefTarget)

    /// Resolves a raw `<ref target>` to its navigable destination — a branch-for-branch mirror of
    /// `FRUSURLSchemeHandler.resolveCrossRefTarget(_:volumeId:)`.
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
        if target.hasPrefix("http://") || target.hasPrefix("https://") {
            return URL(string: target).map { .external($0) } ?? .unresolved
        }

        var vol = volumeId
        var anchor = target
        if let hash = target.firstIndex(of: "#") {
            let prefix = String(target[..<hash])
            if !prefix.isEmpty { vol = prefix }
            anchor = String(target[target.index(after: hash)...])
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
        if let match = anchor.wholeMatch(of: /(d\d+[A-Za-z]?)fn\d+/) {
            return .document(volumeId: vol, documentId: String(match.1))
        }
        return .document(volumeId: vol, documentId: anchor)
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
