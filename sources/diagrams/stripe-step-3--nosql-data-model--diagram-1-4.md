---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-3
  - stripe-project/nosql/diagrams
  - stripe-project/nosql/diagrams/collections
  - stripe-project/nosql/diagrams/collections/customer_feedback
---

```mermaid
flowchart TB
    subgraph OLTP["OLTP"]
        CUSTOMER
        MERCHANT
        ORDER
        TRANSACTION
    end 

    subgraph NOSQL["NoSQL"]
        subgraph COLLECTIONS["Collections"]
            C_CUSTOMER_FEEDBACK("customer_feedback")
            C_CF_CONTEXT("context")
            C_CF_CONTENT("content")
            C_CF_NLP("nlp")
        end

    end

    TRANSACTION --> ORDER  

    C_CF_CONTEXT -.- ORDER
    C_CUSTOMER_FEEDBACK === C_CF_CONTEXT
    C_CUSTOMER_FEEDBACK === C_CF_CONTENT
    C_CUSTOMER_FEEDBACK === C_CF_NLP
    C_CUSTOMER_FEEDBACK -.- CUSTOMER
    C_CUSTOMER_FEEDBACK -.- MERCHANT
```