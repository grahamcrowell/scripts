USE DQMF
GO

DECLARE @pkg_name varchar(100) = '%CCRS%';

SELECT COUNT(*)
	,pkg.PkgName
	,sch.DQMF_ScheduleId
	,stg.StageName
	,stg.StageID
	,br.ShortNameOfTest
	,br.ActionID
	,act.ActionName
	,br.SourceObjectPhysicalName
	,br.TargetObjectPhysicalName
	,br.FactTableObjectAttributeName
	,OBJECT_NAME(col.object_id) AS table_name
	,col.name AS column_name
FROM dbo.ETL_Package AS pkg
JOIN dbo.DQMF_Schedule AS sch
ON pkg.PkgID = sch.PkgKey
JOIN dbo.DQMF_Stage AS stg
ON sch.StageID = stg.StageID
JOIN dbo.DQMF_BizRuleSchedule AS br_sch
ON sch.DQMF_ScheduleId = br_sch.ScheduleID
AND sch.StageID = stg.StageID
JOIN dbo.DQMF_BizRule AS br
ON br_sch.BRID = br.BRId
JOIN dbo.DQMF_Action AS act
ON br.ActionID = act.ActionID
JOIN DSDW.sys.columns AS col
ON br.TargetObjectAttributePhysicalName LIKE '%'+col.name+'%'
--AND (
--	br.TargetObjectPhysicalName LIKE '%'+OBJECT_NAME(col.object_id)+'%'
--	OR
--	br.TargetObjectPhysicalName LIKE '%'+OBJECT_NAME(col.object_id)+'%'
--)
WHERE 1=1
AND pkg.PkgName LIKE @pkg_name
AND br.IsActive = 1
AND act.ActionName NOT IN ('Log Value')
GROUP BY pkg.PkgName
	,sch.DQMF_ScheduleId
	,stg.StageName
	,stg.StageID
	,br.ShortNameOfTest
	,br.ActionID
	,act.ActionName
	,br.SourceObjectPhysicalName
	,br.TargetObjectPhysicalName
	,br.FactTableObjectAttributeName
	,OBJECT_NAME(col.object_id)
	,col.name
ORDER BY pkg.PkgName
	,sch.DQMF_ScheduleId
	,stg.StageName
	,stg.StageID
	,br.ShortNameOfTest
	,br.ActionID
	,act.ActionName
	,br.SourceObjectPhysicalName
	,br.TargetObjectPhysicalName
	,br.FactTableObjectAttributeName
	,OBJECT_NAME(col.object_id)
	,col.name

----ActionID = 0 -> lookup
---- = 1 -> identify bad records:
---- = 2 -> identify bad records: 
--	--conditionSQL not null
--	--actionsql is null
--	--sourceobject is null
--	--targetobject is Staging
---- = 4 -> update, delete records:
--	--conditional sql is null
--	--action sql is not null
--	--source object is ~ not
--	--destination object is ~ not
--SELECT *
--FROM DQMF.dbo.DQMF_BizRule AS br
----JOIN DQMF.dbo.DQMF_BizRuleLookupMapping AS lkup
----ON br.BRId = lkup.BRId
--WHERE 1=1 
----and br.ActionID = 4
--and br.IsActive = 1
----and br.TargetObjectPhysicalName = '%Community%'
--and br.DatabaseId = 32
--ORDER BY CreatedDT DESC;



----USE DSDW
----GO

----SELECT *
----FROM sys.columns as col
----join sys.tables as tab
----on col.object_id = tab.object_id
----where tab.name = 'AdmissionStageLG';