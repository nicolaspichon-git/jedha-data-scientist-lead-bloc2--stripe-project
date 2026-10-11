---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-8
---
> GDA : v32
---
```mermaid
flowchart TB
    subgraph ACTORS["👤 Acteurs"]
        S_CUSTOMER["<u>client</u><br/>checkout/app"]
    end

    subgraph APPS["🟡 Couche applicative"]
        APP_CUSTOMERS["applications clients"]
        APP_EPAYMENTS["paiement"]
    end

    subgraph ML_SERVICES["🔴 Services internes"]
        ML_FRAUD["scoring de fraude<br/>en temps réel"]
    end
    
    subgraph OLTP["🔵 OLTP"]
        OLTP_CORE["<u>core</u><br/>Customer<br/>Merchant<br/>Transaction<br/>..."]
		OLTP_FRAUD["<u>risque & fraude</u><br/>FraudScore"]
        OLTP_CDC["<u><i>Write-Ahead-Log</i></u>"]
    end

    subgraph EBUS["⚪ Bus d'évènements (<i>Kafka</i>)Bus d'évènements"]
	    TOPIC_CDC["<u>topics <code>cdc</code></u><br/>cdc.transaction<br/>..."]
		TOPIC_FRAUD["<u>topics <code>fraud</code></u><br/>scoring.logs"]
    end
    
    subgraph NOSQL["🟠 NoSQL"]
		NOSQL_FEATURES["<u>ml_features</u><br/>scoring temps réel"]
        NOSQL_CONFIG["<u>merchant_config</u><br/>cache dénormalisé<br/>seuils de risque"]
    end

    subgraph ORCHESTRATOR["⚫ Orchestration (<i>Airflow</i>)"]
	    O_DAGS["DAGs<br/>planification, dépendances, orchestration"]
    end

    subgraph OLAP["🟣 Système OLAP (<i>Snowflake</i>)"]
        direction TB
        OLAP_STAGING["<u>staging</u><br/>cache pour <i>dbt</i>"]
        OLAP_DBT["<u><i>dbt</i></u><br/>transformations<br/>..."]
        OLAP_FRAUD_FACTS["<u>faits/dimensions/vues</u><br/>FactFraudEvent<br/>DimFraudRiskLevel<br/>AggFraudDailyMerchant<br/>..."]
    end

    subgraph CONSUMERS["🟢 Consommateurs"]
        C_RISK_TEAM["<u>risque & fraude</u><br/>reporting interne"]
    end

    S_CUSTOMER -->|"1️⃣ paiement, consultation"| APP_CUSTOMERS
    
    APP_CUSTOMERS --- APP_EPAYMENTS
    
    APP_EPAYMENTS -->|"2️⃣ créer transaction"| OLTP_CORE
    APP_EPAYMENTS -->|"8️⃣ app. sync."| ML_FRAUD

	ML_FRAUD ==>|"8️⃣🅁 <u>décision temps réel</u><br/>autorise/bloque/suspend<br/>les transactions<br/>en - de 100 ms"| APP_EPAYMENTS
    
    O_DAGS -.->|"6️⃣ déclenche, orchestre"| OLAP_DBT
    OLTP_CORE -.->|"2️⃣🄸 <i>Change Data Capture</i>"| OLTP_CDC
    
    OLTP_CDC -.->|"3️⃣ ingest. async. cont."| TOPIC_CDC

    TOPIC_CDC -.->|"4️⃣ act. async. cont.<br/>des features"| NOSQL_FEATURES
    TOPIC_CDC -.->|"4️⃣ act. async. cont.<br/>du cache marchand"| NOSQL_CONFIG

	TOPIC_CDC -.->|"5️⃣ compil. async. cont."| OLAP_STAGING

    OLAP_STAGING -->|"6️⃣ "| OLAP_DBT
    OLAP_DBT -->|"6️⃣ "| OLAP_FRAUD_FACTS
    
	NOSQL_FEATURES -->|"8️⃣ lect. sync.<br/>< 10 ms"| ML_FRAUD
	NOSQL_CONFIG -->|"8️⃣ lect. sync.<br/>seuils marchands"| ML_FRAUD

	ML_FRAUD -.->|"3️⃣ pub. logs"| TOPIC_FRAUD
	
    OLAP_FRAUD_FACTS -->|"7️⃣ "| C_RISK_TEAM

    TOPIC_FRAUD -.->|"2️⃣🄱 ingest. async. cont."| OLTP_FRAUD

    style ACTORS fill:#FEF9E7,stroke:#D4AC0D,stroke-width:1px
    style OLTP fill:#EBF5FB,stroke:#3498DB,stroke-width:2px
    style EBUS fill:#F4F6F6,stroke:#95A5A6,stroke-width:1px
    style NOSQL fill:#FDF2E3,stroke:#E67E22,stroke-width:1px
    style ORCHESTRATOR fill:#D6DBDF,stroke:#2C3E50,stroke-width:2px
    style OLAP fill:#F4ECF7,stroke:#8E44AD,stroke-width:2px
    style CONSUMERS fill:#EAFAF1,stroke:#27AE60,stroke-width:1px
    style ML_SERVICES fill:#FDEDEC,stroke:#E74C3C,stroke-width:1px
```