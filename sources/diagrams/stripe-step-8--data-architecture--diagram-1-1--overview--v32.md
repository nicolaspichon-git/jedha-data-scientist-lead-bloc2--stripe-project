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
%%{init: { 
	"theme: "default", 
	"themeVariables": { 
		"fontSize": "12px", 
		"nodePadding": 2  
	},
    "flowchart": {
		"nodeSpacing": 25, 
		"rankSpacing": 20, 
		"padding": 15 
    }
}}%%

flowchart TB
    ACTORS["👤Acteurs"]
    APPS["🟡 Couche applicative<br/>paiement ..."]
    ML_SERVICES["🔴 Scoring de fraude"]

    OLTP["🔵 OLTP"]
    EBUS["⚪ Bus d'évènements"]
    NOSQL["🟠 NoSQL"]
    ORCHESTRATOR["⚫ Orchestrateur"]
    OLAP["🟣 OLAP"]
    ALERT_NOTIFIERS["🔴 Notificateur d'alertes"]
    CONSUMERS["🟢 Consommateurs"]
    COMPLIANCE_REPORTING_PIPE["🟤 Reporting de conformité"]
    
    ACTORS -->|"1️⃣ paiement, consultation,<br/>produit, abonnement,<br/>administration&nbsp;fonctionnelle"| APPS

    APPS -->|"2️⃣ SQL / coeur fonctionnel<br/>& demande de droits"| OLTP
    APPS -.->|"3️⃣ interactions client,<br/>évènements SELECT"|EBUS

    OLTP -.->|"3️⃣ <i>Change Data Capture</i>"| EBUS
    EBUS -.->|"2️⃣🄱 logs,<br/>incidents,<br/>fraud scores"| OLTP

    NOSQL -->|"7️⃣ logs, feedbacks"| CONSUMERS

    NOSQL -.->|"5️⃣ <i>Change Streams</i> &gt; staging"| ORCHESTRATOR
    EBUS -.->|"5️⃣ cdc &gt; staging"| OLAP

    ORCHESTRATOR -.->|"6️⃣ déclenche, orchestre<br/><i>dbt</i> + staging"| OLAP

    OLAP -->|"7️⃣ analytique"| CONSUMERS

    EBUS -.->|"6️⃣ lecture continue"| ALERT_NOTIFIERS
    ALERT_NOTIFIERS -.->|"7️⃣ notification immédiate"| CONSUMERS
    
    OLTP -.->|"6️⃣ extraction planifiée<br/>indépendante"| COMPLIANCE_REPORTING_PIPE
    COMPLIANCE_REPORTING_PIPE -.->|"7️⃣ rapport réglementaire"| CONSUMERS
        

    EBUS -.->|"4️⃣ logs, sessions, feedbacks,<br/>calcule features,<br>cache marchand"| NOSQL

    ML_SERVICES ==>|"8️⃣🅁 autorise/bloque/suspend<br/>les transactions,<br/>en - de 100 ms"| APPS
    NOSQL -->|"8️⃣ features,<br>config. marchand,<br/>en - de 10 ms"| ML_SERVICES
    ML_SERVICES -.->|"3️⃣ scores"| EBUS

    style ACTORS fill:#FEF9E7,stroke:#D4AC0D,stroke-width:1px
    style APPS fill:#FEF9E7,stroke:#D4AC0D,stroke-width:1px
    style OLTP fill:#EBF5FB,stroke:#3498DB,stroke-width:1px
    style EBUS fill:#F4F6F6,stroke:#95A5A6,stroke-width:1px
    style NOSQL fill:#FDF2E3,stroke:#E67E22,stroke-width:1px
    style ORCHESTRATOR fill:#D6DBDF,stroke:#2C3E50,stroke-width:1px
    style OLAP fill:#F4ECF7,stroke:#8E44AD,stroke-width:1px
    style CONSUMERS fill:#EAFAF1,stroke:#27AE60,stroke-width:1px
    style ML_SERVICES fill:#FDEDEC,stroke:#E74C3C,stroke-width:1px
	style ALERT_NOTIFIERS fill:#FDEDEC,stroke:#E74C3C,stroke-width:1px
    style COMPLIANCE_REPORTING_PIPE fill:#EFEBE6,stroke:#795548,stroke-width:1px
```