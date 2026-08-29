*STRIPE* PROJECT
===

# 8. Architecture Globale
## D1. Diagramme détaillé d'architecture

### D1.X. Changelogs

#### Changelog v01 > v02

> **Note de version (v02)** - Deux mises à jour. (1) Bloc OLAP actualisé suite à la
> conception Kimball (2.A) et au DBML v07 (Annexe 2.B) : ajout de `FactSecurityIncident`
> (absent du v06) et renommage de `FactComplianceRequest` en `FactDataSubjectRequest`. (2)
> Scission du bloc conformité OLTP : `DataAccessLog` reste seule sur le bus applicatif
> (justification originale de l'Annexe 1.C, propre à cette table) ; `ChangeAuditLog`,
> `ConsentRecord`, `DataSubjectRequest` et `SecurityIncident` rejoignent désormais le flux CDC
> comme `OLTP_CORE`, puisque ce sont des tables normalement écrites par l'application, sans la
> contrainte spécifique du `SELECT` sans trace WAL qui justifiait le bus applicatif.

---
