*STRIPE* PROJECT
===

# 3. NoSQL Data System
## D4. NoSQL Data Model

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D4 : NoSQL Data Model - Changelogs / 2026/10/13.*

---

### Changelogs

#### Changelog v02 → v03

> **Note de version (v03)** - Fusion des deux brouillons concurrents en un document unique  
> après comparaison (`nosql-design-diagrams` retenu comme structure de base, plus complète -  
> couverture T3, sécurité/conformité, annexe de justification autoportante - enrichi de  
> l'ouverture méthodologique de `nosql-schemas`). Trois décisions tranchées explicitement :  
> `user_sessions` retenu contre `session_events` (le nom doit refléter le Bucket Pattern, pas  
> suggérer un document par événement) ; `ml_features` au grain "un document par entité,  
> continuellement actualisé" plutôt que "un document par transaction évaluée" (le second  
> besoin, historique, est déjà couvert côté OLAP par `FactFraudEvent`) ; `schema_version`  
> généralisé aux cinq collections.

#### Changelog v03 → v04

> **Note de version (v04)** - Cinq corrections sur la version poursuivie indépendamment :  
> grammaire ("demande au le système" → "demande que le système"), balise italique non  
> refermée dans l'annexe, URL malformée de la référence `[A2]`, `schema_version` manquant sur  
> `merchant_config`, nomenclature `fact_fraud_event` → `FactFraudEvent` (PascalCase, cohérent  
> avec l'Annexe 2.B).

#### Changelog v04 → v05

> **Note de version (v05)** - Clarification de la section "NoSQL > OLAP" (D4.9) : distinction  
> entre le **transport** (Change Streams, continu) et le **chargement** vers l'OLAP (lots  
> nocturnes planifiés) - les deux notions étaient présentées comme équivalentes alors qu'elles  
> décrivent deux étapes différentes du même pipeline.

#### Changelog v05 → v06

> **Note de version (v06)** - Fusion du document Python séparé ("Collections Python") dans ce  
> document unique : chaque collection porte désormais son document type, son validateur de  
> schéma et ses index directement en Python plutôt qu'en JSON illustratif séparé. Deux  
> corrections au passage : l'index multikey de `user_sessions` (`events.metadata. transaction_id`, pas `events.transaction_id`) et l'index texte de `customer_feedback`  
> (`content.text`, pas `text`). `_id` rendu cohérent sur les cinq collections (explicite et  
> signifiant quand il porte une identité métier, auto-généré sinon).

#### Changelog v06 → v07

> **Note de version (v07)** - Ajout du paragraphe explicatif manquant au principe 3 de D4.3  
> (jusqu'ici un simple renvoi sans contenu propre), et correction de ce renvoi (il pointait  
> vers §D4.7, sharding, sans rapport, plutôt que §D4.6, relations, où le sujet est  
> réellement traité).
> 
> **À partir de cette version, deux branches ont coexisté** : la présente, et une  
> restructuration indépendante portant le même numéro v07, qui a notamment consolidé la  
> validation de schéma en une remarque unique en tête de D4.5 (§D4.5.1) plutôt que répétée  
> par collection - une amélioration reprise telle quelle à la fusion suivante.

#### Changelog v07 → v08

> **Note de version (v08)** - Fusion des deux branches v07 et correction de deux régressions  
> introduites pendant la restructuration indépendante : les chemins d'index corrigés en v06  
> (`events.metadata.transaction_id`, `content.text`) étaient revenus à leur forme fautive  
> dans le tableau de synthèse D4.6, alors que le code Python restait correct - incohérence  
> interne au document. Correction du renvoi obsolète en D4.10 (§D4.8 pointait encore vers la  
> validation de schéma, déplacée en §D4.5.1 lors de la restructuration). Coquille "ù"  
> parasite retirée en D4.8.