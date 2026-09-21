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
/// more magnified the plate and the LARGER the identity block is in plate coordinates — on a
/// 375 pt iPhone SE about 1.8x what an 834 pt iPad needs. A single hole big enough for the phone
/// leaves an iPad with most of its visible width empty, and one sized for the iPad puts words
/// under the wordmark on the phone.
///
/// An asset catalog already solves this: two images under one name, keyed by idiom, chosen by
/// the device with no code. So the plate is generated twice.
enum LaunchPlateIdiom: String, CaseIterable {
    case iphone, ipad

    /// The asset-catalog filename for this idiom's plate in one appearance — the VECTOR, which is
    /// the source of the rasters below and is what ships for review, not what the catalog carries.
    func filename(_ appearance: LaunchPlateAppearance) -> String {
        "LaunchCloud-\(rawValue)-\(appearance.rawValue).pdf"
    }

    /// The PNG renditions that ship, as (catalog scale, pixel edge).
    ///
    /// **The catalog carries PNGs and not the PDF, and the reason is a measured ceiling.** Left as
    /// a PDF, `actool` rasterises a 1400 pt plate at 4200 x 4200 for 3x — and a launch screen
    /// carrying that rendition drew BLACK on iPad Pro 11-inch and iPhone 17 (iOS 27.0): no
    /// background colour, no labels, no tile, and no snapshot written to the app container's
    /// `Library/SplashBoard`. The same storyboard with a 2400 x 2400 PNG drew everything on the
    /// iPhone, and the PDF kept as a vector for the `ipad` idiom (which `actool` rasterises at
    /// 2800 x 2800 for 2x beside the vector) drew everything on the iPad. So the ceiling lies
    /// between 2800 and 4200 pixels on an edge, and every rendition here stays at or under 2400,
    /// the smaller of the two edges that are known to render — at the cost of a mild upscale on
    /// the tallest canvases: an iPhone 17 Pro Max draws the 2400 px rendition at 2868 px (1.2x),
    /// a 13-inch iPad the 2400 px one at 2732 px (1.14x). The words are at most 24% alpha and
    /// serif; the upscale is not visible at arm's length and the alternative was a black launch
    /// screen. PNG for both idioms rather than a vector for one, because one proven mechanism is
    /// easier to keep true than two.
    var rasterRenditions: [(scale: Int, pixels: Int)] {
        switch self {
        case .iphone: [(2, 1600), (3, 2400)]
        case .ipad:   [(1, 1200), (2, 2400)]
        }
    }

    /// The catalog filename of one raster rendition.
    func rasterFilename(_ appearance: LaunchPlateAppearance, scale: Int) -> String {
        "LaunchCloud-\(rawValue)-\(appearance.rawValue)@\(scale)x.png"
    }

    /// The rects the words are kept out of, in plate coordinates — the glass tile's square and
    /// the wordmark-and-caption strip, each the union over this idiom's canvases of
    /// `LaunchSplashView.identityZones` mapped through that canvas's aspect-fill crop.
    ///
    /// Derived, not authored, so the launch screen's holes and the splash's zones are the same
    /// rule seen through the crop: a change to the block's layout moves both or neither. The
    /// first version of this suite authored one hole per idiom by eye and its own test caught it
    /// 66 plate points too narrow for an iPhone SE; deriving it removes that class of mistake, and
    /// `identityHoleSurvivesEveryCrop` now checks the derivation against each canvas rather than a
    /// hand-picked constant.
    var identityHoles: [CGRect] {
        var holes = [CGRect.null, CGRect.null]
        for canvas in canvases {
            for (index, zone) in mappedZones(on: canvas).enumerated() {
                holes[index] = holes[index].union(zone)
            }
        }
        return holes
    }

    /// The block's sizes on this idiom — asked for explicitly, because the generator runs on
    /// whichever simulator hosts the tests and `LaunchIdentityMetrics.current` would answer for it.
    var metrics: LaunchIdentityMetrics {
        switch self {
        case .iphone: .phone
        case .ipad:   .pad
        }
    }

    /// One canvas's identity zones, in plate coordinates.
    ///
    /// `scaleAspectFill` scales the square plate by `max(w, h) / edge` and centres it on the
    /// SCREEN; the block is centred in the SAFE AREA. So a canvas point maps to the plate as
    /// `centre + (point - screenCentre) / scale`, and the zones are asked for in the safe box
    /// with the canvas's insets so the safe-area offset is carried across.
    func mappedZones(on canvas: LaunchPlateCanvas) -> [CGRect] {
        let scale = max(canvas.size.width / launchPlateEdge, canvas.size.height / launchPlateEdge)
        let safe = CGSize(width: canvas.size.width - canvas.insets.leading - canvas.insets.trailing,
                          height: canvas.size.height - canvas.insets.top - canvas.insets.bottom)
        return LaunchSplashView.identityZones(in: safe, safeAreaInsets: canvas.insets,
                                              metrics: metrics).map { zone in
            CGRect(x: launchPlateEdge / 2 + (zone.minX - canvas.size.width / 2) / scale,
                   y: launchPlateEdge / 2 + (zone.minY - canvas.size.height / 2) / scale,
                   width: zone.width / scale, height: zone.height / scale)
        }
    }

    /// The canvases this idiom's plate must survive, in points, with their safe-area insets.
    ///
    /// Portrait and landscape both, because a launch screen is drawn in whatever orientation the
    /// device is held in and the crop differs between them. The insets matter now that the holes
    /// are derived: the block is centred in the safe area, which on a Dynamic Island phone sits
    /// 12.5 pt above the screen's centre.
    var canvases: [LaunchPlateCanvas] {
        switch self {
        case .iphone:
            [.init(375, 667, top: 20, bottom: 0),             // iPhone SE — the narrowest, and the worst case
             .init(393, 852, top: 59, bottom: 34),            // iPhone 17
             .init(440, 956, top: 59, bottom: 34),            // iPhone 17 Pro Max
             .init(852, 393, top: 0, bottom: 21, sides: 59)]  // …and on its side
        case .ipad:
            [.init(744, 1133, top: 24, bottom: 20),           // iPad mini — the narrowest iPad
             .init(834, 1210, top: 24, bottom: 20),           // iPad Pro 11"
             .init(1366, 1024, top: 24, bottom: 20),          // iPad Pro 13" landscape
             .init(1024, 1366, top: 24, bottom: 20)]          // …and on its end
        }
    }
}

/// A screen the plate must survive: its size in points and its safe-area insets.
struct LaunchPlateCanvas {
    let size: CGSize
    let insets: EdgeInsets
    init(_ width: CGFloat, _ height: CGFloat, top: CGFloat, bottom: CGFloat, sides: CGFloat = 0) {
        size = CGSize(width: width, height: height)
        insets = EdgeInsets(top: top, leading: sides, bottom: bottom, trailing: sides)
    }
}

/// The appearance a plate is baked for.
///
/// **The ink is BAKED.** A template asset would have carried weight in alpha and taken its colour
/// from the image view's `tintColor`, which is how one asset could have served both appearances.
/// #1346 tried that first and saw nothing drawn — but it saw nothing drawn for EVERY new asset,
/// because the device held a stale catalog (see the suite header), so the template route is
/// UNPROVEN either way rather than ruled out. Baked ink is verified on a clean device, costs one
/// more 130 KB PDF, and matches how `LaunchBackground`, `LaunchTitle` and `LaunchCaption` already
/// ship their two appearances; there is nothing to gain by re-testing the alternative.
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
///    appearance variants differ only in that ink — see ``LaunchPlateAppearance`` for why the
///    ink is baked rather than tinted at runtime.
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
/// ## THE PLATE SHIPS, and the lookup failure that held it back for one PR is explained
///
/// PR #1346 generated this plate and reverted its wiring: a full-bleed image view in
/// `LaunchScreen.storyboard` laid out correctly, drew `LaunchAppTile` when pointed at it, and drew
/// nothing when pointed at `LaunchCloud` — including in the known-good 88 pt tile view — while
/// `assetutil` found the asset in `Assets.car`. Template versus original intent, vector
/// preservation, PDF versus PNG, idiom versus universal, 1400 pt versus 200 pt and a mismatched
/// `<resources>` size were each "eliminated" by a build-and-capture cycle.
///
/// **Every one of those cycles ran on a device holding a stale copy of the catalog.** Measured
/// 2026-09-20 on the same iPad Pro 11-inch (M5) / iOS 27.0: a launch screen carrying SEVEN new
/// assets — this plate as PDF and as PNG, a byte-identical copy of `LaunchAppTile` under a new
/// name, a 400 pt PDF with embedded fonts, the same PDF with the text as outlines, a 300 pt PNG
/// crop and the app icon at 1x/2x/3x — drew none of them after uninstall + reinstall and drew
/// `LaunchAppTile` in the same frame. After `simctl shutdown` + `boot` + reinstall, and on a
/// simulator that had never had the app, all seven drew. The launch-screen renderer keeps the
/// app's asset catalog in memory per bundle identifier, and reinstalling does not evict it: a
/// name that existed at the first launch of that boot resolves (to the OLD content), and a name
/// that did not resolves to nothing. Every "eliminated" explanation was a property of the device,
/// not of the asset. **Reboot the simulator after changing a launch-screen image.**
///
/// The wiring is the storyboard's `img-cloud-aaa`, full-bleed and aspect-filled behind the
/// identity block, exactly as #1346 built it — but the catalog carries PNG RENDITIONS of the plate
/// and not the PDF, because the first wired build drew a black launch screen on both devices: see
/// ``LaunchPlateIdiom/rasterRenditions`` for the measured ceiling. `shippedPlateResolves` below is
/// the guard that the catalog still carries what the storyboard names.
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
            exclusionZones: idiom.identityHoles,
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

    /// The holes are what make a square plate work on a device it was not composed for, so they
    /// are checked against every canvas rather than left to look right on the machine they were
    /// made on. Derived holes cover their canvases by construction; what this pins is that the
    /// derivation is SANE — a hole that had swallowed the plate would also "cover" everything.
    @Test("The identity holes cover every canvas of their idiom and no more than they must",
          arguments: LaunchPlateIdiom.allCases)
    func identityHoleSurvivesEveryCrop(idiom: LaunchPlateIdiom) {
        let holes = idiom.identityHoles
        #expect(holes.count == 2)
        for canvas in idiom.canvases {
            for (index, zone) in idiom.mappedZones(on: canvas).enumerated() {
                #expect(holes[index].contains(zone),
                        "\(idiom) on \(Int(canvas.size.width))x\(Int(canvas.size.height)): zone \(index) escapes its hole")
            }
        }
        // The tile hole is a near-square around the glass plate (104 pt on a phone, 192 on an
        // iPad); the text strip is wider than it is tall. Neither may approach the plate's own
        // edge, or there is no cloud left to show.
        let tile = holes[0], text = holes[1]
        #expect(tile.width < launchPlateEdge / 2.5 && tile.height < launchPlateEdge / 2.5,
                "\(idiom): tile hole \(Int(tile.width))x\(Int(tile.height)) — the derivation has run away")
        #expect(text.width > text.height, "\(idiom): the text hole should be a strip")
        #expect(text.width < launchPlateEdge * 0.7,
                "\(idiom): text hole \(Int(text.width)) wide — the derivation has run away")
        #expect(text.minY > tile.midY, "\(idiom): the text strip must sit below the tile's centre")
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
            for hole in idiom.identityHoles {
                #expect(!box.intersects(hole),
                        "\(idiom): '\(word.term)' was placed over the identity block")
            }
        }
    }

    // MARK: - What ships

    /// The two images the launch storyboard names resolve from the catalog the app carries.
    ///
    /// Cheap, and worth having: a launch screen cannot say when an image fails to load, so the
    /// only other guard is a screenshot. `LaunchAppTile` is also the app icon the splash and
    /// onboarding draw, so a missing rendition there is three surfaces, not one.
    @Test("The launch storyboard's images resolve", arguments: ["LaunchCloud", "LaunchAppTile"])
    func shippedPlateResolves(name: String) throws {
        #if canImport(UIKit)
        let image = try #require(UIImage(named: name), "\(name) is missing from the catalog")
        #expect(image.size.width > 0 && image.size.height > 0)
        #else
        let image = try #require(NSImage(named: name), "\(name) is missing from the catalog")
        #expect(image.size.width > 0 && image.size.height > 0)
        #endif
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

        // The rasters that ship — see `rasterRenditions` for why the catalog carries these and
        // not the PDF. Rendered from the same view at a scale that yields exactly the pixel edge.
        for rendition in idiom.rasterRenditions {
            let raster = ImageRenderer(content: plate(words, ink: appearance.ink))
            raster.proposedSize = ProposedViewSize(width: launchPlateEdge, height: launchPlateEdge)
            raster.scale = CGFloat(rendition.pixels) / launchPlateEdge
            let image = try #require(raster.cgImage, "no raster at \(rendition.pixels) px")
            #expect(image.width == rendition.pixels && image.height == rendition.pixels,
                    "\(idiom.rawValue)@\(rendition.scale)x rendered \(image.width) px, not \(rendition.pixels)")
            let pngURL = directory.appending(path: idiom.rasterFilename(appearance, scale: rendition.scale))
            let destination = try #require(CGImageDestinationCreateWithURL(
                pngURL as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination), "could not write \(pngURL.lastPathComponent)")
        }

        print("[LaunchArtwork] \(idiom.rawValue)/\(appearance.rawValue): \(words.count) words -> \(url.path) (\((data as Data).count) bytes)")
        #expect((data as Data).count > 2_000, "the PDF is suspiciously small; did anything draw?")
    }
}
