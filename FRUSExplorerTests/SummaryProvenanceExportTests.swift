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
import Testing
@testable import FRUSExplorer

// MARK: - SummaryProvenanceExportTests

/// Machine-authored text must arrive labelled on **every** path out of the app.
///
/// The collection exporters have branched on `SummaryAuthorship` since the Composer redesign — a
/// `.userWritten` headnote deliberately carries no AI attribution, an `.aiEdited` one carries a
/// different line. The JSON export, which is the one file offered as a *complete* copy of the
/// researcher's data, shipped without the field: machine and human text arrived indistinguishable
/// on the single surface most likely to be read by something other than this app.
///
/// The discipline was achievable — the collection path got it right — and it silently failed on
/// the next surface built. That is what these tests are for.
///
/// Version history:
///   1.0 — provenance-leak fix: initial implementation
@Suite("Summary provenance survives export")
struct SummaryProvenanceExportTests {

    private func summary(_ authorship: SummaryAuthorship?) -> GeneratedSummaryExport {
        GeneratedSummaryExport(
            id: UUID(), documentId: "d1", volumeId: "v1", promptId: UUID(),
            responseText: "text", responseFormat: .general, wasChunked: false,
            projectId: nil, createdAt: nil, lastModified: nil, authorship: authorship)
    }

    private func roundTrip(_ export: GeneratedSummaryExport) throws -> GeneratedSummaryExport {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GeneratedSummaryExport.self, from: encoder.encode(export))
    }

    // MARK: - The field survives the wire

    @Test("Every authorship value round-trips")
    func allValuesRoundTrip() throws {
        for value in SummaryAuthorship.allCases {
            #expect(try roundTrip(summary(value)).authorship == value)
        }
        // Anti-vacuity: the three cases must be distinguishable in the encoded form, or a decoder
        // that collapsed them would still pass the loop above.
        let encoded = try SummaryAuthorship.allCases.map { value -> String in
            String(data: try JSONEncoder().encode(summary(value)), encoding: .utf8) ?? ""
        }
        #expect(Set(encoded).count == SummaryAuthorship.allCases.count)
    }

    @Test("The encoded payload names the field")
    func fieldIsPresentOnTheWire() throws {
        let data = try JSONEncoder().encode(summary(.userWritten))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["authorship"] as? String == "userWritten",
                "a reader outside this app must be able to tell who wrote the text")
    }

    // MARK: - A version-4 file still decodes

    /// The reason the field is `Optional` rather than defaulted: Swift's synthesized `Decodable`
    /// ignores a property's default value, so a non-optional field would have made the key
    /// mandatory and broken every export written before today.
    @Test("A file written before the field still decodes")
    func legacyPayloadDecodes() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","documentId":"d1","volumeId":"v1",
         "promptId":"\(UUID().uuidString)","responseText":"t","responseFormat":{"general":{}},
         "wasChunked":false}
        """
        let decoded = try JSONDecoder().decode(GeneratedSummaryExport.self,
                                               from: Data(legacy.utf8))
        #expect(decoded.authorship == nil, "absent must read as absent, not as a guess")
    }

    /// And the version is what tells the two apart, because a file this build writes never has a
    /// `nil` — so `nil` on read means "predates the field" and nothing else.
    @Test("The format version was bumped for it")
    @MainActor
    func formatVersionBumped() {
        #expect(ResearchDataExporter.currentFormatVersion >= 5)
    }

    // MARK: - What the exporter writes

    /// The model's property is optional for an unrelated reason — a legacy CloudKit NULL would
    /// trap a non-optional enum getter — and every read site in the app coerces that `nil` to
    /// `.aiGenerated`. The export must do the same rather than emitting `null`, or a reader is
    /// asked to resolve an ambiguity with a rule they cannot see.
    @Test("The exporter never writes a null authorship")
    func exporterCoercesLegacyNil() throws {
        let source = try Self.exporterSource()
        #expect(source.contains("authorship: summary.authorship ?? .aiGenerated"),
                "a legacy NULL must export as the value the whole app already treats it as")
    }

    /// A source audit, because the leak was an omission at a mapping site that compiles fine.
    @Test("The DTO and the mapping site both carry the field")
    func bothHalvesArePresent() throws {
        let source = try Self.exporterSource()
        let dtoRange = try #require(source.range(of: "struct GeneratedSummaryExport"))
        let dtoBody = source[dtoRange.upperBound...].prefix(2_400)
        #expect(dtoBody.contains("var authorship: SummaryAuthorship?"),
                "the DTO lost the field")
        let mapRange = try #require(source.range(of: "GeneratedSummaryExport("))
        // A generous window: the mapping site carries ten fields plus the comment explaining
        // why the legacy nil is coerced rather than passed through.
        #expect(source[mapRange.upperBound...].prefix(1_400).contains("authorship:"),
                "the DTO has the field and the mapping site does not fill it — the bug's exact shape")
    }

    private static func exporterSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appending(path: "FRUSExplorer/Export/ResearchDataExporter.swift"),
            encoding: .utf8)
        #expect(text.count > 1_000, "ResearchDataExporter.swift is implausibly small — did it move?")
        return text
    }
}
