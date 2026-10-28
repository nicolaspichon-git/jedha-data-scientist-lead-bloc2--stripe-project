---
version: v18
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-2
  - stripe-project/deliverables
  - stripe-project/deliverables/D3
  - stripe-project/olap
  - stripe-project/olap/design
---

*STRIPE* PROJECT
===

# 2. OLAP Data System
## D3. OLAP System Schema Design

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / D3 : OLAP System Schema Design / v18 --- 2026/11/05.*
---

### D3.1. Contexte

Ce document présente le schéma de l'entrepôt analytique : 
- organisation du schéma en étoiles, 
- stratégie d'agrégation, 
- techniques d'optimisation des requêtes. 

> Convention de notation des cardinalités dans les diagrammes présentés :  notation *crow's foot*,
> - \> `||` = un et un seul, `o{`  = zéro à plusieurs.

L'analyse préliminaire des processus métiers est donnée en annexe \[D3-A\]. Six processus métiers sont identifiés en se basant sur les catégories des données analytiques données dans le document de spécifications du cas d'étude \[D0\] :

| #   | Processus métier                     | Source de données analytiques | Événement déclencheur |
| --- | ------------------------------------ | ----------------------------- | --------------------- | 
| P1  | Traitement d'un paiement             | *Revenue Metrics*, *Product Performance*, *Customer Segmentation* | Création d'une transaction |
| P2  | Évaluation du risque de fraude       | *Fraud Analysis Data* | Calcul d'un score de fraude |
| P3  | Cycle de vie d'un abonnement         | *Revenue Metrics* | Arrivée à échéance d'un abonnement |
| P4  | Accès et modification de données     | *Compliance and Audit Logs* | Journalisation d'une consultation ou d'une modification |
| P5  | Traitement d'une demande de droit    | *Compliance and Audit Logs* | Demande d'application d'un droit RGPD/CCPA |
| P6  | Traitement d'un incident de sécurité | *Compliance and Audit Logs* | Détection d'un incident de sécurité |

### D3.2. Schémas en étoile

Dans le schéma en étoile (*star*), chaque *dimension* est directement reliée à la *table de faits*, sans hiérarchie de sous-dimensions normalisées.

###### Justification
L'architecture en flocons (*snowflake*) réduit la redondance au prix de jointures supplémentaires ; en lecture analytique, c'est l'inverse de l'objectif recherché (*TR1* \[D0\]  : *"optimize performance across all systems"*). La dénormalisation assumée dans les dimensions coûte en stockage mais pas en temps de requête.

###### Dimensions indépendantes
Aucune dimension ne référence une autre dimension : seules les tables de faits portent des clés étrangères vers les dimensions. `DimMerchant` étant en *SCD2*, une clé étrangère `DimCustomer` → `DimMerchant` désignerait une version du marchand et obligerait à versionner tous ses clients, produits et plans tarifaires à chaque changement du marchand. `DimCustomer`, `DimProduct` et `DimPricingPlan` portent donc `merchant_id` (clé métier de l'OLTP, sans lien) ; le marchand d'une ligne de fait reste `merchant_key` du fait. De même, `DimReferenceExchangeRate` identifie la devise source par `from_currency_code`, sans clé étrangère vers `DimCurrency` \[D3-A\] (2.A.4).

### D3.3. Les étoiles des processus métiers

Les diagrammes ci-dessous présentent les schémas en étoile de chaque processus métier. 

Chaque étoile a son propre diagramme (six diagrammes pour six processus) : 
- *Transactions* (P1), 
- *Fraudes* (P2), 
- *Abonnements* (P3), 
- *Lectures et écritures des données* (P4). 
- *Demandes de droit* (P5). 
- *Incidents de Sécurité* (P6). 

> Rappel : chaque processus métier a son propre grain. Les étoiles ne partagent aucune ligne, seulement des dimensions conformées (`DimDate`, `DimMerchant`, `DimCustomer`, `DimGeography`...), voir la matrice de bus \[D3-A\] (2.A.6).

<div style="page-break-after: always;"></div>

#### D3.3.1. Revenus (P1/FactTransaction)

![[stripe-step-2--olap-design--diagram-p1.svg]]

Grain : `FactTransaction` (une transaction). 

Les propriétés `merchant_net_revenue_eur` et `stripe_revenue_eur` cohabitent sur la même ligne. Les deux audiences du reporting (marchands & Stripe) lisent la même table, seule la colonne agrégée change (voir note dans le modèle physique\[D3-B\]).

Montants : entiers en unités mineures (`amount_minor`, `fee_amount_minor`, `refund_amount_minor`) et valeurs en EUR (`decimal(18,4)`) converties au taux de référence (règles en D3.5.6). La commission `fee_amount_minor` est reprise de l'OLTP (`Transaction.fee_amount`) ; elle n'est **jamais recalculée** côté OLAP.

Géographie : `geography_key` (non nulle) désigne le pays où la transaction a été initiée et le type d'appareil. Le pays est résolu à l'ETL à partir de `Transaction.ip_geolocation` (adresse IP, GeoIP en version figée) ; l'adresse IP n'est jamais copiée dans l'OLAP (RGPD). Une IP absente ou non résolue donne le membre par défaut « unknown » (`country_code = 'ZZ'`).

<div style="page-break-after: always;"></div>

#### D3.3.2. Fraudes (P2/FactFraudEvent)

![[stripe-step-2--olap-design--diagram-p2.svg]]

Grain : un événement d'évaluation du risque de fraude (fait transactionnel). `is_confirmed_fraud` est la seule colonne mise à jour après l'insertion, quand la décision de fraude est confirmée \[D3-A\] (2.A.3 et ETL-02).

`date_key` est la date UTC de l'évaluation (`FraudScore.evaluated_at`). `geography_key` est non nulle et résolue comme pour `FactTransaction` (D3.3.1) ; `exposed_amount_eur` est converti au taux de référence (D3.5.6).

#### D3.3.3. Abonnements (P3/FactSubscriptionSnapshot)

![[stripe-step-2--olap-design--diagram-p3.svg]]

Grain : `FactSubscriptionSnapshot` (un instantané d'abonnement capturé périodiquement). 

`mrr_eur` et `stripe_mrr_eur` décrivent un état à un instant donné, et non un événement : ils sont semi-additifs (à ne pas sommer sur plusieurs dates pour un même abonnement). Ils sont convertis au taux de référence fixe (D3.5.6). `date_key` est la date UTC de l'instantané. `started_date_key` (début de l'abonnement) et `canceled_date_key` (demande de résiliation, vide s'il n'y en a pas) sont deux autres rôles de `DimDate` ; elles alimentent `new_subscriptions` et `churned_count` de `AggSubscriptionDailyMerchant`. Une résiliation demandée n'arrête pas l'abonnement avant la fin de la période déjà facturée : `churned_count` compte des demandes de résiliation, pas des abonnements terminés \[D3-A\] (2.A.8 et 2.A.9.6).

#### D3.3.4. Lectures et écritures (P4/FactAuditEvent)

![[diagrams/stripe-step-2--olap-design--diagram-p4.svg]]

Grain : un événement d'audit, accès (`DataAccessLog`) **ou** modification (`ChangeAuditLog`). 

`geography_key` est non nulle. Pour les accès, le pays est résolu depuis `DataAccessLog.source_ip` ; pour les modifications (alimentées par CDC, sans IP dans l'OLTP), la ligne reçoit le membre « unknown ». `device_type` vaut toujours `unknown` pour ce fait : une analyse par pays ne couvre donc que les accès \[D3-A\] (2.A.4). `event_timestamp` est un `timestamptz` UTC.

#### D3.3.5. Demandes de droits (P5/FactDataSubjectRequest)

![[diagrams/stripe-step-2--olap-design--diagram-p5.svg]]

Grain : une demande de droit, mise à jour au fur et à mesure de son traitement. 

`FactDataSubjectRequest` référence `DimDate` deux fois (`received_date_key` à la réception, `fulfilled_date_key` au traitement, renseignée plus tard). C'est la signature d'un instantané cumulatif *Kimball* : plusieurs jalons temporels sur une même ligne, mise à jour au fur et à mesure du processus, au lieu de créer une nouvelle ligne par événement.

#### D3.3.6. Incidents de sécurité (P6/FactSecurityIncident)

![[diagrams/stripe-step-2--olap-design--diagram-p6.svg]]

Grain : un incident de sécurité, mis à jour au fur et à mesure de son traitement. 

`FactSecurityIncident` référence `DimDate` trois fois (`detected_date_key`, `notified_date_key`, `resolved_date_key` : détection, notification, résolution) : même logique d'instantané cumulatif que pour D3.3.5. Cette étoile ne porte ni `DimCustomer` ni `DimGeography`.

<div style="page-break-after: always;"></div>

### D3.4. Stratégie d'agrégation

**Principe constant** : *le fait atomique reste au grain le plus fin, les agrégats sont des
tables séparées, calculées. 

**Dénormalisation différenciée entre fait atomique et agrégat** : le fait atomique référence
toujours une dimension par clé (`regulation_key`, par exemple) pour permettre n'importe quel
angle d'analyse ; l'agrégat précalculé garde parfois l'attribut en clair (par exemple, `regulation` dans `AggDataSubjectRequestMonthly`) pour pouvoir être interrogeable sans jointure (noter qu'un agrégat n'a pas vocation à être recombiné avec d'autres dimensions, il doit juste répondre vite à une question déjà posée).

Le tableau suivant expose les tables d'agrégation présentes dans le modèle physique \[D3-B\]. Les jours et les mois des agrégats sont des jours et des mois UTC (D3.5.2).

| Table d'agrégat                | Grain | Alimentée depuis | Sert |
| ------------------------------ | ----- | ---------------- | --- |
| `AggRevenueDailyMerchant`      | Jour × marchand | `FactTransaction` | Tableau de bord marchand (quasi temps réel) |
| `AggRevenueMonthlyMerchantCountry` | Mois × marchand × pays | `FactTransaction` | Reporting géographique |
| `AggFraudDailyMerchant`        | Jour × marchand | `FactFraudEvent` | Alerting fraude |
| `AggSubscriptionDailyMerchant` | Jour × marchand × produit | `FactSubscriptionSnapshot` | Tableau de bord abonnements |
| `AggComplianceDailyMerchant`   | Jour × marchand | `FactAuditEvent` | Reporting conformité automatisé |
| `AggDataSubjectRequestMonthly` | Mois × marchand × réglementation × type | `FactDataSubjectRequest` | Rapport RGPD/CCPA |
| `AggSecurityIncidentMonthly`   | Mois × marchand × sévérité | `FactSecurityIncident` | Rapport sécurité |


### D3.5. Techniques d'optimisation des requêtes

#### D3.5.1. Clés de substitution entière
Déclarer les clés de substitution comme des entiers plutôt que des identifiants UUID. 
Le format entier est nécessaires pour mettre en place un versionnement *SCD2* (un même `merchant_id` dans la base OLTP correspondra à plusieurs `merchant_key` dans la base OLAP, au fur et à mesure des modification de l'entité marchande).

#### D3.5.2. `DimDate` précalculées
Un pré-calcul des informations d'horodatage dans `DimDate`évite les fonctions de date dans les clauses `WHERE` (`EXTRACT`, `DATE_TRUNC`...). Les fonctions de date empêchent l'*élagage de partitions* dans la plupart des moteurs orientés colonnes. `DimDate` permet aussi de faire des comparaisons période sur période par simple jointure sur `date_key`.

**Fuseau horaire : tout est en UTC** \[D3-A\] (2.A.8). `date_key` (et chaque `*_date_key`) est la date UTC de l'événement ; les horodatages sont des `timestamptz` (jamais un `timestamp` sans fuseau) ; « aujourd'hui » s'écrit `(now() AT TIME ZONE 'UTC')::date` et non `CURRENT_DATE`, qui dépend du fuseau de la session. Il n'y a ni `DimTime` ni fuseau local par marchand : l'extension (`Merchant.timezone`, `local_date_key`) n'est pas retenue en l'absence de besoin exprimé.

#### D3.5.3. Partitionnement par `date_key`
Le partitionnement par `date_key` (date UTC) est systématique sur les tables de faits à fort volume
(`FactTransaction`, `FactAuditEvent`). Il est mensuel ou quotidien selon le volume réel. 
L'*élagage de partitions* élimine la majorité des lignes avant même le scan.

#### D3.5.4. Stockage orienté colonnes
Systèmes courants :  *Redshift*, *BigQuery*, *Snowflake* ou *ClickHouse* ; cohérent avec des requêtes qui agrègent peu de colonnes sur beaucoup de lignes (l'inverse du pattern *OLTP*).

#### D3.5.5. Diffusion des dimensions
**Diffusion des dimensions (*broadcast join*).** Les dimensions restent petites en volume
(quelques milliers à millions de lignes, jamais à l'échelle des faits) - elles peuvent être
répliquées sur chaque nœud de calcul plutôt que redistribuées, évitant un *shuffle* coûteux
lors de la jointure avec une table de faits partitionnée.

#### D3.5.6. Taux de change de référence fixe
**Taux de change fixe (`DimReferenceExchangeRate`).** Au-delà de la comparabilité déjà
justifiée (2.A.7), c'est aussi une optimisation : convertir au vol au taux du jour
demanderait une jointure sur une dimension à cardinalité temporelle fine ; le taux figé par
exercice réduit drastiquement le nombre de versions à joindre.

**Règle de conversion et types** \[D3-A\] (2.A.7) :
- montants locaux : `bigint` en unités mineures (`*_minor`), l'échelle étant portée par `DimCurrency.decimals` ;
- `amount_eur = amount_minor / 10^decimals × reference_rate`, où `reference_rate` (`decimal(24,12)`) est exprimé en EUR pour 1 unité majeure de la devise source ;
- montants en EUR : `decimal(18,4)`, calculés une seule fois à l'ETL en décimal exact, arrondis à la 4e décimale (demi-supérieur) ; l'arrondi à 2 décimales est réservé à l'affichage ;
- une seule conversion par composante (montant, commission, remboursement) ; les mesures dérivées sont calculées sur les valeurs déjà converties ;
- le taux retenu est celui de (devise source, exercice) pour la date de création UTC de la transaction ;
- la commission est reprise de l'OLTP et n'est jamais recalculée.

#### D3.5.7. Sécurité RLS
**Sécurité au niveau des lignes (RLS), pas de filtrage applicatif.** Un marchand consultant
son reporting ne doit voir que ses propres lignes (`merchant_key`) ; imposé par une politique
RLS au niveau du moteur, jamais laissé à la charge de la requête applicative, pour qu'aucun
bug côté client ne puisse exposer les données d'un autre marchand. La politique porte sur `merchant_key` dans les faits, et sur `merchant_id` dans les dimensions propres à un marchand (`DimCustomer`, `DimProduct`, `DimPricingPlan`).
#### D3.5.8. Index ciblés
**Index ciblés sur les clés de jointure et les colonnes de filtrage fréquent** - `date_key`
et `(merchant_key, date_key)` systématiques sur les faits, complétés par les clés métier
(`transaction_id`, `subscription_id`...) pour le dédoublonnage à l'ETL et le rapprochement
avec l'OLTP, et par `merchant_id` sur `DimCustomer`, `DimProduct` et `DimPricingPlan` (filtre RLS).

### D3.6. Règles de transformation (ETL)

Les valeurs que l'OLTP ne fournit pas telles quelles (segment client, regroupement des actions d'audit, remboursement et litige, fraude confirmée, MRR et compteurs d'abonnements, valeurs des événements d'écriture) sont définies par des règles numérotées `ETL-nn`, réunies dans \[D3-A\] (2.A.9) et citées dans les notes du modèle physique \[D3-B\]. Trois principes les gouvernent : la version de dimension SCD2 est celle en vigueur le jour UTC du fait ; seules quelques colonnes d'indicateurs sont mises à jour après l'insertion d'un fait (remboursement, litige, fraude confirmée) ; un rechargement redonne les mêmes lignes. Les seuils de segmentation et certains mappings sont des hypothèses de conception, signalées comme telles. Les politiques et règles non encore définies sont exposées en \[D3-A\] (2.A.9.8).

---

### Couverture des exigences

| # | Exigence \[D0\]                                       | Couverture                                          |
| - | ----------------------------------------------------- | --------------------------------------------------- |
| **BR2** | analyse de revenu, segmentation, conformité | Six étoiles couvrant chacun des besoins (D3.3)      |
| **TR1** | normalisation OLTP / performance OLAP       | Dénormalisation assumée, justifiée section D3.2     |
| **TR3** | scalabilité, indexation, partitionnement    | Partitionnement par `date_key`, index ciblés (D3.5) |

---

### Références

#### Annexes
- \[D3-A\] [OLAP Kimball Analysis](stripe-step-2--olap-annexe-a--kimball-analysis.pdf)
- \[D3-B\] [OLAP Physical Data Model](stripe-step-2--olap-annexe-b--dbml.dbml)

#### Spécifications
- \[D0\] [Stripe Project Introduction](stripe-step-0--introduction.pdf)
