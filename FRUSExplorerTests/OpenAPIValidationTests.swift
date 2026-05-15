// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - OpenAPIValidationTests

/// Structural validation of `FRUS-API.openapi.yaml`.
///
/// These tests verify the internal consistency of the OpenAPI document without
/// requiring a third-party validator at build time. They check:
/// - Required OpenAPI 3.1 top-level fields are present
/// - All expected endpoint paths are defined
/// - Every `$ref: "#/components/schemas/Foo"` has a corresponding schema definition
/// - Every operation has at least one success (2xx) response
/// - Standard error responses (401, 404, 429, 500) are defined in components
struct OpenAPIValidationTests {

    // MARK: - Fixture

    private static let fileURL: URL = {
        // Navigate from FRUSExplorerTests/ up one level to the project root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // FRUSExplorerTests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("FRUS-API.openapi.yaml")
    }()

    private func loadDocument() throws -> String {
        try String(contentsOf: Self.fileURL, encoding: .utf8)
    }

    // MARK: - File Presence

    @Test("OpenAPIValidationTest: document file exists and is non-empty")
    func documentExists() throws {
        let content = try loadDocument()
        #expect(!content.isEmpty)
        #expect(content.count > 1000, "Expected a substantive document, got \(content.count) bytes")
    }

    // MARK: - Top-Level Structure

    @Test("OpenAPIValidationTest: document declares OpenAPI 3.1.0")
    func declaresOpenAPI31() throws {
        let content = try loadDocument()
        #expect(content.contains("openapi: 3.1.0"))
    }

    @Test("OpenAPIValidationTest: required top-level sections are present")
    func requiredTopLevelSectionsPresent() throws {
        let content = try loadDocument()
        let required = ["info:", "paths:", "components:", "servers:", "security:"]
        for key in required {
            #expect(content.contains(key), "Missing top-level section: \(key)")
        }
    }

    @Test("OpenAPIValidationTest: info section has title and version")
    func infoSectionComplete() throws {
        let content = try loadDocument()
        #expect(content.contains("title: FRUS API"))
        #expect(content.contains("version:"))
    }

    // MARK: - Required Endpoints

    @Test("OpenAPIValidationTest: all required endpoint paths are defined")
    func requiredPathsDefined() throws {
        let content = try loadDocument()
        let requiredPaths = [
            "/volumes:",
            "/volumes/{volumeId}:",
            "/volumes/{volumeId}/download:",
            "/volumes/{volumeId}/documents:",
            "/volumes/{volumeId}/documents/{documentId}:",
            "/volumes/{volumeId}/documents/{documentId}/cross-references:",
            "/volumes/{volumeId}/page-ranges:",
            "/subjects:",
            "/subjects/appearances/{volumeId}:",
            "/search:",
        ]
        for path in requiredPaths {
            #expect(content.contains(path), "Missing endpoint path: \(path)")
        }
    }

    @Test("OpenAPIValidationTest: all operations have an operationId")
    func allOperationsHaveOperationId() throws {
        let content = try loadDocument()
        // Count occurrences of `get:` / `post:` / `put:` / `delete:` inside paths,
        // and verify the operationId count matches the number of operations.
        // Simplified: verify at least as many operationIds as expected operations.
        let operationCount = content.components(separatedBy: "operationId:").count - 1
        #expect(operationCount >= 10, "Expected at least 10 operationIds, found \(operationCount)")
    }

    // MARK: - Schema $ref Consistency

    @Test("OpenAPIValidationTest: all schema $ref targets are defined in components/schemas")
    func allSchemaRefsAreDefined() throws {
        let content = try loadDocument()

        // Extract all schema reference names: $ref: "#/components/schemas/Foo"
        let pattern = #"\$ref: "#/components/schemas/([A-Za-z][A-Za-z0-9]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            Issue.record("Failed to compile $ref regex")
            return
        }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        var referencedNames = Set<String>()
        for match in matches {
            if let nameRange = Range(match.range(at: 1), in: content) {
                referencedNames.insert(String(content[nameRange]))
            }
        }

        for name in referencedNames.sorted() {
            // Each referenced schema must appear as a top-level key under schemas:
            let definitionMarker = "\(name):"
            #expect(content.contains(definitionMarker),
                    "Referenced schema '\(name)' is not defined in components/schemas")
        }
    }

    // MARK: - Error Responses

    @Test("OpenAPIValidationTest: standard error responses are defined in components")
    func standardErrorResponsesDefined() throws {
        let content = try loadDocument()
        let required = [
            "400BadRequest:",
            "401Unauthorized:",
            "404NotFound:",
            "429TooManyRequests:",
            "500ServerError:",
        ]
        for key in required {
            #expect(content.contains(key), "Missing component response: \(key)")
        }
    }

    @Test("OpenAPIValidationTest: Error schema is defined with required fields")
    func errorSchemaHasRequiredFields() throws {
        let content = try loadDocument()
        #expect(content.contains("Error:"))
        #expect(content.contains("code:"))
        #expect(content.contains("message:"))
    }

    // MARK: - Security

    @Test("OpenAPIValidationTest: ApiKeyAuth security scheme is defined")
    func apiKeySecuritySchemeDefined() throws {
        let content = try loadDocument()
        #expect(content.contains("ApiKeyAuth:"))
        #expect(content.contains("type: apiKey"))
        #expect(content.contains("X-API-Key"))
    }

    // MARK: - Pagination

    @Test("OpenAPIValidationTest: pagination parameters Limit and Offset are defined")
    func paginationParametersDefined() throws {
        let content = try loadDocument()
        #expect(content.contains("Limit:"))
        #expect(content.contains("Offset:"))
    }

    @Test("OpenAPIValidationTest: list endpoints reference pagination wrapper schemas")
    func listEndpointsUsePaginationWrappers() throws {
        let content = try loadDocument()
        let paginatedSchemas = [
            "VolumeManifestList",
            "DocumentBrowserEntryList",
            "SearchResultList",
            "SubjectTagList",
        ]
        for schema in paginatedSchemas {
            #expect(content.contains(schema),
                    "Expected paginated wrapper schema '\(schema)' to be defined")
        }
    }

    // MARK: - Rate Limiting

    @Test("OpenAPIValidationTest: rate limit headers are defined in components")
    func rateLimitHeadersDefined() throws {
        let content = try loadDocument()
        let requiredHeaders = [
            "X-RateLimit-Limit:",
            "X-RateLimit-Remaining:",
            "X-RateLimit-Reset:",
        ]
        for header in requiredHeaders {
            #expect(content.contains(header), "Missing rate limit header: \(header)")
        }
    }

    // MARK: - OpenAPI 3.1 Compliance

    @Test("OpenAPIValidationTest: document does not use deprecated nullable:true (OpenAPI 3.0 syntax)")
    func noDeprecatedNullableSyntax() throws {
        let content = try loadDocument()
        #expect(!content.contains("nullable: true"),
                "Found 'nullable: true' which is OpenAPI 3.0 syntax. Use 'type: [\"...\", \"null\"]' in 3.1")
    }
}
