# ⚙ SQL Tuning Examples

This section of my learning Journey is dedicated to understanding the SQL server engine and the query optimizer more deeply. I will following a structure of creating a query, recording execution times and then document my process trying to optimize the query whilst also learning how my actions effect the query's performance.


## Query 1 - AdventureWorks2022

This query contains the following:

- 3 table joins
- 3 where conditions 
- An Order by

```
SQL

SELECT p.FirstName,
p.LastName,
p.PersonType,
p.BusinessEntityID,
p.Demographics,
pp.PhoneNumber,
pt.Name
FROM [Person].[Person] p
INNER JOIN [Person].[PersonPhone] pp ON p.BusinessEntityID = pp.BusinessEntityID
INNER JOIN [Person].[PhoneNumberType] pt ON pp.PhoneNumberTypeID = pt.PhoneNumberTypeID
WHERE pt.Name LIKE 'Cell'
AND p.ModifiedDate >= '2010-01-01 00:00:00.000'
AND LastName NOT LIKE 'Adams'
ORDER BY p.BusinessEntityID ASC
```
The executions times and query plan, before tuning, are below:

 SQL Server Execution Times:
   CPU time = 78 ms,  elapsed time = 789 ms.

[! image](images-diagrams/Query1.png)
