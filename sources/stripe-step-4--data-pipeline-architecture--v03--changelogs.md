*STRIPE* PROJECT
===

# 4. Data Pipeline
## D5. Data Pipeline Architecture

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D5 : Data Pipeline Architecture - Changelogs - 2026/10/13.*   

---

### Changelogs

> **Note de version (v02)** - Correction de `FactComplianceRequest` (obsolète depuis la v07
> de l'OLAP) en `FactDataSubjectRequest` (§D5.8.4). Inversion de l'ordre de présentation du
> magasin de features : MongoDB (`ml_features`) comme technologie retenue - déjà spécifiée en
> détail par D4 §D4.5.4 (schéma, index, sharding) - Feast reste mentionné comme alternative
> théorique non retenue, pas l'inverse (§D5.5.3, §D5.10). Ajout d'un diagramme Mermaid pour
> D5.1, illustrant les cinq couches stratifiées et la couche transverse de conformité.

