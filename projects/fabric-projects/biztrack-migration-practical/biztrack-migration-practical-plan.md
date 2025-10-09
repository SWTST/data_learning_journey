```
title: "Biztrack Migration Practical"
date: 2025-10-02
tags: [#onelake #lakehouse #data-factory #pipelines #governance #permissions #lineage #semantic-models #powerbi #dataflows-gen2]
summary: Ingestion and transformation of SQL Server data into Fabric to generate PowerBi reports. 
```

# Biztrack Migration Practical

This project simulates migrating an on-prem SQL Server (Biztrack) database into Microsoft Fabric using the medallion architecture.

### **Goal: Deliver a Bronze → Silver → Gold pipeline with Power BI reporting on the gold layer.**

## <u>Step 1 – Setup & Ingestion (Bronze)</u>

**Aim: Ingest tables from AdventureWorks and Validate Ingestion**

- [x] Connect Fabric Data Factory pipeline to source SQL Server (AdventureWorks)
- [x] Create a Lakehouse.
- [x] Build pipeline(s) to copy raw tables into a bronze layer (parquet/delta).
- [ ] Validate ingestion using Spark notebooks or Data Explorer.

### **Output: Bronze lakehouse with raw tables.**

## <u>Step 2 – Cleaning & Standardisation (Silver)</u>

**Aim: Transform raw bronze data into a clean, consistent, and business-ready silver layer by applying schema alignment, standardisation rules, and data quality checks.**

**Data transformation:**
- [ ] Use Fabric notebooks or Dataflows Gen2 to clean key tables (e.g., Sales, Customers, Products).
- [ ] Apply schema standardisation: consistent datatypes, naming conventions, and null handling.
- [ ] Store transformed data in a silver folder inside Lakehouse.
  
**Quality checks:**
- [ ] Document assumptions (e.g., dropped columns, surrogate keys).
### **Output: Silver tables ready for business consumption.**

## <u>Step 3 – Business Logic (Gold)</u>

**Aim: Build gold-layer tables that apply business rules, aggregations, and denormalisation, ensuring data is optimised for analytics and easy consumption in Power BI.**

**Aggregations & business rules:**
- [ ] Build gold-layer tables with business logic (e.g., monthly sales by region, customer order summaries).
- [ ] Apply denormalisation to make Power BI modelling easier.

**Performance considerations:**
- [ ] Partition large tables.
- [ ] Add surrogate keys / date dimensions.
### **Output: Gold tables aligned to analytics needs.**

## Step 4 – Reporting & Governance</u>

**Aim: Deliver end-to-end visibility by connecting gold data to Power BI, creating reports, and applying governance controls (permissions, RLS, monitoring) to simulate a production-ready solution.**

**Power BI integration:**

- [ ] Connect Power BI to Fabric gold tables.

- [ ] Build at least one simple report/dashboard (e.g., Sales Overview).

**Governance:**

- [ ] Configure basic security:

    - [ ] Row-level security (per region).

    - [ ] Permissions on Lakehouse and Workspace.

**Monitoring**

- [ ] Set up pipeline monitoring in Fabric Data Factory.

### **Output: End-to-end pipeline with reporting and governance.**