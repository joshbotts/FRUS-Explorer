"""Sustained-load probe: the bench's fixed 640 chunks, re-embedded pass after pass for
MINUTES, one JSON line per pass (elapsed seconds, pass seconds, chars/s)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, sys.argv[1])
import harvest_embeddings as h
url, model, minutes = sys.argv[2], sys.argv[3], float(sys.argv[4])
xml = open(os.path.expanduser("~/Development/frus/volumes/frus1948v06.xml"), encoding="utf-8", errors="replace").read()
chunks = []
for _, _, text in h.extract_documents(xml):
    for c0, c1 in h.chunk(text):
        chunks.append("title: none | text: " + text[c0:c1])
chunks = chunks[:640]
chars = sum(len(c) for c in chunks)
def post(batch):
    req = urllib.request.Request(url + "/v1/embeddings", data=json.dumps({"model": model, "input": batch}).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        r.read()
start = time.time(); n = 0
while time.time() - start < minutes * 60:
    t0 = time.time()
    for i in range(0, len(chunks), 64):
        post(chunks[i:i + 64])
    secs = time.time() - t0; n += 1
    print(json.dumps({"pass": n, "elapsed_s": round(time.time() - start), "secs": round(secs, 2), "chars_per_s": round(chars / secs)}), flush=True)
