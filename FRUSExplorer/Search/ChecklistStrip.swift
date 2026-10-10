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

// MARK: - ChecklistCopy

/// The checklist strip's words, apart from the view so that a test can read them off the main
/// actor (#1576 lane 1).
///
/// Version history:
///   1.0 — #1576 lane 1: initial implementation
enum ChecklistCopy {

    /// "12 reviewed hidden": how many results Checklist Mode is hiding.
    ///
    /// - Parameter count: Results hidden as reviewed.
    /// - Returns: The line.
    static func hidden(_ count: Int) -> String {
        String(format: String(localized: "search.checklist.hiddenBanner %lld",
                              defaultValue: "%lld reviewed hidden"), Int64(count))
    }

    /// The strip's line while the mode is on and hides nothing in this list. It says nothing of
    /// what has been reviewed: after a re-run that loaded none of a marked page, marks stand and
    /// nothing here is hidden.
    static var nothingHidden: String {
        String(localized: "search.checklist.nothingHidden", defaultValue: "Nothing hidden")
    }

    /// The button that hides every result on the page.
    static var markPage: String {
        String(localized: "search.checklist.markPage", defaultValue: "Mark Page Reviewed")
    }

    /// What Mark Page Reviewed does, for a pointer's tooltip and VoiceOver's hint.
    static var markPageHelp: String {
        String(localized: "search.checklist.markPage.help",
               defaultValue: "Hide every result on this page as reviewed")
    }

    /// The button that takes the last Mark Page Reviewed back.
    static var undo: String {
        String(localized: "search.checklist.undo", defaultValue: "Undo")
    }

    /// What Undo does, for a pointer's tooltip and VoiceOver's hint.
    static var undoHelp: String {
        String(localized: "search.checklist.undo.help",
               defaultValue: "Bring back the results the last Mark Page Reviewed hid")
    }

    /// What VoiceOver is told after Mark Page Reviewed: "25 results marked reviewed".
    ///
    /// - Parameters:
    ///   - count: Rows the mark took out of the list.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    /// - Returns: The announcement.
    static func markedAnnouncement(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            count,
            one: String(localized: "search.checklist.marked.one",
                        defaultValue: "%@ result marked reviewed"),
            many: String(localized: "search.checklist.marked.many",
                         defaultValue: "%@ results marked reviewed"),
            locale: locale)
    }

    /// What VoiceOver is told after Undo: "25 results are back in the list".
    ///
    /// - Parameters:
    ///   - count: Rows the undo brought back to the list, which a re-run since the mark can make
    ///     fewer than the mark hid.
    ///   - locale: The locale that groups the count; the user's own unless a test passes one.
    /// - Returns: The announcement.
    static func undoneAnnouncement(_ count: Int, locale: Locale = .autoupdatingCurrent) -> String {
        CountCopy.phrase(
            count,
            one: String(localized: "search.checklist.undone.one",
                        defaultValue: "%@ result is back in the list"),
            many: String(localized: "search.checklist.undone.many",
                         defaultValue: "%@ results are back in the list"),
            locale: locale)
    }
}

// MARK: - ChecklistStrip

/// The strip Checklist Mode shows above the results, on iPhone, iPad and Mac (#1576 lane 1).
///
/// ## What it is for
///
/// Until this lane the checklist drew one line, "N reviewed hidden", and only once N was above
/// zero, so a reader who had turned the mode on saw nothing say so until a row had gone. Each
/// result was marked on its own row: a swipe or a menu item at a time. The strip is there whenever
/// the mode is on, and it carries the first bulk action in Search: **Mark Page Reviewed**, which
/// hides the page at a stroke, and **Undo**, which takes that stroke back.
///
/// ## One view for both hosts
///
/// `SearchView` and the Mac's Search window are hand-maintained twins, and each drew its own copy
/// of the old line. A strip with two buttons and three states written twice is two places to
/// drift, so both mount this one and hand it their view model's figures.
///
/// ## Layout
///
/// One row where there is room: the count, then Undo and Mark Page Reviewed at the trailing edge.
/// At compact width and at accessibility text sizes the count has the first row and the buttons the
/// second, side by side where they fit and one above the other where they do not.
///
/// **Nothing in the strip moves when a page is marked.** A reader working down a list presses
/// Mark Page Reviewed again and again, so the button must be where it was. The count's line is
/// there with nothing hidden, Undo is there with nothing to undo (dimmed), and the layout follows
/// the size class and the text size alone. An Undo that appeared on the first mark would take the
/// place the reader's finger was on.
///
/// ## Where the buttons work
///
/// Both act on a page of results, so under a reading that has no page (the timeline, the
/// collocates) the hosts hand the strip no page rows and no undo, and both are dimmed. That is
/// more than tidiness for Undo: a collocation is measured over every result the mode shows and is
/// rebuilt when a search completes, not when a mark changes, so an undo made under it would
/// change the set the panel says it measured and leave the ranking as it was.
///
/// Version history:
///   1.0 — #1576 lane 1: initial implementation
struct ChecklistStrip: View {

    /// Results hidden as reviewed: the loaded results less those shown.
    let hiddenCount: Int
    /// Rows on the page now, which Mark Page Reviewed would hide. Zero disables the button: an
    /// empty page, or a reading that is not a page (the timeline, the collocates).
    let pageRowCount: Int
    /// Whether Undo would bring a row back. `false` dims the button; it does not remove it.
    let canUndo: Bool
    /// The line shown while Log Research Sessions is off (`ChecklistLoggingNotice`), or `nil`.
    let loggingNotice: String?
    /// Marks the page reviewed and answers how many rows left the list.
    let markPage: () -> Int
    /// Undoes the last Mark Page Reviewed and answers how many rows came back.
    let undo: () -> Int

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Whether the buttons take a row of their own.
    private var stacksButtons: Bool {
        #if os(macOS)
        false
        #else
        horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if stacksButtons {
                status
                // Side by side where the two fit, as they do at every standard text size; one
                // above the other at the accessibility sizes where they do not. The titles never
                // change, so the choice is the same before and after a mark.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        markPageButton
                        undoButton
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        markPageButton
                        undoButton
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    status
                    Spacer(minLength: 8)
                    undoButton
                    markPageButton
                }
            }
            if let loggingNotice {
                Label(loggingNotice, systemImage: "info.circle")
                    .font(Self.textFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("search.checklist.loggingOff")
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, 4)
        #if os(macOS)
        .overlay(alignment: .bottom) { Divider() }
        #endif
    }

    /// How many results are hidden, or that none is. Always a line of text, so that the strip
    /// says the mode is on before anything is hidden and its first row is there from the start.
    private var status: some View {
        Label(hiddenCount > 0 ? ChecklistCopy.hidden(hiddenCount) : ChecklistCopy.nothingHidden,
              systemImage: "checklist")
            .font(Self.textFont)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("search.checklist.hidden")
    }

    /// Mark Page Reviewed. Bordered and small, so it reads as a button in a line of secondary
    /// text and has an edge to aim at.
    private var markPageButton: some View {
        Button(ChecklistCopy.markPage) {
            let marked = markPage()
            announce(ChecklistCopy.markedAnnouncement(marked))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(pageRowCount == 0)
        #if os(macOS)
        .help(ChecklistCopy.markPageHelp)
        #endif
        .accessibilityHint(ChecklistCopy.markPageHelp)
        .accessibilityIdentifier("search.checklist.markPage")
    }

    /// Undo, always drawn and dimmed until there is a page mark to take back.
    private var undoButton: some View {
        Button(ChecklistCopy.undo) {
            let restored = undo()
            announce(ChecklistCopy.undoneAnnouncement(restored))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canUndo)
        #if os(macOS)
        .help(ChecklistCopy.undoHelp)
        #endif
        .accessibilityHint(ChecklistCopy.undoHelp)
        .accessibilityIdentifier("search.checklist.undo")
    }

    /// Tells VoiceOver what a bulk action did. The rows leave or return without a sound, and the
    /// strip's own count changes off the cursor.
    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    /// The strip's text size: the footnote the iPhone's line always used, and the Mac's subheadline.
    private static var textFont: Font {
        #if os(macOS)
        .subheadline
        #else
        .footnote
        #endif
    }

    private static var horizontalPadding: CGFloat { 16 }
}
