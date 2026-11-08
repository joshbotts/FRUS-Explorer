// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// Side-loading's validation and import of a volume file, moved here from the app's
// `Settings/SettingsView.swift` (FRUS Explorer Light, S21a, 2026-11-08) so that a host outside the
// app accepts and refuses a file as the app does. Unchanged but for access: `SideloadError` and
// `SideloadValidator` are public, with the validator's initialiser; the sniffing delegate is internal
// as before. `XMLParser` is FoundationXML's on Linux.

// MARK: - SideloadError

/// Errors from `SideloadValidator`.
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 2026-11-08 (FRUS Explorer Light, S21a): moved into FRUSCoreKit, public, unchanged
public enum SideloadError: LocalizedError {
    case notXML
    case notFRUSVolume(reason: String)
    case duplicateVolume(volumeId: String)
    case copyFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .notXML:
            return String(localized: "sideload.error.notXML",
                          defaultValue: "The selected file is not valid XML.")
        case .notFRUSVolume(let reason):
            return String(localized: "sideload.error.notFRUS",
                          defaultValue: "This XML file does not appear to be a FRUS volume: \(reason)")
        case .duplicateVolume(let id):
            return String(localized: "sideload.error.duplicate",
                          defaultValue: "Volume ‘\(id)’ is already present. Delete it first to replace it.")
        case .copyFailed(let error):
            return String(localized: "sideload.error.copy",
                          defaultValue: "Could not import the file: \(error.localizedDescription)")
        }
    }
}

// MARK: - SideloadValidator

/// Validates and imports a sideloaded FRUS volume XML file.
///
/// Validation checks:
/// 1. File is parseable as XML.
/// 2. Root element looks like a FRUS TEI volume (root named `volume` or `TEI`/`tei`,
///    or has a `volumeId` / `xml:id` attribute).
/// 3. VolumeId (derived from filename) does not already exist on disk.
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 2026-11-08 (FRUS Explorer Light, S21a): moved into FRUSCoreKit, public, with
///          its initialiser spelled out and the parse's result discarded with `_ =`, as the kit's
///          `FRUSDocumentParser` discards it, since FoundationXML's `parse()` is not
///          `@discardableResult` and Linux warns; otherwise unchanged
public struct SideloadValidator {

    /// A validator. It keeps no state: each call to `validate(url:volumesDirectory:)` stands alone.
    public init() {}

    /// Validates the file at `url` and imports it to `volumesDirectory` if valid.
    ///
    /// - Returns: The `volumeId` of the imported volume.
    /// - Throws: `SideloadError` describing the failure.
    public func validate(url: URL, volumesDirectory: URL) throws -> String {
        let volumeId = url.deletingPathExtension().lastPathComponent

        // 1. Check root element via a quick XML parse
        guard let xmlParser = XMLParser(contentsOf: url) else {
            throw SideloadError.notXML
        }
        let rootDelegate = RootElementSnifferDelegate()
        xmlParser.delegate = rootDelegate
        _ = xmlParser.parse()

        // An XML parse error (before finding root) means invalid XML
        if !rootDelegate.rootElementFound, xmlParser.parserError != nil {
            throw SideloadError.notXML
        }

        guard rootDelegate.rootElementFound else {
            throw SideloadError.notFRUSVolume(reason: String(
                localized: "sideload.error.noRoot", defaultValue: "No root element found."))
        }

        guard rootDelegate.looksLikeFRUS else {
            let reason = String(
                localized: "sideload.error.unexpectedRoot",
                defaultValue: "Unexpected root element ’\(rootDelegate.rootElementName ?? "unknown")'.")
            throw SideloadError.notFRUSVolume(reason: reason)
        }

        // 2. Check for duplicate
        let dest = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        if FileManager.default.fileExists(atPath: dest.path) {
            throw SideloadError.duplicateVolume(volumeId: volumeId)
        }

        // 3. Copy file to volumes directory
        do {
            try FileManager.default.createDirectory(
                at: volumesDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: dest)
            // Match downloaded volumes: keep the XML out of iCloud Backup / Time Machine, since
            // it is re-obtainable and bulky. The old macOS sideload path set this and the
            // validator did not, so which of the two you used decided whether your copy got
            // backed up (S-2b routed macOS through the validator, so it belongs here now).
            try? (dest as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        } catch {
            throw SideloadError.copyFailed(underlying: error)
        }

        #if DEBUG
        print("[Settings] Sideloaded volume: \(volumeId)")
        #endif

        return volumeId
    }
}

// MARK: - RootElementSnifferDelegate (internal for testing)

final class RootElementSnifferDelegate: NSObject, XMLParserDelegate {
    var rootElementFound = false
    var looksLikeFRUS = false
    var rootElementName: String? = nil
    private var hasFoundRoot = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        guard !hasFoundRoot else { return }
        hasFoundRoot = true
        rootElementFound = true
        rootElementName = elementName

        let lower = elementName.lowercased()
        let knownRoots: Set<String> = ["volume", "tei", "tei:tei"]
        let hasFRUSAttribute = attributes.keys.contains("volumeId")
            || attributes.keys.contains("xml:id")
            || (attributes["xmlns"] ?? "").contains("frus")

        looksLikeFRUS = knownRoots.contains(lower) || hasFRUSAttribute

        // Stop parsing — we have what we need
        parser.abortParsing()
    }
}
