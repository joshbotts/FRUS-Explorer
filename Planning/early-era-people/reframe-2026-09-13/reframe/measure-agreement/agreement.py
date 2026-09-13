#!/usr/bin/env python3
"""Shared definitions for the agreement-arm census (#234 reframe, label measure-agreement).

ONE implementation of the arm, used both by the corpus census (agreement_census.py) and by the gold
re-score (rescore_gold.py), so the census counts exactly what the gold scored.

The arm (feasibility assessment §2.2 / §4.b2; grains.py `editor+intersection_sweep_side`):
    editor marks  UNION  { filtered-sweep span that overlaps (>0 code points) at least one
                           filtered-control span in the same document }
with union = exact-duplicate (s, e, surface) removal (grains.py `union_exact`), so the stored strings
are the sweep's where the detectors agree.

Key: census.py's K2 (casefold, whitespace collapse, trailing possessive stripped, ONE leading honorific
from a fixed 29-token list stripped), imported from a verbatim copy of census.py.

Stdlib only. Read-only on every store.
"""
import bisect
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import census_orig_copy as census  # noqa: E402  verbatim copy (sha256 2b83c1f3...)


def k2_of(surface):
    return census.k2(census.k1(surface))


# ---------------------------------------------------------------- overlap arithmetic

def overlap_index(spans):
    """Sorted-by-start interval index over (s, e) spans; zero-length spans can overlap nothing."""
    iv = sorted((s, e) for s, e in spans if e > s)
    starts = [s for s, _ in iv]
    prefmax = []
    m = -1
    for _, e in iv:
        if e > m:
            m = e
        prefmax.append(m)
    return starts, prefmax


def overlaps_any(s, e, index):
    """True iff (s, e) overlaps >0 code points with some span in the index.

    Equivalent to grains.py `overlaps`: min(e1,e2) - max(s1,s2) > 0  <=>  s2 < e1 and e2 > s1, both non-empty.
    """
    if e <= s:
        return False
    starts, prefmax = index
    i = bisect.bisect_left(starts, e)      # every indexed span with start < e
    return i > 0 and prefmax[i - 1] > s


def split_detectors(fc_rows, fs_rows):
    """(int_fs, fs_only, int_fc, fc_only) as lists of raw rows (s, e, n) for ONE document."""
    fci = overlap_index([(r[0], r[1]) for r in fc_rows])
    fsi = overlap_index([(r[0], r[1]) for r in fs_rows])
    int_fs, fs_only, int_fc, fc_only = [], [], [], []
    for r in fs_rows:
        (int_fs if overlaps_any(r[0], r[1], fci) else fs_only).append(r)
    for r in fc_rows:
        (int_fc if overlaps_any(r[0], r[1], fsi) else fc_only).append(r)
    return int_fs, fs_only, int_fc, fc_only


def agreement_spans(e_rows, fc_rows, fs_rows):
    """The arm's distinct (s, e, n) spans for one document."""
    int_fs = split_detectors(fc_rows, fs_rows)[0]
    return set(e_rows) | set(int_fs)


# ---------------------------------------------------------------- regions in R-0 coordinates

TAG = re.compile(r"<[^>]+>")                                   # == harvest_embeddings.TAG
DOCSPLIT = re.compile(r'(?=<div\b[^>]*type="document")')       # == harvest_embeddings.DOCSPLIT
XMLID = re.compile(r'xml:id="([^"]+)"')                        # == harvest_embeddings.XMLID
DOCDATE = re.compile(r'frus:doc-dateTime-min="(\d{4})')        # == m1a_survey / measure_pocom DOCDATE
APPARATUS = ("opener", "closer", "dateline", "salute", "signed", "postscript", "byline")
# Matched against the START of a TAG match only. Scanning the body for region tags directly is wrong:
# an XML comment containing "<note" (frus1872p2v3/d7) is ONE TAG match to the R-0 extractor, and a
# free-standing scan cuts it in half and counts its prose as text (measured: +100 code points).
REGION_NAME = re.compile(r"<(/?)(head|note|" + "|".join(APPARATUS) + r")(?=[\s>/])")
REGIONS = ("head", "other_head", "note", "apparatus", "prose")


def _advance(out_len, raw):
    toks = TAG.sub(" ", raw).split()
    if toks:
        out_len += sum(map(len, toks)) + len(toks) - (0 if out_len else 1)
    return out_len


def document_regions(xml_text):
    """{doc_id: (r0_length, year_or_None, boundaries, states)} for every document div of one volume.

    Segmentation replicates harvest_embeddings.extract_documents (cut at the next <div or </body>).
    Offsets replicate its `" ".join(TAG.sub(" ", body).split())`: every tag is a space, so a token never
    spans a tag, and a region that opens at a tag starts at the next token's offset.

    Region of a code point, by precedence:
      note       inside any <note> (source notes, footnotes — including a footnote inside the heading)
      head       inside the FIRST <head> element of the document (the heading line: "Mr. Seward to Mr. Adams")
      other_head inside any LATER <head> (chiefly enclosure headings inside <frus:attachment>, table/list heads)
      apparatus  inside <opener>/<closer>/<dateline>/<salute>/<signed>/<postscript>/<byline>
      prose      everything else (<p>, <quote>, <list>, <table>, later <head>s ...)
    Documents with no text are skipped, as extract_documents skips them.
    """
    out = {}
    parts = DOCSPLIT.split(xml_text)[1:]
    for ordinal, segment in enumerate(parts):
        tag_end = segment.find(">")
        cut = len(segment)
        nxt = segment.find("<div", tag_end + 1)
        if nxt != -1:
            cut = min(cut, nxt)
        body_end = segment.find("</body>")
        if body_end != -1:
            cut = min(cut, body_end)
        did = XMLID.search(segment[:600])
        doc_id = did.group(1) if did else "ord%d" % ordinal
        ym = DOCDATE.search(segment[:600])
        year = int(ym.group(1)) if ym else None
        body = segment[:cut]
        out_len, prev = 0, 0
        bounds, states = [0], ["prose"]
        head_seen = in_head = False
        note_d = app_d = other_d = 0
        for m in TAG.finditer(body):
            tag = m.group(0)
            rm = REGION_NAME.match(tag)
            if not rm:
                continue
            out_len = _advance(out_len, body[prev:m.start()])
            prev = m.end()
            if tag.endswith("/>"):
                continue
            closing = rm.group(1) == "/"
            name = rm.group(2)
            if name == "head":
                if closing:
                    if in_head:
                        in_head = False
                    elif other_d:
                        other_d -= 1
                elif not head_seen:
                    head_seen = in_head = True
                else:
                    other_d += 1
            elif name == "note":
                note_d = max(0, note_d + (-1 if closing else 1))
            else:
                app_d = max(0, app_d + (-1 if closing else 1))
            state = ("note" if note_d else "head" if in_head else "other_head" if other_d
                     else "apparatus" if app_d else "prose")
            if state != states[-1]:
                nxt_off = out_len + (1 if out_len else 0)
                if bounds[-1] == nxt_off:
                    states[-1] = state
                else:
                    bounds.append(nxt_off)
                    states.append(state)
        out_len = _advance(out_len, body[prev:])
        if out_len == 0:
            continue
        if doc_id in out:
            raise SystemExit("duplicate document id %s" % doc_id)
        out[doc_id] = (out_len, year, bounds, states)
    return out


def region_of(s, regions_entry):
    _, _, bounds, states = regions_entry
    return states[bisect.bisect_right(bounds, s) - 1]
