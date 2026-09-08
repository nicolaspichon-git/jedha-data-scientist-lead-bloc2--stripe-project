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

#### Changelog v07 → v08

> **Note de version (v08)** - Restructuration du document : renommage du chapitre en _"Global Data Architecture"_ ; les trois principes structurants de D1.1 condensés en liste numérotée ; extraction du diagramme Mermaid hors du document principal vers un fichier dédié, intégré désormais par image plutôt qu'en bloc de code inline ; le paragraphe sur le choix du moteur MongoDB (v03) et celui sur le rôle de rapprochement transverse du NoSQL (v07) sont barrés, en instance de révision ; D1.4 renommée _"Sujets non couverts"_. **Régression introduite au passage** (non intentionnelle) : deux lignes du tableau D1.3 ajoutées en v07 (flux `Topic CDC → merchant_config` et `Topic CDC → ml_features`) ont disparu pendant la restructuration, alors que les arêtes correspondantes restent bien présentes dans le diagramme extrait - détecté et corrigé en v09.

#### Changelog v08 → v09

> **Note de version (v09)** - Correction de la régression identifiée en v08 : réintégration des deux lignes manquantes du tableau D1.3 (`Topic CDC → merchant_config`, `Topic CDC → ml_features`), pour que le tableau documente à nouveau l'intégralité des arêtes visibles dans le diagramme. Détecté en vérifiant la compatibilité du diagramme avec le livrable D4 v08 (NoSQL).

#### Changelog v09 → v10

> **Note de version (v10)** - Correction d'une référence erronée introduite en v09 : la ligne `Topic CDC → merchant_config` citait _"Annexe 3.C, §D4.8"_ - une annexe qui n'existe pas (l'annexe NoSQL réelle est 3.A, et de toute façon §D4.8 vit dans le document D4 lui-même, pas dans une annexe). Corrigé en `[D4], §D4.8`.

#### Changelog v10 → v11

> **Note de version (v11)** - Harmonisation des noms de topics avec D5/D7 (pris comme
> référence, sens inverse de la v10 → v11 précédente) : `cdc.transaction` → `txn.events`,
> `clickstream` → `user.sessions`, `fraud.signal` → `fraud.scores`, dans le diagramme
> (§D1.2). `audit.access` restait déjà identique. `cdc.subscription`/`cdc.compliance`/
> `app.logs`/`feedback.submitted` non concernés, aucun équivalent nommé côté D5/D7 à ce jour.

#### Changelog v11 → v12

> **Note de version (v12)** - Retour sur `txn.events` (v11) : incohérence relevée avec les
> deux autres topics CDC du même diagramme (`cdc.subscription`, `cdc.compliance`), qui
> suivent une convention de préfixe différente. Restauration de `cdc.transaction` (§D1.2)
> pour que les trois topics CDC partagent la même convention de nommage.

#### Changelog v12 → v13

> **Note de version (v13)** - Ajout de deux arêtes de lecture synchrone au diagramme (§D1.2) :
> `merchant_config → FRAUD_SVC` (seuils de risque par marchand, \\[D4\\] §D4.5.5) et
> `customer_feedback → MERCH_ANALYTICS` (tableau de bord marchand) - ces deux collections
> n'avaient jusqu'ici aucune arête sortante, malgré un usage documenté dans D4. Ajout d'une
> précision de périmètre en §D1.4 : le diagramme représente les flux de pipeline, pas
> l'exhaustivité des accès applicatifs en lecture synchrone.

#### Changelog v13 → v14

> **Note de version (v14)** - Correction d'une divergence entre D1 et D5 sur le mécanisme de
> scoring de fraude (§D1.2, §D1.3) : l'arête unique "écriture synchrone des scores" fusionnait
> à tort deux flux distincts que \[D5\] §D5.5.4 décrit séparément - la décision temps réel
> (autorise/bloque, hors Kafka, < 100 ms) et la persistance asynchrone via le topic
> `fraud.scores` (qui alimente à la fois `FraudScore` en OLTP et `FactFraudEvent` en OLAP, par
> le même pipeline batch Airflow que le reste - jamais un accès direct au topic). Le topic
> `fraud.scores` sort de la liste de `TOPIC_APP` pour devenir un topic dédié, cohérent avec la
> nomenclature déjà établie. Correction au passage d'un pointillé résiduel sur
> `merchant_config → FRAUD_SVC` (devrait être synchrone, trait plein, depuis la précédente
> correction jamais appliquée au diagramme).

#### Changelog v14 → v15

> **Note de version (v15)** - Deux manques comblés côté consommateurs OLAP (§D1.2, §D1.3).
> Renommage de `BI` en `C_ANALYTICS_TEAM` - "BI" nommait un type d'outil, pas un public,
> rupture de convention avec `MERCH_ANALYTICS`/`COMPLIANCE` qui nomment tous deux un public.
> Ajout de `C_RISK_TEAM`, absent jusqu'ici : ni `C_ANALYTICS_TEAM` (revenu/produit) ni
> `MERCH_ANALYTICS` (externe) ni `COMPLIANCE` (RGPD/PCI-DSS) ne couvrait le reporting de
> fraude, alors que `FactFraudEvent` et `AggFraudDailyMerchant` (\[D3\] §D3.4, "alerting
> fraude") existaient déjà sans consommateur. Ajout d'une boîte `Vues` dans `OLAP_SYS` pour
> `AggFraudDailyMerchant`, alimentée par `ETL` comme le reste, connectée à `C_RISK_TEAM`.

#### Changelog v15 → v16

> **Note de version (v16)** - Renommage de `COMPLIANCE` en `C_SECREG_TEAM` et de
> `MERCH_ANALYTICS` en `C_MERCHANT` (§D1.2, §D1.3), pour aligner les quatre consommateurs sur
> une convention de nommage unique (`C_` + public visé), amorcée à la v15 avec
> `C_ANALYTICS_TEAM`/`C_RISK_TEAM`.

#### Changelog v16 → v17

> **Note de version (v17)** - Séparation d'orchestration et de transformation (§D1.2, §D1.3),
> jusqu'ici fusionnées dans un seul nœud `ETL`. `AIRFLOW` (dans `ORCH`) ne porte plus que la
> planification et les dépendances ; `OLAP_DBT`, nouvelle boîte dans `OLAP_SYS`, reçoit les
> flux de données et produit `OLAP_FACTS`/`OLAP_DIM`/`OLAP_VIEWS` - cohérent avec \[D5\]
> §D5.11 : dbt s'exécute directement dans l'entrepôt, pas sur un cluster de calcul séparé.
> `AIRFLOW -.-> OLAP_DBT` ne porte aucune donnée, seulement le déclenchement.


#### Changelog v17 → v18

> **Note de version (v18)** - Scission d'`OLTP_COMP` en deux boîtes (§D1.2) : `OLTP_SEC`
> (`ChangeAuditLog`, `SecurityIncident`) et `OLTP_COMPLY` (`ConsentRecord`,
> `DataSubjectRequest`) - le critère retenu distingue les tables réactives (on trace/répond à
> un événement) des tables procédurales (une personne exerce un droit). `DataAccessLog`
> reste séparée (`OLTP_ACCESS`, lecture), inchangée. Les deux nouvelles boîtes CDC vers le
> même topic et reportent au même consommateur (`C_SECREG_TEAM`) - le split n'a pas été
> propagé côté consommateur, non demandé. Répercuté dans le DBML OLTP (Annexe 1.B, v26) :
> nouveau groupement de couleurs (`#922B21` Sécurité, `#B7950B` Conformité), les tables
> d'infrastructure d'audit partagées (`AuditActorType`, `AuditAction`, `DataAccessLog`)
> restent en `#8E44AD`.

#### Changelog v18 → v19

> **Note de version (v19)** - Extraction de `audit.access` en topic dédié (`TOPIC_AUDIT`,
> §D1.2), séparé de `TOPIC_APP`. Deux raisons distinctes de le sortir du groupe applicatif
> générique : sa source n'est pas un acteur (`OLTP_CORE` seul le publie, contrairement à
> `user.sessions` qui vient directement de `CUST_APP`), et il fait déjà l'objet d'un
> traitement à part (le consommateur asynchrone dédié qui écrit `DataAccessLog`, ainsi que le
> second usage Flink de \[D5\] §D5.8.5, propre à ce seul topic). Reste dans la même famille de
> mécanisme que `TOPIC_APP` (publication applicative asynchrone, pas CDC) - seul le
> regroupement visuel change, pas le mécanisme de production.

#### Changelog v19 → v20

> **Note de version (v20)** - Ajout d'une étape d'extraction explicite (`EXTRACT`, dans
> `ORCH`, §D1.2), manquante entre les collections NoSQL et `OLAP_DBT`. dbt est un outil de
> transformation SQL qui s'exécute dans l'entrepôt - il ne peut pas se connecter à MongoDB
> pour en extraire des documents ; l'arête directe `NOSQL_SESSIONS/NOSQL_FEATURES -.-> OLAP_DBT`
> fusionnait à tort extraction et transformation, deux responsabilités désormais distinguées
> comme orchestration et transformation l'ont été précédemment. `EXTRACT` est orchestré par
> Airflow au même titre que `OLAP_DBT`.

#### Changelog v20 → v21

> **Note de version (v21)** - Style dédié pour `ORCH` (§D1.2), jusqu'ici sans style propre
> (rendu par défaut de Mermaid) - `fill:#D6DBDF, stroke:#2C3E50`, cohérent avec l'icône "⚫"
> déjà utilisée pour ce sous-graphe. `ACTEURS` passe de blanc (`#FFFFFF`) à un jaune pâle
> (`fill:#FEF9E7, stroke:#D4AC0D`), distinct des six autres couleurs déjà utilisées.

#### Changelog v21 → v22

> **Note de version (v22)** - Correction des trois arêtes `TOPIC_APP → NOSQL_LOGS/
> NOSQL_SESSIONS/NOSQL_FEEDBACK` (§D1.2), jusqu'ici en trait plein (synchrone) sans
> justification - aucune des trois collections n'a d'exigence de latence bloquante, et
> \[D5\] §D5.4.2 classe `TOPIC_APP` parmi les topics à ingestion continue, par nature
> asynchrone. Passées en pointillé, avec le mécanisme nommé ("consommateur asynchrone,
> ingestion continue"), cohérent avec le traitement déjà appliqué à `audit.access` et
> `fraud.scores`.

#### Changelog v22 → v23

> **Note de version (v23)** - Suppression du chemin d'extraction batch directe
> `OLTP_SEC`/`OLTP_COMPLY`/`OLTP_ACCESS` → `C_SECREG_TEAM` (§D1.2), qui présentait deux
> défauts : trait plein (synchrone) injustifié pour un mécanisme batch, et redondant avec le
> pipeline OLAP déjà conçu spécifiquement pour ce reporting (\[D3\] §D3.4, \[D6\] §D6.8).
> `C_SECREG_TEAM` reçoit désormais ses données via `OLAP_FACTS` (`FactAuditEvent`,
> `FactDataSubjectRequest`, `FactSecurityIncident`) et `OLAP_VIEWS`, qui accueille les trois
> agrégats de conformité jusqu'ici absents du diagramme (`AggComplianceDailyMerchant`,
> `AggDataSubjectRequestMonthly`, `AggSecurityIncidentMonthly`). Le besoin temps réel reste
> couvert séparément par Flink sur `audit.access` (\[D5\] §D5.8.5), non affecté par ce
> changement.

#### Changelog v23 → v24

> **Note de version (v24)** - Retour sur la v23 : le chemin direct OLTP → reporting
> conformité n'était pas une erreur mais une décision d'indépendance délibérée
> (\[D1\] §D1.3 original : *"sans exposer l'OLTP directement aux outils de reporting"*),
> écartée à tort en v23 par un critère de redondance qui ne pesait qu'un côté de la balance.
> Restauré via un nouveau sous-graphe `COMPLIANCE_PIPE`, avec un job d'extraction dédié
> (`COMPLIANCE_EXTRACT`) délibérément **hors Airflow** - une orchestration partagée
> annulerait l'argument d'indépendance en cas de panne du pipeline commun. Les deux chemins
> coexistent désormais : direct (rapports à échéance légale, traçabilité à la source) et OLAP
> (analyse transverse, tendances). Toutes les arêtes de ce nouveau chemin sont en pointillé
> (asynchrone) - une extraction planifiée n'est jamais un mécanisme bloquant, même en gardant
> le chemin direct.

#### Changelog v24 → v25

> **Note de version (v25)** - Scission de `C_SECREG_TEAM` en deux consommateurs distincts
> (§D1.2), sur le même principe déjà appliqué à `C_RISK_TEAM` pour la fraude. `C_SECREG_TEAM`
> ne reçoit plus que le chemin direct (`COMPLIANCE_EXTRACT`) - rapports réglementaires à
> échéance légale, traçables à la source. Nouveau `C_SECCOMPLY_ANALYTICS` reçoit le chemin
> OLAP (`OLAP_FACTS`/`OLAP_VIEWS`) - analyse transverse, tendances, fonction GRC
> (*Governance, Risk, Compliance*), distincte du rôle réglementaire à proprement parler.

#### Changelog v26 → v28

> **Note de version (v28)** - Alignement sur diagrammes. Cinq corrections pour aligner D1.3/D1.4 sur les diagrammes `diagram-1*` (v28) : numérotation dupliquée en D1.2 (deux vues portaient "D1.2.2"), renommage des consommateurs obsolètes dans D1.3 (`C_ANALYTICS_TEAM`→`C_BUSINESS_TEAM`, `C_SECREG_TEAM`→`C_COMPLIANCE_TEAM`, `C_MERCHANT`→`C_MERCHANTS`) et ajout de `C_SECURITY_TEAM`, manquant ; ajout de la ligne `merchant_config → FRAUD_SVC`, absente du tableau ; clarification du mécanisme d'extraction conformité (indépendant d'Airflow, pas un simple "batch") ; ajout des références `[D5]`, `[D5-A]`, `[D7]`, citées en corps de texte mais absentes de la liste finale.

####


---
