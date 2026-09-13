import Foundation

// STUB 1 of 1. `CentralFilesClassifier.enclosureHomes(openers:)` (CentralFilesClassifier.swift
// lines 130-146) names `IndexingPipeline.EnclosureOpener`, whose real declaration sits inside the
// ~5,000-line IndexingPipeline actor (IndexingPipeline.swift:4807) with SQLite, TEI parser and
// SwiftData dependencies. The document-level path never calls enclosureHomes; the stub carries
// the real type's three stored properties (label/header/dateline) so the file compiles unchanged.
enum IndexingPipeline {
    struct EnclosureOpener: Sendable, Equatable {
        let label: String?
        let header: String
        let dateline: String
    }
}
