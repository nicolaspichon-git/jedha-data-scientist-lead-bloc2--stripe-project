-- =====================================================================
-- STRIPE PROJECT - Annexe 1.B (OLTP) - DDL complémentaire : 02_complement.sql
-- Version : v36 - à exécuter APRÈS 01_schema.sql, dans une seule session (propriétaire = rôle de migration).
--
-- Ce fichier porte ce que DBML ne peut pas exprimer :
--   1. Extension et fonctions utilitaires          6. Remplacement d'index par leurs versions partielles
--   2. Contraintes CHECK                           7. Immutabilité des journaux (triggers)
--   3. Exclusion : non-chevauchement des plans     8. Publication CDC (et exclusion de ChangeAuditLog)
--   4. Contrainte différée : remboursement         9. Pseudonymisation RGPD
--   5. Index partiels                              10. Rôles et privilèges ; 11. Vues de contrôle ; 12. Rétention
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Extension et fonctions
-- ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Commission Stripe en unités mineures : ROUND(amount x commission_rate) + fixed_fee.
-- Arrondi demi-supérieur (numeric : arrondi à l'entier le plus éloigné de zéro pour .5). Règle de référence unique :
-- tout recalcul (contrôle, OLAP, rapprochement) doit l'utiliser.
CREATE OR REPLACE FUNCTION stripe_fee(p_amount bigint, p_commission_rate numeric, p_fixed_fee bigint)
RETURNS bigint LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT round(p_amount * p_commission_rate)::bigint + p_fixed_fee $$;

-- ---------------------------------------------------------------------
-- 2. Contraintes CHECK
-- ---------------------------------------------------------------------
ALTER TABLE Currency
  ADD CONSTRAINT ck_currency_decimals CHECK (decimals BETWEEN 0 AND 4);

ALTER TABLE Product
  ADD CONSTRAINT ck_product_unit_price CHECK (unit_price >= 0);

ALTER TABLE PricingPlan
  ADD CONSTRAINT ck_plan_commission_rate CHECK (commission_rate >= 0 AND commission_rate < 1),
  ADD CONSTRAINT ck_plan_effective_range CHECK (effective_to IS NULL OR effective_to > effective_from);

ALTER TABLE PricingPlanFee
  ADD CONSTRAINT ck_planfee_fixed_fee CHECK (fixed_fee >= 0);

-- Moyen de paiement : une carte porte ses détails ; les autres types non. (Version littérale de
-- PaymentMethodType.requires_card_details, qui est une donnée et ne peut pas être référencée par un CHECK.)
ALTER TABLE PaymentMethod
  ADD CONSTRAINT ck_pm_card_details CHECK (
    (type_code = 'card' AND network_code IS NOT NULL AND card_last4 IS NOT NULL AND expiry IS NOT NULL)
    OR (type_code <> 'card' AND network_code IS NULL AND card_last4 IS NULL AND expiry IS NULL)),
  ADD CONSTRAINT ck_pm_last4_digits CHECK (card_last4 IS NULL OR card_last4 ~ '^[0-9]{4}$');

ALTER TABLE Subscription
  ADD CONSTRAINT ck_sub_billing_cycle CHECK (billing_cycle IN ('weekly','monthly','yearly')),
  ADD CONSTRAINT ck_sub_amount CHECK (amount > 0),
  ADD CONSTRAINT ck_sub_failed_attempts CHECK (failed_attempt_count >= 0),
  ADD CONSTRAINT ck_sub_canceled_after_start CHECK (canceled_at IS NULL OR canceled_at >= started_at);

ALTER TABLE Transaction
  ADD CONSTRAINT ck_txn_amount CHECK (amount > 0),
  ADD CONSTRAINT ck_txn_fee CHECK (fee_amount >= 0),
  ADD CONSTRAINT ck_txn_device CHECK (device_type IS NULL OR device_type IN ('mobile','desktop','tablet')),
  -- MCD règle #8 : un prélèvement d'abonnement porte toujours son produit ; is_merchant_initiated est dérivé du lien.
  ADD CONSTRAINT ck_txn_subscription_has_product CHECK (subscription_id IS NULL OR product_id IS NOT NULL),
  ADD CONSTRAINT ck_txn_merchant_initiated CHECK (is_merchant_initiated = (subscription_id IS NOT NULL));

ALTER TABLE Refund
  ADD CONSTRAINT ck_refund_amount CHECK (amount > 0);

ALTER TABLE Chargeback
  ADD CONSTRAINT ck_chargeback_resolved CHECK (resolved_at IS NULL OR resolved_at >= created_at),
  ADD CONSTRAINT ck_chargeback_due CHECK (due_at IS NULL OR due_at > created_at);

ALTER TABLE ChargebackReasonCode
  ADD CONSTRAINT ck_cbrc_category CHECK (category IS NULL OR category IN ('fraud','authorization','processing_error','consumer_dispute'));

ALTER TABLE CardNetworkPolicy
  ADD CONSTRAINT ck_cnp_deadline CHECK (response_deadline_days > 0);

ALTER TABLE FraudScoringLog
  ADD CONSTRAINT ck_fsl_model_role CHECK (model_role IN ('production','staging')),
  ADD CONSTRAINT ck_fsl_score CHECK (anomaly_score BETWEEN 0 AND 1);

ALTER TABLE FraudScore
  ADD CONSTRAINT ck_fs_score CHECK (anomaly_score BETWEEN 0 AND 1);

ALTER TABLE FraudReview
  -- liste ouverte (« ... » dans le DBML) : on contraint le format, pas les valeurs
  ADD CONSTRAINT ck_fr_reason CHECK (reason ~ '^[a-z][a-z_]*$'),
  ADD CONSTRAINT ck_fr_outcome CHECK (outcome IN ('fraud','legitimate','inconclusive'));

ALTER TABLE FraudDecision
  ADD CONSTRAINT ck_fd_value  CHECK (decision_value IN ('legitimate','fraud')),
  ADD CONSTRAINT ck_fd_status CHECK (decision_status IN ('defaulted','confirmed')),
  -- MCD règle #41 : defaulted => horodatage de défaut, pas de confirmation ; confirmed => horodatage de confirmation
  ADD CONSTRAINT ck_fd_status_timestamps CHECK (
    (decision_status = 'defaulted' AND defaulted_at IS NOT NULL AND confirmed_at IS NULL)
    OR (decision_status = 'confirmed' AND confirmed_at IS NOT NULL)),
  -- une décision rattachée à une revue est nécessairement confirmée
  ADD CONSTRAINT ck_fd_review_implies_confirmed CHECK (source_review_id IS NULL OR decision_status = 'confirmed');

ALTER TABLE ConsentRecord
  ADD CONSTRAINT ck_consent_purpose CHECK (purpose IN ('marketing','analytics','data_sharing','profiling')),
  ADD CONSTRAINT ck_consent_source CHECK (source IS NULL OR source IN ('checkout','email','account_settings')),
  ADD CONSTRAINT ck_consent_legal_basis CHECK (legal_basis IS NULL OR legal_basis IN ('consent','contract','legitimate_interest'));

ALTER TABLE DataSubjectRequest
  ADD CONSTRAINT ck_dsr_type CHECK (request_type IN ('access','rectification','erasure','portability','objection')),
  ADD CONSTRAINT ck_dsr_due_after_received CHECK (due_at > received_at),
  ADD CONSTRAINT ck_dsr_fulfilled_after_received CHECK (fulfilled_at IS NULL OR fulfilled_at >= received_at);

ALTER TABLE SecurityIncident
  ADD CONSTRAINT ck_si_type CHECK (incident_type IN ('unauthorized_access','data_breach','anomalous_activity','failed_auth_burst')),
  ADD CONSTRAINT ck_si_severity CHECK (severity IN ('low','medium','high','critical')),
  ADD CONSTRAINT ck_si_notified CHECK (notified_at IS NULL OR notified_at >= detected_at),
  ADD CONSTRAINT ck_si_count CHECK (affected_record_count IS NULL OR affected_record_count >= 0);

-- ---------------------------------------------------------------------
-- 3. MCD règle #21 : un seul plan en vigueur par marchand (non-chevauchement des périodes [from, to))
--    Contrairement à ce qu'affirmait l'Annexe C, c'est exprimable de façon déclarative.
-- ---------------------------------------------------------------------
ALTER TABLE PricingPlan
  ADD CONSTRAINT ex_plan_no_overlap
  EXCLUDE USING gist (merchant_id WITH =, daterange(effective_from, effective_to) WITH &&);

-- ---------------------------------------------------------------------
-- 4. Remboursement <= montant de la transaction (contrainte différée : vérifiée au COMMIT, hors chemin critique)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_refund_amount() RETURNS trigger LANGUAGE plpgsql AS $fn$
DECLARE
  v_amount bigint;
BEGIN
  SELECT t.amount INTO v_amount
  FROM Transaction t
  WHERE t.transaction_id = NEW.transaction_id;
  IF NEW.amount > v_amount THEN
    RAISE EXCEPTION 'refund % (%) exceeds transaction amount (%)', NEW.refund_id, NEW.amount, v_amount
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END
$fn$;

CREATE CONSTRAINT TRIGGER ct_refund_amount
  AFTER INSERT OR UPDATE OF amount, transaction_id ON Refund
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION check_refund_amount();

-- ---------------------------------------------------------------------
-- 5. Index partiels (ce que DBML ne peut pas exprimer)
-- ---------------------------------------------------------------------
-- un seul moyen de paiement par défaut par client
CREATE UNIQUE INDEX uq_paymentmethod_one_default ON PaymentMethod (customer_id) WHERE is_default;

-- MCD : Subscribes est une association (client, produit) : un seul abonnement non résilié par couple
CREATE UNIQUE INDEX uq_subscription_one_open_per_product ON Subscription (customer_id, product_id) WHERE status_code <> 'canceled';

-- transactions en attente / suspendues (balayage de traitement, supervision)
CREATE INDEX ix_transaction_open_status ON Transaction (created_at) WHERE status_code IN ('pending','suspended');

-- ---------------------------------------------------------------------
-- 6. Index remplacés par leurs versions partielles (plus petits, ciblent la fraction utile)
-- ---------------------------------------------------------------------
DROP INDEX ix_dal_was_authorized;
CREATE INDEX ix_dal_denied ON DataAccessLog (occurred_at) WHERE NOT was_authorized;

DROP INDEX ix_subscription_period_end;
CREATE INDEX ix_subscription_due ON Subscription (current_period_end) WHERE status_code IN ('active','past_due');

-- ---------------------------------------------------------------------
-- 7. Immutabilité : aucun UPDATE / DELETE / TRUNCATE sur les journaux et tables immuables
--    Défense en profondeur avec les privilèges (§10). Un superuser peut toujours contourner :
--    l'exploitation ne doit jamais se connecter en superuser pour de l'applicatif.
--    Seule exception : DELETE sur DataAccessLog / ChangeAuditLog, uniquement via purge_expired_log() (§12), qui
--    positionne un indicateur local à la transaction ; le privilège DELETE reste, lui, réservé au propriétaire.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prevent_mutation() RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  IF TG_OP = 'DELETE' AND TG_TABLE_NAME IN ('dataaccesslog', 'changeauditlog')
     AND current_setting('stripe.retention_purge', true) = 'on' THEN
    RETURN OLD;   -- purge de rétention (purge_expired_log)
  END IF;
  RAISE EXCEPTION 'table % is append-only: % refused', TG_TABLE_NAME, TG_OP USING ERRCODE = 'restrict_violation';
END
$fn$;

DO $do$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['DataAccessLog','ChangeAuditLog','FraudScoringLog','FraudScore','ConsentRecord'] LOOP
    EXECUTE format('CREATE TRIGGER trg_%1$s_immutable BEFORE UPDATE OR DELETE ON %1$s FOR EACH ROW EXECUTE FUNCTION prevent_mutation()', t);
    EXECUTE format('CREATE TRIGGER trg_%1$s_no_truncate BEFORE TRUNCATE ON %1$s FOR EACH STATEMENT EXECUTE FUNCTION prevent_mutation()', t);
  END LOOP;
END
$do$;

-- ---------------------------------------------------------------------
-- 8. CDC : publication logique (Debezium / pgoutput)
--    ChangeAuditLog et DataAccessLog sont EXCLUES : ChangeAuditLog est alimentée PAR le flux CDC ; l'inclure créerait
--    une boucle (écriture -> WAL -> CDC -> écriture). IdempotencyKey est opérationnelle et exclue.
--    Prérequis serveur : wal_level = logical, max_replication_slots, max_wal_senders.
--    REPLICA IDENTITY FULL sur les tables mutables : nécessaire pour renseigner « avant » dans
--    ChangeAuditLog.changed_fields (coût WAL accru, acceptable : tables peu mises à jour).
-- ---------------------------------------------------------------------
CREATE PUBLICATION stripe_cdc FOR TABLE
  Merchant, Product, PricingPlan, PricingPlanFee, Customer, PaymentMethod, Subscription,
  Transaction, Refund, Chargeback, FraudScoringLog, FraudScore, FraudReview, FraudDecision,
  ConsentRecord, DataSubjectRequest, SecurityIncident;

DO $do$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['Merchant','Product','PricingPlan','PricingPlanFee','Customer','PaymentMethod','Subscription',
                           'Transaction','Refund','Chargeback','FraudReview','FraudDecision','DataSubjectRequest','SecurityIncident'] LOOP
    EXECUTE format('ALTER TABLE %s REPLICA IDENTITY FULL', t);
  END LOOP;
END
$do$;

-- ---------------------------------------------------------------------
-- 9. Pseudonymisation RGPD (droit à l'effacement) sur les tables MUTABLES
--    Les journaux immuables ne doivent contenir AUCUN identifiant direct : ChangeAuditLog.changed_fields et
--    FraudScoringLog.features doivent être pseudonymisés À L'ÉCRITURE (transformation dans le flux CDC / le service
--    de scoring), faute de quoi seul le crypto-shredding (clé par client détruite) permet d'honorer l'effacement.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pseudonymize_customer(p_customer_id uuid, p_actor text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  UPDATE Customer
     SET email = 'erased-' || customer_id::text || '@invalid.invalid',
         updated_by = p_actor, updater_type = 'service'   -- country_code conservé (NOT NULL ; un pays seul n'identifie pas la personne)
   WHERE customer_id = p_customer_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'customer % not found', p_customer_id;
  END IF;
  UPDATE PaymentMethod
     SET token_reference = 'erased:' || payment_method_id::text, fingerprint = NULL,
         is_default = false, updated_by = p_actor, updater_type = 'service'
   WHERE customer_id = p_customer_id;
END
$fn$;
REVOKE ALL ON FUNCTION pseudonymize_customer(uuid, text) FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 10. Rôles et privilèges (groupes NOLOGIN ; les comptes de service héritent de ces groupes)
--     Le propriétaire des objets doit être un rôle de migration sans accès applicatif.
-- ---------------------------------------------------------------------
DO $do$
DECLARE
  r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['stripe_app','stripe_log_writer','stripe_readonly','stripe_cdc','stripe_retention'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
    END IF;
  END LOOP;
END
$do$;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO stripe_app, stripe_log_writer, stripe_readonly, stripe_cdc, stripe_retention;

-- lecture générale
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stripe_readonly, stripe_cdc;

-- application : lecture partout, écriture sur les tables métier, JAMAIS de DELETE
GRANT SELECT ON ALL TABLES IN SCHEMA public TO stripe_app;
GRANT INSERT, UPDATE ON Merchant, Product, PricingPlan, PricingPlanFee, Customer, PaymentMethod, Subscription,
  Transaction, Refund, Chargeback, FraudReview, FraudDecision, DataSubjectRequest, SecurityIncident TO stripe_app;
GRANT INSERT ON IdempotencyKey, FraudScore, ConsentRecord TO stripe_app;   -- immuables / opérationnelle : pas d'UPDATE

-- écrivains de journaux : INSERT seul (alimentation asynchrone)
GRANT INSERT ON DataAccessLog, ChangeAuditLog, FraudScoringLog TO stripe_log_writer;
GRANT SELECT ON FraudRiskLevel, AuditAction, AuditActorType TO stripe_log_writer;

-- purge opérationnelle des clés d'idempotence ; les journaux ne sont purgés que par purge_expired_log() (§12)
GRANT SELECT, DELETE ON IdempotencyKey TO stripe_retention;

-- ---------------------------------------------------------------------
-- 11. Vues de contrôle (auditables, exécutables en lecture seule sur une réplique ou en OLAP)
-- ---------------------------------------------------------------------
-- fee_amount stocké vs recalculé : un écart signale un plan corrigé rétroactivement (Annexe C §1.C.2)
CREATE VIEW v_fee_discrepancy AS
SELECT t.transaction_id, t.created_at, t.merchant_id, t.currency_code,
       t.fee_amount AS stored_fee,
       stripe_fee(t.amount, p.commission_rate, f.fixed_fee) AS expected_fee
FROM Transaction t
JOIN PricingPlan    p ON p.pricing_plan_id = t.pricing_plan_id
JOIN PricingPlanFee f ON f.pricing_plan_id = t.pricing_plan_id AND f.currency_code = t.currency_code
WHERE t.fee_amount <> stripe_fee(t.amount, p.commission_rate, f.fixed_fee);

-- DataSubjectRequest.due_at doit valoir received_at + Regulation.response_deadline_days
CREATE VIEW v_dsr_due_discrepancy AS
SELECT r.request_id, r.received_at, r.due_at,
       r.received_at + make_interval(days => g.response_deadline_days) AS expected_due_at
FROM DataSubjectRequest r JOIN Regulation g ON g.regulation_code = r.regulation_code
WHERE r.due_at <> r.received_at + make_interval(days => g.response_deadline_days);

-- Chargeback.due_at doit valoir created_at + CardNetworkPolicy.response_deadline_days du réseau du motif (NULL si le réseau n'a pas de politique)
CREATE VIEW v_chargeback_due_discrepancy AS
SELECT c.chargeback_id, c.created_at, c.due_at,
       c.created_at + make_interval(days => p.response_deadline_days) AS expected_due_at
FROM Chargeback c
JOIN ChargebackReasonCode rc ON rc.reason_code = c.reason_code
LEFT JOIN CardNetworkPolicy p ON p.network_code = rc.network_code
WHERE c.due_at IS DISTINCT FROM c.created_at + make_interval(days => p.response_deadline_days);

-- statut 'refunded' vs présence d'un Refund : deux sources de la même information (à trancher, cf. CHANGELOG)
CREATE VIEW v_refund_status_mismatch AS
SELECT t.transaction_id, t.created_at, t.status_code, (r.refund_id IS NOT NULL) AS has_refund
FROM Transaction t LEFT JOIN Refund r ON r.transaction_id = t.transaction_id
WHERE (t.status_code = 'refunded') <> (r.refund_id IS NOT NULL);

GRANT SELECT ON v_fee_discrepancy, v_dsr_due_discrepancy, v_chargeback_due_discrepancy, v_refund_status_mismatch TO stripe_readonly;

-- ---------------------------------------------------------------------
-- 12. Rétention des journaux : purge contrôlée (seule voie autorisée pour supprimer des lignes d'un journal)
--     Sans partitionnement, la purge est un DELETE par lots : elle génère du WAL et des lignes mortes
--     (VACUUM), à exécuter hors pointe et par lots (p_batch) jusqu'à ce que la fonction renvoie 0.
--     SECURITY DEFINER : exécutable par stripe_retention sans être propriétaire des tables.
--     Ne supprime que les lignes plus anciennes que la durée de rétention passée en paramètre.
--     Tables admises : DataAccessLog, ChangeAuditLog. FraudScoringLog est exclue : FraudScore la référence par FK ;
--     sa rétention suit l'archivage des transactions.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION purge_expired_log(p_table regclass, p_retention interval, p_batch integer DEFAULT 10000)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_deleted bigint;
BEGIN
  IF p_table::text NOT IN ('dataaccesslog', 'changeauditlog') THEN
    RAISE EXCEPTION 'retention purge only allowed on DataAccessLog / ChangeAuditLog, not on %', p_table;
  END IF;
  IF p_retention IS NULL OR p_retention <= interval '0' OR p_batch IS NULL OR p_batch <= 0 THEN
    RAISE EXCEPTION 'invalid retention (%) or batch size (%)', p_retention, p_batch;
  END IF;
  PERFORM set_config('stripe.retention_purge', 'on', true);   -- local à la transaction
  EXECUTE format(
    'WITH d AS (SELECT logentry_id FROM %s WHERE occurred_at < now() - $1 ORDER BY occurred_at LIMIT $2) '
    'DELETE FROM %s t USING d WHERE t.logentry_id = d.logentry_id', p_table::text, p_table::text)
    USING p_retention, p_batch;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  PERFORM set_config('stripe.retention_purge', 'off', true);
  RETURN v_deleted;
END
$fn$;
REVOKE ALL ON FUNCTION purge_expired_log(regclass, interval, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION purge_expired_log(regclass, interval, integer) TO stripe_retention;
