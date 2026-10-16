// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import FRUSExplorer

/// Settings ▸ Display's Reading Width (#1665, the owner's decisions 20 and 50): its two ladders,
/// the reload it causes, the page it reaches, and the characters a line its footer states.
@Suite("Reading Width: the reader's measure on each device (#1665)")
@MainActor
struct ReadingWidthTests {

    @Test("Each step is its ladder's rung: 60, 70 and 87ch on iPhone; 70, 87 and 120ch on iPad and the Mac")
    func theLadders() {
        #expect(ReadingWidth.allCases.map { $0.measure(on: .phone).ch } == [60, 70, 87])
        #expect(ReadingWidth.allCases.map { $0.measure(on: .wide).ch } == [70, 87, 120])
        #expect(ReadingWidth.standard.measure(on: .phone) == .classic,
                "the phone's default is no longer the measure the owner found right for phones")
        let ladder: ReadingWidth.Ladder = UIDevice.current.userInterfaceIdiom == .phone ? .phone : .wide
        #expect(ReadingWidth.currentLadder == ladder)
        #expect(ReadingWidth.wide.measure == ReadingWidth.wide.measure(on: ladder))
    }

    @Test("A change of Reading Width reloads the reader, and the page it loads carries the step's measure")
    func theReaderCarriesTheMeasure() async throws {
        let standard = WebViewSignature(documentId: "d475", colorScheme: .light, textSize: .medium, measure: .classic)
        let wider = WebViewSignature(documentId: "d475", colorScheme: .light, textSize: .medium,
                                     measure: ReaderMeasure(ch: 87))
        #expect(standard != wider, "a new Reading Width would leave the page as it was")

        let model = try await ListShapeFixtures.renderModel(Self.longTelegramProse,
                                                            converter: ASTToRenderNodeConverter(volumeId: "frus1946v06"))
        let page = HTMLTemplate.build(model: model, colorScheme: .light, textSize: .medium,
                                      measure: ReaderMeasure(ch: 120))
        #expect(page.contains("--reader-measure:          120ch;"))
        #expect(HTMLTemplate.build(model: model, colorScheme: .light).contains("--reader-measure:          70ch;"),
                "a page built with no measure is not the 70ch page it was")
    }

    /// The footer's figures are measured, and this measures them again: the mean characters a
    /// full line, in the reader's own web view, of the fixture's paragraphs at Medium text. The
    /// whole document measured 63, 77, 100 and 145 (`ReaderMeasure`); these six paragraphs come
    /// within a character of each.
    @Test("Each rung holds the characters a line Settings says it does, at Medium text")
    func theFooterFiguresAreMeasured() async throws {
        let model = try await ListShapeFixtures.renderModel(Self.longTelegramProse,
                                                            converter: ASTToRenderNodeConverter(volumeId: "frus1946v06"))
        let stated: [(measure: Int, characters: Double)] = [(60, 63), (70, 77), (87, 100), (120, 145)]
        var measured: [Int: Double] = [:]
        for rung in stated {
            let harness = OffsetEngineTestHarness()
            // Wider than every rung, so the measure alone sets the column.
            harness.webView.frame = CGRect(x: 0, y: 0, width: 1_400, height: 900)
            try await harness.load(ReaderPage.build(model: model, appearance: .light, textSize: .medium,
                                                    measure: ReaderMeasure(ch: rung.measure)))
            let mean = try #require(try await harness.webView.evaluateJavaScript(Self.meanCharactersALine) as? Double)
            measured[rung.measure] = mean
            #expect(abs(mean - rung.characters) <= 2,
                    "\(rung.measure)ch holds \(mean) characters a line, where Settings says about \(Int(rung.characters))")
        }
        print("[ReadingWidthTests] mean characters a line at Medium: \(measured.sorted { $0.key < $1.key })")
    }

    /// The mean characters of a paragraph's full lines (each paragraph's last, partial line left
    /// out), over every paragraph of the document: each character is placed on its line by the
    /// top of its own box.
    static let meanCharactersALine = """
    (() => {
      const counts = [];
      for (const p of document.querySelectorAll('.frus-document p')) {
        const walker = document.createTreeWalker(p, NodeFilter.SHOW_TEXT);
        let top = null, n = 0;
        while (walker.nextNode()) {
          const t = walker.currentNode;
          for (let i = 0; i < t.length; i++) {
            const r = document.createRange(); r.setStart(t, i); r.setEnd(t, i + 1);
            const rects = r.getClientRects(); if (rects.length === 0) continue;
            const y = rects[0].top;
            if (top === null) top = y;
            if (y - top > 8) { counts.push(n); n = 0; top = y; }
            n++;
          }
        }
      }
      return counts.reduce((a, b) => a + b, 0) / counts.length;
    })()
    """

    /// Six paragraphs of the Long Telegram (frus1946v06/d475), its plain prose — every paragraph of
    /// more than 500 characters with no list, quotation, note, table or line break in it — as the
    /// TEI prints them with their italics and page breaks dropped: 7,825 characters. A work of the
    /// United States government, in the public domain.
    static let longTelegramProse = """
    <div type="document" xml:id="d475" n="475">
        <head>The Chargé in the Soviet Union (Kennan) to the Secretary of State</head>
        <p>First, it does not represent natural outlook of Russian people. Latter are, by and large, friendly to outside world, eager for experience of it, eager to measure against it talents they are conscious of possessing, eager above all to live in peace and enjoy fruits of their own labor. Party line only represents thesis which official propaganda machine puts forward with great skill and persistence to a public often remarkably resistant in the stronghold of its innermost thoughts. But party line is binding for outlook and conduct of people who make up apparatus of power—party, secret police and Government—and it is exclusively with these that we have to deal.</p>
        <p>Second, please note that premises on which this party line is based are for most part simply not true. Experience has shown that peaceful and mutually profitable coexistence of capitalist and socialist states is entirely possible. Basic internal conflicts in advanced countries are no longer primarily those arising out of capitalist ownership of means of production, but are ones arising from advanced urbanism and industrialism as such, which Russia has thus far been spared not by socialism but only by her own backwardness. Internal rivalries of capitalism do not always generate wars; and not all wars are attributable to this cause. To speak of possiblity of intervention against USSR today, after elimination of Germany and Japan and after example of recent war, is sheerest nonsense. If not provoked by forces of intolerance and subversion “capitalist” world of today is quite capable of living at peace with itself and with Russia. Finally, no sane person has reason to doubt sincerity of moderate socialist leaders in Western countries. Nor is it fair to deny success of their efforts to improve conditions for working population whenever, as in Scandinavia, they have been given chance to show what they could do.</p>
        <p>Falseness of these premises, every one of which pre-dates recent war, was amply demonstrated by that conflict itself. Anglo-American differences did not turn out to be major differences of Western World. Capitalist countries, other than those of Axis, showed no disposition to solve their differences by joining in crusade against USSR. Instead of imperialist war turning into civil wars and revolution, USSR found itself obliged to fight side by side with capitalist powers for an avowed community of aims.</p>
        <p>At bottom of Kremlin’s neurotic view of world affairs is traditional and instinctive Russian sense of insecurity. Originally, this was insecurity of a peaceful agricultural people trying to live on vast exposed plain in neighborhood of fierce nomadic peoples. To this was added, as Russia came into contact with economically advanced West, fear of more competent, more powerful, more highly organized societies in that area. But this latter type of insecurity was one which afflicted rather Russian rulers than Russian people; for Russian rulers have invariably sensed that their rule was relatively archaic in form, fragile and artificial in its psychological foundation, unable to stand comparison or contact with political systems of Western countries. For this reason they have always feared foreign penetration, feared direct contact between Western world and their own, feared what would happen if Russians learned truth about world without or if foreigners learned truth about world within. And they have learned to seek security only in patient but deadly struggle for total destruction of rival power, never in compacts and compromises with it.</p>
        <p>It was no coincidence that Marxism, which had smouldered ineffectively for half a century in Western Europe, caught hold and blazed for first time in Russia. Only in this land which had never known a friendly neighbor or indeed any tolerant equilibrium of separate powers, either internal or international, could a doctrine thrive which viewed economic conflicts of society as insoluble by peaceful means. After establishment of Bolshevist regime, Marxist dogma, rendered even more truculent and intolerant by Lenin’s interpretation, became a perfect vehicle for sense of insecurity with which Bolsheviks, even more than previous Russian rulers, were afflicted. In this dogma, with its basic altruism of purpose, they found justification for their instinctive fear of outside world, for the dictatorship without which they did not know how to rule, for cruelties they did not dare not to inflict, for sacrifices they felt bound to demand. In the name of Marxism they sacrificed every single ethical value in their methods and tactics. Today they cannot dispense with it. It is fig leaf of their moral and intellectual respectability. Without it they would stand before history, at best, as only the last of that long succession of cruel and wasteful Russian rulers who have relentlessly forced country on to ever new heights of military power in order to guarantee external security of their internally weak regimes. This is why Soviet purposes must always be solemnly clothed in trappings of Marxism, and why no one should underrate importance of dogma in Soviet affairs. Thus Soviet leaders are driven [by?] necessities of their own past and present position to put forward a dogma which [apparent omission] outside world as evil, hostile and menacing, but as bearing within itself germs of creeping disease and destined to be wracked with growing internal convulsions until it is given final coup de grace by rising power of socialism and yields to new and better world. This thesis provides justification for that increase of military and police power of Russian state, for that isolation of Russian population from outside world, and for that fluid and constant pressure to extend limits of Russian police power which are together the natural and instinctive urges of Russian rulers. Basically this is only the steady advance of uneasy Russian nationalism, a centuries old movement in which conceptions of offense and defense are inextricably confused. But in new guise of international Marxism, with its honeyed promises to a desperate and war torn outside world, it is more dangerous and insidious than ever before.</p>
        <p>It should not be thought from above that Soviet party line is necessarily disingenuous and insincere on part of all those who put it forward. Many of them are too ignorant of outside world and mentally too dependent to question [apparent omission] self-hypnotism, and who have no difficulty making themselves believe what they find it comforting and convenient to believe. Finally we have the unsolved mystery as to who, if anyone, in this great land actually receives accurate and unbiased information about outside world. In atmosphere of oriental secretiveness and conspiracy which pervades this Government, possibilities for distorting or poisoning sources and currents of information are infinite. The very disrespect of Russians for objective truth—indeed, their disbelief in its existence—leads them to view all stated facts as instruments for furtherance of one ulterior purpose or another. There is good reason to suspect that this Government is actually a conspiracy within a conspiracy; and I for one am reluctant to believe that Stalin himself receives anything like an objective picture of outside world. Here there is ample scope for the type of subtle intrigue at which Russians are past masters. Inability of foreign governments to place their case squarely before Russian policy makers—extent to which they are delivered up in their relations with Russia to good graces of obscure and unknown advisers whom they never see and cannot influence—this to my mind is most disquieting feature of diplomacy in Moscow, and one which Western statesmen would do well to keep in mind if they would understand nature of difficulties encountered here.</p>
    </div>
    """
}
