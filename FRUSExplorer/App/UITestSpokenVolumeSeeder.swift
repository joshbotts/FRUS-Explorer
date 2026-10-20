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

// MARK: - The spoken-row volume (#1684)

/// One side-loaded volume of three sections, for the UI suite that reads what VoiceOver says of a
/// search result.
///
/// ## Why the other fixtures cannot carry that suite
/// A result's label says every part its row draws (`SearchResultAccessibility`). The browse
/// fixture's documents draw a heading, a dateline and a volume id, and no number, classification
/// chip or badge; the bulk volume's draw a number and no dateline. Seven suites stand on the first
/// and two on the second, so this volume is written beside them, with a section for each part.
///
/// ## Its shape
/// Three sections, each holding ``spokenQueryWord``, which no other fixture holds, so one keyword
/// search lists exactly these three:
/// - `d7`, `@n` 7 and no number in its head, so the row draws the number beside the heading:
///   "UI Test Spoken Document", dated, with a source note whose second sentence is a classification
///   marking, "Secret; Nodis".
/// - `d8`, an editorial note as the corpus encodes one (`subtype="editorial-note"`), `@n` 8, undated.
/// - `preface`, front matter as the corpus encodes it (`type="section" subtype="preface"`).
///
/// ## Contract — the bulk volume's own
/// `#if DEBUG`, and inert unless `FRUS_UI_TEST_SEED_SPOKEN_VOLUME` is `1`. A launch that asks writes
/// the file and indexes it before the pipeline is published; **any launch that does not ask removes
/// the file and its index rows**, so no other suite ever lists it.
///
/// Version history:
///   1.0 — #1684: initial implementation
extension UITestVolumeSeeder {

    /// The launch-environment key a UI test sets, to `1`, to request the spoken-row volume.
    static let spokenVolumeEnvironmentKey = "FRUS_UI_TEST_SEED_SPOKEN_VOLUME"

    /// The volume's id. Not a catalogue volume's, so Browse lists it only as a side-load.
    static let spokenVolumeId = "uitest-spoken-01"

    /// The word every one of its sections holds, and no other fixture's does.
    static let spokenQueryWord = "xylograph"

    /// Writes the volume when `FRUS_UI_TEST_SEED_SPOKEN_VOLUME` is `1`, and removes it when it is
    /// not. Called from `bootDownloadManager()` beside the bulk volume, before the pipeline is built.
    ///
    /// - Parameter volumesDirectory: The app's volumes directory.
    /// - Returns: Whether a file was written or removed.
    @discardableResult
    static func prepareSpokenVolumeIfRequested(in volumesDirectory: URL) -> Bool {
        prepareSpokenVolume(
            requested: ProcessInfo.processInfo.environment[spokenVolumeEnvironmentKey] == "1",
            in: volumesDirectory)
    }

    /// ``prepareSpokenVolumeIfRequested(in:)`` with the environment read lifted out, so a test can
    /// drive both arms.
    ///
    /// - Parameters:
    ///   - requested: Whether this launch asked for the volume.
    ///   - volumesDirectory: The app's volumes directory.
    /// - Returns: Whether a file was written (requested) or removed (not requested).
    @discardableResult
    static func prepareSpokenVolume(requested: Bool, in volumesDirectory: URL) -> Bool {
        let url = volumesDirectory.appendingPathComponent("\(spokenVolumeId).xml")
        if requested {
            let written = (try? spokenVolumeXML().write(to: url, atomically: true, encoding: .utf8)) != nil
            if written { print("[UITestVolumeSeeder] Seeded the spoken-row volume") }
            return written
        }
        guard FileManager.default.fileExists(atPath: url.path),
              (try? FileManager.default.removeItem(at: url)) != nil else { return false }
        print("[UITestVolumeSeeder] Removed the spoken-row volume")
        return true
    }

    /// The volume's TEI: a header the side-load catalogue can read a title from, a preface in the
    /// front matter, and a document and an editorial note in one compilation.
    static func spokenVolumeXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>UI Test Spoken Volume</title></titleStmt>
          <publicationStmt><date>1998</date></publicationStmt>
          <sourceDesc><p>UI test fixture — not real FRUS content.</p></sourceDesc></fileDesc></teiHeader>
          <text>
            <front>
              <div type="section" subtype="preface" xml:id="preface">
                <head>UI Test Spoken Preface</head>
                <p>Spoken-row fixture, \(spokenQueryWord) preface.</p>
              </div>
            </front>
            <body>
              <div type="compilation" xml:id="comp1">
                <head>UI Test Spoken Compilation</head>
                <div type="document" xml:id="d7" n="7">
                  <head>UI Test Spoken Document<note n="0" type="source" xml:id="d7fn0">Source: UI test fixture, Spoken File. Secret; Nodis.</note></head>
                  <dateline>Washington, May 4, 1962</dateline>
                  <p>Spoken-row fixture, \(spokenQueryWord) document.</p>
                </div>
                <div type="document" subtype="editorial-note" xml:id="d8" n="8">
                  <head>UI Test Spoken Editorial Note</head>
                  <p>Spoken-row fixture, \(spokenQueryWord) editorial note.</p>
                </div>
              </div>
            </body>
          </text>
        </TEI>
        """
    }

    /// Brings the volume's index rows to what this launch asked for, before `AppState` publishes the
    /// pipeline: indexed when asked for and not yet indexed, removed when not asked for and still
    /// there.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline boot just built and has not yet published.
    ///   - requested: Whether this launch asked for the volume. Boot passes nothing and gets the
    ///     launch environment's answer; a test passes each answer in turn.
    static func prepareSpokenVolumeIndex(
        pipeline: IndexingPipeline,
        requested: Bool = ProcessInfo.processInfo.environment[spokenVolumeEnvironmentKey] == "1"
    ) async {
        let indexed = (try? pipeline.isVolumeIndexed(spokenVolumeId)) == true
        switch StorageRowIndexAction.plan(requested: requested, indexed: indexed) {
        case .index:
            try? await pipeline.indexVolume(spokenVolumeId)
        case .unindex:
            try? await pipeline.removeVolume(spokenVolumeId)
        case .none:
            break
        }
    }
}
#endif
