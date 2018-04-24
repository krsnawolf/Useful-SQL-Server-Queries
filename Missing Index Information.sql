SELECT
   @@SERVERNAME AS [ServerName]
   , DB_NAME() AS [DatabaseName]
   , SCHEMA_NAME([sObj].[schema_id]) AS [SchemaName]
   , [sObj].[name] AS [ObjectName]
   , CASE [sObj].[type]
      WHEN 'U' THEN 'Table'
      WHEN 'V' THEN 'View'
      ELSE 'Unknown'
     END AS [ObjectType]
   , [sdmvMID].[equality_columns] AS [EqualityColumns]
   , [sdmvMID].[inequality_columns] AS [InequalityColumns]
   , [sdmvMID].[included_columns] AS [IncludedColumns]
   , [sdmvMIGS].[user_seeks] AS [ExpectedIndexSeeksByUserQueries]
   , [sdmvMIGS].[user_scans] AS [ExpectedIndexScansByUserQueries]
   , [sdmvMIGS].[last_user_seek] AS [ExpectedLastIndexSeekByUserQueries]
   , [sdmvMIGS].[last_user_scan] AS [ExpectedLastIndexScanByUserQueries]
   , [sdmvMIGS].[avg_total_user_cost] AS [ExpectedAvgUserQueriesCostReduction]
   , [sdmvMIGS].[avg_user_impact] AS [ExpectedAvgUserQueriesBenefitPct]
FROM 
   [sys].[dm_db_missing_index_details] AS [sdmvMID]
   LEFT JOIN [sys].[dm_db_missing_index_groups] AS [sdmvMIG]
      ON [sdmvMID].[index_handle] = [sdmvMIG].[index_handle]
   LEFT JOIN [sys].[dm_db_missing_index_group_stats] AS [sdmvMIGS]
      ON [sdmvMIG].[index_group_handle] = [sdmvMIGS].[group_handle]
   INNER JOIN [sys].[objects] AS [sObj]
      ON [sdmvMID].[object_id] = [sObj].[object_id]
WHERE
   [sdmvMID].[database_id] = DB_ID()  -- Look in the Current Database
   AND [sObj].[type] IN ('U','V')     -- Look in Tables & Views
   AND [sObj].[is_ms_shipped] = 0x0   -- Exclude System Generated Objects
