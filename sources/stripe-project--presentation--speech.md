---
version: v06
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

Stripe traite des paiements. ‖ Mais derrière chaque paiement, le système a **trois obligations**, et chacune a son délai.

*[un temps — laisser les trois cartes s'installer]*

**Opérer**, c'est enregistrer la transaction — immédiatement, et sans perte. ‖ **Décider**, c'est autoriser ou bloquer — en moins de cent millisecondes. ‖ Et **rendre compte**, c'est répondre à l'analyste comme au régulateur, en quelques minutes ou quelques heures, et démontrer que les règles ont été tenues.

Trois obligations, trois délais. ‖ De cent millisecondes à plusieurs heures : c'est ce qui interdit de tout servir avec un seul moteur. ‖ Mais un seul principe les relie : **le chemin du paiement ne doit jamais être ralenti par ce qui l'observe.**

---

## Slide 2 : L'architecture d'ensemble

*[laisser deux secondes de silence après l'affichage du schéma]*

Voici l'architecture complète. Parcourons-la dans le sens du paiement.

Tout part de la couche applicative, à gauche. Elle écrit dans le système transactionnel — *PostgreSQL* — qui est **la source de vérité**.

‖ Juste en dessous se trouve la pièce maîtresse, **le bus d'évènements**, *Kafka*. Tout ce qui sort du transactionnel passe par lui, et de façon **asynchrone**. Il n'y a aucun déclencheur synchrone sur la base ; on lit simplement son journal d'écriture, ce qu'on appelle le *Change Data Capture*. ‖ Autrement dit, la base ignore qu'elle est observée.

Le bus alimente ensuite deux destinations : *MongoDB*, pour les documents et les features, et *Snowflake*, pour l'analytique.

‖ Reste le service de scoring. Il lit ses features en moins de **dix** millisecondes, et rend sa décision en moins de **cent**.

---

## Slide 3 : Les pipelines

Venons-en aux pipelines. Ils s'organisent en cinq couches, mais ce qui compte, ce sont **les trois régimes de temps**.

Le premier est le **temps réel strict**, dix millisecondes, servies par un cache. ‖ Le deuxième est le **flux continu**, où *Kafka* et *Flink* propagent les changements en quelques secondes. ‖ Et le troisième est le **batch planifié**, où *Airflow* déclenche *dbt* pour reconstruire les modèles analytiques.

‖ C'est ce découpage qui fait la robustesse. Si *Snowflake* tombe, les paiements continuent. **Le couplage est rompu par construction.**

En contrepartie, j'assume une cohérence à terme entre les systèmes — **jamais sur le chemin transactionnel**.

---

## Slide 4 : L'intégration du machine learning

Le machine learning suit exactement la même logique.

Au centre, vous voyez **un registre de datasets**. Tout converge vers lui — les features, les labels, les logs de production — et tout en repart, vers l'entraînement, l'évaluation et le monitoring.

‖ Mais le point clé, c'est **la boucle**. La production produit des logs ; les logs alimentent le monitoring ; le monitoring détecte la dérive et déclenche un réentraînement ; et le nouveau modèle est *challengé* contre l'ancien avant d'être déployé.

Donc le modèle n'est pas un livrable figé, mais **un actif versionné, surveillé, et remplaçable**.

---

## Slide 5 : Robustesse et conformité

Je termine par la conformité. Ce n'est pas une couche qu'on ajoute à la fin, c'est **une contrainte de conception**.

Prenons *PCI-DSS*. Le numéro de carte n'entre jamais dans le système — seuls les quatre derniers chiffres sont conservés. C'est cette décision qui sort la quasi-totalité du système du périmètre d'audit.

‖ Prenons maintenant le *RGPD*. Le consentement fonctionne **en ajout seul**, c'est-à-dire que lorsqu'un client se rétracte, on crée une ligne et on n'efface rien. Et le droit à l'effacement entre en conflit frontal avec l'immuabilité des journaux d'audit ; c'est un conflit que le dossier traite explicitement.

‖ Enfin, un incident de sécurité est horodaté dès sa **détection**, parce que c'est cet horodatage qui déclenche le délai de soixante-douze heures.

*[ralentir, regarder le jury]*

Voilà. Une architecture où **chaque contrainte réglementaire a fini par laisser une trace dans le modèle de données**.

---

## Repères de minutage

| Slide | Contenu | Mots | Débit seul | Cumul visé *(pauses comprises)* |
| ----- | ------- | ---- | ---------- | ------------------------------- |
| 1 | Trois obligations, un principe | 101 | 53 s | **1:00** |
| 2 | L'architecture d'ensemble | 124 | 65 s | **2:10** |
| 3 | Les pipelines | 98 | 51 s | **3:05** |
| 4 | L'intégration ML | 90 | 47 s | **3:55** |
| 5 | Robustesse et conformité | 136 | 71 s | **5:05** |
| | **Total** | **549** | **4:46** | |

Le texte seul fait 4 min 46 à 115 mots/minute. Les 18 secondes restantes sont les deux temps d'arrêt marqués et les quatre changements de slide. **Ne pas combler ces silences** : c'est la marge qui tient le minutage.

### Si tu débordes malgré tout

| # | Coupe | Gain | Effet |
| - | ----- | ---- | ----- |
| 1 | Slide 5 — *« C'est cette décision qui sort la quasi-totalité du système du périmètre d'audit. »* | ~7 s | Faible, mais c'est la meilleure phrase de la diapositive |
| 2 | Slide 2 — *« Autrement dit, la base ignore qu'elle est observée. »* | ~4 s | Faible : l'idée est déjà dite juste avant |
| 3 | Slide 4 — *« Au centre, vous voyez un registre de datasets. »* → *« Au centre, le registre de datasets. »* | ~3 s | Nul |

### Si tu as de l'avance

Rajoute sur le slide 5, après la phrase sur le RGPD : *« Chaque demande d'exercice de droit porte son délai légal — trente ou quarante-cinq jours selon le cadre. »* (+8 s)

---

## Ce qui a changé

### v05 — alignement sur le diaporama corrigé

- **« Trois métiers » est devenu « trois obligations ».** Un métier est un domaine d'activité ; opérer, décider et rendre compte sont des verbes, et chacun décrit ce que le système s'engage à faire dans un délai donné. Le mot « métier » affaiblissait l'argument : si ce sont trois domaines, un juré peut répondre *« une seule base peut servir trois domaines »* ; si ce sont trois obligations à budgets de temps incompatibles, les trois moteurs deviennent une conséquence.
- **« Prouver » est devenu « rendre compte ».** « Prouver » ne couvrait que le régulateur et laissait l'analytique dehors — revenus, segmentation, performance produit, soit tout D3 et la moitié de D8.2. D5 §D5.2 range pourtant les deux ensemble sous *« sorties analytiques a posteriori »*.
- **Le délai est devenu l'axe de l'ouverture** : immédiat, cent millisecondes, quelques minutes à quelques heures. C'est ce qui amène la diapositive 3 et le principe directeur.

### v02 — passage au texte dit

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
