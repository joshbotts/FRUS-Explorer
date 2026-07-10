// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - BrokenRefReason

/// Why a `<ref target>` fails to resolve. The five reasons the OH-submittable report and the
/// bundled exclusion index emit; every other outcome is a resolvable or informational ref and is
/// not reported.
public enum BrokenRefReason: String, Codable, Sendable, Equatable, CaseIterable {
    /// `""`, `"#"`, or `"vol#"` — no anchor to resolve.
    case emptyTarget
    /// A `#`-less token that is neither a known volume id nor an external URL
    /// (e.g. a page anchor `pg_1602` written without its `#`).
    case malformedTarget
    /// A cross-volume prefix that matches no volume in the series or the local corpus.
    case unknownVolume
    /// The target volume exists but no xml:id (or documented fallback) matches the anchor.
    case unknownAnchor
    /// As `unknownAnchor`, but the missing anchor is page-shaped (`pg…` / `page…`).
    case unknownPage
}

// MARK: - BrokenRef

/// One broken cross-reference, with the precise source location the Office of the Historian needs
/// to find and fix it in the TEI, plus the apparent intended target.
public struct BrokenRef: Codable, Sendable, Equatable {
    /// The volume the ref lives in.
    public let sourceVolume: String
    /// The nearest enclosing `<div type="document">` xml:id, or `nil` for front/back-matter
    /// (index, table of contents, section) refs.
    public let sourceDocument: String?
    /// The source volume's TEI filename, so the recipient need not reconstruct it.
    public let sourceFilename: String
    /// The verbatim `target` attribute value.
    public let rawTarget: String
    /// The volume the target points at (the `vol#` prefix, or the source volume for same-volume
    /// anchors); `nil` when the target is empty or malformed.
    public let resolvedVolume: String?
    /// The anchor the target apparently meant (the literal string after `#`); `nil` when there is
    /// no anchor.
    public let resolvedAnchor: String?
    /// Why it is broken.
    public let reason: BrokenRefReason
    /// 1-based line of the `<ref>` in the source file (for a human opening the TEI).
    public let line: Int
    /// UTF-8 byte offset of the `<ref>`'s `<` in the source file (for programmatic patch tooling).
    public let charOffset: Int

    public init(sourceVolume: String, sourceDocument: String?, sourceFilename: String,
                rawTarget: String, resolvedVolume: String?, resolvedAnchor: String?,
                reason: BrokenRefReason, line: Int, charOffset: Int) {
        self.sourceVolume = sourceVolume
        self.sourceDocument = sourceDocument
        self.sourceFilename = sourceFilename
        self.rawTarget = rawTarget
        self.resolvedVolume = resolvedVolume
        self.resolvedAnchor = resolvedAnchor
        self.reason = reason
        self.line = line
        self.charOffset = charOffset
    }
}

// MARK: - CrossRefValidationReport (repo-committed, OH-submittable)

/// The full report: aggregate metadata (what was checked, how much, the typo inventory) followed by
/// every broken ref. Repo-committed (not bundled into the app); the JSON companion to the CSV.
public struct CrossRefValidationReport: Codable, Sendable {
    public let schemaVersion: Int
    public let generated: String
    public let generator: String
    /// Volume files actually scanned on disk.
    public let corpusVolumeCount: Int
    /// Volumes in the app manifest (the shippable series set).
    public let seriesVolumeCount: Int
    public let totalRefsScanned: Int
    public let totalBroken: Int
    /// Broken-ref count by reason raw value.
    public let totalsByReason: [String: Int]
    /// Non-broken outcome counts (external, wholeVolumeRef, resolved, volumeNotInSnapshot).
    public let informationalCounts: [String: Int]
    /// Distinct dangling volume ids across `unknownVolume` refs, for OH triage.
    public let unknownVolumeIds: [String]
    /// Cross-volume refs that resolve in the corpus but target a volume the app does not ship;
    /// valid in the series, un-navigable in the app (a Session-7 policy input, not broken).
    public let nonShippableVolumeRefCount: Int
    /// Distinct target volume ids behind `nonShippableVolumeRefCount`.
    public let nonShippableVolumeIds: [String]
    public let records: [BrokenRef]
}

// MARK: - BrokenRefsIndex (candidate bundled artifact for Session 7)

/// The compact bundled index Session 7 will load to grey out known-dangling refs at render time and
/// exclude them from analytics. Keyed for exclusion on the composite `(sv, sd, t)` — the same raw
/// target resolves differently per source document, so a raw-target-only key would collide with
/// valid refs.
///
/// This session writes it beside the report as the *measured proposal*; wiring it into the app
/// bundle (and the `is_broken` retroactive update) is Session 7's step.
public struct BrokenRefsIndex: Codable, Sendable {
    public let schemaVersion: Int
    public let generated: String
    public let corpusVolumeCount: Int
    public let seriesVolumeCount: Int
    public let totalBroken: Int
    /// `true` when records carry the full `rv`/`ra` detail; `false` when the size threshold forced
    /// the compact exclusion-key-only form.
    public let fullDetail: Bool
    public let records: [BrokenRefsIndexRecord]
}

/// A bundled index record with short keys (every byte ships in the app). `sd` uses the empty string
/// as the front/back-matter sentinel so nil-document refs still match on lookup.
public struct BrokenRefsIndexRecord: Codable, Sendable, Equatable {
    /// sourceVolume
    public let sv: String
    /// sourceDocument (empty string = front/back-matter)
    public let sd: String
    /// rawTarget
    public let t: String
    /// reason raw value
    public let r: String
    /// resolvedVolume (omitted in the compact form)
    public let rv: String?
    /// resolvedAnchor (omitted in the compact form)
    public let ra: String?
}
