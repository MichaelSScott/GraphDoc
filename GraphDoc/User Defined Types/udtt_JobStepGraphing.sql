/****** Object:  UserDefinedTableType [GraphDoc].[udtt_JobStepGraphing]    Script Date: 04/11/2019 12:55:58 ******/
CREATE TYPE [GraphDoc].[udtt_JobStepGraphing] AS TABLE(
	[GeneratedName] [nvarchar](255) NULL,
	[IsReachable] [nvarchar](20) NULL,
	[jobname] [nvarchar](255) NULL,
	[description] [nvarchar](max) NULL,
	[steps] [int] NULL,
	[step_id] [int] NULL,
	[step_name] [nvarchar](255) NULL,
	[subsystem] [nvarchar](255) NULL,
	[command] [nvarchar](max) NULL,
	[database_name] [nvarchar](255) NULL,
	[runat] [varchar](15) NULL,
	[enabled] [int] NULL
)