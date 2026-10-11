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

#if DEBUG
import Foundation

// MARK: - UITestMeaningSeeder

/// A Meaning search a UI test can reach (#1577 lane 3).
///
/// ## Why
/// No UI test reached a Meaning result. A Meaning search needs the 229 MB query encoder, which no
/// simulator has and no test may download, and it needs a match file for each volume it ranks.
/// So every surface a Meaning list reaches — its rows and chips, its strip, a working corpus it
/// ranks inside — was tested below the view or not at all.
///
/// ## What it replaces, and what it leaves real
/// Three inputs of the searcher. The searcher itself (`SemanticQuerySearcher`), the backend, the
/// bundled index and the bundled sign bits are the app's own.
///
/// - **The question's embedding.** The searcher is built with its `embedOverride`, so the encoder
///   is never loaded. Every question is answered with a vector made from the *bundled sign bits of
///   one document*: +1 where its bit is set, −1 where it is not. A vector taken from anywhere else
///   would almost never land near the fixture volume, since a plain Meaning search chooses its 800
///   candidates from those very bits across 314,616 documents.
/// - **The match-file store.** The seam's searcher reads a store of its own, in a folder of the
///   temporary directory made afresh at each launch that asks, holding one file: the fixture
///   volume's. The app's store is not read, written or cleared. So what the searcher can score is
///   the fixture volume and nothing else, whatever match files the simulator already holds, and no
///   published match file is replaced. The planted file has one row for each of the volume's
///   bundled rows, each the ±1 vector of that row's own bundled sign bits, written with the kit's
///   writer under the bundled provenance digest and with the bundled row count, both of which the
///   store checks (with the file's magic, version, width and length) before it opens one. The
///   exact score of a row is then `1 − 2h/512`, where `h` is its Hamming distance from the
///   question: the ranking the candidate scan itself implies.
/// - **The request for missing match files.** It always declines, so nothing is asked of the
///   network for the candidates in volumes the seam's store does not hold. They are counted as
///   unscored, as a reader's are.
///
/// ## The two questions
/// Measured on the bundled artifacts through the kit's own readers, for the volume the UI suites
/// seed, `frus1961-63v06` (its fixture holds d1, d2 and d3, which have bundled rows, and n1, n2
/// and t1, which have none):
///
/// - **Near, the default**: the bits of the fixture's ``nearDocumentID``, d2. Its three documents
///   with rows are the first three of the whole corpus by Hamming distance (d2, then d1 at 90 bits,
///   then d3 at 100), so a plain Meaning search lists all three: d2 at 100%, d1 at 65%, d3 at 61%.
///   **They are three of 78 hits.** The real volume has 120 documents and 78 of their rows are
///   among the 800 candidates; the planted file scores every one, and the fixture holds three. So
///   the strip above the list says that 75 close matches are not listed because the device's index
///   does not hold those documents, and that 722 possible matches in 179 volumes could not be
///   scored.
/// - **Far**, for a question that holds the word ``farMarker``: the bits of ``farDocument``, the
///   first document of `frus1861`. None of the fixture volume's 120 rows is among its 800
///   candidates (the nearest of d1, d2 and d3 is 75,495th), so a plain Meaning search lists
///   nothing, with all 800 unscored, in 134 volumes, while a search inside a set of the fixture's
///   documents scores every member that has a row: d2 and d3 at 24%, d1 at 16%. That difference
///   is what #1577 lane 1 changed, and it is the reason for a second question.
///
/// `UITestMeaningSeederTests` holds those figures against the bundled artifacts. A regenerated
/// bundle that moves them fails there first, and says which figure moved; the UI suite would fail
/// after it, with a row count.
///
/// ## What it does not reach
/// The card a keyword search with no results shows, which offers the model's download: that card
/// asks the model store whether the model is on the device, and the seam plants no model.
///
/// ## Contract
/// Gated twice over, as `UITestVolumeSeeder` is: the whole file is `#if DEBUG`, and nothing is made
/// unless ``environmentKey`` is `1` and `FRUS_UI_TEST_SEED_VOLUME` names the volume. A launch that
/// does not ask does nothing at all here.
///
/// Version history:
///   1.0 — #1577 lane 3: initial implementation
enum UITestMeaningSeeder {

    /// The launch-environment key that turns the seam on, when its value is `1`.
    static let environmentKey = "FRUS_UI_TEST_SEED_MEANING"

    /// The fixture document whose bundled sign bits answer every question but a far one.
    static let nearDocumentID = "d2"

    /// The document whose bundled sign bits answer a question that holds ``farMarker``: one whose
    /// 800 nearest documents include none of the fixture volume's.
    static let farDocument = (volumeID: "frus1861", documentID: "d1")

    /// The word that makes a question a far one, matched without regard to case.
    static let farMarker = "afield"

    /// The folder of the temporary directory the seam's own match-file store is made in.
    static let storeFolderName = "uitest-meaning-match-files"

    /// What a launch that asked for the seam gives the searcher.
    struct Seam: Sendable {
        /// The fixture volume whose match file was planted.
        let volumeID: String
        /// The stand-in for the query encoder: the near vector, or the far one for a question that
        /// holds ``UITestMeaningSeeder/farMarker``.
        let embed: @Sendable (String) async throws -> [Double]
        /// The seam's own match-file store, which holds the planted file and nothing else.
        let shardStore: SemanticShardStore
    }

    /// Whether `environment` asks for the seam.
    static func isRequested(_ environment: [String: String]) -> Bool {
        environment[environmentKey] == "1"
    }

    /// Whether `question` is a far one.
    static func isFar(_ question: String) -> Bool {
        question.range(of: farMarker, options: .caseInsensitive) != nil
    }

    /// The ±1 vector of a corpus row's sign bits: +1 where the bit is set, −1 where it is not.
    ///
    /// The inverse of `SemanticQuantization.packSignBits`, whose two conventions it has to share:
    /// bits fill most-significant first within a byte, and a set bit is a component that was zero
    /// or above. Packed again, the vector gives the row's own bits back.
    ///
    /// - Parameters:
    ///   - row: The row in the corpus tier.
    ///   - corpus: The bundled sign bits.
    /// - Returns: The vector, at the corpus's width, or `nil` for a row the corpus does not hold.
    static func signVector(ofRow row: Int, in corpus: SemanticCorpusVectors) -> [Double]? {
        guard row >= 0, row < corpus.documentCount else { return nil }
        // The accessor hands over the first row's address and the ROW COUNT. The row's width is
        // the corpus's own `bytesPerRow`.
        let width = corpus.bytesPerRow
        return corpus.withSignBits { pointer, _ in
            let bytes = UnsafeRawBufferPointer(start: pointer.advanced(by: row * width), count: width)
            var vector = [Double](repeating: -1, count: width * 8)
            for index in 0..<(width * 8) where bytes[index / 8] & (UInt8(0x80) >> UInt8(index % 8)) != 0 {
                vector[index] = 1
            }
            return vector
        }
    }

    /// The bytes of a match file for `volumeID`: a row for each of its bundled rows, each the ±1
    /// vector of that row's bundled sign bits as int8 codes, with the scale a unit vector of that
    /// shape quantises to.
    ///
    /// - Parameters:
    ///   - volumeID: The volume to write a match file for.
    ///   - index: The bundled index, for the volume's rows and the provenance pin.
    ///   - corpus: The bundled sign bits.
    /// - Returns: The file's bytes, or `nil` when the index holds no rows for the volume.
    static func syntheticShard(
        for volumeID: String, index: SemanticVectorIndex, corpus: SemanticCorpusVectors
    ) -> Data? {
        guard let rows = index.rows(forVolume: volumeID), !rows.isEmpty else { return nil }
        let dims = index.dims
        var codes: [[Int8]] = []
        codes.reserveCapacity(rows.count)
        for row in rows {
            guard let vector = signVector(ofRow: row, in: corpus), vector.count == dims else { return nil }
            codes.append(vector.map { $0 > 0 ? 127 : -127 })
        }
        // A unit vector whose components are all ±1/√dims quantises to ±127 at this scale
        // (`SemanticQuantization.quantizeInt8`: the peak over 127).
        let scale = Float(1 / (Double(dims).squareRoot() * 127))
        return SemanticVectorsArtifacts.volumeShard(
            codes: codes, scales: [Float](repeating: scale, count: codes.count),
            dims: dims, provenance: index.provenance)
    }

    /// The stand-in encoder for a fixture volume: the near vector for every question, and the far
    /// one for a question that holds ``farMarker``.
    ///
    /// - Parameters:
    ///   - volumeID: The fixture volume.
    ///   - index: The bundled index.
    ///   - corpus: The bundled sign bits.
    /// - Returns: The function, or `nil` when either document has no bundled row.
    static func standInEncoder(
        for volumeID: String, index: SemanticVectorIndex, corpus: SemanticCorpusVectors
    ) -> (@Sendable (String) async throws -> [Double])? {
        guard let nearRow = index.row(documentID: nearDocumentID, volumeID: volumeID),
              let near = signVector(ofRow: nearRow, in: corpus),
              let farRow = index.row(documentID: farDocument.documentID, volumeID: farDocument.volumeID),
              let far = signVector(ofRow: farRow, in: corpus)
        else { return nil }
        return { question in isFar(question) ? far : near }
    }

    /// Makes the seam for a launch that asks for it: a match-file store of its own holding the
    /// fixture volume's planted file, and the stand-in encoder.
    ///
    /// The store's folder is removed and made again each time, so a launch starts from the planted
    /// file alone whatever an earlier one left there. The folder is touched only once both stand-ins
    /// are in hand: a launch that asks for a volume the bundle has no rows for leaves it as it was.
    ///
    /// - Parameters:
    ///   - environment: The launch environment.
    ///   - index: The bundled index.
    ///   - corpus: The bundled sign bits.
    ///   - storeDirectory: Where the seam's store is made. The default is ``storeFolderName`` in
    ///     the temporary directory; a test passes a folder of its own.
    /// - Returns: The seam, or `nil` when the launch did not ask or the seam could not be made.
    static func prepare(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        index: SemanticVectorIndex,
        corpus: SemanticCorpusVectors,
        storeDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(storeFolderName, isDirectory: true)
    ) async -> Seam? {
        guard isRequested(environment),
              let volumeID = environment[UITestVolumeSeeder.environmentKey], !volumeID.isEmpty
        else { return nil }
        guard let embed = standInEncoder(for: volumeID, index: index, corpus: corpus),
              let shard = syntheticShard(for: volumeID, index: index, corpus: corpus)
        else {
            print("[UITestMeaningSeeder] \(volumeID) has no bundled rows to stand in for")
            return nil
        }
        try? FileManager.default.removeItem(at: storeDirectory)
        let store = SemanticShardStore(
            directory: storeDirectory, provenance: index.provenance,
            expectedCounts: Dictionary(index.volumes.map { ($0.volumeID, $0.documentCount) },
                                       uniquingKeysWith: { first, _ in first }))
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("uitest-meaning-\(UUID().uuidString).vec")
        defer { try? FileManager.default.removeItem(at: staging) }
        do {
            try shard.write(to: staging)
            // The store validates the file as it would a published one, then keeps it.
            try await store.adoptShard(from: staging, for: volumeID)
        } catch {
            print("[UITestMeaningSeeder] could not plant \(volumeID): \(error)")
            return nil
        }
        print("[UITestMeaningSeeder] planted a match file for \(volumeID) in a store of its own")
        return Seam(volumeID: volumeID, embed: embed, shardStore: store)
    }

    /// The searcher a launch under the seam uses: the app's own type over the bundled index and
    /// sign bits, with the seam's store, its stand-in encoder, and a request for missing match
    /// files that always declines.
    ///
    /// Here, and not written out where the launch builds its searcher, so that the launch and the
    /// tests of the seam call one function.
    ///
    /// - Parameters:
    ///   - seam: What ``prepare(environment:index:corpus:storeDirectory:)`` made.
    ///   - index: The bundled index.
    ///   - corpus: The bundled sign bits.
    ///   - modelStore: The app's model store. The searcher is given one and, under the seam, never
    ///     asks it for the model.
    /// - Returns: The searcher.
    static func makeSearcher(
        _ seam: Seam, index: SemanticVectorIndex, corpus: SemanticCorpusVectors,
        modelStore: SemanticModelStore
    ) -> SemanticQuerySearcher {
        SemanticQuerySearcher(
            index: index,
            corpus: corpus,
            modelStore: modelStore,
            shardStore: seam.shardStore,
            requestShardFetch: { _ in false },
            embedOverride: seam.embed)
    }
}
#endif
