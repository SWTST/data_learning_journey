```
title: "Fabric Lakehouse Practical - Session 4"
date: 2025-09-30
tags: [#fabric-intro, #lakehouse, #pipelines, #semantic-models]
summary: Exploration of lakehouses and pipelines
```

# Pipeline - IngestCSV

### <u>Session Aim:</u>
Look at the capabilities of notebooks in relation to the DDL query and encoparte that into my pipeline. Take a step back from practicals and learn Data factory basics.

Notebooks are fairly straightforward and are fully implmented in my Pipeline to run DDL queries. 

A rowcount is taken on a successful run and imported into an audit table and another notebook is executed on step failure and logs an error to an errorlog table.

**Actions:**
- Created first Notebook to run on success
- Notebook1 takes a RowCount and imports into table ImportAudit
- Notebook2 runs on failure and logs a fixed error message and the current_timestamp.

The final pipeline is structured as follows:
![image](../../images-diagrams/pipeline-final.png)

I will decide whether to design pipelines relevant to whole table imports from SQL, in the interest of building practical skills, or research into Data factory and Data flow basics, further, to build my foundation.

### <u>Next session Aim:</u>

**One of the following:**
- Design pipelines for whole table ingestion (Practical and expands on Fabric skills)
  
- Research Fundamentals/basics of Dataflow and Datafactory further to build on foundational understanding

- Continue with lakehouse-practical.md steps 4-8