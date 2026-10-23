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

### D2.1. Contexte

Ce document présente les diagrammes dits *ERD* (*Entity-Relation Diagram*) du modèle de données *OLTP*. Il s'agit de représenter les entités et les relations du modèle _logique_. Les éléments de construction du modèle _conceptuel_ sont données en annexe A \[D2-A\]. La définition de référence du modèle _physique_, avec typages précis, contraintes et indexations, est donnée en annexe B \[D2-B\]. Les détails de conception (justification, etc.) sont donnés en annexe C \[D2-C\].

Le modèle *logique* est scindé en différentes vues pour permettre une meilleure lisibilité : 
- les vues globales regroupent les entités par fonctions et par dépendances,
- une vue du modèle centré sur les entités de référence partagées (référentiel géographique, monétaire, etc.).
- une vue du modèle centré sur les entités *Clients*,
- une vue du modèle centré sur les entités *Marchands*,
- une vue du modèle centré sur les entités *Transactions*,
- une vue du modèle centré sur les entités dédiées à la sécurité et à la conformité réglementaire,

###### Limites du modèle
On rappelle que le domaine fonctionnel du modèle de données est limité à la première phase du traitement des transactions financières (cf. \[D0\]). La gestion des transactions avec les banques, des dépôts et des reversements aux marchands, ainsi que la plupart des produits et des services adjacents proposés par *Stripe*, sont hors du périmètre du modèle.

---

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

![[diagrams/stripe-step-1--oltp-views--groups.svg]]

> *Légende : Une flèche du groupe A vers le groupe B signifie que _des tables de A référencent ou utilisent des tables de B_.*

Noter que les vues des sections suivantes reprennent les codes couleurs représentés ci-dessus.

###### Points particulier du modèle
[TODO]

<div style="page-break-after: always;"></div>

#### D2.2.2. Groupes et tables

Cette vue reprend les groupes fonctionnels précédents en détaillant les tables qu'ils contiennent. 
Les tables sont estampillées en fonction de leur nature, de leurs dépendances, et des contraintes d'écriture imposées (cf. Règles de gestion dans \[D2-A\]). 

Les tables et leurs dépendances sont détaillées dans les vues suivantes.

![[diagrams/stripe-step-1--oltp-views--groups-and-tables.svg]]

> _Etiquettes de classe : _
> - ★ : Entité métier principale ;
> - ⊞ : Entité métier secondaire (extension directe ou indirecte d'une entité principale) ;
> - ☷ : Enumération ;
> - ▤ : Journal ;
> - 🔒︎︎︎ : Entité immuable (ne peut être ni modifiée ni supprimée après création) ;
> - ✖ : ne peut pas être journalisé (dans les journaux des accès et des écritures)  ;

---

<div style="page-break-after: always;"></div>

### D2.3. Vues *Références*

Les tables de listes de référence partagées sont les suivantes (code couleur🔘) forment deux sous-groupes  :
- listes de référence pour le coeur de métier : `Country`, `Currency` ;
- catégories d'auditables pour la sécurité et la conformité : `AuditActorType`, `AuditAction' ;
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

![[diagrams/stripe-step-1--oltp-views--references-1.svg|650]]

<div style="page-break-after: always;"></div>

###### Catégories d'auditables

![[diagrams/stripe-step-1--oltp-views--references-2.svg]]

---

<div style="page-break-after: always;"></div>

###  D2.4. Vue *Marchands*
Les tables de l'écosystème *marchand* sont les suivantes (code couleur🔵)  :

![[diagrams/stripe-step-1--oltp-views--merchants.svg]]


---

<div style="page-break-after: always;"></div>

### D2.3. Vue *Clients*
Les tables de l'écosystème *client* sont les suivantes (code couleur🟢)  :


![[diagrams/stripe-step-1--oltp-views--customers.svg]]

---

<div style="page-break-after: always;"></div>

###  D2.5. Vue *Transactions*

Les tables de l'écosystème des *transactions* sont les suivantes (code couleur🔴)  :

![[diagrams/stripe-step-1--oltp-views--transactions.svg]]

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

![[diagrams/stripe-step-1--oltp-views--security-and-regulation-1.svg|650]]

<div style="page-break-after: always;"></div>

###### Conformité et droits des utilisateurs

![[diagrams/stripe-step-1--oltp-views--security-and-regulation-2.svg|650]]

###### Incidents de sécurité

![[diagrams/stripe-step-1--oltp-views--security-and-regulation-3.svg|650]]

---

<div style="page-break-after: always;"></div>

### Couverture des exigences [TODO : A REVOIR]

| #       | Exigence                                                       | Couverture     | Source                                                                                        |
| ------- | -------------------------------------------------------------- | -------------- | --------------------------------------------------------------------------------------------- |
| BR1     | OLTP = grands volumes de transactions + latence minimale       | 🟢             | Indexation `Transaction` (\[D2-B\]), découplage des entités dépendantes (\[D2-B\])            |
| BR1     | OLTP = ACID + distributed environment + sync. temps réel       | --             | --                                                                                            |
| BR1     | OLTP Disaster recovery                                         | 🟢             | Disaster Recovery/Replication/Failover (\[D2-D\])                                             |
| BR2     | analyse de revenu                                              | 🟢             | `PricingPlan`/`PricingPlanFee`/`Transaction.fee_amount` (§1.C.2)                              |
| BR4     | flux cohérent OLTP ↔ OLAP ↔ NoSQL                              | 🟢 (part OLTP) | *CDC* via `ChangeAuditLog` ; écriture asynchrone hors du chemin d'exécution critique          |
| BR5/TR5 | chiffrement, accès, audit, RGPD/PCI-DSS                        | 🟢             | audit & RGPD/PCI-DSS --> Tables conformité (§1.C.3)                                           |
| TR1     | schéma normalisé, intégrité, performance                       | 🟢             | 3NF, tables de référence porteuses de logique métier, index ciblés                            |
| TR3     | scalabilité horizontale, indexation, partitionnement, sharding | 🟢             | Index existants ; ~~stratégie de partitionnement~~ ; stratégie de sharding formalisée au §1.D |
| TR4     | cohérence et synchronisation (CDC)                             | 🟢             | `ChangeAuditLog`, réplication logique (cf. §1.D)                                              |

###### Couverture du  modèle
Le choix précis de l'outillage *managé* (*RDS Multi-AZ*, *Cloud SQL*, *Aurora*...) est hors périmètre. C'est une décision d'infrastructure/déploiement.

---

### Références

[TODO : remplacer référence R0 par D0 (et mettre R0 dans D0)]
#### Ressources
- \[R0\] [Stripe Business Case](resources/stripe-project--business-case.pdf) 

#### Annexes
- \[D2-A\] [OLTP Data Conceptual Model](annexes/stripe-step-1--oltp-annexe-a--mcd.pdf)
- \[D2-B\] [OLTP Data Physical Model](annexes/stripe-step-1--oltp-annexe-b--dbml.dbml)
- \[D2-C\] [OLTP Design Notes](annexes/stripe-step-1--oltp-annexe-c--design-notes.pdf)
- \[D2-D\] [OLTP Disaster Recovery Strategy](annexes/stripe-step-1--oltp-annexe-d--disaster-recovery-strategy.pdf)