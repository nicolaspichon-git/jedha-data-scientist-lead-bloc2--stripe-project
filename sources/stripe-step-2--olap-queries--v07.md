*STRIPE* PROJECT
===

# 2. OLAP Data System
## D8.2. OLAP SQL Queries Examples

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D8 : OLAP Queries / v07 - 2026/10/13.*

---

### 2.A.9.1. Contexte

Le présent document propose quelques exemples de requêtes sur la base de données analytique pour chacun des processus métiers. L'objectif est de vérifier que chaque processus est exploitable sans jointure sur la base transactionnelle.

### 2.A.9.2. Traitement d'un paiement (P1)

#### P1.1 : Revenu mensuel net marchand vs. commission *Stripe*

```sql
SELECT
    d.year,
    d.month,
    m.legal_name,
    SUM(ft.merchant_net_revenue_eur) AS merchant_net_revenue_euro,
    SUM(ft.stripe_revenue_eur)        AS stripe_revenue_euro,
    COUNT(*)                          AS transactions
FROM FactTransaction ft
JOIN DimDate d     ON d.date_key = ft.date_key
JOIN DimMerchant m ON m.merchant_key = ft.merchant_key AND m.is_current = true
WHERE d.full_date >= (CURRENT_DATE - INTERVAL '12 months')
GROUP BY d.year, d.month, m.legal_name
ORDER BY d.year, d.month, merchant_net_revenue_euro DESC;
```

#### P1.2 : Top-10 des produits par revenu, toutes devises d'origine confondues

```sql
SELECT
    p.name                     AS product,
    c.currency_code            AS transaction_currency,
    COUNT(*)                   AS transactions,
    SUM(ft.amount)             AS amount_in_transaction_currency,
    SUM(ft.amount_eur)         AS amount_in_euro
FROM FactTransaction ft
JOIN DimProduct p  ON p.product_key = ft.product_key
JOIN DimCurrency c ON c.currency_key = ft.currency_key
GROUP BY p.name, c.currency_code
ORDER BY amount_in_euro DESC
LIMIT 10;
```

#### P1.3 : Tableau de bord quasi temps réel (table d'agrégat)

```sql
SELECT
    d.full_date,
    m.legal_name,
    a.transaction_count,
    a.gross_volume_eur,
    a.merchant_net_revenue_eur,
    a.avg_ticket_eur
FROM AggRevenueDailyMerchant a
JOIN DimDate d     ON d.date_key = a.date_key
JOIN DimMerchant m ON m.merchant_key = a.merchant_key AND m.is_current = true
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY d.full_date DESC, a.gross_volume_eur DESC;
```

### 2.A.9.3. Évaluation du risque de fraude (P2)

#### P2.1 : Taux de blocage automatique par marchand

```sql
SELECT
    m.legal_name,
    COUNT(*) AS assessments,
    COUNT(*) FILTER (WHERE frl.blocks_transaction) AS blockeds,
    ROUND(100.0 * COUNT(*) FILTER (WHERE frl.blocks_transaction)
          / NULLIF(COUNT(*), 0), 2) AS blockeds_percentage
FROM FactFraudEvent ffe
JOIN DimMerchant m ON m.merchant_key = ffe.merchant_key AND m.is_current = true
JOIN DimFraudRiskLevel frl ON frl.risk_level_key = ffe.risk_level_key
GROUP BY m.legal_name
ORDER BY blockeds_percentage DESC;
```

#### P2.2 : Fiabilité du modèle : taux de fraude confirmée par niveau de risque évalué

```sql
SELECT
    frl.label AS risk_level,
    COUNT(*) AS assessments,
    COUNT(*) FILTER (WHERE ffe.is_confirmed_fraud) AS frauds,
    ROUND(100.0 * COUNT(*) FILTER (WHERE ffe.is_confirmed_fraud)
          / NULLIF(COUNT(*), 0), 3) AS confirmation_rate_percentage
FROM FactFraudEvent ffe
JOIN DimFraudRiskLevel frl ON frl.risk_level_key = ffe.risk_level_key
GROUP BY frl.label
ORDER BY confirmation_rate_percentage DESC;
```

#### P2.3 : Montant exposé par niveau de risque et par région

```sql
SELECT
    g.region,
    frl.label AS risk_level,
    SUM(ffe.exposed_amount_eur) AS exposed_amount_euro,
    COUNT(*) AS assessments
FROM FactFraudEvent ffe
JOIN DimGeography g        ON g.geography_key = ffe.geography_key
JOIN DimFraudRiskLevel frl ON frl.risk_level_key = ffe.risk_level_key
GROUP BY g.region, frl.label
ORDER BY exposed_amount_euro DESC;
```

### 2.A.9.4. Cycle de vie d'un abonnement (P3)

#### P3.1. Revenu récurrent mensuel par marchand sur le dernier instantané de chaque abonnement

> Glossaire : MMR = Monthly Recurring Revenue (revenu récurrent mensuel).

```sql
WITH dernier_instantane AS (
    SELECT DISTINCT ON (subscription_id)
        subscription_id, merchant_key, mrr_eur, stripe_mrr_eur, is_active
    FROM FactSubscriptionSnapshot
    ORDER BY subscription_id, date_key DESC
)
SELECT
    m.legal_name,
    COUNT(*) FILTER (WHERE di.is_active)      AS abonnements_actifs,
    SUM(di.mrr_eur) FILTER (WHERE di.is_active)        AS mrr_merchant_eur,
    SUM(di.stripe_mrr_eur) FILTER (WHERE di.is_active) AS mrr_stripe_eur
FROM dernier_instantane di
JOIN DimMerchant m ON m.merchant_key = di.merchant_key AND m.is_current = true
GROUP BY m.legal_name
ORDER BY mrr_merchant_eur DESC;
```

#### P3.2. Clients à risque de désabonnement, par segment

```sql
SELECT
    c.segment,
    COUNT(DISTINCT fss.subscription_id) AS nb_abonnements_a_risque,
    AVG(fss.failed_attempt_count)        AS echecs_moyens
FROM FactSubscriptionSnapshot fss
JOIN DimCustomer c            ON c.customer_key = fss.customer_key AND c.is_current = true
JOIN DimSubscriptionStatus ss ON ss.subscription_status_key = fss.subscription_status_key
WHERE ss.triggers_dunning = true
  AND fss.date_key = (SELECT MAX(date_key) FROM FactSubscriptionSnapshot)
GROUP BY c.segment
ORDER BY nb_abonnements_a_risque DESC;
```

#### P3.3. Évolution mensuelle du taux de désabonnement (table d'agrégat)

```sql
SELECT
    d.year,
    d.month,
    m.legal_name,
    SUM(a.churned_count)   AS total_desabonnements,
    AVG(a.churn_rate)       AS taux_desabonnement_moyen
FROM AggSubscriptionDailyMerchant a
JOIN DimDate d     ON d.date_key = a.date_key
JOIN DimMerchant m ON m.merchant_key = a.merchant_key AND m.is_current = true
GROUP BY d.year, d.month, m.legal_name
ORDER BY d.year, d.month;
```

---


### 2.A.9.5. Accès et modification de données (P4)

#### P4.1. Tentatives non autorisées par acteur, 7 derniers jours

```sql
SELECT
    act.actor_id,
    act.actor_type,
    COUNT(*)             AS nb_tentatives_non_autorisees,
    MAX(fae.event_timestamp) AS derniere_tentative
FROM FactAuditEvent fae
JOIN DimActor act ON act.actor_key = fae.actor_key AND act.is_current = true
JOIN DimDate d    ON d.date_key = fae.date_key
WHERE fae.was_authorized = false
  AND d.full_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY act.actor_id, act.actor_type
ORDER BY nb_tentatives_non_autorisees DESC;
```

#### P4.2. Répartition des accès sensibles par marchand (table d'agrégat)

```sql
SELECT
    m.legal_name,
    d.full_date,
    a.total_access_count,
    a.sensitive_access_count,
    a.export_count,
    ROUND(100.0 * a.sensitive_access_count / NULLIF(a.total_access_count, 0), 2) AS pct_sensible
FROM AggComplianceDailyMerchant a
JOIN DimMerchant m ON m.merchant_key = a.merchant_key AND m.is_current = true
JOIN DimDate d     ON d.date_key = a.date_key
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY pct_sensible DESC;
```

#### P4.3. Historique d'accès à un client donné (réponse à une demande d'accès RGPD)

```sql
SELECT
    fae.event_timestamp,
    act.actor_id,
    aa.label            AS action,
    fae.resource_type,
    fae.was_authorized
FROM FactAuditEvent fae
JOIN DimCustomer c      ON c.customer_key = fae.customer_key
JOIN DimActor act       ON act.actor_key = fae.actor_key
JOIN DimAuditAction aa  ON aa.audit_action_key = fae.audit_action_key
WHERE c.customer_id = :customer_id  -- clé métier OLTP
ORDER BY fae.event_timestamp DESC;
```

---

### 2.A.9.6. Traitement d'une demande de droit (P5)

#### P5.1. Taux de respect des délais légaux par réglementation

```sql
SELECT
    r.label                              AS reglementation,
    r.response_deadline_days,
    COUNT(*)                              AS nb_demandes,
    COUNT(*) FILTER (WHERE fdsr.is_within_deadline)               AS nb_dans_les_delais,
    ROUND(100.0 * COUNT(*) FILTER (WHERE fdsr.is_within_deadline)
          / NULLIF(COUNT(*), 0), 2)                                AS taux_conformite_pct
FROM FactDataSubjectRequest fdsr
JOIN DimRegulation r ON r.regulation_key = fdsr.regulation_key
GROUP BY r.label, r.response_deadline_days
ORDER BY taux_conformite_pct ASC;
```

#### P5.2. Délai moyen de traitement par type de demande

```sql
SELECT
    fdsr.request_type,
    COUNT(*)                          AS nb_demandes_traitees,
    ROUND(AVG(fdsr.processing_days), 1) AS delai_moyen_jours,
    MAX(fdsr.processing_days)          AS delai_max_jours
FROM FactDataSubjectRequest fdsr
JOIN DimRequestStatus rs ON rs.request_status_key = fdsr.request_status_key
WHERE rs.is_terminal = true
GROUP BY fdsr.request_type
ORDER BY delai_moyen_jours DESC;
```

#### P5.3. Demandes en cours proches de l'échéance légale

```sql
SELECT
    m.legal_name,
    fdsr.request_id,
    fdsr.request_type,
    d.full_date                                              AS date_reception,
    d.full_date + (r.response_deadline_days || ' days')::interval AS echeance_legale,
    (d.full_date + (r.response_deadline_days || ' days')::interval)::date - CURRENT_DATE
                                                                AS jours_restants
FROM FactDataSubjectRequest fdsr
JOIN DimDate d            ON d.date_key = fdsr.received_date_key
JOIN DimRegulation r       ON r.regulation_key = fdsr.regulation_key
JOIN DimRequestStatus rs   ON rs.request_status_key = fdsr.request_status_key
JOIN DimMerchant m         ON m.merchant_key = fdsr.merchant_key AND m.is_current = true
WHERE rs.is_terminal = false
ORDER BY jours_restants ASC;
```

---

### 2.A.9.7. Traitement d'un incident de sécurité (P6)

#### P6.1. Taux de respect du délai de notification (72h RGPD) par sévérité

```sql
SELECT
    fsi.severity,
    COUNT(*)                                                     AS nb_incidents,
    COUNT(*) FILTER (WHERE fsi.is_within_72h_deadline)           AS nb_dans_les_delais,
    ROUND(AVG(fsi.detection_to_notification_hours), 1)           AS delai_moyen_heures
FROM FactSecurityIncident fsi
WHERE fsi.notified_date_key IS NOT NULL
GROUP BY fsi.severity
ORDER BY delai_moyen_heures DESC;
```

#### P6.2. Enregistrements affectés cumulés par marchand et par type d'incident

```sql
SELECT
    COALESCE(m.legal_name, 'Transverse plateforme') AS merchant,
    fsi.incident_type,
    COUNT(*)                          AS nb_incidents,
    SUM(fsi.affected_record_count)     AS total_enregistrements_affectes
FROM FactSecurityIncident fsi
LEFT JOIN DimMerchant m ON m.merchant_key = fsi.merchant_key AND m.is_current = true
GROUP BY merchant, fsi.incident_type
ORDER BY total_enregistrements_affectes DESC;
```

#### P6.3. Incidents non résolus par ancienneté et par sévérité

```sql
SELECT
    fsi.incident_id,
    COALESCE(m.legal_name, 'Transverse plateforme') AS merchant,
    fsi.severity,
    d.full_date                        AS date_detection,
    CURRENT_DATE - d.full_date          AS jours_ouverts
FROM FactSecurityIncident fsi
JOIN DimDate d              ON d.date_key = fsi.detected_date_key
JOIN DimIncidentStatus ist  ON ist.incident_status_key = fsi.incident_status_key
LEFT JOIN DimMerchant m     ON m.merchant_key = fsi.merchant_key AND m.is_current = true
WHERE ist.is_terminal = false
ORDER BY fsi.severity DESC, jours_ouverts DESC;
```
