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
  - stripe-project/data-architecture/diagrams/nosql/feedbacks
---

```mermaid
flowchart TB
    subgraph OLTP["OLTP"]
        CUSTOMER
        MERCHANT
        ORDER[/"<i>ORDER</i>"/]
        TRANSACTION
    end 
    subgraph NOSQL["NoSQL"]
        subgraph COLLS[" "]
            C_CUSTOMER_FEEDBACK("customer_feedback")
        end
		C_CF_CONTEXT("context")
		C_CF_CONTENT("content")
		C_CF_NLP("nlp")
    end

    TRANSACTION --> ORDER  

    C_CF_CONTEXT -.- ORDER
    C_CUSTOMER_FEEDBACK === C_CF_CONTEXT
    C_CUSTOMER_FEEDBACK === C_CF_CONTENT
    C_CUSTOMER_FEEDBACK === C_CF_NLP
    C_CUSTOMER_FEEDBACK -.- CUSTOMER
    C_CUSTOMER_FEEDBACK -.- MERCHANT
```