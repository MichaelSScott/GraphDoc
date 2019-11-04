/****** Object:  UserDefinedTableType [GraphDoc].[udtt_DependencyGraph]    Script Date: 04/11/2019 12:42:40 ******/
CREATE TYPE [GraphDoc].[udtt_DependencyGraph] AS TABLE(
	[ServerName] [nvarchar](255) NULL,
	[DBName] [nvarchar](255) NULL,
	[BaseObjectName] [nvarchar](255) NULL,
	[BaseObjectType] [nvarchar](255) NULL,
	[ParentObjectName] [nvarchar](255) NULL,
	[ParentObjectType] [nvarchar](255) NULL,
	[SchemaName] [nvarchar](255) NULL,
	[ThisObjectName] [nvarchar](255) NULL,
	[ThisObjectType] [nvarchar](255) NULL,
	[Level] [smallint] NULL,
	[referenced_database_name] [nvarchar](255) NULL,
	[referenced_server_name] [nvarchar](255) NULL,
	[srcdest] [tinyint] NULL,
	[loc] [int] NULL
)