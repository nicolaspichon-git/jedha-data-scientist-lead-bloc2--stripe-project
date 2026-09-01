*STRIPE* PROJECT
===

# 8. Global Data Architecture
## D1. Data Architecture Diagram 

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D2 : Data Architecture Diagram - Changelogs / v08 - 2026/10/13.*

---
### Changelogs

#### Changelog v01 > v02

> **Note de version (v02)** - Deux mises à jour. (1) Bloc OLAP actualisé suite à la
> conception Kimball (2.A) et au DBML v07 (Annexe 2.B) : ajout de `FactSecurityIncident`
> (absent du v06) et renommage de `FactComplianceRequest` en `FactDataSubjectRequest`. (2)
> Scission du bloc conformité OLTP : `DataAccessLog` reste seule sur le bus applicatif
> (justification originale de l'Annexe 1.C, propre à cette table) ; `ChangeAuditLog`,
> `ConsentRecord`, `DataSubjectRequest` et `SecurityIncident` rejoignent désormais le flux CDC
> comme `OLTP_CORE`, puisque ce sont des tables normalement écrites par l'application, sans la
> contrainte spécifique du `SELECT` sans trace WAL qui justifiait le bus applicatif.

#### Changelog v02 > v03

> **Note de version (v03)** - Choix du moteur NoSQL tranché : MongoDB (orienté document),
> plutôt que l'alternative "MongoDB / DynamoDB" non départagée jusqu'ici. Justification :
> TR1 exige explicitement le requêtage de données imbriquées/non structurées, ce qu'un moteur
> clé-valeur (DynamoDB en mode natif) ne permet pas aussi nativement qu'un vrai document
> store. Voir D1.1 pour le détail, D1.4 mis à jour en conséquence.

#### Changelog v03 > v04

> **Note de version (v04)** - Correction d'une incohérence relevée en review : `OLTP_ACCESS`
> (`DataAccessLog`) rejoint désormais le flux CDC (`TOPIC_CDC`) comme le reste de la
> conformité, au lieu du bus applicatif (`TOPIC_APP`). La contrainte originale de l'Annexe
> 1.C (*"un `SELECT` ne laisse aucune trace dans le WAL"*) ne concerne que la **création** de
> la ligne dans `DataAccessLog` (`OLTP_CORE → OLTP_ACCESS`, écriture applicative directe) -
> une fois cette ligne insérée, elle devient une table Postgres normale, répliquable par CDC
> comme toute autre. `TOPIC_APP` reste dédié au seul clickstream client direct.

#### Changelog v04 > v05

> **Note de version (v05)** - Correction d'une erreur introduite en v04 : en redirigeant
> `OLTP_ACCESS` vers `TOPIC_CDC` (propagation vers l'aval, correction légitime), la flèche de
> **création** de `DataAccessLog` avait été supprimée par erreur au passage, laissant croire à
> une écriture directe et synchrone (`OLTP_CORE --> OLTP_ACCESS`). Or la création reste,
> comme discuté à l'origine, un mécanisme en deux temps : publication d'un événement
> asynchrone (`OLTP_CORE -.-> TOPIC_APP`), puis un consommateur asynchrone écrit la ligne dans
> `DataAccessLog` avec son contexte métier (`justification`). Propagation (`TOPIC_CDC`) et
> création (`TOPIC_APP`) sont deux mécanismes distincts, chacun sur son propre topic - la v04
> avait fusionné les deux par erreur.

#### Changelog v05 > v06

> **Note de version (v06)** - Corrections diverses dans le diagramme.
> 

#### Changelog v06 > v07

> **Note de version (v07)** - Actualisation du bloc NoSQL suite à la finalisation de D4
> (Annexe 3.C) : les deux boîtes génériques (`Logs bruts...`, `Features ML...`) sont
> remplacées par les cinq collections réellement conçues (`event_logs`, `user_sessions`,
> `ml_features`, `customer_feedback`, `merchant_config`). Deux flux absents jusqu'ici sont
> ajoutés, tous deux explicitement décrits en D4.9 : l'alimentation CDC de `merchant_config`
> (cache dénormalisé mis à jour à chaque changement `Merchant`/`Customer`/`Transaction`), et
> le déclenchement CDC du recalcul de `ml_features`. Le flux vers l'OLAP (Airflow) est
> resserré sur ses deux sources réelles (`user_sessions`, `ml_features`) - `event_logs`,
> `customer_feedback` et `merchant_config` n'alimentent aujourd'hui aucun fait OLAP.
> Ajout d'une mention du rôle de rapprochement transverse du NoSQL (D1.1), capacité décrite
> en D4.9 mais absente de D1 jusqu'ici.

---
