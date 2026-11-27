# Estimate where step 1's change line and step 2's ticks fall at L, AX3 and AX5 on two iPhones.
# Arithmetic only: greedy word wrap at half an em a character; layout constants from memory.
# Text styles (size/leading, pt) as fetched today from the HIG's Typography JSON:
STYLES = {
    "body":     {"L": (17, 22), "AX3": (40, 48), "AX5": (53, 62)},
    "callout":  {"L": (16, 21), "AX3": (38, 46), "AX5": (51, 60)},
    "footnote": {"L": (13, 18), "AX3": (33, 40), "AX5": (44, 52)},
    "caption":  {"L": (12, 16), "AX3": (32, 39), "AX5": (43, 51)},
}
# Widths from the UI runbook (iPhone 17 402 pt, SE 375 pt); heights 874 (runbook) and 667 (memory).
DEVICES = {"iPhone 17": (402, 874, 62, 83), "iPhone SE": (375, 667, 20, 49)}
NAV = 44          # inline navigation bar
SIDE = 36         # per side: section inset (20) + cell padding (16), from memory
ROW_PAD = 22      # a row's top + bottom padding
GAP = 20          # between sections


def lines(text, width, size):
    per_char = 0.5 * size
    words, n, cur = text.split(), 1, 0.0
    for w in words:
        wlen = len(w) * per_char
        add = wlen if cur == 0 else wlen + per_char
        if cur + add <= width:
            cur += add
        else:
            n += 1
            cur = wlen
            while cur > width:      # a word longer than a line breaks
                n += 1
                cur -= width
    return n


def h(text, style, size_cat, width):
    size, lead = STYLES[style][size_cat]
    return lines(text, width, size) * lead


def row(parts, size_cat, width, trailing=0):
    """A form row: stacked texts, each (text, style); trailing = room taken by a control."""
    return ROW_PAD + sum(h(t, s, size_cat, width - trailing) for t, s in parts)


def step1(size_cat, width):
    w = width - 2 * SIDE
    y = 0
    out = {}
    y += h("Step 1 of 2. How each document is presented.", "footnote", size_cat, w) + 8
    templates = [
        ("Full text as printed", "Footnotes and source notes"),
        ("Full text with your annotations", "Research notes, highlights, headnotes"),
        ("Summaries", "A summary of each, by Apple Intelligence"),
        ("Citations with your notes", "Each document as its citation"),
        ("Citations with source notes", "Each document as its citation"),
        ("Full text with everything", "Every option on"),
    ]
    out["first card top"] = y
    for name, sub in templates:
        y += row([(name, "body"), (sub, "footnote")], size_cat, w, trailing=32)
    y += GAP
    out["change line top"] = y
    y += row([("Full text as printed applied. 2 settings changed: Opening and Research notes.", "footnote"),
              ("Undo", "body")], size_cat, w)
    y += GAP
    out["settings top"] = y
    settings = [("Opening", "The volume's heading leads", None), ("Body depth", "Full", None),
                ("Summary prompt", "Brief summary", None), ("Footnotes", "On", "2 set their own"),
                ("Archival source note", "On", None), ("Research notes", "Off", None),
                ("Highlights in body", "Off", "1 sets its own"), ("Headnotes", "Off", None)]
    for name, value, own in settings:
        if size_cat == "L":
            parts = [(name + "   " + value, "body")] + ([(own, "footnote")] if own else [])
            y += max(44, row(parts, size_cat, w))
        else:
            parts = [(name, "body"), (value, "body")] + ([(own, "footnote")] if own else [])
            y += row(parts, size_cat, w)
    out["settings end"] = y
    y += GAP + row([("Next: Apparatus", "body")], size_cat, w)
    out["end"] = y
    return out


def step2(size_cat, width):
    w = width - 2 * SIDE
    y = 0
    out = {}
    y += h("Step 2 of 2. What is added around the documents.", "footnote", size_cat, w) + 8
    out["shortcuts top"] = y
    for s in ("Suggested for…", "All", "None"):     # stacked, the kindest case at these sizes
        y += row([(s, "body")], size_cat, w)
    y += GAP
    y += row([("Contents list", "body"), ("Citation", "body")], size_cat, w)
    y += row([("Word-cloud overview", "body")], size_cat, w, trailing=59)
    out["first tick top"] = y
    ticks = [("Chronology", "Opens the collection"), ("Bibliography", None), ("Sources & Archives", None),
             ("Persons Index", "No volume in this collection tags people."), ("Thematic Index", None),
             ("Note on the Text", "Has 3 things to say"),
             ("Abbreviations & Terms", None), ("Unprinted material cited", None),
             ("Documents cited, not included", "No volume in this collection cites a document by number.")]
    for name, note in ticks:
        parts = [(name, "body")] + ([(note, "footnote")] if note else [])
        y += row(parts, size_cat, w, trailing=32)
    out["last tick end"] = y
    y += h("A tick is a row in the outline. Ticking adds the block at its usual place; unticking removes it. "
           "Move it in the outline, as now.", "footnote", size_cat, w) + GAP
    for s in ("Append colophon page", "Stamp active project", "Append the query log"):
        y += row([(s, "body")], size_cat, w, trailing=59)
    out["end"] = y
    return out


for dev, (width, height, status, bottom) in DEVICES.items():
    visible = height - status - NAV - bottom
    print(f"{dev}: width {width}, visible about {visible} pt")
    for cat in ("L", "AX3", "AX5"):
        s1, s2 = step1(cat, width), step2(cat, width)
        print(f"  {cat:3}  step 1: change line at {s1['change line top']:5.0f}, settings {s1['settings top']:5.0f}"
              f"-{s1['settings end']:5.0f}, end {s1['end']:5.0f} ({s1['end'] / visible:.1f} screens)")
        print(f"       step 2: ticks {s2['first tick top']:5.0f}-{s2['last tick end']:5.0f},"
              f" end {s2['end']:5.0f} ({s2['end'] / visible:.1f} screens)")
