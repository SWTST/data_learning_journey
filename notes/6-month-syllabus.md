# 📅 6 Month Learning Syllabus

## 🍂 September 2025
- [x] **Month Complete**
- [x] SQL: Finish Section 6 (Queries) → start Section 7 (System DBs).
- [x] Fabric: Intro modules (Lakehouse, Data Factory basics).
- [x] Python: Codecademy: Learn Python 3 Course
- [x] Review: Notes + SQL tuning examples

## 🎃 October 2025
- [x] **Month Complete**
- [ ] SQL: Sections 7 (System DBs) + 8 (Deep Dive, start).
- [x] Fabric: Build your first end-to-end pipeline (CSV → Lakehouse → query).
- [x] Python: Codecademy: Learn Python 3 Course
- [ ] Review: Share learning summary → LinkedIn/blog.

## **Behind schedule - Revised targets below:**

## 🎆 November 2025 – Catch-up & Solid Foundations
- [ ] **Month Complete**

- [ ] **SQL (Mon & Fri, 2h/day)**
  - [ ] Finish Section 7 (System DBs).
  - [ ] Start Section 8 (Deep Dive) – focus on:
    - [ ] Storage structures
    - [ ] Indexing basics
    - [ ] Reading execution plans
  - [ ] Reach ~60–70% of Section 8.

- [ ] **Fabric (Tue & Thu, 1h/day)** – *AdventureWorks as main dataset*
  - [ ] Bronze layer:
    - [x] Bulk load core AdventureWorks tables (e.g. Sales, Customers, Products).
    - [x] Fix append vs overwrite behaviour.
    - [ ] Implement at least one incremental load pattern.
  - [ ] Silver layer:
    - [x] Use `MERGE` for first AdventureWorks table (e.g. SalesOrderHeader/Detail).
    - [ ] Add simple SQL-only cleaning (TRIM, NULL handling, basic dedupe).
  - [ ] Governance:
    - [ ] Set up basic workspace roles/permissions for the AdventureWorks project.

- [ ] **Python (Wed, 1h/week)**
  - [ ] Move from ~35% → ~55–60% of Codecademy **Learn Python 3**.
  - [ ] Focus on:
    - [ ] Functions
    - [ ] Lists & dictionaries
    - [ ] File I/O

- [ ] **Review**
  - [ ] Write a combined **Oct + Nov learning recap** (SQL + Fabric progress with AdventureWorks).
  - [ ] Optionally post to LinkedIn or keep as a private reflection.

---

## 🎁 December 2025 – Finish SQL, Add Gold Layer (AdventureWorks)
- [ ] **Month Complete**

- [ ] **SQL (Mon & Fri, 2h/day)**
  - [ ] Finish remaining topics in Section 8.
  - [ ] Complete Section 9 (Backup/Restore):
    - [ ] Full/diff/log backups
    - [ ] Recovery models
    - [ ] Point-in-time restore practice
  - [ ] Complete Section 10 (User Management):
    - [ ] Logins, users, roles, permissions
  - [ ] Quick revision of Sections 7–10.  
  - [ ] **SQL stop rule reached** ✅

- [ ] **Fabric (Tue & Thu, 1h/day)** – *AdventureWorks Bronze → Silver → Gold*
  - [ ] Build 1–2 **Gold tables** from AdventureWorks, e.g.:
    - [ ] Sales summary by date/product/category.
    - [ ] Customer lifetime value or basic customer metrics.
  - [ ] Ensure Gold sources data from **Silver**, not Bronze.
  - [ ] Use lineage view to validate end-to-end AdventureWorks pipeline.
  - [ ] Draw a simple Bronze → Silver → Gold diagram for AdventureWorks.

- [ ] **Python (Wed, 1h/week)**
  - [ ] Move from ~60% → ~85–90% of **Learn Python 3**.
  - [ ] Focus on:
    - [ ] Error handling
    - [ ] Modules
    - [ ] Using external libraries

- [ ] **Review**
  - [ ] Publish a mini case study:
    - “Migrating AdventureWorks into a Fabric Bronze–Silver–Gold pipeline (and fixing append vs overwrite).”

---

## ❄ January 2026 – DP-600 Prep + Portfolio Polish (AdventureWorks Project)
- [ ] **Month Complete**

- [ ] **Mon & Fri – DP-600 + Fabric advanced (4h/week)**
  - [ ] Weeks 1–2:
    - [ ] Work through weaker DP-600 areas (security, modelling, governance, monitoring, etc.).
    - [ ] For each topic, make a concrete change in your **AdventureWorks Fabric project** (e.g. better model for Sales, row-level security).
  - [ ] Weeks 3–4:
    - [ ] Do full DP-600 practice question sets.
    - [ ] Create 1–2 page cheat sheets for:
      - [ ] Ingestion
      - [ ] Transformations
      - [ ] Modelling (using AdventureWorks examples)
      - [ ] Security/governance
      - [ ] Deployment/DevOps

- [ ] **Tue & Thu – Project to portfolio level (2h/week)**
  - [ ] Clean up AdventureWorks Fabric project:
    - [ ] Clear naming conventions for Bronze/Silver/Gold.
    - [ ] Basic monitoring/logging (row counts, simple checks).
  - [ ] Optionally add **one small extra public CSV** just to show reusability (but AdventureWorks stays the main star).
  - [ ] Prepare GitHub repo:
    - [ ] Add notebooks/SQL scripts used for AdventureWorks migration.
    - [ ] Add pipeline screenshots/diagrams.
    - [ ] Write a clear README describing it as:
      - [ ] “AdventureWorks SQL → Fabric Lakehouse migration and modelling project.”

- [ ] **Python (Wed, 1h/week)**
  - [ ] Finish **Learn Python 3** early in the month.
  - [ ] Start **Pandas basics**:
    - [ ] Read CSVs into DataFrames.
    - [ ] Select/filter columns and rows.
    - [ ] Simple transforms and basic `groupby`.

- [ ] **Review**
  - [ ] Push the **AdventureWorks Fabric migration** project to GitHub.
  - [ ] Ensure README sells it as a real-world data engineering/analytics example.

---

## 🤎 February 2026 – Exam + Data Skills Upgrade
- [ ] **Month Complete**

- [ ] **Fabric / DP-600 (Mon & Fri, plus some Tue/Thu if needed)**
  - [ ] Weeks 1–2:
    - [ ] At least one more full DP-600 practice test.
    - [ ] Patch weak areas with small improvements to the AdventureWorks project or mini design exercises.
  - [ ] **Take DP-600 exam** mid-month (or by end of month at the latest).

- [ ] **Fabric project (Tue & Thu, 1h/day)**
  - [ ] After exam:
    - [ ] Formalise your AdventureWorks work as a **migration case study**:
      - [ ] “Original SQL schema → Lakehouse design → Bronze/Silver/Gold model.”
      - [ ] Include diagrams and trade-off notes.
    - [ ] Optionally add a **Power BI report/dashboard** on top of the AdventureWorks Gold layer.

- [ ] **Python (Wed, 1h/week)**
  - [ ] Continue with **Pandas**:
    - [ ] Joins/merges between DataFrames.
    - [ ] `groupby` with aggregations.
    - [ ] Cleaning: missing values, type conversions, simple outlier handling.
  - [ ] Apply these directly to:
    - [ ] CSV practice datasets (or AdventureWorks-like sample exports).

- [ ] **Review**
  - [ ] Write a LinkedIn post:
    - “What I learned preparing for and taking DP-600 (using AdventureWorks in Fabric).”

- [ ] **Stretch goal**
  - [ ] Start **PySpark basics** in Fabric notebooks.
  - [ ] Refactor one small Silver transformation from SQL into PySpark (using an AdventureWorks table).

---

## 🗓 Weekly Rhythm (Reference)

- **Monday & Friday (2h each)**  
  - Nov–Dec: SQL DBA course (Sections 7–10).  
  - Jan–Feb: DP-600 prep + AdventureWorks Fabric advanced work.

- **Tuesday & Thursday (1h each)**  
  - AdventureWorks Fabric project: Bronze/Silver/Gold, governance, migration case study, portfolio polish.

- **Wednesday (1h)**  
  - Until early Jan: Codecademy **Learn Python 3**.  
  - After: **Pandas**, then a bit of **PySpark** on realistic datasets.

---