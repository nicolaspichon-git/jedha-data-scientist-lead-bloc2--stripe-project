---
version: v36
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-1
  - stripe-project/deliverables
  - stripe-project/deliverables/D2
  - stripe-project/oltp
  - stripe-project/oltp/diagrams
---
*STRIPE* PROJECT
===

# 1. OLTP Data System
## D2. OLTP Entity-Relation Diagrams

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / D2 : OLTP ERD / v36 --- 2026/11/05.*   
---

- [[#D2.1. Contexte|D2.1. Contexte]]
- [[#D2.2. Vues globales|D2.2. Vues globales]]
    - [[#D2.2.1. Groupes fonctionnels et dépendances|D2.2.1. Groupes fonctionnels et dépendances]]
    - [[#D2.2.2. Groupes et tables|D2.2.2. Groupes et tables]]
- [[#D2.3. Vues _Références_|D2.3. Vues _Références_]]
- [[#D2.4. Vue _Marchands_|D2.4. Vue _Marchands_]]
- [[#D2.5. Vue _Clients_|D2.5. Vue _Clients_]]
- [[#D2.6. Vue _Transactions_|D2.6. Vue _Transactions_]]
- [[#D2.7. Vue _Sécurité & Conformité_|D2.7. Vue _Sécurité & Conformité_]]
- [[#Références|Références]]

### D2.1. Contexte

Ce document présente les diagrammes dits *ERD* (*Entity-Relation Diagram*) du modèle de données *OLTP*. Il s'agit de représenter les entités et les relations du modèle _logique_. Les éléments de construction du modèle _conceptuel_ sont données en annexe A \[D2-A\]. La définition de référence du modèle _physique_, avec typages précis, contraintes et indexations, est donnée en annexe B \[D2-B\]. Les détails de conception (justification, etc.) sont donnés en annexe C \[D2-C\]. Une stratégie de réplication et de recouvrement est proposée en annexe D \[D2-D\] pour répondre à l'exigence BR1 \[D0, §0.2.4\].

Le modèle *logique* est scindé en différentes vues pour permettre une meilleure lisibilité : 
- les vues globales regroupent les entités par fonctions et par dépendances,
- une vue du modèle centré sur les entités de référence partagées (référentiel géographique, monétaire, etc.).
- une vue du modèle centré sur les entités *Clients*,
- une vue du modèle centré sur les entités *Marchands*,
- une vue du modèle centré sur les entités *Transactions*,
- une vue du modèle centré sur les entités dédiées à la sécurité et à la conformité réglementaire,

###### Points particuliers du modèle
Le modèle transactionnel est conçu en priorité pour permettre une écriture rapide des transactions. La journalisation des lectures et des écritures est conçue pour ne pas ralentir le chemin critique du paiement (cf. \[D1\] - sujet d'intégration OLTP/NoSQL et OLTP/CDC). La même contrainte est appliquée sur le scoring de fraude  (cf. \[D1\] - sujet d'intégration OLTP/Scoring).

Les autres fonctionnalités prises en compte n'interfèrent pas directement avec la procédure de paiement : 
- gestion des alertes de sécurité, 
- gestion des demandes de modification et des consentements,
- gestion des revue de fraude, 
- gestion des abonnements, 
- gestion des catalogue des marchands,
- gestion des plans de tarification des marchands,
- gestion des remboursements, litiges et rétro-facturations.
###### Limites du modèle
Le domaine fonctionnel du modèle de données est limité à la première phase du traitement des transactions financières (cf. \[D0, §0.4\]). La gestion des transactions avec les banques, des dépôts et des reversements aux marchands, ainsi que la plupart des produits et des services adjacents proposés par *Stripe*, sont hors du périmètre du modèle.

Le modèle ne partitionne aucune table et ne prévoit pas de mise en cache. Ces choix, ainsi que la préparation d’un éventuel sharding par marchand, sont justifiés en \[D2-C, §1.C.4\]. Les stratégies d'indexation sont définies dans le modèle physique \[D2-B\].

<div style="page-break-after: always;"></div>

### D2.2. Vues globales

#### D2.2.1. Groupes fonctionnels et dépendances
Cette vue regroupe les entités du modèle par fonctions et par dépendances :

- *Références* : 
	- tables autonomes d'énumération référencées par tous les autres groupes ;
- *Marchands* : 
	- enregistrement des marchands et des tables dépendantes (produits, etc.),
	- ne dépend d'aucun autre groupe que celui des références ;
- *Clients* : 
	- enregistrement des clients et des tables dépendantes (abonnement, etc.) ;
	- s'appuie sur le groupe des marchands ;
- *Transactions* : 
	- enregistrement des transactions et des tables dépendantes (remboursement, fraudes, etc.) ;
	- s'appuie à la fois sur le groupe des marchands et celui des clients ;
- *Sécurité & Conformité* : 
	- journaux et enregistrements diverses répondant aux exigences de sécurité (incidents, etc.) et de conformité réglementaire (consentement, demande de modification, etc.) ;
	- dépend des clients et des marchands (mais pas des transactions) ;

Noter que les vues suivantes reprennent les codes couleurs représentés ci-dessous.

![[stripe-project--d2-oltp-views--groups.svg|700]]

> *Légende : Une flèche du groupe A vers le groupe B signifie que _des tables de A référencent ou utilisent des tables de B_.*

Noter que les vues des sections suivantes reprennent les codes couleurs représentés ci-dessus.

#### D2.2.2. Groupes et tables

Cette vue reprend les groupes fonctionnels précédents en détaillant les tables qu'ils contiennent. 
Les tables sont estampillées en fonction de leur nature, de leurs dépendances, et des contraintes d'écriture imposées (cf. Règles de gestion dans \[D2-A\]). 

Les tables et leurs dépendances sont détaillées dans les vues suivantes.

![[stripe-project--d2-oltp-views--groups-and-tables.svg]]

> _Etiquettes de table : _
> - ★ : Entité métier principale ;
> - ⊞ : Entité métier secondaire (extension directe ou indirecte d'une entité principale) ;
> - ☷ : Enumération ;
> - ▤ : Journal ;
> - 🔒︎︎︎ : Entité immuable (ne peut être ni modifiée ni supprimée après création) ;
> - ✖ : ne peut pas être journalisé (dans les journaux des accès et des écritures)  ;

###### Points particuliers
- *Pas de partitionnement :* les tables `Transaction`, `DataAccessLog`, `ChangeAuditLog` et `FraudScoringLog` restent des tables ordinaires, à clé primaire *simple*. Les tables dépendantes de  `Transaction` ne portent aucune colonne de partition et leurs clés étrangères sont définies par `transaction_id` seul.

---

<div style="page-break-after: always;"></div>

### D2.3. Vues *Références*

Les tables de listes de référence partagées sont les suivantes (code couleur🔘) forment deux sous-groupes  :
- listes de référence pour le coeur de métier : `Country`, `Currency` ;
- catégories d'auditables pour la sécurité et la conformité : `AuditActorType`, `AuditAction` ;
	- Types des acteurs auditables : 
		- user,
		- system,
		- service,
		- merchant\_api ;
	- Types des actions auditables :
		- Actions de lecture : read, export, login,
		- Actions d'écriture : create, update, delete, grant, revoke ;

Remarque : la plupart des listes de référence du modèle restent dans leur groupe d'utilisation tant qu'elles ne sont pas partagées par d'autres groupes (ex: *Regulation*, *Card Network*, etc.). Exceptionnellement, la table`AuditAction` suit l'autre table d'audit, `AuditActorType`, dans le groupe des références alors qu'elle n'est utilisée que par les tables de journalisation du groupe *Sécurité & Conformité*.

###### Coeur de métier

![[stripe-project--d2-oltp-views--references-1.svg|650]]

<div style="page-break-after: always;"></div>

###### Catégories d'auditables

![[stripe-project--d2-oltp-views--references-2.svg]]

---

<div style="page-break-after: always;"></div>

### D2.4. Vue *Marchands*
Les tables de l'écosystème *marchand* sont les suivantes (code couleur🔵)  :

![[stripe-project--d2-oltp-views--merchants.svg]]


---

<div style="page-break-after: always;"></div>

### D2.5. Vue *Clients*
Les tables de l'écosystème *client* sont les suivantes (code couleur🟢)  :


![[stripe-project--d2-oltp-views--customers.svg]]

---

<div style="page-break-after: always;"></div>

### D2.6. Vue *Transactions*

Les tables de l'écosystème des *transactions* sont les suivantes (code couleur🔴)  :

![[stripe-project--d2-oltp-views--transactions.svg]]

Remarque #1 : le délai de réponse du marchand (`response_deadline_days`) est spécifique au réseau de cartes et non au code de justification du litige (`ChargebackReasonCode`). Dans le cadre d'une normalisation stricte, il aurait fallu découpler le réseau de cartes lui même (ex: `CardNetworkPolicy`) du le code de justification, de la même manière que l'on a sorti `Regulation`de `DataSubjectRequest`.

Remarque #2 : la date limite de réponse du marchand (`due_at`) devrait être précalculée pour `Chargeback`, comme elle l'est pour `DataSubjectRequest` : `due_at = created_at + response_deadline_days`.

---

<div style="page-break-after: always;"></div>

### D2.7. Vue *Sécurité & Conformité*

Les tables dédiées aux questions de *sécurité* et de *conformité* sont les suivantes (codes couleurs 🟣, 🟡 et 🟠) :

Les tables dédiées aux questions de *sécurité* et de *conformité* forment les sous-groupes suivants : 
- Journalisation des accès et des écritures (🟣) 
	- \> concerne à la fois la sécurité et la conformité réglementaire ;
- Conformité et droits des utilisateurs (🟡) 
	- \> demandes de modification ou de suppression, consentements ;
- Incidents de sécurité (🟠)
	- \> incidents de sécurité.

###### Journalisation des accès et écritures

![[stripe-project--d2-oltp-views--security-and-regulation-1.svg|650]]

<div style="page-break-after: always;"></div>

###### Conformité et droits des utilisateurs

![[stripe-project--d2-oltp-views--security-and-regulation-2.svg|650]]

###### Incidents de sécurité

![[stripe-project--d2-oltp-views--security-and-regulation-3.svg|650]]

---

<div style="page-break-after: always;"></div>

### Références

#### Spécifications
- \[D0\] [Stripe Project Introduction](stripe-project--d0-introduction.pdf)
#### Livrables
- \[D1\] [Data Architecture](stripe-project--d1-data-architecture.pdf)
#### Annexes
- \[D2-A\] [OLTP Data Conceptual Model](annexes/stripe-project--d2-oltp-annexe-a--mcd.pdf)
- \[D2-B\] [OLTP Data Physical Model](annexes/stripe-project--d2-oltp-annexe-b--dbml.pdf)
- \[D2-C\] [OLTP Design Notes](annexes/stripe-project--d2-oltp-annexe-c--design-notes.pdf)
- \[D2-D\] [OLTP Replication, Failover and Disaster Recovery Strategy](annexes/stripe-project--d2-oltp-annexe-d--disaster-recovery-strategy.pdf)
