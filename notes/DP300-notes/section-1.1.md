# **(1.1)** Plan & Implement Data Platform Resources

## Sub-Sections

### Theory:

- [ ] **(1.11)** Deploy Azure SQL DB, Managed Instance, SQL on VMs — when to use each 
- [ ] **(1.12)** Automated deployment (ARM/Bicep templates)
- [ ] **(1.13)** Migration strategies — online vs offline, Azure Migrate, DMS
- [ ] **(1.14)** Table partitioning & database sharding concepts
- [ ] **(1.15)** Configuring scale & performance (DTUs, vCores, elastic pools, read replicas)

### Practical:
- [ ] **(1.16)** Deploy an Azure SQL Database using the Azure free tier
- [ ] **(1.17)** On SQL Express, create a partitioned table with sample data

### Applied:
- [ ] **(1.18)** Audit Atrium's SQL estate — document what's on-prem vs cloud


## **(1.11)** Deploy Azure SQL DB, Managed Instance, SQL on VMs — when to use each 

There are 3 products within the Azure SQL family:

- Azure SQL Database (PaaS)
  - Azure SQL Database Hyperscale
- Azure Managed Instances (PaaS)
- SQL Server on Azure VMs (IaaS)

Below is a table that compares how the responsibilities differ between each Azure SQL Product.

| Responsibility | Azure SQL Database | Azure SQL Managed Instance | SQL Server on Azure VM |
|---|---|---|---|
| **Physical Hardware** | Microsoft | Microsoft | Microsoft |
| **Networking (Host)** | Microsoft | Microsoft | Microsoft |
| **Operating System** | Microsoft | Microsoft | Customer |
| **OS Patching & Updates** | Microsoft | Microsoft | Customer |
| **SQL Server Installation** | Microsoft | Microsoft | Customer |
| **SQL Server Patching** | Microsoft | Microsoft | Customer |
| **High Availability** | Microsoft (built-in) | Microsoft (built-in) | Customer (configure Always On, FCIs, etc.) |
| **Automated Backups** | Microsoft (built-in) | Microsoft (built-in) | Customer (can use Azure Backup for SQL) |
| **Disaster Recovery** | Microsoft (geo-replication, auto-failover groups) | Microsoft (auto-failover groups) | Customer (configure manually) |
| **Database Creation & Design** | Customer | Customer | Customer |
| **Index & Query Tuning** | Customer (with built-in intelligence) | Customer (with built-in intelligence) | Customer |
| **Security & Access Control** | Customer | Customer | Customer |
| **Data Encryption (TDE)** | Microsoft (enabled by default) | Microsoft (enabled by default) | Customer (configure manually) |
| **Compliance & Auditing** | Shared | Shared | Customer |
| **Scaling** | Customer (choose tier/DTUs/vCores) | Customer (choose vCores) | Customer (resize VM) |

---
SQL Server on Azure VMs is IaaS and the others are PaaS. This means that it is the most configurable option but also comes with the most work and responsibility. The User has full control over everything other than the Network and Hardware.
        
Azure SQL Database and Azure SQL Managed Instance are offered and 'pre-built' by Microsoft. The user is only responsible for the database design including Performance tuning, Security and Scaling via the Azure portal.

### Azure SQL Database

Azure SQL Database is a DBaaS hosted in Azure and falls in the PaaS category.

It is best for Modern Cloud applications that wanted to use the latest stable version of SQL Server with time constraints present in Development or Marketing.

Azure SQL Database offers the following Deployment options:

- A single database with its own set of resources managed by a logical server. A single database is similar to a contained database in SQL Server. Hyperscale and Serverless options are available. 
- An elastic pool which is a collection of databases using a shared set of resources managed via a logical server. Single databases can be moved into and out of an elastic pool

### Azure SQL Managed Instances

Azure SQL Managed instances falls into the PaaS category and is usually the best for most migrations into the cloud.    An Instance of SQL managed instance is a collection of system and user databases with a shared set of resources that is lift and shift ready.

It is best for new applications or existing on-prem applications that want to use the latest stable version of SQL Server and that are migrated to the cloud with minimal changes.

SQL Managed instances supports database migration from on-prem to the cloud with minimal database changes. This option provides all of the PaaS benefits of Azure SQL database but adds additional capabilities.

### SQL Server on Azure VMs

SQL Server on Azure VMs falls into the IaaS category and allows SQL Server to be run on a fully managed virtual machine.

It is best for migrations and applications that require OS-Level access. SQL virtual machines are lift and shift ready for existing applications that require fast migration to the cloud with minimal changes. They offer full control over the SQL server instance and underlying OS.


