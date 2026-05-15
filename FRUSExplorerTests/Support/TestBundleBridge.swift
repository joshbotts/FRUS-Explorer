// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// A class whose sole purpose is to anchor `Bundle(for:)` lookups in the test target.
///
/// Swift Testing uses structs, which cannot be passed to `Bundle(for:)` (it requires
/// an `AnyClass`). Tests that need to load bundle resources call `Bundle.testBundle`
/// which resolves via this bridge class.
final class TestBundleBridge: NSObject {}

extension Bundle {
    /// The bundle of the `FRUSExplorerTests` test target.
    static var testBundle: Bundle { Bundle(for: TestBundleBridge.self) }
}
