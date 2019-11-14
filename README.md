# GraphDoc
Draw graphs of stored procedure calls and object usage.

## Prerequisites
Some use of the string_split() t-sql command in the dependency table generator so your database needs 
a minimum compatibility level 130 (i.e. SQL Server 2016 or higher).

You will need to have [GraphViz](https://www.graphviz.org) installed to render the diagrams.

## Installation
Clone and open in Visual Studio, from where you can publish to the database of your choice. Or, if you copy the scripts and execute them directly in a database remember to create the schema 'GraphDoc' first.

## Usage
See the wiki for a more comprehensive overview.
### Procedure Graphs
There are three parts to producing the final diagram; 
1. create a dependency table for the procedure
2. pass the dependency table to the graph file generator
3. run the GraphViz *dot* command to create the graphical output

The first two parts are run in sql script. The last part from the command line

In SSMS 
```sql
-- Set SQLCMD mode on to allow output to file system.
:out folderPath\uspHubConsumeFMPOChanges_Y.gv 

DECLARE @dep [GraphDoc].[udtt_DependencyGraph]

Insert into @dep
Select distinct * from [GraphDoc].[udf_cs_DepTable] ('DUAL', 'uspHubConsumeFMPOChanges')

SET NOCOUNT ON
DECLARE @RC int

EXECUTE @RC = [GraphDoc].[usp_cs_DrawDependencyGraph] 
   @dep
  ,@FriendlyName  = 'HubConsumeFMPOChanges'
  ,@direction = 'LR'  
  ,@overview='Y'
  ,@description='Part of the integration hub'
GO
```

Dot command
```
dot -Tsvg HubConsumeFMPOChanges.gv > HubConsumeFMPOChanges.svg
```
To get
![GraphDoc](/images/Hub_Y.png)

You could do the whole thing on the command line. Put the sql above into a script, then something like
```cmd
sqlcmd -S "myServer\myInstance" -d myDBName -i "script.sql" -E -h -1 | dot  -Tsvg > myFile.svg
```

### Job Graphs
You can also pass an SQLServer agent job name and produce a diagram showing an overview of the job and
the individual steps that make it up.

In SSMS
```sql
:out myFolder\graphtest.gv 

DECLARE @RC int

EXECUTE @RC = [GraphDoc].[usp_cs_Job_Graphs] 
   @JobName = 'GraphTest'

GO

```
A sample of the output:
![GraphDoc](/images/job.png)

## Licence
MIT
