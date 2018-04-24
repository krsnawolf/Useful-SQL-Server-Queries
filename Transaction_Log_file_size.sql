SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'dbo.TLogSqlPerf', N'P') IS NOT NULL DROP PROCEDURE dbo.TLogSqlPerf;
GO

CREATE PROCEDURE dbo.TLogSqlPerf
(
	@p_DbName	NVARCHAR(200) = ''
)
AS

SET NOCOUNT ON;

DECLARE @t TABLE 
(
	DatabaseName	NVARCHAR(128),
	LogSizeMB	DECIMAL(18,5),
	LogUsedPct	DECIMAL(18,5),
	[Status]	INT
)
INSERT INTO @t
(
	DatabaseName,
	LogSizeMB,
	LogUsedPct,
	[Status]
)
EXEC sp_executesql N'DBCC SQLPERF(logspace) WITH NO_INFOMSGS'

SELECT
	DatabaseName,
	LogSizeMB,
	LogUsedPct,
	[Status]
FROM @t
WHERE DatabaseName LIKE '%' + @p_DbName + '%'
ORDER BY DatabaseName

RETURN 0;

SET NOCOUNT OFF;
