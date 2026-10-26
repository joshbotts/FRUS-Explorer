# Build the scope set S2 = A1 U (R2 n LA). (Same as 09_build_scope.py with the tight family R2 in place of R.)
# R2 = out/hits_R2.tsv, MATCH expression in scripts/R2_expr.txt (52 quoted phrases), non-apparatus, LA universe, Ed2 dropped.
#  A1 = every non-apparatus document under one of the editors' headings listed below (each names the recognition,
#       non-recognition, withholding of recognition, or continuance of relations with a Latin American government,
#       or the policy that governed it), read from volume_structures.structure_json;
#  R2 = out/hits_R2.tsv (08_fts_family.py with the MATCH expression in scripts/R2_expr.txt).
# SQL run: SELECT volume_id, structure_json FROM volume_structures WHERE volume_id = ?;
#          SELECT is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?;
import json, sqlite3, collections
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
A1 = [("frus1895p1","ch41"),("frus1899","ch123"),("frus1900","ch33"),("frus1900","ch36"),("frus1903","ch45"),
      ("frus1903","ch71"),("frus1904","ch55"),("frus1907p2","ch5"),("frus1911","ch69"),("frus1912","ch58"),
      ("frus1913","ch47"),("frus1914","ch124"),("frus1917","ch21"),("frus1919v01","ch37subch2"),("frus1919v02","ch69subch1"),
      ("frus1920v01","ch21subch1"),("frus1920v01","ch39"),("frus1920v03","ch9"),("frus1920v03","ch23"),("frus1921v01","ch15"),
      ("frus1921v02","ch38"),("frus1921v02","ch39"),("frus1922v02","ch32"),("frus1922v02","ch50"),("frus1922v02","ch51"),
      ("frus1923v02","ch37"),("frus1925v02","ch7"),("frus1928v02","ch53"),("frus1931v02","ch31"),("frus1932v05","ch6"),
      ("frus1932v05","ch14"),("frus1933v05","ch15"),("frus1934v05","ch5"),("frus1934v05","ch13"),("frus1936v05","ch5"),
      ("frus1937v05","ch14"),("frus1937v05","ch17"),("frus1937v05","ch28"),("frus1937v05","ch43"),("frus1940v05","ch37"),
      ("frus1943v05","ch11"),("frus1943v05","ch18"),("frus1944v07","ch13"),("frus1944v07","ch18"),("frus1944v07","ch56"),
      ("frus1944v07","ch60"),("frus1944v07","ch62"),("frus1945v09","ch13"),("frus1945v09","ch57"),("frus1945v09","ch99"),
      ("frus1946v11","ch13"),("frus1946v11","ch52"),("frus1947v08","ch43"),("frus1947v08","ch63"),("frus1948v09","ch5"),
      ("frus1950v02","ch21subch1")]
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
meta = {}
for line in open(R + "out/doc_paths.tsv"):
    v, d, fm, ed, di, la, p, isdoc = line.rstrip("\n").split("\t")
    meta[(v, d)] = (fm, ed, di, la, p, isdoc)
def find(secs, sid):
    for s in secs:
        if s.get("sectionId") == sid:
            return s
        r = find(s.get("subsections") or [], sid)
        if r: return r
def alldocs(sec):
    out = list(sec.get("documentIds") or [])
    for s in sec.get("subsections") or []:
        out += alldocs(s)
    return out
a1 = {}
for v, sid in A1:
    sj = con.execute("SELECT structure_json FROM volume_structures WHERE volume_id=?", (v,)).fetchone()[0]
    sec = find(json.loads(sj)["sections"], sid)
    title = " ".join((sec.get("title") or "").split())
    kept = 0
    for d in alldocs(sec):
        m = meta.get((v, d))
        if m and m[0] == "0" and m[1] == "0" and m[5] == "1":
            a1[(v, d)] = (v + "/" + sid, title); kept += 1
    print("A1 chapter %s/%s kept %d: %s" % (v, sid, kept, title[:110]))
rh = {}
for line in open(R + "out/hits_R2.tsv"):
    v, d, di, p = line.rstrip("\n").split("\t")
    rh[(v, d)] = 1
S = sorted(set(a1) | set(rh))
with open(R + "out/scope_S2.tsv", "w") as f:
    for k in S:
        fm, ed, di, la, p, isdoc = meta[k]
        f.write("\t".join([k[0], k[1], di, "A1" if k in a1 else "", "R2" if k in rh else "", a1[k][0] if k in a1 else "", p]) + "\n")
print("A1 documents:", len(a1), " R2 n LA:", len(rh), " A1 n R2:", len(set(a1) & set(rh)), " S2 = A1 u R2:", len(S))
dec = collections.Counter(); deca1 = collections.Counter()
for k in S:
    di = meta[k][2]
    dec[(di[:3] + "0s") if di else "undated"] += 1
for k in a1:
    di = meta[k][2]
    deca1[(di[:3] + "0s") if di else "undated"] += 1
print("decade\tS\tA1")
for k in sorted(dec): print("%s\t%d\t%d" % (k, dec[k], deca1[k]))
