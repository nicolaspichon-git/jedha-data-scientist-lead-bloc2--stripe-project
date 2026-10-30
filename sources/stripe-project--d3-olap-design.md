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
  - stripe-project/deliverables
  - stripe-project/deliverables/D3
  - stripe-project/olap
  - stripe-project/olap/design
---
*STRIPE* PROJECT
===

# 2. OLAP Data System
## D3. OLAP System Schema Design

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / D3 : OLAP System Schema Design / v22 --- 2026/11/05.*
---

### D3.1. Contexte

Ce document présente le schéma de l'entrepôt analytique : 
- organisation du schéma en étoiles, 
- stratégie d'agrégation, 
- techniques d'optimisation des requêtes. 

> Convention de notation des cardinalités dans les diagrammes présentés :  notation *crow's foot*,
> - \> `||` = un et un seul, `o{`  = zéro à plusieurs.

L'analyse préliminaire des processus métiers est donnée en annexe \[D3-A\]. Six processus sont identifiés en se basant sur les catégories des données analytiques présentées dans le cahier des charges \[D0\] :

| #   | Processus métier                     | Source de données analytiques | Événement déclencheur |
| --- | ------------------------------------ | ----------------------------- | --------------------- | 
| P1  | Traitement d'un paiement             | *Revenue Metrics*,<br*Product Performance*, *Customer Segmentation* | Création d'une transaction |
| P2  | Évaluation du risque de fraude       | *Fraud Analysis Data* | Calcul d'un score de fraude |
| P3  | Cycle de vie d'un abonnement         | *Revenue Metrics* | Arrivée à échéance d'un abonnement |
| P4  | Accès et modification de données     | *Compliance and Audit Logs* | Journalisation d'une consultation ou d'une modification |
| P5  | Traitement d'une demande de droit    | *Compliance and Audit Logs* | Demande d'application d'un droit RGPD/CCPA |
| P6  | Traitement d'un incident de sécurité | *Compliance and Audit Logs* | Détection d'un incident de sécurité |

### D3.2. Schémas en étoile

Dans le schéma en étoile (*star schema*), chaque *dimension* est directement reliée à la *table de faits*, sans hiérarchie de sous-dimensions normalisées.

###### Justification
L'architecture en flocons (*snowflake schema*) réduit la redondance au prix de jointures supplémentaires. En lecture analytique, c'est l'inverse de l'objectif recherché. La *dénormalisation* assumée dans les dimensions coûte en stockage mais gagne en temps de requête.

###### Dimensions indépendantes
Aucune dimension ne référence une autre dimension : seules les tables de faits portent des clés étrangères vers les dimensions. 

`DimMerchant` étant une *SCD2* (\*), une clé étrangère (`key`) de type `DimCustomer` → `DimMerchant` désignerait une version spécifique du marchand et obligerait à versionner tous ses clients, produits et plans tarifaires à chaque changement du marchand. `DimCustomer`, `DimProduct` et `DimPricingPlan` portent donc `merchant_id` (la clé métier de l'OLTP) seule. La version de marchand d'une ligne de fait (*fact*) reste identifiée par `merchant_key`. 

De même, `DimReferenceExchangeRate` identifie la devise source par `from_currency_code`, sans clé étrangère vers `DimCurrency` \[D3-A, §2.A.4\].

> (\*) *SCD2* = *Slowly Changing Dimension of Type 2* où *Type 2* signifie que chaque modification est versionnée.

<div style="page-break-after: always;"></div>

### D3.3. Les étoiles des processus métiers

Les diagrammes ci-dessous présentent les schémas en étoile de chaque processus métier. 

Chaque étoile a son propre diagramme : 
- *Transactions* (P1), 
- *Fraudes* (P2), 
- *Abonnements* (P3), 
- *Lectures et écritures des données* (P4), 
- *Demandes de droit* (P5), 
- *Incidents de Sécurité* (P6). 

> Rappel : chaque processus métier a son propre *grain*. Les étoiles ne partagent aucune ligne, seulement des dimensions conformées (`DimDate`, `DimMerchant`, `DimCustomer`, `DimGeography`...), voir la matrice de bus \[D3-A, §2.A.6\].

<div style="page-break-after: always;"></div>

#### D3.3.1. Revenus (P1/FactTransaction)

![[stripe-step-2--olap-design--diagram-p1.svg]]

Grain : `FactTransaction` (une transaction). 

Les propriétés `merchant_net_revenue_eur` et `stripe_revenue_eur` cohabitent sur la même ligne. Les deux audiences du reporting (marchands & Stripe) lisent la même table, seule la colonne agrégée change (voir note dans le modèle physique \[D3-B\]).

Montants : entiers en unités mineures (`amount_minor`, `fee_amount_minor`, `refund_amount_minor`) et valeurs en EUR (`decimal(18,4)`) converties au taux de référence (règles en D3.5.6). La commission `fee_amount_minor` est reprise de l'OLTP (`Transaction.fee_amount`) ; elle n'est **jamais recalculée** côté OLAP.

Géographie : `geography_key` (non nulle) désigne le pays où la transaction a été initiée et le type d'appareil. Le pays est résolu à l'ETL à partir de `Transaction.ip_geolocation` (adresse IP, GeoIP en version figée) ; l'adresse IP n'est jamais copiée dans l'OLAP (RGPD). Une IP absente ou non résolue donne le membre par défaut « unknown » (`country_code = 'ZZ'`).

<div style="page-break-after: always;"></div>

#### D3.3.2. Fraudes (P2/FactFraudEvent)

![[stripe-step-2--olap-design--diagram-p2.svg]]

Grain : un événement d'évaluation du risque de fraude (fait transactionnel). `is_confirmed_fraud` est la seule colonne mise à jour après l'insertion, quand la décision de fraude est confirmée \[D3-A\] (2.A.3) et \[D3-C\] (ETL-02).

`date_key` est la date UTC de l'évaluation (`FraudScore.evaluated_at`). `geography_key` est non nulle et résolue comme pour `FactTransaction` (D3.3.1) ; `exposed_amount_eur` est converti au taux de référence (D3.5.6).

<div style="page-break-after: always;"></div>

#### D3.3.3. Abonnements (P3/FactSubscriptionSnapshot)

![[stripe-step-2--olap-design--diagram-p3.svg]]

Grain : `FactSubscriptionSnapshot` (un instantané d'abonnement capturé périodiquement). 

`mrr_eur` et `stripe_mrr_eur` décrivent un état à un instant donné, et non un événement : ils sont semi-additifs (à ne pas sommer sur plusieurs dates pour un même abonnement). Ils sont convertis au taux de référence fixe (D3.5.6) : `exchange_rate_key` désigne le taux retenu, donc aussi la devise de l'abonnement (`from_currency_code`). `date_key` est la date UTC de l'instantané. `started_date_key` (début de l'abonnement) et `canceled_date_key` (demande de résiliation, vide s'il n'y en a pas) sont deux autres rôles de `DimDate` ; elles alimentent `new_subscriptions` et `churned_count` de `AggSubscriptionDailyMerchant`. Une résiliation demandée n'arrête pas l'abonnement avant la fin de la période déjà facturée : `churned_count` compte des demandes de résiliation, pas des abonnements terminés \[D3-C\] (2.C.2 et 2.C.3.6).

<div style="page-break-after: always;"></div>

#### D3.3.4. Lectures et écritures (P4/FactAuditEvent)

![[diagrams/stripe-step-2--olap-design--diagram-p4.svg]]

Grain : un événement d'audit, accès (`DataAccessLog`) **ou** modification (`ChangeAuditLog`). 

`geography_key` est non nulle. Pour les accès, le pays est résolu depuis `DataAccessLog.source_ip` ; pour les modifications (alimentées par CDC, sans IP dans l'OLTP), la ligne reçoit le membre « unknown ». `device_type` vaut toujours `unknown` pour ce fait : une analyse par pays ne couvre donc que les accès \[D3-A\] (2.A.4). `event_timestamp` est un `timestamptz` UTC.

<div style="page-break-after: always;"></div>

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
tables séparées, calculées.* 

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
Le format entier est nécessaire pour mettre en place un versionnement *SCD2* (un même `merchant_id` dans la base OLTP correspondra à plusieurs `merchant_key` dans la base OLAP, au fur et à mesure des modification de l'entité marchande).

#### D3.5.2. `DimDate` précalculées
Un pré-calcul des informations d'horodatage dans `DimDate` évite les fonctions de date dans les clauses `WHERE` (`EXTRACT`, `DATE_TRUNC`...). Les fonctions de date empêchent l'*élagage de partitions* dans la plupart des moteurs orientés colonnes. `DimDate` permet aussi de faire des comparaisons période sur période par simple jointure sur `date_key`.

**Fuseau horaire : tout est en UTC** \[D3-C\] (2.C.2). `date_key` (et chaque `*_date_key`) est la date UTC de l'événement ; les horodatages sont des `timestamptz` (jamais un `timestamp` sans fuseau) ; « aujourd'hui » s'écrit `(now() AT TIME ZONE 'UTC')::date` et non `CURRENT_DATE`, qui dépend du fuseau de la session. Il n'y a ni `DimTime` ni fuseau local par marchand : l'extension (`Merchant.timezone`, `local_date_key`) n'est pas retenue en l'absence de besoin exprimé.

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
justifiée \[D3-C\] (2.C.1), c'est aussi une optimisation : convertir au vol au taux du jour
demanderait une jointure sur une dimension à cardinalité temporelle fine ; le taux figé par
exercice réduit drastiquement le nombre de versions à joindre.

**Règle de conversion et types** \[D3-C\] (2.C.1) :
- montants locaux : `bigint` en unités mineures (`*_minor`), l'échelle étant portée par `DimCurrency.decimals` ;
- `amount_eur = amount_minor / 10^decimals × reference_rate`, où `reference_rate` (`decimal(24,12)`) est exprimé en EUR pour 1 unité majeure de la devise source ;
- montants en EUR : `decimal(18,4)`, calculés une seule fois à l'ETL en décimal exact, arrondis à la 4e décimale (demi-supérieur) ; l'arrondi à 2 décimales est réservé à l'affichage ;
- une seule conversion par composante (montant, commission, remboursement) ; les mesures dérivées sont calculées sur les valeurs déjà converties ;
- le taux retenu est celui de (devise source, exercice) pour la date de création UTC de la transaction (pour un instantané d'abonnement : la date de l'instantané) ;
- la commission est reprise de l'OLTP et n'est jamais recalculée.

#### D3.5.7. Sécurité RLS
**Sécurité au niveau des lignes (RLS), pas de filtrage applicatif.** Un marchand consultant
son reporting ne doit voir que ses propres lignes ; imposé par une politique
RLS au niveau du moteur, jamais laissé à la charge de la requête applicative, pour qu'aucun
bug côté client ne puisse exposer les données d'un autre marchand. 

La politique repose sur l'identifiant stable `merchant_id`, et non sur `merchant_key` : `DimMerchant` étant en *SCD2*, un marchand possède une `merchant_key` par version, et une politique `merchant_key = X` lui masquerait son historique. Elle s'applique ainsi :
- **faits et agrégats** (qui portent `merchant_key`) : `merchant_key` doit appartenir à l'ensemble des clés du marchand de la session (`merchant_key IN (SELECT merchant_key FROM DimMerchant WHERE merchant_id = <marchand de la session>)`) ;
- **dimensions propres à un marchand** (`DimMerchant`, `DimCustomer`, `DimProduct`, `DimPricingPlan`) : `merchant_id` égal à celui de la session. Les autres dimensions sont des référentiels partagés ;
- **lignes sans marchand** (`merchant_key` nul dans `FactAuditEvent` et `FactSecurityIncident`) : n'appartenant à aucun marchand, elles ne sont pas visibles par cette politique ; leur lecture par les rôles internes reste à définir \[D3-C\] (2.C.3.8, O-08).

#### D3.5.8. Index ciblés
**Index ciblés sur les clés de jointure et les colonnes de filtrage fréquent** - `date_key`
et `(merchant_key, date_key)` systématiques sur les faits, complétés par les clés métier
(`transaction_id`, `(subscription_id, date_key)`, `request_id`, `incident_id`...) pour le dédoublonnage à l'ETL et le rapprochement
avec l'OLTP, et par `merchant_id` sur `DimMerchant`, `DimCustomer`, `DimProduct` et `DimPricingPlan` (filtre RLS).

### D3.6. Règles de transformation (ETL)

Les valeurs que l'OLTP ne fournit pas telles quelles (segment client, regroupement des actions d'audit, remboursement et litige, fraude confirmée, MRR et compteurs d'abonnements, valeurs des événements d'écriture) sont définies par des règles numérotées `ETL-nn`, réunies dans \[D3-C\] (2.C.3) et citées dans les notes du modèle physique \[D3-B\]. Trois principes les gouvernent : la version de dimension SCD2 est celle en vigueur le jour UTC du fait ; seules quelques colonnes d'indicateurs sont mises à jour après l'insertion d'un fait (remboursement, litige, fraude confirmée) ; un rechargement redonne les mêmes lignes. Les seuils de segmentation et certains mappings sont des hypothèses de conception, signalées comme telles. Les politiques et règles non encore définies sont exposées en \[D3-C\] (2.C.3.8).

---

<div style="page-break-after: always;"></div>

### Couverture des exigences

| # | Fonctionnalité | A/ | C/ | Sources |
| --- | --- | --- | --- | --- |
| F01.08 | Paiements, remboursements, rétro-facturations | D2 | 🟢 | P1 §D3.3.1 ; `is_refunded` et `refund_amount_*` (ETL-20), `is_chargeback` (ETL-21) ; \[D3-A\] §2.A.2 traite remboursement et litige comme attributs de l'issue d'une transaction. |
| F01.09 | Gestion des abonnements | D2 | 🟢 | P3 `FactSubscriptionSnapshot` §D3.3.3 ; ETL-40 à ETL-44 ; `AggSubscriptionDailyMerchant` (ETL-50 à ETL-53). |
| F02.01 | Requêtes analytiques complexes et efficaces | **D3**, D8 | 🟢 | §D3.2, §D3.3 (six étoiles), §D3.5 (huit techniques d'optimisation). |
| F02.02 | Agrégation multidimensionnelle | **D3** | 🟢 | §D3.3 ; 17 dimensions conformées, matrice de bus \[D3-A\] §2.A.6 ; §D3.4. |
| F02.03 | Schémas en étoile ou en flocon | **D3** | 🟢 | §D3.2 (étoile pure, dimensions indépendantes), §D3.3 ; \[D3-B\]. |
| F02.04 | Tables pré-agrégées | **D3** | 🟢 | §D3.4 : sept tables d'agrégats, grain et usage définis ; \[D3-B\]. |
| F02.05 | Optimisation des requêtes analytiques | **D3** | 🟢 | §D3.5.1 à §D3.5.8 : clés entières, `DimDate`, partitionnement, stockage colonnes, diffusion des dimensions, taux fixe, index ciblés. |
| F02.06 | Faible latence pour les requêtes métier critiques | **D3** | 🟠 | §D3.4 (agrégats), §D3.5.3, §D3.5.8 ; aucune cible de latence, et les requêtes « critiques » ne sont pas définies. |
| F02.07 | Analyse de séries temporelles | (BR2) | 🟢 | `DimDate` précalculée §D3.5.2 (comparaison période sur période), partitionnement par `date_key` §D3.5.3, instantanés périodiques \[D3-A\] §2.A.3. |
| F02.08 | Jointures et sous-requêtes à grande échelle | (BR2) | 🟠 | §D3.5.5 (diffusion des dimensions), §D3.5.8 (index sur les clés de jointure) ; les sous-requêtes ne sont pas traitées. |
| F02.09 | Analyse historique | (BR2) | 🟢 | SCD2 sur `DimMerchant`, `DimCustomer`, `DimPricingPlan`, `DimActor` (\[D3-A\] §2.A.4) ; version retenue par ETL-01 ; instantanés cumulatifs §D3.3.5 et §D3.3.6. |
| F02.10 | Analyse ad hoc | (C2) | 🟠 | §D3.2 (étoile pure) et \[D3-A\] §2.A.6 (dimensions conformées) la rendent possible ; elle n'est nommée nulle part et aucun angle libre n'est documenté. |
| F02.11 | Analytique quasi temps réel | (BR2) | 🟠 | §D3.4 : `AggRevenueDailyMerchant` sert un tableau de bord « quasi temps réel » ; la fréquence de recalcul des agrégats reste à définir (O-10). |
| F02.12 | Restitution aux clients et aux parties prenantes internes | (C2) | 🟠 | §D3.3.1 : les deux audiences lisent la même table, `merchant_net_revenue_eur` et `stripe_revenue_eur` ; cloisonnement par RLS §D3.5.7 ; la lecture des lignes sans marchand par les rôles internes reste à définir (O-08). |
| F02.13 | Analyse des revenus | D8 | 🟢 | P1 §D3.3.1 ; `AggRevenueDailyMerchant` et `AggRevenueMonthlyMerchantCountry` §D3.4 ; P3 pour le revenu récurrent (`mrr_eur`, ETL-40). |
| F02.14 | Segmentation client | D8 | 🟠 | `DimCustomer.segment` (ETL-10, recalcul mensuel) ; seuils en hypothèse de conception (O-07) et aucun agrégat de segmentation. |
| F02.15 | Suivi de la performance des produits | (C2) | 🟠 | `DimProduct` ; P1 couvre *Product Performance* (§D3.1, \[D3-A\] §2.A.2) ; seul `AggSubscriptionDailyMerchant` a un grain par produit, aucun agrégat de performance produit. |
| F04.01 | Intégration entre OLTP, OLAP et NoSQL | D1, D5 | 🟠 | §D3.6 et \[D3-C\] §2.C.3 : règles de transformation OLTP → OLAP (ETL-01 à ETL-62) ; le système *NoSQL* n'est source d'aucune table. |
| F04.03 | Circulation cohérente des données | D5 | 🟠 | ETL-03 (rechargement idempotent), ETL-62 (contrôle d'appartenance), rapprochement \[D3-C\] §2.C.1.3/4 ; le flux lui-même relève de \[D5\]. |
| F04.04 | Traitement par lots | D5 | 🟠 | ETL-10 (évaluation mensuelle du segment), ETL-03 (rechargement par jour de `FactAuditEvent`), recalcul des jours concernés \[D3-C\] §2.C.3.6 ; aucune orchestration. |
| F04.05 | Flux de données en continu | D5 | 🟠 | `ChangeAuditLog` est dit alimenté par *CDC* (§D3.3.4, \[D3-A\] §2.A.4) ; aucun flux continu n'est décrit côté entrepôt. |
| F04.07 | Processus ETL/ELT | D5 | 🟢 | §D3.6 et \[D3-C\] §2.C.3 : 20 règles numérotées ETL-01 à ETL-62, citées dans les notes de \[D3-B\]. |
| F04.08 | Transformation et enrichissement des données | D5 | 🟢 | \[D3-C\] §2.C.3 : segment client (ETL-10), regroupement d'actions (ETL-11), mesures calculées (ETL-20 à ETL-53) ; conversion de devise §2.C.1. |
| F04.09 | Cohérence des données entre systèmes | D5 | 🟠 | Rapprochement `SUM(amount_minor)` avec l'OLTP (\[D3-C\] §2.C.1.3/4), commission jamais recalculée, ETL-62 ; l'OLTP reste la source de vérité. |
| F04.10 | Fraîcheur des données | D5 | 🟠 | §D3.4 (« quasi temps réel ») ; compteurs provisoires \[D3-C\] §2.C.3.6 ; fréquence de recalcul des agrégats à définir (O-10). |
| F04.12 | Résolution de conflits | D5 | 🟠 | Les écarts sont signalés comme anomalies de chargement et jamais corrigés (ETL-20, ETL-62) ; aucune règle de résolution. |
| F04.13 | *Change Data Capture* | D5 | 🟠 | Cité pour la seule alimentation de `ChangeAuditLog` (§D3.3.4, \[D3-A\] §2.A.4), sans mécanisme ni portée. |
| F04.15 | Vue globale et cohérente des données | (BR3) | 🟠 | Dimensions conformées et matrice de bus \[D3-A\] §2.A.6 : croiser revenu et incidents par marchand sans jointure artificielle ; vue limitée au périmètre analytique. |
| F04.16 | Accessibilité pour les différents cas d'usage | (C4) | 🟠 | Six étoiles par processus métier (§D3.3) et agrégats répondant à une question déjà posée (§D3.4) ; aucune couche d'exposition ni de service. |
| F05.01 | Montée en charge horizontale | (TR3) | 🟠 | §D3.5.4 (stockage orienté colonnes), §D3.5.5 (diffusion des dimensions, nœuds de calcul) ; moteur non tranché et aucun volume cible. |
| F05.03 | Bases de données distribuées | (TR3) | 🟠 | §D3.5.4 cite *Redshift*, *BigQuery*, *Snowflake* et *ClickHouse*, §D3.5.5 suppose plusieurs nœuds ; \[D3-B\] cible *PostgreSQL* et aucune topologie n'est décrite. |
| F05.05 | Partitionnement | (TR3) | 🟠 | §D3.5.3 : partitionnement par `date_key`, élagage de partitions, mensuel ou quotidien ; cité pour `FactTransaction` et `FactAuditEvent`, pas pour `FactFraudEvent`. |
| F05.07 | Indexation | D4 | 🟢 | §D3.5.8 (clés de jointure, clés métier, `merchant_id` pour la RLS) ; blocs `Indexes` de chaque table dans \[D3-B\]. |
| F06.03 | Contrôles d'accès (RBAC) | D6 | 🟠 | §D3.5.7 : RLS imposée par le moteur, assise sur `merchant_id` et non sur `merchant_key` ; les rôles internes et les lignes sans marchand restent à définir (O-08). |
| F06.04 | Journalisation d'audit | D6 | 🟠 | P4 `FactAuditEvent` §D3.3.4, `DimActor`, `DimAuditAction` (ETL-11), ETL-60 à ETL-62 ; il s'agit des journaux de l'OLTP, pas des accès à l'entrepôt lui-même. |
| F06.05 | Surveillance de l'utilisation des données | (C5) | 🟠 | P4 répond à « qui a fait quoi, quand, sur quoi » (\[D3-A\] §2.A.3) ; `AggComplianceDailyMerchant` compte accès, accès sensibles, tentatives non autorisées, acteurs et exports ; ses règles ETL restent à écrire (O-10). |
| F06.06 | Surveillance en temps réel des failles de sécurité | D6 | 🟠 | P6 `FactSecurityIncident` §D3.3.6 et `AggSecurityIncidentMonthly` : analyse a posteriori ; aucun alerting, et les règles ETL manquent (O-09). |
| F07.01 | Conformité réglementaire du stockage et du traitement | D6 | 🟠 | P4, P5 et P6 ; `DimRegulation.response_deadline_days`, `is_within_deadline`, `is_within_72h_deadline` ; ni durée de conservation ni effacement sur l'entrepôt. |
| F07.02 | RGPD | (TR5) | 🟠 | L'adresse IP n'est jamais copiée dans l'OLAP (§D3.3.1, \[D3-A\] §2.A.4) ; P5 modélise les demandes de droit ; ni rétention ni propagation de l'effacement. |
| F07.03 | PCI-DSS | (TR5) | 🟢 | `DimPaymentMethod` : type et réseau de la carte, jamais le PAN (\[D3-A\] §2.A.4). |
| F07.04 | CCPA | (C5) | 🟠 | `DimRegulation` et P5 couvrent RGPD et CCPA (§D3.1, \[D3-A\] §2.A.2) ; `AggDataSubjectRequestMonthly` sert le rapport RGPD/CCPA ; aucune règle propre au CCPA. |
| F07.06 | Contrôles de conformité automatisés | D6 | 🟠 | Indicateurs `is_within_deadline` et `is_within_72h_deadline` (\[D3-A\] §2.A.5) ; leurs règles de calcul ne sont pas écrites (O-09). |
| F07.07 | Reporting de conformité | D6 | 🟠 | `AggComplianceDailyMerchant`, `AggDataSubjectRequestMonthly`, `AggSecurityIncidentMonthly` §D3.4 ; leurs règles ETL ne sont pas écrites (O-10). |
| F08.01 | Modèles de détection de fraude en temps réel | D4, D7, D8 | 🟠 | P2 `FactFraudEvent` §D3.3.2, `DimFraudRiskLevel`, `anomaly_score` (ETL-22, ETL-30), `is_confirmed_fraud` (ETL-32), `AggFraudDailyMerchant` : analyse a posteriori des scores, le scoring est hors de \[D3\]. |
| F09.01 | Conception des modèles de données par système | D1, D2, **D3**, D4 | 🟢 | \[D3\] pour le schéma, \[D3-A\] pour l'analyse de *Kimball*, \[D3-B\] pour le modèle physique (30 tables), \[D3-C\] pour les conventions et les règles de transformation. |

> _Légende : « A/ » : les livrables qui couvrent la fonctionnalité dans D0, ou, à défaut, l'exigence technique, l'exigence d'affaire ou l'enjeu source ; « C/ » :  niveau de couverture par D3 ; 🟢 : fonctionnalité traitée ; 🟠 : fonctionnalité traitée partiellement (réserve est indiquée dans la colonne Sources)._

---

<div style="page-break-after: always;"></div>

### Références

#### Spécifications
- \[D0\] [Stripe Project Introduction](stripe-project--d0-introduction.pdf)
- 
#### Annexes
- \[D3-A\] [OLAP Kimball Analysis](stripe-project--d3-olap-annexe-a--kimball-analysis.pdf)
- \[D3-B\] [OLAP Physical Data Model](stripe-project--d3-olap-annexe-b--dbml.pdf)
- \[D3-C\] [OLAP Conventions and Transformation Rules](stripe-project--d3-olap-annexe-c--conventions-and-transformation-rules.pdf)

