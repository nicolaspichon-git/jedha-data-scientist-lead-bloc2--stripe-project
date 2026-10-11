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
        DEVICE
        COUNTRY
    end 

    subgraph NOSQL["NoSQL"]
        subgraph EMBEDDED["Collections"]
            C_USER_SESSIONS("user_sessions")
        end
        subgraph EMBEDDED["Sources embarquées"]
            C_US_EVENTS("events")
        end
    end

    C_USER_SESSIONS -.- CUSTOMER
    C_USER_SESSIONS -.- MERCHANT
    C_USER_SESSIONS === COUNTRY
    C_USER_SESSIONS === DEVICE
    C_USER_SESSIONS === C_US_EVENTS
```