```
title: "Fabric Lakehouse Practical"
date: 2025-09-16
tags: [#fabric-intro, #lakehouse, #pipelines, #semantic-models]
summary: Exploration of lakehouses and other fabric functionality 
```
# Mini-Project Lakehouse Practical

The aims are to span over multiple sessions and give a well rounded practical introduction to basic Lakehouse functionality. These are as follows:

**<u>Step 1: Lakehouse Quickstart</u>**

- [x] Create a Lakehouse in your workspace.
- [x] Load a sample CSV (either from your local machine or OneLake sample data).
- [x] Verify you can see tables in the Explorer pane.
- [x] Build a simple report with Direct Lake connection.

**<u>Step 2: Pipelines 101</u>**

- [x] Create a new Pipeline.
- [x] Add activities: Lookup → ForEach → Copy activity.
- [x] Parameterise the source path (so you can reuse it easily).
- [x] Run the pipeline → confirm data lands in your Lakehouse.
- [x] Note down failure handling options (retry, stop, continue).


**<u>Step 3: Copy Job (Preview)</u>**

- [ ] Recreate your pipeline using the Copy job activity instead of Copy activity.
- [ ] Compare the differences: performance, ease of use, limitations.
- [ ] Add a short note in your fabric-notes folder.

**<u>Step 4: Dataflow Gen2 → Pipeline chaining</u>**

- [ ] Create a Dataflow Gen2 to clean/transform sample data (e.g. rename columns, filter rows).
- [ ] Save output to your Lakehouse.
- [ ] Chain it with a Pipeline to automate ingestion → transformation.
- [ ] Note when you’d use Dataflow Gen2 vs Pipeline.

**<u>Step 5: Lakehouse Schemas (Preview)</u>**

- [ ] Inside your Lakehouse, create two schemas: bronze and silver.
- [ ] Land raw data into bronze, then copy/transform into silver.
- [ ] Write down how schemas help with organising data.

**<u>Step 6: Semantic Model (Direct Lake)</u>**

- [ ] Create a small semantic model in Direct Lake mode from your silver tables.
- [ ] Define relationships (star schema if possible).
- [ ] Build a quick Power BI report on top.
- [ ] Write down any limitations you hit with Direct Lake.

**<u>Step 7: Monitoring & Cost Awareness</u>**

- [ ] Run your pipeline a few times.
- [ ] Open the Monitoring hub → review success/failure, execution time.
- [ ] Capture a screenshot or note CU usage if shown.

**<u>Step 8: What’s New Sweep</u>**

- [ ] Check Fabric → Help → What’s new.
- [ ] Note anything that touches pipelines or lakehouses that you haven’t tried yet
