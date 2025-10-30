```
title: "Silver Migration Practical Plan"
date: 2025-10-30
tags: [#onelake #lakehouse #data-factory #pipelines #governance #permissions #lineage #semantic-models #powerbi #dataflows-gen2]
summary: Ingestion and transformation of SQL Server data into Fabric to generate PowerBi reports. 
```
# Cleaning & Standardisation (Silver)

## **Aim: Transform raw bronze data into a clean, consistent, and business-ready silver layer by applying schema alignment, standardisation rules, and data quality checks.**

My table target for the silver schema is 25 tables across all five schemas: Person, Production, Purchasing, HumanResources and Sales. These are all encapsulated in my bronze schema.

### Table Counter: 0/25
#### Table list:
- Person: 0/4
- Production: 0/6
- Purchasing: 0/5
- HumanResources: 0/4
- Sales: 0/6

I will be using the following criteria for each table:

### Criteria
- Stable Business key and deduped
- Types standardized (money as decimal, dates as datetime2)
- Text Trimmed; code columns case-normalised
- DQ gates pass (not-null key, key uniqueness, no impossible values, sane dates)
- Incremental watermark set (ModifiedDate)
- Minimal docs: rules and lineage

## bronze.Person_Person

The corresponding silver_raw table is silver.raw_Person_Person. My first attempt at the notebook is below where I'm creating the table and then using a MERGE to UPSERT data. The notebook is failing on incompatible rows so I will review this next session. 

THe statement is updating rows if the modified date has changed since the last update and if the PK column matches. If the value is not found already in the table the values are inserted as new values from my source bronze table.

### **Notebook:**
```
-- Code Block 1:
%%sql
CREATE TABLE IF NOT EXISTS silver.raw_Person_Person(
    BusinessEntityID INT,
    PersonType string,
    NameStyle BOOLEAN,
    Title string,
    FirstName string,
    MiddleName string,
    LastName string,
    Suffix string,
    EmailPromotion INT,
    AdditionalContactInfo string,
    rowguid string,
    ModifiedDate TIMESTAMP,
    TimeIngested TIMESTAMP
);
```
```
-- Code Block 2:
%%sql

MERGE INTO silver.raw_Person_Person as tgt
USING (
    SELECT
    BusinessEntityID,
    PersonType,
    NameStyle,
    Title,
    FirstName,
    MiddleName,
    LastName,
    Suffix,
    EmailPromotion,
    AdditionalContactInfo,
    rowguid,
    ModifiedDate
    FROM bronze.Person_Person
) as src
ON tgt.BusinessEntityID = src.BusinessEntityID
WHEN MATCHED AND src.ModifiedDate >= tgt.ModifiedDate
THEN
    UPDATE
    SET tgt.BusinessEntityID = src.BusinessEntityID,
    tgt.PersonType = src.BusinessEntityID,
    tgt.NameStyle = src.NameStyle,
    tgt.Title = src.Title,
    tgt.FirstName = src.FirstName,
    tgt.MiddleName = src.MiddleName,
    tgt.LastName = src.LastName,
    tgt.Suffix = src.Suffix,
    tgt.EmailPromotion = src.EmailPromotion,
    tgt.AdditionalContactInfo = src.AdditionalContactInfo,
    tgt.rowguid = src.rowguid,
    tgt.ModifiedDate = src.ModifiedDate,
    tgt.TimeIngested = CURRENT_TIMESTAMP

WHEN NOT MATCHED
THEN
    INSERT (BusinessEntityID,
    PersonType,
    NameStyle,
    Title,
    FirstName,
    MiddleName,
    LastName,
    Suffix,
    EmailPromotion,
    AdditionalContactInfo,
    rowguid,
    ModifiedDate,
    TimeIngested)
    VALUES (
        src.BusinessEntityID,
    src.BusinessEntityID,
    src.NameStyle,
    src.Title,
    src.FirstName,
    src.MiddleName,
    src.LastName,
    src.Suffix,
    src.EmailPromotion,
    src.AdditionalContactInfo,
    src.rowguid,
    src.ModifiedDate,
    CURRENT_TIMESTAMP
    );
```


