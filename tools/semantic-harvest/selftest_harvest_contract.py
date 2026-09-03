#!/usr/bin/env python3
"""Self-test for harvest_embeddings.py's contract guard (release plan R-2 / W-1).

    python3 selftest_harvest_contract.py

Runs anywhere python3 does — no corpus, no LM Studio, no pip. What it pins:

  * contract_mismatch is exact on the five contract fields and ignores an uncaptured
    model_file_sha256 on either side;
  * a RESUME (>=1 completed volume) under a dropped PREFIX exits non-zero and names the
    field — driven through the real main(), not a copy of its logic;
  * the identical command line resumes;
  * a run-manifest.json in a directory with NO completed volume is not a resume and
    does not refuse;
  * ALLOW_CONTRACT_CHANGE=1 overrides;
  * every head.json written from now on carries prefix / chunk_chars / overlap_chars,
    so the packer can check the contract per volume — which it could not before.

The harvest is monkeypatched at exactly two seams: pick_model (no server) and
harvest_volume (no corpus, writes a head/bin/meta the way the real one does). Everything
between them — volume_done, the guard, the manifest write — is the shipped code.
"""

import json
import os
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("  ok   " if ok else "  FAIL ") + name + ("" if ok else "  -- " + str(detail)))


def fresh_module(env):
    """Import harvest_embeddings under a given environment (its config is module-level)."""
    for key in ("PREFIX", "CHUNK_CHARS", "OVERLAP_CHARS", "OUT_DIR", "MANIFEST", "VOLUMES",
                "MODEL", "MODEL_FILE", "ALLOW_CONTRACT_CHANGE", "VOLUMES_DIR"):
        os.environ.pop(key, None)
    os.environ.update(env)
    sys.modules.pop("harvest_embeddings", None)
    import harvest_embeddings as he
    return he


def write_completed_volume(out_dir, vol, model, dim=4, with_contract=None):
    """A completed volume exactly as harvest_volume leaves one: bin + meta + head, head last."""
    vectors = os.path.join(out_dir, "vectors")
    os.makedirs(vectors, exist_ok=True)
    os.makedirs(os.path.join(out_dir, "text"), exist_ok=True)
    with open(os.path.join(vectors, vol + ".bin"), "wb") as f:
        f.write(struct.pack("<%df" % dim, *([0.5] * dim)))
    with open(os.path.join(vectors, vol + ".meta.jsonl"), "w") as f:
        f.write(json.dumps({"d": "d1", "o": 0, "c0": 0, "c1": 10}) + "\n")
    head = {"volume": vol, "model": model, "dim": dim, "docs": 1, "chunks": 1,
            "chars": 10, "secs": 0.1}
    if with_contract:
        head.update(with_contract)
    json.dump(head, open(os.path.join(vectors, vol + ".head.json"), "w"))


def write_store_manifest(out_dir, **fields):
    base = {"model": "gemma", "model_file_sha256": "a" * 64, "dim": 4,
            "chunk_chars": 3200, "overlap_chars": 480, "prefix": "title: none | text: ",
            "generated": "x", "script_sha256": "y"}
    base.update(fields)
    json.dump(base, open(os.path.join(out_dir, "run-manifest.json"), "w"))


def drive_main(he, out_dir, volumes, model="gemma"):
    """Run the real main() with the two external seams patched. Returns (exit_code, output)."""
    manifest_path = os.path.join(out_dir, "manifest.json")
    json.dump([{"volumeId": v, "sizeBytes": 1000} for v in volumes], open(manifest_path, "w"))
    he.MANIFEST = manifest_path
    he.OUT = out_dir
    he.pick_model = lambda: (model, {"data": [{"id": model}]})

    def fake_harvest(vol, model_id, dim_holder, stats):
        dim_holder[0] = dim_holder[0] or 4
        # The real writer's shape, INCLUDING the contract keys this change adds.
        write_completed_volume(out_dir, vol, model_id, dim_holder[0],
                               with_contract={"prefix": he.PREFIX, "chunk_chars": he.CHUNK_CHARS,
                                              "overlap_chars": he.OVERLAP_CHARS})
        stats["docs"] += 1; stats["chunks"] += 1; stats["chars"] += 10; stats["secs"] += 0.1
        return (0.1, 10, 1)
    he.harvest_volume = fake_harvest
    he.write_checksums = lambda: os.path.join(out_dir, "SHA256SUMS")

    import io, contextlib
    buf = io.StringIO()
    code = 0
    with contextlib.redirect_stdout(buf):
        try:
            he.main()
        except SystemExit as e:
            code = e.code if isinstance(e.code, int) else 1
            buf.write(str(e.code))
    return code, buf.getvalue()


def main():
    print("contract_mismatch — the pure comparison")
    he = fresh_module({"PREFIX": "title: none | text: "})
    stored = {"model": "gemma", "model_file_sha256": "a" * 64, "prefix": "title: none | text: ",
              "chunk_chars": 3200, "overlap_chars": 480}
    same = he.contract_mismatch(stored, dict(stored))
    check("identical contracts have no diff", same == [])
    dropped = dict(stored); dropped["prefix"] = ""
    diffs = he.contract_mismatch(stored, dropped)
    check("a dropped prefix is named", [d[0] for d in diffs] == ["prefix"], diffs)
    chunk = dict(stored); chunk["chunk_chars"] = 1600
    check("a changed chunk size is named",
          [d[0] for d in he.contract_mismatch(stored, chunk)] == ["chunk_chars"])
    uncaptured = dict(stored); uncaptured["model_file_sha256"] = "not captured"
    check("an uncaptured GGUF hash on one side is not a mismatch",
          he.contract_mismatch(stored, uncaptured) == [])
    other_file = dict(stored); other_file["model_file_sha256"] = "b" * 64
    check("a DIFFERENT GGUF at the same path is a mismatch",
          [d[0] for d in he.contract_mismatch(stored, other_file)] == ["model_file_sha256"])

    print("the guard, through the real main()")
    # 1. A resume that forgot PREFIX — the plan's exact scenario — must exit non-zero.
    with tempfile.TemporaryDirectory() as out:
        he = fresh_module({"PREFIX": ""})            # forgot it
        write_store_manifest(out)                   # store says "title: none | text: "
        write_completed_volume(out, "frus1861", "gemma")
        code, text = drive_main(he, out, ["frus1861", "frus1862"])
        check("resume under a dropped PREFIX exits non-zero", code != 0, code)
        check("...and the refusal names 'prefix'", "prefix" in text, text[-300:])
        check("...and embeds nothing new",
              not os.path.exists(os.path.join(out, "vectors", "frus1862.head.json")))
        # The store's manifest is untouched — the refusal happens before the end-of-run write.
        check("...and leaves run-manifest.json unrewritten",
              json.load(open(os.path.join(out, "run-manifest.json")))["prefix"] == "title: none | text: ")

    # 2. The identical command line resumes and finishes.
    with tempfile.TemporaryDirectory() as out:
        he = fresh_module({"PREFIX": "title: none | text: "})
        write_store_manifest(out)
        write_completed_volume(out, "frus1861", "gemma")
        code, text = drive_main(he, out, ["frus1861", "frus1862"])
        check("identical contract resumes", code == 0, text[-300:])
        head = json.load(open(os.path.join(out, "vectors", "frus1862.head.json")))
        check("a new head.json carries the contract",
              head.get("prefix") == "title: none | text: " and head.get("chunk_chars") == 3200
              and head.get("overlap_chars") == 480, head)

    # 3. A stale manifest with NO completed volume is not a resume.
    with tempfile.TemporaryDirectory() as out:
        he = fresh_module({"PREFIX": ""})
        write_store_manifest(out)                   # says a different prefix
        code, text = drive_main(he, out, ["frus1861"])   # nothing completed yet
        check("no completed volume: a stale manifest does not refuse", code == 0, text[-300:])

    # 4. ALLOW_CONTRACT_CHANGE=1 proceeds, loudly.
    with tempfile.TemporaryDirectory() as out:
        he = fresh_module({"PREFIX": "", "ALLOW_CONTRACT_CHANGE": "1"})
        write_store_manifest(out)
        write_completed_volume(out, "frus1861", "gemma")
        code, text = drive_main(he, out, ["frus1861", "frus1862"])
        check("ALLOW_CONTRACT_CHANGE=1 overrides", code == 0, text[-300:])
        check("...and says so", "WARNING" in text and "prefix" in text)

    # 5. A changed MODEL is refused too (the guard is not prefix-only).
    with tempfile.TemporaryDirectory() as out:
        he = fresh_module({"PREFIX": "title: none | text: "})
        write_store_manifest(out)
        write_completed_volume(out, "frus1861", "gemma")
        code, text = drive_main(he, out, ["frus1861", "frus1862"], model="nomic")
        check("a different model on resume is refused", code != 0 and "model" in text, text[-200:])

    # 6. The REAL harvest_volume writes the contract into head.json. The scenarios above
    #    patch harvest_volume out (no corpus, no server), so they were testing the fake's head
    #    write, not the shipped one — a mutation that dropped the contract keys from the real
    #    writer survived them. Here only the network seam is patched.
    with tempfile.TemporaryDirectory() as out, tempfile.TemporaryDirectory() as vols:
        he = fresh_module({"PREFIX": "title: none | text: ", "CHUNK_CHARS": "40",
                           "OVERLAP_CHARS": "5"})
        he.OUT = out; he.VOLUMES_DIR = vols
        for sub in ("text", "vectors"):
            os.makedirs(os.path.join(out, sub), exist_ok=True)
        open(os.path.join(vols, "frus1861.xml"), "w").write(
            '<TEI><text><body><div type="document" xml:id="d1"><p>' + "word " * 30
            + '</p></div></body></text></TEI>')
        he.embed_batch = lambda model, texts: [[0.5, 0.25, 0.125, 0.0625] for _ in texts]
        dim_holder = [None]
        stats = {"docs": 0, "chunks": 0, "chars": 0, "secs": 0.0, "missing": []}
        result = he.harvest_volume("frus1861", "gemma", dim_holder, stats)
        head = json.load(open(os.path.join(out, "vectors", "frus1861.head.json")))
        check("the REAL harvest_volume embeds the fixture", result is not None and head["chunks"] >= 1, head)
        check("...and its head.json records the contract",
              head.get("prefix") == "title: none | text: " and head.get("chunk_chars") == 40
              and head.get("overlap_chars") == 5, head)

    # 7. MODEL_FILE is hashed at STARTUP and compared — the one check that can tell an
    #    operator they loaded a different GGUF at the same path. No scenario above set
    #    MODEL_FILE, so the real hashing in main() was never driven and a mutation that never
    #    hashed it survived.
    with tempfile.TemporaryDirectory() as out:
        gguf = os.path.join(out, "model.gguf")
        open(gguf, "wb").write(b"weights-v1")
        import hashlib
        real_sha = hashlib.sha256(b"weights-v1").hexdigest()
        # Store says the model was hashed as something ELSE.
        he = fresh_module({"PREFIX": "title: none | text: ", "MODEL_FILE": gguf})
        write_store_manifest(out, model_file_sha256="f" * 64)
        write_completed_volume(out, "frus1861", "gemma")
        code, text = drive_main(he, out, ["frus1861", "frus1862"])
        check("a different GGUF at the same path is refused on resume",
              code != 0 and "model_file_sha256" in text, text[-300:])
        # Store says the model was hashed as exactly this file: resumes.
        he = fresh_module({"PREFIX": "title: none | text: ", "MODEL_FILE": gguf})
        write_store_manifest(out, model_file_sha256=real_sha)
        code, text = drive_main(he, out, ["frus1861", "frus1862"])
        check("the same GGUF resumes", code == 0, text[-300:])
        check("...and the rewritten manifest records the real hash",
              json.load(open(os.path.join(out, "run-manifest.json")))["model_file_sha256"] == real_sha)

    failed = [n for n, ok in CHECKS if not ok]
    print("\n%d checks, %d failed" % (len(CHECKS), len(failed)))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
