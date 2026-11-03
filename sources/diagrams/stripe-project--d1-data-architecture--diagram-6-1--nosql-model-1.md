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
        TRANSACTION
        MERCHANT
    end 
    subgraph NOSQL["NoSQL"]
	    subgraph COLLS[" "]
	        C_EVENT_LOGS("event_logs")
	    end
	    C_EL_CONTEXT("context")
    end
    
    C_EVENT_LOGS === C_EL_CONTEXT
    C_EVENT_LOGS -.- TRANSACTION
    C_EVENT_LOGS -.- MERCHANT
```