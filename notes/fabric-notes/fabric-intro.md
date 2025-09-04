# Fabric Introduction

 ### **Session Intent (04/09/2025):** Learn what Fabric is and how its Key components (OneLake, Data factory, LakeHouse, PowerBi) fit together.

 ## <u>**What is Microsoft Fabric?**</u>

 Current Understanding: 

 Fabric is a Data platform that unifies the Data Movement process. It incapsulates all stages of the data lifecycle e.g. Ingestion, Organisation, Consumption. It uses AI to analyse data allowing for efficient reporting/assurance. It is ran on Microsoft SQL Server at its heart and can be used to optimise reports/queries, backup/restore data and uses pipelines which are similar to processes that were originally created via SSIS.

### **Capabilities of Fabric**

- **Role-Specific Workloads:** Customized solutions for various roles within an Organisation, providing each user with the necessary tools.
- **OneLake:** A unified data lake that simplifies data management and access.
- **CoPilot support:** AI-driven features that assist users by providing intelligent suggestions and automating tasks.
- **Integration with Microsoft 365:** Seamless integration with Microsoft 365 tools, enhancing collaboration and productivity across the organisation.
- **Azure AI Foundry:** Utilizes Azure AI Foundry for advanced AI and machine learning capabilities, enabling users to build and deploy AI models efficiently.
- **Unified Data Management:** Centralized data discovery that simplifies governance, sharing and access

### **Unification with SaaS Foundation**

As a SaaS, Fabric unifies new and existing components from Power BI, Azure Synapse Analytics, Azure Data Factory and more into a single environment.

![image](/data_learning_journey/images-diagrams//UnifiSaas.png)

Fabric integrates workloads like Data Engineering, Data factory, Data science, Data warehouse, Real-Time Intelligence, Industry Solutions, Databases and Power BI into a SaaS platform. Each of these workloads is tailored for distinct user roles like Data engineers, Scientists, or warehousing professionals, and they serve a specific task.

#### **Advantages of Fabric**

- End to end integrated Analytics
- Consistent, user-friendly experiences
- Easy access and reuse of all assets
- Unified data lake storage preserving data in its original location
- AI-Enhanced stack to accelerate the data journey
- Centralized administration and governance

## **Components of Microsoft Fabric**

- **Power BI** - Power BI lets you connect to your data sources, visualise (see the data), and decide what's important. it can be shared with anyone or everyone that you want. This integrated experience allows business owners to access all data in Fabric and intuitively and make better decisions with data.
- **Databases** - Databases in Microsoft Fabric are transactional databases, such as Azure SQL database, which allows you to easily create your operational database in Fabric. Using ***mirroring capabilities(?)*** you can bring data from various systems, together in OneLake. You can continuously replicate your existing data estate directly into Fabric's OneLake, including data from Azure SQL database,  Azure Cosmos DB, Azure Databricks, Snowflake and Fabric SQL Database.
- **Data Factory** - Data Factory provides a modern data integration experience to ingest, prepare, and transform data from a rich set of data sources. It incorporates the simplicity of ***Power Query(?)***, and you can use more than 200 native connectors to connect to data sources on-premises and in the cloud.
- **Industry Solutions** - Fabric provides industry-specific data solutions that address unique industry needs and challenges, and include data management, analytics, and decision-making. 
- **Real-time Intelligence** - Real-time Intelligence is an end-to-end solution for event-driven scenarios, streaming data, and data logs. It enables the extraction of insights, visualization, and action on data in motion by handling data ingestion, transformation, storage, modelling, analytics, visualization, tracking, AI, and real-time actions. The Real-Time hub in Real-Time Intelligence provides a wide variety of no-code connectors, converging into a catalog of organizational data that is protected, governed, and integrated across Fabric.
- **Data Engineering** - Fabric Data Engineering provides a Spark platform with great authoring experiences. It enables you to create, manage, and optimize infrastructures for collecting, storing, processing, and analysing vast data volumes. Fabric Spark's integration with Data Factory allows you to schedule and orchestrate notebooks and Spark jobs. 
- **Fabric Data Science** - Fabric Data Science enables you to build, deploy, and operationalize machine learning models from Fabric. It integrates with Azure Machine Learning to provide built-in experiment tracking and model registry. Data scientists can enrich organizational data with predictions and business analysts can integrate those predictions into their BI reports, allowing a shift from descriptive to predictive insights. 
- **Fabric Data Warehouse** - Fabric Data Warehouse provides industry leading SQL performance and scale. It separates compute from storage, enabling independent scaling of both components. Additionally, it natively stores data in the open Delta Lake format.

- *Data Mirroring:* https://learn.microsoft.com/en-us/fabric/mirroring/overview
- *Data Factory:* https://learn.microsoft.com/en-us/fabric/data-factory/data-factory-overview
- *Real-Time Intelligence:* https://learn.microsoft.com/en-us/fabric/real-time-intelligence/overview
- *Data Engineering:* https://learn.microsoft.com/en-us/fabric/data-engineering/data-engineering-overview
- *Fabric Data science:* https://learn.microsoft.com/en-us/fabric/data-science/data-science-overview
- *Fabric Data warehouse:* https://learn.microsoft.com/en-us/fabric/data-warehouse/data-warehousing

Fabric enables organizations and individuals to turn large and complex data repositories into actionable workloads and analytics, and is an implementation of data mesh architecture.

#### **Session Conclusion:**

Fabric is an All-in-One platform for managing data as an organisation. It combines current Workloads and introduces new workloads to allow users to achieve specific roles. PowerBI allows business users to visualise data themselves to strip away noise and share this with whoever necessary. Databases, Data factory and Data Engineering allow for control over the whole Data lifecycle; mirroring allows for exact data estate replication which can then be consumed by the Data Factory and Data Engineering components. Data Factory can ingest and prepare data through the use of Power Query and can connect to a multitude of Data Sources including On-Premises and In the cloud. Data Engineering allows the creation of infrastructure to optimise, collection, storage, processing and analysing of vast data volumes. Real-Time Intelligence allows for insight into Data-in-motion within the organisation by monitoring the entire data lifecycle. Fabric Data Science and Data warehouse are new workloads which are used to 1. provide proactive insights into BI reports through the use of AI and machine learning and 2. to provide SQL performance and scale through the separation of compute from storage, enabling independent scaling of both components. 

### Next session continue to OneLake and data flow