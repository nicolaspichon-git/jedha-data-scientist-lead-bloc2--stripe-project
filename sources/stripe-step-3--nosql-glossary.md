
*STRIPE* PROJECT

===

# 3. NoSQL Data System
## Glossary

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / NoSQL : Glossary - 2026/10/13.*  

---

- **Sharding** = partitionnement horizontal.
	- Le *sharding* est une technique d’architecturation de base de données qui consiste à découper une grande base en plusieurs fragments plus petits, appelés *shards*, répartis sur différents serveurs. 
	- Dans un système *NoSQL*, au lieu de tout stocker sur un seul serveur, on divise les données en sous-ensembles disjoints : chaque *shard* contient une partie des lignes/documents, et l’ensemble des *shards* reconstitue la base complète.
	- Contrairement à la *réplication* (qui copie les mêmes données sur plusieurs nœuds pour la lecture et la disponibilité), le *sharding* répartit des données différentes sur plusieurs nœuds pour augmenter la capacité de stockage et le débit en écriture.

-**Change Streams** 
	- [...]
- **TTL** = _Time To Live_ (durée de vie)
	- L'*index TTL* indique au système *MongoDB* qu'il doit supprimer automatiquement ce document une fois qu'un délai donné s'est écoulé depuis une date de référence qu'il porte.
	- Un processus d'arrière-plan interne vérifie périodiquement les documents et purge ceux dont le délai est dépassé.