-- =====================================================================
-- STRIPE PROJECT - Annexe 1.B (OLTP) - DDL de base : 01_schema.sql
-- Version : v36 - cible PostgreSQL 16+ (UUID v7 natif en 18 ; fonction de repli fournie pour 16/17)
--
-- Contenu : tables, types, PK, UNIQUE, FK (simples et composites), index du DBML v36 (aucune table partitionnée).
-- Les contraintes que DBML ne sait pas exprimer (CHECK, EXCLUDE, index partiels, immutabilité, privilèges,
-- publication CDC) sont dans 02_complement.sql, à exécuter ensuite.
--
-- Ce fichier est écrit à la main (dbml2sql n'a pas pu être installé) ; sa cohérence avec stripe-oltp-v36.dbml
-- est vérifiée par scripts/check_consistency.py (tables, colonnes, PK, ensemble des FK).
-- Identifiants non quotés : PostgreSQL les replie en minuscules (Transaction -> transaction).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Repli uuidv7() pour PostgreSQL < 18 (sans effet si la fonction native existe)
-- ---------------------------------------------------------------------
DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE p.proname = 'uuidv7' AND n.nspname = 'pg_catalog') THEN
    EXECUTE $f$
      CREATE OR REPLACE FUNCTION public.uuidv7() RETURNS uuid LANGUAGE sql VOLATILE PARALLEL SAFE AS $body$
        SELECT encode(
          set_bit(set_bit(
            overlay(uuid_send(gen_random_uuid())
                    PLACING substring(int8send(floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint) FROM 3)
                    FROM 1 FOR 6),
            52, 1), 53, 1),
          'hex')::uuid
      $body$
    $f$;
  END IF;
END
$do$;

-- ---------------------------------------------------------------------
-- 1. Référentiels
-- ---------------------------------------------------------------------
CREATE TABLE Country (
  country_code varchar(2) PRIMARY KEY,
  name         varchar(100) NOT NULL,
  region       varchar(50)
);

CREATE TABLE Currency (
  currency_code varchar(3) PRIMARY KEY,
  name          varchar(50) NOT NULL,
  decimals      smallint NOT NULL DEFAULT 2
);

CREATE TABLE AuditActorType (
  actor_type_code varchar(20) PRIMARY KEY,
  label           varchar(100) NOT NULL,
  is_human        boolean,
  is_active       boolean NOT NULL DEFAULT true
);

CREATE TABLE AuditAction (
  action_code            varchar(30) PRIMARY KEY,
  label                  varchar(100) NOT NULL,
  is_sensitive           boolean NOT NULL DEFAULT false,
  requires_justification boolean NOT NULL DEFAULT false,
  is_active              boolean NOT NULL DEFAULT true
);

-- ---------------------------------------------------------------------
-- 2. Marchands, produits, tarification
-- ---------------------------------------------------------------------
CREATE TABLE MerchantStatus (
  status_code          varchar(20) PRIMARY KEY,
  label                varchar(100) NOT NULL,
  can_process_payments boolean NOT NULL DEFAULT false,
  sort_order           smallint,
  is_active            boolean NOT NULL DEFAULT true
);

CREATE TABLE Merchant (
  merchant_id  uuid PRIMARY KEY DEFAULT uuidv7(),
  legal_name   varchar(255) NOT NULL,
  country_code varchar(2)  NOT NULL REFERENCES Country (country_code),
  status_code  varchar(20) NOT NULL DEFAULT 'active' REFERENCES MerchantStatus (status_code),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   varchar(255) NOT NULL,
  updater_type varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code)
);
CREATE INDEX ix_merchant_country ON Merchant (country_code);
CREATE INDEX ix_merchant_status  ON Merchant (status_code);

CREATE TABLE Product (
  product_id    uuid PRIMARY KEY DEFAULT uuidv7(),
  merchant_id   uuid NOT NULL REFERENCES Merchant (merchant_id),
  name          varchar(255) NOT NULL,
  unit_price    bigint NOT NULL,
  currency_code varchar(3) NOT NULL REFERENCES Currency (currency_code),
  active        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_by    varchar(255) NOT NULL,
  updater_type  varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT uq_product_merchant_product UNIQUE (merchant_id, product_id)
);
CREATE INDEX ix_product_merchant ON Product (merchant_id);

CREATE TABLE PricingPlan (
  pricing_plan_id uuid PRIMARY KEY DEFAULT uuidv7(),
  merchant_id     uuid NOT NULL REFERENCES Merchant (merchant_id),
  commission_rate numeric(5,4) NOT NULL,
  effective_from  date NOT NULL,
  effective_to    date,
  updated_by      varchar(255) NOT NULL,
  updater_type    varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT uq_plan_merchant_plan UNIQUE (merchant_id, pricing_plan_id)
);
CREATE INDEX ix_pricingplan_merchant_from ON PricingPlan (merchant_id, effective_from);

CREATE TABLE PricingPlanFee (
  pricing_plan_id uuid NOT NULL REFERENCES PricingPlan (pricing_plan_id),
  currency_code   varchar(3) NOT NULL REFERENCES Currency (currency_code),
  fixed_fee       bigint NOT NULL,
  updated_by      varchar(255) NOT NULL,
  updater_type    varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  PRIMARY KEY (pricing_plan_id, currency_code)
);

-- ---------------------------------------------------------------------
-- 3. Clients, moyens de paiement, abonnements
-- ---------------------------------------------------------------------
CREATE TABLE Customer (
  customer_id  uuid PRIMARY KEY DEFAULT uuidv7(),
  merchant_id  uuid NOT NULL REFERENCES Merchant (merchant_id),
  email        varchar(320) NOT NULL,
  country_code varchar(2) NOT NULL REFERENCES Country (country_code),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   varchar(255) NOT NULL,
  updater_type varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT uq_customer_merchant_customer UNIQUE (merchant_id, customer_id)
);
CREATE UNIQUE INDEX uq_customer_merchant_email_ci ON Customer (merchant_id, lower(email));

CREATE TABLE PaymentMethodType (
  type_code             varchar(20) PRIMARY KEY,
  label                 varchar(100) NOT NULL,
  requires_card_details boolean NOT NULL DEFAULT false,
  sort_order            smallint,
  is_active             boolean NOT NULL DEFAULT true
);

CREATE TABLE CardNetwork (
  network_code varchar(20) PRIMARY KEY,
  label      varchar(100) NOT NULL,
  is_active  boolean NOT NULL DEFAULT true
);

CREATE TABLE PaymentMethod (
  payment_method_id uuid PRIMARY KEY DEFAULT uuidv7(),
  customer_id       uuid NOT NULL REFERENCES Customer (customer_id),
  type_code         varchar(20) NOT NULL REFERENCES PaymentMethodType (type_code),
  network_code      varchar(20) REFERENCES CardNetwork (network_code),
  card_last4        char(4),
  expiry            date,
  token_reference   varchar(255) NOT NULL,
  fingerprint       varchar(64),
  is_default        boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_by        varchar(255) NOT NULL,
  updater_type      varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT uq_pm_customer_pm UNIQUE (customer_id, payment_method_id)
);
CREATE INDEX ix_paymentmethod_customer    ON PaymentMethod (customer_id);
CREATE UNIQUE INDEX uq_paymentmethod_token ON PaymentMethod (token_reference);
CREATE INDEX ix_paymentmethod_fingerprint ON PaymentMethod (fingerprint);

CREATE TABLE SubscriptionStatus (
  status_code      varchar(20) PRIMARY KEY,
  label            varchar(100) NOT NULL,
  is_billable      boolean NOT NULL DEFAULT false,
  is_terminal      boolean NOT NULL DEFAULT false,
  triggers_dunning boolean NOT NULL DEFAULT false,
  sort_order       smallint,
  is_active        boolean NOT NULL DEFAULT true
);

CREATE TABLE Subscription (
  subscription_id      uuid PRIMARY KEY DEFAULT uuidv7(),
  merchant_id          uuid NOT NULL,
  customer_id          uuid NOT NULL,
  product_id           uuid NOT NULL,
  payment_method_id    uuid NOT NULL,
  status_code          varchar(20) NOT NULL DEFAULT 'active' REFERENCES SubscriptionStatus (status_code),
  billing_cycle        varchar(20) NOT NULL,
  amount               bigint NOT NULL,
  currency_code        varchar(3) NOT NULL REFERENCES Currency (currency_code),
  started_at           timestamptz NOT NULL DEFAULT now(),
  current_period_end   timestamptz,
  canceled_at          timestamptz,
  failed_attempt_count smallint NOT NULL DEFAULT 0,
  updated_by           varchar(255) NOT NULL,
  updater_type         varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT uq_sub_customer_sub_product UNIQUE (customer_id, subscription_id, product_id),
  CONSTRAINT fk_subscription_customer FOREIGN KEY (merchant_id, customer_id)
    REFERENCES Customer (merchant_id, customer_id),
  CONSTRAINT fk_subscription_product FOREIGN KEY (merchant_id, product_id)
    REFERENCES Product (merchant_id, product_id),
  CONSTRAINT fk_subscription_payment_method FOREIGN KEY (customer_id, payment_method_id)
    REFERENCES PaymentMethod (customer_id, payment_method_id)
);
CREATE INDEX ix_subscription_customer       ON Subscription (customer_id);
CREATE INDEX ix_subscription_product        ON Subscription (product_id);
CREATE INDEX ix_subscription_payment_method ON Subscription (payment_method_id);
CREATE INDEX ix_subscription_status         ON Subscription (status_code);
CREATE INDEX ix_subscription_period_end     ON Subscription (current_period_end);

-- ---------------------------------------------------------------------
-- 4. Transactions
-- ---------------------------------------------------------------------
CREATE TABLE TransactionStatus (
  status_code  varchar(20) PRIMARY KEY,
  label        varchar(100) NOT NULL,
  is_terminal  boolean NOT NULL DEFAULT false,
  allows_refund boolean NOT NULL DEFAULT false,
  sort_order   smallint,
  is_active    boolean NOT NULL DEFAULT true
);

CREATE TABLE Transaction (
  transaction_id        uuid PRIMARY KEY DEFAULT uuidv7(),
  merchant_id           uuid NOT NULL,
  customer_id           uuid NOT NULL,
  payment_method_id     uuid NOT NULL,
  product_id            uuid,
  subscription_id       uuid,
  pricing_plan_id       uuid NOT NULL,
  is_merchant_initiated boolean NOT NULL DEFAULT false,
  amount                bigint NOT NULL,
  fee_amount            bigint NOT NULL,
  currency_code         varchar(3)  NOT NULL REFERENCES Currency (currency_code),
  status_code           varchar(20) NOT NULL REFERENCES TransactionStatus (status_code),
  ip_geolocation        varchar(45),
  device_type           varchar(20),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_by            varchar(255) NOT NULL,
  updater_type          varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT fk_transaction_customer FOREIGN KEY (merchant_id, customer_id)
    REFERENCES Customer (merchant_id, customer_id),
  CONSTRAINT fk_transaction_payment_method FOREIGN KEY (customer_id, payment_method_id)
    REFERENCES PaymentMethod (customer_id, payment_method_id),
  CONSTRAINT fk_transaction_product FOREIGN KEY (merchant_id, product_id)
    REFERENCES Product (merchant_id, product_id),
  CONSTRAINT fk_transaction_subscription FOREIGN KEY (customer_id, subscription_id, product_id)
    REFERENCES Subscription (customer_id, subscription_id, product_id),
  CONSTRAINT fk_transaction_pricing_plan FOREIGN KEY (merchant_id, pricing_plan_id)
    REFERENCES PricingPlan (merchant_id, pricing_plan_id),
  CONSTRAINT fk_transaction_pricing_plan_fee FOREIGN KEY (pricing_plan_id, currency_code)
    REFERENCES PricingPlanFee (pricing_plan_id, currency_code)
);
CREATE INDEX ix_transaction_merchant_created ON Transaction (merchant_id, created_at);
CREATE INDEX ix_transaction_customer_created ON Transaction (customer_id, created_at);
CREATE INDEX ix_transaction_payment_method   ON Transaction (payment_method_id);
CREATE INDEX ix_transaction_product          ON Transaction (product_id);
CREATE INDEX ix_transaction_subscription     ON Transaction (subscription_id);
CREATE INDEX ix_transaction_created          ON Transaction (created_at);

CREATE TABLE IdempotencyKey (
  merchant_id            uuid NOT NULL REFERENCES Merchant (merchant_id),
  idempotency_key        varchar(255) NOT NULL,
  transaction_id         uuid NOT NULL,
  created_at             timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (merchant_id, idempotency_key),
  CONSTRAINT fk_idempotency_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX ix_idempotencykey_created ON IdempotencyKey (created_at);

-- ---------------------------------------------------------------------
-- 5. Entités dépendantes de la transaction
-- ---------------------------------------------------------------------
CREATE TABLE Refund (
  refund_id              uuid PRIMARY KEY DEFAULT uuidv7(),
  transaction_id         uuid NOT NULL UNIQUE,
  amount                 bigint NOT NULL,
  reason                 varchar(255),
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_by             varchar(255) NOT NULL,
  updater_type           varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT fk_refund_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id)
);

CREATE TABLE ChargebackStatus (
  status_code varchar(20) PRIMARY KEY,
  label       varchar(100) NOT NULL,
  is_terminal boolean NOT NULL DEFAULT false,
  sort_order  smallint,
  is_active   boolean NOT NULL DEFAULT true
);

CREATE TABLE CardNetworkPolicy (
  network_code           varchar(20) PRIMARY KEY REFERENCES CardNetwork (network_code),
  response_deadline_days smallint NOT NULL
);

CREATE TABLE ChargebackReasonCode (
  reason_code            varchar(20) PRIMARY KEY,
  network_code           varchar(20) NOT NULL REFERENCES CardNetwork (network_code),
  label                  varchar(255) NOT NULL,
  category               varchar(50),
  is_active              boolean NOT NULL DEFAULT true
);

CREATE TABLE Chargeback (
  chargeback_id          uuid PRIMARY KEY DEFAULT uuidv7(),
  transaction_id         uuid NOT NULL UNIQUE,
  reason_code            varchar(20) NOT NULL REFERENCES ChargebackReasonCode (reason_code),
  status_code            varchar(20) NOT NULL DEFAULT 'open' REFERENCES ChargebackStatus (status_code),
  created_at             timestamptz NOT NULL DEFAULT now(),
  due_at                 timestamptz,
  resolved_at            timestamptz,
  updated_by             varchar(255) NOT NULL,
  updater_type           varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT fk_chargeback_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id)
);
CREATE INDEX ix_chargeback_status ON Chargeback (status_code);
CREATE INDEX ix_chargeback_reason ON Chargeback (reason_code);

-- ---------------------------------------------------------------------
-- 6. Fraude
-- ---------------------------------------------------------------------
CREATE TABLE FraudRiskLevel (
  risk_level_code        varchar(10) PRIMARY KEY,
  label                  varchar(50) NOT NULL,
  requires_manual_review boolean NOT NULL DEFAULT false,
  blocks_transaction     boolean NOT NULL DEFAULT false,
  sort_order             smallint,
  is_active              boolean NOT NULL DEFAULT true
);

-- Journal append-only (rétention alignée sur la transaction : FraudScore le référence)
CREATE TABLE FraudScoringLog (
  fraud_scoring_logentry_id uuid PRIMARY KEY DEFAULT uuidv7(),
  transaction_id         uuid NOT NULL,
  model_version          varchar(20) NOT NULL,
  model_role             varchar(20) NOT NULL,
  features               jsonb NOT NULL,
  anomaly_score          numeric(5,4) NOT NULL,
  risk_level_code        varchar(10) NOT NULL REFERENCES FraudRiskLevel (risk_level_code),
  evaluated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_fsl_txn_model UNIQUE (transaction_id, model_version, model_role),
  CONSTRAINT uq_fsl_for_fraudscore UNIQUE (fraud_scoring_logentry_id, transaction_id, model_version, anomaly_score, risk_level_code),
  CONSTRAINT fk_fraudscoringlog_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id)
);
CREATE INDEX ix_fsl_txn_evaluated ON FraudScoringLog (transaction_id, evaluated_at);
CREATE INDEX ix_fsl_evaluated     ON FraudScoringLog (evaluated_at);

CREATE TABLE FraudScore (
  fraud_score_id         uuid PRIMARY KEY DEFAULT uuidv7(),
  transaction_id         uuid NOT NULL UNIQUE,
  fraud_scoring_logentry_id uuid NOT NULL,
  anomaly_score          numeric(5,4) NOT NULL,
  risk_level_code        varchar(10) NOT NULL REFERENCES FraudRiskLevel (risk_level_code),
  model_version          varchar(20) NOT NULL,
  evaluated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_fraudscore_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id),
  CONSTRAINT fk_fraudscore_log FOREIGN KEY (fraud_scoring_logentry_id, transaction_id, model_version, anomaly_score, risk_level_code)
    REFERENCES FraudScoringLog (fraud_scoring_logentry_id, transaction_id, model_version, anomaly_score, risk_level_code)
);
CREATE INDEX ix_fraudscore_risk_level ON FraudScore (risk_level_code, evaluated_at);

CREATE TABLE FraudReview (
  review_id              uuid PRIMARY KEY DEFAULT uuidv7(),
  transaction_id         uuid NOT NULL,
  reason                 varchar(20) NOT NULL,
  reviewed_at            timestamptz NOT NULL DEFAULT now(),
  reviewer_id            varchar(255) NOT NULL,
  reviewer_type          varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  outcome                varchar(20) NOT NULL,
  notes                  text,
  updated_by             varchar(255) NOT NULL,
  updater_type           varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT uq_fr_review_txn UNIQUE (review_id, transaction_id),
  CONSTRAINT fk_fraudreview_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id)
);
CREATE INDEX ix_fraudreview_txn_reviewed ON FraudReview (transaction_id, reviewed_at);

CREATE TABLE FraudDecision (
  decision_id            uuid PRIMARY KEY DEFAULT uuidv7(),
  transaction_id         uuid NOT NULL UNIQUE,
  source_review_id       uuid,
  decision_value         varchar(20) NOT NULL,
  decision_status        varchar(20) NOT NULL DEFAULT 'defaulted',
  defaulted_at           timestamptz,
  confirmed_at           timestamptz,
  updated_by             varchar(255) NOT NULL,
  updater_type           varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT fk_frauddecision_transaction FOREIGN KEY (transaction_id)
    REFERENCES Transaction (transaction_id),
  CONSTRAINT fk_frauddecision_review FOREIGN KEY (source_review_id, transaction_id)
    REFERENCES FraudReview (review_id, transaction_id)
);
CREATE INDEX ix_frauddecision_source_review ON FraudDecision (source_review_id);

-- ---------------------------------------------------------------------
-- 7. Sécurité et conformité
-- ---------------------------------------------------------------------
CREATE TABLE DataAccessLog (
  logentry_id     uuid PRIMARY KEY DEFAULT uuidv7(),
  actor_id        varchar(255) NOT NULL,
  actor_type_code varchar(20) NOT NULL REFERENCES AuditActorType (actor_type_code),
  action_code     varchar(30) NOT NULL REFERENCES AuditAction (action_code),
  resource_type   varchar(50) NOT NULL,
  resource_id     varchar(64),
  merchant_id     uuid REFERENCES Merchant (merchant_id),
  customer_id     uuid REFERENCES Customer (customer_id),
  source_ip       varchar(45),
  user_agent      varchar(255),
  justification   varchar(500),
  was_authorized  boolean NOT NULL DEFAULT true,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_dataaccesslog_customer_merchant FOREIGN KEY (merchant_id, customer_id)
    REFERENCES Customer (merchant_id, customer_id)
);
CREATE INDEX ix_dal_customer_occurred ON DataAccessLog (customer_id, occurred_at);
CREATE INDEX ix_dal_merchant_occurred ON DataAccessLog (merchant_id, occurred_at);
CREATE INDEX ix_dal_actor_occurred    ON DataAccessLog (actor_id, occurred_at);
CREATE INDEX ix_dal_was_authorized    ON DataAccessLog (was_authorized);
CREATE INDEX ix_dal_occurred          ON DataAccessLog (occurred_at);

CREATE TABLE ChangeAuditLog (
  logentry_id     uuid PRIMARY KEY DEFAULT uuidv7(),
  table_name      varchar(50) NOT NULL,
  record_id       varchar(64) NOT NULL,
  action_code     varchar(30) NOT NULL REFERENCES AuditAction (action_code),
  actor_id        varchar(255) NOT NULL,
  actor_type_code varchar(20) NOT NULL REFERENCES AuditActorType (actor_type_code),
  changed_fields  jsonb,
  merchant_id     uuid REFERENCES Merchant (merchant_id),
  occurred_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_cal_table_record_occurred ON ChangeAuditLog (table_name, record_id, occurred_at);
CREATE INDEX ix_cal_merchant_occurred     ON ChangeAuditLog (merchant_id, occurred_at);
CREATE INDEX ix_cal_occurred              ON ChangeAuditLog (occurred_at);

CREATE TABLE ConsentRecord (
  consent_id   uuid PRIMARY KEY DEFAULT uuidv7(),
  customer_id  uuid NOT NULL,
  merchant_id  uuid NOT NULL,
  purpose      varchar(100) NOT NULL,
  is_granted   boolean NOT NULL,
  legal_basis  varchar(50),
  source       varchar(50),
  recorded_at  timestamptz NOT NULL DEFAULT now(),
  updated_by   varchar(255) NOT NULL,
  updater_type varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT fk_consent_customer_merchant FOREIGN KEY (merchant_id, customer_id)
    REFERENCES Customer (merchant_id, customer_id)
);
CREATE INDEX ix_consent_customer_purpose ON ConsentRecord (customer_id, purpose, recorded_at);
CREATE INDEX ix_consent_merchant         ON ConsentRecord (merchant_id, recorded_at);

CREATE TABLE Regulation (
  regulation_code        varchar(20) PRIMARY KEY,
  label                  varchar(100) NOT NULL,
  response_deadline_days smallint NOT NULL,
  is_active              boolean NOT NULL DEFAULT true
);

CREATE TABLE DataSubjectRequestStatus (
  status_code varchar(20) PRIMARY KEY,
  label       varchar(100) NOT NULL,
  is_terminal boolean NOT NULL DEFAULT false,
  sort_order  smallint,
  is_active   boolean NOT NULL DEFAULT true
);

CREATE TABLE DataSubjectRequest (
  request_id      uuid PRIMARY KEY DEFAULT uuidv7(),
  customer_id     uuid NOT NULL,
  merchant_id     uuid NOT NULL,
  request_type    varchar(30) NOT NULL,
  regulation_code varchar(20) NOT NULL REFERENCES Regulation (regulation_code),
  status_code     varchar(20) NOT NULL DEFAULT 'received' REFERENCES DataSubjectRequestStatus (status_code),
  received_at     timestamptz NOT NULL DEFAULT now(),
  due_at          timestamptz NOT NULL,
  fulfilled_at    timestamptz,
  rejection_reason varchar(500),
  updated_by      varchar(255) NOT NULL,
  updater_type    varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code),
  CONSTRAINT fk_dsr_customer_merchant FOREIGN KEY (merchant_id, customer_id)
    REFERENCES Customer (merchant_id, customer_id)
);
CREATE INDEX ix_dsr_customer_received ON DataSubjectRequest (customer_id, received_at);
CREATE INDEX ix_dsr_merchant_status   ON DataSubjectRequest (merchant_id, status_code);
CREATE INDEX ix_dsr_status            ON DataSubjectRequest (status_code);
CREATE INDEX ix_dsr_due               ON DataSubjectRequest (due_at);

CREATE TABLE SecurityIncidentStatus (
  status_code varchar(20) PRIMARY KEY,
  label       varchar(100) NOT NULL,
  is_terminal boolean NOT NULL DEFAULT false,
  sort_order  smallint,
  is_active   boolean NOT NULL DEFAULT true
);

CREATE TABLE SecurityIncident (
  incident_id           uuid PRIMARY KEY DEFAULT uuidv7(),
  incident_type         varchar(50) NOT NULL,
  severity              varchar(20) NOT NULL,
  merchant_id           uuid REFERENCES Merchant (merchant_id),
  affected_record_count int,
  description           varchar(1000),
  detected_at           timestamptz NOT NULL DEFAULT now(),
  notified_at           timestamptz,
  resolved_at           timestamptz,
  status_code           varchar(20) NOT NULL DEFAULT 'open' REFERENCES SecurityIncidentStatus (status_code),
  updated_by            varchar(255) NOT NULL,
  updater_type          varchar(20)  NOT NULL REFERENCES AuditActorType (actor_type_code)
);
CREATE INDEX ix_secincident_severity_detected ON SecurityIncident (severity, detected_at);
CREATE INDEX ix_secincident_status            ON SecurityIncident (status_code);
CREATE INDEX ix_secincident_detected          ON SecurityIncident (detected_at);
