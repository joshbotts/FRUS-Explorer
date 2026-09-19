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

/// The offline overlay's `sizeBytes` must be the VOLUME's size, even through a symlink.
///
/// `FileManager.attributesOfItem(atPath:)` describes a symbolic link itself, not its target. The
/// overlay read it directly, so a `VOLUMES_DIR` whose volume FILES are symlinks recorded each
/// link's own 51–65 bytes (552 volumes in the run that found it) — and still printed "Parse
/// errors: 0", because the header parse reads through the link. Found by the frus1981-88v16
/// corrections audit (2026-09-19).
///
/// Two levels, because either can regress alone: the helper (`fileSize(at:)`), and the overlay
/// that must call it — a direct read restored at the call site would leave the helper's tests
/// green.
///
/// Version history:
///   1.0 — 2026-09-19: initial implementation
@Suite("Manifest overlay — file size")
struct ManifestOverlayFileSizeTests {

    /// A scratch directory holding a real "volume" (a parseable TEI header) in `real/` and a
    /// symlink to it, under the same filename, in `volumes/`.
    private func fixture() throws -> (root: URL, file: URL, link: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManifestOverlayFileSizeTests-\(UUID().uuidString)")
        let real = root.appendingPathComponent("real")
        let volumes = root.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let file = real.appendingPathComponent("frus-test.xml")
        try Data(TEIFixtures.fullHeader.utf8).write(to: file)
        let link = volumes.appendingPathComponent("frus-test.xml")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        return (root, file, link)
    }

    /// The size `attributesOfItem(atPath:)` reports for `url` without following it — what the
    /// overlay used to record.
    private func naiveSize(of url: URL) throws -> Int? {
        (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
    }

    @Test("A plain file reports its own size")
    func plainFile() throws {
        let (root, file, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(ManifestGeneratorRunner.fileSize(at: file) == TEIFixtures.fullHeader.utf8.count)
    }

    @Test("A symlink reports its TARGET's size, not its own")
    func symlinkFollowsToTheVolume() throws {
        let (root, file, link) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let expected = try #require(try naiveSize(of: file))

        // The trap is real on this fixture: the naive read returns the link's own size. Without
        // this the assertion below could pass on a platform whose naive read followed links.
        #expect(try naiveSize(of: link) != expected, "the fixture must reproduce the symlink trap")
        #expect(ManifestGeneratorRunner.fileSize(at: link) == expected)
    }

    @Test("A dangling symlink reports nil, not the link's own size")
    func danglingSymlinkIsRefused() throws {
        let (root, file, link) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.removeItem(at: file)

        // `resolvingSymlinksInPath()` returns a dangling link unchanged, so a helper that only
        // resolved would hand back the link's few bytes — the original bug by another route.
        #expect(try naiveSize(of: link) != nil, "the link itself must still exist")
        #expect(ManifestGeneratorRunner.fileSize(at: link) == nil)
    }

    @Test("A missing file reports nil, so the overlay keeps the manifest's value")
    func missingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManifestOverlayFileSizeTests-missing-\(UUID().uuidString).xml")
        #expect(ManifestGeneratorRunner.fileSize(at: missing) == nil)
    }

    @Test("The overlay records the target's size for a volume file that is a symlink")
    func overlayFollowsASymlinkedVolumeFile() throws {
        let (root, file, link) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let expected = try #require(try naiveSize(of: file))
        #expect(try naiveSize(of: link) != expected, "the fixture must reproduce the symlink trap")

        let manifest = root.appendingPathComponent("manifest.json")
        try ManifestWriter.write(entries: [VolumeManifestEntry(
            volumeId: "frus-test", filename: "frus-test.xml", subseries: "test", title: "Test",
            dateRange: DateRange(earliest: nil, latest: nil), publicationDate: nil,
            status: .published, editors: [], generalEditor: nil, documentCount: 0,
            sizeBytes: 0, tags: [])], to: manifest.path)

        ManifestGeneratorRunner.runLocalOverlay(
            outputPath: manifest.path,
            volumesDirectory: link.deletingLastPathComponent().path)

        let entries = try JSONDecoder().decode(
            [VolumeManifestEntry].self, from: Data(contentsOf: manifest))
        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.sizeBytes == expected, """
            The overlay recorded \(entry.sizeBytes) bytes for a volume of \(expected) — the size of \
            the symlink, not of the file it points at.
            """)
    }
}
