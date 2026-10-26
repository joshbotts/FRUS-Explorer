# helper for run scripts: read-only connection to the index copy; every statement is appended to queries.log first
import sqlite3, os, re, sys, json, time
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
LOG = RUN + "/queries.log"

def connect():
    return sqlite3.connect("file:%s?mode=ro" % DB, uri=True)

def _lit(v):
    if v is None:
        return "NULL"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"

def render(sql, params=()):
    parts = sql.split("?")
    if len(parts) - 1 != len(params):
        return sql
    out = parts[0]
    for p, rest in zip(params, parts[1:]):
        out += _lit(p) + rest
    return out

def log_line(text):
    with open(LOG, "a") as f:
        f.write(text.rstrip("\n") + "\n")

def log_sql(sql, params=(), script=""):
    one = re.sub(r"\s+", " ", render(sql, params)).strip()
    esc = one.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
    log_line('sqlite3 -readonly %s "%s"  # run by %s' % (DB, esc, script))

def sql(conn, q, params=(), script="", log=True):
    if log:
        log_sql(q, params, script)
    return conn.execute(q, params).fetchall()

def collapse(s):
    return re.sub(r"\s+", " ", s or "").strip()
