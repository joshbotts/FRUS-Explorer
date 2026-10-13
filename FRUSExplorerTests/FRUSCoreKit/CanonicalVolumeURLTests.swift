// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - CanonicalVolumeURLTests

/// A volume's public page, which a reference to a whole volume outside the catalogue opens (#1603),
/// in the app and in FRUS Explorer Light. The document's address is `ZoteroIOSFallbackTests.swift`'s
/// `FRUSCanonicalURLTests`.
///
/// Version history:
///   1.0 — FRUS Explorer Light: initial implementation, when `volumeURL(volumeId:)` became public
@Suite("Canonical volume address")
struct CanonicalVolumeURLTests {

    @Test("A volume's page is history.state.gov's, for a volume the catalogue does not hold too")
    func volumePages() {
        #expect(FRUSCanonicalURL.volumeURL(volumeId: "frus1961-63v05")?.absoluteString
                == "https://history.state.gov/historicaldocuments/frus1961-63v05")
        #expect(FRUSCanonicalURL.volumeURL(volumeId: "frus1958-60v11mSupp")?.absoluteString
                == "https://history.state.gov/historicaldocuments/frus1958-60v11mSupp")
    }

    @Test("An id that is not one path component has no page")
    func unsafeIds() {
        for id in ["", ".", "..", "frus1961-63v05/d1", #"frus\v05"#] {
            #expect(FRUSCanonicalURL.volumeURL(volumeId: id) == nil, "\(id) named a page")
        }
    }
}
