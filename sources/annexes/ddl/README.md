# STRIPE PROJECT — OLTP v36 (Annexe B, DDL, D8.1)

Contenu : voir `CHANGELOG-v36.md` (`Customer.country_code` NOT NULL), `CHANGELOG-v35.md` (`CardNetwork`, `CardNetworkPolicy`), `CHANGELOG-v34.md` (retrait de `decline_code`, ajout de `Chargeback.due_at`), `CHANGELOG-v33.md` (retrait du partitionnement), `CHANGELOG-v32.md` puis `CHANGELOG-v31.md` (modifications, décisions, points ouverts, documents à reporter).

## Fichiers
- `stripe-step-1--oltp-annexe-b--dbml--v36.dbml` — modèle physique v36 (remplace v30 à v35) ; `…--v35-to-v36.diff` — le changement sous forme de patch
- `ddl/01_schema.sql`, `ddl/02_complement.sql`, `ddl/03_reference_data.sql` — DDL exécutable (dans cet ordre)
- `ddl/04_tests.sql`, `ddl/05_sample_data.sql`, `ddl/scripts/` — tests et jeu de données
- `stripe-step-1--oltp-queries--v36.md` — D8.1 corrigé ; `VERIFICATION-D8.1.md` — résultats d'exécution et plans

## Installer et tester (PostgreSQL 16+)
```bash
createdb stripe
for f in 01_schema 02_complement 03_reference_data; do psql -v ON_ERROR_STOP=1 -d stripe -f ddl/$f.sql; done
psql -d stripe -f ddl/04_tests.sql          # 89 tests : colonne « passed » = t ; « complete » = t ; aucune ligne dans la liste des échecs
psql -d stripe -f ddl/05_sample_data.sql    # facultatif : jeu volumétrique (jamais en production)
```
`02_complement.sql` crée des rôles de groupe (`stripe_app`, `stripe_log_writer`, `stripe_readonly`, `stripe_cdc`, `stripe_retention`) et une publication logique : à exécuter avec un rôle de migration, pas avec le rôle applicatif.
Les scripts de `ddl/scripts/` supposent l'instance de test utilisée pour la vérification (`PGHOST`, `PGPORT`, `PGUSER` à adapter) et les bases `stripe_test` / `stripe_perf`.

`diagrams/` — vues SVG régénérées depuis le DBML v36 (voir `diagrams/LISEZMOI.md`).
