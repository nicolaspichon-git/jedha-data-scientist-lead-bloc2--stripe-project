*STRIPE* PROJECT
===

# 1. OLTP Data System
## D8.1. OLTP SQL Queries Examples

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D8.1 : OLTP Queries - Changelogs - 2026/10/13.*

---

### Changelogs

#### Changelog v25

> **Note de version (v25)** - Première version du document. Trois jeux de requêtes SQL, alignés sur les trois exemples cités explicitement au cahier des charges (D8) : analyse de revenu, détection de fraude, segmentation client. Douze requêtes au total (quatre par jeu), sur le modèle physique OLTP (Annexe 1.B, alors en v25 - d'où l'alignement direct du numéro de version plutôt qu'un départ en v01). Volet NoSQL explicitement renvoyé à un document séparé, non traité ici. Note sur les index sollicités (D8.5) ajoutée en clôture.

#### Changelog v25 → v26

> **Note de version (v26)** - Ajout d'une colonne `currency` à droite de chaque colonne de montant agrégé (D8.2.1, D8.2.2, D8.2.3, D8.4.1, D8.4.3, D8.4.4). Ce n'est pas qu'un ajout cosmétique : `Transaction.amount` n'est jamais converti côté OLTP (contrairement à l'OLAP, qui applique un taux de référence figé) - sommer sans grouper par devise aurait mélangé des montants incomparables dès qu'un marchand ou un client traite en plusieurs devises. Le `GROUP BY` de chacune de ces requêtes a donc été corrigé en même temps que la colonne ajoutée, pas seulement la colonne d'affichage. D8.2.4, D8.3.1 à D8.3.4 et D8.4.2 ne comportent aucune colonne de montant agrégé et restent inchangées (D8.3.1 affiche déjà `currency_code` au niveau ligne, sans agrégation). Une incohérence relevée en cours de route sur D8.4.4 (répartition géographique) : la requête calculait un revenu total alors que sa description n'annonçait qu'une segmentation par pays - assumée et laissée telle quelle, la description sous-vendant simplement ce que la requête fait réellement.

#### Changelog v26 → v27

> **Note de version (v27)** - Réduit à deux requêtes par domaine, les plus représentatives et les plus diverses en technique démontrée. Renommage du document en D8.1 pour le distinguer explicitement de D8.2 (OLAP) et D8.3 (NoSQL), qui portaient jusqu'ici la même numérotation de base "D8" sans indice de système. **Revenu** : gardé l'analyse marchand (canonique) et l'analyse produit (seul axe non-marchand du jeu) - retiré l'impact remboursements/litiges (raffinement du même axe) et le contrôle de cohérence `fee_amount` (un contrôle d'audit, pas une question de revenu). **Fraude** : gardé l'alerting direct et la validation _a posteriori_ du modèle - ce choix plutôt que la détection de rafales crée une symétrie volontaire avec le livrable OLAP équivalent (2.A.9, P2), qui retient exactement la même paire de besoins (alerting immédiat / validation du modèle) ; ce n'était pas le seul choix défendable, assumé explicitement comme tel. **Segmentation** : gardé le RFM (technique canonique) et la segmentation valeur/moyen de paiement croisée (avec son avertissement sur les seuils multi-devises) - retiré le risque de désabonnement (plus proche de la rétention que de la segmentation) et la répartition géographique (la plus simple, partiellement redondante). Note sur les index (D8.5) intégralement réécrite - elle référençait trois requêtes désormais retirées. Les six requêtes retirées restent valides et disponibles dans la v26 précédente.

#### Changelog v27 → v28

> **Note de version (v28)** - D8.4.2 : la sous-requête imbriquée `seg` réécrite en CTE (`WITH seg AS (...)`) plutôt qu'en sous-requête `FROM (...)`- même style que D8.4.1 (`stats_client`), pour une syntaxe cohérente sur les deux requêtes du jeu segmentation qui en ont besoin.

---