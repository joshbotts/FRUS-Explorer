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

// MARK: - The bulk-actions volume (#1576 lane 3)

/// One side-loaded volume of thirty documents, for the UI suite that selects search results.
///
/// ## Why the browse fixture cannot carry that suite
/// `FRUS_UI_TEST_SEED_VOLUME` writes six documents. A page of results is twenty-five rows, so no
/// search over the fixture has a second page, and nothing can be read about a selection that
/// outlives a page turn or about a whole page marked reviewed. Two suites depend on that
/// fixture's shape, so it is left alone and this volume is written beside it.
///
/// ## Its shape
/// Thirty documents, `d1`…`d30`, titled "UI Test Bulk Document 01"…"30", each with one paragraph
/// that holds ``bulkQueryWord``. No other fixture holds that word, so one keyword search lists
/// exactly these thirty: a first page of twenty-five and a second of five.
///
/// ## Contract — the storage rows' own
/// `#if DEBUG`, and inert unless `FRUS_UI_TEST_SEED_BULK_VOLUME` is `1`. A launch that asks writes
/// the file and indexes it before the pipeline is published; **any launch that does not ask
/// removes the file and its index rows**, so no other suite ever lists it.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
extension UITestVolumeSeeder {

    /// The launch-environment key a UI test sets, to `1`, to request the bulk volume.
    static let bulkVolumeEnvironmentKey = "FRUS_UI_TEST_SEED_BULK_VOLUME"

    /// The bulk volume's id. Not a catalogue volume's, so Browse lists it only as a side-load.
    static let bulkVolumeId = "uitest-bulk-01"

    /// How many documents it holds: one page of results and five more.
    static let bulkDocumentCount = 30

    /// The word every one of its paragraphs holds, and no other fixture's does.
    static let bulkQueryWord = "quillwort"

    /// A bulk document's `<head>`: "UI Test Bulk Document 07".
    ///
    /// - Parameter number: The document's number, from 1.
    static func bulkDocumentTitle(_ number: Int) -> String {
        String(format: "UI Test Bulk Document %02d", number)
    }

    /// Writes the bulk volume when `FRUS_UI_TEST_SEED_BULK_VOLUME` is `1`, and removes it when it
    /// is not. Called from `bootDownloadManager()` beside the storage rows, before the pipeline
    /// is built.
    ///
    /// - Parameter volumesDirectory: The app's volumes directory.
    /// - Returns: Whether a file was written or removed.
    @discardableResult
    static func prepareBulkVolumeIfRequested(in volumesDirectory: URL) -> Bool {
        prepareBulkVolume(
            requested: ProcessInfo.processInfo.environment[bulkVolumeEnvironmentKey] == "1",
            in: volumesDirectory)
    }

    /// ``prepareBulkVolumeIfRequested(in:)`` with the environment read lifted out, so a test can
    /// drive both arms.
    ///
    /// - Parameters:
    ///   - requested: Whether this launch asked for the volume.
    ///   - volumesDirectory: The app's volumes directory.
    /// - Returns: Whether a file was written (requested) or removed (not requested).
    @discardableResult
    static func prepareBulkVolume(requested: Bool, in volumesDirectory: URL) -> Bool {
        let url = volumesDirectory.appendingPathComponent("\(bulkVolumeId).xml")
        if requested {
            let written = (try? bulkVolumeXML().write(to: url, atomically: true, encoding: .utf8)) != nil
            if written { print("[UITestVolumeSeeder] Seeded the bulk volume") }
            return written
        }
        guard FileManager.default.fileExists(atPath: url.path),
              (try? FileManager.default.removeItem(at: url)) != nil else { return false }
        print("[UITestVolumeSeeder] Removed the bulk volume")
        return true
    }

    /// The bulk volume's TEI: a header the side-load catalogue can read a title from, and thirty
    /// documents in one compilation.
    static func bulkVolumeXML() -> String {
        let documents = (1...bulkDocumentCount).map { number in
            """
                  <div type="document" xml:id="d\(number)" n="\(number)">
                    <head>\(bulkDocumentTitle(number))</head>
                    <p>Bulk-actions fixture, \(bulkQueryWord) paragraph \(number).</p>
                  </div>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>UI Test Bulk Volume</title></titleStmt>
          <publicationStmt><date>1997</date></publicationStmt>
          <sourceDesc><p>UI test fixture — not real FRUS content.</p></sourceDesc></fileDesc></teiHeader>
          <text><body>
            <div type="compilation" xml:id="comp1">
              <head>UI Test Bulk Compilation</head>
        \(documents)
            </div>
          </body></text>
        </TEI>
        """
    }

    /// Brings the bulk volume's index rows to what this launch asked for, before `AppState`
    /// publishes the pipeline: indexed when asked for and not yet indexed, removed when not asked
    /// for and still there.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline boot just built and has not yet published.
    ///   - requested: Whether this launch asked for the volume. Boot passes nothing and gets the
    ///     launch environment's answer; a test passes each answer in turn.
    static func prepareBulkVolumeIndex(
        pipeline: IndexingPipeline,
        requested: Bool = ProcessInfo.processInfo.environment[bulkVolumeEnvironmentKey] == "1"
    ) async {
        let indexed = (try? pipeline.isVolumeIndexed(bulkVolumeId)) == true
        switch StorageRowIndexAction.plan(requested: requested, indexed: indexed) {
        case .index:
            try? await pipeline.indexVolume(bulkVolumeId)
        case .unindex:
            try? await pipeline.removeVolume(bulkVolumeId)
        case .none:
            break
        }
    }
}
#endif
