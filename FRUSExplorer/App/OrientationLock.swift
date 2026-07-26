// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)
import SwiftUI
import UIKit

// MARK: - OrientationLock

/// Process-wide interface-orientation lock, consulted by
/// `FRUSAppDelegate.application(_:supportedInterfaceOrientationsFor:)`.
///
/// ## Why this exists (#498)
/// Rotating the Corpus Analytics sheet on iPhone while its term field has been focused a second
/// time wedges the app. The mechanism is an AttributeGraph cycle, confirmed from three device crash
/// reports and reproduced under `sample` in the simulator: the rotation opens a SwiftUI graph
/// transaction, UIKit re-enters synchronously through `-[UIViewController _traitCollectionDidChange:]`
/// to ask the hosting controller for its status-bar child, and resolving that preference re-enters
/// the transaction that is still building it. AttributeGraph detects the cycle and blocks forever in
/// `write()` dumping it to stderr; on device the 10-second scene-update watchdog then kills the
/// process (`FRONTBOARD 0x8BADF00D`).
///
/// The defect needs a rotation, so removing rotation removes the defect. This is a **mitigation, not
/// a fix** — the underlying cycle is still there and the search for it continues. It is scoped as
/// tightly as the evidence allows:
///
/// - **iPhone only.** iPad Pro 11" passes both the minimal trigger and the multi-term case; the
///   defect needs compact width.
/// - **Corpus Analytics only.** The iPhone Search tab's focused field rotates safely, so this is not
///   a general focused-text-field problem — it is specific to a field inside a *sheet* whose content
///   opens its own `NavigationStack`.
/// - **Locks to the orientation already on screen**, rather than forcing landscape. Forcing a
///   rotation would strand anyone who cannot physically turn their device (a mounted phone, reading
///   in bed) and would itself perform a portrait→landscape transition — the fatal direction.
///
/// ## Balanced, not set/reset
/// `lock()`/`release()` are counted rather than assigning a flag, so overlapping presentations (a
/// hand-off that re-presents the sheet before the old one finishes dismissing) cannot leave the app
/// permanently locked. A leaked lock would be worse than the bug it prevents.
///
/// Version history:
///   1.0 — #498: initial implementation (mitigation while the AttributeGraph cycle is investigated)
@MainActor
final class OrientationLock {

    /// The shared lock. A single process-wide value, because `UIApplicationDelegate` answers the
    /// orientation question for the whole application.
    static let shared = OrientationLock()

    /// The mask the app delegate should return. `.all` when nothing is locked.
    private(set) var mask: UIInterfaceOrientationMask = .all

    /// Outstanding `lock()` calls. Rotation is restored only when this returns to zero.
    private var lockCount = 0

    private init() {}

    /// Pins the interface to the orientation currently on screen.
    ///
    /// No-op on anything other than iPhone — iPad does not exhibit #498 and rotating an iPad while
    /// reading a chart is normal use.
    func lockToCurrentOrientation() {
        guard !Self.isDisabledForTesting else { return }
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        lockCount += 1
        guard lockCount == 1 else { return }   // already locked; keep the first orientation

        guard let scene = Self.activeScene else { return }
        // `UIWindowScene.interfaceOrientation` is deprecated in iOS 26 in favour of the geometry.
        mask = scene.effectiveGeometry.interfaceOrientation.isLandscape ? .landscape : .portrait
        Self.applyMaskChange(in: scene)
    }

    /// Releases one lock. Rotation is restored when the last one goes.
    func release() {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        guard lockCount > 0 else { return }
        lockCount -= 1
        guard lockCount == 0 else { return }

        mask = .all
        if let scene = Self.activeScene { Self.applyMaskChange(in: scene) }
    }

    /// `true` while rotation is pinned — used to keep the Corpus Analytics landscape hint honest
    /// (it must not tell the reader to rotate when rotating does nothing).
    var isLocked: Bool { lockCount > 0 }

    // MARK: - Private

    /// Opt-out used by the #498 regression suite.
    ///
    /// The lock makes every in-sheet rotation inert, which would silently turn
    /// `AnalyticsRotationTests` into a test of the lock rather than a test of the defect. Setting
    /// `FRUS_DISABLE_ORIENTATION_LOCK=1` restores real rotation so the underlying AttributeGraph
    /// cycle can still be reproduced — that suite is the only way to tell whether a candidate fix
    /// works, and it has to keep working after this mitigation ships.
    ///
    /// Read once, not per call, so it cannot change mid-session.
    static let isDisabledForTesting =
        ProcessInfo.processInfo.environment["FRUS_DISABLE_ORIENTATION_LOCK"] == "1"

    /// The foreground-active window scene, or the first connected one as a fallback (a scene can be
    /// briefly `.foregroundInactive` while a sheet animates in).
    private static var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// Tells UIKit to re-ask the delegate for the supported orientations.
    private static func applyMaskChange(in scene: UIWindowScene) {
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

// MARK: - View modifier

/// Pins the interface orientation for as long as the modified view is on screen (#498).
///
/// Attach to the *content of a presentation*, not to a persistent view — the lock is released in
/// `onDisappear`, so a view that never disappears would never restore rotation.
private struct OrientationLockedWhilePresented: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationLock.shared.lockToCurrentOrientation() }
            .onDisappear { OrientationLock.shared.release() }
    }
}

extension View {

    /// Pins the interface orientation while this view is presented (#498 mitigation, iPhone only).
    ///
    /// See `OrientationLock` for why this exists and what it does and does not fix.
    func orientationLockedWhilePresented() -> some View {
        modifier(OrientationLockedWhilePresented())
    }
}
#endif
