SELECT object_name(IPS.object_id) AS [TableName], 
   SI.name AS [IndexName], 
   IPS.Index_type_desc, 
   IPS.avg_fragmentation_in_percent,    
   IPS.fragment_count, 
   IPS.avg_fragment_size_in_pages,
   alloc_unit_type_desc
FROM sys.dm_db_index_physical_stats(db_id(N'AdventureWorks2012'), NULL, NULL, NULL , 'LIMITED') IPS
   JOIN sys.tables ST WITH (nolock) ON IPS.object_id = ST.object_id
   JOIN sys.indexes SI WITH (nolock) ON IPS.object_id = SI.object_id AND IPS.index_id = SI.index_id
WHERE ST.is_ms_shipped = 0 and index_type_desc in ('NONCLUSTERED INDEX','CLUSTERED INDEX')
and  (fragment_count * avg_fragment_size_in_pages) > 20
ORDER BY avg_fragmentation_in_percent desc
