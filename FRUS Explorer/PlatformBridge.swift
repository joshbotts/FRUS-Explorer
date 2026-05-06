// PlatformBridge.swift
// Environment key for PlatformViewReference — allows views to trigger
// platform-specific UI (save panel on macOS, share sheet on iPadOS)
// without importing AppKit or UIKit directly.

import SwiftUI

// MARK: - Environment key

private struct PlatformViewReferenceKey: EnvironmentKey {
    static let defaultValue: PlatformViewReference? = nil
}

extension EnvironmentValues {
    var platformViewReference: PlatformViewReference? {
        get { self[PlatformViewReferenceKey.self] }
        set { self[PlatformViewReferenceKey.self] = newValue }
    }
}

// MARK: - macOS window-reading helper

#if os(macOS)
/// An invisible NSViewRepresentable that reads the enclosing NSWindow
/// once the view is placed in the window hierarchy, then calls `onWindow`.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> ReadingView {
        ReadingView(callback: onWindow)
    }

    func updateNSView(_ nsView: ReadingView, context: Context) {}

    final class ReadingView: NSView {
        let callback: @MainActor (NSWindow?) -> Void
        init(callback: @escaping @MainActor (NSWindow?) -> Void) {
            self.callback = callback
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            Task { @MainActor in callback(self.window) }
        }
    }
}
#endif
