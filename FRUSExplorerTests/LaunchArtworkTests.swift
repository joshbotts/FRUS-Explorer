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

import Testing
import Foundation
import SwiftUI
import UniformTypeIdentifiers
@testable import FRUSExplorer

/// Where a generator run writes, or `nil` for an ordinary run.
///
/// FILE-LEVEL, not a static on the suite. The suite is `@MainActor`, so its statics are too, and
/// `@Test(.enabled(if:))` evaluates its condition in a nonisolated Sendable closure — which is a
/// compile error rather than a runtime surprise, but only once something tries it. The
/// frame-sequence suite's `frameSequenceHasMetal` has the same shape for the same reason.
private let launchArtworkOutputDirectory: URL? =
    ProcessInfo.processInfo.environment["RENDER_LAUNCH_ARTWORK_DIR"]
        .map { URL(fileURLWithPath: $0, isDirectory: true) }

/// The plate's edge, in points.
///
/// Square because the storyboard aspect-FILLS it: a square source crops symmetrically from
/// whichever axis is long, so no device sees a stretched composition and every device sees the
/// middle. 1400 covers the widest supported canvas (a 1366 pt iPad in landscape) without upscaling.
///
/// FILE-LEVEL for the same reason `launchArtworkOutputDirectory` is: the suite is `@MainActor`, so
/// a static on it is too, and `LaunchPlateIdiom` below is an ordinary nonisolated type.
let launchPlateEdge: CGFloat = 1400

    /// The two plates, because ONE cannot serve both idioms and the measurement says so.
///
/// Aspect-fill magnifies a square plate by `max(w, h) / edge`, so the *narrower* the device the
/// more magnified the plate and the LARGER the identity block is in plate coordinates. On a
/// 375 pt iPhone SE the block needs a 686 x 374 hole; on an 834 pt iPad it needs 394 x 206.
/// A single hole big enough for the phone leaves an iPad with 75% of its visible width empty,
/// and one sized for the iPad puts words under the wordmark on the phone.
///
/// An asset catalog already solves this: two images under one name, keyed by idiom, chosen by
/// the device with no code. So the plate is generated twice.
enum LaunchPlateIdiom: String, CaseIterable {
    case iphone, ipad

    /// The asset-catalog filename for this idiom's plate in one appearance.
    func filename(_ appearance: LaunchPlateAppearance) -> String {
        "LaunchCloud-\(rawValue)-\(appearance.rawValue).pdf"
    }

    /// The centred rect the words are kept out of, in plate coordinates.
    ///
    /// Each is the worst case over that idiom's canvases in ``LaunchPlateIdiom/canvases``,
    /// rounded up — `identityHoleSurvivesEveryCrop` is what holds them to it.
    var identityHole: CGRect {
        let size: CGSize = switch self {
        case .iphone: CGSize(width: 720, height: 400)
        case .ipad:   CGSize(width: 460, height: 250)
        }
        return CGRect(x: (launchPlateEdge - size.width) / 2, y: (launchPlateEdge - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// The canvases this idiom's plate must survive, in points.
    ///
    /// Portrait and landscape both, because a launch screen is drawn in whatever orientation the
    /// device is held in and the crop differs between them.
    var canvases: [CGSize] {
        switch self {
        case .iphone:
            [CGSize(width: 375, height: 667),    // iPhone SE — the narrowest, and the worst case
             CGSize(width: 393, height: 852),    // iPhone 17
             CGSize(width: 440, height: 956),    // iPhone 17 Pro Max
             CGSize(width: 852, height: 393)]    // …and on its side
        case .ipad:
            [CGSize(width: 744, height: 1133),   // iPad mini — the narrowest iPad
             CGSize(width: 834, height: 1210),   // iPad Pro 11"
             CGSize(width: 1366, height: 1024),  // iPad Pro 13" landscape
             CGSize(width: 1024, height: 1366)]  // …and on its end
        }
    }
}

/// The appearance a plate is baked for.
///
/// **The ink is BAKED, and a template image is what this replaces.** A template asset would have
/// carried weight in alpha and taken its colour from the image view's `tintColor`, which is how one
/// asset could have served both appearances. It does not work in a launch screen: measured on iPad
/// Pro 11-inch / iOS 27.0 with the image view given a temporary red background, the view laid out
/// full-bleed and drew **nothing at all** — while `LaunchAppTile`, a PDF in the same catalog with
/// `template-rendering-intent: original`, drew normally in the same frame. So the plate follows the
/// tile: original intent, colour baked, and the two appearances shipped as asset-catalog variants
/// exactly as `LaunchBackground`, `LaunchTitle` and `LaunchCaption` already are.
enum LaunchPlateAppearance: String, CaseIterable {
    case light, dark

    /// The ink, at full strength; each word's own alpha is applied on top of it.
    var ink: Color {
        switch self {
        case .light: .black
        case .dark:  .white
        }
    }
}

/// The launch screen's backdrop plate, and the rules that make a static asset honest.
///
/// ## Why a generated asset and not a drawn one
/// `LaunchScreen.storyboard` runs **no code**: no packer, no `NLTagger`, no Dynamic Type, no
/// `Color.primary`. So the only way the launch screen can carry the app's own visual signature is
/// to bake one — and the only way a baked one can be *true* is for it to come out of the same
/// `WordCloudLayout.place` and the same `cloud-vectors-core.json` that every live surface reads.
/// This suite is that generator, behind `RENDER_LAUNCH_ARTWORK_DIR`, on the env-gated pattern
/// `SemanticMapFrameSequenceTests` already establishes.
///
/// ## Three properties the plate must have, and each is asserted rather than assumed
/// 1. **Its weight lives in ALPHA.** Every word is drawn in one ink at a varying alpha, so the two
///    appearance variants differ only in that ink — see ``LaunchPlateAppearance``, which also
///    records why a template asset (one image, tinted) does not work in a launch screen.
/// 2. **It is SQUARE, with a hole in the middle.** The storyboard scales it `scaleAspectFill`,
///    which crops the long edge and always keeps the centre — so a centred exclusion zone is the
///    one region guaranteed to survive on every device from a 375 pt phone to a 1366 pt iPad, and
///    that is exactly where the identity block sits.
/// 3. **It is QUIET.** A launch screen is a held frame, seen on every cold start, and the app's
///    own measured rule for a cloud under type is `FRUSTheme.cloudDimIndexingStrip`.
///
/// Regenerate with:
///
///     TEST_RUNNER_RENDER_LAUNCH_ARTWORK_DIR=/tmp/launch-art xcodebuild test … \
///       -only-testing FRUSExplorerTests/LaunchArtworkTests
///
/// ## NOTHING CONSUMES THE PLATE YET, AND THE REASON IS A PLATFORM FACT THIS SUITE RECORDS
///
/// The intended consumer is a full-bleed `UIImageView` behind the identity block in
/// `LaunchScreen.storyboard`. It was built and **it does not render**, for a reason none of the
/// obvious explanations covers. Measured on iPad Pro 11-inch (M5) / iOS 27.0, fresh install each
/// time, `simctl` screenshots of the settled launch screen:
///
/// - The image view is laid out correctly. Given a temporary red background it filled the screen.
/// - The image view renders images. Pointed at `LaunchAppTile` it drew that, full-bleed.
/// - The asset compiles. `assetutil --info` finds `LaunchCloud` in the built `Assets.car` in every
///   configuration tried.
/// - **`LaunchCloud` never resolves at runtime.** Placed in the *known-good* 88 pt tile image view,
///   in place of `LaunchAppTile`, it drew nothing there either — so the fault is the asset lookup
///   and not the view.
///
/// Ruled out, each by its own build-and-capture cycle: template versus original rendering intent;
/// `preserves-vector-representation` on and off; PDF versus PNG; per-idiom keying versus
/// `universal`; a 1400 pt plate versus a 200 pt one; and a `<resources>` declaration whose stated
/// size disagreed with the asset's. The launch screen renders the storyboard's own views and the
/// catalog's colours, and draws `LaunchAppTile`, so the boundary is narrower than "launch screens
/// cannot use the catalog" — but what puts `LaunchCloud` on the wrong side of it is not yet known.
///
/// **So the plate ships as a measurement, not a feature.** The composition and its geometry are the
/// expensive, reusable half and they are verified below; the wiring is one image view whenever the
/// lookup is explained. Owner decision 2026-09-20: do not ship a launch screen asset nobody can
/// account for.
///
/// Version history:
///   1.0 — the launch screen's cloud plate
@Suite("Launch artwork")
@MainActor
struct LaunchArtworkTests {

    // MARK: - The composition

    /// The plate's words, from the bundled artifact through the app's own packer.
    ///
    /// `.concepts`, matching `WordCloudBackdropView.firstImpressionLenses.first` — the launch
    /// screen hands over to the splash, and the splash opens on that lens by seed. The two must
    /// name the same vocabulary or the handover the storyboard's own header calls "one moment"
    /// becomes two.
    private func placedWords(for idiom: LaunchPlateIdiom) async -> [PlacedWord] {
        await BundledCloudVectors.prepareCore()
        guard let source = BundledCloudVectors.terms(forScope: .corpus, lens: .concepts) else {
            return []
        }
        return WordCloudLayout.place(
            terms: source.terms,
            in: CGSize(width: launchPlateEdge, height: launchPlateEdge),
            maxWords: 50,
            minFontSize: 22,
            maxFontSize: 96,
            exclusionZones: [idiom.identityHole],
            // NO vertical squash. `FRUSTheme.cloudYCompression` makes the field elliptical so it
            // fills a wide screen; this plate is square and is then cropped to the screen, so a
            // squashed source would leave bands of nothing on the axis the crop keeps.
            yCompression: 1.0,
            sizeExponent: FRUSTheme.cloudSizeExponent
        )
    }

    /// The plate as a view: one ink colour, alpha carrying weight, nothing else.
    private func plate(_ words: [PlacedWord], ink: Color) -> some View {
        let maxCount = max(1, words.first?.count ?? 1)
        return ZStack {
            Color.clear
            ForEach(words, id: \.id) { word in
                Text(word.term)
                    .font(.system(size: word.fontSize, weight: .semibold, design: .serif))
                    // One ink at a varying alpha. The alpha is the whole encoding — weight, and
                    // the ceiling that keeps this quiet — so the two appearances differ ONLY in
                    // which ink it is applied to.
                    .foregroundStyle(ink.opacity(Self.alpha(count: word.count, of: maxCount)))
                    .rotationEffect(.degrees(word.rotationDegrees))
                    .position(word.center)
            }
        }
        .frame(width: launchPlateEdge, height: launchPlateEdge)
    }

    /// A word's alpha, from its share of the loudest word's count.
    ///
    /// Ceilinged at `FRUSTheme.cloudDimIndexingStrip`, which is the app's one MEASURED figure for
    /// "a cloud under type that has to stay readable" — see
    /// `WordCloudDriftRenderTests.stripCloudStaysUnderItsCaption`, which resolves `.tertiary`
    /// through a renderer rather than assuming it. A launch screen is a held frame on every cold
    /// start, so if anything it wants to be quieter than a banner, never louder.
    static func alpha(count: Int, of maxCount: Int) -> Double {
        let weight = Double(count) / Double(max(1, maxCount))
        let floorShare = 0.45
        return FRUSTheme.cloudDimIndexingStrip * (floorShare + (1 - floorShare) * weight)
    }

    // MARK: - Properties

    @Test("The plate's ink never exceeds the app's measured ceiling for a cloud under type")
    func alphaStaysUnderTheCeiling() {
        let ceiling = FRUSTheme.cloudDimIndexingStrip
        #expect(Self.alpha(count: 100, of: 100) <= ceiling + 1e-9,
                "the loudest word must not exceed the banner ceiling")
        #expect(Self.alpha(count: 1, of: 100) > 0,
                "and the quietest must still draw — an invisible word is a wasted one")
        #expect(Self.alpha(count: 1, of: 100) < Self.alpha(count: 100, of: 100),
                "weight must still be legible as weight")
    }

    /// The hole is what makes a square plate work on a device it was not composed for, so its
    /// geometry is pinned rather than left to look right on the machine it was made on.
    ///
    /// **This test failed on its first run and that is why the plate is per-idiom.** A single
    /// 620 x 340 hole, sized by eye from a 393 pt phone, was 66 plate points too narrow and 34 too
    /// short for a 375 pt iPhone SE — where aspect-fill magnifies the plate most and the identity
    /// block is therefore largest in plate coordinates.
    @Test("The identity hole survives an aspect-fill crop on every canvas of its idiom",
          arguments: LaunchPlateIdiom.allCases)
    func identityHoleSurvivesEveryCrop(idiom: LaunchPlateIdiom) {
        // `LaunchSplashView`'s block, whose composition the storyboard mirrors. The 48 is the
        // storyboard's own 2 x 24 pt horizontal inset, which bounds the block on a narrow device.
        let blockWidth: CGFloat = 340
        let blockHeight = LaunchSplashView.identityBlockMinimumHeight

        for canvas in idiom.canvases {
            // scaleAspectFill: the plate is scaled so BOTH axes are covered, then centre-cropped.
            let scale = max(canvas.width / launchPlateEdge, canvas.height / launchPlateEdge)
            // The identity block, expressed in plate points at that scale.
            let neededWidth = min(blockWidth, canvas.width - 48) / scale
            let neededHeight = blockHeight / scale
            #expect(idiom.identityHole.width >= neededWidth,
                    "\(idiom) on \(Int(canvas.width))x\(Int(canvas.height)): the block needs \(neededWidth) plate pt of width")
            #expect(idiom.identityHole.height >= neededHeight,
                    "\(idiom) on \(Int(canvas.width))x\(Int(canvas.height)): the block needs \(neededHeight) plate pt of height")
        }
    }

    @Test("Each plate is packed from the bundled artifact and clears the identity block",
          arguments: LaunchPlateIdiom.allCases)
    func plateIsPackedAndClear(idiom: LaunchPlateIdiom) async throws {
        let words = await placedWords(for: idiom)
        try #require(!words.isEmpty, "no bundled concepts list — the plate cannot be generated")
        #expect(words.count > 20, "only \(words.count) words placed; the plate would read as sparse")

        for word in words {
            let half = WordCloudDriftField.estimatedHalfSize(
                term: word.term, fontSize: word.fontSize, rotated: word.rotationDegrees != 0)
            let box = CGRect(x: word.center.x - half.width, y: word.center.y - half.height,
                             width: half.width * 2, height: half.height * 2)
            #expect(!box.intersects(idiom.identityHole),
                    "\(idiom): '\(word.term)' was placed over the identity block")
        }
    }

    // MARK: - The generator

    @Test("Render the plates (RENDER_LAUNCH_ARTWORK_DIR)",
          .enabled(if: launchArtworkOutputDirectory != nil),
          arguments: LaunchPlateIdiom.allCases, LaunchPlateAppearance.allCases)
    func renderPlate(idiom: LaunchPlateIdiom, appearance: LaunchPlateAppearance) async throws {
        let directory = try #require(launchArtworkOutputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let words = await placedWords(for: idiom)
        try #require(!words.isEmpty)

        let renderer = ImageRenderer(content: plate(words, ink: appearance.ink))
        renderer.proposedSize = ProposedViewSize(width: launchPlateEdge, height: launchPlateEdge)

        let url = directory.appending(path: idiom.filename(appearance))
        var box = CGRect(x: 0, y: 0, width: launchPlateEdge, height: launchPlateEdge)
        let data = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: data))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        renderer.render { _, draw in
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        try (data as Data).write(to: url)

        // A PNG beside it, for looking at. Never shipped — the asset is the vector.
        if let image = renderer.cgImage {
            let preview = directory.appending(path: "LaunchCloud-\(idiom.rawValue)-\(appearance.rawValue)-preview.png")
            if let destination = CGImageDestinationCreateWithURL(
                preview as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                _ = CGImageDestinationFinalize(destination)
            }
        }

        print("[LaunchArtwork] \(idiom.rawValue)/\(appearance.rawValue): \(words.count) words -> \(url.path) (\((data as Data).count) bytes)")
        #expect((data as Data).count > 2_000, "the PDF is suspiciously small; did anything draw?")
    }
}
