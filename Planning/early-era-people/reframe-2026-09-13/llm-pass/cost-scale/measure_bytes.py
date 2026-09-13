#!/usr/bin/env python3
"""UTF-8 and JSON-escaped byte size of every scope document's R-0 text (for the 256 MB batch cap)."""
import sys, os, json
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import ner_store
vols = ner_store.scope_volumes(os.path.expanduser("~/frus-ner-raw"))
chars = utf8 = js = nonascii = 0
for v in vols:
    for d, t in ner_store.volume_text(os.path.expanduser("~/frus-semantic-raw/text"), v).items():
        chars += len(t); utf8 += len(t.encode()); js += len(json.dumps(t)); nonascii += sum(1 for c in t if ord(c) > 127)
r = {"chars": chars, "utf8_bytes": utf8, "json_ascii_escaped_bytes": js, "non_ascii_chars": nonascii}
json.dump(r, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "bytes.json"), "w"), indent=1); print(r)
