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
        MERCHANT
        TRANSACTION
    end 

    subgraph NOSQL["NoSQL"]
        subgraph EMBEDDED["Collections"]
            C_EVENT_LOGS("event_logs")
        end
        subgraph EMBEDDED["Sources embarquées"]
            C_EL_CONTEXT("context")
        end
    end
    
    C_EVENT_LOGS -.- MERCHANT
    C_EVENT_LOGS -.- TRANSACTION
    C_EVENT_LOGS === C_EL_CONTEXT
```