---
version: v02
locale: en
tags:
  - _RNCP38777
  - _2026
  - aia
  - aia/bc02
  - stripe-project
  - stripe-project/step-0
  - stripe-project/checklist
---

*STRIPE* PROJECT
===

# Deliverables Checklist

> *Nicolas Pichon --- AIA RNCP 38777 / BC02 / Checklist / v02 --- 2026/11/05.*   
---

## D1. Comprehensive Data Architecture Diagram
A detailed diagram showing the integration of OLTP, OLAP, and NoSQL systems, including data flows, pipelines, and data models.

## D2. ERD for OLTP System
An Entity-Relationship Diagram showing the normalized schema for the transactional system.

## D3. Schema Design for OLAP System
A detailed schema design for the OLAP system, including star or snowflake schemas, aggregation strategies, and query optimization techniques.

## D4. NoSQL Data Model
A detailed schema design for the NoSQL system, including strategies for managing unstructured data, relationships, and indexing.

## D5. Data Pipeline Architecture
A technical document describing the data pipeline architecture, including tools, technologies, and processes for data integration and synchronization.

## D6. Security and Compliance Plan
A detailed plan outlining the security measures, compliance strategies, and monitoring tools to be implemented across the data architecture.

## D7. Machine Learning Integration Strategy
A document describing the integration of machine learning models within the NoSQL system, including feature extraction, model deployment, and performance monitoring.

## D8. SQL and NoSQL Queries
A set of SQL and NoSQL queries demonstrating how key business questions (e.g., revenue analysis, fraud detection, customer segmentation) can be answered using the proposed data models.

---

# Références

#### Spécifications
- \[D0\] [*Stripe Project Introduction*](stripe-step-0--introduction.pdf)

#### Livrables

- \[D1\] [*Comprehensive Data Architecture Diagram*](stripe-step-8--data-architecture.pdf)
- \[D2\] [*OLTP Entity-Relation Diagrams*](stripe-step-1--oltp-diagrams.pdf)
- \[D3] [*OLAP System Schema Design*](stripe-step-2--olap-design.pdf)
- \[D4\] [*NoSQL Data Model*](stripe-step-3--nosql-data-model.pdf)
- \[D5\] [*Data Pipeline Architecture*](stripe-step-4--data-pipeline-architecture.pdf)
- \[D6\] [*Security and Compliance Plan*](stripe-step-5--security-and-compliance-plan.pdf)
- \[D7\] [*Machine Learning Integration Strategy*](stripe-step-4--ml-integration-strategy.pdf)
- \[D8-1\] [*SQL and NoSQL Queries : OLTP Queries*](stripe-step-1--oltp-queries.pdf)
- \[D8-2\] [*SQL and NoSQL Queries : OLAP Queries*](stripe-step-2--olap-queries.pdf)
- \[D8-3\] [*SQL and NoSQL Queries : NoSQL Queries*](stripe-step-3--nosql-queries.pdf)

#### Annexes

- \[D2-A\] [*OLPT Conceptual Data Model*](annexes/stripe-step-1--oltp-annexe-a--mcd.pdf)
- \[D2-B\] [*OLTP Physical Data Model*](annexes/stripe-step-1--oltp-annexe-b--dbml.dbml)
- \[D2-C\] [*OLTP Design Notes*](annexes/stripe-step-1--oltp-annexe-c--design-notes.pdf)
- \[D2-D\] [*OLTP Replication, Failover and Disaster Recovery Strategy*](annexes/stripe-step-1--oltp-annexe-d--disaster-recovery-strategy.pdf)
- \[D3-A\] [*OLAP Kimball Analysis*](annexes/stripe-step-2--olap-annexe-a--kimball-analysis.pdf)
- \[D3-B\] [*OLAP Physical Data Model*](annexes/stripe-step-2--olap-annexe-b--dbml.dbml)
- \[D3-C\] [*OLAP Conventions and Transformation Rules*](annexes/stripe-step-2--olap-annexe-c--conventions-and-transformation-rules.pdf)
- \[D4-A\] [*NoSQL Storage Model Rationale*](annexes/stripe-step-3--nosql-annexe-a--storage-model-rationale.pdf)

#### Ressources

- \[R0\] [Stripe Business Case](stripe-project--business-case.pdf)