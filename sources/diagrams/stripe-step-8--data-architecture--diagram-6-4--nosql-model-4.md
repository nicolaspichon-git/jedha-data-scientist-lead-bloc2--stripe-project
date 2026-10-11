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
        TRANSACTION
        ORDER
    end 

    subgraph NOSQL["NoSQL"]
        subgraph EMBEDDED["Collections"]
            C_CUSTOMER_FEEDBACK("customer_feedback")
        end
        subgraph EMBEDDED["Sources embarquées"]
            CF_CONTENT("content")
            CF_CONTEXT("context")
            CF_NLP("nlp")
        end

    end

    TRANSACTION --> ORDER  

    C_CUSTOMER_FEEDBACK -.- CUSTOMER
    C_CUSTOMER_FEEDBACK -.- MERCHANT
    C_CUSTOMER_FEEDBACK -.- ORDER
    C_CUSTOMER_FEEDBACK === CF_CONTENT
    C_CUSTOMER_FEEDBACK === CF_CONTEXT
    C_CUSTOMER_FEEDBACK === CF_NLP
```