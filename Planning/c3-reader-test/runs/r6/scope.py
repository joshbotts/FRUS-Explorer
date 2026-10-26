# Build the scope: rule 1 = editors' chapters whose title names U.S. recognition/nonrecognition of a
# Latin American government (rows chosen from raw/chapters_recogni.tsv); rule 2 = general policy chapters.
# Reads volume_structures.structure_json; joins document_cache (both keys) to drop front matter and editorial notes.
import sqlite3, json, re, csv
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
R1 = [  # (volume, regex on the section's own title, country)
("frus1895p1",r"^Recognition of de facto government","Ecuador"),
("frus1899",r"^Revolution in Venezuela and recognition","Venezuela"),
("frus1900",r"^Recognition of new Government of Colombia","Colombia"),
("frus1900",r"^Recognition of new Government$","Dominican Republic"),
("frus1903",r"^Revolution in Santo Domingo, and recognition","Dominican Republic"),
("frus1903",r"^Revolution in Honduras, and recognition","Honduras"),
("frus1904",r"^Recognition of the provisional government of the Dominican","Dominican Republic"),
("frus1907p2",r"^Recognition of the provisional Government of Honduras","Honduras"),
("frus1911",r"^Revolution in Haiti—Recognition","Haiti"),
("frus1911",r"^Political affairs—Revolution\. Organization of revolutionary government of Francisco","Mexico"),
("frus1911",r"^Political affairs: Recognition of Provisional President Estrada","Nicaragua"),
("frus1912",r"^Death of President Leconte and recognition","Haiti"),
("frus1912",r"^Political affairs: insurrection of February","Paraguay"),
("frus1913",r"^Recognition of President Plaza","Ecuador"),
("frus1914",r"^Political and financial affairs:—revolution, with Dominican aid","Haiti"),
("frus1914",r"^Political affairs: Revolution; resignation of President Billinghurst","Peru"),
("frus1915",r"^Political affairs; revolutionary movements; escape of President Theodore","Haiti"),
("frus1915",r"^Political affairs: Provincial presidencies of Gutierrez","Mexico"),
("frus1916",r"^Political affairs\. Revolutionary movements\. Resignation of President Jim","Dominican Republic"),
("frus1917",r"^Political affairs\. Revolution; overthrow of President Alfredo Gon","Costa Rica"),
("frus1919v01",r"^Surrender of power by the Tinocos","Costa Rica"),
("frus1919v02",r"^Arbitrary rule of President Bertrand","Honduras"),
("frus1919v02",r"^Presumptive election of Augusto B\. Legu","Peru"),
("frus1920v01",r"^Coup d’état by the Republican Party","Bolivia"),
("frus1920v01",r"^Recognition of the Government of Costa Rica","Costa Rica"),
("frus1920v02",r"^Revolutionary agitation against President Estrada Cabrera","Guatemala"),
("frus1920v03",r"^Question of the recognition of the Provisional Government by the United States$","Mexico"),
("frus1920v03",r"^Recognition of the Leguia government","Peru"),
("frus1921v01",r"^Recognition of the Saavedra Government","Bolivia"),
("frus1921v02",r"^Question of the recognition of the Government of General Obregon","Mexico"),
("frus1921v02",r"^Attitude of other governments toward recognition of the Obregon","Mexico"),
("frus1922v02",r"^Recognition of the Orellana government","Guatemala"),
("frus1922v02",r"^Question of the recognition of the government of General Obregon","Mexico"),
("frus1922v02",r"^Attitude of other governments toward recognition of the Obregon","Mexico"),
("frus1923v02",r"^Recognition of the Government of General Obreg","Mexico"),
("frus1925v02",r"^Withholding of recognition","Ecuador"),
("frus1928v02",r"^Extension by the United States of de jure recognition","Ecuador"),
("frus1931v02",r"^Recognition of constitutional government in Guatemala","Guatemala"),
("frus1932v05",r"^Refusal of the United States to recognize the Mart","El Salvador"),
("frus1933v05",r"^Refusal of the United States to recognize the Mart","El Salvador"),
("frus1934v05",r"^Recognition of the Provisional Government of Cuba","Cuba"),
("frus1934v05",r"^Recognition of the Mart","El Salvador"),
("frus1937v05",r"^Revolution in Bolivia; recognition","Bolivia"),
("frus1937v05",r"^Abrogation of Brazilian constitution","Brazil"),
("frus1937v05",r"^Forced resignation of President Paez","Ecuador"),
("frus1937v05",r"^Revolution in Paraguay; recognition","Paraguay"),
("frus1940v05",r"^Refusal of the United States to indicate whether","Cuba"),
("frus1943v05",r"^Discussions leading to the recognition","Argentina"),
("frus1943v05",r"^Non-recognition by the United States of the revolutionary regime","Bolivia"),
("frus1944v07",r"^Withholding of recognition from the regime of Edelmiro","Argentina"),
("frus1944v07",r"^Recognition by the United States and other American Republics of the revolutionary junta","Bolivia"),
("frus1944v07",r"^Recognition by the United States and the other American Republics of the new government of Ecuador","Ecuador"),
("frus1944v07",r"^Revolutions in El Salvador; policies","El Salvador"),
("frus1944v07",r"^Revolution in Guatemala and recognition","Guatemala"),
("frus1945v09",r"^Problems arising in connection with the recognition of the Farrell","Argentina"),
("frus1945v09",r"^Recognition by the United States and other American Republics of the government of Osm","El Salvador"),
("frus1945v09",r"^Consultation concerning and recognition of the Venezuelan","Venezuela"),
("frus1946v11",r"^Concern of the United States with respect to the violence accompanying the Bolivian","Bolivia"),
("frus1946v11",r"^United States recognition of the new Haitian","Haiti"),
("frus1947v08",r"^The question of recognizing the Mancheno","Ecuador"),
("frus1947v08",r"^Political upheaval in Nicaragua","Nicaragua"),
("frus1950v02",r"^Recognition by the United States of the military junta government of Haiti","Haiti"),
]
R2 = [
("frus1907p2",r"^Report of the Central American Peace Conference","Central America (policy)"),
("frus1923v01",r"^Agreements between the United States and Central American Republics","Central America (policy)"),
("frus1932v05",r"^Efforts of Costa Rica to effect the denunciation","Central America (policy)"),
("frus1936v05",r"^Decision of the Department of State that the United States should no longer be guided","Central America (policy)"),
("frus1948v09",r"^Continuance by the United States of diplomatic relations with new governments","American Republics (policy)"),
]
def alld(x):
    n=list(x.get("documentIds") or [])
    for c in x.get("subsections") or []: n+=alld(c)
    return n
out=[]; hit={}
for rule,lst in (("R1",R1),("R2",R2)):
    for v,rx,country in lst:
        j=json.loads(con.execute("select structure_json from volume_structures where volume_id=?",(v,)).fetchone()[0])
        found=[]
        def walk(s):
            for x in s:
                if re.search(rx,x.get("title") or ""): found.append(x)
                else: walk(x.get("subsections") or [])
        walk(j["sections"])
        hit[(v,rx)]=len(found)
        for f in found:
            for d in alld(f):
                out.append((v,d,rule,country,re.sub(r"\s+"," ",f["title"])[:120]))
seen=set(); rows=[]
for r in out:
    if (r[0],r[1]) in seen: continue
    seen.add((r[0],r[1]))
    q=con.execute("select dc.is_front_matter, dc.is_editorial_note, coalesce(substr(dd.date_iso,1,10),''), length(dc.body_text) from document_cache dc left join document_dates dd on dd.volume_id=dc.volume_id and dd.document_id=dc.document_id where dc.volume_id=? and dc.document_id=?",(r[0],r[1])).fetchone()
    if q is None: print("MISSING",r); continue
    rows.append(r+q)
miss=[k for k,n in hit.items() if n!=1]
print("sections not matched exactly once:",miss)
with open("scope.tsv","w") as f:
    w=csv.writer(f,delimiter="\t"); w.writerow(["volume_id","document_id","rule","country","chapter","is_front_matter","is_editorial_note","date","chars"])
    w.writerows(rows)
import collections
print("rows",len(rows),"FM",sum(r[5] for r in rows),"EN",sum(r[6] for r in rows))
kept=[r for r in rows if r[5]==0 and r[6]==0]
print("kept",len(kept),"volumes",len(set(r[0] for r in kept)),"chars",sum(r[8] for r in kept))
print(collections.Counter(r[2] for r in kept))
print("dated",sum(1 for r in kept if r[7]),"min",min(r[7] for r in kept if r[7]),"max",max(r[7] for r in kept if r[7]))
print(sorted(collections.Counter(r[3] for r in kept).items(), key=lambda x:-x[1]))
