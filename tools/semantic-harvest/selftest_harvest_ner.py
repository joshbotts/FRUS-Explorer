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
  * grounding: a name the model invents is counted `unlocated` and stored nowhere;
  * de-duplication of the same occurrence seen through two overlapping chunks;
  * resume (a completed volume is skipped) and byte-stable gzip across runs;
  * the refusal to start an unsampled LLM sweep over the whole scope.
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
    """Just enough of LM Studio: a model listing and a schema-abiding chat reply."""

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
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
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

    print("\n== pass 4: resume + provenance ==")
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
