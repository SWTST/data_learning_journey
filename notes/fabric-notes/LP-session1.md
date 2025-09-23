```
title: "Fabric Lakehouse Practical - Session 1"
date: 2025-09-16
tags: [#fabric-intro, #lakehouse, #pipelines, #semantic-models]
summary: Exploration of lakehouses and pipelines
```
# Pipeline - IngestCSV

I've completed the following:

- Created a lakehouse 
- Manually loaded CSVs and viewed as tables 
- Built a semantic model and report 
- Created a basic pipeline to ingest a CSV file  
  
The lookup finds the file but it fails on the **foreach** due to a length parameter error. See below:

```
The function 'length' expects its parameter to be an array or a string. The provided value is of type 'Object'.
```
### Steps Completed/In Progress:
- Step 1: Lakehouse Quickstart
- Step 2: Pipelines 101