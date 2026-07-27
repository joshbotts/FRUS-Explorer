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

import SwiftUI

/// Glass, or a solid card when the reader has asked for one.
///
/// `.glassEffect` responds to Reduce Transparency on its own, but it degrades to a
/// *less* translucent material rather than an opaque one. Every surface in this feature
/// floats over a **moving word cloud**, so anything still see-through leaves body text
/// competing with drifting serif words underneath it — which is precisely the situation
/// Reduce Transparency exists to end. The hand-off says so too: "Reduce Transparency →
/// replace glass with solid `windowBackgroundColor` cards."
///
/// Version history:
///   1.0 — O-5: initial implementation
extension View {

    /// Applies the feature's glass surface, or an opaque card under Reduce Transparency.
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius shared by both treatments, so the layout is
    ///     identical either way and only the material changes.
    ///   - solid: Pass the view's `accessibilityReduceTransparency` environment value.
    @ViewBuilder
    func cloudSurfaceBackground(cornerRadius: CGFloat, solid: Bool) -> some View {
        if solid {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.systemBackgroundCompat)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            )
        } else {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}
