*STRIPE* PROJECT
===

# 2. OLAP Data System
## Annexes
### 2.A. Kimball Analysis

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D3 : OLAP - Annexe A / v08 - 2026/10/13.*   

---

### 2.A.1. Méthode et périmètre

La méthode **Kimball** est une méthode de conception de système OLAP  (cf. *The Data Warehouse Toolkit* par *Kimball*) : le point de départ n'est pas le schéma source, mais la problématique du métier. Le processus se déroule en quatre étapes, dans l'ordre suivant :
1. **Choisir le processus métier** : un événement qui se produit dans l'entreprise.
2. **Définir la granularité des faits**  : ce que représente une ligne de la table de faits.
3. **Identifier les dimensions** : les axes d'analyse.
4. **Identifier les faits** : les mesures numériques agrégeables.

Le présent document couvre le processus complet pour l'ensemble des besoins analytiques exprimés dans le cahier des charges (BR2, DS2, D3, D8), en traçant chaque choix jusqu'à sa source dans le modèle OLTP (annexe 1.B).

---

### 2.A.2. Étape 1 : Les processus métiers

Six processus métiers sont identifiés d'après les catégories de données analytiques du cahier des charges (DS2 : *Revenue Metrics*, *Customer Segmentation Data*, *Product Performance Metrics*, *Fraud Analysis Data*, *Compliance and Audit Logs*).

| #   | Processus métier                     | Événement déclencheur                                | Catégorie couverte                                          |
| --- | ------------------------------------ | ---------------------------------------------------- | ----------------------------------------------------------- |
| P1  | Traitement d'un paiement             | Une transaction est créée                            | Revenue Metrics, Product Performance, Customer Segmentation |
| P2  | Évaluation du risque de fraude       | Un score de fraude est calculé                       | Fraud Analysis Data                                         |
| P3  | Cycle de vie d'un abonnement         | Un abonnement atteint une échéance                   | Revenue Metrics (récurrent)                                 |
| P4  | Accès et modification de données     | Une consultation ou une modification est journalisée | Compliance and Audit Logs                                   |
| P5  | Traitement d'une demande de droit    | Un client exerce un droit RGPD/CCPA                  | Compliance and Audit Logs                                   |
| P6  | Traitement d'un incident de sécurité | Un incident est détecté                              | Compliance and Audit Logs                                   |

**Problématiques volontairement exclues** : les remboursements (Refund) et rétro-facturations (ChargeBack) ne constituent pas des processus séparés. Ce sont des *attributs de l'issue* d'une transaction (P1), et non des événements analytiques autonomes (cf. BR2).

### 2.A.3. Étape 2 : Les grains

Le grain fixe ce qu'une ligne de fait représente, et ne doit jamais être mélangé avec un autre grain dans la même table (risque de double comptage lors des agrégations).

| Fait | Grain | Type de table (Kimball) |
| ---- | ----- | ----------------------- |
| `FactTransaction`          | Une transaction individuelle                             | Fait transactionnel |
| `FactFraudEvaluation`      | Une évaluation de risque de fraude                       | Fait transactionnel |
| `FactSubscriptionSnapshot` | Un abonnement, à la fin de chaque période de facturation | Instantané périodique |
| `FactAuditEvent`           | Un événement d'audit (accès **ou** modification)         | Fait transactionnel |
| `FactDataSubjectRequest`   | Une demande de droit, mise à jour au fil du traitement   | Instantané cumulatif |
| `FactSecurityIncident`     | Un incident de sécurité, mis à jour au fil du traitement | Instantané cumulatif |

**Pourquoi`DataAccessLog` et `ChangeAuditLog` fusionnent-ils dans  `FactAuditEvent` ?** 
Tables distinctes dans le système OLTP, elle correspond au même type d'évènement dans le système OLAP car ils donnent la même réponse à la question : *"qui a fait quoi, quand, sur quoi"*. Un grain unique sert mieux le reporting consolidé de conformité, sans que cela contredise la séparation OLTP.

**Pourquoi `FactDataSubjectRequest` et `FactSecurityIncident` sont-ils des instantanés
cumulatifs et non des faits transactionnels classiques.** Une demande de droit ou un incident
traverse plusieurs jalons dans le temps (`received_at` --> `due_at` --> `fulfilled_at` ; `detected_at` --> `notified_at` --> `resolved_at`). 
Le fait cumulatif Kimball est justement conçu pour ce cas : une ligne par demande/incident, mise à jour à chaque jalon franchi, avec une clé de date par jalon (qui )permet de calculer directement des délais de traitement sans reconstruire l'historique à partir d'événements séparés).

**Pourquoi `FactSubscriptionSnapshot` est-il un instantané périodique.** 
Un abonnement ne génère pas d'événement ponctuel quotidien. C'est son état (actif, montant, échéance) que l'on veut pouvoir suivre dans le temps. C'est l'usage typique de l'instantané périodique : une ligne par abonnement et par point de mesure (ici, la fin de chaque cycle de facturation, cohérent avec `Subscription.current_period_end`).

### 2.A.4. Étape 3 - Les dimensions

Les dimensions sont *conformées* : une même dimension (ex. `DimMerchant`) est partagée par
plusieurs faits, avec les mêmes clés et attributs, pour permettre des analyses transverses
(ex. comparer le revenu et les incidents de sécurité par marchand). 
'est la matrice de bus ci-dessous qui documente ce partage.

| Dimension | Type SCD     | Origine OLTP | Remarque |
| --------- | ------------ | ------------ | -------- |
| `DimDate` | - (statique) | Calendrier généré | Partagée par tous les faits |
| `DimMerchant` | SCD2 | `Merchant` + `MerchantStatus` + `Country` | Historise les changements de statut/pays |
| `DimCustomer` | SCD2 | `Customer` + `Country` | Historise le pays de résidence |
| `DimProduct` | SCD1 | `Product` | Pas d'historisation : le prix courant suffit, le montant réel est déjà figé dans le fait |
| `DimPaymentMethod` | SCD1 | `PaymentMethod` + `PaymentMethodType` + `CardBrand` | Type et marque, jamais le PAN |
| `DimPricingPlan` | SCD2 | `PricingPlan` + `PricingPlanFee` | Doit s'historiser : un plan corrigé rétroactivement ne doit pas réécrire le passé (cf. MCD règle #15) |
| `DimCurrency` | - (statique) | `Currency` | |
| `DimGeography` | - (statique) | `Country` + `device_type` | Dénormalisation assumée (deux notions combinées) pour limiter le nombre de dimensions |
| `DimTransactionStatus` | - (statique) | `TransactionStatus` | Inclut `allows_refund`, `is_terminal` |
| `DimFraudRiskLevel` | - (statique) | `FraudRiskLevel` | Inclut `requires_manual_review`, `blocks_transaction` |
| `DimSubscriptionStatus` | - (statique) | `SubscriptionStatus` | Inclut `triggers_dunning` |
| `DimActor` | SCD2 | `ActorType` (OLTP) + identité externe | Historise le type d'acteur si réaffecté |
| `DimAuditAction` | - (statique) | `AuditAction` | Inclut `is_sensitive`, `requires_justification` |
| `DimRegulation` | - (statique) | `Regulation` | Inclut `response_deadline_days` |
| `DimRequestStatus` | - (statique) | `DataSubjectRequestStatus` | |
| `DimIncidentStatus` | - (statique) | `SecurityIncidentStatus` | |
| `DimReferenceExchangeRate` | Versionnée (annuelle) | Constante de référence, hors OLTP | Voir 2.A.7 |

**Pourquoi `DimProduct` reste-t-elle en SCD1 alors que `DimMerchant` et `DimCustomer` sont en SCD2.** Le montant réellement payé est déjà figé dans `FactTransaction.amount` au moment de la vente. Retrouver le prix catalogue *historique* d'un produit n'apporte rien que le fait ne porte déjà. `DimMerchant`/`DimCustomer`, en revanche, sont interrogées pour des attributs qui *évoluent indépendamment* du fait (statut, pays) et que l'on veut pouvoir dater précisément.

### 2.A.5. Étape 4 : Les faits

| Table de faits | Mesures | Nature |
|---|---|---|
| `FactTransaction` | `amount`, `fee_amount`, `merchant_net_revenue` (calculé), `is_refunded`, `is_disputed`, `refund_amount` | Additives sur toutes les dimensions sauf `is_*` (semi-additives) |
| `FactFraudEvaluation` | `anomaly_score`, `is_high_risk`, `requires_review`, `is_blocked` | `anomaly_score` non additif (moyenne pertinente, somme non) |
| `FactSubscriptionSnapshot` | `mrr` (revenu récurrent mensualisé, calculé), `failed_attempt_count`, `is_active`, `days_until_renewal` | `mrr` semi-additif (additif sur toutes les dimensions sauf le temps - sommer deux instantanés du même abonnement à deux dates n'a pas de sens) |
| `FactAuditEvent` | `event_count` (= 1, fait de comptage), `was_authorized`, `is_sensitive` | Entièrement additif |
| `FactDataSubjectRequest` | `processing_days` (calculé, `fulfilled_at - received_at`), `days_overdue`, `is_within_deadline` | Non additif (moyenne/max pertinents, jamais de somme) |
| `FactSecurityIncident` | `affected_record_count`, `detection_to_notification_hours`, `is_within_72h_deadline` | `affected_record_count` additif, les délais non additifs |

### 2.A.6. Matrice de bus (Kimball Bus Matrix)

Vue synthétique du partage des dimensions entre processus. 
Chaque case cochée est une dimension conformée, réutilisable telle quelle d'un fait à l'autre.

| Dimension / Processus | P1 Transaction | P2 Fraude | P3 Abonnement | P4 Audit | P5 Droit RGPD | P6 Incident |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| DimDate | ✕ | ✕ | ✕ | ✕ | ✕ | ✕ |
| DimMerchant | ✕ | ✕ | ✕ | ✕ | ✕ | ✕ |
| DimCustomer | ✕ | ✕ | ✕ | ✕ | ✕ | |
| DimProduct | ✕ | | ✕ | | | |
| DimPaymentMethod | ✕ | | ✕ | | | |
| DimPricingPlan | ✕ | | | | | |
| DimCurrency | ✕ | | ✕ | | | |
| DimGeography | ✕ | | | ✕ | | |
| DimTransactionStatus | ✕ | | | | | |
| DimFraudRiskLevel | | ✕ | | | | |
| DimSubscriptionStatus | | | ✕ | | | |
| DimActor | | | | ✕ | | |
| DimAuditAction | | | | ✕ | | |
| DimRegulation | | | | | ✕ | |
| DimRequestStatus | | | | | ✕ | |
| DimIncidentStatus | | | | | | ✕ |

`DimDate` et `DimMerchant` traversent les six processus. C'est ce qui permettra, par exemple, de croiser revenu et incidents de sécurité par marchand et par mois sans jointure artificielle entre deux entrepôts séparés.

### 2.A.7. Conversion de devise
`DimReferenceExchangeRate` porte un taux de conversion **figé par année** (différent a priori du taux du jour) pour que deux montants convertis à des dates différentes restent comparables entre eux. 

---
