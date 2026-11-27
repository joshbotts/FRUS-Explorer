# L35's check: when the export sheet opens, are its sentence, the format and Export in view?
# 1.0's sheet (CollectionExportSheet.swift:342-397): the sentence in .callout, then the two-column format
# grid (label .body semibold, caption .caption lineLimit 1), with Export pinned (L35's change).
# Sentences built by Collection.compositionSummarySentence's rule (Collection.swift:244-280) for each recipe
# (CollectionExporter.swift:226-249) and a new collection (decision 159: 1.0's settings).
# Arithmetic only: greedy wrap at half an em a character; layout constants from memory; text styles as fetched
# from the HIG today.
STYLES = {
    "body":    {"L": (17, 22), "AX3": (40, 48), "AX5": (53, 62)},
    "callout": {"L": (16, 21), "AX3": (38, 46), "AX5": (51, 60)},
    "caption": {"L": (12, 16), "AX3": (32, 39), "AX5": (43, 51)},
}


def lines(text, width, size):
    per = 0.5 * size
    n, cur = 1, 0.0
    for w in text.split():
        wl = len(w) * per
        add = wl if cur == 0 else wl + per
        if cur + add <= width:
            cur += add
        else:
            n += 1
            cur = wl
            while cur > width:
                n += 1
                cur -= width
    return n


SENTENCES = {
    "New collection (decision 159)": "Exports the full text of each document, with your notes and footnotes.",
    "Full text as printed": "Exports the full text of each document, with footnotes and source notes.",
    "Full text with your annotations": "Exports the full text of each document, with headnotes, your notes, "
                                       "source notes, and highlights.",
    "Summaries": "Exports an AI summary of each document, with your notes and a word-cloud overview.",
    "Citations with your notes": "Exports a citation-only index, with your notes.",
    "Citations with source notes": "Exports a citation-only index, with source notes.",
    "Full text with everything": "Exports the full text of each document, with headnotes, your notes, footnotes, "
                                 "source notes, highlights, and a word-cloud overview.",
}
# width, visible height under the sheet's navigation bar (status, sheet gap, 56-pt bar; home indicator)
DEVICES = {"iPhone SE": (375, 667 - 20 - 10 - 56), "iPhone 17": (402, 874 - 62 - 10 - 56 - 34)}

for dev, (W, visible) in DEVICES.items():
    text_w = W - 64                    # 16 pt section inset and 16 pt cell padding, each side
    card_w = (text_w - 10) / 2 - 24     # LazyVGrid of two, 10 pt apart; 12 pt padding each side
    print(f"{dev} (width {W}, about {visible} pt under the bar)")
    for cat in ("L", "AX3", "AX5"):
        bsize, blead = STYLES["body"][cat]
        export_h = blead + 28 + 24        # the pinned button: its label, its padding, the dock's
        card = max(lines(l, card_w, bsize) for l in ("PDF", "HTML")) * blead + STYLES["caption"][cat][1] + 20
        room = visible - export_h
        verdicts = []
        for name, s in SENTENCES.items():
            sent = lines(s, text_w, STYLES["callout"][cat][0]) * STYLES["callout"][cat][1] + 22
            need = sent + 20 + card     # the sentence, a section gap, the first row of cards
            verdicts.append(f"{name}: {need:.0f}/{room:.0f} {'fits' if need <= room else 'NO'}")
        print(f"  {cat}: " + "; ".join(verdicts))
