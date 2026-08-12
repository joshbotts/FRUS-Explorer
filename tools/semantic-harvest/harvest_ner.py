#!/usr/bin/env python3
"""Early-era person-mention harvest (#234 R-1) — the no-list volumes.

Two layers over the same single pass of each volume's TEI:

  * the MARKED layer — every <persName> the editors already delimit, placed in the
    R-0 text layer's coordinate space. Free, deterministic, no model, no server.
    This is M1b's input (measured: 253,919 mentions across the 268 no-list volumes).
  * the DETECTED layer — candidate mentions from an LM Studio chat model over the
    same text, grounded by exact-substring location. Optional (DETECT=llm), priced
    sample-first: see NER-RUNBOOK.md for why no full LLM sweep is scheduled.

Nothing here ships. Per Planning/M2-Semantic-Pipeline-Ride-Along.md §2, running the
pass to PRODUCE candidates is harvest; nothing derived from it enters an artifact
until the M2a prose ground truth exists and has scored it.

Stdlib only — no pip, no venv. Runs on the stock macOS python3, same as its sibling
harvest_embeddings.py, whose extraction this pass reuses rather than re-deriving.

    SCOPE_ONLY=1 python3 harvest_ner.py                  # derive + write scope.json
    python3 harvest_ner.py                               # the marked layer (free)
    DETECT=llm VOLUMES=frus1895p1 SAMPLE_DOCS=40 \
        MODEL="<id>" python3 harvest_ner.py              # the detector pilot
    SELFTEST=1 python3 harvest_ner.py                    # fixtures + mock server

Environment:
  VOLUMES_DIR    default ~/frus-volumes  (a copy of Development/frus/volumes)
  MANIFEST       default ./manifest.json (copy it next to this script)
  OUT_DIR        default ~/frus-ner-raw
  TEXT_DIR       optional ~/frus-semantic-raw/text — the R-0 layer the embeddings
                 harvest wrote. When set, every volume's extracted text is checked
                 against the stored layer character for character. Use it: it is what
                 makes a mention offset and a chunk span the same coordinate.
  VOLUMES        comma-separated volume ids (overrides the derived scope)
  SCOPE_ONLY     =1 writes scope.json and stops
  DETECT         none (default) | llm
  SAMPLE_DOCS    documents per volume for the detector, 0 = all (default 0)
  SEED           sampling seed, default 234 (m1a_survey.py's seed)
  FULL_SWEEP     =1 required to run DETECT=llm unsampled over the whole scope
  LMSTUDIO_URL   default http://localhost:1234
  MODEL          LM Studio chat model id — required for DETECT=llm, never auto-picked
  MODEL_FILE     optional path to the GGUF, to record its SHA-256 in provenance
  CHUNK_CHARS    default 3200 (~800 tokens), OVERLAP_CHARS default 480 (~15%)
  MAX_TOKENS     default 1024, TEMPERATURE default 0
  BATCH_SLEEP    optional seconds between requests (thermal headroom)

Design notes (why the store looks like this):
  * The text is NOT re-derived. Documents come from harvest_embeddings.extract_documents;
    this script's own segmentation exists only to carry <persName> offsets through the
    same tag-strip, and every volume ASSERTS its (doc_id, ordinal, text) list equals the
    imported extractor's. A volume that disagrees fails rather than writing a store whose
    offsets mean something slightly different from the embeddings' text layer — the
    cross-source-join failure class this repo keeps re-learning.
  * harvest_embeddings.py is imported, never edited: its SHA-256 is pinned in the
    semantic store's provenance, and a store already exists that was produced by it.
  * Detector output is located by EXACT SUBSTRING SEARCH over the chunk. A model that
    returns a name it paraphrased, normalised, or invented contributes an `unlocated`
    count and no mention. Offsets asked of the model directly would be fiction.
  * The model is asked for DISTINCT surface strings, not per-occurrence spans: it cuts
    output tokens by an order of magnitude, and every occurrence of a returned string is
    located. The cost is stated rather than hidden — a surface the model names once is
    found everywhere it occurs; a surface it omits is missed everywhere.
  * gzip members are written with mtime=0 so two runs over the same input produce
    byte-identical files (the V-0 spike found gzip mtime to be the only difference
    between five otherwise-identical text layers).
"""

import gzip
import io
import json
import os
import platform
import random
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import harvest_embeddings as he  # noqa: E402  (the R-0 extraction, imported not copied)

# ---------------------------------------------------------------- configuration

URL = os.environ.get("LMSTUDIO_URL", "http://localhost:1234").rstrip("/")
VOLUMES_DIR = os.path.expanduser(os.environ.get("VOLUMES_DIR", "~/frus-volumes"))
MANIFEST = os.environ.get("MANIFEST", os.path.join(os.path.dirname(__file__) or ".", "manifest.json"))
OUT = os.path.expanduser(os.environ.get("OUT_DIR", "~/frus-ner-raw"))
TEXT_DIR = os.path.expanduser(os.environ.get("TEXT_DIR", "")) if os.environ.get("TEXT_DIR") else ""
DETECT = os.environ.get("DETECT", "none").lower()
SAMPLE_DOCS = int(os.environ.get("SAMPLE_DOCS", "0"))
SEED = os.environ.get("SEED", "234")
CHUNK_CHARS = int(os.environ.get("CHUNK_CHARS", "3200"))
OVERLAP_CHARS = int(os.environ.get("OVERLAP_CHARS", "480"))
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", "1024"))
TEMPERATURE = float(os.environ.get("TEMPERATURE", "0"))
BATCH_SLEEP = float(os.environ.get("BATCH_SLEEP", "0"))

# he.chunk() reads these module globals; set them so the NER windows are the same
# shape as the embeddings' chunks and are recorded in provenance either way.
he.CHUNK_CHARS = CHUNK_CHARS
he.OVERLAP_CHARS = OVERLAP_CHARS

PERSNAME = re.compile(r"<persName\b([^>]*)>(.*?)</persName>", re.S)
PERSNAME_DEFINES = re.compile(r"<persName[^>]*xml:id=")
ATTR_TYPE = re.compile(r'\btype="([^"]*)"')
ATTR_XMLID = re.compile(r'\bxml:id="([^"]*)"')
ATTR_LINK = re.compile(r'\b(?:corresp|ref|sameAs)="([^"]*)"')

SYSTEM_PROMPT = (
    "You identify PERSON mentions in printed United States diplomatic correspondence "
    "from the 1860s to the 1950s (the Foreign Relations of the United States series). "
    "Return every distinct span of text in the passage that names an individual human "
    "being, copied VERBATIM and EXACTLY as printed, including any title or honorific "
    "attached to the name (\"Mr. Bevin\", \"Sir Edward Grey\", \"Count Bernstorff\"). "
    "Include a bare surname when it names a person (\"Marshall\"). "
    "Exclude countries, cities, ships, treaties, conferences, legations, departments, "
    "companies, and every other non-person name. Exclude a title with no name attached "
    "(\"the Secretary of State\"). Copy each string once, exactly as it appears in the "
    "passage — do not correct spelling, expand abbreviations, or translate. "
    "Answer with JSON only."
)

RESPONSE_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "person_mentions",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {"mentions": {"type": "array", "items": {"type": "string"}}},
            "required": ["mentions"],
            "additionalProperties": False,
        },
    },
}


# ---------------------------------------------------------------- extraction

def collapse_with_map(subbed):
    """`" ".join(subbed.split())` plus, per source index, its index in the result.

    Returns (collapsed_text, col_of) where col_of[i] is the collapsed-space index of
    subbed[i], or -1 when that character was whitespace the collapse removed.
    """
    col_of = [-1] * len(subbed)
    parts, length, i, n = [], 0, 0, len(subbed)
    while i < n:
        if subbed[i].isspace():
            i += 1
            continue
        j = i
        while j < n and not subbed[j].isspace():
            j += 1
        if parts:
            parts.append(" ")
            length += 1
        for k in range(i, j):
            col_of[k] = length + (k - i)
        parts.append(subbed[i:j])
        length += j - i
        i = j
    return "".join(parts), col_of


def strip_tags_with_map(segment):
    """Tag-strip one document segment, keeping a map back to source offsets.

    Mirrors harvest_embeddings' `" ".join(TAG.sub(" ", segment).split())` exactly —
    each tag becomes one space — and additionally records, for every tag, where its
    replacement space lands, which is what lets a <persName>'s inner content be
    located in the finished text.
    """
    pieces, out_len, pos = [], 0, 0
    tag_out = {}
    for match in he.TAG.finditer(segment):
        piece = segment[pos:match.start()]
        pieces.append(piece)
        out_len += len(piece)
        tag_out[match.start()] = out_len
        pieces.append(" ")
        out_len += 1
        pos = match.end()
    pieces.append(segment[pos:])
    subbed = "".join(pieces)
    text, col_of = collapse_with_map(subbed)
    return text, col_of, tag_out


def map_span(col_of, start, end):
    """A [start, end) span in tag-stripped space -> its span in collapsed space."""
    while start < end and col_of[start] == -1:
        start += 1
    if start >= end:
        return None
    last = end - 1
    while last >= start and col_of[last] == -1:
        last -= 1
    if last < start:
        return None
    return col_of[start], col_of[last] + 1


def documents_with_marks(xml_text):
    """[(doc_id, ordinal, text, marks)] — marks are the volume's <persName> spans.

    The segmentation replicates harvest_embeddings.extract_documents (that function
    returns text only, and its file is not edited because its SHA is pinned in the
    semantic store's provenance). `harvest_volume` asserts the two agree.
    """
    docs = []
    parts = he.DOCSPLIT.split(xml_text)[1:]
    for ordinal, segment in enumerate(parts):
        tag_end = segment.find(">")
        cut = len(segment)
        nxt = segment.find("<div", tag_end + 1)
        if nxt != -1:
            cut = min(cut, nxt)
        body_end = segment.find("</body>")
        if body_end != -1:
            cut = min(cut, body_end)
        did_match = he.XMLID.search(segment[:600])
        doc_id = did_match.group(1) if did_match else "ord%d" % ordinal
        body = segment[:cut]
        text, col_of, tag_out = strip_tags_with_map(body)
        if not text:
            continue
        marks = []
        for match in PERSNAME.finditer(body):
            # The inner content runs from just past the open tag's replacement space to
            # the close tag's, both of which strip_tags_with_map recorded.
            inner_end = match.span(2)[1]
            open_out = tag_out.get(match.start())
            close_out = tag_out.get(inner_end)
            if open_out is None or close_out is None:
                continue
            span = map_span(col_of, open_out + 1, close_out)
            if span is None:
                continue
            attrs = match.group(1)
            type_match = ATTR_TYPE.search(attrs)
            id_match = ATTR_XMLID.search(attrs)
            link_match = ATTR_LINK.search(attrs)
            marks.append({
                "d": doc_id, "o": ordinal, "s": span[0], "e": span[1],
                "n": text[span[0]:span[1]],
                "t": type_match.group(1) if type_match else None,
                "x": id_match.group(1) if id_match else None,
                "c": link_match.group(1) if link_match else None,
            })
        docs.append((doc_id, ordinal, text, marks))
    return docs


# ---------------------------------------------------------------- scope

def load_manifest():
    manifest = json.load(open(MANIFEST))
    return manifest["volumes"] if isinstance(manifest, dict) else manifest


def has_editor_list(xml_text):
    """A volume has an editor person list iff it DEFINES persName xml:ids.

    The same rule as Planning/early-era-people/m1a_survey.py, and deliberately not the
    app's parser rule: frus1873p1v1/p1v2 carry a real 57-entry list under
    xml:id="correspondents" that the app does not read. This scope counts what the TEI
    has (267 volumes), not what the app currently shows (268). M1a-Findings.md §
    "Reconciling two volume counts" is the whole of the difference.
    """
    return PERSNAME_DEFINES.search(xml_text) is None


def derive_scope(entries):
    scope, missing, with_list = [], [], []
    for entry in entries:
        vol = entry["volumeId"]
        path = os.path.join(VOLUMES_DIR, vol + ".xml")
        if not os.path.exists(path):
            missing.append(vol)
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        (scope if has_editor_list(text) else with_list).append(vol)
    return scope, with_list, missing


# ---------------------------------------------------------------- LM Studio client

def http_json(method, path, payload=None, timeout=900):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(URL + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read())


def pick_chat_model():
    """The chat model id, which must be stated and must be one the server lists.

    Never auto-picked. LM Studio routes an unknown id to whatever model is loaded, so
    a typo would harvest happily while writing a fictional model into provenance
    (measured 2026-08-10 on the embedding spike, which embedded a literal placeholder).
    """
    explicit = os.environ.get("MODEL", "")
    listing = http_json("GET", "/v1/models")
    ids = [m.get("id", "") for m in listing.get("data", [])]
    if not explicit:
        sys.exit("Set MODEL explicitly (chat model). Models the server reports:\n  "
                 + "\n  ".join(ids or ["(none)"]))
    if ids and explicit not in ids:
        sys.exit("MODEL %r is not among the ids the server reports:\n  %s\n"
                 "Copy the id exactly from the list above." % (explicit, "\n  ".join(ids)))
    return explicit, listing


def parse_mentions(content):
    """The model's reply -> [surface strings]. Tolerates a non-schema-abiding reply."""
    text = (content or "").strip()
    if not text:
        return [], "empty"
    try:
        payload = json.loads(text)
    except ValueError:
        start, end = text.find("{"), text.rfind("}")
        if start == -1 or end <= start:
            return [], "unparsable"
        try:
            payload = json.loads(text[start:end + 1])
        except ValueError:
            return [], "unparsable"
    if isinstance(payload, list):
        items = payload
    elif isinstance(payload, dict):
        items = payload.get("mentions", [])
    else:
        return [], "unparsable"
    out = []
    for item in items:
        if isinstance(item, str):
            out.append(item)
        elif isinstance(item, dict):
            for key in ("text", "name", "mention", "surface"):
                if isinstance(item.get(key), str):
                    out.append(item[key])
                    break
    return out, "ok"


def detect_chunk(model, passage):
    """One chunk -> ([surface strings], prompt_tokens, completion_tokens, status)."""
    payload = {
        "model": model,
        "messages": [{"role": "system", "content": SYSTEM_PROMPT},
                     {"role": "user", "content": passage}],
        "temperature": TEMPERATURE,
        "max_tokens": MAX_TOKENS,
        "response_format": RESPONSE_FORMAT,
    }
    delay = 5
    for attempt in range(4):
        try:
            response = http_json("POST", "/v1/chat/completions", payload)
            choice = response["choices"][0]
            content = choice.get("message", {}).get("content", "")
            usage = response.get("usage", {}) or {}
            names, status = parse_mentions(content)
            if choice.get("finish_reason") == "length":
                status = "truncated"
            return (names, int(usage.get("prompt_tokens", 0)),
                    int(usage.get("completion_tokens", 0)), status)
        except (urllib.error.URLError, KeyError, IndexError, ValueError, TimeoutError) as err:
            if attempt == 3:
                raise
            print("    retry after error: %s (waiting %ds)" % (err, delay))
            time.sleep(delay)
            delay *= 3


def locate(passage, offset, surface):
    """Every exact occurrence of `surface` in `passage`, as document-space spans."""
    spans, start = [], 0
    while True:
        found = passage.find(surface, start)
        if found == -1:
            return spans
        spans.append((offset + found, offset + found + len(surface)))
        start = found + 1


# ---------------------------------------------------------------- store

def write_jsonl_gz(path, rows):
    """Deterministic gzip: mtime=0, so re-running over the same input is byte-stable."""
    with open(path, "wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as zipped:
            with io.TextIOWrapper(zipped, encoding="utf-8") as out:
                for row in rows:
                    out.write(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n")


def verify_against_r0(vol, docs):
    """Check this volume's text against the embeddings store's R-0 layer, if given.

    The parity assert below catches a divergence in the CODE; this catches a divergence
    in the CORPUS. R-2 embeds a context window around each mention against chunk vectors
    that were computed from the stored text — if the TEI on disk has moved since that
    harvest, the offsets here address a document the vectors never saw, and nothing
    downstream could tell. An absent file is an error, not a skip: the whole value of
    the check is that it ran.
    """
    path = os.path.join(TEXT_DIR, vol + ".jsonl.gz")
    if not os.path.exists(path):
        sys.exit("TEXT_DIR is set but %s is missing. The R-0 layer must cover the scope, "
                 "or unset TEXT_DIR and accept an unverified extraction." % path)
    with gzip.open(path, "rt", encoding="utf-8") as handle:
        stored = [(row["d"], row["o"], row["t"])
                  for row in (json.loads(line) for line in handle if line.strip())]
    mine = [(d, o, t) for d, o, t, _ in docs]
    if mine == stored:
        return
    first = next((i for i, (a, b) in enumerate(zip(mine, stored)) if a != b), None)
    sys.exit("R-0 STORE mismatch on %s: %d documents here vs %d stored%s\n"
             "The corpus copy has moved since the embeddings harvest. Offsets from this "
             "run would not address the text those vectors were computed from."
             % (vol, len(mine), len(stored),
                "" if first is None else " (first difference at ordinal %d)" % first))


def layer_done(layer, vol):
    head = os.path.join(OUT, layer, vol + ".head.json")
    body = os.path.join(OUT, layer, vol + ".jsonl.gz")
    if not (os.path.exists(head) and os.path.exists(body)):
        return False
    try:
        json.load(open(head))
    except ValueError:
        return False
    return True


def sample_documents(vol, docs):
    """SAMPLE_DOCS documents, chosen deterministically from (SEED, volume id)."""
    if not SAMPLE_DOCS or SAMPLE_DOCS >= len(docs):
        return docs, False
    picker = random.Random("%s:%s" % (SEED, vol))
    return sorted(picker.sample(docs, SAMPLE_DOCS), key=lambda d: d[1]), True


def harvest_volume(vol, model, stats):
    path = os.path.join(VOLUMES_DIR, vol + ".xml")
    if not os.path.exists(path):
        print("  !! missing from VOLUMES_DIR, skipped: %s" % vol)
        stats["missing"].append(vol)
        return None
    started = time.time()
    xml_text = open(path, encoding="utf-8", errors="replace").read()
    docs = documents_with_marks(xml_text)

    # The parity guard: this pass must see exactly the documents and exactly the text
    # the embeddings' R-0 layer holds, or its offsets describe a different corpus.
    reference = he.extract_documents(xml_text)
    mine = [(d, o, t) for d, o, t, _ in docs]
    if mine != reference:
        first = next((i for i, (a, b) in enumerate(zip(mine, reference)) if a != b), None)
        sys.exit("R-0 parity FAILED on %s: %d docs here vs %d from harvest_embeddings"
                 "%s\nRefusing to write a store whose offsets mean something else."
                 % (vol, len(mine), len(reference),
                    "" if first is None else " (first difference at ordinal %d)" % first))
    if TEXT_DIR:
        verify_against_r0(vol, docs)

    chars = sum(len(t) for _, _, t, _ in docs)
    marked_rows = [mark for _, _, _, marks in docs for mark in marks]

    if not layer_done("marked", vol):
        write_jsonl_gz(os.path.join(OUT, "marked", vol + ".jsonl.gz"), marked_rows)
        typed = {"from": 0, "to": 0, "untyped": 0}
        for row in marked_rows:
            typed["from" if row["t"] == "from" else "to" if row["t"] == "to" else "untyped"] += 1
        json.dump({"volume": vol, "docs": len(docs), "chars": chars,
                   "mentions": len(marked_rows), "typed_from": typed["from"],
                   "typed_to": typed["to"], "untyped": typed["untyped"],
                   "linked": sum(1 for r in marked_rows if r["c"]),
                   "defines_ids": sum(1 for r in marked_rows if r["x"]),
                   "secs": round(time.time() - started, 1)},
                  open(os.path.join(OUT, "marked", vol + ".head.json"), "w"),
                  indent=1, sort_keys=True)
    stats["marked"] += len(marked_rows)
    stats["docs"] += len(docs)
    stats["chars"] += chars

    detected_summary = None
    if DETECT == "llm" and not layer_done("detected", vol):
        detected_summary = detect_volume(vol, docs, marked_rows, model, stats)

    secs = time.time() - started
    stats["secs"] += secs
    with open(os.path.join(OUT, "runs.jsonl"), "a") as out:
        out.write(json.dumps({"vol": vol, "docs": len(docs), "chars": chars,
                              "marked": len(marked_rows), "detected": detected_summary,
                              "secs": round(secs, 1),
                              "ts": time.strftime("%Y-%m-%dT%H:%M:%S")}) + "\n")
    return secs, chars, len(marked_rows), detected_summary


def detect_volume(vol, docs, marked_rows, model, stats):
    """The optional detector layer over one volume (or a deterministic sample of it)."""
    started = time.time()
    chosen, sampled = sample_documents(vol, docs)
    marked_by_doc = {}
    for row in marked_rows:
        marked_by_doc.setdefault(row["d"], []).append((row["s"], row["e"]))

    rows, unlocated_examples = [], []
    seen = set()
    counters = {"chunks": 0, "returned": 0, "located": 0, "unlocated": 0,
                "prompt_tokens": 0, "completion_tokens": 0,
                "truncated": 0, "unparsable": 0}
    for doc_id, ordinal, text, _ in chosen:
        for chunk_index, (c0, c1) in enumerate(he.chunk(text)):
            passage = text[c0:c1]
            names, prompt_tokens, completion_tokens, status = detect_chunk(model, passage)
            counters["chunks"] += 1
            counters["returned"] += len(names)
            counters["prompt_tokens"] += prompt_tokens
            counters["completion_tokens"] += completion_tokens
            if status in ("truncated", "unparsable", "empty"):
                counters["truncated" if status == "truncated" else "unparsable"] += 1
            for raw in names:
                surface = raw.strip()
                if len(surface) < 2:
                    continue
                spans = locate(passage, c0, surface)
                if not spans:
                    counters["unlocated"] += 1
                    if len(unlocated_examples) < 25:
                        unlocated_examples.append({"d": doc_id, "n": surface})
                    continue
                counters["located"] += 1
                for start, end in spans:
                    key = (doc_id, start, end)
                    if key in seen:
                        continue
                    seen.add(key)
                    rows.append({"d": doc_id, "o": ordinal, "s": start, "e": end,
                                 "n": text[start:end], "ci": chunk_index})
            if BATCH_SLEEP:
                time.sleep(BATCH_SLEEP)

    rows.sort(key=lambda r: (r["o"], r["s"], r["e"]))
    overlap = 0
    for row in rows:
        for mark_start, mark_end in marked_by_doc.get(row["d"], ()):
            if row["s"] < mark_end and mark_start < row["e"]:
                overlap += 1
                break
    write_jsonl_gz(os.path.join(OUT, "detected", vol + ".jsonl.gz"), rows)
    summary = {
        "volume": vol, "model": model, "sampled": sampled,
        "docs_scanned": len(chosen), "docs_in_volume": len(docs),
        # Which documents, not just how many: score_detections.py evaluates a detector
        # only over what it actually looked at, and a document it never saw would
        # otherwise count as a page of misses and depress recall by an arbitrary amount.
        # Recorded only for a sample — for a full volume the answer is "all of them".
        "sampled_doc_ids": sorted(d for d, _, _, _ in chosen) if sampled else None,
        "chars_scanned": sum(len(t) for _, _, t, _ in chosen),
        "mentions": len(rows), "overlapping_marked": overlap, "novel": len(rows) - overlap,
        "marked_in_scanned_docs": sum(1 for r in marked_rows
                                      if r["d"] in {d for d, _, _, _ in chosen}),
        "unlocated_examples": unlocated_examples,
        "secs": round(time.time() - started, 1),
        "temperature": TEMPERATURE, "max_tokens": MAX_TOKENS,
        "chunk_chars": CHUNK_CHARS, "overlap_chars": OVERLAP_CHARS,
    }
    summary.update(counters)
    json.dump(summary, open(os.path.join(OUT, "detected", vol + ".head.json"), "w"),
              indent=1, sort_keys=True)
    stats["detected"] += len(rows)
    stats["prompt_tokens"] += counters["prompt_tokens"]
    stats["completion_tokens"] += counters["completion_tokens"]
    return {k: summary[k] for k in ("chunks", "mentions", "novel", "unlocated",
                                    "prompt_tokens", "completion_tokens", "secs")}


# ---------------------------------------------------------------- provenance

def machine_description():
    try:
        model = subprocess.run(["sysctl", "-n", "hw.model"], capture_output=True,
                               text=True).stdout.strip()
        cpu = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                             capture_output=True, text=True).stdout.strip()
    except OSError:
        model, cpu = "", ""
    return {"node": platform.node(), "hw_model": model, "cpu": cpu,
            "arch": platform.machine(), "python": platform.python_version()}


def write_checksums():
    lines = []
    for sub in ("marked", "detected"):
        folder = os.path.join(OUT, sub)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            full = os.path.join(folder, name)
            lines.append("%s  %s/%s\n" % (he.sha256(full), sub, name))
    scope_path = os.path.join(OUT, "scope.json")
    if os.path.exists(scope_path):
        lines.append("%s  scope.json\n" % he.sha256(scope_path))
    with open(os.path.join(OUT, "SHA256SUMS"), "w") as out:
        out.writelines(lines)


# ---------------------------------------------------------------- main

def main():
    for sub in ("marked", "detected"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    entries = load_manifest()

    scope_path = os.path.join(OUT, "scope.json")
    if os.environ.get("VOLUMES"):
        volumes = [v.strip() for v in os.environ["VOLUMES"].split(",") if v.strip()]
        scope_note = "explicit VOLUMES"
    elif os.path.exists(scope_path) and not os.environ.get("SCOPE_ONLY"):
        scope = json.load(open(scope_path))
        volumes = scope["volumes"]
        scope_note = "scope.json (%s)" % scope["generated"]
    else:
        print("Deriving scope over %d manifest volumes..." % len(entries))
        volumes, with_list, missing = derive_scope(entries)
        json.dump({"generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
                   "rule": "no <persName xml:id=...> anywhere in the volume TEI "
                           "(m1a_survey.py's rule; 267 expected)",
                   "manifest_volumes": len(entries),
                   "volumes_without_editor_list": len(volumes),
                   "volumes_with_editor_list": len(with_list),
                   "volumes_missing_from_disk": missing,
                   "volumes": volumes},
                  open(scope_path, "w"), indent=1)
        print("scope: %d of %d volumes carry no editor person list (expected 267); "
              "%d with a list; %d missing from disk"
              % (len(volumes), len(entries), len(with_list), len(missing)))
        if len(volumes) != 267:
            print("  !! NOT 267 — the corpus or the rule has moved since M1a "
                  "(Planning/early-era-people/M1a-Findings.md). Investigate before harvesting.")
        scope_note = "derived"
        if os.environ.get("SCOPE_ONLY"):
            print("SCOPE_ONLY: wrote %s" % scope_path)
            return

    if DETECT == "llm" and not os.environ.get("VOLUMES") and not SAMPLE_DOCS \
            and not os.environ.get("FULL_SWEEP"):
        sys.exit("Refusing an unsampled LLM sweep over the whole scope: NER-RUNBOOK.md "
                 "prices it at days of continuous Studio time, and no ground truth exists "
                 "to score it. Set SAMPLE_DOCS=N (pilot) or FULL_SWEEP=1 (deliberate).")

    model, listing = None, None
    if DETECT == "llm":
        model, listing = pick_chat_model()
    model_file = os.environ.get("MODEL_FILE", "")
    if model_file and not os.path.exists(model_file):
        sys.exit("MODEL_FILE does not exist: %s" % model_file)

    todo = [v for v in volumes
            if not (layer_done("marked", v) and (DETECT != "llm" or layer_done("detected", v)))]
    print("scope %s | detect=%s | %d volume(s), %d to do -> %s"
          % (scope_note, DETECT, len(volumes), len(todo), OUT))

    stats = {"docs": 0, "chars": 0, "marked": 0, "detected": 0, "secs": 0.0,
             "prompt_tokens": 0, "completion_tokens": 0, "missing": []}
    for index, vol in enumerate(todo):
        result = harvest_volume(vol, model, stats)
        if result is None:
            continue
        secs, chars, marked, detected = result
        rate = stats["chars"] / stats["secs"] if stats["secs"] else 0
        extra = ""
        if detected:
            extra = ("  %5d detected (%d novel, %d unlocated)"
                     % (detected["mentions"], detected["novel"], detected["unlocated"]))
        print("[%d/%d] %-22s %6d marked  %6.1fs  %8.0f chars/s%s"
              % (index + 1, len(todo), vol, marked, secs, rate, extra))

    run_manifest = {
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "script_sha256": he.sha256(os.path.abspath(__file__)),
        "extractor_sha256": he.sha256(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                   "harvest_embeddings.py")),
        "machine": machine_description(),
        "r0_text_layer_verified_against": TEXT_DIR or "not verified (TEXT_DIR unset)",
        "detect": DETECT,
        "model": model, "models_listing": listing,
        "model_file_sha256": he.sha256(model_file) if model_file else "not captured",
        "temperature": TEMPERATURE, "max_tokens": MAX_TOKENS,
        "system_prompt": SYSTEM_PROMPT, "response_format": RESPONSE_FORMAT,
        "chunk_chars": CHUNK_CHARS, "overlap_chars": OVERLAP_CHARS,
        "sample_docs": SAMPLE_DOCS, "seed": SEED,
        "volumes_requested": len(volumes), "volumes_missing": stats["missing"],
        "totals_this_run": {"docs": stats["docs"], "chars": stats["chars"],
                            "marked": stats["marked"], "detected": stats["detected"],
                            "prompt_tokens": stats["prompt_tokens"],
                            "completion_tokens": stats["completion_tokens"],
                            "secs": round(stats["secs"], 1)},
    }
    json.dump(run_manifest, open(os.path.join(OUT, "run-manifest.json"), "w"),
              indent=2, sort_keys=True)
    write_checksums()
    print("\nDone. Store: %s\n  Verify after transfer with:  cd %s && shasum -a 256 -c SHA256SUMS"
          % (OUT, OUT))
    if stats["secs"]:
        print("This run: %d docs, %d marked mentions, %d detected, %.2f h"
              % (stats["docs"], stats["marked"], stats["detected"], stats["secs"] / 3600))
        if stats["prompt_tokens"]:
            tokens = stats["prompt_tokens"] + stats["completion_tokens"]
            print("Model: %d prompt + %d completion tokens, ~%.0f tok/s aggregate"
                  % (stats["prompt_tokens"], stats["completion_tokens"],
                     tokens / stats["secs"]))


if __name__ == "__main__":
    if os.environ.get("SELFTEST"):
        import selftest_harvest_ner
        selftest_harvest_ner.run()
    else:
        main()
