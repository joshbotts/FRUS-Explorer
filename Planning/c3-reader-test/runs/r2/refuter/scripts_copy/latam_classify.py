# Classify each mapped document as Latin American or not, from its chapter breadcrumb
# (out/doc_sections.tsv) and the volume title (out/manifest_volumes.tsv). Writes out/latam_docs.tsv.
# Rule (v3): walk the breadcrumb from its deepest heading upward. The first heading that names one of the
# twenty republics (period spellings included) assigns that country; a heading that names only a
# non-republic Caribbean/Canadian unit (Guyana, Jamaica, Bahamas, Eastern Caribbean, Suriname, Trinidad,
# Grenada, Barbados, Canada) excludes the document; a regional inter-American heading, or a
# Latin-America-only volume, assigns 'Regional'. Single-country volumes take the volume's country.
import csv, re
csv.field_size_limit(10**9)
COUNTRIES = [
 ("Argentina", r"argentin"), ("Bolivia", r"bolivi"), ("Brazil", r"brazil"), ("Chile", r"\bchile"),
 ("Colombia", r"colombi|new granada"), ("Costa Rica", r"costa rica"), ("Cuba", r"\bcuba"),
 ("Dominican Republic", r"dominican|santo domingo"), ("Ecuador", r"ecuador"),
 ("El Salvador", r"(?<!downfall of )\bsalvador\b(?! allende)|salvadoran"), ("Guatemala", r"guatemal"), ("Haiti", r"\bhait|\bhayti"),
 ("Honduras", r"hondura"), ("Mexico", r"mexic"), ("Nicaragua", r"nicaragu|mosquito|bluefields"),
 ("Panama", r"\bpanam[aá]\b|panamanian|canal zone"), ("Paraguay", r"paragu"), ("Peru", r"\bperu"),
 ("Uruguay", r"urugu"), ("Venezuela", r"venezuel"),
]
NONREPUBLIC = r"guyana|british guiana|jamaica|bahamas|eastern caribbean|suriname|trinidad|canada|canadian|grenada|barbados|newfoundland"
REGIONAL = r"central america|american republics|latin america|inter-american|pan american|american states|western hemisphere|caribbean|south america|soccer war|alliance for progress|cuban question|latin american security"
LATAM_VOL_TITLE = r"american republics|western hemisphere|latin america|central america|south america|caribbean|guatemala|\bcuba|chile|panama|mexico"
MIXED = {"frus1949v02", "frus1950v02", "frus1951v02"}
VOL_COUNTRY = {"frus1969-76v21":"Chile","frus1969-76ve16":"Chile","frus1952-54Guat":"Guatemala","frus1958-60v06":"Cuba",
  "frus1961-63v10":"Cuba","frus1961-63v11":"Cuba","frus1969-76v22":"Panama","frus1977-80v29":"Panama"}
vols = {}
with open("out/manifest_volumes.tsv") as f:
    for row in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        vols[row["volumeId"]] = row["title"]
def vol_is_latam(v):
    return v not in MIXED and re.search(LATAM_VOL_TITLE, vols.get(v, "").lower()) is not None
def classify(v, crumb):
    parts = [p.strip().lower() for p in crumb.split(" > ")]
    if parts and parts[0] in ("front matter", "back matter"): return None, None
    regional = False
    for comp in reversed(parts):
        hits = [name for name, pat in COUNTRIES if re.search(pat, comp)]
        if len(hits) == 1:
            return (VOL_COUNTRY.get(v, hits[0])), "heading-country"
        if len(hits) > 1:   # a heading naming several republics is regional (v4)
            regional = True
            continue
        if re.search(NONREPUBLIC, comp): return None, "excluded-nonrepublic"
        if re.search(REGIONAL, comp): regional = True
    if v in VOL_COUNTRY: return VOL_COUNTRY[v], "single-country-volume"
    if regional: return "Regional", "heading-regional"
    if vol_is_latam(v): return "Regional", "latam-volume"
    return None, None
n = 0; ex = 0
out = open("out/latam_docs.tsv", "w"); out.write("volume_id\tdocument_id\tcountry\tbasis\tbreadcrumb\n")
with open("out/doc_sections.tsv") as f:
    for row in csv.DictReader(f, delimiter="\t", quoting=csv.QUOTE_NONE):
        c, b = classify(row["volume_id"], row["breadcrumb"])
        if b == "excluded-nonrepublic": ex += 1
        if c:
            out.write(f"{row['volume_id']}\t{row['document_id']}\t{c}\t{b}\t{row['breadcrumb']}\n"); n += 1
out.close()
print("latam docs", n, "excluded non-republic", ex)
