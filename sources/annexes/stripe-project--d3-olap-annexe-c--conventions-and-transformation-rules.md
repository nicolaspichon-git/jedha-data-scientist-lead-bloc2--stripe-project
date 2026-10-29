---
version: v22
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-2
  - stripe-project/step-2/annexes
  - stripe-project/step-2/annexes/c
  - stripe-project/olap
  - stripe-project/olap/design
  - stripe-project/olap/design/conventions
---

*STRIPE* PROJECT
===

# 2. OLAP Data System
## Annexes
### 2.C. OLAP Conventions and Transformation Rules

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / D3 : OLAP Annexe C / v22 --- 2026/11/05.*   
---

Cette annexe réunit les conventions de données du schéma OLAP \[D3\] (montants et devises, fuseaux horaires) et les règles de transformation (ETL) qui produisent les valeurs que l'OLTP ne fournit pas telles quelles. Elle complète l'analyse de Kimball \[D3-A\] et les notes du modèle physique \[D3-B\] ; ses sources sont le MCD \[D2-A\] et le modèle physique de l'OLTP \[D2-B\] (v36).

### 2.C.1. Conversion de devise

`DimReferenceExchangeRate` porte un taux de conversion de référence fixe pour l'année (différent a priori du taux du jour) pour que deux montants convertis à des dates différentes restent comparables entre eux. La devise de référence (EUR) est une constante du modèle : aucune colonne ne la porte (ni `to_currency_*` dans `DimReferenceExchangeRate`, ni drapeau dans `DimCurrency`).

#### 2.C.1.1. Représentation des montants

- **Montants locaux** : entiers en unités mineures (`bigint`), comme dans l'OLTP (`Transaction.amount`, `Transaction.fee_amount`, `Refund.amount`). L'échelle est portée par `DimCurrency.decimals` (JPY = 0, EUR = 2, BHD = 3) : montant en unité majeure = `amount_minor / 10^decimals`. Aucune perte, quelle que soit la devise, et rapprochement exact avec l'OLTP.
- **Montants en EUR** : `decimal(18,4)`, calculés une seule fois à l'ETL, en décimal exact (jamais en flottant).

#### 2.C.1.2. Formule de conversion

`amount_eur = amount_minor / 10^decimals × reference_rate`

où `reference_rate` (`decimal(24,12)`) est exprimé en **EUR pour 1 unité majeure** de la devise source. Exemples (taux fictifs, à titre d'illustration) :

| Devise | `amount_minor` | `decimals` | Montant local | `reference_rate` | `amount_eur` |
| ------ | -------------- | ---------- | ------------- | ---------------- | ------------ |
| BHD    | 12345          | 3          | 12,345        | 2,4              | 29,6280      |
| JPY    | 5000           | 0          | 5 000         | 0,0062           | 31,0000      |
| EUR    | 1990           | 2          | 19,90         | 1                | 19,9000      |

#### 2.C.1.3. Règles d'application

1. **Taux retenu** : celui de (devise source, exercice) pour la date de création UTC de la transaction ; pour un instantané d'abonnement, celui de (devise de l'abonnement, exercice) pour la date de l'instantané (`FactSubscriptionSnapshot.exchange_rate_key`, qui porte aussi la devise, ETL-40). La paire EUR → EUR (taux 1) existe, afin que `FactTransaction.exchange_rate_key` et `FactSubscriptionSnapshot.exchange_rate_key` restent non nuls.
2. **Une seule conversion par composante** : montant, commission et remboursement sont convertis chacun une fois. La commission (`fee_amount_minor`) est reprise telle quelle de `Transaction.fee_amount` ; elle n'est **jamais recalculée** côté OLAP. `stripe_revenue_eur` est une colonne dérivée de `fee_amount_eur` (`GENERATED ALWAYS AS (fee_amount_eur) STORED`), jamais alimentée séparément. Les mesures dérivées sont calculées sur les valeurs déjà converties : `merchant_net_revenue_eur = amount_eur − fee_amount_eur − refund_amount_eur` (identité exacte).
3. **Arrondi** : à la 4e décimale, demi-supérieur. L'arrondi à 2 décimales est réservé à l'affichage, pour que les agrégats sur de grands volumes ne cumulent pas de biais d'arrondi.
4. **Rapprochement** : `SUM(amount_minor)` par jour, marchand et devise doit égaler la somme des `Transaction.amount` correspondantes de l'OLTP.

<div style="page-break-after: always;"></div>

### 2.C.2. Fuseaux horaires

**Règle : tout est en UTC.** L'OLTP stocke ses horodatages en `timestamptz` (UTC) ; l'OLAP reprend cette référence, sans conversion en heure locale.

| Élément OLAP | Type | Règle |
|---|---|---|
| `FactTransaction.transaction_timestamp`, `FactAuditEvent.event_timestamp` | `timestamptz` | Valeur UTC. Un `timestamp` sans fuseau est interdit : il ne dit pas quelle heure il représente. |
| `date_key` (et `*_date_key`) de chaque fait | `int` AAAAMMJJ | Date **UTC** de l'événement (tableau ci-dessous). |
| `valid_from`, `valid_to` (dimensions SCD2), `effective_from`, `effective_to` (taux) | `date` | Dates UTC. |
| Exercice fiscal (`DimReferenceExchangeRate.fiscal_year`) | `smallint` | Bornes en UTC ; c'est la même date que celle qui sélectionne le taux (2.C.1.3, règle 1). |

Origine de la date de chaque fait :

| Fait | `date_key` calculée à partir de |
|---|---|
| `FactTransaction` | `Transaction.created_at` |
| `FactFraudEvent` | `FraudScore.evaluated_at` |
| `FactSubscriptionSnapshot` | `date_key` : date de l'instantané (fin de la période de facturation en cours) ; `started_date_key` : `Subscription.started_at` ; `canceled_date_key` : `Subscription.canceled_at` (demande de résiliation, NULL si aucune) |
| `FactAuditEvent` | `DataAccessLog.occurred_at` ou `ChangeAuditLog.occurred_at` |
| `FactDataSubjectRequest` | `DataSubjectRequest.received_at` (réception), `fulfilled_at` (traitement) |
| `FactSecurityIncident` | `SecurityIncident.detected_at`, `notified_at`, `resolved_at` |

**Pourquoi UTC plutôt que l'heure du marchand ?**
- Une seule définition du « jour » pour tous les marchands : les agrégats (`AggRevenueDailyMerchant`, etc.) restent additionnables et rapprochables de l'OLTP.
- Le taux de change et l'exercice fiscal se déterminent avec la même date que `date_key` : pas de transaction dont le jour diffère selon la table lue.
- Le modèle OLTP ne porte aucun fuseau par marchand ; sans fuseau IANA fiable, un pays à plusieurs fuseaux interdit de déduire l'heure locale du pays seul.

**Conséquences à connaître.** Un marchand loin de l'Europe verra une transaction passée à 23 h 30 heure locale comptée au jour UTC suivant ou précédent. Pour un besoin de clôture quotidienne en heure locale, il faudrait ajouter `Merchant.timezone` (fuseau IANA) à l'OLTP et un `local_date_key` aux faits ; cette extension n'est pas retenue en l'absence de besoin exprimé.

**Requêtes.** « Aujourd'hui » s'écrit `(now() AT TIME ZONE 'UTC')::date` ; `CURRENT_DATE` dépend du fuseau de la session et est donc proscrit (appliqué dans les requêtes P1.1, P4.1 et P5.2 de D8.2). Pour une analyse par heure, utiliser `EXTRACT(hour FROM transaction_timestamp AT TIME ZONE 'UTC')` ; aucune dimension `DimTime` n'est créée.

**Jours fériés.** `DimDate` ne porte aucun pays, et l'OLTP ne fournit aucune source de jours fériés.

### 2.C.3. Règles de transformation

Cette section réunit les règles qui produisent les valeurs que l'OLTP ne fournit pas telles quelles : indicateurs, mesures calculées, regroupements, segments. Chaque règle porte un identifiant (`ETL-nn`) cité dans les notes du modèle physique \[D3-B\]. Les points non tranchés sont exposés en 2.C.3.8 (`O-nn`). Les règles sur les montants (2.C.1) et sur les fuseaux horaires (2.C.2) restent à leur place et s'appliquent à toutes celles ci-dessous.

**Statut des valeurs.** Les sources (tables et colonnes de l'OLTP v36) sont celles du MCD et du modèle physique OLTP. Les seuils, les mappings et les choix signalés « *hypothèse de conception* » sont des décisions de ce document, non des faits issus de l'OLTP ; ils sont à valider avec le besoin métier.

<div style="page-break-after: always;"></div>

#### 2.C.3.1. Principes communs

| ID | Règle |
|---|---|
| ETL-01 | **Version de dimension SCD2 retenue.** Pour un fait daté du jour UTC `D`, l'ETL retient la version de la dimension telle que `valid_from ≤ D < valid_to` (`valid_to` NULL = version courante). Les bornes sont demi-ouvertes, comme les `daterange` de l'OLTP (`PricingPlan`) : `valid_to` d'une version est égal à `valid_from` de la suivante. |
| ETL-02 | **Colonnes mises à jour après l'insertion.** Les faits sont insérés une fois. Seules exceptions, car l'information arrive après la transaction : `FactTransaction.status_key`, `refund_amount_minor`, `refund_amount_eur`, `merchant_net_revenue_eur`, `is_refunded`, `is_chargeback` ; `FactFraudEvent.is_confirmed_fraud`. Les clés, `date_key`, les montants de la transaction et la commission ne changent jamais. |
| ETL-03 | **Rechargement idempotent.** Un fait rechargé donne la même ligne : clé métier unique (`transaction_id` pour `FactTransaction` et `FactFraudEvent`, `subscription_id` + `date_key` pour `FactSubscriptionSnapshot`, `request_id` pour `FactDataSubjectRequest`, `incident_id` pour `FactSecurityIncident`), taux de référence (2.C.1) et base GeoIP (\[D3-A\] 2.A.4) figés. `FactAuditEvent` n'a pas de clé métier : un rechargement remplace toutes ses lignes d'un même `date_key` (jour UTC) en une seule opération. *Hypothèse de conception : rechargement par jour.* |

#### 2.C.3.2. Dimensions

| ID | Cible | Règle |
|---|---|---|
| ETL-10 | `DimCustomer.segment` | Évalué **le 1er jour de chaque mois (UTC)**, pour chaque client, dans cet ordre : (1) `nouveau` si `Customer.created_at` date de moins de 90 jours ; (2) `dormant` si, sinon, aucune transaction aboutie (statuts `successful` ou `refunded`) sur les 180 derniers jours ; (3) `VIP` si, sinon, la somme de `amount_eur` des transactions abouties des 12 derniers mois place le client parmi les 5 % supérieurs de son marchand (seulement si le marchand compte au moins 20 clients actifs, un client actif étant un client ayant au moins une transaction aboutie sur les 12 derniers mois ; sinon on passe à (4)) ; (4) `régulier` dans tous les autres cas. Une nouvelle version SCD2 (`valid_from` = jour d'évaluation) n'est créée que si le segment change. *Hypothèse de conception : 90 jours, 180 jours, 5 %, 20 clients, définition du client actif.* Aucune de ces valeurs ne vient de l'OLTP. |
| ETL-11 | `DimAuditAction.action_group` | Correspondance fixe sur `AuditAction.action_code` : `read`, `export`, `login` → `lecture` (actions du journal des accès, `DataAccessLog`) ; `create`, `update`, `delete` → `ecriture` ; `grant`, `revoke` → `administration` (modification d'un état d'autorisation). `login` est classé `lecture` parce qu'il est journalisé dans `DataAccessLog` ; il n'est pas une lecture de données : une analyse « lectures de données » l'exclut par `action_code`. Un `action_code` inconnu interrompt le chargement de la dimension (pas de groupe par défaut). |

**Pourquoi un recalcul mensuel pour le segment.** Un recalcul quotidien créerait une version SCD2 chaque fois qu'un client franchit un seuil, et le fait se rattache à la version en vigueur le jour de la transaction (ETL-01) : le segment d'une transaction est donc celui du début de mois. Une mini-dimension de segments est écartée : elle serait une seconde dimension liée au fait pour un seul attribut, alors que les dimensions restent indépendantes (\[D3-A\] 2.A.4).

#### 2.C.3.3. `FactTransaction`

| ID | Colonne | Règle |
|---|---|---|
| ETL-20 | `is_refunded`, `refund_amount_minor`, `refund_amount_eur` | `is_refunded` est vrai si la transaction a un `Refund` (au plus un, règle MCD #13), y compris pour un remboursement partiel. `refund_amount_minor` = `Refund.amount` (0 sinon) ; `refund_amount_eur` est converti une seule fois, au taux de la transaction (2.C.1.3). Le statut `refunded` de `Transaction` n'est pas la source ; un désaccord entre ce statut et l'existence d'un `Refund` est signalé comme anomalie de chargement, non corrigé. |
| ETL-21 | `is_chargeback` | Vrai si la transaction a un `Chargeback` (au plus un, règle MCD #14), **quel que soit son statut** (`open`, `won`, `lost`) : un litige gagné par le marchand reste un litige. Le fait ne porte ni le statut ni un montant perdu ; `merchant_net_revenue_eur` n'est donc pas diminué par une rétrofacturation. |
| ETL-22 | `anomaly_score` | `FraudScore.anomaly_score` de la transaction ; NULL si elle n'a pas été évaluée. |

La date d'un remboursement ou d'un litige n'est pas portée par le fait : `date_key` reste la date de la transaction.

<div style="page-break-after: always;"></div>

#### 2.C.3.4. `FactFraudEvent`

| ID | Colonne | Règle |
|---|---|---|
| ETL-30 | ligne, `risk_level_key`, `anomaly_score`, `date_key` | Une ligne par `FraudScore` (1:1 avec la transaction). `risk_level_key` désigne `FraudScore.risk_level_code` ; `anomaly_score` est copié ; `date_key` est la date UTC de `FraudScore.evaluated_at`. |
| ETL-31 | `exposed_amount_eur` | Reprise de `FactTransaction.amount_eur` de la transaction évaluée : même valeur, même taux, aucune nouvelle conversion, donc les deux faits concordent. |
| ETL-32 | `is_confirmed_fraud` | Faux à l'insertion. Devient vrai quand la transaction a une `FraudDecision` avec `decision_value = 'fraud'` **et** `decision_status = 'confirmed'` (règle MCD #41). Une décision `defaulted` (décision automatique faute de revue), même « fraud », n'est pas une fraude confirmée ; une décision `legitimate` non plus. La colonne suit l'état courant de la décision. Une rétrofacturation, même de catégorie `fraud`, n'est pas une source : elle ne vaut pas décision. |

#### 2.C.3.5. `FactSubscriptionSnapshot`

Les valeurs sont celles de l'abonnement à l'instant de l'instantané, lues après la tentative de prélèvement de fin de période.

| ID | Colonne | Règle |
|---|---|---|
| ETL-40 | `mrr_eur` | 0 si le statut n'est pas facturable (`DimSubscriptionStatus.is_billable = false`). Sinon, `ROUND( Subscription.amount / 10^decimals × reference_rate × f , 4 )`, avec `f` = 52/12 (`weekly`), 1 (`monthly`), 1/12 (`yearly`) d'après `Subscription.billing_cycle`. Le taux est celui de (devise de l'abonnement, exercice de la date de l'instantané) ; il est tracé par `exchange_rate_key` du fait, qui désigne aussi la devise (`from_currency_code`). Un seul arrondi, à la fin, demi-supérieur (2.C.1.3). |
| ETL-41 | `stripe_mrr_eur` | Même calcul que `mrr_eur`, appliqué à `Transaction.fee_amount` de la **dernière transaction aboutie** de l'abonnement (`Transaction.subscription_id`) à la date de l'instantané, dans la devise de cette transaction, supposée égale à celle de l'abonnement (même `exchange_rate_key` que `mrr_eur`). La commission est reprise, non recalculée. 0 si le statut n'est pas facturable ou s'il n'y a pas encore de transaction aboutie. *Limite :* après un changement de plan tarifaire, la valeur ne bouge qu'au prélèvement suivant. |
| ETL-42 | `is_active` | Vrai si `Subscription.status_code = 'active'`. `paused`, `past_due` et `canceled` donnent faux. Une demande de résiliation ne change rien avant la fin de période (règle MCD #20). |
| ETL-43 | `days_until_renewal` | `Subscription.current_period_end` (jour UTC) moins `date_key`, si cette date est postérieure à `date_key` ; NULL sinon (abonnement non renouvelé, ou `current_period_end` absente). |
| ETL-44 | `started_date_key`, `canceled_date_key` | Jour UTC de `Subscription.started_at` ; jour UTC de `Subscription.canceled_at`, NULL tant qu'aucune demande n'existe. Valeur connue à la date de l'instantané : les instantanés antérieurs à la demande gardent NULL. |

#### 2.C.3.6. `AggSubscriptionDailyMerchant`

Grain : jour `D` (UTC) × marchand × produit. Les compteurs comptent des abonnements distincts (`subscription_id`).

| ID | Colonne | Règle |
|---|---|---|
| ETL-50 | `new_subscriptions` | Abonnements dont `started_date_key = D`. |
| ETL-51 | `churned_count` | Abonnements dont `canceled_date_key = D` : ce sont des **demandes de résiliation**. Les fins d'abonnement par échecs de prélèvement répétés (`canceled_at` vide, règle MCD #20) ne sont pas comptées. |
| ETL-52 | `active_subscriptions`, `past_due_subscriptions` | État au jour `D` : le dernier instantané de l'abonnement dont `date_key ≤ D` est reporté jusqu'à l'instantané suivant. `active_subscriptions` : `is_active` vrai ; `past_due_subscriptions` : `DimSubscriptionStatus.triggers_dunning` vrai. |
| ETL-53 | `churn_rate` | `churned_count(D) / active_subscriptions(D − 1)`, arrondi à la 4e décimale (demi-supérieur) ; NULL si le dénominateur est 0. |

<div style="page-break-after: always;"></div>

**Compteurs provisoires.** Un abonnement n'apparaît dans le fait qu'à son premier instantané, à la fin de sa première période : pour un abonnement annuel, `new_subscriptions` du jour de souscription ne devient exact qu'un an plus tard. Il en va de même de `churned_count` pour une demande de résiliation faite entre deux instantanés. L'ETL recalcule les jours concernés à chaque chargement d'instantanés ; les compteurs des cycles récents sont donc à lire comme provisoires. Pour des compteurs exacts le jour même, il faudrait produire aussi un instantané à la souscription et à la demande de résiliation, ce qui change le grain actuel (\[D3-A\] 2.A.3) ; ce n'est pas retenu à ce stade.

#### 2.C.3.7. `FactAuditEvent`

| ID | Source | Règle |
|---|---|---|
| ETL-60 | `DataAccessLog` | Une ligne par entrée. `audit_action_key` d'après `action_code` ; `actor_key` : version de (`actor_id`, `actor_type_code`) en vigueur à la date de l'événement (ETL-01) ; `merchant_key` et `customer_key` : NULL si l'entrée n'en désigne pas (règle MCD #29) ; `geography_key` : pays résolu depuis `source_ip` (\[D3-A\] 2.A.4) ; `resource_type` copié ; `was_authorized` copié ; `had_justification` vrai si `justification` n'est ni NULL ni vide. |
| ETL-61 | `ChangeAuditLog` | Une ligne par entrée. `merchant_key` : celui de l'entrée, NULL s'il n'y en a pas ; `customer_key` : **toujours NULL** (une écriture ne vise jamais un client isolément, règle MCD #31) ; `geography_key` : membre « unknown » ; `resource_type` = `table_name` ; `was_authorized` = vrai (le journal ne contient que des écritures exécutées, pas de refus) ; `had_justification` = faux, ce qui signifie ici « non journalisée » et non « injustifiée » : l'OLTP ne conserve pas de motif sur ce journal. Les analyses de justification se limitent donc aux lignes `action_group = 'lecture'` (ETL-11). |
| ETL-62 | contrôle | Quand une entrée de `DataAccessLog` désigne un client et un marchand, le client doit appartenir à ce marchand (règle MCD #33). L'ETL signale l'écart comme anomalie de chargement ; il ne le corrige pas. |

#### 2.C.3.8. Politiques et règles de transformation à définir

Les points ci-dessous ne sont pas tranchés. Pour chacun de ces points, le tableau expose la situation actuelle du modèle et ce qui reste à définir - sans proposer de solution. Les valeurs retenues provisoirement ailleurs dans §2.C.3 sont signalées.

| ID      | Sujet                                                      | Situation actuelle                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | À définir                                                                                                                                                                                                                                                |
| ------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| O-01 | Date d'un remboursement ou d'un litige                     | `FactTransaction` ne porte que la date de la transaction (`date_key`). `is_refunded`, `refund_amount_eur` et `is_chargeback` sont donc rattachés au jour de la transaction (ETL-20, ETL-21), et `AggRevenueDailyMerchant.refund_total_eur` en reprend la date.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Si le reporting doit situer un remboursement ou un litige à sa propre date, et, dans ce cas, comment la date est portée par le modèle.                                                                                                                   |
| O-02 | Commission en cas de remboursement                         | `fee_amount_minor` est repris de l'OLTP et un remboursement ne le modifie pas (ETL-02, ETL-20). `stripe_revenue_eur` reste donc égal à `fee_amount_eur`, et `merchant_net_revenue_eur = amount_eur − fee_amount_eur − refund_amount_eur` laisse la commission à la charge du marchand, y compris pour un remboursement partiel.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | La politique applicable à la commission d'une transaction remboursée (conservée, restituée en tout ou en partie, selon le type de remboursement) et la manière dont le modèle la reflète.                                                                |
| O-03 | Grain de l'instantané d'abonnement                         | Un instantané est produit à la fin de chaque période de facturation (\[D3-A\] 2.A.3). Un abonnement entre donc dans le fait à la fin de sa première période, et `new_subscriptions` ainsi que `churned_count` sont provisoires jusqu'à l'instantané suivant (2.C.3.6).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Si des instantanés doivent aussi être produits à la souscription ou à la demande de résiliation, et l'effet de ce choix sur le grain décrit en \[D3-A\] (2.A.3).                                                                                         |
| O-04 | Définition du churn                                        | `churned_count` compte les demandes de résiliation (`canceled_date_key`, ETL-51). Les fins d'abonnement par échecs de prélèvement répétés (`canceled_at` vide, règle MCD #20) ne sont pas comptées. `churn_rate` rapporte ces demandes aux abonnements actifs de la veille (ETL-53).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Ce que « churn » désigne (demande de résiliation, fin effective, ou les deux), le traitement des fins sans demande, et le dénominateur du taux.                                                                                                          |
| O-05 | `had_justification` pour `ChangeAuditLog`                  | La colonne est `not null` ; pour une ligne issue de `ChangeAuditLog` elle vaut faux, ce qui signifie « non journalisée » et non « injustifiée » (ETL-61), car l'OLTP ne conserve pas de motif sur ce journal.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Comment représenter « information absente » distinctement de « pas de justification », et comment les analyses de justification (`DimAuditAction.requires_justification`) en tiennent compte.                                                            |
| O-06 | `DimActor.is_human`                                        | La colonne est `not null` avec la valeur par défaut faux. Dans l'OLTP, `AuditActorType.is_human` est indéterminé pour le type `merchant_api`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Comment représenter un acteur dont la nature humaine ou automatique est indéterminée.                                                                                                                                                                    |
| O-07 | Valeurs retenues provisoirement par 2.C.3                  | Aucune de ces valeurs ne vient de l'OLTP : seuils du segment client (90 jours, 180 jours, 5 %, 20 clients ; ETL-10) ; `login` classé `lecture` (ETL-11) ; `is_chargeback` vrai pour tous les statuts de litige (ETL-21) ; `is_confirmed_fraud` défini par la décision de fraude confirmée (ETL-32), en remplacement de l'ancienne mention d'une rétrofacturation ; `stripe_mrr_eur` pris sur la commission de la dernière transaction aboutie (ETL-41) ; `mrr_eur` nul pour un statut non facturable, selon des valeurs de `is_billable` qui sont des données de référence (ETL-40) ; `is_active` vrai pour le seul statut `active` (ETL-42) ; client actif = au moins une transaction aboutie sur 12 mois (ETL-10) ; devise de la commission de la dernière transaction aboutie supposée égale à celle de l'abonnement, l'OLTP n'imposant pas cette égalité (ETL-41) ; rechargement de `FactAuditEvent` par jour (ETL-03).                                                          | La validation métier de chacune de ces valeurs.                                                                                                                                                                                                          |
| O-08 | Visibilité des lignes sans marchand                        | `FactAuditEvent.merchant_key` et `FactSecurityIncident.merchant_key` sont nullables (accès ou incident transverses à la plateforme). La sécurité au niveau des lignes repose sur `merchant_id` (\[D3\] D3.5.7) : une ligne sans marchand n'est visible d'aucun marchand.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Qui peut lire les lignes sans marchand (rôles internes), et la politique correspondante.                                                                                                                                                                 |
| O-09 | Règles ETL manquantes sur les faits                        | Aucune règle de transformation n'est écrite pour : `FactDataSubjectRequest` (`processing_days`, `is_within_deadline`, mise à jour à chaque jalon, `request_status_key`) ; `FactSecurityIncident` (`detection_to_notification_hours`, `is_within_72h_deadline`, jalons, `incident_status_key`) ; `FactTransaction.is_merchant_initiated` et la mise à jour de `status_key` après l'insertion.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Les règles de calcul et de mise à jour de ces colonnes.                                                                                                                                                                                                  |
| O-10 | Règles ETL manquantes sur les agrégats                     | Seules les colonnes de `AggSubscriptionDailyMerchant` portant sur les compteurs et le taux de churn ont des règles (2.C.3.6). Restent sans règle : `merchant_mrr_eur` et `stripe_mrr_eur` de cette table (MRR brut ou net de la commission) ; `AggRevenueDailyMerchant` ; `AggRevenueMonthlyMerchantCountry` (le pays visé par `country_code` : transaction, client ou marchand) ; `AggFraudDailyMerchant` (`high_risk_count`, `confirmed_fraud_count`, `fraud_rate`) ; `AggComplianceDailyMerchant` (`total_access_count`, `sensitive_access_count`, `unauthorized_attempt_count`, `distinct_actor_count`, `export_count`) ; `AggDataSubjectRequestMonthly` et `AggSecurityIncidentMonthly` (mois de rattachement). Les lignes sans marchand (O-08) ne sont pas reçues par `AggComplianceDailyMerchant`, qui compte les accès aux données d'un marchand ; `AggSecurityIncidentMonthly` les regroupe sous une clé marchand nulle (clé unique `NULLS NOT DISTINCT`, non primaire). | Les règles de calcul, le jour ou le mois de rattachement et la fréquence de recalcul de chaque agrégat, et le traitement des lignes sans marchand dans chacun.                                                                                           |
| O-11 | Provenance et chargement des dimensions                    | \[D3-A\] (2.A.4) indique l'origine OLTP de chaque dimension, mais aucune règle n'en décrit le chargement : création des versions SCD2 de `DimMerchant`, `DimCustomer` (hors segment), `DimPricingPlan` et `DimActor` (l'identité des acteurs est gérée hors du modèle, règle MCD #28) ; génération de `DimDate` (plage de dates) ; chargement annuel de `DimReferenceExchangeRate` (source, reprise de l'historique) ; mise à jour des dimensions statiques.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Les règles de chargement de chaque dimension.                                                                                                                                                                                                            |
| O-12 | Clés étrangères nulles (revue critique D3, §1.4)           | Plusieurs clés de fait sont nullables : `FactTransaction.product_key` ; `FactAuditEvent.merchant_key` et `customer_key` ; `FactSecurityIncident.merchant_key` ; les dates de jalon `FactSubscriptionSnapshot.canceled_date_key`, `FactDataSubjectRequest.fulfilled_date_key`, `FactSecurityIncident.notified_date_key` et `resolved_date_key`. Une jointure interne supprime ces lignes ; D8.2 utilise des jointures externes lorsque la clé est nullable. La matrice de bus (\[D3-A\] 2.A.6) indique que `DimMerchant` traverse les six processus, alors que `FactSecurityIncident.merchant_key` peut être nul.                                                                                                                                                                                                                                                                                                                                                                     | Si ces clés doivent référencer un membre par défaut de la dimension (inconnu, non applicable, plateforme, date à venir) plutôt que `NULL`, pour quelles colonnes, et l'effet sur les indicateurs de jalon (`IS NOT NULL`), la matrice de bus et O-08. |
| O-13 | Agrégats et versions de marchand (revue critique D3, §1.3) | Les sept agrégats portent `merchant_key`, donc une version du marchand. Un agrégat quotidien a une seule version par jour, mais un agrégat mensuel (`AggRevenueMonthlyMerchantCountry`, `AggDataSubjectRequestMonthly`, `AggSecurityIncidentMonthly`) peut compter deux lignes pour un même marchand et un même mois si sa version change dans le mois. `churn_rate` (ETL-53) rapporte `active_subscriptions(D − 1)` à `churned_count(D)` : les deux jours peuvent avoir des `merchant_key` différentes.                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | La clé du marchand dans les agrégats (clé métier `merchant_id` ou version) et la règle de rattachement d'un mois ou d'un jour à une version.                                                                                                             |

---

### Références

#### Livrables
- \[D3\] [OLAP System Schema Design](stripe-step-2--olap-design.pdf)

#### Annexes
- \[D3-A\] [OLAP Kimball Analysis](stripe-step-2--olap-annexe-a--kimball-analysis.pdf)
- \[D3-B\] [OLAP Physical Data Model](stripe-step-2--olap-annexe-b--dbml.dbml)
- \[D2-A\] [OLTP Conceptual Data Model](stripe-step-1--oltp-annexe-a--mcd.pdf)
- \[D2-B\] [OLTP Physical Data Model](stripe-step-1--oltp-annexe-b--dbml.dbml)

#### Spécifications
- \[D0\] [Stripe Project Introduction](stripe-step-0--introduction.pdf)
