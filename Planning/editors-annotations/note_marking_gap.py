#!/usr/bin/env python3
# The classification markings source notes print that the index does not store (2026-11-06).
# argv: <frus.db at index version 72> <manifest.json> <out.json>
# Opens the index read-only. Reads every stored source note (document_cache.source_note, rows
# outside front matter) twice:
#   parse()    a replica of SourceNoteParser.classificationMarking(fromSourceNote:) at v2
#              dcf178ed: the note split at `[.!?]\s+(?=[A-Z\[“"])`, sentence 2 alone, through the
#              parser's gates (at most 100 characters, no digit, a level first, every
#              semicolon-separated fragment capitalised, at most 4 words, no `.`, no remark verb).
#              Checked against the index: wherever the replica reads a marking, it must equal the
#              stored value (`replica`).
#   relaxed()  the same gates over every sentence after the first, and over a sentence's head
#              before a remark that opens with a digit. A note counts in the gap when the replica
#              reads nothing, the index stores nothing, and relaxed() reads a marking.
# The cause of each: the marking's sentence glued to a digit-led remark (sentence 2 itself), a
# volume or part number whose period split the citation ("Vol. I."), or another abbreviation's
# period ("U.S.", an initial, "Jan.").
import collections, json, re, sqlite3, sys

BOUND = re.compile(r'[.!?]\s+(?=[A-Z\[“"])')
LEVEL = re.compile(r'^(?:Top Secret|Secret|Confidential|Unclassified|Limited Official Use|'
                   r'Official Use Only|Restricted|No classification marking)\b')
VERB = re.compile(r'^(?:Drafted|Sent|Received|Repeated)\b')
ROMAN = re.compile(r'^[IVXLC]+\.$')
WS = ' \t              　'

def sentences(text):
    out, start = [], 0
    for m in BOUND.finditer(text):
        out.append(text[start:m.end()].strip()); start = m.end()
    if start < len(text): out.append(text[start:].strip())
    return out

def gate(c):
    while c.endswith('.'): c = c[:-1]
    c = c.strip(WS)
    if not c or len(c) > 100 or any(ch.isnumeric() for ch in c): return None
    frags = [f.strip(WS) for f in c.split(';')]
    if not frags[0] or not LEVEL.search(frags[0]): return None
    for f in frags:
        if (not f or not f[0].isupper() or len([w for w in f.split(' ') if w]) > 4 or '.' in f
                or VERB.search(f)):
            return None
    return '; '.join(frags)

def parse(note):
    s = sentences(note.strip())
    return gate(s[1]) if len(s) >= 2 else None

def relaxed(note):
    s = sentences(note.strip())
    for k in range(1, len(s)):
        for piece in re.split(r'(?<=\.)\s+(?=\d)', s[k]):
            g = gate(piece)
            if g: return g, k, s
    return None, None, s

def main():
    db_path, manifest, out = sys.argv[1:4]
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    vols = {v["volumeId"] for v in json.load(open(manifest))}
    agree = disagree = 0
    gap = collections.Counter(); cause = collections.Counter(); samples = []
    for vid, did, note, stored in db.execute("""
            SELECT d.volume_id, d.document_id, d.source_note, ds.classification FROM document_cache d
            LEFT JOIN document_sources ds ON ds.volume_id = d.volume_id AND ds.document_id = d.document_id
            WHERE d.is_front_matter = 0 AND d.source_note IS NOT NULL AND TRIM(d.source_note) <> ''
            ORDER BY d.volume_id, d.document_id"""):
        if vid not in vols: continue
        stored = (stored or "").strip() or None
        p = parse(note)
        if p is not None:
            if p == stored: agree += 1
            else: disagree += 1
            continue
        if stored is not None: continue
        marking, k, s = relaxed(note)
        if marking is None: continue
        gap[vid] += 1
        why = ("digit-led remark" if k == 1 else
               "volume or part number" if ROMAN.match(s[1]) else "another abbreviation")
        cause[why] += 1
        if len(samples) < 60 and gap[vid] == 1:
            samples.append(dict(volume=vid, document=did, marking=marking, cause=why,
                                note=re.sub(r"\s+", " ", note)[:240]))
    json.dump(dict(replica=dict(agree=agree, disagree=disagree), causes=cause, volumes=gap,
                   samples=samples), open(out, "w"), indent=0, sort_keys=True)
    print("replica agrees", agree, "disagrees", disagree, "| gap", sum(gap.values()), "in", len(gap),
          "volumes |", dict(cause))

if __name__ == "__main__":
    main()
