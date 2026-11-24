// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
/// Handoff / NSUserActivity type identifiers.
///
/// The activity type strings must be registered in each target's `Info.plist`
/// under `NSUserActivityTypes` for Handoff to route activities to this app.
enum AppActivityTypes {
    /// A user is viewing a FRUS document. Carries `volumeId` and `documentId`
    /// in `userInfo` so the receiving device can navigate directly to it.
    static let document = "com.joshbotts.frus-explorer.document"

    /// A user is looking at the semantic map (UI review F-28). Carries the scope and the colour
    /// lens in `userInfo`, so the map the reader built on one device opens the same way on
    /// another.
    ///
    /// **The slice poles are carried since W-2, and the deferral that makes it safe exists.**
    /// They were deliberately excluded before that: `setPole` before the artifact loaded would
    /// half-apply — roll back the pole it had just set and post `semanticMap.axis.noSummary`, a
    /// confident diagnosis of the wrong cause — leaving a half-drawn axis card with no retry.
    /// `SemanticMapModel` now remembers an early pole in `requestedPoles`, exactly as `setScope`
    /// remembers a scope, and the view re-applies it after `prepare()` beside its deferred-reveal
    /// retry — so a continued map arrives sliced along the same axis the sender built.
    static let semanticMap = "com.joshbotts.frus-explorer.semanticMap"
}

// `SemanticMapRequest`, the map this activity carries, is FRUSCoreKit's since FRUS Explorer Light's S28a
// (`FRUSCoreKit/Semantic/SemanticMapRequest.swift`), so a host builds and reads the links that name a
// document or a region on the map as the app does.

// MARK: - Deep links (W-19 row L-5)

/// A `frusexplorer://` URL arriving from outside the app.
///
/// ## The scheme was already in use, and that shapes everything here
///
/// `frusexplorer://` is not new. It has been registered *with WebKit* since the TEI renderer
/// shipped (`FRUSWebViewConfiguration.setURLSchemeHandler`), carrying four hosts —
/// `person`, `gloss`, `doc`, `brokenref` — that `FRUSDocumentWebView` intercepts and cancels
/// before the OS ever sees them. Those links are also serialized into **exported collection HTML**,
/// where they have always been inert.
///
/// Registering the scheme with LaunchServices makes every one of those already-exported files
/// clickable from a browser. So this type deliberately knows about all five hosts rather than only
/// the new one: an in-document link that reaches the OS gets a stated refusal naming why, instead
/// of launching the app to do nothing. A router that recognised only `document` would have made
/// those files *worse* than inert.
///
/// The new host is `document`, spelled out, and NOT the existing `doc`: `doc` takes its target
/// first and its volume second, and its target is frequently not a document id at all (`d42fn3`,
/// `pg_313`). Reusing it would have meant one host with two argument orders.
///
/// ## Every id is validated here, before anything reaches the filesystem
///
/// A custom scheme is reachable from any web page. `DownloadManager.volumeURL(for:)` interpolates a
/// volume id into a path with `appendingPathComponent`, which does not resolve `..`, so the parser
/// admits only `[A-Za-z0-9_-]` — no dots, no separators, no traversal. The router then checks the
/// volume against the manifest, which is the app's own allow-list.
///
/// Version history:
///   1.0 — W-19 L-5: initial implementation
enum DeepLinkRoute: Equatable, Sendable {

    /// `frusexplorer://document/<volumeId>/<documentId>` — open a document.
    case document(volumeID: String, documentID: String)

    /// One of the renderer's in-document hosts, reaching the OS from an exported file. Carries the
    /// host so the refusal can name what the link was.
    case inAppOnly(host: String)

    /// The scheme this app answers for.
    static let scheme = "frusexplorer"

    /// The renderer's own hosts — links that only mean something inside a rendered document.
    /// Kept in sync with `FRUSURLSchemeHandler`'s switch by a test, not by hope. The handler's
    /// `figure` host (#1516) is not one of them: it is the source of an image the reader draws,
    /// which nothing follows, and no export writes it — so from outside it is an unknown host.
    static let inAppHosts: Set<String> = ["person", "gloss", "doc", "brokenref"]

    /// Ids may contain only these. Deliberately excludes `.`, which is what makes `..` unspellable.
    private static let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")

    /// Parses a URL, or returns `nil` for anything this app should not act on.
    ///
    /// - Parameter url: The incoming URL.
    /// - Returns: The route, or `nil` if the scheme is not ours, the host is unknown, the shape is
    ///   wrong, or either id contains a character an id may not contain.
    static func from(url: URL) -> DeepLinkRoute? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        guard let host = url.host?.lowercased() else { return nil }

        if inAppHosts.contains(host) { return .inAppOnly(host: host) }
        guard host == "document" else { return nil }

        // `pathComponents` on `frusexplorer://document/a/b` is ["/", "a", "b"].
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2 else { return nil }
        let volumeID = parts[0]
        let documentID = parts[1]
        guard isSafeIdentifier(volumeID), isSafeIdentifier(documentID) else { return nil }
        return .document(volumeID: volumeID, documentID: documentID)
    }

    /// Whether a path component is admissible as an identifier.
    /// - Parameter value: The component.
    /// - Returns: `true` when non-empty and drawn only from the allowed set.
    static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
