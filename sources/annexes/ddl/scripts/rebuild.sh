#!/bin/bash
# Recrée la base de test et charge 01, 02, 03 (arrêt à la première erreur).
set -e
cd "$(dirname "$0")/.."
export PGHOST=/var/tmp/pgtest PGPORT=54329 PGUSER=postgres
DB=${1:-stripe_test}
psql -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
for f in 01_schema.sql 02_complement.sql 03_reference_data.sql; do
  psql -q -v ON_ERROR_STOP=1 -d $DB -f $f > /dev/null 2> /tmp/claude-0/rebuild.err || { cat /tmp/claude-0/rebuild.err; echo "ÉCHEC dans $f"; exit 1; }
  grep -v -e '^HINT' -e 'wal_level' /tmp/claude-0/rebuild.err || true
done
echo "schéma chargé"
