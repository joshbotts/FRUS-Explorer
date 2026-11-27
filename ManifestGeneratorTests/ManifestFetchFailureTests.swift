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

import Testing
import Foundation
@testable import ManifestGeneratorCore

/// #2022: **an online run writes `manifest.json` only when every volume of the listing reached it.**
///
/// The manifest is the gate: every corpus generator after it takes it as the set of volumes that
/// ship, and the app lists only its volumes. L28's rehearsal of the release runbook (2026-11-26)
/// ran the generator online and six of the 553 header fetches answered HTTP 503: the run logged
/// each, printed `Errors: 6`, wrote a file of 547 volumes, said it was written and exited 0. A
/// second run a few minutes later had no failed fetch and reproduced the bundled file byte for byte.
///
/// A live 503 cannot be called up, so each test drives the whole online pass,
/// `ManifestGeneratorRunner.runOnline`, over a listing of three volumes and a host that answers
/// each from a script, and records the pauses instead of sleeping them. A run that refuses must
/// leave the previous file byte for byte; one that recovers must write every volume.
///
/// Version history:
///   1.0 — #2022 (row L61): initial implementation
@Suite("Manifest — a run with a volume it could not read writes nothing (#2022)")
struct ManifestFetchFailureTests {

    /// What the host answers for one volume, in order; the last answer repeats.
    enum Answer: Sendable {
        /// A header the parser reads.
        case header
        /// An HTTP status outside 2xx, as `TEIHeaderFetcher` throws it.
        case status(Int)
        /// A header that does not parse.
        case garbage
    }

    /// A host whose every answer is scripted, and which counts the requests it was sent.
    actor Host {
        private var script: [String: [Answer]]
        private(set) var requests: [String: Int] = [:]

        init(_ script: [String: [Answer]]) { self.script = script }

        /// Answers one request for `url`, keyed by its file name.
        func answer(_ url: URL) throws -> Data {
            let name = url.lastPathComponent
            requests[name, default: 0] += 1
            var answers = script[name] ?? [.header]
            let answer = answers.count > 1 ? answers.removeFirst() : answers[0]
            script[name] = answers
            switch answer {
            case .header: return Data(TEIFixtures.fullHeader.utf8)
            case .status(let code): throw TEIHeaderFetcherError.badHTTPStatus(code)
            case .garbage: return Data("<TEI><teiHeader><fileDesc>".utf8)
            }
        }
    }

    /// The pauses a run asked for, in order.
    actor Pauses {
        private(set) var asked: [Duration] = []
        func record(_ duration: Duration) { asked.append(duration) }
    }

    /// Three of the six volumes L28's first run lost, as the listing names them.
    static let names = ["frus1961-63v20.xml", "frus1964-68v02.xml", "frus1969-76v08.xml"]

    /// The listing of `names`, each with a download URL on the host L28's 503s came from.
    static let listing = names.map { name in
        GitHubVolumeEntry(
            name: name, size: 1_000_000, sha: String(repeating: "a", count: 40),
            downloadUrl: "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(name)")
    }

    /// The bytes standing at the output path before each run: what a refused run must leave.
    static let previousFile = Data("[]\n".utf8)

    /// What one run did: whether it threw, what it left at the output path, and what it asked of
    /// the host.
    struct Outcome {
        let thrown: (any Error)?
        let file: Data?
        let requests: [String: Int]
        let pauses: [Duration]

        /// The volume ids of the manifest the run left, or nil when it is not a manifest.
        var volumeIds: [String]? {
            file.flatMap { try? JSONDecoder().decode([VolumeManifestEntry].self, from: $0) }?
                .map(\.volumeId)
        }
    }

    /// Runs the online pass over `listing` against a host scripted with `script`.
    static func run(_ script: [String: [Answer]]) async throws -> Outcome {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManifestFetchFailureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appendingPathComponent("manifest.json")
        try previousFile.write(to: output)

        let host = Host(script)
        let pauses = Pauses()
        var thrown: (any Error)?
        do {
            try await ManifestGeneratorRunner.runOnline(
                outputPath: output.path, concurrencyLimit: 8,
                listing: { Self.listing },
                fetchHeader: { url in try await host.answer(url) },
                pause: { duration in await pauses.record(duration) })
        } catch {
            thrown = error
        }
        return Outcome(thrown: thrown, file: try? Data(contentsOf: output),
                       requests: await host.requests, pauses: await pauses.asked)
    }

    /// **The issue's own case.** One volume's fetch answers 503 every time: the run refuses,
    /// names the volume and its status, and leaves the previous file as it was.
    @Test("A fetch that answers 503 every time leaves the previous file and names the volume")
    func aFetchThatKeepsFailingWritesNothing() async throws {
        let outcome = try await Self.run(["frus1961-63v20.xml": [.status(503)]])

        guard case ManifestGeneratorRunner.RunError.incompleteListing(
            let listed, let written, let failures, _)? = outcome.thrown else {
            Issue.record("""
                The run did not refuse: it threw \(String(describing: outcome.thrown)) and left \
                \(outcome.volumeIds.map { "a manifest of \($0.count) volumes" } ?? "no manifest").
                """)
            return
        }
        #expect(listed == 3)
        #expect(written == 2)
        #expect(failures.map(\.filename) == ["frus1961-63v20.xml"])
        #expect(failures.first?.reason.contains("503") == true,
                "the refusal does not give the status: \(failures)")
        #expect(outcome.file == Self.previousFile,
                "the refused run changed the file at the output path")
        let message = String(describing: try #require(outcome.thrown))
        #expect(message.contains("frus1961-63v20.xml"), "the refusal does not name the volume: \(message)")
        #expect(message.contains("nothing was written"), "the refusal does not say so: \(message)")
    }

    /// The owner's second half: a 503 that clears is tried again, after a pause, and the volume
    /// reaches the manifest.
    @Test("A 503 that clears on the third try reaches the manifest, after pauses of 2 and 4 seconds")
    func aFetchThatRecoversReachesTheManifest() async throws {
        let outcome = try await Self.run(["frus1961-63v20.xml": [.status(503), .status(503), .header]])

        #expect(outcome.thrown == nil, "the run refused: \(String(describing: outcome.thrown))")
        #expect(outcome.volumeIds == ["frus1961-63v20", "frus1964-68v02", "frus1969-76v08"])
        #expect(outcome.requests["frus1961-63v20.xml"] == 3)
        #expect(outcome.pauses == [.seconds(2), .seconds(4)])
    }

    /// The statuses the owner named, a 429 and any 5xx, are each tried again.
    @Test("A 429 or a 5xx is tried again", arguments: [429, 500, 502, 503, 504])
    func transientStatusesAreRetried(status: Int) async throws {
        let outcome = try await Self.run(["frus1964-68v02.xml": [.status(status), .header]])

        #expect(outcome.thrown == nil, "a \(status) was not tried again: \(String(describing: outcome.thrown))")
        #expect(outcome.volumeIds?.count == 3)
        #expect(outcome.requests["frus1964-68v02.xml"] == 2)
        #expect(outcome.pauses == [.seconds(2)])
    }

    /// A status that answers the same way every time is not tried again, and still refuses.
    @Test("A 404 or a 403 is not tried again, and the run still writes nothing", arguments: [404, 403])
    func lastingStatusesAreNotRetried(status: Int) async throws {
        let outcome = try await Self.run(["frus1969-76v08.xml": [.status(status), .header]])

        guard case ManifestGeneratorRunner.RunError.incompleteListing(_, _, let failures, _)? = outcome.thrown else {
            Issue.record("a \(status) did not refuse the run: \(String(describing: outcome.thrown))")
            return
        }
        #expect(failures.map(\.filename) == ["frus1969-76v08.xml"])
        #expect(outcome.requests["frus1969-76v08.xml"] == 1, "a \(status) was tried again")
        #expect(outcome.pauses.isEmpty)
        #expect(outcome.file == Self.previousFile)
    }

    /// A fetch that never clears is tried four times in all, with pauses of 2, 4 and 8 seconds.
    @Test("A 503 that never clears is tried four times, after pauses of 2, 4 and 8 seconds")
    func aLastingFailureIsTriedFourTimes() async throws {
        let outcome = try await Self.run(["frus1961-63v20.xml": [.status(503)]])

        #expect(outcome.requests["frus1961-63v20.xml"] == 4)
        #expect(outcome.pauses == [.seconds(2), .seconds(4), .seconds(8)])
        #expect(outcome.file == Self.previousFile)
    }

    /// **Not only a fetch.** A header that does not parse leaves its volume out by the same road,
    /// so it refuses the run too: the runbook's interim step already required `Errors: 0`, which
    /// counts it.
    @Test("A header that does not parse leaves the previous file and names the volume")
    func anUnparseableHeaderWritesNothing() async throws {
        let outcome = try await Self.run(["frus1964-68v02.xml": [.garbage]])

        guard case ManifestGeneratorRunner.RunError.incompleteListing(_, _, let failures, _)? = outcome.thrown else {
            Issue.record("an unparseable header did not refuse the run: \(String(describing: outcome.thrown))")
            return
        }
        #expect(failures.map(\.filename) == ["frus1964-68v02.xml"])
        #expect(failures.first?.reason.hasPrefix("parse failed") == true, "\(failures)")
        #expect(outcome.requests["frus1964-68v02.xml"] == 1, "a header that does not parse was fetched again")
        #expect(outcome.file == Self.previousFile)
    }

    /// Two volumes that fail are both named, in file-name order, whatever order they failed in.
    @Test("Every volume that failed is named, in file-name order")
    func everyFailureIsNamed() async throws {
        let outcome = try await Self.run([
            "frus1969-76v08.xml": [.status(503)], "frus1961-63v20.xml": [.status(404)],
        ])

        guard case ManifestGeneratorRunner.RunError.incompleteListing(
            let listed, let written, let failures, _)? = outcome.thrown else {
            Issue.record("the run did not refuse: \(String(describing: outcome.thrown))")
            return
        }
        #expect(listed == 3)
        #expect(written == 1)
        #expect(failures.map(\.filename) == ["frus1961-63v20.xml", "frus1969-76v08.xml"])
        #expect(outcome.file == Self.previousFile)
    }

    /// **The control,** without which every refusal above could be a run that cannot write at all:
    /// a host that answers every volume writes all three, and pauses for nothing.
    @Test("A run whose every fetch succeeds writes every volume of the listing")
    func aSoundRunWritesEveryVolume() async throws {
        let outcome = try await Self.run([:])

        #expect(outcome.thrown == nil, "the sound run refused: \(String(describing: outcome.thrown))")
        #expect(outcome.volumeIds == ["frus1961-63v20", "frus1964-68v02", "frus1969-76v08"])
        #expect(outcome.pauses.isEmpty)
    }
}
