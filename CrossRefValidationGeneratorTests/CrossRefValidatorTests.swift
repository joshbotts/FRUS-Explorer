// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import CrossRefValidationGeneratorCore

struct CrossRefValidatorTests {

    // A small corpus: two shipped series volumes plus one corpus-only supplement, and one series
    // volume that is not on disk (to exercise volumeNotInSnapshot).
    private static func makeValidator() -> CrossRefValidator {
        let inventories: [String: Set<String>] = [
            "frus1901": ["d1", "d2", "pg_5", "d1fn1", "in5"],
            "frus1902": ["d1", "d10", "pg_100"],
            "frus1899supp": ["d1", "d2"],
        ]
        return CrossRefValidator(
            inventories: inventories,
            corpusVolumeIds: ["frus1901", "frus1902", "frus1899supp"],
            seriesVolumeIds: ["frus1901", "frus1902", "frus1903"])   // 1903 in series, not on disk
    }

    private func outcome(_ target: String, source: String = "frus1901") -> ValidationOutcome {
        let ref = HarvestedRef(rawTarget: target, byteOffset: 0, line: 1, enclosingDocument: "d1")
        return Self.makeValidator().validate(ref, sourceVolume: source, sourceFilename: "\(source).xml")
    }

    private func reason(_ target: String, source: String = "frus1901") -> BrokenRefReason? {
        if case .broken(let r) = outcome(target, source: source) { return r.reason }
        return nil
    }

    // MARK: - Resolvable

    @Test("Same-volume and cross-volume anchors that exist resolve")
    func resolves() {
        #expect(outcome("#d1") == .resolved)
        #expect(outcome("#pg_5") == .resolved)
        #expect(outcome("frus1902#d10") == .resolved)
    }

    @Test("A footnote anchor resolves via its literal id or the base document")
    func footnoteResolves() {
        #expect(outcome("#d1fn1") == .resolved)   // literal footnote element id exists
        #expect(outcome("#d1fn9") == .resolved)   // footnote id absent, base d1 exists → still resolves
    }

    @Test("A page anchor without the underscore resolves via the canonical pg_<n>")
    func pageCanonicalResolves() {
        #expect(outcome("#page5") == .resolved)
    }

    // MARK: - Broken reasons

    @Test("A missing generic anchor is unknownAnchor")
    func unknownAnchor() {
        #expect(reason("#d99") == .unknownAnchor)
        #expect(reason("#in99") == .unknownAnchor)
    }

    @Test("A missing page anchor is unknownPage")
    func unknownPage() {
        #expect(reason("#pg_9999") == .unknownPage)
    }

    @Test("A cross-volume prefix matching no real volume is unknownVolume")
    func unknownVolume() {
        #expect(reason("frusBOGUS#d1") == .unknownVolume)
        if case .broken(let r) = outcome("frusBOGUS#d1") {
            #expect(r.resolvedVolume == "frusBOGUS")
            #expect(r.resolvedAnchor == "d1")
        } else { Issue.record("expected broken") }
    }

    @Test("A bare token that is not a known volume is malformedTarget, hinted as a same-volume anchor")
    func malformed() {
        #expect(reason("randomtoken") == .malformedTarget)
        #expect(reason("pg_1602") == .malformedTarget)   // page anchor written without its '#'
        // The record carries the apparent intent (a same-volume anchor missing its '#') for OH.
        if case .broken(let r) = outcome("pg_1602") {
            #expect(r.resolvedVolume == "frus1901")
            #expect(r.resolvedAnchor == "pg_1602")
        } else { Issue.record("expected broken") }
    }

    @Test("Empty targets are emptyTarget")
    func empty() {
        #expect(reason("") == .emptyTarget)
        #expect(reason("#") == .emptyTarget)
        #expect(reason("frus1902#") == .emptyTarget)
    }

    // MARK: - Informational (not broken)

    @Test("http and mailto targets are external")
    func external() {
        #expect(outcome("http://example.com") == .external)
        #expect(outcome("https://history.state.gov") == .external)
        #expect(outcome("mailto:history@state.gov") == .external)
    }

    @Test("A bare known series volume is a whole-volume ref")
    func wholeVolume() {
        #expect(outcome("frus1902") == .wholeVolumeRef)
    }

    @Test("A ref to a corpus volume the app does not ship is non-shippable, not broken")
    func nonShippable() {
        #expect(outcome("frus1899supp#d1") == .nonShippable(targetVolume: "frus1899supp"))
        #expect(outcome("frus1899supp") == .nonShippable(targetVolume: "frus1899supp"))
    }

    @Test("A ref to a series volume that is not downloaded cannot be validated")
    func notInSnapshot() {
        #expect(outcome("frus1903#d1") == .volumeNotInSnapshot)
    }
}
