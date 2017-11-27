/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [ServerName]
      ,[PackageName]
      ,[VersionBuild]
      ,[VersionMajor]
      ,[VersionMinor]
      ,[VersionGUID]
      ,[LastUpdateDT]
  FROM [BaselineData].[MSDB].[ETLVersion]
  where PackageName like '%CommunityLoad%'
  order by PackageName, ServerName