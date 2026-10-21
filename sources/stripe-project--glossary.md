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
  - stripe-project/glossary
---

*STRIPE* PROJECT
===

# Glossary

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / Glossary  --- 2026/11/05.*   
---

## General
- **ACID** = Atomicity, Consistency, Isolation, Durability

## OLTP Data System 

- **MCD** (**CDM**) = Modèle Conceptuel de Données (Conceptual Data Model)
- **MLD** (**LDM**) = Modèle Logique de Données (Logical Data Model)
- **DEA** (**ERD**) = Diagramme Entités-Associations (Entity-Relationship Diagram)
- **KYB** (**KYC**) = Know Your Business (Know Your Customer)
- **RFM** = Recency, Frequency, Monetary value
- **DR** = Disaster Recovery
- **AZ** = Availability Zone
- **RPO** = Recovery Point Objective
- **RTO** = Recovery Time Objective
- **PTIR** = Point-In-Time Recovery
- **WAL** = Write Ahead Log (le journal d'écriture anticipée de *PostgreSQL*) ; 
- **CDC** = Change Data Capture

## OLAP Data System

- **MRR** = Monthly Recurrent Revenue (revenu récurrent mensuel)
- **SCD** = Slowly Changing Dimension. 
	- Concept central de la méthode *Kimball*. Répond à la question : "Quand un attribut d'une dimension change dans le monde réel (un marchand change de pays, un client change de statut), que fait-on dans l'entrepôt ?"
	- Types SCD :
		- SCD1 : écraser sans garder de trace ; La nouvelle valeur remplace l'ancienne directement dans la ligne existante ; Pas d'historique : si on interroge le passé, on retrouvera la valeur _actuelle_, pas celle qui était vraie à l'époque.
		- SCD2 : garder toutes les versions, avec des dates de validité ; Un changement crée une nouvelle ligne dans la dimension (nouvelle clé technique), avec des colonnes `valid_from`/`valid_to` marquant la période de validité de chaque version. La ligne précédente n'est jamais modifiée ni supprimée, elle devient juste "expirée".
## NoSQL Data System

- **Sharding** = partitionnement horizontal.
	- Le *sharding* est une technique d’architecturation de base de données qui consiste à découper une grande base en plusieurs fragments plus petits, appelés *shards*, répartis sur différents serveurs. 
	- Dans un système *NoSQL*, au lieu de tout stocker sur un seul serveur, on divise les données en sous-ensembles disjoints : chaque *shard* contient une partie des lignes/documents, et l’ensemble des *shards* reconstitue la base complète.
	- Contrairement à la *réplication* (qui copie les mêmes données sur plusieurs nœuds pour la lecture et la disponibilité), le *sharding* répartit des données différentes sur plusieurs nœuds pour augmenter la capacité de stockage et le débit en écriture.
- **Change Streams** 
	- Mécanisme de capture des modifications propre aux systèmes de stockage par documents (comme *MongoDB*) , et équivalent au mécanisme *CDC* (*Change Data Capture*) des systèmes OLTP (comme *PostgreSQL*).
- **TTL** = _Time To Live_ (durée de vie)
	- L'*index TTL* indique au système *MongoDB* qu'il doit supprimer automatiquement ce document une fois qu'un délai donné s'est écoulé depuis une date de référence qu'il porte.
	- Un processus d'arrière-plan interne vérifie périodiquement les documents et purge ceux dont le délai est dépassé.

## MLOps
- *Training-Serving Skew* = biais entraînement-production.
	- Ecart de performance *systématique* entre les performances du modèle à l'entrainement (modèle entrainé / validé avec les données d'entrainement et de test) et ses performances en production.
	- C'est une anomalie du pipeline (un _bug_) et non un _drift_ progressif du modèle.