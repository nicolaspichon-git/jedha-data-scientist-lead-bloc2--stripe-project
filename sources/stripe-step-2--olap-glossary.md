*STRIPE* PROJECT
===
# 2. OLAP Data System
## Glossary

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / OLAP : Glossary - 2026/10/13.*   

---

- **SCD** = Slowly Changing Dimension. 
	- C'est un concept central de la méthode *Kimball*. Il répond à la question : **quand un attribut d'une dimension change dans le monde réel (un marchand change de pays, un client change de statut), que fait-on dans l'entrepôt ?**
	- Types 
		- **SCD1** : écraser sans garder de trace ; La nouvelle valeur remplace l'ancienne directement dans la ligne existante ; Pas d'historique : si on interroge le passé, on retrouvera la valeur _actuelle_, pas celle qui était vraie à l'époque.

		- **SCD2** : garder toutes les versions, avec des dates de validité ; Un changement crée une nouvelle ligne dans la dimension (nouvelle clé technique), avec des colonnes `valid_from`/`valid_to` marquant la période de validité de chaque version. La ligne précédente n'est jamais modifiée ni supprimée, elle devient juste "expirée".

- **MRR** = Monthly Recurrent Revenue (revenu récurrent mensuel)