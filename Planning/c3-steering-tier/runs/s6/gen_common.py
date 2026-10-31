import json, re
M=json.load(open("meta.json"))
QV={q["id"]:q for q in json.load(open("quotes_verified.json"))}
URL="https://history.state.gov/historicaldocuments/%s/%s"
def split(k): return k.split("/")
def cite(k):
    v,d=split(k); m=M[k]
    if v=="frus1894app2":
        mm=re.match(r"No\. (\d+)\. (.*?)\.?$",m["header"].strip())
        return "Foreign Relations of the United States, 1894, Appendix II, No. %s, %s (%s)"%(mm.group(1),mm.group(2),URL%(v,d))
    return "%s, Document %s (%s)"%(m["vol_title"],m["num"],URL%(v,d))
