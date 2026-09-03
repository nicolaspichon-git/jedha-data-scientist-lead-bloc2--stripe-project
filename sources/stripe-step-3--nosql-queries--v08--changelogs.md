*STRIPE* PROJECT
===

# 3. NoSQL Data System
## D8.3. NoSQL Queries Examples

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D8.3 : NoSQL Queries - Changelogs / 2026/10/13.*

---

### Changelogs

#### Changelog v01 → v02

> **Note de version (v02)** - Conversion de l'ensemble des requêtes de la syntaxe shell  
> MongoDB (JavaScript) vers Python (`pymongo`), pour rester cohérent avec un seul langage sur  
> tout le document plutôt que de mélanger les styles. Explication de l'objet `db` intégrée  
> une seule fois en tête de document plutôt que répétée à chaque requête.

#### Changelog v02 → v03

> **Note de version (v03)** - Réduit à deux requêtes par collection, les plus représentatives  
> de son motif d'accès dominant (D4.4) et du mécanisme d'index le plus distinctif de chacune  
> (D4.6) - composé temporel, sparse, multikey, texte, projection. Les requêtes retirées  
> (agrégations secondaires, contrôles de fraîcheur, recherches redondantes avec un mécanisme  
> déjà illustré ailleurs) restent valides dans la v02 précédente. Restructuration du document  
> sous la référence D8.3, avec numérotation `D8.3.X.Y` par collection.

#### Changelog v03 → v04

> **Note de version (v04)** - Trois corrections suite à revue croisée avec D4 et l'Annexe A :  
> ajout d'une section "Couverture des exigences" (BR3/TR1 uniquement, cohérent avec le  
> principe que les références D/T ne sont pas des exigences), mise à jour de la référence à  
> D4 (`v05` → `v08`), suppression d'une puce vide résiduelle dans la liste des ressources.

#### Changelog v04 → v08

**Note de version (v08)** - Alignement sur la version de livraison du package "step 3".
