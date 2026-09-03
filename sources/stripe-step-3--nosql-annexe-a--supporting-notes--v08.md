*STRIPE* PROJECT
===
# 3. NoSQL Data System
## Annexes
### 3.A. Justification du modèle de stockage


> *Nicolas Pichon - AIA RNCP 38777 / BC02 / NoSQL Data System - Annexe A / v08 - 2026/10/13.* 
  
---

#### 3.A.1. Pourquoi choisir une base orientée _documents_?

La première exigence technique du *business case* (TR1 dans \[R0\]) demande explicitement que le système soit capable de requêter efficacement des données non structurées imbriquées (_"efficient querying of nested and unstructured data"_). Cette exigence élimine, de fait, les trois autres familles de stockage *NoSQL* (cf. analyse ci-dessous).

#### 3.A.2. Sources de données

D'après \[R0\], les types de données que le système *NoSQL* prendre en compte sont les suivants (cf. _"3. Data Source_/_Semi-Structured and Non Structured Data"_ dans \[R0\]) :

- *Clickstreams des utilisateurs & données de sessions* : un événement de clic n'a pas les mêmes attributs qu'une soumission de formulaire ou qu'une vue de page ; la structure varie par nature d'un enregistrement à l'autre.
- *Machine Learning features (détection de fraude)* : un vecteur de caractéristiques évolue au fil des itérations du modèle : on ajoute, retire, recombine des variables sans prévenir.
- *Retours clients (avis, enquêtes)* : texte libre plus métadonnées dont les champs varient selon le canal de collecte.

Point commun de ces sources : une structure imprévisible et changeante, et de gros volumes.

#### 3.A.3. Pourquoi rejeter les trois autres familles de stockage?

###### Stockage par clé-valeur (*Redis*, *DynamoDB*)
Excellent pour une lecture par clé unique, mais aucune capacité native à interroger _à l'intérieur_ de la donnée. Impossible de requêter "*tous les événements t.q. `device_type = mobile` et `event_type = click`*" sans tout rapatrier du côté de l'application. Or c'est exactement ce type de requête qu'exige l'exigence TR1 \[R0\].

###### Stockage par colonne (*Cassandra*, *HBase*)
Très bon pour un débit d'écriture extrême sur un schéma de colonnes relativement stable, mais une famille de colonnes reste rigide par nature. Mal adapté à des enregistrements dont la forme change d'un type d'événement à l'autre.

###### Stockage en graphe (*Neo4j*)
Pertinent pour des requêtes de traversée de relations (détection de réseaux de fraude coordonnée, par exemple), mais ce n'est pas le besoin ici : on stocke des événements et des vecteurs de caractéristiques, pas un graphe de relations à parcourir.

#### 3.A.4. Ce que le stockage par documents apporte spécifiquement
##### 3.A.4.1. Le format correspond déjà à la donnée source
Un événement de *clickstream* envoyé par une app web/mobile est nativement un objet JSON. Le stocker tel quel, sans le forcer dans un schéma relationnel fixe, évite une transformation qui n'apporterait rien.

##### 3.A.4.2. Schéma flexible sans migration
Un document non structuré de type JSON absorbe immédiatement les nouveaux types d'événement ou les nouveaux champs de feature, sans restructuration de tables SQL ni migration des enregistrements existants. Cette flexibilité permet au modèle de données d'évoluer continûement (nouvelles features testées, nouvelle instrumentation produit) sans surcoût significatif.
##### 3.A.4.3. Requêtage riche sur des champs imbriqués
Pour répondre à l'exigence technique "_Efficient querying of nested and unstructured data_" (TR1 \[R0\]), *MongoDB* propose des mécanismes optimisés d'accès aux données imbriqués (et dont on ne disposera pas dans les systèmes de stockage par clé-valeur comme *Redis* ou *DynamoDB*) :
- Indexation secondaire sur des sous-champs ;
	- Par exemple, ce type d'indexation permet de trier ou de filtrer directement sur le champ `fraud_v3` qui est lui-même imbriqué dans la structure `model_scores` de la collection `ml_features` (cf. *Collections* dans \[D4\]) ; 
- Indexation *multikey* sur des tableaux imbriqués ; 
	- Exemple : dans la collection `user_sessions`, `events` est un tableau imbriqué dans chaque objet de session, `metadata`est une structure imbriquée dans chaque objet d'évènement; le champ `metadata.transaction_id` est donc niché à deux niveaux à l'intérieur de chaque élément de ce tableau (cf. *Collections* dans \[D4\]). 
	- *MongoDB* crée automatiquement une entrée d'index par élément du tableau, de sorte qu'une requête comme `findOne({"events.metadata.transaction_id": "b7c2..."})` retrouve directement la session concernée sans parcourir un seul document ligne par ligne.

##### 3.A.4.4. Capture des changements par *Change Streams*
*MongoDB* dispose nativement d'un mécanisme de capture des modifications basé sur des flux d'évènements continus dits *Change Streams*. Ecouter ces flux en temps réel permet au système d'alimenter le pipeline *NoSQL* -> *OLAP* via l'orchestration*Airflow* (cf. architecture globale \[D1\]).

##### 3.A.4.5. *Sharding* horizontal natif
Pour répondre à l'exigence technique "_distributed databases and data sharding_" (TR3 \[R0\]), *MongoDB* propose nativement des capacités de *sharding* horizontal. Cette technique de partitionnement permet de mettre le système à l'échelle horizontalement (*horizontal scaling*)  sans avoir besoin de revoir le modèle.

---

<div style="page-break-after: always;"></div>

#### Références
##### Ressources
- \[R0\] [Stripe Business Case](stripe-project--business-case.pdf)
##### Livrables
- \[D1\] [Data Architecture Diagram](stripe-step-8--data-architecture--v08.pdf)
- \[D4\] [NoSQL Data Model](stripe-step-3--nosql-data-model--v08.pdf)