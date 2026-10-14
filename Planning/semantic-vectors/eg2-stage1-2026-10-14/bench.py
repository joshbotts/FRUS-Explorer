"""Fixed-input embedding throughput probe: the harvester's own extraction and chunking,
the first N chunks of one volume, posted in the harvester's batches of 64."""
import json, os, sys, time, urllib.request
sys.path.insert(0, sys.argv[1])  # tools/semantic-harvest
import harvest_embeddings as h

url, model, vol, n = sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
xml = open(os.path.expanduser("~/Development/frus/volumes/%s.xml" % vol), encoding="utf-8", errors="replace").read()
chunks = []
for _, _, text in h.extract_documents(xml):
    for c0, c1 in h.chunk(text):
        chunks.append("title: none | text: " + text[c0:c1])
chunks = chunks[:n]

def post(batch):
    req = urllib.request.Request(url + "/v1/embeddings", data=json.dumps({"model": model, "input": batch}).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.loads(r.read())

post(chunks[:8])  # warm-up: pipelines compile on first use
chars = sum(len(c) for c in chunks)
tokens = 0
t0 = time.time()
for i in range(0, len(chunks), 64):
    resp = post(chunks[i:i + 64])
    tokens += resp.get("usage", {}).get("prompt_tokens", 0)
secs = time.time() - t0
print(json.dumps({"model": model, "vol": vol, "chunks": len(chunks), "chars": chars, "tokens": tokens,
                  "secs": round(secs, 2), "chars_per_s": round(chars / secs), "tok_per_s": round(tokens / secs),
                  "chars_per_token": round(chars / tokens, 3) if tokens else None}))
