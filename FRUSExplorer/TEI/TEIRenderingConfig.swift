// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Rendering Config

/// Defines how each TEI element is rendered in the Document view.
///
/// Loaded from the bundled `tei-rendering-config.json` at app launch.
/// When FRUS.odd changes:
///   1. Review the ODD diff for new or modified elements.
///   2. If a new element requires a new AST case, add it to `FRUSASTNode` (Sessions 06/07).
///   3. Add or update the corresponding entry in `tei-rendering-config.json`.
///   4. In most cases, no Swift code change is needed — the config update is sufficient.
///
/// The `schemaVersion` field tracks which version of FRUS.odd the config targets.
/// It is logged at startup for diagnostic purposes.
///
/// Version history:
///   1.0 — Session 06: initial implementation with core elements
public struct TEIRenderingConfig: Codable, Sendable {

    /// Rendering behavior for a single TEI element.
    public struct ElementBehavior: Codable, Sendable {
        /// The local TEI element name (e.g. `"p"`, `"hi"`, `"note"`).
        public let elementName: String

        /// How this element should be rendered.
        public let renderAs: RenderBehavior

        /// Whether inline whitespace within this element should be preserved as-is.
        /// `false`: whitespace is normalized (trimmed and collapsed). Default for block elements.
        /// `true`: whitespace is preserved. Default for inline elements with intentional spacing.
        public let preserveWhitespace: Bool
    }

    /// Behavior definitions for all known TEI elements.
    public let elements: [ElementBehavior]

    /// The FRUS.odd schema version this configuration targets.
    /// Logged at startup; compared against the TEI header version in future sessions.
    public let schemaVersion: String

    // MARK: Lookup

    private lazy var behaviorIndex: [String: ElementBehavior] = {
        Dictionary(uniqueKeysWithValues: elements.map { ($0.elementName, $0) })
    }()

    /// Returns the rendering behavior for a TEI element name.
    /// Returns a `.passThrough` default for elements not listed in the config.
    public mutating func behavior(for elementName: String) -> ElementBehavior {
        if let b = behaviorIndex[elementName] { return b }
        return ElementBehavior(elementName: elementName, renderAs: .passThrough, preserveWhitespace: false)
    }
}

/// How a TEI element maps to a visual representation.
public enum RenderBehavior: String, Codable, Sendable {
    /// Rendered as a distinct visual block (paragraph, heading, etc.).
    case block

    /// Rendered inline within the surrounding text flow.
    case inline

    /// The element itself is not rendered; its children are passed through to the parent.
    case passThrough

    /// The element and all its children are not rendered.
    case suppress
}

// MARK: - Loading

public extension TEIRenderingConfig {

    /// Loads and decodes `tei-rendering-config.json` from the main bundle.
    ///
    /// This is called once at app launch by the rendering pipeline. If the file is absent
    /// or malformed, a warning is logged and an empty config is returned so the app
    /// continues to function (unknown elements fall back to `.passThrough`).
    static func loadFromBundle() -> TEIRenderingConfig {
        guard let url = Bundle.main.url(forResource: "tei-rendering-config", withExtension: "json") else {
            #if DEBUG
            print("[TEIParser] Warning: tei-rendering-config.json not found in bundle. Using empty config.")
            #endif
            return TEIRenderingConfig(elements: [], schemaVersion: "unknown")
        }
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(TEIRenderingConfig.self, from: data)
            #if DEBUG
            print("[TEIParser] Loaded tei-rendering-config.json (schema: \(config.schemaVersion), \(config.elements.count) elements).")
            #endif
            return config
        } catch {
            #if DEBUG
            print("[TEIParser] Warning: Failed to decode tei-rendering-config.json — \(error). Using empty config.")
            #endif
            return TEIRenderingConfig(elements: [], schemaVersion: "unknown")
        }
    }
}
