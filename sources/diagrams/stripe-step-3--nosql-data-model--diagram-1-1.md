---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-3
---

```mermaid
flowchart TB
    subgraph OLTP["OLTP"]
        TRANSACTION
        MERCHANT
    end 

    subgraph NOSQL["NoSQL"]
        subgraph COLLECTIONS["Collections"]
            C_EVENT_LOGS("event_logs")
            C_EL_CONTEXT("context")
        end
    end
    
    C_EVENT_LOGS === C_EL_CONTEXT
    C_EVENT_LOGS -.- TRANSACTION
    C_EVENT_LOGS -.- MERCHANT
```