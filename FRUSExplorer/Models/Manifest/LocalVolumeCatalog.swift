// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
// No `import TEIHeaderKit`: like FTS5Store, WordCloudKit and SourceNoteKit, the kit's sources are
// compiled directly INTO the app target (project.yml), so its types are already in this module.
// The SPM library target exists for the generator, which links it as a real module.

// MARK: - LocalVolumeCatalog

/// The catalogue entry for a volume the published catalogue does not know: a side-loaded file.
///
/// ## The bug this exists to close (#777)
/// Side-loading did exactly two durable things — copy the XML into the volumes directory and index
/// it into SQLite. Neither records that *a volume exists*. Every navigation surface, meanwhile,
/// enumerates `manifest.json`, and `ManifestStore` has no mutation API at all. So a side-loaded
/// volume was fully searchable (index-keyed) and structurally unrepresentable in Browse
/// (manifest-keyed): not a failure, a missing half.
///
/// This is that half. It reads the volume's own `<teiHeader>` with **`TEIHeaderKit` — the same
/// parser that built `manifest.json`** — and mints a `VolumeManifestEntry` marked
/// `.sideloaded`. Every one of the ~53 `entry(forVolumeId:)` call sites then works: the volume has
/// a title instead of a raw id, a coverage range, editors, and a place in a subseries.
///
/// ## Why a sidecar file and not a `@Model`
/// Adding a stored property to a mirrored `@Model` trips the R-7 CloudKit schema-deploy gate, and
/// this data has no business syncing: it is **fully reconstructible from the XML sitting beside
/// it**, and a device that does not have the file has no use for its metadata. A JSON sidecar next
/// to the volume keeps the two together — delete the volume and its metadata goes with it, with no
/// orphan row to reconcile.
///
/// ## Why reconciliation is lazy rather than eager
/// Volumes side-loaded before this shipped have no sidecar. Rather than parsing every unknown file
/// at launch — which would put an XML parse per volume on the boot path — ``reconcile(in:known:)``
/// parses only files that are unknown *and* unparsed, and it is called from the corpus-change
/// refresh that side-loading already triggers. A first launch after updating pays once.
///
/// Version history:
///   1.0 — Session 2026-08-09: #777
public struct LocalVolumeCatalog: Sendable {

    /// The sidecar's filename for a volume, e.g. `frus1969-76v01.frusmeta.json`.
    static func sidecarName(for volumeId: String) -> String { "\(volumeId).frusmeta.json" }

    // MARK: - Minting

    /// Builds a `.sideloaded` entry from a volume's own TEI header.
    ///
    /// - Parameters:
    ///   - volumeId: The id the side-load derived from the filename.
    ///   - url: The volume XML, already copied into the volumes directory.
    ///   - sizeBytes: The file's size, so storage figures are right without a second `stat`.
    /// - Returns: An entry, or `nil` if the header could not be parsed — in which case the caller
    ///   should leave the volume unlisted rather than invent a title. A volume that will not parse
    ///   will not render either, and a browse row leading to a parse failure is worse than no row.
    public static func entry(volumeId: String, url: URL, sizeBytes: Int) -> VolumeManifestEntry? {
        guard let data = try? Data(contentsOf: url),
              let header = try? TEIHeaderParser.parse(data) else { return nil }

        // Whitespace-collapse to match `VolumeManifestEntry`'s own decoder: raw TEI indents the
        // title element, so an uncollapsed title arrives with embedded newlines.
        let title = header.title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return VolumeManifestEntry(
            volumeId: volumeId,
            filename: url.lastPathComponent,
            // The same filename→subseries derivation the manifest uses. A file that does not look
            // like a FRUS volume id lands in its own group rather than being dropped — see
            // `sideloadedSubseries`.
            subseries: subseries(for: volumeId),
            title: title.isEmpty ? volumeId : title,
            dateRange: DateRange(earliest: header.earliestDate, latest: header.latestDate),
            publicationDate: header.publicationDate,
            // The TEI header carries no publication status. `.published` is what the manifest
            // generator records for every volume for the same reason.
            status: .published,
            editors: header.editors,
            generalEditor: header.generalEditor,
            documentCount: header.documentCount,
            sizeBytes: sizeBytes,
            tags: header.tags,
            provenance: .sideloaded
        )
    }

    /// The subseries a side-loaded volume belongs to.
    ///
    /// A conventionally-named file (`frus1969-76v01.xml`) joins the era its neighbours are in, so
    /// an unpublished pre-release sits beside the published volumes it belongs with. Anything else
    /// gets ``sideloadedSubseries`` — its own group, rather than a silent drop or a wrong era.
    static func subseries(for volumeId: String) -> String {
        guard volumeId.hasPrefix("frus") else { return sideloadedSubseries }
        let rest = volumeId.dropFirst(4)
        guard let match = rest.range(of: #"^\d{4}(-\d{2,4})?"#, options: .regularExpression) else {
            return sideloadedSubseries
        }
        return String(rest[match])
    }

    /// The group for a file whose name says nothing about where it belongs.
    public static let sideloadedSubseries = "sideloaded"

    // MARK: - Persistence

    /// Writes the entry beside its volume.
    static func write(_ entry: VolumeManifestEntry, in directory: URL) {
        let url = directory.appendingPathComponent(sidecarName(for: entry.volumeId))
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url, options: .atomic)
        // Match the volume XML: re-derivable from a file the user already has, so it has no place
        // in a backup.
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }

    /// Reads every sidecar in `directory`, dropping any that will not decode.
    ///
    /// A sidecar that fails to decode is treated as absent, not as an error: the next reconcile
    /// re-parses the volume and rewrites it. That keeps a format change from stranding a volume.
    public static func load(from directory: URL) -> [VolumeManifestEntry] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let decoder = JSONDecoder()
        return names
            .filter { $0.hasSuffix(".frusmeta.json") }
            .compactMap { name -> VolumeManifestEntry? in
                guard let data = try? Data(contentsOf: directory.appendingPathComponent(name))
                else { return nil }
                return try? decoder.decode(VolumeManifestEntry.self, from: data)
            }
            // A sidecar decodes without a `provenance` (the property is not decoded), so it would
            // arrive as `.publishedCatalogue` — which would hand it a download URL. Everything read
            // from here is side-loaded by construction.
            .map { entry in
                var e = entry
                e.provenance = .sideloaded
                return e
            }
            .sorted { $0.volumeId < $1.volumeId }
    }

    // MARK: - Reconciliation

    /// Parses a sidecar for every volume on disk that the catalogue does not know and that has no
    /// sidecar yet, and returns the full local set.
    ///
    /// This is what repairs volumes side-loaded before #777 shipped. It is deliberately not on the
    /// boot path's critical section: it walks a directory listing, and only *parses* files that are
    /// both unknown and unparsed, so the steady-state cost is one `contentsOfDirectory`.
    ///
    /// - Parameters:
    ///   - directory: The volumes directory.
    ///   - known: The catalogue's volume ids. Anything on disk outside this set is side-loaded.
    public static func reconcile(in directory: URL, known: Set<String>) -> [VolumeManifestEntry] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
        var existing = Dictionary(uniqueKeysWithValues: load(from: directory).map { ($0.volumeId, $0) })

        for name in names where name.hasSuffix(".xml") {
            let volumeId = String(name.dropLast(4))
            guard !known.contains(volumeId), existing[volumeId] == nil else { continue }
            let url = directory.appendingPathComponent(name)
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            guard let minted = entry(volumeId: volumeId, url: url, sizeBytes: size ?? 0) else { continue }
            write(minted, in: directory)
            existing[volumeId] = minted
        }

        // A sidecar whose volume has been removed is dropped, and its file with it — the metadata
        // describes a file that is gone.
        for (volumeId, _) in existing where !fm.fileExists(
            atPath: directory.appendingPathComponent("\(volumeId).xml").path) {
            try? fm.removeItem(at: directory.appendingPathComponent(sidecarName(for: volumeId)))
            existing.removeValue(forKey: volumeId)
        }

        return existing.values.sorted { $0.volumeId < $1.volumeId }
    }
}
