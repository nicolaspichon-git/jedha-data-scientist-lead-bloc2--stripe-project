---
version: v33
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-8
  - stripe-project/deliverables
  - stripe-project/deliverables/D1
  - stripe-project/data-architecture
  - stripe-project/data-architecture/diagrams
---


*STRIPE* PROJECT
===

# 8. Global Data Architecture
## D1. Data Architecture Diagrams 

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D1 : Data Architecture Diagrams / v33 - 2026/11/05.*
---

### D1.1. Introduction

#### D1.1.1. Contexte

Ce document présente l'architecture de données du projet *Stripe* \[D0\]. Il décrit l'intégration des systèmes *OLTP* \[D2\], *OLAP* \[D3\] et *NoSQL* \[D4\], et détaille les flux de données et les pipelines qui lient ces systèmes.

L'architecture est structurée par les principes suivants :

1. *Le chemin transactionnel ne doit jamais être ralenti* par des processus de sécurité, de conformité, d'analytique ou de détection de fraude. Les flux de données qui partent du système transactionnel vers les autres systèmes de données sont donc *asynchrones*.

2. *La réplication des changements d'état transactionnels ne doit pas être synchrone*. On évite les déclencheurs synchrones (*triggers*) et on privilégie l'exploitation asynchrone du flux *CDC* (*Change Data Capture*) natif du système *OLTP*.

3. *Le taux de change est fixe* dans la base analytique. Il est actualisable périodiquement (annuellement par exemple).
 
<div style="page-break-after: always;"></div>

### D1.2. Vue d'ensemble

![[diagrams/stripe-project--d1-data-architecture--diagram-1-1--overview.svg]]

<div style="page-break-after: always;"></div>

### D1.3. Vue du coeur métier

#### D1.3.1. Architecture

![[diagrams/stripe-project--d1-data-architecture--diagram-1-2--core.svg]]

<div style="page-break-after: always;"></div>

#### D1.3.2. Modèle de données transactionnelles

![[diagrams/stripe-project--d1-data-architecture--diagram-4-1--transactional-model-1.svg]]

<div style="page-break-after: always;"></div>

#### D1.3.3. Modèle de données analytiques

![[diagrams/stripe-project--d1-data-architecture--diagram-5-1--analytics-model-1.svg|600]]

<div style="page-break-after: always;"></div>

#### D1.3.4. Modèle de données non-structurées

![[diagrams/stripe-project--d1-data-architecture--diagram-6-1--nosql-model-1.svg|600]]
![[diagrams/stripe-project--d1-data-architecture--diagram-6-2--nosql-model-2.svg]]
![[diagrams/stripe-project--d1-data-architecture--diagram-6-4--nosql-model-4.svg]]

<div style="page-break-after: always;"></div>

#### D1.3.5. Flux de données

| #   | Flux                                  | Mécanisme                   | Justification                                                                                                                                                   |
| --- | ------------------------------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | 
| 1   | Acteurs → Apps                        | écr. sync. directe          | Flux d'entrée des données dans  le système ; passe par une couche applicative interne qui isole le système les acteurs externes sont : client/marchand/interne. |
| 2   | Apps → Core OLTP                      | écr. sync. directe          | Logique de traitement (validation, orchestration du paiement) séparée de la logique de persistance. |
| 3   | Core OLTP → Topic `cdc`               | lect.&nbsp;async.&nbsp;cont.<br/>du *WAL* | Journalisation des modifications des tables Core (`Transaction`, etc.) => *banir les déclencheur synchrone (triggers*) => lecture *asynchrone* du journal système (WAL : Write-Ahead-Log) + publication des modifications dans les topics `cdc`. |
| 4   | Topic `app` → NoSQL                   | ingest.&nbsp;async.&nbsp;cont.  | Transport des logs d'application, clickstreams, interactions avec l'utilisateur, vers NoSQL.  |
| 5   | Topic&nbsp;`cdc`&nbsp;→&nbsp;staging&nbsp;OLAP | extract.&nbsp;async.&nbsp;cont. | Chargement temporaire des modifications des tables Core (via les les topics `cdc`) dans l'entrepôt OLAP  |
| 5   | NoSQL&nbsp;*Change Streams*&nbsp;→&nbsp;staging&nbsp;OLAP | extract.&nbsp;async.&nbsp;cont. | Chargement temporaire des modifications de la collection NoSQL `user_sessions` dans l'entrepôt OLAP   |
| 6   | dbt + staging → OLAP Core             | transf. plan.| L'orchestrateur déclenche les processus de transformation (ici, portés par *dbt*), les processus transforment et chargent directement dans l'entrepôt OLAP ; |
| 7   | OLAP Core → analytiques               | req.&nbsp;analytiques | 1 consommateur externe : marchand, 1 consommateur interne : analyste revenus & produits            |
| 7   | NoSQL&nbsp;`customer_feedback`&nbsp;→&nbsp;marchand | req.&nbsp;analytiques | 1 consommateur externe : marchand                                                    |
| 7   | NoSQL&nbsp;`event_logs`&nbsp;→&nbsp;admins          | req.&nbsp;analytiques | 1 consommateur interne : administrateur fonctionnel                                  |

> *abréviations :*
> - écr. = écriture
> - lect. = lecture 
> - cont. = continue 
> - sync. = synchrone 
> - async. = asynchrone 
> - ingest. = ingestion
> - compil. = compilation
> - extract. = extraction
> - transf. = transformation
> - plan. = planifié
> - req. = requêtes

<div style="page-break-after: always;"></div>

### D1.4. Vue du scoring de fraude

#### D1.4.1. Architecture

![[stripe-project--d1-data-architecture--diagram-1-3--scoring.svg]]

<div style="page-break-after: always;"></div>

###### Diagramme de séquence du scoring de fraude au cours d'une transaction 

![[diagrams/stripe-project--d1-data-architecture--diagram-2--scoring-sequence.svg]]

<div style="page-break-after: always;"></div>

#### D1.4.2. Modèle de données transactionnelles

![[diagrams/stripe-project--d1-data-architecture--diagram-4-2--transactional-model-2.svg]]

<div style="page-break-after: always;"></div>

#### D1.4.3. Modèle de données analytiques

![[diagrams/stripe-project--d1-data-architecture--diagram-5-2--analytics-model-2.svg]]

<div style="page-break-after: always;"></div>

#### D1.3.4. Modèle de données non-structurées

![[diagrams/stripe-project--d1-data-architecture--diagram-6-3--nosql-model-3.svg]]
![[diagrams/stripe-project--d1-data-architecture--diagram-6-5--nosql-model-5.svg]]

#### D1.4.5. Flux de données

| # | Flux                         | Mécanisme     | Justification  |
| - | ---------------------------- | ------------- | -------------- |
| 4 | Topic&nbsp;`cdc`&nbsp;→&nbsp;NoSQL&nbsp;`merchants`  | act.&nbsp;async.&nbsp;cont.<br/>du&nbsp;cache&nbsp;marchands | Cache dénormalisé actualisé à chaque changement de OLTP Core ; évite d'interroger OLTP à chaque événement app |
| 4 | Topic&nbsp;`cdc`&nbsp;→&nbsp;NoSQL&nbsp;`features`   | act.&nbsp;async.&nbsp;cont.<br/>des&nbsp;features | Le recalcul des features suit le même flux CDC que "NoSQL merchants" ; pas de mécanisme distinct  |
| 8 | NoSQL `features` → scoring  | lect. sync.<br/>&lt; 10 ms | Alimente le modèle de fraude en continu |
| 8 | NoSQL `merchants` → scoring | lect. sync. | Seuils de risque par marchand, consultés en même temps que les features   |
| 8R| scoring → Apps | rép. sync.  | Autorise/bloque/suspend la transaction ; latence bout en bout < 100 ms ; la décision revient à la couche applicative ; la persistance du score est un flux séparé  |
| 3 | scoring → Topic `fraud`  | pub. async. | Seul flux qui revient vers OLTP par un mécanisme asynchrone (\[D5\] §D5.5.4), distinct de la décision de fraude elle-même  |
| 2B| Topic&nbsp;`fraud`&nbsp;→&nbsp;OLTP&nbsp;`FraudScore` | ... | Enregistre le score dans OLTP ; planifié/compilé/orchestré ? |
| 5 | Topic&nbsp;`fraud`&nbsp;→&nbsp;staging&nbsp;OLAP | extract. async. cont. | cf. §D1.3.5. |
| 5 | NoSQL → staging OLAP  | transf. plan. | cf. §D1.3.5. |
| 6 | `dbt` + staging → OLAP  | transf. planifiée   | Alimente `FactFraudEvent` via `dbt` |
| 7 | OLAP → analytiques | req. analytiques  | Découplé du chemin transactionnel, pas d'impact sur latence de paiement, quatre consommateurs analytiques distincts, tous alimentés par OLAP (\[D1\] §D1.2) : 1 externe: marchand, 3 internes: revenu & produit, risque & fraude, sécurité & conformité |

> *abréviations :*
> - act. = actualisation
> - pub. = publication
> - lect. = lecture 
> - écr. = écriture 
> - cont. = continue 
> - sync. = synchrone 
> - async. = asynchrone 
> - transf. = transformation 
> - req. = requêtes
> - rép. = réponse

<div style="page-break-after: always;"></div>

### D1.5. Vue du reporting de sécurité et de conformité

#### D1.5.1. Architecture

![[diagrams/stripe-project--d1-data-architecture--diagram-1-4--security-and-compliance.svg]]

<div style="page-break-after: always;"></div>

#### D1.5.2. Modèle de données transactionnelles

![[diagrams/stripe-project--d1-data-architecture--diagram-4-3--transactional-model-3.svg]]

<div style="page-break-after: always;"></div>

#### D1.5.3. Modèle de données analytiques

![[diagrams/stripe-project--d1-data-architecture--diagram-5-3--analytics-model-3.svg]]

<div style="page-break-after: always;"></div>

#### D1.5.5. Flux de données

| #   | Flux                 | Mécanisme      | Justification  |
| --- | -------------------- | -------------- | -------------- |
| 3   | Apps → Topic `audit` | pub. async. d'événement justifé | `SELECT` ne laisse pas de trace dans *WAL* ; l'application connaît le contexte de l'accès  |
| 2B  | Topic&nbsp;`audit`&nbsp;→&nbsp;OLTP&nbsp;`DataAccessLog` | ingest. async. cont.   | Mappage direct : la justification de l'accès voyage dans le message publié par Apps |
| 3   | OLTP&nbsp;`DataAccessLog`&nbsp;→&nbsp;Topic&nbsp;`cdc` | lect.&nbsp;async.&nbsp;cont.<br/>du *WAL* | Réplication standard |
|     | OLTP Sécurité → Topic `cdc` | | |
|     | OLTP Conformité → Topic `cdc` | | |
| 2B  | Topic `cdc` → OLTP `ChangeAuditLog` | ingest. async. cont. | Dérive une ligne d'audit depuis l'événement CDC ; *`ChangeAuditLog` ne doit pas être recapturée par CDC* |
| 2B  | Topic&nbsp;`audit`&nbsp;→&nbsp;OLTP&nbsp;`SecurityIncident` | détect. async. cont. | Détection à état (fenêtres glissantes) |
| 3i  | Topic `cdc` → Topic `security` | relais async. cont. | Réutilise le fait constaté (l'écriture de `SecurityIncident`) plutôt que de redétecter une seconde fois depuis `audit.access` |
| 6+7 | Topic `security` →  équipe sécurité | ... | Le mécanisme de notification (canal d'astreinte) reste indépendant du mécanisme de détection  |
| 2   | Apps → OLTP `DataSubjectRequest`  | écr. sync. directe | Le client exerce un droit ou donne/retire son consentement via une application  |
|     | Apps → OLTP `ConsentRecord` | '' | ''  |
| 5   | Topic `cdc` → staging OLAP | extract. async. cont.  | cf. §D1.3.5. |
| 6   | `dbt` + staging → OLAP | transf. plan. | cf. §D1.3.5. |
| 7   | OLAP → analytiques | req. analytiques | Découplé du chemin transactionnel, pas d'impact sur latence de paiement, consommateur analyste sécurité & conformité |
| 6+7 | OLTP → reporting conformité | extract. plan. indé. | Alimente les rapports RGPD/PCI-DSS sans exposer l'OLTP directement aux outils de reporting ; job d'extraction dédié non intégré au pipeline partagé (robustesse aux pannes du sytème) |

> *abréviations :*
> - lect. = lecture 
> - écr. = écriture 
> - cont. = continue 
> - sync. = synchrone 
> - async. = asynchrone 
> - pub. = publication
> - ingest. = ingestion 
> - détect. = détection 
> - transf. = transformation 
> - mess. = message
> - req. = requêtes
> - extract. = extraction 
> - plan. = planifié 
> - indé. = indépendante

---

<div style="page-break-after: always;"></div>

### D1.x. Technologies (D5)

| #     | Rôle                                                                | Technologies                                                            | Remarques                                               |     |
| ----- | ------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------- | --- |
|       | OLTP                                                                | *PostgreSQL*                                                            |                                                         |     |
|       | OLAP                                                                | *Snowflake*                                                             |                                                         |     |
|       | NoSQL                                                               | *MongoDB*                                                               | orienté documents                                       |     |
|       | bus d'évènement                                                     | *Kafka*                                                                 | topic streams                                           |     |
|       | CDC (OLTP)                                                          | Write-Ahead-Log (WAL) *PostgreSQL*                                      | CDC = Change Data Capture                               |     |
|       | CS (NoSQL)                                                          | CS *MongoDB*                                                            | CS = Change Streams                                     |     |
|       | Orchestrateur                                                       | *Airflow* | | 
| 3️⃣   | OLTP CDC > topics `cdc`                                             | connecteur source *Kafka Connect/Debezium*                              | ingestion asynchrone continue                           |     |
| 4️⃣   | topics `app` > NoSQL                                                | connecteur sink *Kafka Connect/MongoDB*                                 | ingestion asynchrone continue                           |     |
| 5️⃣   | CS NoSQL > staging OLAP                                             | connecteur *Change Streams*                                             | compilation asynchrone continue                         |     |
| 5️⃣   | topics `cdc` > staging OLAP                                         | connecteur sink *Kafka Connect/Snowflake*                               | extraction asynchrone continue                          |     |
| 5️⃣   | topics `fraud` > staging OLAP                                       | connecteur sink *Kafka Connect/Snowflake*                               | extraction asynchrone continue                          |     |
| 4️⃣   | actualisation des features : Topics `cdc` > NoSQL `features`        | job *Flink*                                                             | actualisation des features, asynchrone continue         |     |
| 4️⃣   | actualisation du cache marchands : Topics `cdc` > NoSQL `merchants` | job *Flink*                                                             | actualisation asynchrone continue                       |     |
| 3️⃣🄸 | topics `cdc` > topics `security`                                    | relais *Kafka Streams*                                                  | relais asynchrone continue                              |     |
| 2️⃣🄱 | topics `cdc` > OLTP `AuditChangeLog`                                | connecteur sink *Kafka Connect* + *SMT (Simple Message Transformation)* | asynchrone continue                                     |     |
| 2️⃣🄱 | topics `fraud`  > OLTP `FraudScore`                                 | connecteur sink *Kafka Connect*                                         | asynchrone continue                                     |     |
| 2️⃣🄱 | topics `audit` > OLTP `DataAccessLog`                               | connecteur sink *Kafka Connect*                                         | asynchrone continue                                     |     |
| 2️⃣🄱 | topics `audit` > OLTP `SecurityIncident`                            | job *Flink*                                                             | détection des tentatives suspectes, asynchrone continue |     |
| 6️⃣   | topics `security` > canal de notification                           | connecteur sink *Kafka Connect/webhook*                                 | ingestion asynchrone continue                           |     |
    

<div style="page-break-after: always;"></div>

### D1.x. Remarques

###### `event_logs` vs. `audit.access` (D4)

`event_logs` est un journal d'erreur technique ou opérationnelle : une panne de service, un timeout, une exception applicative. `audit.access` trace les accès en lecture des données OLTP.

|             | `event_logs` | `audit.access`|
| ----------- | ------------ | ------------- |
| Question    | "Qu'est-ce qui a mal fonctionné techniquement?" | "Qui a consulté quelle donnée?" |
| Déclencheur | Erreur/exception d'un service | Lecture réussie ou refusée | 
| Exemple     | "Card authorization timeout" sur `payment-gateway` | Un agent support consulte le profil d'un client| 
| Alimente    | Rien % sécurité/conformité | `DataAccessLog` (OLTP), alerting *Flink* (D5 §D5.8.5) | 

###### Reporting Sécurité  & Conformité OLTP vs. OLAP (D4)

On a deux types de reporting lié à la *sécurité et à la conformité* :

|              | Reporting réglementaire | Reporting analytique |
| ------------ | ----------------------- | -------------------- |
| Consommateur | Délégué à la protection des données (DPO), responsable conformité | Analyste risque, équipe GRC (_Governance, Risk, Compliance_)|
| Produit      | Dépôts légaux, notification de violation, réponse à une demande RGPD | Tableaux de bord de tendance, corrélations, revues périodiques|
| Contrainte   | Délai légal opposable (72h, 30/45j), valeur probante | Aucune échéance légale, exploration libre|
| Fraîcheur    | Nécessaire à l'instant du dépôt | Suffisante avec un décalage batch |
| Valeur       | Traçabilité directe à la source, preuve d'audit | Corrélation avec d'autres dimensions (marchand, segment, temps) |
| Dépendance   | Traçable à la source, isolé du pipeline partagé | Dépend du pipeline OLAP (Kafka/Airflow/dbt) |
| Source       | OLTP | OLAP |

Le chemin OLTP est volontairement minimal, aussi proche de la source que possible. D'un autre coté, l'outil de reporting RGPD/PCIDSS ne peut pas avoir de connexion directe à la base transactionnelle (cf. §D1.3 "alimente les rapports \[...\] sans exposer l'OLTP directement aux outils de reporting" ) . D'où la nécessité d'un job d'extraction dédié.

<div style="page-break-after: always;"></div>

### D1.x.  Sujets non couverts

La sélection des technologies et des outils managés sous-jacents (*MongoDB Atlas*, self-hosted, ou service compatible de type *DocumentDB* est une décision d'infrastructure et d'hébergement hors du périmètre de l'architecture de données.

La sélection du bus d'évènements *Kafka* est une exigence technique dans le *business case* \[R0\], bien qu'elle soit normalement exclue du périmètre de l'architecture de données proprement dite.

La sélection de l'entrepôt analytique *Snowflake* est une décision prise dans \[D5\]  et justifiée dans \[D5-A\], mais représentée ici pour permettre au diagramme d'architecture de montrer les choix techniques les plus importants sans avoir à dépendre du document technique \[D5\].

La stratégie de réplication/failover propre à *OLTP* est détaillée séparément (cf. \[D2-C\]).

---

<div style="page-break-after: always;"></div>

### Références

Spécifications
- \[D0\] [Stripe Project Introduction](stripe-project--d0-introduction.pdf)

#### Livrables
- \[D2\] [OLTP Entity-Relation Diagrams](stripe-project--d2-oltp-diagrams.pdf)
- \[D3\] [OLAP System Schema Design](stripe-project--d3-olap-design.pdf)
- \[D4\] [NoSQL Data Model](stripe-project--d4-nosql-data-model.pdf)
- \[D5\] [Data Pipeline Architecture](stripe-project--d5-data-pipeline-architecture.pdf)
- \[D6\] [Security and Compliance Plan](stripe-project--d7-security-and-compliance-plan.pdf)
- \[D7\] [Machine Learning Integration Strategy](stripe-project--d7-ml-integration-strategy.pdf)

#### Annexes
- \[D2-C\] [OLTP Supporting Notes](stripe-project--d2-oltp-annexe-c--supporting-notes.pdf)
- \[D5-A\] [Data Pipeline Supporting Notes](stripe-project--d5-data-pipeline-annexe-a--supporting-notes.pdf)

---

<div style="page-break-after: always;"></div>

### Annexe : Diagramme d'architecture globale complet

![[diagrams/stripe-project--d1-data-architecture--diagram-1.svg]]
