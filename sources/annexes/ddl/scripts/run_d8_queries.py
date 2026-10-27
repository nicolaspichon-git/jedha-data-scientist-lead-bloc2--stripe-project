#!/usr/bin/env python3
"""Exécute les requêtes SQL de D8.1 sur la base de test (stripe_perf), relève lignes, durée et plan.
Usage : run_d8_queries.py d8-vNN.md [--report VERIFICATION-D8.1.md]
Chaque requête est exécutée dans une transaction annulée (ROLLBACK) : aucune donnée n'est modifiée."""
import re, subprocess, sys, json, uuid

md, report = sys.argv[1], None
if "--report" in sys.argv:
    report = sys.argv[sys.argv.index("--report") + 1]
DB = "stripe_perf"


def psql(sql, tuples=True):
    args = ["psql", "-d", DB, "-X", "-q", "-v", "ON_ERROR_STOP=1"]
    if tuples:
        args += ["-At"]
    r = subprocess.run(args, input=sql, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


# ------------------------------------------------------------ paramètres issus des données
_, out, _ = psql("""
WITH top_m AS (SELECT merchant_id FROM Transaction GROUP BY 1 ORDER BY count(*) DESC LIMIT 1),
     top_c AS (SELECT customer_id, merchant_id FROM Transaction WHERE merchant_id = (SELECT merchant_id FROM top_m)
               GROUP BY 1,2 ORDER BY count(*) DESC LIMIT 1),
     one_t AS (SELECT transaction_id, created_at FROM Transaction WHERE merchant_id = (SELECT merchant_id FROM top_m)
               AND status_code = 'successful' ORDER BY created_at DESC LIMIT 1 OFFSET 1000)
SELECT json_build_object(
  'merchant_id', (SELECT merchant_id FROM top_m),
  'customer_id', (SELECT customer_id FROM top_c),
  'transaction_id', (SELECT transaction_id FROM one_t),
  'created_at_existing', (SELECT created_at FROM one_t),
  'payment_method_id', (SELECT payment_method_id FROM PaymentMethod WHERE customer_id = (SELECT customer_id FROM top_c)),
  'product_id', (SELECT product_id FROM Product WHERE merchant_id = (SELECT merchant_id FROM top_m) LIMIT 1));
""")
P = json.loads(out)
P.update({
    "before": "now", "currency_code": "EUR", "amount": "5000", "ip_geolocation": "203.0.113.9", "device_type": "mobile",
    "actor_id": "api-key-1", "actor_type_code": "merchant_api", "since": (__import__("datetime").date.today() - __import__("datetime").timedelta(days=90)).isoformat(),
})

# ------------------------------------------------------------ extraction des requêtes
queries, cur_id, in_sql, buf = {}, None, False, []
for line in open(md, encoding="utf-8"):
    m = re.match(r"^#{3,4} (D8\.1\.\d\.\d)\.", line)
    if m:
        cur_id = m.group(1)
    if line.startswith("```sql"):
        in_sql, buf = True, []
    elif line.startswith("```") and in_sql:
        in_sql = False
        queries.setdefault(cur_id, []).append("".join(buf))
    elif in_sql:
        buf.append(line)

OVERRIDES = {
    "D8.1.2.2": {"before": "NOW"},
    "D8.1.2.3": {"transaction_id": str(uuid.uuid4()), "idempotency_key": "k-" + uuid.uuid4().hex, "created_at": "NOW"},
    "D8.1.3.2": {"from": "2000-01-01", "to": "2100-01-01"},
    "D8.1.4.2": {"from": "2000-01-01", "to": "2100-01-01"},
}


def subst(sql, params):
    def rep(m):
        k = m.group(1)
        v = params[k]
        if v == "NOW":
            return "now()"
        if v == "now":
            return "now()"
        return "'" + str(v).replace("'", "''") + "'"
    return re.sub(r"(?<![:\w]):([a-z_]+)\b", rep, sql)


T_QUERIES = {"D8.1.2.1", "D8.1.2.2", "D8.1.2.3", "D8.1.2.4", "D8.1.2.5", "D8.1.2.6", "D8.1.4.1"}
rows = []
ok_all = True
for qid, blocks in queries.items():
    params = dict(P)
    params.update(OVERRIDES.get(qid, {}))
    if qid == "D8.1.5.1" or qid == "D8.1.2.3" and False:
        pass
    sqls = [subst(b.strip().rstrip(";") + ";", params) for b in blocks]
    # exécution réelle (compte de lignes) puis EXPLAIN ANALYZE du dernier bloc, le tout annulé
    script = "BEGIN;\n" + "\n".join(sqls[:-1]) + "\n" if len(sqls) > 1 else "BEGIN;\n"
    count_sql = script + f"SELECT count(*) FROM ({sqls[-1].rstrip(';')}) q;\n" if (sqls[-1].lstrip().upper().startswith(("SELECT", "WITH")) and "FOR UPDATE" not in sqls[-1]) else None
    status, nrows, err = "OK", "", ""
    if count_sql:
        rc, o, e = psql(count_sql + "ROLLBACK;\n")
        if rc != 0:
            status, err = "ERREUR", e.strip().splitlines()[-1] if e.strip() else ""
        else:
            nrows = o.strip().splitlines()[-1] if o.strip() else ""
    else:
        rc, o, e = psql(script + sqls[-1] + "\nROLLBACK;\n")
        if rc != 0:
            status, err = "ERREUR", e.strip().splitlines()[-1] if e.strip() else ""
        else:
            nrows = "(écriture annulée)"
    plan, ms = "", ""
    if status == "OK":
        rc, o, e = psql(script + "EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)\n" + sqls[-1] + "\nROLLBACK;\n")
        if rc == 0:
            lines = o.splitlines()
            ms = next((re.search(r"Execution Time: ([\d.]+)", l).group(1) for l in lines if "Execution Time" in l), "")
            idx = sorted(set(re.findall(r"(?:Index(?: Only)? Scan(?: Backward)?|Bitmap Index Scan) (?:using|on) (\w+)", " ".join(lines))))
            seq = sorted(set(re.findall(r"Seq Scan on (\w+)", " ".join(lines))))
            plan = f"index: {', '.join(i.replace('transaction_', 't_') if False else i for i in idx[:3]) or '-'}{' (+%d)' % (len(idx)-3) if len(idx) > 3 else ''} ; seq: {', '.join(x for x in seq ) or '-'}"
            rows_plan = o
            if qid in T_QUERIES:
                rc2, o2, _ = psql(script + "SET LOCAL enable_seqscan = off;\nEXPLAIN (COSTS OFF)\n" + sqls[-1] + "\nROLLBACK;\n")
                if rc2 == 0:
                    idx2 = sorted({re.sub(r"_20\d\d_\d\d_", "_<mois>_", i) for i in re.findall(r"(?:Index(?: Only)? Scan(?: Backward)?|Bitmap Index Scan) (?:using|on) (\w+)", o2)})
                    plan += " ; index utilisables (seqscan off): " + (", ".join(idx2) or "-")
    else:
        ok_all = False
    rows.append((qid, status, nrows, ms, plan, err))
    print(f"{qid:10} {status:7} lignes={nrows:>18} ms={ms:>9}  {plan}  {err}")

if report:
    with open(report, "w", encoding="utf-8") as f:
        f.write("# Vérification de D8.1 (v35)\n\n")
        f.write("Environnement : PostgreSQL 16.15, DDL `01_schema.sql` + `02_complement.sql` (v35), jeu synthétique `05_sample_data.sql` ")
        n = psql("SELECT (SELECT count(*) FROM Transaction)||' transactions, '||(SELECT count(*) FROM Customer)||' clients, '||(SELECT count(*) FROM FraudScoringLog)||' scorings'")[1].strip()
        f.write(f"({n}). Chaque requête est exécutée dans une transaction annulée ; les plans sont issus de `EXPLAIN (ANALYZE)`.\n\n")
        f.write("Les durées sont indicatives (jeu de ~80 000 lignes, machine de test partagée) : elles servent à vérifier le *plan*, pas à prédire la production.\n\n")
        f.write("| Requête | Résultat | Lignes | Durée (ms) | Plan |\n|---|---|---|---|---|\n")
        for qid, status, nrows, ms, plan, err in rows:
            f.write(f"| {qid} | {status} | {nrows} | {ms} | {plan or err} |\n")
sys.exit(0 if ok_all else 1)
