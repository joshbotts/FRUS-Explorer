// Collections/PDFExporter.swift
//
// Renders a DocumentCollection to a PDF using WKWebView's print pipeline,
// then saves or shares it using the appropriate platform mechanism:
//
//   macOS  — NSSavePanel lets the user choose a save location.
//   iPadOS — UIActivityViewController presents the system share sheet,
//            which includes "Save to Files" for local storage.
//
// WKWebView and WKPDFConfiguration are available on both platforms.
// We intentionally do NOT set WKPDFConfiguration.rect so that WebKit
// uses the CSS @page rule for pagination.

import Foundation
import WebKit
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Error types

enum PDFExportError: Error, LocalizedError {
    case loadFailed(String)
    case renderFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let m):   return "HTML load failed: \(m)"
        case .renderFailed(let m): return "PDF render failed: \(m)"
        case .writeFailed(let m):  return "File write failed: \(m)"
        }
    }
}

// MARK: - PDFExporter

/// Renders an HTML string to PDF data via WKWebView.
/// Works identically on macOS and iPadOS — platform differences
/// are handled in the `exportCollectionToPDF` convenience function below.
@MainActor
final class PDFExporter: NSObject {

    func export(html: String, to url: URL) async throws {
        let data = try await renderToPDFData(html: html)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PDFExportError.writeFailed(error.localizedDescription)
        }
    }

    func renderToPDFData(html: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let config = WKWebViewConfiguration()
            let webView = WKWebView(
                frame: CGRect(x: 0, y: 0, width: 816, height: 1056),
                configuration: config
            )
            webView.isHidden = true

            let coordinator = Coordinator(continuation: continuation)
            coordinator.webView = webView
            webView.navigationDelegate = coordinator
            objc_setAssociatedObject(
                webView,
                &AssociatedKeys.coordinator,
                coordinator,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    private enum AssociatedKeys {
        static var coordinator = "coordinator"
    }
}

// MARK: - WKWebView coordinator

private final class Coordinator: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Data, Error>
    var webView: WKWebView?

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.generatePDF(from: webView)
        }
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        continuation.resume(throwing: PDFExportError.loadFailed(error.localizedDescription))
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        continuation.resume(throwing: PDFExportError.loadFailed(error.localizedDescription))
    }

    private func generatePDF(from webView: WKWebView) {
        let pdfConfig = WKPDFConfiguration()
        // rect intentionally left unset — WebKit uses the CSS @page rule
        webView.createPDF(configuration: pdfConfig) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.continuation.resume(returning: data)
            case .failure(let error):
                self.continuation.resume(
                    throwing: PDFExportError.renderFailed(error.localizedDescription))
            }
        }
    }
}

// MARK: - Platform-adaptive export

/// Renders the collection to PDF and presents the appropriate save/share UI
/// for the current platform.
@MainActor
func exportCollectionToPDF(
    collection: DocumentCollection,
    resolvedItems: [UUID: Division],
    loadedVolumes: [String: LoadedVolume],
    presentingView: PlatformViewReference
) async {
    let html = CollectionHTMLRenderer.html(
        for: collection,
        resolvedItems: resolvedItems,
        loadedVolumes: loadedVolumes
    )

    let data: Data
    do {
        data = try await PDFExporter().renderToPDFData(html: html)
    } catch {
        await presentingView.showError("PDF Render Failed", message: error.localizedDescription)
        return
    }

#if os(macOS)
    // macOS: NSSavePanel
    let panel = NSSavePanel()
    panel.nameFieldStringValue = sanitiseFilename(collection.name) + ".pdf"
    panel.allowedContentTypes = [UTType.pdf]
    panel.canCreateDirectories = true
    panel.message = "Choose where to save \u{201C}\(collection.name)\u{201D}"

    guard let window = presentingView.nsWindow else { return }
    let response = await panel.beginSheetModal(for: window)
    guard response == .OK, let url = panel.url else { return }

    do {
        try data.write(to: url, options: .atomic)
    } catch {
        await presentingView.showError("Save Failed", message: error.localizedDescription)
    }

#else
    // iPadOS: write to a temp file, then present the system share sheet.
    // "Save to Files" in the share sheet lets the user store to any Files location.
    let tempURL = FileManager.default.temporaryDirectory
        .appending(component: sanitiseFilename(collection.name) + ".pdf")
    do {
        try data.write(to: tempURL, options: .atomic)
    } catch {
        await presentingView.showError("Export Failed", message: error.localizedDescription)
        return
    }
    await presentingView.shareFile(at: tempURL)
#endif
}

// MARK: - PlatformViewReference

/// A platform-neutral reference to the presenting view context,
/// used to show panels, alerts, and share sheets without importing AppKit/UIKit
/// directly in callers.
@MainActor
final class PlatformViewReference {

#if os(macOS)
    weak var nsWindow: NSWindow?

    init(window: NSWindow? = nil) {
        self.nsWindow = window
    }

    /// Convenience no-arg init used as a safe fallback when the environment
    /// reference is nil (e.g. in previews or before the window is available).
    convenience init() { self.init(window: nil) }

    func showError(_ title: String, message: String) async {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    func shareFile(at url: URL) async {
        // Unused on macOS — we use NSSavePanel instead
    }

#else
    weak var uiViewController: UIViewController?

    init(viewController: UIViewController? = nil) {
        self.uiViewController = viewController
    }

    /// Convenience no-arg init used as a safe fallback when the environment
    /// reference is nil (e.g. in previews or before a view controller is available).
    convenience init() { self.init(viewController: nil) }

    func showError(_ title: String, message: String) async {
        guard let vc = uiViewController else { return }
        await withCheckedContinuation { cont in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                cont.resume()
            })
            vc.present(alert, animated: true)
        }
    }

    func shareFile(at url: URL) async {
        guard let vc = uiViewController else { return }
        await withCheckedContinuation { cont in
            let activity = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            activity.completionWithItemsHandler = { _, _, _, _ in cont.resume() }
            // On iPad, UIActivityViewController requires a sourceView or barButtonItem
            if let popover = activity.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(
                    x: vc.view.bounds.midX,
                    y: vc.view.bounds.midY,
                    width: 0, height: 0
                )
                popover.permittedArrowDirections = []
            }
            vc.present(activity, animated: true)
        }
    }
#endif
}

// MARK: - Filename sanitisation

private func sanitiseFilename(_ name: String) -> String {
    let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|")
    return name
        .components(separatedBy: forbidden)
        .joined(separator: "-")
        .trimmingCharacters(in: .whitespaces)
        .prefix(80)
        .description
}
