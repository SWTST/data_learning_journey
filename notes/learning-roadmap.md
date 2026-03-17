# Data Engineering Career Roadmap

**Role:** Junior SQL Server DBA → Data Engineer  
**Organisation:** Atrium Underwriting, London  
**Last Updated:** March 2026  
**Status:** Active

---

## The Rules (Non-Negotiable)

These exist because you've identified a pattern of dropping plans after ~2 months. Every design decision below works against that tendency.

1. **Book exams before you feel ready.** Pay the fee. Put the date in your calendar. The discomfort of a looming deadline is your best friend.
2. **Physical weekly calendar on your desk/wall.** Every Sunday evening, write out next week's study blocks by hand. Cross them off as you go. If you miss one, it stares at you.
3. **30 minutes beats 0 minutes.** A bad study session is infinitely better than a skipped one. If you're tired, do 30 minutes of flashcards instead of nothing.
4. **Pair study with work.** Every concept you learn, try to apply at Atrium within the same week. This doubles retention and builds your internal reputation.
5. **Weekly checkpoint.** Every Friday, spend 10 minutes writing a short entry in this repo: what you studied, what you applied, what confused you. This is your accountability log.

---

## Phase 1: DP-300 — Azure Database Administrator Associate

**Duration:** 10 weeks  
**Target exam date:** Late May / Early June 2026  
**Action:** Book the exam NOW for ~10 weeks from today.

### Why this first

You're working as a DBA daily. DP-300 reinforces and formalises what you're already doing. It covers on-premises SQL Server *and* Azure SQL, which means you're building cloud skills on top of your existing foundation rather than starting from scratch.

### Exam Domains & Weekly Plan

| Week | Domain | Topics | Hours | Apply at Work |
|------|--------|--------|-------|---------------|
| 1–2 | **Plan & Implement Data Platform Resources** (20–25%) | Deploy Azure SQL DB, Managed Instance, SQL on VMs. Understand automated deployment. Evaluate migration strategies. Table partitioning & sharding. | 5–6 hrs/wk | Audit current Atrium SQL estate. Document what's on-prem vs cloud. |
| 3–4 | **Implement a Secure Environment** (15–20%) | Entra ID auth, TDE, Always Encrypted, firewall rules, TLS, data masking, row-level security, Microsoft Defender for SQL, database ledger. | 5–6 hrs/wk | Review current security posture of a dev database. Propose one improvement to your manager. |
| 5–6 | **Monitor, Configure & Optimise** (20–25%) | Query Store, DMVs, Extended Events, SQL Insights, database watcher, execution plans, index maintenance, statistics, automatic tuning, IQP. | 5–6 hrs/wk | Enable Query Store on a dev instance. Identify and tune one slow query. Document it. |
| 7–8 | **Automation of Tasks** (15–20%) | SQL Agent jobs, ARM/Bicep templates, PowerShell & Azure CLI deployment, elastic jobs. | 5–6 hrs/wk | Automate one routine maintenance task you currently do manually. |
| 9 | **High Availability & Disaster Recovery** (20–25%) | RPO/RTO planning, backup strategies, geo-replication, Always On AGs, failover groups, log shipping. | 5–6 hrs/wk | Map Atrium's current HA/DR setup. Understand your RPO/RTO targets. |
| 10 | **Revision & Practice Exams** | Microsoft Learn practice assessment. Revisit weak areas. Timed mock exams aiming for 85%+. | 8–10 hrs | — |

### Weekly Study Structure (Physical Calendar Template)

```
Monday      06:45–07:30   Study (theory / Microsoft Learn module)
Tuesday     06:45–07:30   Study (hands-on lab in Azure free tier)
Wednesday   —             REST (or catch-up if you missed Mon/Tue)
Thursday    06:45–07:30   Study (practice questions / flashcards)
Friday      17:30–18:00   Weekly checkpoint entry in this repo
Saturday    09:00–11:00   Deep study block (labs + revision)
Sunday      20:00–20:30   Write out next week's physical calendar
```

Adjust times to your life — the point is that the *slots are specific and written down physically*.

### Key Resources

- **Microsoft Learn DP-300 Learning Path** (free, official, hands-on)
- **Microsoft Learn Practice Assessment** (free, official mock exam)
- **Azure free tier** — spin up Azure SQL Database for hands-on labs
- **John Savill's YouTube** — excellent Azure infrastructure explanations
- **Data Exposed** (Microsoft Learn show) — short videos on SQL topics
                         
---

## Phase 2: DP-700 — Fabric Data Engineer Associate

**Duration:** 10–12 weeks  
**Target exam date:** August / September 2026  
**Action:** Book the exam within 1 week of passing DP-300. Keep momentum.

### Why this second

DP-700 shifts you from *administering* databases to *engineering* data pipelines. This is the cert that signals you're moving toward data engineering. Microsoft Fabric is where the entire Microsoft data stack is converging, and early adopters have a significant advantage in the job market.

### Exam Domains & Weekly Plan

| Week | Domain | Topics | Hours |
|------|--------|--------|-------|
| 1–2 | **Fabric Fundamentals & Workspace Config** | Fabric architecture, OneLake, Spark settings, domain settings, data workflow settings, licensing. | 5–6 hrs/wk |
| 3–4 | **Lifecycle Management & Security** | Git integration, deployment pipelines (Dev→Test→Prod), database projects, workspace/item-level access, RLS, CLS, sensitivity labels, OneLake security. | 5–6 hrs/wk |
| 5–6 | **Orchestration & Loading Patterns** | Pipelines vs notebooks vs Dataflow Gen2, schedules & triggers, parameters, full vs incremental loads, dimensional model prep. | 5–6 hrs/wk |
| 7–8 | **Ingesting & Transforming Data** | Shortcuts, mirroring, PySpark transformations, Power Query (M), SQL, KQL, deduplication, late-arriving data. Lakehouse & Warehouse patterns. | 5–6 hrs/wk |
| 9–10 | **Streaming & Real-Time Intelligence** | Eventstreams, Spark structured streaming, KQL, windowing functions, real-time intelligence storage options. | 5–6 hrs/wk |
| 11 | **Monitoring & Optimisation** | Monitor pipelines/dataflows/notebooks, lakehouse table optimisation, V-Order, compaction, Spark tuning, query performance. | 5–6 hrs/wk |
| 12 | **Revision & Practice Exams** | Full mock exams, weak area deep-dives, timed practice. Target 85%+. | 8–10 hrs |

### Key Resources

- **Microsoft Learn DP-700 Learning Path** (free, official)
- **Microsoft Fabric Trial** (60-day free trial — time this to start with your study)
- **Coursera: Exam Prep DP-700** by Whizlabs (structured video course)
- **Microsoft Fabric Blog** & **Tech Community** (stay current; Fabric evolves fast)
- **FabCon recordings** (conference talks on real-world Fabric implementations)

---

## Phase 3: Portfolio & AI Integration (Ongoing — Start Alongside Phase 2)

### Philosophy

Your portfolio should demonstrate three things:
1. You can build end-to-end data pipelines (not just query databases)
2. You understand the insurance/underwriting domain
3. You use AI as a tool to accelerate your work, not as a gimmick

### Project Ideas (Pick 2–3 Over 6 Months)

#### Project 1: Insurance Claims Data Pipeline
**Skills demonstrated:** Data engineering, domain knowledge, Fabric  
Build a pipeline that ingests synthetic insurance claims data (CSV/API), transforms it (clean, deduplicate, enrich with geography data), loads into a Fabric Lakehouse, and surfaces a Power BI dashboard showing claims trends by region, policy type, and time.  
**AI angle:** Use Claude/GPT to generate the synthetic data, write transformation logic, and document the pipeline.

#### Project 2: AI-Assisted SQL Query Optimiser
**Skills demonstrated:** DBA expertise, AI integration, Python  
Build a tool (Python + Claude API) that takes a slow SQL query and its execution plan as input, and returns optimisation suggestions with explanations. Test it against real (anonymised) queries from your DBA work.  
**AI angle:** This IS the AI project. Shows you understand both SQL performance and how to integrate AI into practical DBA workflows.

#### Project 3: London Market Data Standards Explorer
**Skills demonstrated:** Domain expertise, data modelling, web development  
Create an interactive tool that maps and explains London Market data standards (e.g., ACORD, Lloyd's CDR). Ingest publicly available documentation, transform it into a structured knowledge base, and build a simple search/explore interface.  
**AI angle:** Use AI to parse and structure the documentation, generate summaries, and power the search.

#### Project 4: Automated Database Documentation Generator
**Skills demonstrated:** Automation, AI integration, practical DBA value  
Build a script that connects to a SQL Server database, extracts schema metadata, and uses AI to generate human-readable documentation — table descriptions, relationship maps, data dictionary. This is something every DBA team needs and nobody has time to do.  
**AI angle:** Core to the project. Demonstrates AI as a practical productivity tool.

### Portfolio Presentation

- Host on GitHub with clear READMEs
- Each project should have: Problem statement → Architecture diagram → Setup instructions → Results/screenshots
- Write a brief blog post for each project (Medium or personal site) explaining what you learned

---

## Phase 4: Ongoing Growth & Positioning (Month 7+)

### Skills to Develop Incrementally

| Skill | Why | How |
|-------|-----|-----|
| **Python** | Data engineering lingua franca. PySpark for Fabric. | Use it in your portfolio projects. No separate course needed — learn by doing. |
| **Git** | Version control is non-negotiable for DE. | You already have a repo. Use it actively. Commit weekly. |
| **Insurance domain knowledge** | Makes you irreplaceable. AI can't replicate deep domain context. | Read Lloyd's market publications. Attend Atrium internal talks. Ask underwriters questions. |
| **AI tooling fluency** | Using Claude/Copilot daily makes you faster and signals you're forward-thinking. | Use AI in your daily DBA work: writing queries, documenting, troubleshooting, drafting comms. |
| **Power BI basics** | Complements Fabric. Data engineers who can build dashboards are rare and valued. | Build dashboards for your portfolio projects. |
| **Networking** | London insurance data community is small. Being known matters. | Attend SQLBits, Fabric User Group London, London Data Engineering meetups. |

### Internal Career Strategy at Atrium

- **Make your learning visible.** Tell your manager about your certification goals. Ask if Atrium will fund the exams (many London market firms do).
- **Volunteer for data projects.** When migration or modernisation work comes up, raise your hand.
- **Build relationships with the data/analytics team.** Understand their pain points. Position yourself as the DBA who speaks their language.
- **Document everything you improve.** Kept a query from 30 seconds to 2 seconds? Write it up. Automated a manual process? Record the before/after. This becomes your internal promotion case AND your interview evidence.

---

## Accountability Tracker

Use this table to log weekly progress. Copy/paste a new row each Friday.

| Week Starting | Phase | Hours Studied | Key Topic | Applied at Work? | Notes |
|---------------|-------|---------------|-----------|------------------|-------|
| 2026-03-17 | 1 | — | — | — | *Start here* |

---

## Calendar Milestones

| Date | Milestone |
|------|-----------|
| March 2026 | Book DP-300 exam. Start Phase 1. |
| Late May 2026 | Sit DP-300 exam. |
| June 2026 | Book DP-700 exam. Start Fabric trial. Begin Phase 2. Start first portfolio project. |
| Aug/Sep 2026 | Sit DP-700 exam. |
| Sep–Dec 2026 | Complete 2–3 portfolio projects. Attend 1–2 community events. |
| Dec 2026 | Review year. Two certs earned. Portfolio live. Internal reputation growing. |

---

## If You Fall Behind (And You Might — That's OK)

The goal is not perfection. The goal is *recovery speed*.

- **Missed a week?** Don't try to "catch up" by doubling next week. Just resume normal pace and push the exam back 1 week if needed.
- **Missed two weeks?** Write a short honest entry in this repo about why. Then do ONE 30-minute session to break the inertia. Momentum matters more than volume.
- **Feeling overwhelmed?** Drop to the minimum: 3 sessions per week, 30 minutes each. That's still 90 minutes of progress.
- **Considering giving up entirely?** Remember why you started. Re-read this document. Then just do 30 minutes.

The physical calendar and the exam deadline exist precisely for these moments. They create just enough friction to get you back on track.

---

*"The best time to plant a tree was 20 years ago. The second best time is now."*
