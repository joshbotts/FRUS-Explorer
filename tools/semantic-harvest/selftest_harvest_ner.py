#!/usr/bin/env python3
"""End-to-end self-test for harvest_ner.py — fixtures plus a mock LM Studio server.

    SELFTEST=1 python3 harvest_ner.py

Runs anywhere python3 does (no corpus, no LM Studio, no pip). It is the same discipline
harvest_embeddings.py was handed over under: the harvest is verified against a mock
/v1/... server before it is trusted with hours of machine time. What it pins:

  * the R-0 parity guard (this pass's text == harvest_embeddings.extract_documents');
  * <persName> offsets surviving the tag-strip and whitespace collapse, including a
    nested tag inside a name and a name split across lines;
  * the scope rule (a volume defining persName xml:ids is NOT in scope);
  * the R-0 STORE check (TEXT_DIR): a matching stored layer passes, a corpus that has
    moved since the embeddings harvest aborts, a missing file aborts;
  * grounding: a name the model invents is counted `unlocated` and stored nowhere;
  * de-duplication of the same occurrence seen through two overlapping chunks;
  * resume (a completed volume is skipped) and byte-stable gzip across runs;
  * the refusal to start an unsampled LLM sweep over the whole scope;
  * ONLY_DOCUMENTS (both file shapes) restricting the detector to exactly the listed
    documents, exempt from the sweep refusal, with sampled_doc_ids recorded;
  * WORKERS>1 writing a byte-identical store — only the HTTP calls parallelize, and
    the fixture's overlapping chunks make ordering visible (an out-of-order merge
    flips which chunk's `ci` claims a de-duplicated row).
"""

import gzip
import hashlib
import json
import os
import shutil
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import harvest_ner as hn

# The model always claims these three. "Seward" is real but unmarked (the case M2 is
# for), "Ghost Person" is not in the text at all (the hallucination the store must not
# accept), and the two marked names test agreement with the editors' markup.
MOCK_MENTIONS = ["Hamilton Fish", "Mr. Bevin", "Seward", "Ghost Person"]

# The phrase that marks the one chunk the "poison" mock refuses to serve.
POISON = "well past the first chunk"

NO_LIST_VOLUME = """<?xml version="1.0"?>
<TEI><text><body>
<div type="document" xml:id="d1" frus:doc-dateTime-min="1872-03-04">
  <head>Despatch</head>
  <p><persName type="from">Hamilton
     Fish</persName> to <persName type="to">Mr. <hi rend="italic">Bevin</hi></persName>.</p>
  <p>Seward had already written on the subject, and Seward's view prevailed.</p>
</div>
<div type="document" xml:id="d2">
  <p>%s</p>
  <p>A later paragraph naming Hamilton Fish once more, well past the first chunk.</p>
</div>
<div type="index" xml:id="back">
  <p>Index: Fish, Hamilton, 1-40. This must never be read as a document.</p>
</div>
</body></text></TEI>
""" % ("Filler sentence about the negotiations. " * 12)

WITH_LIST_VOLUME = """<?xml version="1.0"?>
<TEI><text><body>
<div type="section" xml:id="correspondents">
  <list><item><persName xml:id="p_HF1">Hamilton Fish</persName>, Secretary of State.</item></list>
</div>
<div type="document" xml:id="d1">
  <p><persName type="from" corresp="#p_HF1">Hamilton Fish</persName> wrote.</p>
</div>
</body></text></TEI>
"""


class MockHandler(BaseHTTPRequestHandler):
    """Just enough of LM Studio: a model listing and a schema-abiding chat reply.

    `fail_mode` makes it misbehave the way the real server did on 2026-08-28, when it
    returned HTTP 400 to every in-flight request 27 volumes into the sweep: "always"
    fails everything (a dead server), "poison" fails only the chunks carrying POISON
    (one unservable chunk among healthy ones). "poison" keys on the REQUEST BODY rather
    than on a request counter: a counter-based flake is cured by the very next retry, so
    it never exhausts a retry schedule and never exercises the failure path at all.
    """

    fail_mode = None          # None | "always" | "poison"

    def log_message(self, *args):
        pass

    def _send(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._send({"data": [{"id": "mock-chat-model"}]})

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        # The warm-up is always served: a server that cannot answer it makes main() exit
        # before reaching the failure handling these modes exist to test.
        warmup = hn.WARMUP_PASSAGE.encode() in raw
        if not warmup and (MockHandler.fail_mode == "always" or (
                MockHandler.fail_mode == "poison" and POISON.encode() in raw)):
            self.send_error(400, "mock server failure")
            return
        self._send({
            "choices": [{"finish_reason": "stop",
                         "message": {"content": json.dumps({"mentions": MOCK_MENTIONS})}}],
            "usage": {"prompt_tokens": 100, "completion_tokens": 20},
        })


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_gz(path):
    with gzip.open(path, "rt", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


CHECKS = []


def check(label, condition, detail=""):
    CHECKS.append((label, bool(condition), detail))
    print("  %s %s%s" % ("ok  " if condition else "FAIL", label,
                         "" if condition or not detail else "  <- " + str(detail)))


def run():
    root = tempfile.mkdtemp(prefix="ner-selftest-")
    volumes_dir = os.path.join(root, "volumes")
    os.makedirs(volumes_dir)
    open(os.path.join(volumes_dir, "frusNOLIST.xml"), "w").write(NO_LIST_VOLUME)
    open(os.path.join(volumes_dir, "frusWITHLIST.xml"), "w").write(WITH_LIST_VOLUME)
    manifest = os.path.join(root, "manifest.json")
    json.dump([{"volumeId": "frusNOLIST", "sizeBytes": len(NO_LIST_VOLUME)},
               {"volumeId": "frusWITHLIST", "sizeBytes": len(WITH_LIST_VOLUME)}],
              open(manifest, "w"))
    out = os.path.join(root, "store")

    server = HTTPServer(("127.0.0.1", 0), MockHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    hn.VOLUMES_DIR = volumes_dir
    hn.MANIFEST = manifest
    hn.OUT = out
    hn.URL = "http://127.0.0.1:%d" % server.server_address[1]
    hn.he.CHUNK_CHARS = hn.CHUNK_CHARS = 200      # force several chunks on d2
    hn.he.OVERLAP_CHARS = hn.OVERLAP_CHARS = 60
    for key in ("VOLUMES", "SCOPE_ONLY", "FULL_SWEEP", "MODEL_FILE"):
        os.environ.pop(key, None)

    print("\n== pass 1: scope + marked layer (no model) ==")
    hn.DETECT = "none"
    hn.main()

    scope = json.load(open(os.path.join(out, "scope.json")))
    check("scope excludes the volume that defines persName ids",
          scope["volumes"] == ["frusNOLIST"], scope["volumes"])

    marked = read_gz(os.path.join(out, "marked", "frusNOLIST.jsonl.gz"))
    names = [row["n"] for row in marked]
    check("both marked names recovered", names == ["Hamilton Fish", "Mr. Bevin"], names)
    check("a name broken across lines collapses to one space", names[0] == "Hamilton Fish")
    check("a nested tag inside a name does not leak", names[1] == "Mr. Bevin")
    check("from/to types preserved", [r["t"] for r in marked] == ["from", "to"])
    check("no identity links in a no-list volume", all(r["c"] is None for r in marked))

    # The offsets must slice their own name back out of the R-0 text, which is the
    # entire contract between this store and anything that later reads it.
    docs = hn.documents_with_marks(open(os.path.join(volumes_dir, "frusNOLIST.xml")).read())
    text_by_doc = {d: t for d, _, t, _ in docs}
    check("every marked offset slices back to its name",
          all(text_by_doc[r["d"]][r["s"]:r["e"]] == r["n"] for r in marked))
    check("the back-of-book index is not a document",
          [d for d, _, _, _ in docs] == ["d1", "d2"], [d for d, _, _, _ in docs])
    check("R-0 parity holds (documents_with_marks == extract_documents)",
          [(d, o, t) for d, o, t, _ in docs]
          == hn.he.extract_documents(open(os.path.join(volumes_dir, "frusNOLIST.xml")).read()))

    head = json.load(open(os.path.join(out, "marked", "frusNOLIST.head.json")))
    check("head counts agree with the rows",
          (head["mentions"], head["typed_from"], head["typed_to"]) == (2, 1, 1), head)

    digest_before = sha256(os.path.join(out, "marked", "frusNOLIST.jsonl.gz"))

    print("\n== pass 2: the refusal ==")
    hn.DETECT = "llm"
    os.environ["MODEL"] = "mock-chat-model"
    try:
        hn.main()
        check("unsampled full-scope LLM sweep is refused", False, "it ran")
    except SystemExit as exit_code:
        check("unsampled full-scope LLM sweep is refused",
              "Refusing" in str(exit_code), exit_code)

    print("\n== pass 3: the detector, sampled ==")
    hn.SAMPLE_DOCS = 2
    hn.main()
    detected = read_gz(os.path.join(out, "detected", "frusNOLIST.jsonl.gz"))
    summary = json.load(open(os.path.join(out, "detected", "frusNOLIST.head.json")))
    surfaces = sorted({row["n"] for row in detected})
    check("only real substrings are stored",
          surfaces == ["Hamilton Fish", "Mr. Bevin", "Seward"], surfaces)
    check("the invented name is counted, not stored",
          summary["unlocated"] >= 1 and summary["unlocated_examples"][0]["n"] == "Ghost Person",
          summary["unlocated_examples"])
    check("every detected offset slices back to its surface",
          all(text_by_doc[r["d"]][r["s"]:r["e"]] == r["n"] for r in detected))
    check("occurrences seen through overlapping chunks are de-duplicated",
          len({(r["d"], r["s"], r["e"]) for r in detected}) == len(detected))
    check("both Seward occurrences are kept",
          sum(1 for r in detected if r["n"] == "Seward") == 2,
          [r for r in detected if r["n"] == "Seward"])
    check("agreement with the editors' markup is counted",
          summary["overlapping_marked"] == 2 and summary["novel"] == len(detected) - 2, summary)
    check("token usage recorded", summary["prompt_tokens"] > 0 and summary["chunks"] > 1, summary)
    check("rows are sorted by (ordinal, start)",
          detected == sorted(detected, key=lambda r: (r["o"], r["s"], r["e"])))

    print("\n== pass 3b: ONLY_DOCUMENTS — the targeted pass ==")
    only_manifest = os.path.join(root, "m2a-manifest.json")
    json.dump({"documents": [{"volume": "frusNOLIST", "document": "d2"}]},
              open(only_manifest, "w"))
    check("ONLY_DOCUMENTS reads the staged-manifest shape",
          hn.load_only_documents(only_manifest) == {"frusNOLIST": {"d2"}})
    gold = os.path.join(root, "gold.jsonl")
    open(gold, "w").write(json.dumps({"v": "frusNOLIST", "d": "d2",
                                      "s": 0, "e": 4, "n": "x"}) + "\n")
    check("ONLY_DOCUMENTS reads the ground-truth shape",
          hn.load_only_documents(gold) == {"frusNOLIST": {"d2"}})
    # The collector's annotated-document list has no span fields at all, and it is the file that
    # names a document with no mentions — the one a pass restricted by the span file cannot see.
    listing = os.path.join(root, "gold-documents.jsonl")
    open(listing, "w").write(json.dumps({"v": "frusNOLIST", "d": "d2", "band": "1861-1899",
                                         "mentions": 0, "mark": "none"}) + "\n")
    check("ONLY_DOCUMENTS reads the annotated-document list shape",
          hn.load_only_documents(listing) == {"frusNOLIST": {"d2"}})
    out2 = os.path.join(root, "store-only-docs")
    hn.OUT = out2
    hn.SAMPLE_DOCS = 0
    hn.ONLY_DOCUMENTS = only_manifest
    hn.ONLY_DOCS_BY_VOLUME = None
    hn.main()   # unsampled, no VOLUMES, no FULL_SWEEP: the restriction must exempt it
    check("a restricted unsampled run is exempt from the sweep refusal", True)
    head_only = json.load(open(os.path.join(out2, "detected", "frusNOLIST.head.json")))
    check("only the listed document is scanned, and it is recorded",
          head_only["docs_scanned"] == 1 and head_only["sampled_doc_ids"] == ["d2"],
          (head_only["docs_scanned"], head_only["sampled_doc_ids"]))
    only_rows = read_gz(os.path.join(out2, "detected", "frusNOLIST.jsonl.gz"))
    check("no rows from unlisted documents",
          only_rows and all(r["d"] == "d2" for r in only_rows),
          sorted({r["d"] for r in only_rows}))
    hn.ONLY_DOCUMENTS = ""
    hn.ONLY_DOCS_BY_VOLUME = None

    print("\n== pass 3c: WORKERS — concurrent requests, identical store ==")
    out3 = os.path.join(root, "store-workers")
    hn.OUT = out3
    hn.SAMPLE_DOCS = 2
    hn.WORKERS = 3
    hn.main()
    hn.WORKERS = 1
    check("a WORKERS>1 run writes a byte-identical detected layer",
          sha256(os.path.join(out3, "detected", "frusNOLIST.jsonl.gz"))
          == sha256(os.path.join(out, "detected", "frusNOLIST.jsonl.gz")))
    check("...and a byte-identical marked layer",
          sha256(os.path.join(out3, "marked", "frusNOLIST.jsonl.gz")) == digest_before)
    head_workers = json.load(open(os.path.join(out3, "detected", "frusNOLIST.head.json")))
    check("the width is recorded in the head", head_workers.get("workers") == 3,
          head_workers.get("workers"))
    hn.OUT = out

    print("\n== pass 3d: a chunk that never answers does not kill the run ==")
    saved_backoffs, saved_abort = hn.RETRY_BACKOFFS, hn.FAILURE_ABORT
    out4 = os.path.join(root, "store-chunk-failure")
    hn.OUT = out4
    hn.RETRY_BACKOFFS = [0]            # exhaust retries instantly
    hn.FAILURE_ABORT = 99              # well above what "alternate" can reach
    MockHandler.fail_mode = "poison"
    hn.main()                          # must COMPLETE, not raise
    MockHandler.fail_mode = None
    check("a run survives chunks that exhaust their retries", True)
    head_fail = json.load(open(os.path.join(out4, "detected", "frusNOLIST.head.json")))
    check("a failed chunk is counted in the head",
          head_fail.get("failed_chunks", 0) > 0, head_fail.get("failed_chunks"))
    check("...and the volume is NOT marked done, so a re-run redoes it",
          hn.layer_done("detected", "frusNOLIST") is False)
    check("the surviving chunks still produced rows",
          len(read_gz(os.path.join(out4, "detected", "frusNOLIST.jsonl.gz"))) > 0)

    print("\n== pass 3e: a dead server aborts instead of writing empty layers ==")
    out5 = os.path.join(root, "store-server-down")
    hn.OUT = out5
    hn.FAILURE_ABORT = 3
    MockHandler.fail_mode = "always"
    try:
        hn.main()
        check("a dead server aborts the run", False, "it reported success")
    except SystemExit as exit_code:
        check("a dead server aborts the run", exit_code.code == 1, exit_code.code)
    MockHandler.fail_mode = None
    check("the volume in flight is left unmarked",
          not os.path.exists(os.path.join(out5, "detected", "frusNOLIST.head.json")))
    manifest_down = json.load(open(os.path.join(out5, "run-manifest.json")))
    check("the abort is recorded in provenance",
          bool(manifest_down.get("aborted")), manifest_down.get("aborted"))
    hn.RETRY_BACKOFFS, hn.FAILURE_ABORT = saved_backoffs, saved_abort
    hn.OUT = out

    print("\n== pass 4: the R-0 store check ==")
    text_dir = os.path.join(root, "r0-text")
    os.makedirs(text_dir)
    with gzip.open(os.path.join(text_dir, "frusNOLIST.jsonl.gz"), "wt", encoding="utf-8") as layer:
        for doc_id, ordinal, text, _ in docs:
            layer.write(json.dumps({"d": doc_id, "o": ordinal, "t": text}) + "\n")
    hn.TEXT_DIR = text_dir
    hn.verify_against_r0("frusNOLIST", docs)          # exits on mismatch; returning IS the pass
    check("a matching R-0 layer verifies", True)

    moved = [(d, o, t + " (a sentence the embeddings harvest never saw)", m) for d, o, t, m in docs]
    try:
        hn.verify_against_r0("frusNOLIST", moved)
        check("a corpus that moved since the harvest aborts", False, "it passed")
    except SystemExit as exit_code:
        check("a corpus that moved since the harvest aborts",
              "R-0 STORE mismatch" in str(exit_code), exit_code)
    try:
        hn.verify_against_r0("frusABSENT", docs)
        check("a missing R-0 file aborts", False, "it passed")
    except SystemExit as exit_code:
        check("a missing R-0 file aborts", "is missing" in str(exit_code), exit_code)
    hn.TEXT_DIR = ""

    print("\n== pass 5: resume + provenance ==")
    hn.main()   # everything is done; must be a no-op
    check("gzip output is byte-stable across runs (mtime=0)",
          sha256(os.path.join(out, "marked", "frusNOLIST.jsonl.gz")) == digest_before)
    manifest_out = json.load(open(os.path.join(out, "run-manifest.json")))
    check("provenance pins both scripts",
          len(manifest_out["script_sha256"]) == 64 and len(manifest_out["extractor_sha256"]) == 64)
    check("provenance pins the prompt and decoding params",
          manifest_out["system_prompt"] == hn.SYSTEM_PROMPT
          and manifest_out["temperature"] == hn.TEMPERATURE)
    sums = open(os.path.join(out, "SHA256SUMS")).read().strip().splitlines()
    ok = all(line.split("  ")[0] == sha256(os.path.join(out, line.split("  ")[1]))
             for line in sums)
    check("SHA256SUMS covers the store and verifies", ok and len(sums) == 5, sums)

    server.shutdown()
    shutil.rmtree(root, ignore_errors=True)

    failed = [label for label, ok_, _ in CHECKS if not ok_]
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    if failed:
        print("FAILED: " + "; ".join(failed))
        sys.exit(1)
    print("SELFTEST PASSED")
