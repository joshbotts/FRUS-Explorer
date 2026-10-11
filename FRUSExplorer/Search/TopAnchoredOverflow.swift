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

// MARK: - TopAnchoredOverflow

/// Lays a view out in the room it is offered, and where the view is taller than that room lets it
/// run out at the bottom only (#1576 lane 3).
///
/// ## Why
///
/// A view that needs more height than its parent offers reports the height it needs, and the
/// parent centres it: it runs out equally above and below, and so does everything attached to its
/// edges. The Search screen's results are the base that the mode picker, the actions bar and the
/// Query Inspector are attached above as safe-area insets. Seen 2026-10-10 on an iPhone 17e at
/// the third accessibility size, with Checklist Mode on and the tab shell's banner showing, on
/// this lane's code with two things taken out, this layout and the results column's scrolling
/// rows: the count header and the checklist's strip needed more than the room between the Query
/// Inspector and the banner, the mode picker drew about 35 pt up, behind the search field, the
/// strip's Undo was cut off by the banner, and no result showed. `TopAnchoredOverflowTests`
/// holds the same arrangement in small, with a control that fails if SwiftUI stops centring.
///
/// With the scrolling rows in, the list reading gives way by itself and this layout has nothing
/// to do there; nor, on the same day's evidence, has it with the Timeline reading or with All
/// Results Reviewed, which give way too. It is for a reading that cannot: Collocates has controls
/// of its own above its list. Seen on the iPhone 17e at the largest accessibility size, with this
/// layout out and the scrolling rows in: the Collocates reading put the mode picker behind the
/// search field and the actions bar half behind it.
/// `ResultSelectionBarFitTests.testCollocatesTallerThanTheirRoomLeaveTheModePickerInPlace` is
/// the test of it on the Search screen.
///
/// Inside this layout the view still has the height it needs. What changes is what the parent is
/// told: never more than was offered. So the parent has nothing to centre, the bars stay at their
/// edges, and the part that does not fit is below the room, where the banner covers it.
///
/// ## What it does not change
///
/// A view that fits reports its own size, as it did without the layout, and is placed where it
/// was. A view that fills the room it is offered, as a list does, is offered the same room.
///
/// It is not a way to make content reachable: what runs out at the bottom cannot be scrolled to.
/// The content has to give way by itself, as ``SearchView``'s results column does.
///
/// More than one view is laid from the top over the others, each as if it were alone.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
struct TopAnchoredOverflow: Layout {

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var needed = CGSize.zero
        for subview in subviews {
            let size = subview.sizeThatFits(proposal)
            needed.width = max(needed.width, size.width)
            needed.height = max(needed.height, size.height)
        }
        return CGSize(width: needed.width,
                      height: Self.reportedHeight(needed: needed.height, offered: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
                       cache: inout ()) {
        let room = ProposedViewSize(width: bounds.width, height: bounds.height)
        for subview in subviews {
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top, proposal: room)
        }
    }

    /// The height the layout reports for content that needs `needed` in a room of `offered`: the
    /// content's own where it fits, and the room's where it does not.
    ///
    /// - Parameters:
    ///   - needed: The height the content takes when offered the room.
    ///   - offered: The room's height, or `nil` when the parent asks for the ideal size.
    /// - Returns: The height to report to the parent.
    static func reportedHeight(needed: CGFloat, offered: CGFloat?) -> CGFloat {
        guard let offered else { return needed }
        return min(needed, offered)
    }
}
