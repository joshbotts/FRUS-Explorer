// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// `StructuredSummarySchema` and `ResponseFormat` moved to FRUSCoreKit
// (`FRUSCoreKit/Models/SummaryTypes.swift`) under their names, since the research data export,
// now kit code, names them.

// `TextSizePreference` moved to FRUSCoreKit (`FRUSCoreKit/TEI/TextSizePreference.swift`) under its
// name, since the reader's page, `ReaderPage`, now kit code, reads it.

// MARK: - TabShellBannerRoom

/// The room an iOS tab sets aside below its content for the tab shell's banner, against the banner's height, as
/// measured once a change has settled (L27, F1).
///
/// `TabShellBannerReserve` (`App/MainTabView.swift`) measures it and logs it; its "The room against the banner"
/// says why. Every value is in points.
///
/// ## What it judges
/// - **The reserve:** the bottom inset last written to the tab's host equals the banner's height.
/// - **The room, while a banner is up:** the space from the tab content's bottom edge down to the window's own
///   safe-area floor equals the banner's height. F1's frame, a 188-pt banner at the top of about 322 pt, is a band
///   of +134. With no banner nothing hangs in the room, and while the keyboard is up there is no banner (#1070) and
///   SwiftUI raises the content's bottom edge to the keyboard, which is not room the reserve set aside. A banner left
///   up over the keyboard (#1835's shape) is judged, and reads as a band the keyboard's height.
/// - **Not judged:** the room where a tab bar sits at the bottom of the window, as on an iPhone, whose share of the
///   inset UIKit decides; that measurement is `nil`.
///
/// Version history:
///   1.0 — L27 (F1): initial implementation
struct TabShellBannerRoom: Equatable, Sendable {
    /// The banner's measured height: what the room should be.
    let bannerHeight: CGFloat
    /// The bottom inset the reserve last wrote to the tab's host.
    let reserve: CGFloat
    /// The room below the tab's content, down to the window's own safe-area floor, or `nil` where a tab bar sits at
    /// the bottom of the window.
    let room: CGFloat?
    /// The window's own bottom safe-area inset: the home indicator's, on an iPad with Face ID.
    let windowInset: CGFloat
    /// The type of the controller the reserve was written to, without its generic arguments.
    let host: String
    /// The type of that controller's parent, without its generic arguments, or `none`.
    let parent: String

    /// The room less the banner's height: zero when the banner fills the room, positive when room is left below it.
    /// `nil` where the room is not measured, or no banner is up.
    var band: CGFloat? {
        guard bannerHeight > 0, let room else { return nil }
        return room - bannerHeight
    }

    /// Whether the reserve is the banner's height and, where a band is judged, the band is nothing.
    var isBalanced: Bool {
        guard abs(reserve - bannerHeight) < Self.tolerance else { return false }
        guard let band else { return true }
        return abs(band) < Self.tolerance
    }

    /// The difference below which two heights count as the same: under a pixel at 2x.
    static let tolerance: CGFloat = 0.5

    /// The room below a content edge at `contentBottom`, in a window whose bottom edge is at `windowBottom` and whose
    /// own bottom safe-area inset is `windowInset`.
    static func room(windowBottom: CGFloat, windowInset: CGFloat, contentBottom: CGFloat) -> CGFloat {
        windowBottom - windowInset - contentBottom
    }

    /// The name of `object`'s type without its generic arguments, which for SwiftUI's hosting controllers run to
    /// hundreds of characters.
    static func typeName(of object: AnyObject) -> String {
        String(String(describing: type(of: object)).prefix { $0 != "<" })
    }

    /// One line for the log, with every value measured.
    var summary: String {
        let measured: String
        switch (room, band) {
        case let (room?, band?):
            measured = "room \(Self.points(room)), band \(Self.points(band))"
        case let (room?, nil):
            measured = "room \(Self.points(room)), no banner up"
        case (nil, _):
            measured = "room not measured, a tab bar at the bottom"
        }
        return "banner \(Self.points(bannerHeight)), reserve \(Self.points(reserve)) on \(host) in \(parent), "
            + "\(measured), window inset \(Self.points(windowInset))"
    }

    /// `value` in points, to a tenth.
    private static func points(_ value: CGFloat) -> String {
        String(format: "%.1f pt", Double(value))
    }
}

// MARK: - DefaultDocumentMode

/// User preference for which mode a document opens in (Session 154).
///
/// Stored via `AppStorage(SettingsKeys.defaultDocumentMode)`. `.rememberLast`
/// preserves the original behaviour: `frus.document.researchPanel.visible`
/// persists the last Read/Research choice across documents and is left alone
/// on open. `.read`/`.research` force that panel-visibility flag to a fixed
/// value each time a document opens; the in-document Read/Research rail toggle
/// can still switch modes live for that document.
public enum DefaultDocumentMode: String, CaseIterable, Identifiable, Sendable {
    case read
    case research
    case rememberLast

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .read:         return "Read"
        case .research:     return "Research"
        case .rememberLast: return "Remember Last"
        }
    }
}
