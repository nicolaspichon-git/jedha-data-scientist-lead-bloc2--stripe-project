*STRIPE* PROJECT
===

# 8. Architecture Globale
## D1. Diagramme détaillé d'architecture globale

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D1 : Diagramme d'Architecture / v25 - 2026/10/13.*

---

### D1.1. Contexte

Le cahier des charges (D1) demande un diagramme montrant l'intégration des systèmes OLTP,
OLAP et NoSQL - flux de données, pipelines, et modèles de données. Contrairement à D2 (ERD
détaillée du seul OLTP), ce diagramme se place au niveau **architecture** : quels systèmes,
quels mécanismes de transport entre eux, quel usage en sortie.

Trois principes structurants, hérités des choix déjà justifiés côté OLTP (Annexe 1.C) :
- **Le chemin transactionnel ne doit jamais être ralenti** par la conformité, l'analytique ou
  la détection de fraude - tout ce qui part de l'OLTP vers les autres systèmes est asynchrone.
- **CDC plutôt que triggers synchrones** pour répliquer les changements (déjà retenu pour
  `ChangeAuditLog`, généralisé ici à l'alimentation de l'OLAP).
- **Taux de change figé côté OLAP**, jamais recalculé côté OLTP (déjà acté dès la conception
  de `Transaction` - voir note v06).

### D1.2. Diagramme

```mermaid
flowchart TB
    subgraph ACTEURS["👤&nbsp;<u>Acteurs</u>"]
        direction LR
        CUST_APP["App / Checkout<br/>client"]
        MERCH_API["Dashboard / API<br/>marchand"]
        ADMIN["Support / Ops<br/>interne"]
    end

    subgraph OLTP_SYS["🔵&nbsp;<u>OLTP - PostgreSQL (Annexe 1.B)"]
        direction TB
        OLTP_CORE["<u>Métier</u><br/>Customer | Merchant | Transaction | Subscription | Product | PricingPlan"]
        OLTP_COMP["<u>Sécurité & Conformité</u><br/>DataAccessLog | ChangeAuditLog | ConsentRecord | DataSubjectRequest | SecurityIncident"]
    end

    subgraph STREAM["⚪ Bus d'événements - Kafka"]
        direction LR
        TOPIC_CDC["Topic : cdc.transaction<br/>cdc.subscription ..."]
        TOPIC_APP["Topic : audit.access<br/>fraud.signal"]
    end

    subgraph NOSQL_SYS["🟠 NoSQL - MongoDB / DynamoDB"]
        direction TB
        NOSQL_LOGS["Logs bruts, clickstream,<br/>interactions client (DS3)"]
        NOSQL_FEATURES["Features ML<br/>(entraînement fraude)"]
    end

    subgraph ORCH["⚫ Orchestration - Airflow"]
        ETL["DAGs ETL/ELT batch<br/>+ conversion de change<br/>(taux de référence figé)"]
    end

    subgraph OLAP_SYS["🟣 OLAP - Entrepôt analytique"]
        direction TB
        OLAP_FACTS["FactTransaction · FactFraudEvent<br/>FactAuditEvent · FactSubscriptionSnapshot"]
        OLAP_DIM["Dimensions + tables agrégées<br/>DimMerchant (SCD2) · DimReferenceExchangeRate"]
    end

    subgraph MLSYS["🔴 Service de scoring fraude"]
        FRAUD_SVC["Modèle temps réel"]
    end

    subgraph CONSO["🟢 Consommation"]
        direction LR
        BI["BI / Dashboards<br/>revenu, produit"]
        COMPLIANCE["Reporting conformité<br/>RGPD / PCI-DSS"]
        MERCH_ANALYTICS["Analytics<br/>exposées au marchand"]
    end

    CUST_APP -->|paiement, consultation| OLTP_CORE
    MERCH_API -->|catalogue, config| OLTP_CORE
    ADMIN -->|actions admin| OLTP_CORE

    OLTP_CORE -.->|CDC synchrone<br/>Debezium / réplication logique| TOPIC_CDC
    OLTP_CORE -->|écriture directe<br/>append-only| OLTP_COMP
    OLTP_COMP -.->|écriture asynchrone<br/>hors chemin critique| TOPIC_APP
    CUST_APP -.->|clickstream direct<br/>bus d'événements| TOPIC_APP

    TOPIC_APP --> NOSQL_LOGS
    TOPIC_APP --> NOSQL_FEATURES
    NOSQL_FEATURES --> FRAUD_SVC
    FRAUD_SVC -->|score écrit en synchrone<br/>FraudScore, hors verrou Transaction| OLTP_CORE

    TOPIC_CDC --> ETL
    NOSQL_LOGS -.->|batch agrégé| ETL
    ETL --> OLAP_FACTS
    ETL --> OLAP_DIM

    OLAP_FACTS --> BI
    OLAP_DIM --> BI
    OLTP_COMP -->|extraction batch| COMPLIANCE
    OLAP_FACTS --> MERCH_ANALYTICS

    style OLTP_SYS fill:#EBF5FB,stroke:#3498DB,stroke-width:2px
    style STREAM fill:#F4F6F6,stroke:#95A5A6,stroke-width:1px
    style NOSQL_SYS fill:#FDF2E3,stroke:#E67E22,stroke-width:1px
    style ORCH fill:#F2F3F4,stroke:#5D6D7E,stroke-width:1px
    style OLAP_SYS fill:#F4ECF7,stroke:#8E44AD,stroke-width:2px
    style MLSYS fill:#FDEDEC,stroke:#E74C3C,stroke-width:1px
    style CONSO fill:#EAFAF1,stroke:#27AE60,stroke-width:1px
    style ACTEURS fill:#FFFFFF,stroke:#BFC9CA,stroke-width:1px
```

### D1.3. Lecture des flux

| Flux | Mécanisme | Justification |
|---|---|---|
| Client/Marchand → OLTP | Écriture synchrone directe | Chemin transactionnel, ACID requis (T1, BR1) |
| OLTP cœur → topic CDC | CDC (Debezium / réplication logique WAL) | Même principe que `ChangeAuditLog` (Annexe 1.C) : jamais de trigger synchrone sur `Transaction` |
| OLTP conformité → topic applicatif | Écriture asynchrone (bus d'événements) | `DataAccessLog` ne peut pas utiliser le CDC - rien à lire dans le WAL pour un `SELECT` (voir Annexe 1.C) |
| Topic applicatif → NoSQL | Ingestion continue | Absorbe logs, clickstream, interactions (DS3) - schéma flexible, volumétrie non bornée |
| NoSQL features → service de scoring | Lecture temps réel | Alimente le modèle de fraude en continu |
| Service de scoring → OLTP | Écriture synchrone ciblée sur `FraudScore` | Table découplée de `Transaction` (Annexe 1.C) : n'ajoute aucun verrou sur le chemin critique |
| Topic CDC + NoSQL → Airflow → OLAP | Batch ETL/ELT planifié | Conversion de change appliquée ici, avec taux de référence figé - jamais recalculée côté OLTP |
| OLAP → BI / marchand | Requêtes analytiques | Découplé du chemin transactionnel, aucun impact sur la latence de paiement |
| Conformité OLTP → reporting | Extraction batch | Alimente les rapports RGPD/PCI-DSS sans exposer l'OLTP directement aux outils de reporting |

### D1.4. Couverture du diagramme

Le choix précis de l'outillage managé (quel service Kafka, quel entrepôt OLAP, quelle base NoSQL) sont hors périmètre (décision d'infrastructure, pas d'architecture de données). 
La stratégie de réplication/failover propre à l'OLTP est détaillée séparément (annexe 1.C).

---
