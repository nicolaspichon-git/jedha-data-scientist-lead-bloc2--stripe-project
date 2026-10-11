---
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-8
---
> OLTP : v30 (2026/09/21).
---

```mermaid
flowchart TB
  ACTEUR[["ACTOR"]]
  TRANSACTION[["TRANSACTION"]]

  subgraph FRAUD["Scoring de fraude"]
    FRAUDE_SCORE[["FRAUD_SCORE"]]
    FRAUDE_REVUE[["FRAUD_REVIEW"]]
    FRAUDE_DECISION[["FRAUD_DECISION"]]
    REALISER{Performs}
    SUBIR{Undergoes}
    DECIDER{Decides}
    EVALUER{Evaluates}
  end

  ACTEUR ---|"0,n"| REALISER 
  REALISER ---|"1,1"| FRAUDE_REVUE
  
  TRANSACTION ---|"0,n"| SUBIR
  SUBIR ---|"1,1"| FRAUDE_REVUE
  TRANSACTION ---|"0,1"| DECIDER 
  DECIDER ---|"1,1"| FRAUDE_DECISION
  
  TRANSACTION ---|"0,1"| EVALUER
  EVALUER ---|"1,1"| FRAUDE_SCORE
```
