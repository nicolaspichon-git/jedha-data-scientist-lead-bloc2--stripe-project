-- =====================================================================
-- STRIPE PROJECT - Annexe 1.B (OLTP) - jeu de tests des contraintes : 04_tests.sql
-- Version : v36. À exécuter sur une base vierge chargée avec 01, 02, 03.
-- Chaque test positif doit réussir ; chaque test négatif doit échouer avec le SQLSTATE attendu.
-- Sortie finale : tableau PASS/FAIL (aucun FAIL attendu).
-- =====================================================================
\set ON_ERROR_STOP off
\o /dev/null
SET client_min_messages = warning;

CREATE TEMP TABLE test_result (n serial, label text, expected text, got text, ok boolean);

-- exécute stmt (éventuellement sous un rôle) et vérifie le SQLSTATE obtenu ('00000' = succès attendu)
CREATE FUNCTION pg_temp.t(p_label text, p_stmt text, p_expected text DEFAULT '00000', p_role text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $fn$
DECLARE
  v_state text := '00000';
BEGIN
  BEGIN
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_stmt;
    IF p_expected <> '00000' OR p_role IS NOT NULL THEN
      -- force l'évaluation des contraintes différées dans le sous-bloc
      EXECUTE 'SET CONSTRAINTS ALL IMMEDIATE';
    END IF;
    IF p_expected <> '00000' THEN
      RAISE EXCEPTION USING ERRCODE = 'XX999', MESSAGE = 'no error raised';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_state := SQLSTATE;
    IF p_expected = '00000' OR v_state <> p_expected THEN
      INSERT INTO test_result (label, expected, got, ok) VALUES (p_label, p_expected, v_state || ' ' || SQLERRM, false);
      RETURN;
    END IF;
  END;
  EXECUTE 'RESET ROLE';   -- le rôle d'un test réussi persiste jusqu'à la fin de la transaction : sans cela, l'écriture du résultat échoue et annule le test
  IF p_expected = '00000' OR v_state = p_expected THEN
    INSERT INTO test_result (label, expected, got, ok) VALUES (p_label, p_expected, v_state, true);
  END IF;
END
$fn$;

-- ---------------------------------------------------------------- jeu de données de base
INSERT INTO Merchant (merchant_id, legal_name, country_code, updated_by, updater_type) VALUES
  ('00000000-0000-7000-8000-0000000000a1','Marchand A','FR','test','system'),
  ('00000000-0000-7000-8000-0000000000b1','Marchand B','US','test','system');
INSERT INTO PricingPlan (pricing_plan_id, merchant_id, commission_rate, effective_from, updated_by, updater_type) VALUES
  ('00000000-0000-7000-8000-000000000a01','00000000-0000-7000-8000-0000000000a1',0.0290,'2026-01-01','test','system'),
  ('00000000-0000-7000-8000-000000000b01','00000000-0000-7000-8000-0000000000b1',0.0250,'2026-01-01','test','system');
INSERT INTO PricingPlanFee VALUES
  ('00000000-0000-7000-8000-000000000a01','EUR',30,'test','system'),
  ('00000000-0000-7000-8000-000000000a01','USD',30,'test','system'),
  ('00000000-0000-7000-8000-000000000b01','USD',30,'test','system');
INSERT INTO Customer (customer_id, merchant_id, email, country_code, updated_by, updater_type) VALUES
  ('00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-0000000000a1','alice@example.com','FR','test','system'),
  ('00000000-0000-7000-8000-00000000cb01','00000000-0000-7000-8000-0000000000b1','bob@example.com','US','test','system');
INSERT INTO PaymentMethod (payment_method_id, customer_id, type_code, network_code, card_last4, expiry, token_reference, is_default, updated_by, updater_type) VALUES
  ('00000000-0000-7000-8000-00000000da01','00000000-0000-7000-8000-00000000ca01','card','visa','4242','2030-12-31','tok_a1',true,'test','system'),
  ('00000000-0000-7000-8000-00000000db01','00000000-0000-7000-8000-00000000cb01','card','visa','1111','2030-12-31','tok_b1',true,'test','system');
INSERT INTO Product (product_id, merchant_id, name, unit_price, currency_code, updated_by, updater_type) VALUES
  ('00000000-0000-7000-8000-00000000ea01','00000000-0000-7000-8000-0000000000a1','Produit A1',10000,'EUR','test','system'),
  ('00000000-0000-7000-8000-00000000ea02','00000000-0000-7000-8000-0000000000a1','Produit A2',5000,'EUR','test','system'),
  ('00000000-0000-7000-8000-00000000eb01','00000000-0000-7000-8000-0000000000b1','Produit B1',2000,'USD','test','system');
INSERT INTO Subscription (subscription_id, merchant_id, customer_id, product_id, payment_method_id, billing_cycle, amount, currency_code, updated_by, updater_type) VALUES
  ('00000000-0000-7000-8000-00000000fa01','00000000-0000-7000-8000-0000000000a1','00000000-0000-7000-8000-00000000ca01',
   '00000000-0000-7000-8000-00000000ea01','00000000-0000-7000-8000-00000000da01','monthly',10000,'EUR','test','system');

-- gabarit de transaction valide (a1/ca01/da01/ea01/plan a01, EUR 10000, fee 320)
CREATE FUNCTION pg_temp.txn(p_id text, p_cust text DEFAULT 'ca01', p_pm text DEFAULT 'da01', p_prod text DEFAULT 'ea01',
                            p_sub text DEFAULT NULL, p_plan text DEFAULT 'a01', p_cur text DEFAULT 'EUR',
                            p_amount bigint DEFAULT 10000, p_fee bigint DEFAULT 320, p_mi boolean DEFAULT false,
                            p_status text DEFAULT 'successful', p_at timestamptz DEFAULT now(), p_merchant text DEFAULT 'a1')
RETURNS text LANGUAGE sql AS $$
 SELECT format($q$INSERT INTO Transaction (transaction_id, merchant_id, customer_id, payment_method_id, product_id, subscription_id, pricing_plan_id,
          is_merchant_initiated, amount, fee_amount, currency_code, status_code, created_at, updated_by, updater_type)
          VALUES ('00000000-0000-7000-8000-%s', '00000000-0000-7000-8000-0000000000%s', %L, %L, %L, %L, %L, %L, %s, %s, %L, %L, %L, 'test', 'system')$q$,
          lpad(p_id,12,'0'), p_merchant,
          '00000000-0000-7000-8000-00000000' || p_cust, '00000000-0000-7000-8000-00000000' || p_pm,
          CASE WHEN p_prod IS NULL THEN NULL ELSE '00000000-0000-7000-8000-00000000' || p_prod END,
          CASE WHEN p_sub IS NULL THEN NULL ELSE '00000000-0000-7000-8000-00000000' || p_sub END,
          '00000000-0000-7000-8000-000000000' || p_plan, p_mi, p_amount, p_fee, p_cur, p_status, p_at)
$$;

-- ---------------------------------------------------------------- transactions : positifs
SELECT pg_temp.t('P01 transaction valide', pg_temp.txn('0001'));
SELECT pg_temp.t('P02 prélèvement d''abonnement valide', pg_temp.txn('0002', p_sub => 'fa01', p_mi => true));
SELECT pg_temp.t('P03 paiement libre (sans produit)', pg_temp.txn('0003', p_prod => NULL));
SELECT pg_temp.t('P04 transaction datée du mois précédent', pg_temp.txn('0004', p_at => date_trunc('month', now()) - interval '10 days'));
SELECT pg_temp.t('P05 même email chez un autre marchand',
  $q$INSERT INTO Customer (customer_id, merchant_id, email, country_code, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-00000000cb02','00000000-0000-7000-8000-0000000000b1','alice@example.com','US','test','system')$q$);

-- ---------------------------------------------------------------- transactions : négatifs (cloisonnement, plan, frais)
SELECT pg_temp.t('N01 client d''un autre marchand', pg_temp.txn('0101', p_cust => 'cb01', p_pm => 'db01', p_prod => NULL), '23503');
SELECT pg_temp.t('N02 moyen de paiement d''un autre client', pg_temp.txn('0102', p_pm => 'db01'), '23503');
SELECT pg_temp.t('N03 produit d''un autre marchand', pg_temp.txn('0103', p_prod => 'eb01'), '23503');
SELECT pg_temp.t('N04 plan d''un autre marchand', pg_temp.txn('0104', p_plan => 'b01', p_cur => 'USD'), '23503');
SELECT pg_temp.t('N05 devise sans frais fixe dans le plan (règle #25)', pg_temp.txn('0105', p_cur => 'GBP'), '23503');
SELECT pg_temp.t('N06 abonnement sans produit', pg_temp.txn('0106', p_prod => NULL, p_sub => 'fa01', p_mi => true), '23514');
SELECT pg_temp.t('N07 abonnement avec un autre produit', pg_temp.txn('0107', p_prod => 'ea02', p_sub => 'fa01', p_mi => true), '23503');
SELECT pg_temp.t('N08 is_merchant_initiated incohérent avec subscription_id', pg_temp.txn('0108', p_sub => 'fa01', p_mi => false), '23514');
SELECT pg_temp.t('N09 montant nul', pg_temp.txn('0109', p_amount => 0), '23514');
SELECT pg_temp.t('N10 statut inconnu', pg_temp.txn('0110', p_status => 'unknown'), '23503');

-- ---------------------------------------------------------------- tarification, moyens de paiement, abonnements
SELECT pg_temp.t('N12 plans qui se chevauchent (EXCLUDE, règle #21)',
  $q$INSERT INTO PricingPlan (pricing_plan_id, merchant_id, commission_rate, effective_from, effective_to, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-000000000a02','00000000-0000-7000-8000-0000000000a1',0.03,'2026-06-01','2026-12-31','test','system')$q$, '23P01');
SELECT pg_temp.t('P06 plans successifs sans chevauchement',
  $q$UPDATE PricingPlan SET effective_to = '2026-07-01' WHERE pricing_plan_id = '00000000-0000-7000-8000-000000000a01';
     INSERT INTO PricingPlan (pricing_plan_id, merchant_id, commission_rate, effective_from, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-000000000a02','00000000-0000-7000-8000-0000000000a1',0.03,'2026-07-01','test','system')$q$);
SELECT pg_temp.t('N13 deux moyens de paiement par défaut',
  $q$INSERT INTO PaymentMethod (customer_id, type_code, network_code, card_last4, expiry, token_reference, is_default, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-00000000ca01','card','visa','0001','2031-01-31','tok_dup_default',true,'test','system')$q$, '23505');
SELECT pg_temp.t('N14 carte sans détails',
  $q$INSERT INTO PaymentMethod (customer_id, type_code, token_reference, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-00000000ca01','card','tok_nodetails','test','system')$q$, '23514');
SELECT pg_temp.t('N15 second abonnement non résilié au même produit',
  $q$INSERT INTO Subscription (merchant_id, customer_id, product_id, payment_method_id, billing_cycle, amount, currency_code, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000000a1','00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-00000000ea01',
             '00000000-0000-7000-8000-00000000da01','monthly',10000,'EUR','test','system')$q$, '23505');
SELECT pg_temp.t('N16 abonnement avec le moyen de paiement d''un autre client (règle #19)',
  $q$INSERT INTO Subscription (merchant_id, customer_id, product_id, payment_method_id, billing_cycle, amount, currency_code, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000000a1','00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-00000000ea02',
             '00000000-0000-7000-8000-00000000db01','monthly',5000,'EUR','test','system')$q$, '23503');
SELECT pg_temp.t('N17 abonnement à un produit d''un autre marchand',
  $q$INSERT INTO Subscription (merchant_id, customer_id, product_id, payment_method_id, billing_cycle, amount, currency_code, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000000a1','00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-00000000eb01',
             '00000000-0000-7000-8000-00000000da01','monthly',2000,'USD','test','system')$q$, '23503');
SELECT pg_temp.t('N18 email en doublon à la casse près chez le même marchand',
  $q$INSERT INTO Customer (merchant_id, email, country_code, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000000a1','ALICE@Example.com','FR','test','system')$q$, '23505');

SELECT pg_temp.t('N18b moyen de paiement rattaché à un client inexistant (FK PaymentMethod -> Customer)',
  $q$INSERT INTO PaymentMethod (customer_id, type_code, network_code, card_last4, expiry, token_reference, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000fffff','card','visa','4242','2030-12-31','tok_orphan','test','system')$q$, '23503');

-- ---------------------------------------------------------------- idempotence
SELECT pg_temp.t('P07 clé d''idempotence + transaction dans la même transaction SQL',
  format($q$INSERT INTO IdempotencyKey (merchant_id, idempotency_key, transaction_id)
            SELECT merchant_id, 'key-1', transaction_id FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'));
SELECT pg_temp.t('N19 rejeu de la même clé d''idempotence',
  format($q$INSERT INTO IdempotencyKey (merchant_id, idempotency_key, transaction_id)
            SELECT merchant_id, 'key-1', transaction_id FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000002'), '23505');
SELECT pg_temp.t('N20 clé d''idempotence vers une transaction inexistante (FK différée)',
  $q$INSERT INTO IdempotencyKey (merchant_id, idempotency_key, transaction_id)
     VALUES ('00000000-0000-7000-8000-0000000000a1','key-ghost','00000000-0000-7000-8000-00000000dead')$q$, '23503');

-- ---------------------------------------------------------------- remboursement / litige
SELECT pg_temp.t('P08 remboursement partiel',
  format($q$INSERT INTO Refund (transaction_id, amount, updated_by, updater_type)
            SELECT transaction_id, 4000, 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'));
SELECT pg_temp.t('N21 remboursement supérieur au montant (trigger différé)',
  format($q$INSERT INTO Refund (transaction_id, amount, updated_by, updater_type)
            SELECT transaction_id, 10001, 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000002'), '23514');
SELECT pg_temp.t('N22 second remboursement pour la même transaction',
  format($q$INSERT INTO Refund (transaction_id, amount, updated_by, updater_type)
            SELECT transaction_id, 100, 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'), '23505');
SELECT pg_temp.t('P09 rétro-facturation',
  format($q$INSERT INTO Chargeback (transaction_id, reason_code, due_at, updated_by, updater_type)
            SELECT transaction_id, 'V-10.4', now() + interval '30 days', 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000002'));

-- ---------------------------------------------------------------- fraude
SELECT pg_temp.t('P10 entrée de journal de scoring',
  format($q$INSERT INTO FraudScoringLog (fraud_scoring_logentry_id, transaction_id, model_version, model_role, features, anomaly_score, risk_level_code)
            SELECT '00000000-0000-7000-8000-0000000f0001', transaction_id, 'v1', 'production', '{"f":1}', 0.9100, 'high'
            FROM Transaction WHERE transaction_id = %L$q$, '00000000-0000-7000-8000-000000000001'));
SELECT pg_temp.t('N24 second scoring identique (transaction, version, rôle)',
  format($q$INSERT INTO FraudScoringLog (transaction_id, model_version, model_role, features, anomaly_score, risk_level_code)
            SELECT transaction_id, 'v1', 'production', '{}', 0.5, 'medium' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'), '23505');
SELECT pg_temp.t('N25 FraudScore incohérent avec le journal (score différent)',
  format($q$INSERT INTO FraudScore (transaction_id, fraud_scoring_logentry_id, anomaly_score, risk_level_code, model_version)
            SELECT transaction_id, '00000000-0000-7000-8000-0000000f0001', 0.1000, 'high', 'v1' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'), '23503');
SELECT pg_temp.t('P11 FraudScore cohérent avec le journal',
  format($q$INSERT INTO FraudScore (transaction_id, fraud_scoring_logentry_id, anomaly_score, risk_level_code, model_version)
            SELECT transaction_id, '00000000-0000-7000-8000-0000000f0001', 0.9100, 'high', 'v1' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'));
SELECT pg_temp.t('P12 revue de fraude',
  format($q$INSERT INTO FraudReview (review_id, transaction_id, reason, reviewer_id, reviewer_type, outcome, updated_by, updater_type)
            SELECT '00000000-0000-7000-8000-0000000e0001', transaction_id, 'uncertain_score', 'agent-7', 'user', 'fraud', 'agent-7', 'user'
            FROM Transaction WHERE transaction_id = %L$q$, '00000000-0000-7000-8000-000000000001'));
SELECT pg_temp.t('N26 décision defaulted sans defaulted_at',
  format($q$INSERT INTO FraudDecision (transaction_id, decision_value, decision_status, updated_by, updater_type)
            SELECT transaction_id, 'legitimate', 'defaulted', 'scoring', 'service' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000002'), '23514');
SELECT pg_temp.t('N27 décision confirmée par la revue d''une AUTRE transaction',
  format($q$INSERT INTO FraudDecision (transaction_id, source_review_id, decision_value, decision_status, confirmed_at, updated_by, updater_type)
            SELECT transaction_id, '00000000-0000-7000-8000-0000000e0001', 'fraud', 'confirmed', now(), 'agent-7', 'user' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000002'), '23503');
SELECT pg_temp.t('P13 décision confirmée par la revue de la même transaction',
  format($q$INSERT INTO FraudDecision (transaction_id, source_review_id, decision_value, decision_status, confirmed_at, updated_by, updater_type)
            SELECT transaction_id, '00000000-0000-7000-8000-0000000e0001', 'fraud', 'confirmed', now(), 'agent-7', 'user' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000001'));

-- ---------------------------------------------------------------- sécurité et conformité
SELECT pg_temp.t('P14 consentement',
  $q$INSERT INTO ConsentRecord (consent_id, customer_id, merchant_id, purpose, is_granted, legal_basis, source, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000c0001','00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-0000000000a1','marketing',true,'consent','checkout','alice','user')$q$);
SELECT pg_temp.t('N28 consentement donné à un marchand qui n''est pas celui du client',
  $q$INSERT INTO ConsentRecord (customer_id, merchant_id, purpose, is_granted, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-0000000000b1','analytics',true,'alice','user')$q$, '23503');
SELECT pg_temp.t('N29 demande RGPD : marchand incohérent',
  $q$INSERT INTO DataSubjectRequest (customer_id, merchant_id, request_type, regulation_code, due_at, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-00000000ca01','00000000-0000-7000-8000-0000000000b1','access','GDPR',now() + interval '30 days','alice','user')$q$, '23503');
SELECT pg_temp.t('P15 accès journalisé (client du marchand)',
  $q$INSERT INTO DataAccessLog (actor_id, actor_type_code, action_code, resource_type, merchant_id, customer_id)
     VALUES ('agent-7','user','read','Customer','00000000-0000-7000-8000-0000000000a1','00000000-0000-7000-8000-00000000ca01')$q$);
SELECT pg_temp.t('N30 accès journalisé : client d''un autre marchand (règle #33)',
  $q$INSERT INTO DataAccessLog (actor_id, actor_type_code, action_code, resource_type, merchant_id, customer_id)
     VALUES ('agent-7','user','read','Customer','00000000-0000-7000-8000-0000000000b1','00000000-0000-7000-8000-00000000ca01')$q$, '23503');
SELECT pg_temp.t('P16 accès transverse sans marchand ni client',
  $q$INSERT INTO DataAccessLog (actor_id, actor_type_code, action_code, resource_type) VALUES ('ops','system','export','Report')$q$);
SELECT pg_temp.t('P17 journal des écritures',
  $q$INSERT INTO ChangeAuditLog (table_name, record_id, action_code, actor_id, actor_type_code, changed_fields)
     VALUES ('Customer','x','update','test','system','{"email":{"avant":"a","apres":"b"}}')$q$);

-- ---------------------------------------------------------------- immutabilité
SELECT pg_temp.t('N31 UPDATE interdit sur FraudScore', $q$UPDATE FraudScore SET anomaly_score = 0.5$q$, '23001');
SELECT pg_temp.t('N32 DELETE interdit sur ConsentRecord', $q$DELETE FROM ConsentRecord$q$, '23001');
SELECT pg_temp.t('N33 UPDATE interdit sur DataAccessLog', $q$UPDATE DataAccessLog SET was_authorized = false$q$, '23001');
SELECT pg_temp.t('N34 DELETE interdit sur ChangeAuditLog', $q$DELETE FROM ChangeAuditLog$q$, '23001');
SELECT pg_temp.t('N35 UPDATE interdit sur FraudScoringLog', $q$UPDATE FraudScoringLog SET features = '{}'$q$, '23001');
SELECT pg_temp.t('N36 TRUNCATE interdit sur FraudScore', $q$TRUNCATE FraudScore$q$, '23001');
SELECT pg_temp.t('N37 TRUNCATE interdit sur DataAccessLog', $q$TRUNCATE DataAccessLog$q$, '23001');
SELECT pg_temp.t('P18 FraudDecision reste modifiable (mutable)',
  $q$UPDATE FraudDecision SET updated_by = 'agent-8' WHERE decision_value = 'fraud'$q$);

-- ---------------------------------------------------------------- privilèges
SELECT pg_temp.t('N38 stripe_app ne peut pas supprimer de transaction', $q$DELETE FROM Transaction$q$, '42501', 'stripe_app');
SELECT pg_temp.t('N39 stripe_app ne peut pas modifier FraudScore (privilège)', $q$UPDATE FraudScore SET anomaly_score = 0.5$q$, '42501', 'stripe_app');
SELECT pg_temp.t('N40 stripe_app ne peut pas écrire dans DataAccessLog', $q$INSERT INTO DataAccessLog (actor_id, actor_type_code, action_code, resource_type) VALUES ('a','user','read','x')$q$, '42501', 'stripe_app');
SELECT pg_temp.t('P19 stripe_log_writer peut insérer dans DataAccessLog', $q$INSERT INTO DataAccessLog (actor_id, actor_type_code, action_code, resource_type) VALUES ('a','user','read','x')$q$, '00000', 'stripe_log_writer');
SELECT pg_temp.t('N41 stripe_log_writer ne lit pas les clients', $q$SELECT * FROM Customer$q$, '42501', 'stripe_log_writer');
SELECT pg_temp.t('P20 stripe_app peut insérer une transaction', pg_temp.txn('0020'), '00000', 'stripe_app');

-- ---------------------------------------------------------------- pseudonymisation et vues de contrôle
SELECT pg_temp.t('P21 pseudonymisation d''un client',
  $q$SELECT pseudonymize_customer('00000000-0000-7000-8000-00000000cb02', 'dpo')$q$);
SELECT pg_temp.t('P22 le client est pseudonymisé',
  $q$DO $d$ BEGIN IF (SELECT email FROM Customer WHERE customer_id = '00000000-0000-7000-8000-00000000cb02') NOT LIKE 'erased-%' THEN RAISE EXCEPTION 'not erased'; END IF; END $d$$q$);
SELECT pg_temp.t('P23 v_fee_discrepancy vide sur données cohérentes',
  $q$DO $d$ BEGIN IF EXISTS (SELECT 1 FROM v_fee_discrepancy) THEN RAISE EXCEPTION 'unexpected discrepancy'; END IF; END $d$$q$);
SELECT pg_temp.t('P24 commission erronée acceptée par la table mais détectée par la vue',
  pg_temp.txn('0030', p_fee => 999));
SELECT pg_temp.t('P25 v_fee_discrepancy signale la commission erronée',
  $q$DO $d$ BEGIN IF (SELECT count(*) FROM v_fee_discrepancy) <> 1 THEN RAISE EXCEPTION 'expected exactly one discrepancy'; END IF; END $d$$q$);

-- ---------------------------------------------------------------- Chargeback.due_at (v34)
SELECT pg_temp.t('P30 v_chargeback_due_discrepancy vide sur données cohérentes',
  $q$DO $d$ BEGIN IF EXISTS (SELECT 1 FROM v_chargeback_due_discrepancy) THEN RAISE EXCEPTION 'unexpected discrepancy'; END IF; END $d$$q$);
SELECT pg_temp.t('P31 échéance erronée acceptée par la table (mais détectée par la vue)',
  format($q$INSERT INTO Chargeback (transaction_id, reason_code, due_at, updated_by, updater_type)
            SELECT transaction_id, 'V-13.1', now() + interval '1 day', 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000003'));
SELECT pg_temp.t('P32 v_chargeback_due_discrepancy signale l''échéance erronée',
  $q$DO $d$ BEGIN IF (SELECT count(*) FROM v_chargeback_due_discrepancy) <> 1 THEN RAISE EXCEPTION 'expected exactly one discrepancy'; END IF; END $d$$q$);
SELECT pg_temp.t('N48 échéance antérieure à la création du litige',
  format($q$INSERT INTO Chargeback (transaction_id, reason_code, due_at, updated_by, updater_type)
            SELECT transaction_id, 'M-4837', now() - interval '1 day', 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000004'), '23514');

-- ---------------------------------------------------------------- CardNetwork / CardNetworkPolicy (v35)
SELECT pg_temp.t('P33 litige sur un réseau sans politique : due_at NULL accepté',
  format($q$INSERT INTO ChargebackReasonCode (reason_code, network_code, label) VALUES ('D-0001', 'discover', 'test');
            INSERT INTO Chargeback (transaction_id, reason_code, updated_by, updater_type)
            SELECT transaction_id, 'D-0001', 'test', 'system' FROM Transaction WHERE transaction_id = %L$q$,
         '00000000-0000-7000-8000-000000000004'));
SELECT pg_temp.t('P34 ce litige sans politique n''est pas signalé par la vue',
  $q$DO $d$ BEGIN IF (SELECT count(*) FROM v_chargeback_due_discrepancy) <> 1 THEN RAISE EXCEPTION 'expected exactly one discrepancy'; END IF; END $d$$q$);
SELECT pg_temp.t('N49 délai de réponse nul',
  $q$INSERT INTO CardNetworkPolicy (network_code, response_deadline_days) VALUES ('discover', 0)$q$, '23514');
SELECT pg_temp.t('N50 politique pour un réseau inconnu',
  $q$INSERT INTO CardNetworkPolicy (network_code, response_deadline_days) VALUES ('unknown_net', 30)$q$, '23503');
SELECT pg_temp.t('N51 code motif rattaché à un réseau inconnu',
  $q$INSERT INTO ChargebackReasonCode (reason_code, network_code, label) VALUES ('X-1', 'unknown_net', 'test')$q$, '23503');
SELECT pg_temp.t('N52 politique en double pour un réseau',
  $q$INSERT INTO CardNetworkPolicy (network_code, response_deadline_days) VALUES ('visa', 10)$q$, '23505');
SELECT pg_temp.t('P35 acteur d''humanité indéterminée accepté (is_human nullable, ex. merchant_api)',
  $q$INSERT INTO AuditActorType (actor_type_code, label, is_human) VALUES ('test_actor', 'test', NULL)$q$);
SELECT pg_temp.t('N53 client sans pays (Customer.country_code NOT NULL)',
  $q$INSERT INTO Customer (merchant_id, email, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000000a1','nocountry@example.com','test','system')$q$, '23502');
SELECT pg_temp.t('N54 client avec un pays inconnu (FK Customer -> Country)',
  $q$INSERT INTO Customer (merchant_id, email, country_code, updated_by, updater_type)
     VALUES ('00000000-0000-7000-8000-0000000000a1','badcountry@example.com','ZZ','test','system')$q$, '23503');
SELECT pg_temp.t('P36 pseudonymisation : le pays du client est conservé',
  $q$DO $d$ BEGIN IF (SELECT country_code FROM Customer WHERE customer_id = '00000000-0000-7000-8000-00000000cb02') IS DISTINCT FROM 'US' THEN RAISE EXCEPTION 'country lost'; END IF; END $d$$q$);

-- ---------------------------------------------------------------- rétention des journaux (v33 : purge contrôlée)
SELECT pg_temp.t('P26 entrée ancienne dans ChangeAuditLog (jeu de test de rétention)',
  $q$INSERT INTO ChangeAuditLog (table_name, record_id, action_code, actor_id, actor_type_code, occurred_at)
     VALUES ('Customer','old','update','test','system','2020-01-15')$q$);
SELECT pg_temp.t('P27 purge de rétention par stripe_retention',
  $q$SELECT purge_expired_log('ChangeAuditLog', interval '1 year')$q$, '00000', 'stripe_retention');
SELECT pg_temp.t('P28 l''entrée ancienne a disparu',
  $q$DO $d$ BEGIN IF EXISTS (SELECT 1 FROM ChangeAuditLog WHERE occurred_at < '2021-01-01') THEN RAISE EXCEPTION 'old entry still there'; END IF; END $d$$q$);
SELECT pg_temp.t('P29 les entrées récentes sont conservées',
  $q$DO $d$ BEGIN IF NOT EXISTS (SELECT 1 FROM ChangeAuditLog WHERE occurred_at > now() - interval '1 day') THEN RAISE EXCEPTION 'recent entries purged'; END IF; END $d$$q$);
SELECT pg_temp.t('N43 purge refusée sur FraudScoringLog', $q$SELECT purge_expired_log('FraudScoringLog', interval '1 year')$q$, 'P0001', 'stripe_retention');
SELECT pg_temp.t('N44 stripe_retention ne peut pas supprimer directement (privilège)', $q$DELETE FROM ChangeAuditLog$q$, '42501', 'stripe_retention');
SELECT pg_temp.t('N45 stripe_app ne peut pas appeler la purge', $q$SELECT purge_expired_log('ChangeAuditLog', interval '1 year')$q$, '42501', 'stripe_app');
SELECT pg_temp.t('N46 DELETE direct refusé par le trigger, même pour le propriétaire', $q$DELETE FROM DataAccessLog$q$, '23001');
SELECT pg_temp.t('N47 indicateur de purge positionné à la main : le privilège DELETE reste requis',
  $q$SET LOCAL stripe.retention_purge = 'on'; DELETE FROM ChangeAuditLog$q$, '42501', 'stripe_app');

-- ---------------------------------------------------------------- FraudScore -> FraudScoringLog : même transaction (v33)
SELECT pg_temp.t('N25b FraudScore pointant vers l''entrée de journal d''une AUTRE transaction',
  format($q$INSERT INTO FraudScore (transaction_id, fraud_scoring_logentry_id, anomaly_score, risk_level_code, model_version)
            VALUES (%L, '00000000-0000-7000-8000-0000000f0001', 0.9100, 'high', 'v1')$q$,
         '00000000-0000-7000-8000-000000000002'), '23503');

-- ---------------------------------------------------------------- bilan
\o
\echo
SELECT ok AS passed, count(*) FROM test_result GROUP BY ok ORDER BY ok;
\echo
-- contrôle de complétude : un test qui lève une erreur hors de son sous-bloc n'est PAS enregistré ; recorded doit égaler expected
-- (expected = nombre de lignes « SELECT pg_temp.t( » du fichier : à mettre à jour avec les tests)
SELECT count(*) AS recorded, 89 AS expected, count(*) = 89 AS complete FROM test_result;
\o
\echo
SELECT label, expected, got FROM test_result WHERE NOT ok ORDER BY n;
