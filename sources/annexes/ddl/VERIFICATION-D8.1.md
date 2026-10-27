# Vérification de D8.1 (v36)

Environnement : PostgreSQL 16.15, DDL `01_schema.sql` + `02_complement.sql` (v36), jeu synthétique `05_sample_data.sql` (82400 transactions, 2000 clients, 82400 scorings). Chaque requête est exécutée dans une transaction annulée ; les plans sont issus de `EXPLAIN (ANALYZE)`.

Les durées sont indicatives (jeu de ~80 000 lignes, machine de test partagée) : elles servent à vérifier le *plan*, pas à prédire la production.

| Requête | Résultat | Lignes | Durée (ms) | Plan |
|---|---|---|---|---|
| D8.1.2.1 | OK | 1 | 0.068 | index: transaction_pkey ; seq: - ; index utilisables (seqscan off): transaction_pkey |
| D8.1.2.2 | OK | 20 | 0.089 | index: ix_transaction_customer_created ; seq: - ; index utilisables (seqscan off): ix_transaction_customer_created |
| D8.1.2.3 | OK | (écriture annulée) | 1.617 | index: customer_pkey ; seq: pricingplan, pricingplanfee ; index utilisables (seqscan off): customer_pkey, ex_plan_no_overlap, pricingplanfee_pkey |
| D8.1.2.4 | OK | (écriture annulée) | 0.032 | index: ix_subscription_due ; seq: - ; index utilisables (seqscan off): ix_subscription_due |
| D8.1.2.5 | OK | 50 | 0.160 | index: - ; seq: datasubjectrequest, datasubjectrequeststatus ; index utilisables (seqscan off): datasubjectrequeststatus_pkey, ix_dsr_due |
| D8.1.2.6 | OK | 5 | 0.155 | index: ix_dal_customer_occurred ; seq: - ; index utilisables (seqscan off): ix_dal_customer_occurred |
| D8.1.3.1 | OK | 10 | 18.272 | index: ix_transaction_created ; seq: currency, merchant, refund |
| D8.1.3.2 | OK | 16 | 62.597 | index: - ; seq: product, transaction |
| D8.1.4.1 | OK | 100 | 2.229 | index: ix_fraudscore_risk_level, transaction_pkey ; seq: fraudreview, fraudrisklevel ; index utilisables (seqscan off): ix_fraudscore_risk_level, transaction_pkey, uq_fr_review_txn |
| D8.1.4.2 | OK | 3 | 33.877 | index: ix_transaction_created ; seq: chargeback, chargebackreasoncode, frauddecision, fraudrisklevel, fraudscore |
| D8.1.5.1 | OK | 400 | 17.386 | index: ix_transaction_merchant_created ; seq: customer, refund |
| D8.1.5.2 | OK | 5 | 103.690 | index: - ; seq: chargeback, currency, currencyreferencerate, refund, transaction |
