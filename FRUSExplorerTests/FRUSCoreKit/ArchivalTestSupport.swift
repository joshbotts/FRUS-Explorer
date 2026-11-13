// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - What the app gives the archival suites, for the package

// In Xcode the suites run inside the app, whose `ArchivalCollectionsData+App.swift` gives them
// `make(authority:usage:coverage:external:labels:)` over its bundled stores, and whose
// `ArchivalNetworkBuilder+App.swift` gives them `layout(_:in:)`, which measures each caption with UIKit.
// The package has no app, so it declares the same two names here: `make` over the stores
// `SourceExplorerTestSupport.swift` reads from the repository's copies, and `layout(_:in:)` over an
// estimate of the caption font, the one `GraphNodeLabelTests` sizes labels with. That estimate is the
// caption measure the archival network's suites inject in the package, as a host injects its own. What
// they check holds under it as under UIKit's measure: every caption clear of every node, the class box
// and its caption on the swept canvases, and the fallback at 240 × 160. It does not hold for every
// measure: captions some 5% wider than this estimate come within the clearance of the class box at
// 390 × 300. The label counts pinned at UIKit's measure are Xcode's alone.
//
// Version history:
//   1.0 — 2026-11-12 (FRUS Explorer Light, S24c): initial implementation, when the archival derivations
//          moved into the kit

#if SWIFT_PACKAGE
extension ArchivalCollectionsData {

    /// The app's `make`, over the package's stand-ins for its stores.
    static func make(authority: [AuthorityCollectionRecord],
                     usage: CollectionUsageIndex?,
                     coverage: [String: ArchivalVolumeCoverage],
                     external: ExternalCitationIndex? = ExternalCitationIndexStore.shared,
                     labels: DecimalClassLabelTable? = DecimalClassLabelStore.shared)
        -> ArchivalCollectionsData {
        make(authority: authority, usage: usage, coverage: coverage, external: external,
             labels: labels, readingSubjectNumericLabels: { SubjectNumericLabelStore.shared })
    }
}

extension ArchivalNetworkBuilder {

    /// A caption's size at `captionPointSize`, estimated as `GraphNodeLabelTests` estimates a label's
    /// and rounded up to whole points as the app's measure is: within a few points of what UIKit
    /// measures for the custodians' and the class box's captions.
    static func estimatedCaptionSize(_ text: String) -> CGSize {
        let size = GraphNodeLabelTests.estimatedSize(text, fontSize: captionPointSize)
        return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    /// The app's `layout(_:in:)`, with each caption estimated where the app measures it.
    static func layout(_ graph: ArchivalNetworkGraph, in size: CGSize) -> ArchivalNetworkLayout {
        layout(graph, in: size, captionSize: estimatedCaptionSize)
    }
}
#endif
