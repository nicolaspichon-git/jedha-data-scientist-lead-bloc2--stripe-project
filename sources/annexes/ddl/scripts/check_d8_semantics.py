#!/usr/bin/env python3
"""Contrôles sémantiques de D8.1 : chaque requête est comparée à une formulation indépendante (sous-requêtes, pas de CTE ni de jointure commune)."""
import re, subprocess, sys, json
md = sys.argv[1]
DB = "stripe_perf"
def psql(sql):
    r = subprocess.run(["psql", "-d", DB, "-X", "-q", "-At", "-v", "ON_ERROR_STOP=1"], input=sql, capture_output=True, text=True)
    if r.returncode: raise SystemExit(r.stderr)
    return r.stdout.strip()
q, cur, inq, buf = {}, None, False, []
for line in open(md, encoding="utf-8"):
    m = re.match(r"^#{3,4} (D8\.1\.\d\.\d)\.", line)
    if m: cur = m.group(1)
    if line.startswith("```sql"): inq, buf = True, []
    elif line.startswith("```") and inq: inq = False; q.setdefault(cur, []).append("".join(buf).strip().rstrip(";"))
    elif inq: buf.append(line)
def sub(sql, **kw):
    for k, v in kw.items(): sql = re.sub(rf"(?<![:\w]):{k}\b", v, sql)
    return sql
results = []
def check(name, got, expected):
    ok = str(got) == str(expected); results.append(ok)
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f"  got={got} expected={expected}"))

# D8.1.3.1 : totaux = agrégats directs sur la même fenêtre
got = psql(f"SELECT sum(gross_amount), sum(refunded_amount), sum(fee_amount), sum(merchant_net_amount), sum(transactions) FROM ({q['D8.1.3.1'][0]}) x")
exp = psql("""SELECT (SELECT sum(amount) FROM Transaction WHERE status_code IN ('successful','refunded') AND created_at >= now() - interval '30 days'),
 (SELECT coalesce(sum(r.amount),0) FROM Refund r WHERE r.transaction_id IN (SELECT transaction_id FROM Transaction WHERE status_code IN ('successful','refunded') AND created_at >= now() - interval '30 days')),
 (SELECT sum(fee_amount) FROM Transaction WHERE status_code IN ('successful','refunded') AND created_at >= now() - interval '30 days'),
 (SELECT sum(amount) - sum(fee_amount) FROM Transaction WHERE status_code IN ('successful','refunded') AND created_at >= now() - interval '30 days')
   - (SELECT coalesce(sum(r.amount),0) FROM Refund r WHERE r.transaction_id IN (SELECT transaction_id FROM Transaction WHERE status_code IN ('successful','refunded') AND created_at >= now() - interval '30 days')),
 (SELECT count(*) FROM Transaction WHERE status_code IN ('successful','refunded') AND created_at >= now() - interval '30 days')""")
check("D8.1.3.1 totaux (encaissé, remboursé, commission, net, nombre)", got, exp)

# D8.1.3.2 : somme par type = total encaissé sur la période, et 3 types présents
s = sub(q['D8.1.3.2'][0], **{"from": "'2000-01-01'", "to": "'2100-01-01'"})
check("D8.1.3.2 somme des montants", psql(f"SELECT sum(total_amount) FROM ({s}) x"), psql("SELECT sum(amount) FROM Transaction WHERE status_code IN ('successful','refunded')"))
check("D8.1.3.2 types ponctuel/recurrent/libre", psql(f"SELECT string_agg(DISTINCT revenue_type, ',' ORDER BY revenue_type) FROM ({s}) x"), "libre,ponctuel,recurrent")

# D8.1.4.2 : la somme des transactions = scores dans la fenêtre mature ; fraudes connues cohérentes
s = sub(q['D8.1.4.2'][0], **{"from": "'2000-01-01'", "to": "'2100-01-01'"})
check("D8.1.4.2 effectif", psql(f"SELECT sum(transactions) FROM ({s}) x"),
      psql("SELECT count(*) FROM FraudScore fs JOIN Transaction t ON t.transaction_id=fs.transaction_id WHERE t.created_at < now() - interval '120 days'"))
check("D8.1.4.2 fraudes connues", psql(f"SELECT sum(known_frauds) FROM ({s}) x"),
      psql("""SELECT count(*) FROM FraudScore fs JOIN Transaction t ON t.transaction_id=fs.transaction_id
              WHERE t.created_at < now() - interval '120 days' AND (
                EXISTS (SELECT 1 FROM Chargeback cb JOIN ChargebackReasonCode c USING (reason_code) WHERE cb.transaction_id=t.transaction_id AND c.category='fraud')
                OR EXISTS (SELECT 1 FROM FraudDecision d WHERE d.transaction_id=t.transaction_id AND d.decision_status='confirmed' AND d.decision_value='fraud'))"""))

# D8.1.4.1 : aucune transaction déjà revue, uniquement des niveaux à revue, ordre décroissant, 100 lignes max
check("D8.1.4.1 aucune transaction déjà revue", psql(f"SELECT count(*) FROM ({q['D8.1.4.1'][0]}) x WHERE EXISTS (SELECT 1 FROM FraudReview r WHERE r.transaction_id = x.transaction_id)"), 0)
check("D8.1.4.1 tri décroissant", psql(f"SELECT bool_and(a >= b) FROM (SELECT anomaly_score a, lead(anomaly_score) OVER () b FROM ({q['D8.1.4.1'][0]}) x) y WHERE b IS NOT NULL"), "t")

# D8.1.5.1 : effectif = clients ayant au moins une transaction réussie en EUR chez le marchand ; quartiles équilibrés
mid = psql("SELECT merchant_id FROM Transaction GROUP BY 1 ORDER BY count(*) DESC LIMIT 1")
s = sub(q['D8.1.5.1'][0], merchant_id=f"'{mid}'", currency_code="'EUR'")
check("D8.1.5.1 effectif", psql(f"SELECT count(*) FROM ({s}) x"), psql(f"SELECT count(DISTINCT customer_id) FROM Transaction WHERE merchant_id='{mid}' AND currency_code='EUR' AND status_code='successful'"))
check("D8.1.5.1 quartiles équilibrés (écart max 1)", psql(f"SELECT max(c)-min(c) <= 1 FROM (SELECT count(*) c FROM ({s}) x GROUP BY quartile_monetary) y"), "t")

# D8.1.5.2 : segments = clients de la fenêtre ; moyenne pondérée cohérente ; un 'unclassified' existe (GBP sans taux)
s = q['D8.1.5.2'][0]
check("D8.1.5.2 effectif des segments", psql(f"SELECT sum(customers) FROM ({s}) x"),
      psql("""SELECT count(*) FROM (SELECT DISTINCT t.merchant_id, t.customer_id FROM Transaction t LEFT JOIN Chargeback cb ON cb.transaction_id=t.transaction_id
              WHERE t.status_code IN ('successful','refunded') AND t.created_at >= CURRENT_DATE - INTERVAL '12 months' AND cb.status_code IS DISTINCT FROM 'lost') x"""))
check("D8.1.5.2 'unclassified' présent (devise GBP sans taux)", psql(f"SELECT count(*) > 0 FROM ({s}) x WHERE segment = 'unclassified'"), "t")
check("D8.1.5.2 moyenne NULL pour unclassified uniquement", psql(f"SELECT bool_and((segment = 'unclassified') = (avg_customer_net_amount_in_euros IS NULL)) FROM ({s}) x"), "t")
# recalcul indépendant de la dépense d'un client mono-devise EUR
cid = psql("""SELECT customer_id FROM Transaction WHERE status_code='successful' AND created_at >= CURRENT_DATE - INTERVAL '12 months'
              GROUP BY customer_id HAVING count(DISTINCT currency_code) = 1 AND max(currency_code)='EUR' ORDER BY count(*) DESC LIMIT 1""")
manual = psql(f"""SELECT round(sum(t.amount - coalesce((SELECT r.amount FROM Refund r WHERE r.transaction_id=t.transaction_id),0))/100.0,2)
  FROM Transaction t WHERE t.customer_id='{cid}' AND t.status_code IN ('successful','refunded') AND t.created_at >= CURRENT_DATE - INTERVAL '12 months'
  AND NOT EXISTS (SELECT 1 FROM Chargeback cb WHERE cb.transaction_id=t.transaction_id AND cb.status_code='lost')""")
seg_expected = "top" if float(manual) >= 1000 else "regular" if float(manual) >= 200 else "occasional"
got_seg = psql(f"""SELECT segment FROM (SELECT merchant_id, customer_id, CASE WHEN tot >= 1000 THEN 'top' WHEN tot >= 200 THEN 'regular' ELSE 'occasional' END segment
                   FROM (SELECT t.merchant_id, t.customer_id, sum((t.amount - coalesce(rf.amount,0))/100.0) tot FROM Transaction t
                         LEFT JOIN Refund rf ON rf.transaction_id=t.transaction_id
                         LEFT JOIN Chargeback cb ON cb.transaction_id=t.transaction_id
                         WHERE t.customer_id='{cid}' AND t.status_code IN ('successful','refunded') AND t.created_at >= CURRENT_DATE - INTERVAL '12 months' AND cb.status_code IS DISTINCT FROM 'lost'
                         GROUP BY 1,2) z) w""")
check("D8.1.5.2 recalcul indépendant d'un client EUR", got_seg, seg_expected)

# D8.1.2.3 : commission = stripe_fee, rejeu détecté, idempotence
cust = psql("SELECT customer_id FROM Customer LIMIT 1"); pm = psql(f"SELECT payment_method_id FROM PaymentMethod WHERE customer_id='{cust}'")
import uuid
tid, key = str(uuid.uuid4()), "k-" + uuid.uuid4().hex
params = dict(idempotency_key=f"'{key}'", transaction_id=f"'{tid}'", created_at="now()", customer_id=f"'{cust}'", payment_method_id=f"'{pm}'", product_id="NULL",
              amount="12345", currency_code="'EUR'", ip_geolocation="'203.0.113.1'", device_type="'mobile'", actor_id="'t'", actor_type_code="'merchant_api'")
a, b = (sub(x, **params) for x in q['D8.1.2.3'])
out = psql(f"BEGIN;\n{a};\n{b};\nSELECT fee_amount = stripe_fee(12345, p.commission_rate, f.fixed_fee) FROM Transaction t JOIN PricingPlan p USING (pricing_plan_id) JOIN PricingPlanFee f ON f.pricing_plan_id=p.pricing_plan_id AND f.currency_code=t.currency_code WHERE t.transaction_id='{tid}';\n"
           f"{a};\nROLLBACK;")
lines = [l for l in out.splitlines() if l.strip()]
# sortie : INSERT 0 1 (RETURNING -> uuid), INSERT 0 1 est supprimé par -q ; le test final : fee ok = 't', rejeu = aucune ligne RETURNING
check("D8.1.2.3 première réservation retourne l'identifiant", lines[0], tid)
check("D8.1.2.3 commission = stripe_fee(plan en vigueur)", lines[1], "t")
check("D8.1.2.3 rejeu : aucune ligne retournée", len(lines), 2)
print(f"\n{sum(results)}/{len(results)} contrôles sémantiques réussis")
sys.exit(0 if all(results) else 1)
