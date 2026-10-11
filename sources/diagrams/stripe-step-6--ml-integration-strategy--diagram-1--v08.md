---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-6
---

```mermaid 
sequenceDiagram 
	actor Client 
	participant App as Application
	participant OLTP as OLTP 
	participant Debezium 
	participant KafkaCdc as Kafka<br/>cdc.transaction
	participant Flink 
	participant MLFeat as MongoDB<br/>ml_features
	participant MConfig as MongoDB<br/>merchant_config
	participant FraudSvc as Service de scoring 
	participant KafkaFraud as Kafka<br/>fraud.scores
	participant Consumer as Consommateur async. 
	participant OLAP as OLAP
	
	Client->>App: paiement
	App->>OLTP: INSERT Transaction
	activate OLTP
	OLTP-->>App: Transaction créée (ACID)
	deactivate OLTP
	
	par chemin critique : décision temps réel (100 ms)
	    App->>FraudSvc: demander le scoring (sync.)
	    activate FraudSvc
	    FraudSvc->>MLFeat: lire par clé (features pré-calculées)
	    MLFeat-->>FraudSvc: features
	    FraudSvc->>MConfig: lire les seuils<br/>de risque par marchand
	    MConfig-->>FraudSvc: seuils
	    FraudSvc->>FraudSvc: calculer le score
	    FraudSvc-->>App: autorise / bloque / 3DS
	    deactivate FraudSvc
	    App-->>Client: Transaction confirmée / refusée
	and chemin asynchrone : actualiser les features pour les transactions futures
	    OLTP->>Debezium: capturer le changement
	    Debezium->>KafkaCdc: publier l'événement
	    KafkaCdc->>Flink: consommer en continu
	    Flink->>MLFeat: actualiser les compteurs glissants
end

Note over FraudSvc,KafkaFraud: Enregistrement du score (async.)
FraudSvc->>KafkaFraud: publier le score
KafkaFraud->>Consumer: consommer le score
Consumer->>OLTP: écrire FraudScore
Consumer->>OLAP: alimenter FactFraudEvent
```
