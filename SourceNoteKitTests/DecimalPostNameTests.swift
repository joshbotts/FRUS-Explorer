// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import SourceNoteKit

// MARK: - DecimalPostNameTests

/// The decimal file's **post-name subdivision** (#353).
///
/// `102.8951 Rio de Janeiro: Airgram` is a decimal class plus the post it is subdivided by,
/// with no `/item` at all. `decimalNoItemRegex` required the note to end at the class and
/// admitted only `: Telegram` after it, so both the post name and every other document type
/// fell out. Measured: **101 documents**, 0 lost.
///
/// The stored identifier is the whole citation — `102.8951 Rio de Janeiro` — which is the grain
/// the decimal file actually uses, so these join their post's neighbours rather than collapsing
/// onto the bare class.
///
/// ## What keeps the widening safe
/// The `$` anchor. The whole note must be the citation and an optional document-type tail, so a
/// remark sentence can never ride in — which is the failure mode the unbounded class scan was
/// abandoned for. The last three tests are that guard.
///
/// Version history:
///   1.0 — Session 2026-08-07: #353, post-name subdivision and non-Telegram tails
@Suite("Decimal post-name subdivision")
struct DecimalPostNameTests {

    private let parser = SourceNoteParser()

    private func fileID(_ note: String) -> String? {
        if case .centralFiles(_, let identifier) = parser.parse(note) { return identifier }
        return nil
    }

    @Test("A post name after the class is kept in the identifier")
    func postNameIsKept() {
        #expect(fileID("102.8951 Rio de Janeiro: Airgram") == "102.8951 Rio de Janeiro")
        #expect(fileID("103.9169 Asunción: Telegram") == "103.9169 Asunción")
        #expect(fileID("102.895102 Bogotá: Airgram") == "102.895102 Bogotá")
    }

    /// The tail was hard-coded to `Telegram`; `Airgram`, `Despatch` and the rest were refused
    /// on a citation the parser otherwise understood completely.
    @Test("A document type other than Telegram is admitted")
    func anyDocumentTypeTailIsAdmitted() {
        #expect(fileID("102.8951: Airgram") == "102.8951")
        #expect(fileID("102.8951: Despatch") == "102.8951")
        #expect(fileID("102.8951: Telegram") == "102.8951", "the original tail must still work")
    }

    /// The bare class form, unchanged.
    @Test("A bare class is unaffected")
    func bareClassIsUnchanged() {
        #expect(fileID("861.00") == "861.00")
    }

    // MARK: - What the anchor refuses

    /// A note that continues past the citation is not a bare-class citation. This is the case
    /// the `$` anchor exists for, and the reason the widening cannot reach a remark.
    @Test("A note continuing into prose is refused")
    func trailingProseIsRefused() {
        #expect(fileID("102.8951 Rio de Janeiro: Airgram. Drafted by Smith on June 2.") == nil)
    }

    /// A leading year is not a class — it has no dot, so the shape fails outright. The guard
    /// matters because the widened infix would otherwise be a wide net over any capitalized run.
    @Test("A year-led title is not a decimal citation")
    func yearLedTitleIsRefused() {
        #expect(fileID("1943 Conference at Cairo") == nil)
        #expect(fileID("1919 Paris Peace Conference") == nil)
    }

    /// The infix must be capitalized — a post name, not running prose.
    @Test("A lowercase infix is refused")
    func lowercaseInfixIsRefused() {
        #expect(fileID("102.8951 and related correspondence") == nil)
    }
}
