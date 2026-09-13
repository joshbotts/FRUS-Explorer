p = 'candidates.py'; s = open(p).read()
def rep(old, new):
    global s
    assert old in s, old[:70]
    s = s.replace(old, new, 1)
rep('''                if m_ini:
                    ci = {k: v for k, v in cs.items() if not v[0] or m_ini in v[0]}''', '''                if m_ini:
                    initial_prefilter[band][src][bin_of(len(cs))] += 1
                    ci = {k: v for k, v in cs.items() if not v[0] or m_ini in v[0]}''')
rep('''            if m_ini:
                ci = {k: v for k, v in union.items() if not v[0] or m_ini in v[0]}''', '''            if m_ini:
                initial_prefilter[band]["union"][ub] += 1
                ci = {k: v for k, v in union.items() if not v[0] or m_ini in v[0]}''')
rep('''    namekey_bins = collections.defaultdict(collections.Counter)''', '''    namekey_bins = collections.defaultdict(collections.Counter)
    initial_prefilter = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
    rule = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))''')
rep('''        "surface_carries_given_initial_by_band"''', '''        "bins_before_given_initial_filter_same_rows": tab(initial_prefilter),
        "post_place_rule_by_band_and_pocom_class": {b: {k: dict(c) for k, c in v.items()} for b, v in sorted(rule.items())},
        "post_place_rule_definition": RULE_DEF,
        "surface_carries_given_initial_by_band"''')
rep('''                elif re.search(r"\\b(Mr|Mrs|Señor|Senor|Sir|Baron|Count|M|Messrs)\\.?\\s*$", before):''', '''                elif POST.search(" ".join(before.split()[-3:])) and not re.search(r"\\bto\\s*$|\\.\\s*$", before):
                    hs["fromto_mentions_in_head_prefix_title"] += 1
                    post_any = True
                elif re.match(r"(Mr|Mrs|Señor|Senor|Sir|Baron|Count|M|Messrs|Lord|Earl)\\.?\\s", t[r["s"]:r["e"]]):
                    hs["fromto_mentions_in_head_span_starts_with_honorific"] += 1
                elif re.search(r"\\b(Mr|Mrs|Señor|Senor|Sir|Baron|Count|M|Messrs)\\.?\\s*$", before):''')
rep('''        texts = None
        fromto_by_doc = collections.defaultdict(list)''', '''        texts = ner_store.volume_text(TEXT, vol)
        fromto_by_doc = collections.defaultdict(list)''')
rep('''            rec = (vol, r["d"], y, r["t"], raw, r["s"], r["e"], union)''', '''            if pclass in ("one", "several", "nobody"):
                tt = texts.get(r["d"])
                if tt is None:
                    rule[band][pclass]["no_text"] += 1
                else:
                    local = fold(" ".join(tt[max(0, r["s"] - 110):r["e"] + 70].split()))
                    hits = 0
                    for slug in pocom_by_surname.get(sur, ()):
                        live_ap = [ap for ap in appts[slug] if ap[0] - 1 <= y <= ap[1] + 1]
                        ok = False
                        for lo_, hi_, rl_, where_ in live_ap:
                            w = fold(where_)
                            alts = ALIASES.get(w, (w,))
                            if any(a and re.search(r"\\b" + re.escape(a) + r"\\b", local) for a in alts):
                                ok = True
                        hits += ok
                    rule[band][pclass]["resolves_one" if hits == 1 else "matches_several" if hits > 1 else "matches_none"] += 1
            rec = (vol, r["d"], y, r["t"], raw, r["s"], r["e"], union)''')
rep('''OFFICE_ONLY = re.compile''', '''ALIASES = {"united kingdom": ("united kingdom", "great britain", "england", "london"), "russia": ("russia", "soviet union", "moscow"),
           "holy see": ("holy see", "vatican"), "china": ("china", "peking", "peiping", "chungking", "nanking")}
RULE_DEF = ("local = R-0 text from 110 chars before the span to 70 after it, folded. For each POCOM officeholder of the surname "
            "in office in the doc year (+-1), a match if one of their in-office appointments' place (territory/org id, hyphens as spaces; "
            "aliases for united kingdom, russia, holy see, china) or principal-position title occurs as a whole word in local. "
            "resolves_one = exactly one in-office officeholder matches. For class 'one' this is agreement, not accuracy; "
            "for 'nobody' it is 0 by construction.")
OFFICE_ONLY = re.compile''')
rep('''"sample": "1,500 documents per band''', '''"note_prefix_title": NOTE_PREFIX, "sample": "1,500 documents per band''')
rep('''ALIASES = {''', '''NOTE_PREFIX = ("prefix_title = a post word among the 3 tokens before the span, not right after 'to' or a full stop "
               "(e.g. Minister Blanchard, President Wilson); counted in doc_head_names_a_fromto_with_post")
ALIASES = {''')
open(p, 'w').write(s)
print("patched")
