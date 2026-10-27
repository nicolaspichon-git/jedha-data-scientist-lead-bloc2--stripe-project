-- =====================================================================
-- STRIPE PROJECT - Annexe 1.B (OLTP) - données synthétiques : 05_sample_data.sql
-- Version : v36. Jeu volumétrique déterministe pour valider les requêtes de D8.1 et leurs plans d'exécution.
-- À charger après 01, 02, 03 (jamais en production). Volume : ~100 000 transactions sur 5 mois, 5 marchands.
-- =====================================================================
\set ON_ERROR_STOP on
SET client_min_messages = warning;


-- marchands, plans, frais, produits -----------------------------------
CREATE TEMP TABLE m AS SELECT i, uuidv7() AS id FROM generate_series(1,5) i;
INSERT INTO Merchant (merchant_id, legal_name, country_code, updated_by, updater_type)
  SELECT id, 'Marchand ' || i, (ARRAY['FR','DE','US','FR','JP'])[i], 'seed', 'system' FROM m;
CREATE TEMP TABLE pl AS SELECT m.i, m.id AS merchant_id, uuidv7() AS plan_id FROM m;
INSERT INTO PricingPlan (pricing_plan_id, merchant_id, commission_rate, effective_from, updated_by, updater_type)
  SELECT plan_id, merchant_id, 0.0250 + i * 0.001, date '2020-01-01', 'seed', 'system' FROM pl;
INSERT INTO PricingPlanFee (pricing_plan_id, currency_code, fixed_fee, updated_by, updater_type)
  SELECT plan_id, c, CASE c WHEN 'JPY' THEN 30 ELSE 30 END, 'seed', 'system' FROM pl, (VALUES ('EUR'),('USD'),('JPY'),('GBP')) v(c);
CREATE TEMP TABLE pr AS
  SELECT m.i AS mi, p AS pn, m.id AS merchant_id, uuidv7() AS product_id FROM m, generate_series(1,10) p;
INSERT INTO Product (product_id, merchant_id, name, unit_price, currency_code, updated_by, updater_type)
  SELECT product_id, merchant_id, 'Produit ' || mi || '-' || pn, 500 + pn * 700, 'EUR', 'seed', 'system' FROM pr;

-- clients (400 / marchand) et moyens de paiement ------------------------
CREATE TEMP TABLE cu AS
  SELECT row_number() OVER () AS n, m.id AS merchant_id, k AS k, uuidv7() AS customer_id, uuidv7() AS pm_id, m.i AS mi
  FROM m, generate_series(1,400) k;
INSERT INTO Customer (customer_id, merchant_id, email, country_code, created_at, updated_by, updater_type)
  SELECT customer_id, merchant_id, 'client' || n || '@example.com', (ARRAY['FR','DE','US','JP'])[1 + n % 4],
         now() - interval '200 days', 'seed', 'system' FROM cu;
INSERT INTO PaymentMethod (payment_method_id, customer_id, type_code, network_code, card_last4, expiry, token_reference, fingerprint, is_default, updated_by, updater_type)
  SELECT pm_id, customer_id, 'card', (ARRAY['visa','mastercard','amex'])[1 + n % 3], lpad((n % 10000)::text, 4, '0'),
         date '2030-12-31', 'tok_' || n, md5(n::text), true, 'seed', 'system' FROM cu;

-- abonnements : 1 client sur 5 ------------------------------------------
CREATE TEMP TABLE su AS
  SELECT cu.n, cu.merchant_id, cu.customer_id, cu.pm_id, uuidv7() AS subscription_id,
         (SELECT product_id FROM pr WHERE pr.merchant_id = cu.merchant_id AND pr.pn = 1 + cu.n % 10) AS product_id
  FROM cu WHERE cu.n % 5 = 0;
INSERT INTO Subscription (subscription_id, merchant_id, customer_id, product_id, payment_method_id, billing_cycle, amount, currency_code,
                          started_at, current_period_end, updated_by, updater_type)
  SELECT s.subscription_id, s.merchant_id, s.customer_id, s.product_id, s.pm_id, 'monthly', p.unit_price, 'EUR',
         now() - interval '150 days', now() + interval '5 days', 'seed', 'system'
  FROM su s JOIN Product p USING (product_id);

-- transactions ponctuelles (60 %), libres (20 %) --------------------------
CREATE TEMP TABLE tx (tid uuid, g int, created_at timestamptz);
INSERT INTO tx SELECT uuidv7(), g, now() - (g % 150) * interval '1 day' - (g * 37 % 86400) * interval '1 second'
  FROM generate_series(1, 100000) g;

INSERT INTO Transaction (transaction_id, merchant_id, customer_id, payment_method_id, product_id, subscription_id, pricing_plan_id,
                         is_merchant_initiated, amount, fee_amount, currency_code, status_code, ip_geolocation, device_type, created_at, updated_by, updater_type)
SELECT t.tid, cu.merchant_id, cu.customer_id, cu.pm_id,
       CASE WHEN t.g % 5 < 3 THEN (SELECT product_id FROM pr WHERE pr.merchant_id = cu.merchant_id AND pr.pn = 1 + t.g % 10) END,
       NULL, pl.plan_id, false,
       amt.amount,
       stripe_fee(amt.amount, 0.0250 + cu.mi * 0.001, 30),
       amt.cur,
       CASE WHEN t.g % 20 = 0 THEN 'failed' ELSE 'successful' END,
       '203.0.113.' || (t.g % 250), (ARRAY['mobile','desktop','tablet'])[1 + t.g % 3], t.created_at, 'seed', 'system'
FROM tx t
JOIN cu ON cu.n = 1 + (t.g * 7919) % 2000
JOIN pl ON pl.merchant_id = cu.merchant_id
CROSS JOIN LATERAL (SELECT 500 + (t.g * 37) % 20000 AS amount,
                           CASE WHEN t.g % 10 = 0 THEN 'USD' WHEN t.g % 37 = 0 THEN 'JPY' WHEN t.g % 500 = 1 THEN 'GBP' ELSE 'EUR' END AS cur) amt
WHERE t.g % 5 < 4;

-- prélèvements d'abonnement : 6 échéances mensuelles par abonnement ---------
INSERT INTO Transaction (transaction_id, merchant_id, customer_id, payment_method_id, product_id, subscription_id, pricing_plan_id,
                         is_merchant_initiated, amount, fee_amount, currency_code, status_code, created_at, updated_by, updater_type)
SELECT uuidv7(), s.merchant_id, s.customer_id, s.pm_id, s.product_id, s.subscription_id, pl.plan_id, true,
       p.unit_price, stripe_fee(p.unit_price, 0.0250 + pl.i * 0.001, 30), 'EUR',
       CASE WHEN k = 3 AND s.n % 10 = 0 THEN 'failed' ELSE 'successful' END,
       now() - k * interval '28 days', 'seed', 'system'
FROM su s JOIN pl USING (merchant_id) JOIN Product p USING (product_id), generate_series(0,5) k;

-- remboursements : 3 % partiels (50 %), 1 % totaux (statut refunded) ----------
INSERT INTO Refund (transaction_id, amount, reason, created_at, updated_by, updater_type)
SELECT transaction_id, CASE WHEN rn % 4 = 0 THEN amount ELSE amount / 2 END, 'seed', created_at + interval '2 days', 'seed', 'system'
FROM (SELECT t.*, row_number() OVER (ORDER BY transaction_id) AS rn FROM Transaction t WHERE status_code = 'successful' AND amount > 1) x
WHERE rn % 33 = 0;
UPDATE Transaction t SET status_code = 'refunded'
  FROM Refund r WHERE r.transaction_id = t.transaction_id AND r.amount = t.amount;

-- rétro-facturations : ~1 % -------------------------------------------------
INSERT INTO Chargeback (transaction_id, reason_code, status_code, created_at, due_at, resolved_at, updated_by, updater_type)
SELECT transaction_id, (ARRAY['V-10.4','V-13.1','M-4837'])[1 + rn % 3],
       (ARRAY['open','won','lost'])[1 + rn % 3], created_at + interval '30 days',
       created_at + interval '30 days' + make_interval(days => (SELECT p.response_deadline_days FROM ChargebackReasonCode c
                                                                  JOIN CardNetworkPolicy p ON p.network_code = c.network_code
                                                                  WHERE c.reason_code = (ARRAY['V-10.4','V-13.1','M-4837'])[1 + rn % 3])),
       CASE WHEN rn % 3 <> 0 THEN created_at + interval '60 days' END, 'seed', 'system'
FROM (SELECT t.*, row_number() OVER (ORDER BY transaction_id) AS rn FROM Transaction t WHERE status_code = 'successful') x
WHERE rn % 101 = 0 AND created_at + interval '30 days' < now();

-- scoring : un journal + un FraudScore par transaction -------------------------
INSERT INTO FraudScoringLog (transaction_id, model_version, model_role, features, anomaly_score, risk_level_code, evaluated_at)
SELECT t.transaction_id, 'v1', 'production', jsonb_build_object('amount', t.amount),
       sc.score,
       CASE WHEN sc.score >= 0.99 THEN 'high' WHEN sc.score >= 0.95 THEN 'medium' ELSE 'low' END,
       t.created_at + interval '1 second'
FROM Transaction t
CROSS JOIN LATERAL (SELECT CASE WHEN c.transaction_id IS NOT NULL AND c.reason_code IN ('V-10.4','M-4837') THEN 0.9950
                                ELSE round(((abs(hashtext(t.transaction_id::text)::bigint) % 10000)::numeric / 10000), 4) END AS score
                    FROM (SELECT 1) one LEFT JOIN Chargeback c ON c.transaction_id = t.transaction_id) sc;
INSERT INTO FraudScore (transaction_id, fraud_scoring_logentry_id, anomaly_score, risk_level_code, model_version, evaluated_at)
SELECT transaction_id, fraud_scoring_logentry_id, anomaly_score, risk_level_code, model_version, evaluated_at FROM FraudScoringLog;

-- revues (la moitié des risques élevés/moyens anciens de plus de 7 jours) et décisions ------
INSERT INTO FraudReview (transaction_id, reason, reviewed_at, reviewer_id, reviewer_type, outcome, updated_by, updater_type)
SELECT transaction_id, 'uncertain_score', evaluated_at + interval '3 days', 'agent-1', 'user',
       CASE WHEN risk_level_code = 'high' THEN 'fraud' ELSE 'legitimate' END, 'agent-1', 'user'
FROM (SELECT f.*, row_number() OVER (ORDER BY transaction_id) rn FROM FraudScore f WHERE risk_level_code IN ('high','medium')
      AND evaluated_at < now() - interval '7 days') x WHERE rn % 2 = 0;
INSERT INTO FraudDecision (transaction_id, source_review_id, decision_value, decision_status, confirmed_at, updated_by, updater_type)
SELECT transaction_id, review_id, CASE WHEN outcome = 'fraud' THEN 'fraud' ELSE 'legitimate' END, 'confirmed', reviewed_at, 'agent-1', 'user'
FROM FraudReview;

-- conformité et journal des accès ---------------------------------------------
INSERT INTO DataSubjectRequest (customer_id, merchant_id, request_type, regulation_code, received_at, due_at, updated_by, updater_type)
SELECT customer_id, merchant_id, 'access', 'GDPR', now() - (n % 40) * interval '1 day', now() - (n % 40) * interval '1 day' + interval '30 days', 'seed', 'system'
FROM cu WHERE n % 10 = 0;
INSERT INTO DataAccessLog (actor_id, actor_type_code, action_code, resource_type, merchant_id, customer_id, occurred_at)
SELECT 'agent-' || (n % 20), 'user', 'read', 'Customer', merchant_id, customer_id, now() - (n % 100) * interval '1 day'
FROM cu, generate_series(1, 5) k;

-- référence de conversion hypothétique (hors modèle OLTP : voir D8.1, remarque amont de la requête de segmentation) -----------
CREATE TABLE IF NOT EXISTS CurrencyReferenceRate (currency_code varchar(3) PRIMARY KEY REFERENCES Currency, rate_to_eur numeric(18,8) NOT NULL);
INSERT INTO CurrencyReferenceRate VALUES ('EUR',1),('USD',0.92),('JPY',0.0061) ON CONFLICT DO NOTHING;   -- GBP, BHD volontairement absents

ANALYZE;
