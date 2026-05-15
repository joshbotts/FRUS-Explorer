// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - ResponseFormatCodingTests

/// Verifies that `ResponseFormat` round-trips through `Codable` correctly for
/// both the `.general` case and the `.structured(schema:)` case with associated value.
struct ResponseFormatCodingTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("ResponseFormat.general round-trips through Codable")
    func generalRoundTrip() throws {
        let original = ResponseFormat.general
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseFormat.self, from: data)
        #expect(decoded == original)
    }

    @Test("ResponseFormat.structured round-trips through Codable")
    func structuredRoundTrip() throws {
        let schema = StructuredSummarySchema(fields: [
            .init(name: "Background", description: "Historical context of the document"),
            .init(name: "Key Actions", description: "Decisions and commitments made"),
        ])
        let original = ResponseFormat.structured(schema: schema)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ResponseFormat.self, from: data)
        #expect(decoded == original)
    }

    @Test("StructuredSummarySchema round-trips preserving field order")
    func schemaFieldOrder() throws {
        let schema = StructuredSummarySchema(fields: [
            .init(name: "Alpha", description: "First"),
            .init(name: "Beta",  description: "Second"),
            .init(name: "Gamma", description: "Third"),
        ])
        let data = try encoder.encode(schema)
        let decoded = try decoder.decode(StructuredSummarySchema.self, from: data)

        #expect(decoded.fields.count == 3)
        #expect(decoded.fields[0].name == "Alpha")
        #expect(decoded.fields[2].name == "Gamma")
    }

    @Test("ResponseFormat.general and .structured are not equal")
    func generalStructuredInequality() {
        let schema = StructuredSummarySchema(fields: [.init(name: "X", description: "Y")])
        #expect(ResponseFormat.general != ResponseFormat.structured(schema: schema))
    }

    @Test("Two .structured cases with different schemas are not equal")
    func structuredInequality() {
        let s1 = StructuredSummarySchema(fields: [.init(name: "A", description: "1")])
        let s2 = StructuredSummarySchema(fields: [.init(name: "B", description: "2")])
        #expect(ResponseFormat.structured(schema: s1) != ResponseFormat.structured(schema: s2))
    }
}
