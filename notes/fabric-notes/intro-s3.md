```
title: "Session 3: Fabric Introduction - Finish OneLake Intro & Fabric Intro"
date: 2025-09-11
content: Fabric Intro - (https://learn.microsoft.com/en-us/fabric/fundamentals/microsoft-fabric-overview)
         What is OneLake - (https://learn.microsoft.com/en-us/fabric/onelake/onelake-overview)
tags: [#fabric-intro]
summary: What is OneLake? What is Fabric?
```

# Fabric Introduction - Finish OneLake Intro & Fabric Intro

## **OneLake:**
## OneLake Shortcuts

Shortcuts allow the organisation to share data between business groups or applications without duplicating data unnecessarily. When work is done in separate workspaces, data can be shared between them via a shortcut enabling you to combine data to fit a specific users needs.

A shortcut is effectively a reference to data stored in other file locations. They can be within the same workspace, external workspaces or outside of workspaces in ADLS, S3 or Dataverse.

## One copy of data for multiple engines

In fabric, the different analytical engines (T-SQL, Apache Spark, Analysis Services etc.) store data in Delta Parquet format to allow the same data to be consumed by any engine. For example: SQL Developers can create tables and load data using T-SQL. Data engineers can then access that data directly, using Spark, without needing to use a middleman. Business users can also access the data directly and consume this in the Analysis Services engine. 

## **Fabric:** 
## Fabric Compute engines

All Fabric compute experiences come preconfigured with OneLake as their native Data store.

OneLake also lets you mount your existing PaaS storage accounts using the shortcut feature. Shortcuts provide direct access to data in ADLS. Also, shortcuts can be created to other storage systems, allowing you to analyse cross-cloud data. Fabric also uses intelligent caching to reduce egress charges.

### Next session: Explore more fabric topics (research-topics, other modules in Microsoft Learn)