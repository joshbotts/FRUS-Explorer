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

import WidgetKit
import SwiftUI

/// Widget bundle entry point for FRUS Explorer.
///
/// Currently contains a single widget: `IndexingLiveActivity`, which renders the
/// indexing progress Live Activity in the Dynamic Island and on the lock screen.
@main
struct FRUSExplorerWidgetBundle: WidgetBundle {
    var body: some Widget {
        IndexingLiveActivity()
    }
}
