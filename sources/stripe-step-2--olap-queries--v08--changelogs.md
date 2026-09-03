*STRIPE* PROJECT
===

# 2. OLAP Data System
## D8.2. OLAP SQL Queries Examples

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D8.2 : OLAP Queries - Changelogs - 2026/10/13.*

---

### Changelogs

#### Changelog v07

> **Note de version (v07)** - Première version du document. Dix-huit requêtes SQL, trois par processus métier identifié en 2.A.2 (P1 à P6), sur le schéma physique OLAP (Annexe 2.B, alors en v07 - d'où le choix d'aligner directement le numéro de version du document sur celui du DBML dont il dépend, plutôt que de repartir d'une v01). Objectif : vérifier que chaque processus métier de la conception Kimball est réellement exploitable tel que modélisé, sans jointure vers l'OLTP.

#### Changelog v07 → v08

> **Note de version (v08)** - Réduit à deux requêtes par processus, les plus représentatives de sa raison d'être (2.A.2) et du mécanisme le plus distinctif de chacune. Trois motifs redondants sur l'ensemble du document ont guidé les retraits : le pattern table d'agrégat (démontré dans trois processus sur six - P1, P3, P4 - conservé nulle part au final, D3.4 suffit à en documenter le principe une seule fois) ; le pattern "éléments en attente proches d'une échéance" (démontré à la fois pour les demandes de droit et pour les incidents - conservé uniquement côté P5, où le calcul de date est le plus riche) ; la ventilation géographique secondaire (P2.3, retirée - le motif "croiser avec une dimension supplémentaire" est déjà démontré par P1.2 et P3.2). Les six requêtes retirées restent valides et disponibles dans la v07 précédente.