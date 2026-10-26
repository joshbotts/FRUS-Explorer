# Build work/scope.db: one row per document_cache row with the scope flags used throughout the run.
#  numbered      = document_number non-empty (chapter/container rows have none)
#  apparatus     = is_front_matter=1 OR is_editorial_note=1
#  ed2_dup       = volume is frus1951-54IranEd2 or frus1969-76ve15p2Ed2 (second editions whose first editions are present)
#  latam         = document sits in a hemisphere volume (whole volume) or in a Latin American section of any other volume
#  lat_basis     = 'hemisphere volume' | 'latam section' | ''
import re, sqlite3, os, sys, json
sys.path.insert(0, "/Users/jbotts/frus-analysis/c3/runs/r1/scripts")
import frus
RUN = frus.RUN
HEMI = """frus1932v05 frus1933v04 frus1933v05 frus1934v04 frus1934v05 frus1935v04 frus1936v05 frus1937v05 frus1938v05 frus1939v05
frus1940v05 frus1941v06 frus1941v07 frus1942v05 frus1942v06 frus1943v05 frus1943v06 frus1944v07 frus1945v09 frus1946v11 frus1947v08
frus1948v09 frus1952-54Guat frus1952-54v04 frus1955-57v06 frus1955-57v07 frus1958-60v05 frus1958-60v05mSupp frus1958-60v06
frus1961-63v10 frus1961-63v10-12mSupp frus1961-63v11 frus1961-63v12 frus1964-68v31 frus1964-68v32 frus1969-76v21 frus1969-76v22
frus1969-76ve10 frus1969-76ve11p1 frus1969-76ve11p2 frus1969-76ve16 frus1977-80v15 frus1977-80v23 frus1977-80v24 frus1977-80v29 frus1981-88v16""".split()
ED2 = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
LAT = r"^(?:[ivxl]+\.\s*[—–-]?\s*)?(?:argentina|argentine republic|bolivia|brazil|chile|chili|colombia|united states of colombia|costa rica|cuba|dominican republic|dominion republic|santo domingo|san domingo|ecuador|el salvador|salvador|guatemala|haiti|hayti|honduras|mexico|nicaragua|panama|paraguay|peru|uruguay|venezuela|central america|central american states|greater republic of central america|latin america|american republics|the american republics|western hemisphere|guyana|british guiana|british honduras|surinam|suriname|grenada|jamaica|trinidad|bahamas|barbados|belize|puerto rico|caribbean|south america|hispaniola|affairs at bluefields|mosquito territory|third international conference of american|international conference of american states|pan american|inter-american)\b"
latrx = re.compile(LAT, re.I)
paths = {}
for line in open(RUN + "/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    if v == "volume_id":
        continue
    paths.setdefault((v, d), p)
conn = frus.connect()
rows = frus.sql(conn, "SELECT c.volume_id, c.document_id, c.document_number, c.is_front_matter, c.is_editorial_note, length(c.body_text), d.date_iso FROM document_cache c LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id", script="scripts/build_scope.py")
out = RUN + "/work/scope.db"
if os.path.exists(out):
    os.remove(out)
s = sqlite3.connect(out)
s.execute("""CREATE TABLE scope_docs(volume_id TEXT, document_id TEXT, numbered INT, apparatus INT, ed2_dup INT, latam INT, lat_basis TEXT, section_path TEXT, body_len INT, date_iso TEXT, year INT, decade INT, PRIMARY KEY(volume_id, document_id))""")
hemi = set(HEMI)
batch = []
nlat = 0
for v, d, num, fm, en, ln, di in rows:
    p = paths.get((v, d), "")
    segs = [x.strip() for x in p.split(" > ")] if p else []
    if v in hemi:
        lat, basis = 1, "hemisphere volume"
    elif segs and any(latrx.search(x) for x in segs):
        lat, basis = 1, "latam section"
    else:
        lat, basis = 0, ""
    yr = int(di[:4]) if di and re.match(r"\d{4}", di) else None
    batch.append((v, d, 1 if (num or "") != "" else 0, 1 if (fm or en) else 0, 1 if v in ED2 else 0, lat, basis, p, ln, di, yr, (yr // 10) * 10 if yr else None))
    nlat += lat
s.executemany("INSERT INTO scope_docs VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", batch)
s.commit()
print("rows:", len(batch), "latam rows (incl. container/apparatus):", nlat)
for r in s.execute("SELECT lat_basis, COUNT(*), SUM(numbered=1 AND apparatus=0 AND ed2_dup=0) FROM scope_docs WHERE latam=1 GROUP BY 1"):
    print(r)
open(RUN + "/work/hemisphere_volumes.txt", "w").write("\n".join(HEMI) + "\n")
