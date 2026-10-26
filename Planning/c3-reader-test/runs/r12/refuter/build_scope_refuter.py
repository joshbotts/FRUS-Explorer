# Builds scope.db (own file in run dir): documents under editor-chosen LatAm recognition/revolution chapters.
import sqlite3, json, re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
out=sqlite3.connect("/Users/jbotts/frus-analysis/c3/runs/r12/refuter/scope_rebuilt.db"); out.execute("drop table if exists scope")
out.execute("create table scope(volume_id,document_id,tier,chapter,primary key(volume_id,document_id))")
# (volume, regex on chapter-path, tier)
A=[
('frus1895p1','Ecuador.*Recognition of de facto'),
('frus1899','Venezuela.*Revolution in Venezuela and recognition'),
('frus1900','Colombia.*Recognition of new Government'),('frus1900','Dominican Republic.*Recognition of new Government'),
('frus1903','Dominican Republic.*recognition of new Government'),('frus1903','Revolution in Honduras, and recognition'),
('frus1904','Recognition of the provisional government of the Dominican'),
('frus1907p2','Recognition of the provisional Government of Honduras'),
('frus1911','Haiti.*Recognition by the United States of the Leconte'),('frus1911','Nicaragua.*Recognition of Provisional President Estrada'),
('frus1912','Haiti.*recognition by the United States of President Auguste'),('frus1912','Paraguay.*Political affairs'),
('frus1913','Ecuador.*Recognition of President Plaza'),('frus1913','Mexico.*Political affairs: assassination of President Madero'),('frus1913','Peru.*Arrest, imprisonment'),
('frus1914','Haiti.*Political and financial affairs:—revolution, with Dominican'),('frus1914','Peru.*Political affairs: Revolution'),
('frus1916','Dominican Republic.*refusal of recognition'),
('frus1917','Costa Rica.*Refusal of the United States to recognize'),
('frus1919v01','Surrender of power by the Tinocos'),('frus1919v02','Overthrow of President Pardo'),
('frus1920v01','Coup d’état by the Republican Party'),('frus1920v01','Costa Rica.*Recognition of the Government'),
('frus1920v03','Mexico.*Question of the recognition of the Provisional'),('frus1920v03','Peru.*Recognition of the Leguia'),
('frus1921v01','Bolivia.*Recognition of the Saavedra'),('frus1921v02','Guatemala.*Overthrow of President Herrera'),
('frus1921v02','Mexico.*Question of the recognition of the Government of General Obregon'),
('frus1922v02','Guatemala.*Recognition of the Orellana'),('frus1922v02','Mexico.*Question of the recognition of the government'),
('frus1923v02','Mexico.*Recognition of the Government of General Obreg'),
('frus1925v02','Ecuador.*Withholding of recognition'),('frus1928v02','Ecuador.*de jure recognition'),
('frus1931v02','Guatemala.*Recognition of constitutional government'),
('frus1932v05','El Salvador.*Refusal of the United States to recognize'),('frus1933v05','El Salvador.*Refusal of the United States to recognize'),
('frus1934v05','Cuba.*Recognition of the Provisional Government of Cuba'),('frus1934v05','El Salvador.*Recognition of the Martínez'),
('frus1936v05','General.*Decision of the Department of State that the United States should no longer'),
('frus1937v05','Bolivia.*recognition of the Busch'),('frus1937v05','Brazil.*Abrogation of Brazilian constitution'),
('frus1937v05','Ecuador.*recognition of the Enriquez'),('frus1937v05','Paraguay.*recognition of the Paiva'),
('frus1940v05','Cuba.*Refusal of the United States to indicate'),
('frus1943v05','Argentina.*recognition of the Government of General Pedro'),('frus1943v05','Bolivia.*Non-recognition'),
('frus1944v07','Argentina.*Withholding of recognition'),('frus1944v07','Bolivia.*Recognition by the United States'),
('frus1944v07','Ecuador.*Recognition by the United States'),('frus1944v07','El Salvador.*Revolutions in El Salvador'),
('frus1944v07','Guatemala.*Revolution in Guatemala and recognition'),
('frus1945v09','Argentina.*recognition of the Farrell'),('frus1945v09','El Salvador.*Recognition by the United States'),
('frus1945v09','Venezuela.*Consultation concerning and recognition'),
('frus1946v11','Bolivia.*problem of recognition'),('frus1946v11','Haiti.*recognition of the new Haitian'),
('frus1947v08','Ecuador.*question of recognizing'),('frus1947v08','Nicaragua.*nonrecognition'),
('frus1948v09','Multilateral Relations.*Bogota Resolution'),
('frus1950v02','Haiti.*Recognition by the United States of the military junta'),
]
B=[
('frus1930v01','Argentina.*Revolution in Argentina'),('frus1930v01','Bolivia.*Revolution in Bolivia'),('frus1930v01','Brazil.*Revolution in Brazil'),
('frus1930v03','Peru.*Revolution in Peru'),('frus1930v03','Guatemala.*Revolution in Guatemala'),
('frus1931v01','Chile.*Revolution in Chile'),('frus1931v02','El Salvador.*Revolution in El Salvador'),('frus1931v02','Panama.*Revolution in Panama'),('frus1931v02','Peru.*Revolution in Peru'),
('frus1933v05','Cuba.*Revolution in Cuba'),
('frus1935v04','Ecuador.*Revolution in Ecuador'),('frus1936v05','Bolivia.*Revolution in Bolivia'),('frus1936v05','Paraguay.*Revolution in Paraguay'),
('frus1947v08','Venezuela.*revolutionary activity'),
('frus1917','Costa Rica.*Political affairs'),('frus1918','Costa Rica.*Political affairs'),
]
def docs(s):
    r=list(s.get('documentIds',[]))
    for x in s.get('subsections',[]): r+=docs(x)
    return r
n=0
for tier,lst in (('A',A),('B',B)):
  for vid,pat in lst:
    sj=db.execute("select structure_json from volume_structures where volume_id=?",(vid,)).fetchone()[0]
    j=json.loads(sj); found=[]
    def walk(secs,path):
        for s in secs:
            t=re.sub(r'\s+',' ',s.get('title') or ''); p=path+[t]
            full=' > '.join(p)
            if re.search(pat,full,re.I) and not found_cover(full): 
                found.append((full,docs(s)))
            else: walk(s.get('subsections',[]),p)
    def found_cover(full): return False
    walk(j['sections'],[])
    if not found: print("NO MATCH",vid,pat)
    for full,ds in found:
        for d in ds:
            out.execute("insert or ignore into scope values(?,?,?,?)",(vid,d,tier,full[-120:])); n+=1
out.commit()
print("rows",out.execute("select count(*) from scope").fetchone())
