// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - IndexEntryLanding

/// The script that brings the reader to the entry of a back-of-volume index that a "See" reference
/// named (Lane 2 of `Planning/Editors-Annotations-Followups-2026-11-08.md`): it scrolls the entry's
/// `<li>` into view and washes it for 2.4 seconds, as `FootnoteLanding` does a note's endnote entry.
///
/// The entry is the `<item xml:id="in2">` the serializer writes as `<li id="ix-in2">`. Every such
/// reference in the 553 catalogue volumes sits inside the index that holds its entry (49,799 at
/// corpus `6170e4b32`, none across volumes), so the reader runs this on the page already on screen
/// and pushes nothing. The script is ``ReaderLanding``'s, so what #988 measured about the scroll,
/// synchronous and `auto` while the page is hidden, holds here, and the page's global records the
/// entry for the figure retry as it records a footnote.
///
/// Version history:
///   1.0 — 2026-11-08: Lane 2 of the follow-ups plan
public enum IndexEntryLanding {

    /// The script for the entry whose `xml:id` is `anchor`: `true` when the page holds the entry,
    /// `false` when it does not. The id is JSON-encoded rather than interpolated, as a footnote's
    /// key is.
    ///
    /// - Parameter anchor: The entry's anchor, as a reference names it (`in2`).
    /// - Returns: The script, or `nil` when the id cannot be encoded.
    public static func script(anchor: String) -> String? {
        guard let keyData = try? JSONEncoder().encode(anchor),
              let keyLiteral = String(data: keyData, encoding: .utf8) else { return nil }
        return script(keyExpression: keyLiteral)
    }

    /// The script, with `keyExpression` where the entry's id goes: a JavaScript expression that
    /// evaluates to the `xml:id`, such as a string literal.
    ///
    /// - Parameter keyExpression: JavaScript evaluating to the entry's `xml:id`.
    /// - Returns: An expression whose value is `true` when the page holds the entry.
    public static func script(keyExpression: String) -> String {
        ReaderLanding.script(elementId: "\"ix-\" + \(keyExpression)", arrivedClass: "ix-arrived")
    }
}
