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
        S_MERCHANT["<u>marchand</u><br/>dashboard/API"]
        S_ADMIN["<u>interne</u><br/>support/ops"]
    end

    subgraph APPS["🟡 Couche applicative"]
        APP_CUSTOMERS["applications clients"]
        APP_EPAYMENTS["paiement"]
        APP_MERCHANTS["applications marchands"]
        APP_ADMINS["applications admins"]
    end

    subgraph OLTP["🔵 OLTP"]
		OLTP_CORE["<u>core</u><br/>Customer<br/>Merchant<br/>Transaction<br/>Subscription<br/>Product<br/>PricingPlan"]		
		OLTP_ACCESS["<u>sécurité & conformité (R)</u><br/>DataAccessLog"]
		OLTP_CHANGE["<u>sécurité & conformité (W)</u><br/>ChangeAuditLog"]
		OLTP_SECURE["<u>sécurité</u><br/>SecurityIncident"]
		OLTP_COMPLY["<u>conformité</u><br/>DataSubjectRequest<br/>ConsentRecord"]
        OLTP_CDC["<u><i>Write-Ahead-Log</i></u>"]
    end
    
    subgraph EBUS["⚪ Bus d'évènements"]
        TOPIC_SECURITY["<u>topics <code>security</code></u><br/>security.alerts"]
        TOPIC_AUDIT["<u>topics <code>audit</code></u><br/>audit.access"]
		TOPIC_CDC["<u>topics <code>cdc</code></u><br/>cdc.transaction<br/>cdc.subscription<br/>cdc.compliance<br/>cdc.security<br/>..."]
    end
    
    subgraph ORCHESTRATOR["⚫ Orchestrateur"]
	    O_DAGS["DAGs<br/>planification, dépendances, orchestration"]
    end
    
    subgraph OLAP["🟣 OLAP"]
        subgraph OLAP_FACTS_SUBSYS["faits/dimensions/vues"]
	        direction TB
	        OLAP_COMPLY_FACTS["<u>conformité</u><br/>FactDataSubjectRequest<br/>AggComplianceDailyMerchant<br/>AggDataSubjectRequestMonthly<br/>..."]
	        OLAP_SECURE_FACTS["<u>sécurité</u><br/>FactAuditEvent<br/>FactSecurityIncident<br/>AggSecurityIncidentMonthly<br/>..."]
	    end
        OLAP_STAGING["<u>staging</u><br/>cache pour <i>dbt</i>"]
        OLAP_DBT["<u><i>dbt</i></u><br/>transformations<br/>..."]
        OLAP_FACTS_SUBSYS
    end
    
    subgraph CONSUMERS["🟢 Consommateurs"]
	    C_SECURITY_TEAM["<u>analytiques séc. & conf.</u><br/>tendances, alertes"]
        C_COMPLIANCE_TEAM["<u>reporting conformité</u><br/>RGPD/PCI-DSS"]
    end
      
    subgraph ALERT_NOTIFIERS["🔴 Notificateur d'alertes"]
	    ALERT_SECURITY["alerte de sécurité"]
    end
    
    subgraph COMPLIANCE_REPORTING_PIPE["🟤 Extraction Reporting Conformité"]
	    CR_EXTRACT["processus d'extraction dédié,<br/>planification indépendante"]
    end
    
    S_CUSTOMER -->|"1️⃣ paiement, consultation"| APP_CUSTOMERS
    S_MERCHANT -->|"1️⃣ produits, abonnements"| APP_MERCHANTS
    S_ADMIN -->|"1️⃣ administration fonctionnelle"| APP_ADMINS
    
    APP_CUSTOMERS --- APP_EPAYMENTS
	APP_CUSTOMERS -->|"2️⃣ "| OLTP_COMPLY

    APPS -.->|"3️⃣ SELECT events<br/>avec justification"| TOPIC_AUDIT
    APPS -->|"2️⃣ "| OLTP_CORE
    
    OLTP_CORE -.->|"2️⃣🄸 <i>Change Data Capture</i>"| OLTP_CDC
    OLTP_ACCESS -.->|"2️⃣🄸 <i>Change Data Capture</i>"| OLTP_CDC
    OLTP_SECURE -.->|"2️⃣🄸 <i>Change Data Capture</i>"| OLTP_CDC
    OLTP_COMPLY -.->|"2️⃣🄸 <i>Change Data Capture</i>"| OLTP_CDC
    OLTP_CDC -.->|"3️⃣ ingestion async. cont."| TOPIC_CDC


	TOPIC_CDC -.->|"5️⃣ compilation async. cont."| OLAP_STAGING

    O_DAGS -.->|"6️⃣ déclenche, orchestre"| OLAP_DBT
    OLAP_STAGING -->|"6️⃣  "| OLAP_DBT
    OLAP_DBT -->|"6️⃣  "| OLAP_FACTS_SUBSYS
    
    OLAP_FACTS_SUBSYS -->|"7️⃣ "| C_SECURITY_TEAM

    OLTP_ACCESS -.->|"6️⃣ extraction planifiée<br/>indépendante"| CR_EXTRACT
    OLTP_CHANGE -.->|"6️⃣ extraction planifiée<br/>indépendante"| CR_EXTRACT
    OLTP_COMPLY -.->|"6️⃣ extraction planifiée<br/>indépendante"| CR_EXTRACT
    CR_EXTRACT -.->|"7️⃣ rapport réglementaire,<br/>traçable à la source"| C_COMPLIANCE_TEAM

    TOPIC_AUDIT -.->|"2️⃣🄱 ingestion async. cont."| OLTP_ACCESS
    TOPIC_CDC -.->|"2️⃣🄱 ingest./interpr. async. cont."| OLTP_CHANGE

    TOPIC_AUDIT -.->|"2️⃣🄱 détection async. cont.<br/>des tentatives suspectes"| OLTP_SECURE
    TOPIC_CDC -.->|"3️⃣🄸 relais async. cont."| TOPIC_SECURITY

    TOPIC_SECURITY -.->|"6️⃣ ingest./webhook async. cont."| ALERT_SECURITY
    ALERT_SECURITY -.->|"7️⃣ notif immédiate<br/>canal d'astreinte"| C_SECURITY_TEAM
    
    style ACTORS fill:#FEF9E7,stroke:#D4AC0D,stroke-width:1px
    style APPS fill:#FEF9E7,stroke:#D4AC0D,stroke-width:1px
    style OLTP fill:#EBF5FB,stroke:#3498DB,stroke-width:2px
    style EBUS fill:#F4F6F6,stroke:#95A5A6,stroke-width:1px
    style ORCHESTRATOR fill:#D6DBDF,stroke:#2C3E50,stroke-width:2px
    style OLAP fill:#F4ECF7,stroke:#8E44AD,stroke-width:2px
    style OLAP_FACTS_SUBSYS fill:#F4ECF7,stroke:#8E44AD,stroke-width:2px
    style CONSUMERS fill:#EAFAF1,stroke:#27AE60,stroke-width:1px 
	style ALERT_NOTIFIERS fill:#FDEDEC,stroke:#E74C3C,stroke-width:1px 
    style COMPLIANCE_REPORTING_PIPE fill:#EFEBE6,stroke:#795548,stroke-width:2px
```