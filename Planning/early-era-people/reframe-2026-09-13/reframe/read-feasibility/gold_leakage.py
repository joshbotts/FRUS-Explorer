#!/usr/bin/env python3
"""How much of the M2a gold's answer key is already written into files committed to the repository.
Counts gold documents named in committed files under the feasibility evidence folder, and the bracketed
context lines in the four committed error listings. Read-only (git ls-files only). Stdlib only."""
import json, os, subprocess
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
M = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gold_leakage.json")
gold = set()
for line in open(os.path.join(M, "m2a-ground-truth-documents.jsonl"), encoding="utf-8"):
    r = json.loads(line); gold.add("%s/%s" % (r["v"], r["d"]))
files = subprocess.run(["git", "-C", REPO, "ls-files", "Planning/early-era-people/feasibility-2026-09-12"],
                       capture_output=True, text=True, check=True).stdout.split()
named = {}; docs = set(); bracket_lines = {}
for f in files:
    try: s = open(os.path.join(REPO, f), encoding="utf-8", errors="ignore").read()
    except Exception: continue
    hit = {d for d in gold if d in s}
    if hit: named[f] = len(hit); docs |= hit
    if "/listing-" in f: bracket_lines[os.path.basename(f)] = s.count("⟦")
out = {"gold_documents": len(gold), "committed_files_scanned": len(files), "files_naming_a_gold_document": len(named),
       "gold_documents_named_in_committed_files": len(docs), "bracketed_context_snippets_in_listings": bracket_lines,
       "files": named}
json.dump(out, open(OUT, "w"), indent=1); print(json.dumps({k: v for k, v in out.items() if k != "files"}, indent=1))
