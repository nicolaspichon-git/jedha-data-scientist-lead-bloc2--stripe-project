---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-8
---
> NoSQL : v08 (2026/x/x).
---
```mermaid
flowchart
    subgraph OLTP["OLTP"]
        CUSTOMER
        MERCHANT
        ENTITY
    end 

    subgraph NOSQL["NoSQL"]
        subgraph EMBEDDED["Collections"]
            C_ML_FEATURES("ml_features")
        end
        subgraph EMBEDDED["Sources embarquées"]
            C_FEATURES("features")
        end

    end

    CUSTOMER --> ENTITY  
    C_ML_FEATURES -.- ENTITY
    C_ML_FEATURES -.- MERCHANT
    C_ML_FEATURES === C_FEATURES
```