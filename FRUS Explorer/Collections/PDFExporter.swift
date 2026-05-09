// Collections/PDFExporter.swift
//
// Renders a DocumentCollection to a PDF and saves or shares it:
//
//   macOS  — WKWebView.createPDF() drives PDF generation directly through
//            WebKit. The HTML's @page { size: 8.5in 11in; margin: 1in } CSS
//            rule controls pagination. NSSavePanel lets the user pick a save
//            location. This approach requires no print entitlement and is
//            fully sandboxed — NSPrintOperation is NOT used because it requires
//            access to the print daemon (printd) which is blocked by the
//            sandbox, causing a crash.
//   iPadOS — UIPrintPageRenderer with viewPrintFormatter() drives pagination.
//            UIActivityViewController presents the system share sheet.

import Foundation
import WebKit
import UniformTypeIdentifiers
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
            // Width = printable content area: 8.5" − 2 × 1" margin = 6.5" × 96 CSS px/in = 624 px.
            // Height is one page tall; the print pipeline handles multi-page layout.
            let webView = WKWebView(
                frame: CGRect(x: 0, y: 0, width: 624, height: 1056),
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
        // UInt8 key avoids the UnsafeRawPointer-to-String warning that arises
        // when a Swift String is used as an objc_setAssociatedObject key.
        static var coordinator: UInt8 = 0
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
#if os(macOS)
        // macOS: WKWebView.createPDF() is the sandboxed path — it talks directly
        // to the WebContent process and needs no print entitlement. The HTML's
        // @page { size: 8.5in 11in; margin: 1in } CSS rule tells WebKit the paper
        // dimensions, so the resulting PDF is paginated to US letter.
        //
        // NSPrintOperation is intentionally avoided: it requires the print daemon
        // (printd / printToolAgent) which is blocked by the app sandbox, causing
        // an immediate crash with "frame not initialized" from WKPrintingView.
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.continuation.resume(returning: data)
            case .failure(let error):
                self.continuation.resume(throwing: PDFExportError.renderFailed(
                    error.localizedDescription))
            }
        }

#else
        let ptPerIn: CGFloat = 72          // PDF point = 1/72 inch
        let pageW:   CGFloat = 8.5 * ptPerIn   // 612 pt
        let pageH:   CGFloat = 11.0 * ptPerIn  // 792 pt
        let margin:  CGFloat = 1.0 * ptPerIn   //  72 pt
        // iPadOS: UIPrintPageRenderer with viewPrintFormatter() properly
        // paginates the web view's content into letter-size pages.
        let paperRect     = CGRect(origin: .zero, size: CGSize(width: pageW, height: pageH))
        let printableRect = paperRect.insetBy(dx: margin, dy: margin)

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: paperRect),     forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
        let pageCount = renderer.numberOfPages
        for i in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        guard pdfData.length > 0 else {
            continuation.resume(throwing: PDFExportError.renderFailed(
                "PDF rendering produced no data"))
            return
        }
        continuation.resume(returning: pdfData as Data)
#endif
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
