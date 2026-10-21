---
version: v01
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-0
  - stripe-project/introduction
---

STRIPE PROJECT
===

# 0. Introduction

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / Introduction / v01 --- 2026/11/05.*
---

- [0.1. Contexte](#0-1--introduction)
- [0.2. Enoncé](#0-2--enonce)
	- [0.2.1. Contexte d'entreprise](#0-2-1--contexte-d-entreprise)
	- [0.2.2. Objectifs de l'exercice](#0-2-2--objectifs-de-l-exercice)
	- [0.2.3. Enjeux stratégiques](#0-2-3--enjeux-strategiques)
	- [0.2.4. Exigences d'affaire](#0-2-4--exigences-d-affaire)
	- [0.2.5. Exigences techniques](#0-2-5--exigences-techniques)
	- [0.2.6. Sources de données](#0-2-6--sources-de-donnees)
	- [0.2.7. Livrables](#0-2-7--livrables)
	- [0.2.8. Traçabilité des exigences](#0-2-8--tracabilites-des-exigences)
- [0.3. Compréhension](#0-3--comprehension)
- [0.4. Périmètre](#0-4--périmetre)
- [Références](#références)

## 0.1. Contexte

[objectif du document : exercice pour le bloc 2 de la certif AIA ]

## 0.2. Enoncé

D'après \[R0\].

### 0.2.1. Contexte d'entreprise
*Stripe* est une entreprise de technologie financière de premier plan, fondée en 2010, et basée à San Francisco, en Californie. Elle propose une suite complète de produits pour gérer les paiements et les opérations financières des entreprises de toutes tailles. Elle accompagne des millions de marchands dans le monde entier et traite des milliards de transactions chaque année. À mesure que la société se développe, elle fait face à une complexité croissante dans la gestion de ses données réparties sur différentes plateformes, incluant les systèmes transactionnels (OLTP), les systèmes analytiques (OLAP) et les bases de données non relationnelles (NoSQL).

### 0.2.2. Objectifs de l'exercice
*Stripe* souhaite construire une infrastructure de données de pointe qui intègre de manière fluide ces différents types de systèmes afin de soutenir à la fois l'excellence opérationnelle et l'analyse avancée. L'objectif de cet exercice est de créer une architecture de données unifiée et évolutive, capable de gérer de gros volumes de données transactionnelles, de supporter des requêtes analytiques complexes, et de gérer des données non structurées pour des cas d'usage avancés tels que la détection de fraude, l'analyse du comportement client et les recommandations en temps réel. 
### 0.2.3. Enjeux stratégiques

#### 0.2.3.1. Synopsis

Les enjeux stratégiques de l'exercice sont les suivants :

| #      | Enjeu stratégique (fr)                                  | Business Objective (en) |
| ------ | ------------------------------------------------------- | ----------------- | 
| **C1** | Charges transactionnelles complexes                     | Complex Transactional Workloads |
| **C2** | Besoins avancés en matière d'analytique                 | Advanced Analytics Requirements |
| **C3** | Gestion des données non structurées et semi-structurées | Handling Unstructured and Semi-Structured Data |
| **C4** | Intégration des données entre systèmes                  | Data Integration Across Systems |
| **C5** | Sécurité e conformité                                   | Security & Compliance |

#### 0.2.3.2. Descriptions détaillées

##### C1. Complex Transactional Workloads
Les systèmes *OLTP* de *Stripe* traitent des millions de transactions chaque jour, avec des exigences élevées en matière de disponibilité, de cohérence et de rapidité. Ces transactions incluent les paiements, les remboursements (refunds), les rétro-facturations (chargebacks) et la gestion des abonnements. L'entreprise doit s'assurer que ces systèmes sont hautement disponibles, évolutifs et capables de supporter de nouvelles fonctionnalités comme la détection de fraude en temps réel.

##### C2. Advanced Analytics Requirements
 *Stripe* doit fournir une analytique robuste à ses clients et aux parties prenantes internes. Cela inclut l'analyse des revenus, la segmentation client, le reporting de conformité et le suivi de la performance des différents produits. L'entreprise a besoin d'un système *OLAP* capable de traiter des requêtes complexes efficacement, de supporter l'analyse ad hoc, et de fournir des insights quasi temps réel.

##### C3. Handling Unstructured and Semi-Structured Data
 *Stripe* collecte de grandes quantités de données non structurées et semi-structurées, telles que les journaux (logs), les retours clients et les données d'interaction issues de son site web et de ses applications mobiles. Ces données sont essentielles pour construire des modèles de machine learning dédiés à la détection de fraude, à la personnalisation client et à l'analyse prédictive. L'entreprise a besoin d'une base de données *NoSQL* capable de stocker et traiter efficacement ces données, de les intégrer aux données relationnelles, et d'offrir des capacités de requêtage flexibles.

##### C4. Data Integration Across Systems
Intégrer les données entre les systèmes *OLTP*, *OLAP* et *NoSQL* constitue un défi majeur. *Stripe* a besoin d'une architecture de données unifiée permettant une circulation fluide des données entre ces systèmes, garantissant que les données restent cohérentes, à jour et accessibles pour les différents cas d'usage.

##### C5. Security & Compliance
Étant donné la nature sensible des données financières, *Stripe* doit s'assurer que son architecture de données respecte les réglementations telles que le RGPD, la norme PCI-DSS et le CCPA. L'entreprise doit également mettre en œuvre des mesures de sécurité robustes pour protéger les données au repos et en transit, gérer les contrôles d'accès, et surveiller l'utilisation des données.

### 0.2.4. Exigences d'affaire

#### 0.2.4.1. Synopsis

Les enjeux stratégiques de l'exercice sont les suivants :

| #       | Exigence d'affaire (fr)              | Business Requirement (en)               |
| ------- | ------------------------------------ | --------------------------------------- |
| **BR1** | Intégrité transactionnelle           | Transactional Integrity (OLTP)          |
| **BR2** | Analytique évolutive et efficace     | Scalable and Efficient Analytics (OLAP) |
| **BR3** | Gestion flexible des données         | Flexible Data Management (NoSQL)        |
| **BR4** | Intégration et cohérence des données | Data Integration Across Systems         |
| **BR5** | Sécurité et conformité               | Security & Compliance                   |

#### 0.2.4.2. Descriptions détaillées

##### BR1. Transactional Integrity
Les systèmes *OLTP* de *Stripe* doivent gérer de gros volumes de transactions avec une latence minimale. Le système doit respecter les propriétés ACID afin de garantir la cohérence et l'intégrité des données dans des environnements distribués. Il doit également supporter des fonctionnalités telles que les transactions multi-documents, la synchronisation des données en temps réel, et la reprise après sinistre (disaster recovery).

##### BR2. Scalable and Efficient Analytics
 Le système *OLAP* doit supporter des requêtes complexes sur de grands ensembles de données. Il doit être capable d'agréger les données selon plusieurs dimensions, de supporter l'analyse de séries temporelles, et de gérer des jointures et sous-requêtes à grande échelle. Le système doit fournir des réponses à faible latence pour les requêtes métier critiques et supporter à la fois l'analyse historique et l'analyse quasi temps réel.

##### BR3. Flexible Data Management
*Stripe* a besoin d'un système *NoSQL* capable de gérer des types de données variés, incluant le JSON, le XML et les données binaires. Le système doit supporter une conception de schéma flexible, permettre un requêtage efficace des données imbriquées et non structurées, et s'intégrer avec les autres systèmes de données afin d'offrir une vue globale et cohérente des données.

##### BR4. Data Integration and Consistency
L'architecture de données doit garantir une circulation cohérente des données entre les systèmes *OLTP*, *OLAP* et *NoSQL*. *Stripe* doit mettre en œuvre des pipelines de données capables de gérer le traitement par lots (batch), les flux de données en continu (streaming), et la synchronisation en temps réel. L'architecture doit supporter les processus *ETL*/*ELT* et permettre la transformation et l'enrichissement des données.

##### BR5. Security and Compliance
L'architecture de données doit inclure des mesures de sécurité robustes, telles que le chiffrement, les contrôles d'accès et la journalisation d'audit. *Stripe* doit s'assurer que son stockage et son traitement des données respectent les exigences réglementaires des différentes juridictions. Le système doit supporter un reporting de conformité automatisé et une surveillance en temps réel des failles de sécurité.

### 0.2.5. Exigences techniques

#### 0.2.5.1. Synopsis

Les enjeux stratégiques de l'exercice sont les suivants :

| #       | Exigence Technique (fr)                           | Technical Requirement (en)               |
| ------- | ------------------------------------------------- | ---------------------------------------- |
| **TR1** | Conception des modèles de données                 | Data Model Design (OLTP, OLAP, NoSQL)    |
| **TR2** | Architecture du pipeline de données               | Data Pipeline Architecture               |
| **TR3** | Optimisation de l'évolutivité et des performances | Scalability and Performance Optimization |
| **TR4** | Cohérence et synchronisation des données          | Data Consistency and Synchronization     |
| **TR5** | Sécurité et conformité                            | Security & Compliance                    |
| **TR6** | Analytique avancée et machine learning            | Advanced Analytics and Machine Learning  |

#### 0.2.5.2. Descriptions détaillées

##### TR1. Data Model Design
Concevoir des modèles de données pour chaque type de système :
- **OLTP** : privilégier des schémas normalisés, l'intégrité transactionnelle et l'optimisation des performances.
- **OLAP** : concevoir des schémas en étoile ou en flocon pour un requêtage et une agrégation efficaces. Inclure des tables pré-agrégées pour les requêtes courantes.
- **NoSQL** : concevoir des schémas flexibles supportant les données non structurées et permettant un requêtage et une récupération de données efficaces.

##### TR2. Data Pipeline Architecture
Développer un *pipeline* de données intégrant les systèmes *OLTP*, *OLAP* et *NoSQL*. Le pipeline doit supporter le traitement par lots et en temps réel, ainsi que la transformation et l'enrichissement des données. Envisager l'utilisation d'outils tels qu'*Apache Kafka* pour le streaming de données en temps réel et *Apache Airflow* pour l'orchestration des processus ETL/ELT.

##### TR3. Scalability and Performance Optimization
S'assurer que l'architecture de données peut monter en charge horizontalement pour gérer des volumes de données croissants. Mettre en œuvre des stratégies d'indexation, de partitionnement et de mise en cache afin d'optimiser les performances sur l'ensemble des systèmes. Envisager l'utilisation de bases de données distribuées et du sharding pour garantir une haute disponibilité.

##### TR4. Data Consistency and Synchronization
Mettre en œuvre des mécanismes garantissant la cohérence des données entre les systèmes *OLTP*, *OLAP* et *NoSQL*. Envisager des modèles de cohérence à terme (*eventual consistency*) lorsque cela est pertinent, et mettre en œuvre des stratégies de résolution de conflits pour les données distribuées. Utiliser des techniques de *CDC* (*Change Data Capture*) pour maintenir les données synchronisées en temps réel.

##### TR5. Security and Compliance
Concevoir un cadre de sécurité incluant le chiffrement des données, le contrôle d'accès basé sur les rôles (RBAC) et la journalisation d'audit. S'assurer que l'architecture respecte les réglementations en vigueur (ex. RGPD, PCI-DSS). Mettre en œuvre des contrôles de conformité automatisés et des fonctionnalités de reporting.

##### TR6. Advanced Analytics and Machine Learning
Intégrer des modèles de *machine learning* au sein du système *NoSQL* pour la détection de fraude en temps réel et la personnalisation client. S'assurer que le pipeline de données supporte l'extraction de caractéristiques (*feature extraction*) et le déploiement de modèles. Prévoir des mécanismes de suivi de la performance des modèles et de mise à jour.

### 0.2.6. Sources de données

D'après \[R0\].

#### 0.2.6.1. Synopsis

| #       | Source de données (fr)                      | Data Source (en)                              |
| ------- | ------------------------------------------- | --------------------------------------------- |
| **DS1** | Données transactionnelles                   | Transactional Data (OLTP)                     |
| **DS2** | Données analytiques                         | Analytical Data (OLAP)                        |
| **DS3** | Données non structurées et semi-structurées | Unstructured and Semi-Structured Data (NoSQL) |
| **DS4** | Données de référence                        | Reference Data                                |

#### 0.2.6.2. Descriptions détaillées

##### DS1. Transactional Data
Capturent l'ensemble des transactions financières traitées par *Stripe*. Champs inclus :
- Identifiant de transaction
- Identifiant marchand
- Identifiant client
- Montant de la transaction
- Devise
- Moyen de paiement
- Date et heure de la transaction
- Localisation (géolocalisation par IP)
- Type d'appareil (mobile, ordinateur, etc.)
- Statut (réussie, échouée, remboursée)
- Indicateurs de fraude (ex. scores d'anomalie)

##### DS2. Analytical Data
Données agrégées et historiques utilisées pour le reporting et l'analyse. Champs inclus :
- Indicateurs de revenus (journaliers, hebdomadaires, mensuels)
- Données de segmentation client
- Indicateurs de performance produit
- Données d'analyse de la fraude
- Journaux de conformité et d'audit

##### DS3. U/S and S/S Data
 Données collectées depuis diverses sources, telles que les journaux, les interactions clients et les données générées par des machines. Champs inclus :
- Données de journaux (journaux d'erreurs, journaux d'accès)
- Données d'interaction utilisateur (données de clics, données de session)
- Caractéristiques (features) de machine learning (données d'entrée des modèles)
- Retours clients (avis, réponses aux enquêtes)

##### DS4. Reference Data
Données statiques ou évoluant lentement, utilisées à travers l'ensemble des systèmes :
- Codes pays et région
- Taux de change des devises
- Informations sur les marchands
- Catalogues produits

### 0.2.7. Livrables

D'après \[R0\].

#### 0.2.7.1. Synopsis

| #      | Livrable (fr)                               | Deliverable (en)                        |
| ------ | ------------------------------------------- | --------------------------------------- | 
| **D1** | Diagramme d'architecture de données complet | Comprehensive Data Architecture Diagram |
| **D2** | ERD pour le système OLTP                    | ERD for OLTP System |
| **D3** | Conception du schéma pour le système OLAP   | Schema Design for OLAP System |
| **D4** | Modèle de données NoSQL                     | NoSQL Data Model |
| **D5** | Architecture du pipeline de données         | Data Pipeline Architecture |
| **D6** | Plan de sécurité et de conformité           | Security and Compliance Plan |
| **D7** | Stratégie d'intégration du machine learning | Machine Learning Integration Strategy |
| **D8** | Requêtes SQL et NoSQL                       | SQL and NoSQL Queries |

#### 0.2.7.2. Descriptions détaillées
##### D1. Data Architecture Diagram
Diagramme détaillé montrant l'intégration des systèmes de données (*OLTP*, *OLAP*, *NoSQL*), incluant les flux de données, les pipelines et les modèles de données.
##### D2. OLTP System's Entity-Relation Diagram
Diagramme entité-relation (ERD) présentant le schéma normalisé du système transactionnel.
##### D3. OLAP System's Schema Design 
Conception détaillée du schéma pour le système OLAP, incluant les schémas en étoile ou en flocon, les stratégies d'agrégation et les techniques d'optimisation des requêtes.
##### D4. NoSQL Data Model
Une conception détaillée du schéma pour le système *NoSQL*, incluant les stratégies de gestion des données non structurées, des relations et de l'indexation.
##### D5. Data Pipeline Architecture
Document technique décrivant l'architecture du pipeline de données, incluant les outils, technologies et processus d'intégration et de synchronisation des données.
##### D6. Security and Compliance Plan
Plan détaillé décrivant les mesures de sécurité, les stratégies de conformité et les outils de surveillance à mettre en œuvre à travers l'architecture de données.
##### D7. Machine Learning Integration Strategy
Document décrivant l'intégration des modèles de machine learning au sein du système NoSQL, incluant l'extraction de caractéristiques, le déploiement de modèles et le suivi de la performance.
##### D8. SQ/NoSQL Queries
Un ensemble de requêtes SQL et NoSQL démontrant comment des questions métier clés (ex. analyse des revenus, détection de fraude, segmentation client) peuvent être répondues à l'aide des modèles de données proposés.

### 0.2.8. Traçabilité des exigences

#### 0.2.7.1. Couverture des enjeux stratégiques

| #      | Business Objective              | Business Requirements | Technical Requirements           | Livrables      |
| ------ | ------------------------------- | --------------------- | -------------------------------- | -------------- |
| **C1** | Complex Transactional Workloads | BR1                   | TR1 _(volet OLTP)_, TR3\[, TR6\] | D1, D2, D8     |
| **C2** | Advanced Analytics Requirements | BR2                   | TR1 _(volet OLAP)_, TR3          | D1, D3, D8     |
| **C3** | Handling U/S and S/S Data       | BR3                   | TR1 _(volet NoSQL)_, TR6         | D1, D4, D7, D8 |
| **C4** | Data Integration Across Systems | BR4                   | TR2, TR4                         | D1, D5         |
| **C5** | Security and Compliance         | BR5                   | TR5                              | D1, D6         |

#### 0.2.7.2. Couverture des exigences d'affaire

| #       | Business Requirement                 | Business Objective | Technical Requirements   | Livrables      |
| ------- | ------------------------------------ | ------------------ | ------------------------ | -------------- |
| **BR1** | Intégrité transactionnelle           | C1                 | TR1 *(volet OLTP)*, TR3  | D1, D2, D8     |
| **BR2** | Analytique évolutive et efficace     | C2                 | TR1 *(volet OLAP)*, TR3  | D1, D3, D8     |
| **BR3** | Gestion flexible des données         | C3                 | TR1 *(volet NoSQL)*, TR6 | D1, D4, D7, D8 |
| **BR4** | Intégration et cohérence des données | C4                 | TR2, TR4                 | D1, D5         |
| **BR5** | Sécurité et conformité               | C5                 | TR5                      | D1, D6         |

#### 0.2.7.3. Couverture des exigences techniques

| #       | Technical Requirement                       | Business Objectives | Business Requirements | Livrables          |
| ------- | ------------------------------------------- | ------------------- | --------------------- | ------------------ |
| **TR1** | Conception des modèles de données           | C1, C2, C3          | BR1, BR2, BR3         | D1, D2, D3, D4, D8 |
| **TR2** | Architecture du pipeline de données         | C4                  | BR4                   | D1, D5             |
| **TR3** | Évolutivité & optimisation des performances | C1, C2              | BR1, BR2              | D1, D2, D3, D8     |
| **TR4** | Cohérence & synchronisation des données     | C4                  | BR4                   | D1, D5             |
| **TR5** | Sécurité & conformité                       | C5                  | BR5                   | D1, D6             |
| **TR6** | Analytique avancée & machine learning       | C3                  | BR3                   | D1, D4, D7         |

## 0.3. Compréhension

[...]
- métiers et fonctionnements de Stripe
- produits, services et revenus
- scénario de paiement typique

## 0.4. Périmètre

[...]
- contour fonctionnel
	- gérer des transactions du point de vue du client 
- cas d'utilisation
	- enregistrement des marchands, catalogues et plans tarifaires,
	- enregistrement des clients, abonnements, moyens de paiement,
	- enregistrement des transactions, remboursement, et retro-facturations (litiges),
	- scoring de fraude au paiement,
	- alerting de sécurité,
	- reporting de conformité.
- limites
	- pas de dépôts ni de reversement au marchands
	- pas de produits ni de services annexes
	- pas de description unifiée de l'architecture distribué. implicite dans annexe D (OLTP). 
	- intégration du machine learning  : étude de cas des modèles de scoring de fraude ; description succincte des modèles de personnalisation et d'analyse prédictive ; 
	- modèle OLTP incomplet : 
		- ~~manque `NetworkCard`~~ 
		- ~~manque pré-calcul de `Chargeback.due_at` (comme `DataSubjectRequest.due_at`)~~

---

## Références

#### Ressources
- \[R0\] [Stripe Business Case](specs/stripe-project--business-case.pdf)