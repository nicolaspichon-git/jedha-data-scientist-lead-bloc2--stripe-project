*STRIPE* PROJECT
===

# 1. Modèle de Données OLTP
## D2. Diagramme Entité-Relation (ERD)

> *Nicolas Pichon - AIA RNCP 38777 / BC02 / D2 : OLTP - ERD / v25 - 2026/10/13.*   

---

### D2.1. Contexte

Diagrammes représentant le modèle physique des données OLTP.

Le modèle est scindé en différentes groupes fonctionnels pour permettre une meilleure lisibilité : 
- une vue globale des entités regroupées par fonctions,
- une vue du modèle centré sur les entités *Clients*,
- une vue du modèle centré sur les entités *Marchands*,
- une vue du modèle centré sur les entités *Transactions*,
- une vue du modèle centré sur les référentiels géographique et monétaire,
- une vue du modèle centré sur les entités dédiées à la sécurité et à la conformité réglementaire.

---

<div style="page-break-after: always;"></div>

### D2.2. Vue fonctionnelle des entités

```mermaid
%%{init: {'flowchart': {'defaultRenderer': 'elk'}}}%%
flowchart TB
	REF["<b>🔘&nbsp;<u>References</u></b><br/>Country<br/>Currency"]
    
	CUSTOMER_DOMAIN["<b>🟢&nbsp;<u>Customers</u></b><br/>Customer<br/>PaymentMethod<br/>PaymentMethodType<br/>CardBrand<br/>Subscription<br/>SubscriptionStatus"]
	
	MERCHANT_DOMAIN["<b>🔵&nbsp;<u>Merchants</u></b><br/>Merchant<br/>MerchantStatus<br/>PricingPlan<br/>PricingPlanFee<br/>Product"]
	
	TRANSACTION_DOMAIN["<b>🔴&nbsp;<u>Transactions</u></b><br/>Transaction<br/>TransactionStatus<br/>Chargeback<br/>ChargebackStatus<br/>ChargebackReasonCode<br/>FraudScore<br/>FraudRiskLevel"]

    SECREGULATION_DOMAIN["<b>🟣&nbsp;<u>Sec&nbsp;&amp;&nbsp;Regulation</u></b><br/>DataAccessLog<br/>ChangeAuditLog<br/>AuditAction<br/>AuditActorType<br/>DataSubjectRequest<br/>DataSubjectRequestStatus<br/>Regulation<br/>ConsentRecord<br/>SecurityIncident<br/>SecurityIncidentStatus"]

    CUSTOMER_DOMAIN --> REF
    CUSTOMER_DOMAIN --> MERCHANT_DOMAIN
    
    MERCHANT_DOMAIN --> REF
    
    TRANSACTION_DOMAIN --> REF
    TRANSACTION_DOMAIN --> CUSTOMER_DOMAIN
    TRANSACTION_DOMAIN --> MERCHANT_DOMAIN

    SECREGULATION_DOMAIN --> CUSTOMER_DOMAIN
    SECREGULATION_DOMAIN --> MERCHANT_DOMAIN
    
    
    style REF fill:#F4F6F6,stroke:#95A5A6,stroke-width:1px
    style MERCHANT_DOMAIN fill:#EBF5FB,stroke:#3498DB,stroke-width:1px
    style CUSTOMER_DOMAIN fill:#EAFAF1,stroke:#27AE60,stroke-width:1px
    style TRANSACTION_DOMAIN fill:#FDEDEC,stroke:#E74C3C,stroke-width:1px
    style SECREGULATION_DOMAIN fill:#F4ECF7,stroke:#8E44AD,stroke-width:1px
```

---

<div style="page-break-after: always;"></div>

### D2.3. Modèle *Clients*

![[stripe-step-1--oltp-views--customers.svg]]

---

<div style="page-break-after: always;"></div>

###  D2.4. Modèle *Marchands*

![[stripe-step-1--oltp-views--merchants.svg]]

---

<div style="page-break-after: always;"></div>

###  D2.5. Modèle *Transactions*

![[stripe-step-1--oltp-views--transactions.svg]]

---

<div style="page-break-after: always;"></div>

### D2.6. Référentiels *Géographique* & *Monétaire*

![[stripe-step-1--oltp-views--references.svg]]

---

<div style="page-break-after: always;"></div>

### D2.7. Modèle *Sécurité & Conformité*

![[stripe-step-1--oltp-views--security-and-regulation.svg]]

---
