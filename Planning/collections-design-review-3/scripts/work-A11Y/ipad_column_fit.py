# A document's settings, and the drawn opening, in a 280-pt column (BrowseTwoPaneMetrics.researchRailWidth,
# the width the R6a rail is drawn at) against a wider sheet, at L, AX3 and AX5. Arithmetic only: greedy word
# wrap at half an em a character; 16 pt padding each side; text styles as fetched from the HIG today.
STYLES = {
    "body":     {"L": (17, 22), "AX3": (40, 48), "AX5": (53, 62)},
    "footnote": {"L": (13, 18), "AX3": (33, 40), "AX5": (44, 52)},
}
ROW_PAD = 22


def lines(text, width, size):
    per_char = 0.5 * size
    n, cur = 1, 0.0
    for w in text.split():
        wl = len(w) * per_char
        add = wl if cur == 0 else wl + per_char
        if cur + add <= width:
            cur += add
        else:
            n += 1
            cur = wl
            while cur > width:
                n += 1
                cur -= width
    return n


def h(text, style, cat, width):
    size, lead = STYLES[style][cat]
    return lines(text, width, size) * lead


# PartsPhone.dc.html's rows (the third form's board), name then value, stacked at the accessibility sizes.
ROWS = [("Body depth", "Follow the collection: Full"), ("Summary prompt", "Follow the collection: Brief summary"),
        ("Footnotes", "Follow the collection: On"), ("Archival source note", "Follow the collection: On"),
        ("Highlights in body", "On"), ("Research notes", "Follow the collection: On"),
        ("Headnote", "Follow the collection: Off"), ("See also", "Not set above: Off")]
OPENING = [("The Long Telegram", "body"), ("Moscow, 22 February 1946", "body"),
           ("Foreign Relations of the United States, 1946, Eastern Europe, The Soviet Union, Volume VI, eds. "
            "Rogers P. Churchill and William Slany (Washington, D.C.: Government Printing Office, 1969), "
            "Document 475.", "footnote"),
           ("As published: The Chargé in the Soviet Union (Kennan) to the Secretary of State", "body"),
           ("SECRET Moscow, February 22, 1946—9 p.m. [Received February 22—3:52 p.m.]", "body")]


def column(width, cat):
    w = width - 32
    rows = 0
    worst = 0
    for name, value in ROWS:
        if cat == "L":
            r = max(44, ROW_PAD + h(name + "   " + value, "body", cat, w))
        else:
            r = ROW_PAD + h(name, "body", cat, w) + h(value, "body", cat, w)
        worst = max(worst, r)
        rows += r
    opening = 24 + sum(h(t, s, cat, w) for t, s in OPENING)
    per_line = int(w // (0.5 * STYLES["body"][cat][0]))
    return per_line, worst, rows, opening


for label, width in (("280-pt column (R6a's rail)", 280), ("a 540-pt form sheet (from memory)", 540)):
    print(label)
    for cat in ("L", "AX3", "AX5"):
        per_line, worst, rows, opening = column(width, cat)
        print(f"  {cat:3}: ~{per_line} body characters a line; tallest picker row {worst:.0f} pt; "
              f"eight pickers {rows:.0f} pt; the drawn opening {opening:.0f} pt")
print("iPad Pro 13-inch is 1,032 pt tall in landscape and 1,376 in portrait (from memory).")
