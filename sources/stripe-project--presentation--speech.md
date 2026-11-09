---
version: v09
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/presentation
---

*STRIPE* PROJECT
===

# Présentation orale — Architecture de données

> **Durée cible : 5 min 00** — débit moyen-lent (≈ 115 mots/minute).
> Texte écrit pour être **dit**, pas lu : phrases complètes, listes annoncées avant d'être développées, aucun fragment à deux-points.
> Les `*[…]*` sont des indications de jeu, à ne pas prononcer. Les `‖` marquent une respiration.

---

## Sommaire

- [Slide 1 : Trois obligations, un principe](#slide-1--trois-obligations-un-principe)
- [Slide 2 : L'architecture d'ensemble](#slide-2--larchitecture-densemble)
- [Slide 3 : Les pipelines](#slide-3--les-pipelines)
- [Slide 4 : L'intégration du machine learning](#slide-4--lintégration-du-machine-learning)
- [Slide 5 : Robustesse et conformité](#slide-5--robustesse-et-conformité)
- [Repères de minutage](#repères-de-minutage)
- [Ce qui a changé](#ce-qui-a-changé)
- [Questions probables](#questions-probables)

---

## Slide 1 : Trois obligations, un principe

Stripe traite des paiements. Derrière chaque paiement, le système a trois obligations de métier :

[un temps]

- Opérer, pour enregistrer une transaction, immédiatement et sans perte.
- Décider, pour autoriser ou bloquer la transaction, en moins de cent millisecondes. 
- Et rendre compte, pour répondre à l'analyste et au régulateur, en quelques minutes ou quelques heures, et aussi, démontrer que les règlementations sont respectées.

Chaque obligation a un délai d'exécution propre, de quelques millisecondes à quelques heures. 
Mais elles ne sont pas indépendantes, car elles sont tenues par un fil directeur commun, à savoir : 

- Prioriser le chemin de paiement en empêchant les observateurs de le ralentir.

---

## Slide 2 : L'architecture d'ensemble

[2s]

Ce diagramme présente l'architecture complète et ses flux.

Les données sources arrivent par la couche applicative (en haut au centre).
Elle écrit les données de vérité transactionnelle dans l'OLTP. 
Dans le cas d'un paiement, elle établit un dialogue *synchrone* avec le service de scoring de fraude. 
Celui-ci lui répond en moins de 100 ms après avoir lu ses features en moins de 10 ms, le magasin de features *online* étant hébergé par la base NoSQL.

Le bus d'évènements *Kafka* est la pièce centrale du système. 
La couche applicative y publie ses évènements et ses informations non transactionnelles. 
La base OLTP y publie ses changements via la lecture asynchrone du journal des écritures. 
Toutes les publications entrent dans le bus de manière asynchrone.

Le bus d’évènements alimente plusieurs destinations :
- La base NoSQL *MongoDB*, pour les documents applicatifs non structurés et les features online, 
- La base *Snowflake* pour l'analytique OLAP, 
- Le notificateur d’alertes de sécurité en temps réel,
- Et, pour finir, un renvoi des logs, des incidents et des scores vers l'OLTP.

---

## Slide 3 : Les pipelines

Les pipelines sont structurés pour tenir simultanément trois régimes de temps différents : 

- Le premier régime est le *temps réel strict*, avec des lectures de 10 ms servies par le magasin NoSQL *MongoDB* ;
- Le second régime est le *flux continu* de propagation des changements, en quelques secondes, via *Kafka* et les jobs *Flink* et *Debezium* ;
- Et le troisième est celui des batchs planifiés, orchestrés par *Airflow*, qui déclenche *dbt* pour reconstruire les modèles analytiques.

C'est ce découplage qui fait la robustesse du système. 
Par exemple, quand *Snowflake* tombe, la chaîne des paiements n’est pas interrompue.

En contrepartie, l’architecture assume une cohérence *à terme* entre les systèmes (hors du chemin transactionnel, qui reste forcément fortement cohérent). 

---

## Slide 4 : L'intégration du machine learning

L’intégration du machine learning est la 3e application du principe directeur (de priorisation du paiement) :
- ni l'entraînement, ni le monitoring, ni le déploiement d'un nouveau modèle ne ralentissent le paiement.

Le registre des datasets est au centre des flux de données : 
- il s’alimente des features, des labels et des logs de production et produit les inputs d'entraînement, d’évaluation et de monitoring.

Le point clé du cycle d’intégration est sa *fermeture* 
	- la production produit les logs, les logs alimentent le monitoring, le monitoring détecte les dérives et déclenche le réentraînement, le modèle réentraîné challenge contre le modèle courant avant d'être éventuellement déployé.

Avec ce système, le modèle prédictif est un actif versionné, surveillé, et remplaçable.

---

## Slide 5 : Robustesse et conformité

Je termine par l’intégration de la conformité réglementaire. 

C’est une contrainte de conception forte qui traverse toutes les couches de l’architecture, allant souvent jusqu’à conditionner complètement un modèle de données ou un pipeline.

Typiquement, conformément à la norme PCI-DSS, le numéro de carte bancaire ne rentre jamais dans le système en entier \[le système reste ainsi pour rester hors du périmètre des audits CDE \[Cardholder Data Environment\]\].

En ce qui concerne le RGPD, les consentements des utilisateurs sont enregistrés en mode *append-only* (et cela signifie que l’on n'efface rien, même lorsqu’un client se rétracte),
On sait également que le droit à l'effacement crée un conflit avec l'*immuabilité* des journaux d'audit, et ce conflit est traité explicitement dans le dossier.

Et aussi, le fait d’horodater un incident de sécurité *dès sa détection* donne la base pour déclencher le délai de soixante-douze heures du RGPD.

[Fin]

Voilà. On a présenté une architecture de données complète, guidée par un principe de priorisation de la chaîne de paiement, et structurée transversalement par le respect des contraintes réglementaires.

---

## Repères de minutage

| Slide | Contenu | Mots | Débit seul | Cumul visé *(pauses comprises)* |
| ----- | ------- | ---- | ---------- | ------------------------------- |
| 1 | Trois obligations, un principe | 104 | 54 s | **1:00** |
| 2 | L'architecture d'ensemble | 119 | 62 s | **2:05** |
| 3 | Les pipelines | 98 | 51 s | **3:00** |
| 4 | L'intégration ML | 104 | 54 s | **4:00** |
| 5 | Robustesse et conformité | 137 | 71 s | **5:10** |
| | **Total** | **562** | **4:53** | |

Le texte seul fait 4 min 53 à 115 mots/minute. Les 18 secondes restantes sont les deux temps d'arrêt marqués et les quatre changements de slide, ce qui porte l'ensemble à **5 min 11**. **Ne pas combler ces silences** — c'est la marge qui tient le minutage.

> Le budget de pauses est une estimation ; à ±10 secondes près, seul un chronométrage à voix haute tranchera. Si tu dépasses, la liste ci-dessous donne l'ordre des coupes.

### Si tu débordes malgré tout

| # | Coupe | Gain | Effet |
| - | ----- | ---- | ----- |
| 1 | Slide 5 — *« C'est cette décision qui sort la quasi-totalité du système du périmètre d'audit. »* | ~7 s | Faible, mais c'est la meilleure phrase de la diapositive |
| 3 | Slide 4 — *« Au centre, vous voyez un registre de datasets. »* → *« Au centre, le registre de datasets. »* | ~3 s | Nul |

### Si tu as de l'avance

Rajoute sur le slide 5, après la phrase sur le RGPD : *« Chaque demande d'exercice de droit porte son délai légal — trente ou quarante-cinq jours selon le cadre. »* (+8 s)

---

## Ce qui a changé

### v09 : mes modifications
[...juste des reformulations...]

### v08 : le slide 4 nomme le principe
- **« Le machine learning suit exactement la même logique » ne disait pas laquelle.** La phrase obligeait l'auditeur à reconstruire l'antécédent pendant qu'on enchaîne. Elle devient : *« Le machine learning obéit au même principe. Ni l'entraînement, ni le monitoring, ni même l'essai d'un nouveau modèle ne ralentissent le paiement. »* Le slide 4 est ainsi la troisième instance du principe du slide 1, après les slides 2 et 3 — et la boucle se referme.
- **Compensation.** Le slide 2 perd *« Autrement dit, la base ignore qu'elle est observée »*, qui reformulait la phrase précédente sans rien ajouter, et qui faisait désormais doublon avec la nouvelle phrase du slide 4.

### v05-v07 : alignement sur le diaporama corrigé, et liaisons parlées

- **Toute la ponctuation purement écrite a disparu du texte dit.** Plus aucun deux-points, aucun point-virgule, aucun tiret explicatif : ce sont des signes typographiques, qui ne s'entendent pas. Chacun a été remplacé par la liaison que la voix produirait de toute façon — *« et c'est », « et le voici », « d'un côté… de l'autre », « puisque », « qui », « mais »* — ou par un point franc quand deux phrases valaient mieux qu'une.
- Les seuls tirets restants sont dans les indications de jeu, qui ne se prononcent pas.

- **« Trois métiers » est devenu « trois obligations ».** Un métier est un domaine d'activité ; opérer, décider et rendre compte sont des verbes, et chacun décrit ce que le système s'engage à faire dans un délai donné. Le mot « métier » affaiblissait l'argument : si ce sont trois domaines, un juré peut répondre *« une seule base peut servir trois domaines »* ; si ce sont trois obligations à budgets de temps incompatibles, les trois moteurs deviennent une conséquence.
- **« Prouver » est devenu « rendre compte ».** « Prouver » ne couvrait que le régulateur et laissait l'analytique dehors — revenus, segmentation, performance produit, soit tout D3 et la moitié de D8.2. D5 §D5.2 range pourtant les deux ensemble sous *« sorties analytiques a posteriori »*.
- **Le délai est devenu l'axe de l'ouverture** : immédiat, cent millisecondes, quelques minutes à quelques heures. C'est ce qui amène la diapositive 3 et le principe directeur.

### v02 : passage au texte lu

- **Tout le texte est passé en phrases dites.** Plus aucun fragment à deux-points : *« Opérer : enregistrer la transaction »* est devenu *« Opérer, c'est enregistrer la transaction »*. Les listes sont **annoncées puis développées** — on annonce d'abord les trois, et seulement ensuite ce que chacun recouvre.
- **Les énumérations sont articulées** par *le premier / le deuxième / et le troisième*, et les transitions par *venons-en à*, *prenons*, *reste*, *autrement dit*, *donc*.
- **Les nombres se disent en lettres** : *cent millisecondes*, *soixante-douze heures*.
- **Les sigles sont explicités à la première occurrence** : *« son journal d'écriture, ce qu'on appelle le Change Data Capture »*.
- **Slide 3 — la phrase de cohérence est corrigée** : *« une cohérence à terme entre les systèmes — jamais sur le chemin transactionnel »*. Sans ces derniers mots, la question qui suit est *« donc un paiement peut se perdre ? »*.
- **Deux passages ont été retirés pour tenir les cinq minutes** : sur le slide 2, le reporting réglementaire qui part directement du transactionnel ; sur le slide 5, le contrôle d'accès ligne par ligne et la journalisation des lectures. Les deux sont sur les diapositives, et les deux ont leur écran dans le deck des questions probables (Q5 et Q6). Les dire serait redondant ; les avoir en réserve ne l'est pas.

---

## Questions probables

Traitées en détail dans `stripe-project--presentation--questions-probables.pptx`.

| Question | Écran | Appui |
| -------- | ----- | ----- |
| Les cinq couches du pipeline ? | 3 | D5 §D5.2 — cinq stratifiées, plus une transverse |
| Pourquoi trois bases et pas une ? | 4 | Trois régimes de temps incompatibles |
| Comment garantissez-vous la cohérence ? | 5–6 | D5 §D5.7.2, puis la réconciliation quotidienne §D5.8 |
| Et si Kafka tombe ? | 7 | Le paiement reste servi ; rattrapage par rejeu |
| Pourquoi le reporting réglementaire hors OLAP ? | 8 | Valeur probante et délai opposable, D1 §D1.7 |
| Le droit à l'effacement sur des journaux immuables ? | 9 | Conserver les faits, effacer l'identité, D5 §D5.9.3 |
| Le scoring est-il réentraîné automatiquement ? | 10 | Domaine adversarial et label différé, D7 §D7.3.9 |
| Quelle volumétrie ? | 11 | **Limite déclarée**, D0 §0.4.3 |

---

### Références

- \[D0\] Stripe Project Introduction
- \[D1\] Data Architecture Diagrams
- \[D5\] Data Pipeline Architecture
- \[D6\] Security and Compliance Plan
- \[D7\] Machine Learning Integration Strategy
