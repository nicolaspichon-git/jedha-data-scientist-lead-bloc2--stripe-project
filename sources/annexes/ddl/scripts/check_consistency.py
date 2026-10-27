#!/usr/bin/env python3
"""Vérifie la cohérence DBML <-> base PostgreSQL chargée avec 01_schema.sql.
Compare : tables, colonnes, types, nullabilité, clés primaires, ENSEMBLE des clés étrangères (simples et composites).
Usage : check_consistency.py stripe-oltp-v32.dbml   (variables PG* pour la connexion)"""
import re, subprocess, sys

dbml = open(sys.argv[1], encoding="utf-8").read().splitlines()
DB = sys.argv[2] if len(sys.argv) > 2 else "stripe_test"


def psql(q):
    out = subprocess.run(["psql", "-d", DB, "-AtF", "|", "-c", q], capture_output=True, text=True, check=True).stdout
    return [l.split("|") for l in out.splitlines() if l]


# ---------------------------------------------------------------- parse DBML
tables, pks, refs = {}, {}, {}
dbml_fk = set()   # (table, cols, table_cible, cols_cible)
cur, mode = None, None
for line in dbml:
    m = re.match(r"^Table (\w+) ", line)
    if m:
        cur, mode = m.group(1).lower(), "cols"
        tables[cur], pks[cur] = {}, []
        continue
    if cur is None:
        m = re.match(r"^Ref (\w+): (\w+)\.\(([^)]*)\) [>\-<]\??\s?(\w+)\.\(([^)]*)\)", line)
        if m:
            refs[m.group(1)] = (m.group(2).lower(), [c.strip() for c in m.group(3).split(",")])
        m = re.match(r"^Ref \w*:?\s*(\w+)\.\(?([\w, ]+)\)?\s*([>\-<])\??\s*(\w+)\.\(?([\w, ]+)\)?", line)
        if m:
            a = (m.group(1).lower(), tuple(x.strip() for x in m.group(2).split(",")))
            b = (m.group(4).lower(), tuple(x.strip() for x in m.group(5).split(",")))
            src, dst = (b, a) if m.group(3) == "<" else (a, b)
            dbml_fk.add((src[0], src[1], dst[0], dst[1]))
        continue
    if line == "}":
        cur = None
        continue
    if mode == "note3":
        if line.strip() == "'''":
            mode = "cols_after"
        continue
    if re.match(r"^  Indexes \{", line):
        mode = "idx"
        continue
    if mode == "idx":
        if line.startswith("  }"):
            mode = "cols_after"
            continue
        m = re.match(r"^\s+\(([^)]*)\)\s*\[([^\]]*)\]", line)
        if m and re.search(r"\bpk\b", m.group(2)):
            pks[cur] = [c.strip() for c in m.group(1).split(",")]
        continue
    if re.match(r"^  Note: '''", line):
        mode = "note3"
        continue
    if re.match(r"^  Note:", line):
        continue
    if mode == "cols":
        m = re.match(r"^  (\w+) ([\w(),]+)(?: \[(.*)\])?\s*$", line)
        if m:
            name, typ, attrs = m.group(1), m.group(2), m.group(3) or ""
            nullable = not (re.search(r"\bnot null\b", attrs) or re.search(r"\bpk\b", attrs))
            tables[cur][name] = (typ, nullable)
            mr = re.search(r"ref:\s*([>\-<])\??\s*(\w+)\.(\w+)", attrs)
            if mr:
                if mr.group(1) == "<":
                    dbml_fk.add((mr.group(2).lower(), (mr.group(3),), cur, (name,)))
                else:
                    dbml_fk.add((cur, (name,), mr.group(2).lower(), (mr.group(3),)))
            if re.search(r"(^|[\[ ,])pk([\],]|$)", attrs) and not attrs.startswith("note"):
                pks[cur] = [name]

TYPEMAP = {"decimal": "numeric", "varchar": "character varying", "char": "character", "timestamptz": "timestamp with time zone",
           "timestamp": "timestamp without time zone", "int": "integer", "bool": "boolean"}


def norm(t):
    m = re.match(r"(\w+)(\(.*\))?$", t)
    base, par = m.group(1), m.group(2) or ""
    return TYPEMAP.get(base, base), par.replace(" ", "")


# ---------------------------------------------------------------- catalogue
cols = {}
for t, c, dt, ml, np_, ns, nul in psql(
    "select table_name,column_name,data_type,coalesce(character_maximum_length::text,''),coalesce(numeric_precision::text,''),"
    "coalesce(numeric_scale::text,''),is_nullable from information_schema.columns where table_schema='public' order by 1,ordinal_position"):
    cols.setdefault(t, {})[c] = (dt, ml, np_, ns, nul == "YES")
db_pk = {}
for t, c in psql("select tc.table_name, string_agg(kcu.column_name, ',' order by kcu.ordinal_position) from information_schema.table_constraints tc "
                 "join information_schema.key_column_usage kcu using (constraint_name, table_schema, table_name) "
                 "where tc.table_schema='public' and tc.constraint_type='PRIMARY KEY' group by 1, tc.constraint_name"):
    db_pk[t] = c.split(",")
db_fk = {n: t for n, t in psql("select conname, conrelid::regclass::text from pg_constraint where contype='f' and conparentid=0 and connamespace='public'::regnamespace")}

db_fk_all = set()
for t, d in psql("select conrelid::regclass::text, pg_get_constraintdef(oid) from pg_constraint where contype='f' and conparentid=0 and connamespace='public'::regnamespace"):
    m = re.match(r"FOREIGN KEY \(([^)]*)\) REFERENCES (\w+)\(([^)]*)\)", d)
    db_fk_all.add((t.lower().strip('"'), tuple(x.strip() for x in m.group(1).split(",")), m.group(2).lower(), tuple(x.strip() for x in m.group(3).split(","))))

errors = []
dbtables = {t for t in cols if not re.search(r"_(default|\d{4}_\d{2})$", t) and not t.startswith("v_")}
if set(tables) != dbtables:
    errors.append(f"tables DBML only: {sorted(set(tables) - dbtables)} ; DB only: {sorted(dbtables - set(tables))}")
for t, cs in tables.items():
    if t not in cols:
        continue
    if set(cs) != set(cols[t]):
        errors.append(f"{t}: colonnes DBML only {sorted(set(cs) - set(cols[t]))} ; DB only {sorted(set(cols[t]) - set(cs))}")
    for c, (typ, nullable) in cs.items():
        if c not in cols[t]:
            continue
        dt, ml, np_, ns, dbnull = cols[t][c]
        base, par = norm(typ)
        if base != dt:
            errors.append(f"{t}.{c}: type DBML {typ} != DB {dt}")
        elif base == "character varying" and par != f"({ml})":
            errors.append(f"{t}.{c}: longueur DBML {par} != DB ({ml})")
        elif base == "numeric" and par != f"({np_},{ns})":
            errors.append(f"{t}.{c}: précision DBML {par} != DB ({np_},{ns})")
        if nullable != dbnull:
            errors.append(f"{t}.{c}: nullable DBML {nullable} != DB {dbnull}")
    if pks.get(t) != db_pk.get(t):
        errors.append(f"{t}: PK DBML {pks.get(t)} != DB {db_pk.get(t)}")
for n, (t, _) in refs.items():
    if n not in db_fk:
        errors.append(f"FK composite {n} absente de la base")
    elif db_fk[n].lower() != t:
        errors.append(f"FK {n}: table {db_fk[n]} != {t}")

for f in sorted(dbml_fk - db_fk_all):
    errors.append(f"FK dans le DBML, absente de la base : {f[0]}{list(f[1])} -> {f[2]}{list(f[3])}")
for f in sorted(db_fk_all - dbml_fk):
    errors.append(f"FK dans la base, absente du DBML : {f[0]}{list(f[1])} -> {f[2]}{list(f[3])}")
print(f"{len(dbml_fk)} FK DBML, {len(db_fk_all)} FK base comparées")
print(f"{len(tables)} tables DBML, {len(dbtables)} tables DB, {len(refs)} FK composites nommées vérifiées")
if errors:
    print("ÉCARTS :")
    [print(" -", e) for e in errors]
    sys.exit(1)
print("COHÉRENT")
