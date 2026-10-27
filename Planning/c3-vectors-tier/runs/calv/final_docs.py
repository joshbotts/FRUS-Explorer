# final_docs.py: the argument set, grouped by finding, in date order within each finding. Exports F (findings) used by build_collection.py
F=[
("The rule the Department inherited: control, popular assent and obligations (1877-1900)",[
 ("frus1877","d222","1877-05-16"),("frus1878","d344","1878-03-23"),("frus1889","d43","1889-11-30"),("frus1895p1","d246","1895-11-06"),("frus1900","d530","1900-09-08")]),
("Wilson's break: constitutional legitimacy as a condition, and what it cost (1913-1923)",[
 ("frus1913","d7","1913-03-12"),("frus1913","d1028","1913-08-27"),("frus1913","d1064","1913-10-22"),("frus1915","d987","1915-09-18"),("frus1915","d1004","1915-10-19"),("frus1916","d258","1916-11-22"),
 ("frus1917","d379","1917-02-09"),("frus1919v01","d869","1919-08-19"),("frus1920v01","d377","1920-07-20"),("frus1920v01","d391","1920-09-27"),("frus1920v01","d399","1920-12-09"),
 ("frus1921v02","d344","1921-06-08"),("frus1923v02","d484","1923-08-22")]),
("A treaty exception in Central America, and the return to control (1923-1936)",[
 ("frus1923v02","d345","1923-06-30"),("frus1930v01","d375","1930-09-17"),("frus1932v05","d618","1932-01-13"),("frus1932v05","d641","1932-03-07"),("frus1933v05","d508","1933-11-28"),
 ("frus1934v05","d197","1934-01-03"),("frus1934v05","d103","1934-01-23"),("frus1934v05","d255","1934-01-25"),("frus1936v05","d109","1936-04-21")]),
("Recognition by consultation, and what the war added (1943-1945)",[
 ("frus1943v05","d334","1943-06-06"),("frus1943v05","d340","1943-06-09"),("frus1943v05","d486","1943-12-22"),("frus1944v07","d388","1944-01-10"),("frus1944v07","d219","1944-03-04"),
 ("frus1944v07","d231","1944-05-18"),("frus1944v07","d429","1944-05-23"),("frus1944v07","d437","1944-06-17"),("frus1945v09","d70","1945-02-09")]),
("From a weapon to a routine: relations without approval (1948-1959)",[
 ("frus1948v09","d7","1948-03-15"),("frus1948v09","d89","1948-11-08"),("frus1948v09","d115","1948-12-10"),("frus1948v09","d119","1948-12-16"),("frus1949v02","d457","1949-02-21"),
 ("frus1952-54v04","d490","1954-06-28"),("frus1958-60v06","d217","1959-01-07")]),
("The Alliance for Progress interval, and continuity again (1962-1979)",[
 ("frus1961-63v12","d421","1962-07-27"),("frus1961-63v12","d423","1962-07-30"),("frus1961-63v12","d427","1962-10-03"),("frus1961-63v10-12mSupp","d160","1963-10-04"),("frus1961-63v12","d363","1963-12-13"),
 ("frus1964-68v31","d206","1964-04-02"),("frus1964-68v31","d135","1966-06-29"),("frus1964-68v31","d141","1966-07-12"),("frus1964-68v31","d515","1968-10-11"),
 ("frus1969-76v21","d358","1973-09-17"),("frus1969-76v21","d360","1973-09-18"),("frus1977-80v24","d132","1978-07-22"),("frus1977-80v15","d276","1979-07-15")]),
]
ALL=[(v,d) for _,L in F for v,d,_ in L]
if __name__=="__main__":
    import sqlite3
    c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
    seen=set(); miss=0
    for v,d in ALL:
        r=c.execute("SELECT is_front_matter,is_editorial_note,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        if r is None or r[0] or r[1] or (v,d) in seen or v.endswith('Ed2'): print('PROBLEM',v,d,r); miss+=1
        seen.add((v,d))
    print(len(ALL),'documents;',len({v for v,d in ALL}),'volumes; problems',miss)
