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

// MARK: - ResultSelectionBar

/// The bar that takes the search actions bar's place while results are being selected
/// (#1576 lane 3): Done, the count, the Select menu and the Actions menu.
///
/// ## Why it replaces the actions bar
///
/// The five-control actions bar cannot wrap, scroll or fold, and `SearchActionsBarFitTests` holds
/// it to the screen at every text size. A sixth control would not fit. Selection is a mode: while
/// it is on the reader is picking and commanding, not filtering or changing the reading, so the
/// bar's slot shows this one, and the five controls and their fit test are untouched.
///
/// ## Why the commands are a menu
///
/// The plan's first design was a second bar at the foot of the results, above the tab shell's
/// banner, and it gave the rule for dropping it: if that bar cannot clear the banner at 375 pt and
/// the accessibility sizes, the commands go in one Actions menu here. The bar was built and
/// measured on 2026-10-10. On an iPhone SE (3rd generation) at the largest accessibility size,
/// with the banner showing, Mark Reviewed drew at y 334 to 382 under a banner whose top was at
/// y 344, and no result showed above the commands. So the commands are a menu. It is at the
/// trailing end of the row, where the actions bar's own More menu is, and is drawn with that
/// menu's glyph at that menu's size.
///
/// ## Layout
///
/// One row and nothing else, exactly as tall as the row it takes the place of, so nothing under
/// it moves when selection begins or ends, and the room it takes above the results is the room
/// the actions bar took. The row cannot wrap, so its text stops growing at the first
/// accessibility size, as the actions bar's glyphs do (#1307), and each control shows its name in
/// the Large Content Viewer on a long press. The menus the row presents are not held to that
/// size: seen on iOS 27.0 at the largest accessibility size, the Select menu's items drew at the
/// reader's own.
///
/// The count keeps a reserved width: it changes with every tap, and a label that grew from
/// "9 selected" to "10 selected" would move the two menus from under the reader's finger. Where
/// the row is tight the count is what gives: it draws smaller, down to six tenths of its size,
/// which at the row's largest text is the default body size. Measured 2026-10-10 by
/// `ResultSelectionBarFitTests`, which holds the room to the widest count: on an iPhone SE
/// (375 pt) at the accessibility sizes the count has 123 to 124 pt, and "8,888 selected" needs
/// 111 at six tenths; on an iPhone 17 (402 pt) it has 150 to 151. Seen on an iPhone 17e at the
/// largest size: "1,000 selected" drawn whole.
///
/// What the last command did is not drawn here: see ``ResultSelectionStatus``.
///
/// ## The announcement
///
/// Each outcome is announced to VoiceOver from here, because this view is there for as long as
/// selection is and the line that shows the outcome is not: it is one of the rows above the
/// results, which are drawn again as a different view when they start or stop scrolling. The
/// announcement is posted on the host's count of outcomes and not on a change of the words,
/// because two commands can leave the same words. It is posted once for each: the task that
/// posts it starts again whenever the bar comes back on screen, from a document opened out of a
/// row's menu or from another tab, so the bar keeps the count it last spoke
/// (`BulkOutcome.owesAnnouncement`). It is posted late and at high priority, as a toast's is
/// (`TransientToast`, #1594): an add's outcome arrives while the picker is still closing, which
/// is when VoiceOver moves its focus and an announcement at the default priority is dropped or
/// cut off. **Neither value was heard on a device.**
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
struct ResultSelectionBar: View {

    /// Results picked. Zero dims Mark Reviewed.
    let count: Int
    /// Rows on the page on screen, which This Page picks. Zero dims the item.
    let pageRowCount: Int
    /// Results the list shows, which All Shown picks.
    let shownCount: Int
    /// Whether Add to Collection can run: something is picked, and no more than one add takes.
    let canAdd: Bool
    /// Whether Mark Reviewed is offered: Checklist Mode is on.
    let showsMarkReviewed: Bool
    /// What the last command did, to announce, or `nil`.
    let outcomeMessage: String?
    /// How many outcomes the host has set. Each new one is announced, whatever its words.
    let outcomeSerial: Int
    /// The point size of the actions bar's glyphs, as that bar draws them now. The Actions glyph
    /// is drawn at it.
    let rowGlyphSize: CGFloat
    /// Leaves selection.
    let done: () -> Void
    /// Picks the page on screen.
    let selectPage: () -> Void
    /// Picks every result shown.
    let selectAllShown: () -> Void
    /// Un-picks everything.
    let selectNone: () -> Void
    /// Opens the collection picker for the selection.
    let addToCollection: () -> Void
    /// Hides the selection as reviewed.
    let markReviewed: () -> Void

    /// The count of outcomes whose announcement was last posted, so that the same one is not
    /// spoken again when the bar comes back on screen.
    @State private var announcedSerial = 0

    var body: some View {
        HStack(spacing: Self.spacing) {
            Button(ResultSelectionCopy.done, action: done)
                .fontWeight(.semibold)
                .accessibilityShowsLargeContentViewer()
                .accessibilityIdentifier("search.selection.done")
            Spacer(minLength: 0)
            countLabel
            Spacer(minLength: 0)
            selectMenu
            actionsMenu
        }
        .lineLimit(1)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .task(id: outcomeSerial) {
            guard BulkOutcome.owesAnnouncement(serial: outcomeSerial, lastAnnounced: announcedSerial,
                                               message: outcomeMessage),
                  let outcomeMessage else { return }
            // A newer outcome cancels this task, so only the latest is spoken.
            do { try await Task.sleep(for: Self.announcementDelay) } catch { return }
            announcedSerial = outcomeSerial
            AccessibilityNotification.Announcement(TransientToast.announcement(outcomeMessage)).post()
        }
    }

    /// The space between the row's controls. `ResultSelectionBarFitTests` works out the count's
    /// room from it.
    static let spacing: CGFloat = 8

    /// The smallest the count draws, as a share of its size. `ResultSelectionBarFitTests` holds
    /// the count's room to the widest count at this scale.
    static let countMinimumScale: CGFloat = 0.6

    /// How long after an outcome is set its announcement is posted: long enough for the
    /// collection picker, which closes itself 0.6 to 0.8 s after an add, to have gone.
    static let announcementDelay: Duration = .seconds(1.2)

    /// "37 selected", in the width its widest value needs where the row has it, and smaller where
    /// it does not.
    private var countLabel: some View {
        ZStack {
            Text(ResultSelectionCopy.selected(8_888)).hidden().accessibilityHidden(true)
            Text(ResultSelectionCopy.selected(count))
                .accessibilityShowsLargeContentViewer()
                .accessibilityIdentifier("search.selection.count")
        }
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .minimumScaleFactor(Self.countMinimumScale)
    }

    /// The picks a reader does not make one row at a time.
    private var selectMenu: some View {
        Menu {
            Button(ResultSelectionCopy.thisPage, action: selectPage)
                .disabled(pageRowCount == 0)
            Button(ResultSelectionCopy.allShown(shownCount), action: selectAllShown)
                .disabled(shownCount == 0)
            Button(ResultSelectionCopy.none, action: selectNone)
                .disabled(count == 0)
        } label: {
            Text(ResultSelectionCopy.selectMenu)
        }
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("search.selection.menu")
    }

    /// The commands on the selection. The menu itself is never dimmed: with nothing picked it
    /// opens on its dimmed items, which is how a reader learns what a selection is for.
    private var actionsMenu: some View {
        Menu {
            Button(action: addToCollection) {
                Label(BulkResultCopy.addToCollection, systemImage: "plus.circle")
            }
            .disabled(!canAdd)
            if showsMarkReviewed {
                Button(action: markReviewed) {
                    Label(ResultSelectionCopy.markReviewed, systemImage: "checkmark.circle")
                }
                .disabled(count == 0)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: rowGlyphSize))
        }
        .accessibilityLabel(ResultSelectionCopy.actions)
        .accessibilityShowsLargeContentViewer {
            Label(ResultSelectionCopy.actions, systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("search.selection.actions")
    }
}

// MARK: - ResultSelectionStatus

/// The lines a selection adds above the results (#1576 lane 3): why Add to Collection is dimmed,
/// and what the last command did, with its Undo where there is something to take back.
///
/// ## Why they are not in the selection bar
///
/// Both lines wrap, and grow with the reader's text. The selection bar is attached above the
/// results as a safe-area inset, with the mode picker and the Query Inspector, and what is
/// attached there cannot give way: at the largest accessibility size, on an iPhone with the tab
/// shell's banner showing, an outcome of three lines under the bar made that stack taller than
/// the room between the search field and the banner, and the mode picker drew behind the search
/// field (seen 2026-10-10 on an iPhone 17e). The rows above the results can give way: they scroll
/// where they do not fit (`SearchView.resultsColumn`). So the lines are the first of those rows.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
struct ResultSelectionStatus: View {

    /// Why Add to Collection is dimmed, when more are picked than one add takes; `nil` otherwise.
    let addRefusal: String?
    /// What the last command did, or `nil`.
    let outcome: BulkOutcome?
    /// Takes the last command back.
    let undo: () -> Void

    var body: some View {
        if addRefusal != nil || outcome != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let addRefusal {
                    Text(addRefusal)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("search.selection.overLimit")
                }
                if let outcome {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(outcome.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("search.selection.outcome")
                        if let kind = outcome.undo {
                            Button(ResultSelectionCopy.undo, action: undo)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                // The checklist's strip has an Undo of its own a few lines
                                // down, which takes back something else after an add.
                                .accessibilityHint(ResultSelectionCopy.undoHint(for: kind))
                                .accessibilityIdentifier("search.selection.undo")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - ResultSelectionMark

/// The mark at a result row's leading edge while the list is in selection (#1576 lane 3): an
/// empty circle, or a filled one with a check.
///
/// Hidden from VoiceOver: the row itself carries the selected trait, which is what says it.
///
/// Version history:
///   1.0 — #1576 lane 3: initial implementation
struct ResultSelectionMark: View {

    /// Whether the row is picked.
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .accessibilityHidden(true)
    }
}
