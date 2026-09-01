*STRIPE* PROJECT
===

# 8. Global Data Architecture
## D1. Data Architecture Diagram 

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D1 : Data Architecture Diagram / v08 - 2026/10/13.*

---

### D1.1. Contexte

Ce document présente les grands principes de l'architecture de données du *business case Stripe*, montrant l'intégration des systèmes OLTP, OLAP et NoSQL : flux de données, pipelines, et modèles de données.

Trois principes structurent l'architecture :
1. *Le chemin transactionnel ne doit jamais être ralenti* par des processus de sécurité, de conformité, d'analytique ou de détection de fraude. Les flux de données qui partent du système transactionnel vers les autres systèmes sont donc asynchrones.
2. *Eviter les triggers synchrones pour répliquer les changements. Utiliser les systèmes CDC (Change Data Capture) du système OLTP
3. *Le taux de change est fixe dans la base analytique (actualisable périodiquement, annuellement par exemple). ~~, jamais recalculé côté OLTP (déjà acté dès la conception de `Transaction`)~~.

~~**Choix du moteur NoSQL : MongoDB (orienté document).** L'exigence TR1 demande
explicitement une base capable de *"efficient querying of nested and unstructured data"* -
ce qui élimine les trois autres familles NoSQL : clé-valeur (pas de requêtage à l'intérieur
de la donnée), colonne-famille (schéma trop rigide pour des événements dont la forme varie
selon le type), graphe (pas de besoin de traversée de relations ici). Les données visées
(DS3 : clickstream, features ML, retours clients) partagent une structure imprévisible et
changeante, nativement JSON à la source - un document store l'absorbe sans migration à
chaque nouveau champ. Les *Change Streams* MongoDB rejouent par ailleurs le même principe de réplication asynchrone que le CDC déjà retenu côté OLTP, sans mécanisme supplémentaire à
justifier pour alimenter le pipeline ETL/OLAP.~~ 

~~**Le système NoSQL joue également un rôle que les systèmes OLTP et OLAP ne peuvent porter** : rapprocher une même personne physique agissant chez plusieurs marchands (empreinte de carte ou d'appareil), sans jamais compromettre le cloisonnement transactionnel strict imposé côté OLTP (Annexe 3.C, §D4.9). C'est une capacité de la couche NoSQL, pas un flux supplémentaire représenté dans le diagramme ci-dessous.~~
 
<div style="page-break-after: always;"></div>

### D1.2. Diagramme d'architecture globale des données

![[stripe-step-8--data-architecture--v08--diagram-1B.png]]

<div style="page-break-after: always;"></div>

### D1.3. Lecture des flux de données

| Flux | Mécanisme | Justification |
|---|---|---|
| Client / Marchand → OLTP | Écriture synchrone directe | Chemin transactionnel, ACID requis (BR1) |
| OLTP coeur → Topic CDC | CDC (Debezium ou réplication logique PostgreSQL) | Même principe que `ChangeAuditLog` (Annexe 1.C) : jamais de trigger synchrone sur `Transaction` |
| OLTP coeur → Topic applicatif (accès) | Publication d'événement, asynchrone | Un `SELECT` sur `OLTP_CORE` ne laisse aucune trace dans le WAL - rien à capter en CDC pour créer la ligne (Annexe 1.C) |
| Topic applicatif → `DataAccessLog` (création) | Consommateur asynchrone | Le consommateur porte le contexte métier (`justification`) que seule l'application connaît au moment de l'accès |
| `DataAccessLog` / `ChangeAuditLog` / `ConsentRecord` / `DataSubjectRequest` / `SecurityIncident` → topic CDC | CDC (même mécanisme que `OLTP_CORE`) | Une fois la ligne insérée dans l'OLTP (par le consommateur pour `DataAccessLog`, normalement pour les quatre autres), le CDC la réplique comme n'importe quelle autre table |
| Topic applicatif → NoSQL | Ingestion continue | Absorbe logs, clickstream, interactions (DS3) - schéma flexible, volumétrie non bornée |
| NoSQL features → service de scoring | Lecture temps réel | Alimente le modèle de fraude en continu |
| Service de scoring → OLTP | Écriture synchrone ciblée sur `FraudScore` | Table découplée de `Transaction` (Annexe 1.C) : n'ajoute aucun verrou sur le chemin critique |
| Topic CDC + NoSQL → Airflow → OLAP | Batch ETL/ELT planifié | Conversion de change appliquée ici, avec taux de référence figé - jamais recalculée côté OLTP |
| OLAP → BI / marchand | Requêtes analytiques | Découplé du chemin transactionnel, aucun impact sur la latence de paiement |
| Conformité OLTP → reporting | Extraction batch | Alimente les rapports RGPD/PCI-DSS sans exposer l'OLTP directement aux outils de reporting |

### D1.4. Sujets non couverts

~~Le choix de la famille NoSQL (document, MongoDB) est désormais tranché (D1.1)~~.

La sélection des technologies et des outils managés sous-jacents (*MongoDB Atlas*, self-hosted, ou service compatible de type *DocumentDB*), tout comme le service *Kafka* ou l'entrepôt OLAP, est une décision d'infrastructure et d'hébergement hors du périmètre de l'architecture de données.

La stratégie de réplication/failover propre à *OLTP* est détaillée séparément (annexe 1.C, §1.C.5).

---
<div style="page-break-after: always;"></div>
