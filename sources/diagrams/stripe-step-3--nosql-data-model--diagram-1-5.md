---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-3
  - stripe-project/nosql
  - stripe-project/nosql/diagrams
  - stripe-project/nosql/diagrams/collections
  - stripe-project/nosql/diagrams/collections/merchant_config
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