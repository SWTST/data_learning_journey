General Post structure

Intro:
- What is the post?
- Reasons for starting
- What topics am I learning and why (summary)
- Where I am documenting progress/notes

Topic Paragraphs (4):
- Content covered in 2 months
- What learning techniques am I using?
- How effective am I finding the techniques?

Conclusion:
- How I'm maintaining commitment to learning
- What is my target short term and long term for each topic or in general

Intro

The intention of this post is to share my current progress in my learning journey and, hopefully, help inspire others to start their own. I think its too easy to assume that you will understand something given time and repetition, which is true, especially if you are consistently facing new venues for learning day-in and out. However, I'd say that for the majority of people, work can become repetitive and familiar leading to less opportunities to learn and therefore slows or stagnates learning. In a changing tech world, now more than ever, it is vital to stay relevant considering the rise of new technologies and how they integrate and elevate current solutions and ways of working.

The topics I am covering in my current 6 month syllabus are below:

- MSSQL for Database Administration and development, since this is core to my role and an imperative RDBMS in the industry. 
- SQL Query Tuning; deserving of its own section in my schedule considering the titan that the SQL Query Processor can be and that proficiency will be utilised in data manipulation in general and can be applied to any SQL technology
- Microsoft Fabric in the spirit learning new technologies, fabric is central in this space as it is revolutionary in its nature of having all platforms in one space.
- Python to support my effectiveness in Fabric as it is industry-leading for Data Science and file manipulation.

MSSQL
Since SQL is core to my Role as a DBA  I have built my understanding naturally whilst building my experience. As it stands, I have 1 year and 8 months experience in my current role. I've had exposure to the Syntax, worked with SQL Agent jobs & Stored procedures, managed database workloads and efficiency, and have been hands on with Server, Network and Always-On AG configuration. 

The majority of my learning outside work has been working through an MSSQL DBA Udemy Course and filling in my knowledge gaps. The main benefits I've felt, so far, is learning the specific constraints and nuances to SQL statements. Since my role is not development oriented it's given me an opportunity to build that understanding and inspired me to start developing my own SQL projects. One, being a budget tool to manage my own finances and two, to attempt,  to conduct a general data analysis of the UK housing market. 

SQL Query Tuning
I think a strong understanding of the SQL Query Processor is built through exposure. My understanding currently looks like a list of DO's and DONT's but, with that considered, I've learned a great deal about how to make query's go faster. I've worked with indexes to improve execution times and understand that writing a query is an art form. It's one thing making a query that compiles and returns data, and its another thing entirely to write a query with the engine and your data in mind. As a DBA it is paramount to get your estimates and considerations accurate: you only want to touch as much data as you need and you don't want to store anything you wont use. I hope to continue to build my knowledge on Query tuning; working with Query plans, SQL Sentry and Brent Ozar's First responder kit to drill down into exactly what is slowing down my production servers.

Microsoft Fabric
My current experience with Fabric has been positive as it is very intuitive. Pipelines are very similar to SSIS and the way connections are handled for SQL databases is very easy to digest and use. My main issue has been understanding the differences in syntax between SQL and Spark SQL and also understanding the constraints with DDL and DML statements. My main way of learning has been through projects that I have set for myself. My initial task was to Load a CSV into a table via a pipeline and setup validation and error logging which I achieved with little issue. My current project is to simulate a real-world style migration for the AdventureWorks database using a medallion architecture. Since data engineering is new to me the journey so far has been difficult with my progress slowing at the silver stage but I'm learning with each session and it is broadening my understanding around data manipulation. I plan to work through a fabric course to fill in knowledge gaps that I have and also aim to obtain a DP-600 certification in February/March 2025.

Python
My history with Python has been on and off. I initially built a rudimentary understanding of Python during my time at Secondary School from 2014-2017, working to understand basic programming constructs: Variables, Sequence, Selection & Iteration as well as, List manipulation. Not touching work with files or classes, that's where I dropped Python learning. Although, with the rise of Fabric, and its utilisation of Python, it's rekindled my motivation and desire to gain a deep understanding of Python. Currently, I'm working through a course on Codeacademy "Learn Python 3", which covers all basic functionality in Python 3, some of which: Control Flow, Loops, Lists, Functions, Classes, Files. A few of the course concepts I have already studied but the learning is conducted in a practical way with yourself actually writing python to a brief, so it has been helpful to build a solid foundation and good habits. My plan is to work through the multitude of courses on Codeacademy and Pivot to working on my own projects with Python, working with files and data to simulate real world scenarios and requirements.



ChatGPT suggestion:
# My Learning Summary (SQL Server, Query Tuning, Fabric & Python)
## <u>**Mid-August - Present**</u>

Since late August I’ve been following my own 6-month learning plan alongside my role as a Junior DBA, and I wanted to share what I’ve been working on and how I’m approaching it.

It’s easy to assume you’ll keep learning just by showing up to work. But once a role becomes familiar, the learning curve can "fall off" and development slows. In a fast-moving tech world, with platforms like Fabric and newer data engineering practices emerging all the time, I’ve realised I learn best when I’m intentional about it. So I’ve put together a simple 6-month plan and wanted to share what I’m doing in case it gives anyone else ideas for their own journey.

Over this 6-month syllabus I’m focusing on:

- **SQL Server (MSSQL)** Core to my current role. Database administration and development.  
- **SQL query tuning** to really understand the query processor and make workloads go faster.  
- **Microsoft Fabric** as a modern, end-to-end data platform.  
- **Python** to support Fabric work and general data manipulation.

 ###   I’m documenting progress through structured notes and small side projects so I can see how my skills are actually changing over time. All of my notes, including this post, are taken in the repository below: 
 - https://github.com/SWTST/data_learning_journey/tree/main

### Please feel free to take a look if you have the time and I'm open to suggestions of projects I can try or ways that I can improve my self-study sessions.

---

## SQL Server (MSSQL)

SQL Server is at the heart of my role, and I now have around **1 year and 8 months** experience as a DBA. In that time I’ve:

- Managed database workloads, access and performance  
- Worked with SQL Agent jobs and stored procedures  
- Been hands-on with server, network and Always On AG configuration  

Over the last couple of months, my main focus outside work has been a SQL Server DBA course on Udemy to fill in gaps and sharpen my understanding of T-SQL's behaviour and constraints.

Because my role isn’t development-heavy, this has also pushed me to start **building my own SQL projects**, including:

- A budgeting tool to manage my personal finances  
- A dataset and analysis project on the **UK housing market**  

This has allowed me to apply theory in real use cases and helped make the learning stick.

---

## SQL Query Tuning

My understanding of the SQL query processor is still evolving, but it’s already moved beyond a simple list of “do this / don’t do that”.

Recently I’ve been:

- Spending more time reading and understanding execution plans 
- Working with indexes to improve execution times  
- Using tools like SQL Sentry and Brent Ozar’s First Responder Kit to identify problem queries  

The big shift for me has been realising that **writing a query is an art form**. It’s one thing to write something that compiles and returns the right result; it’s another to write it with the engine and your data in mind.

As a DBA, being precise about estimates and data access patterns is paramount. You only want to touch as much data as you need, and you don’t want to store what you’ll never use. My goal over the next few months is to deepen this by systematically working through more execution plans and real production issues.

---

## Microsoft Fabric

My early experience with Fabric has been positive, it feels intuitive, and pipelines are reassuringly similar to SSIS. The way connections are handled for SQL databases has also been straightforward.

My main learning has come from **self-set projects**, for example:

- Loading a CSV into a table via a pipeline, with validation and error logging  
- A larger ongoing project: simulating a real-world style migration for the AdventureWorks database using a medallion architecture  

Data engineering is new to me, and my progress has definitely slowed around the Silver layer, but each session is teaching me more about data modelling and transformation.

Going forward, my next steps will be:
- Work through a structured Fabric course to close knowledge gaps  
- Aim for **DP-600 certification** around February/March 2025  

---

## Python

I first learned Python at secondary school, focusing on basics like variables, control flow, lists and loops, and I stepped away before ever working with files or classes. Fabric has brought Python back to the forefront for me, and I want a deeper understanding of the language.

Currently, I’m working through **Codecademy’s “Learn Python 3”**, which covers:

- Control flow and loops  
- Lists and functions  
- Classes  
- Working with files  

Some of this is a refresher, but the practical, brief-driven style of the course, has been useful for building better habits and confidence.

My plan is to:

- Work through more of Codecademy’s Python content  
- Pivot towards my own Python projects, especially around **file and data manipulation**, to better simulate real-world scenarios and integrate Python with my Fabric work  

---

## How I’m staying committed – and what’s next

To stay consistent I’m:

- Blocking out dedicated study time each weekday  
- Structuring my learning in 6-month syllabus' 
- Anchoring everything to either my current DBA responsibilities or realistic future projects

**Short-term (next 3–6 months):**

- Solidify my SQL Server fundamentals and query tuning skills  
- Complete a structured Fabric course and progress my AdventureWorks medallion project  
- Finish my current Python track and build 1–2 small, end-to-end projects  

**Long-term:**

- Grow into a DBA/data professional who can move comfortably across **database administration, performance tuning and modern data engineering tools** like Fabric and Python.

If you’re also learning in this space – SQL Server, Fabric, Python, or query tuning – I’d love to hear what you’re working on and which resources you’ve found most helpful. If you've read this far, I appreciate it, and I hope I've inspired you to start your own self learning journey!
