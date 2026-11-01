---
version: v09
locale: fr
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-8
  - stripe-project/data-architecture
  - stripe-project/data-architecture/diagrams
  - stripe-project/data-architecture/diagrams/nosql
  - stripe-project/data-architecture/diagrams/nosql/events
---

```mermaid
flowchart TB
    subgraph OLTP["OLTP"]
        MERCHANT
        COUNTRY
    end 

    subgraph NOSQL["NoSQL"]
        subgraph COLLECTIONS["Collections"]
            C_MERCHANT_CONFIG("merchant_config")
	        C_MC_RISK("risk_profile")
        end
    end

    C_MERCHANT_CONFIG === C_MC_RISK
    C_MERCHANT_CONFIG === MERCHANT
    C_MERCHANT_CONFIG -.- COUNTRY
```