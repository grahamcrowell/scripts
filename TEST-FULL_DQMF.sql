USE [DQMF]
GO
/****** Object:  Schema [AuditResult]    Script Date: 6/4/2016 1:54:46 PM ******/
CREATE SCHEMA [AuditResult]
GO
/****** Object:  Schema [CommunityAgile]    Script Date: 6/4/2016 1:54:46 PM ******/
CREATE SCHEMA [CommunityAgile]
GO
/****** Object:  Schema [DataProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
CREATE SCHEMA [DataProfile]
GO
/****** Object:  Schema [MD]    Script Date: 6/4/2016 1:54:46 PM ******/
CREATE SCHEMA [MD]
GO
/****** Object:  Schema [reference]    Script Date: 6/4/2016 1:54:46 PM ******/
CREATE SCHEMA [reference]
GO
/****** Object:  StoredProcedure [DataProfile].[CreateProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [DataProfile].[CreateProfile]
    @pSourceTable varchar(100),
    @pDestinationTable varchar(100),
    @pFilter varchar(500) = null,
    @Debug int = 0
AS

--Declare @pDestinationTable varchar(100),
--		@pSourceTable  varchar(100),
--		@pFilter varchar(max)

--truncate table WoundMart.dbo.EDMartProfile

--set @pDestinationTable = 'WoundMart.dbo.EDMartProfile'
--set @pSourceTable = 'WoundMart.dbo.vw_EDMartProfile'
--set @pFilter = 'FacilityID = 112'

declare @stmt varchar(max),
		@pWhere varchar(max)

set @pWhere = ''

set @stmt = 'insert into ' + @pDestinationTable 
set @stmt = @stmt + ' Select * from '+ @pSourceTable  
if len(@pFilter) > 0
	set @pWhere = ' where ' + @pFilter

set @stmt = @stmt + @pWhere
exec(@stmt)

IF @Debug > 0 RAISERROR( @stmt, 0, 1, null ) WITH NOWAIT

GO
/****** Object:  StoredProcedure [dbo].[ConditionalInsETLBizRuleAuditFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- 27-Nov-2009 DR408 Added [ETLBizRuleAuditFact].[PkgExecID]
-- =============================================
CREATE PROCEDURE [dbo].[ConditionalInsETLBizRuleAuditFact]
            @pCondition bit = 1
	       ,@pETLId bigint
           ,@pBRId int
           ,@pPkgExecKey bigint
           ,@pPreviousValue varchar(100)
           ,@pNewValue varchar(100) out
           ,@pNegativeRating tinyint

AS
DECLARE     @pDQMF_ScheduleId int
           ,@pDatabaseId int
           ,@pTableId int
           ,@pAttributeId int
           ,@pOlsonTypeID int
           ,@pActionID int
           ,@pSeverityTypeID int

BEGIN
	SET NOCOUNT ON;
IF @pCondition is null SET @pCondition = 1

	if (@pCondition = 1)
	BEGIN
	  --lookup the BZRule 
		SELECT      @pDQMF_ScheduleId = bs.[ScheduleId]
				   ,@pDatabaseId = br.[DatabaseId]
				   ,@pTableId = 0
				   ,@pAttributeId = 0
				   ,@pOlsonTypeID = br.[OlsonTypeID]
				   ,@pActionID = br.[ActionID]
				   ,@pSeverityTypeID = br.[SeverityTypeID]
                   ,@pNewValue = br.DefaultValue
		FROM   [DQMF].[dbo].[DQMF_BizRule] as br
              ,[DQMF].[dbo].[DQMF_BizRuleSchedule] as bs
              ,dbo.DQMF_Schedule s
              ,dbo.ETL_Package p
              ,dbo.AuditPkgExecution a
		WHERE  br.BRId = @pBRId
        AND    br.BRID = bs.BRID
        and    bs.[ScheduleId] = DQMF_ScheduleId
        and    s.PkgKey = p.PkgID
        and    p.PkgID = a.PkgKey
        and    a.pkgExecKey = @pPkgExecKey  -- need to make sure we pick up the correct package/schedule/rule definition

		INSERT INTO [DQMF].[dbo].[ETLBizRuleAuditFact]
				   ([ETLId]
                   ,[PkgExecKey]
				   ,[DQMF_ScheduleId]
				   ,[BRId]
				   ,[DatebaseId]
				   ,[TableId]
				   ,[AttributeId]
				   ,[PreviousValue]
				   ,[NewValue]
				   ,[OlsonTypeID]
				   ,[ActionID]
				   ,[SeverityTypeID]
				   ,[NegativeRating])
			 VALUES
				   ( @pETLId, 
                    @pPkgExecKey,
					@pDQMF_ScheduleId, 
					@pBRId, 
					@pDatabaseId,
					@pTableId,
					@pAttributeId, 
					@pPreviousValue, 
					@pNewValue, 
					@pOlsonTypeID, 
					@pActionID, 
					@pSeverityTypeID, 
					@pNegativeRating)
	END
--  ELSE
--     there is no problem with this data, reflect the incoming data as pNewValue
END








GO
/****** Object:  StoredProcedure [dbo].[CopyDataMartOjects]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
=======================================================================
SP:         Proc to copy the DIM Objects from DSDW to the Mart
            Data Mart:  N/A (but the code can should be used to any datamart)
Desc:       Code drops, creates, copies all data, create PK
                for all tables that are mentioned in the DQMF.MD* Tables
Dept:       Decision Support, VCH
Author:     Sreedhar Vankayala
Create dt:  Thu, Mar 11, 10
Note:       * This is requirment provided by Grant
            To have a SP that populates DataMart

Parameters: 5
        -- Input parameters:
            @pSourceDatabaseName VARCHAR(50),       -- Database name  -- Table: dbo.MD_Database
            @pDataMartDatabaseName varchar(50),     -- Database name  -- Table: dbo.MD_Database
            @pDataMartSubjectAreaName  VARCHAR(50), -- Subject Area Name -- Table: dbo.MD_SubjectArea
            @pObjectPurpose varchar(100),           -- Values: Data Mart,Dimension Copy,Dimension Source,Fact,Map,Staging
            @pCopyData bit = 1                      -- ?? (Talk to grant)
        -- Output Parameters: NO

EXEC SQL:
    EXEC DQMF.dbo.CopyDataMartOjects
        @pSourceDatabaseName  = 'DSDW' ,
        @pDataMartDatabaseName  = 'AdrMart' ,
        @pDataMartSubjectAreaName   = 'Populate Dim Tables to ADRMART',
        @pObjectPurpose = 'Dimension Copy',
        @pCopyData  = 1

 Change History
    Date            Author                  Description
    ----------      -------------------     ---------------------------
    Mar 11, 10      Sreedhar Vankayala      Created
    Apr 29, 10      James.Pua               DR 683
                                            Modified the following line to include IsActive=1
                                            SET @SourceSchema = (SELECT ObjectSchemaName FROM DQMF.dbo.MD_Object WHERE DatabaseId =  @SourceDatabaseId AND ObjectPhysicalName = @TableName)
                                            SET @SourceSchema = (SELECT ObjectSchemaName FROM DQMF.dbo.MD_Object WHERE DatabaseId =  @SourceDatabaseId AND ObjectPhysicalName = @TableName AND IsActive=1)

    Jun 02,2010     Derrick Campbell        DR743
                                            Add check for IsActive=1 when getting MD_Object rows in @ObjectsList4Copy.
                                            This allows metadata on DB3 to be configured before the physical table exists.
    Jun 09, 2010    Daniel Pepermans        Refactored to use cursor insetad of pseudo cursor.
                                            Default @SourceSchema if it can't be found.
                                            Added optional @Debug to display status messages.
   Jun 09 2010     Grant S       revverted some of daniels changes around teh cursor and added AND ObjectSchemaName <> 'Staging' to the sourceschema selection criteria

=======================================================================
*/
/*
    Developer Notes:
    Assumptions:
        Schemas should exists already, if not Script raise error.

    Approach used
    -----------------------------------
    Part 1: Lookup and init data
            dbo.MD_Database, dbo.MD_SubjectArea, dbo.MD_Object

    Minimum metadata required:
    MD_Database - 1 row for DSDW (source), 1 row for your mart
    MD_SubjectArea - 1 row for your mart associated to your mart DatabaseID
    MD_Object - 1 row per object associated to DSDW database with IsActive=1,ObjectPurpose='Dimension Source' and
                1 row per object associated to your mart with IsActive=1,ObjectPurpose='Dimension Copy'

    Part 2: Get the list of objects into temp table (IsActive=1 only)

    Part 3: Populate Data
            For each object
                Drop table                          ... dynamic sql
                Create table using Select * into    ... dynamic sql
                Enable PK for the table             ... dynamic sql
*/


CREATE PROCEDURE [dbo].[CopyDataMartOjects](
		  @pSourceDatabaseName VARCHAR(50), 
        @pDataMartDatabaseName varchar(50),
		  @pDataMartSubjectAreaName  VARCHAR(50), 
        @pObjectPurpose varchar(100),
        @pCopyData bit = 1    ,
        @Debug tinyint = 0

) AS

	SET NOCOUNT ON

	/** DECLARE VARIABLES **/
DECLARE	@DatabaseId INT
   ,@SourceDatabaseID int
	,@SubjectAreaID INT
	,@TableName varchar(255)
	,@SQLStr varchar (Max)
   ,@SourceSchema varchar(50)
   ,@QalTableName varchar(200)
	, @ObjectPKField varchar(255)

	DECLARE @ObjectsList4Copy TABLE
	(
		ObjectPhysicalName varchar(50) null,
	    ObjectSchemaName varchar(50) null,
		ObjectPKField varchar(255) null
	)

	-- Part 1: Lookup and init data 
	-- SET the DatabaseId
	SELECT @DatabaseId = (SELECT  DatabaseId 
                            FROM DQMF.dbo.MD_Database 
                           WHERE DatabaseName = @pDataMartDatabaseName)

	SELECT @SourceDatabaseId = (SELECT  DatabaseId 
                            FROM DQMF.dbo.MD_Database 
                           WHERE DatabaseName = @pSourceDatabaseName)

	-- SET the SubjectAreaID
	SELECT @SubjectAreaId =(SELECT	 SubjectAreaID 
		                      FROM	DQMF.dbo.MD_SubjectArea 
		                     WHERE	SubjectAreaName = @pDataMartSubjectAreaName 
				               AND DatabaseId = @DatabaseId)

	-- Part 2: Get the list of objects into temp table 
	INSERT @ObjectsList4Copy
	SELECT  ObjectPhysicalName,
			          ObjectSchemaName, 
			           ObjectPKField
	 FROM DQMF.dbo.MD_Object
	WHERE DatabaseId = @DatabaseId
	  AND SubjectAreaID = @SubjectAreaID
      AND ObjectPurpose = @pObjectPurpose
      AND IsActive = 1    -- dc 2-Jun-2010

	--		Part 3: Populate Data
WHILE EXISTS (SELECT * FROM @ObjectsList4Copy)
	BEGIN
		SELECT TOP 1  
				@TableName = ltrim(ObjectPhysicalName),
				@QalTableName = ltrim(rtrim(ObjectSchemaName) + '.'+ ltrim(ObjectPhysicalName)),
				@ObjectPKField = ltrim(ObjectPKField)
		FROM @ObjectsList4Copy

       IF @Debug > 0 RAISERROR( 'dbo.CopyDataMartOjects: Processing %s...', 0, 1, @QalTableName ) WITH NOWAIT

        SET @SQLStr = 'IF  EXISTS (SELECT * FROM ' + rtrim(@pDataMArtDatabaseName) + '.' + 'sys.objects WHERE object_id = OBJECT_ID(N''' + rtrim(@pDataMArtDatabaseName) + '.' + @QalTableName + ''')AND type in (N''U'')) 
                      DROP TABLE ' + rtrim(@pDataMArtDatabaseName) + '.'+ @QalTableName      
         IF @Debug > 1 RAISERROR( '%s', 0, 1, @SQLStr ) WITH NOWAIT
        EXEC (@SQLStr)

		SET @SourceSchema = (SELECT ObjectSchemaName FROM DQMF.dbo.MD_Object 
                              WHERE DatabaseId =  @SourceDatabaseId 
							  AND ObjectPhysicalName = @TableName 
							  AND IsActive=1 
							  AND ObjectSchemaName <> 'Staging'
							  AND ObjectPurpose = case when @pObjectPurpose = 'Dimension Copy' then 'Dimension Source' else @pObjectPurpose end)

		SET @SQLStr = 'SELECT * INTO ' + rtrim(@pDataMArtDatabaseName) + '.' + @QalTableName + ' FROM ' +  @pSourceDatabaseName  + '.' + @SourceSchema + '.' + @TableName
       IF @Debug > 1 RAISERROR( '%s', 0, 1, @SQLStr ) WITH NOWAIT
       EXEC (@SQLStr)
			
		SET @SQLStr = 'ALTER TABLE ' + rtrim(@pDataMArtDatabaseName) + '.' + @QalTableName + ' ADD CONSTRAINT PK__' + @TableName + ' PRIMARY KEY (' + @ObjectPKField + ') '
      IF @Debug > 1 RAISERROR( '%s', 0, 1, @SQLStr ) WITH NOWAIT
      EXEC (@SQLStr)

		DELETE FROM @ObjectsList4Copy 
        WHERE ObjectPhysicalName in (SELECT top 1 ObjectPhysicalName FROM @ObjectsList4Copy)
END

GO
/****** Object:  StoredProcedure [dbo].[DelBizRule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[DelBizRule] 
	@pGUID varchar(200)
AS
BEGIN
	
	SET NOCOUNT ON;

    IF EXISTS (SELECT a.BRID FROM dbo.DQMF_BizRuleSchedule a inner join dbo.DQMF_BizRule b on a.brid = b.brid WHERE GUID = @pGUID)
    BEGIN
        RAISERROR ( 'There are still Schedules associated with this Biz Rule Can not delete',16,1 )
    END
    ELSE
    BEGIN

        DELETE FROM dbo.DQMF_BizRule
         WHERE GUID = @pGUID
    END
END


GO
/****** Object:  StoredProcedure [dbo].[DelBizRuleSchedule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Grants
-- Create date: <Create Date,,>
-- Description:	remove rows from Biz rule Schedule
-- =============================================
CREATE PROCEDURE [dbo].[DelBizRuleSchedule]
@pGUID varchar(200),
@pScheduleID int
AS
BEGIN
	SET NOCOUNT ON;

   DELETE a FROM dbo.DQMF_BizRuleSchedule a inner join dbo.DQMF_BizRule b
                     on a.BRID = b.BRID
   WHERE ScheduleID = @pScheduleID and GUID = ISnull(@pGUID,GUID)


END



GO
/****** Object:  StoredProcedure [dbo].[DelCensusRecordsOutSideAdmissionAndDischarge]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DelCensusRecordsOutSideAdmissionAndDischarge] 
AS

BEGIN

	--census after discharge
	DELETE FROM Adtc.CensusFact
	WHERE ETLAuditID in
		(select C.ETLAuditID 
		from Adtc.CensusFact as C 
		inner join Dim.AccountType as A on A.AccountTypeID=C.AccountTypeID
		inner join Adtc.DischargeFact as D on D.AccountNum=C.AccountNum
		where CensusDateID > DischargeDateID)

	--census before admission
	DELETE FROM Adtc.CensusFact
	WHERE CensusDateID < AdmissionDateID
END
GO
/****** Object:  StoredProcedure [dbo].[DelDuplicateAuditFacts]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David George
-- Create date: 01-Jul-2010
-- Description:	Removes Dulicated Audit Facts
--              
-- Note:  This procedure removes duplicates generated by type 1 (actionid=1) rules
--        that are repeatedly executed (once a day). If the data condition is not 
--        corrected, this generates multiple audit facts.
--        The procedure will keep the most recent audit fact.
--
-- =============================================
CREATE PROCEDURE [dbo].[DelDuplicateAuditFacts] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	WITH DuplicateID AS (
	select f.ETLId, f.brid, count(*) cnt, max(f.PkgExecKey) mpkg
	from dqmf.dbo.ETLBizRuleAuditFact f
	where 1=1
	group by f.ETLId, f.brid
	having count(*) > 1
	)

		DELETE AF
		FROM dqmf.dbo.ETLBizRuleAuditFact AF
		JOIN DuplicateID d ON AF.ETLID = d.ETLID AND AF.BRID = d.BRID AND AF.PkgExecKey <> d.MPKG
		

END


GO
/****** Object:  StoredProcedure [dbo].[DelETLPackage]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Grant Stephens
-- Create date: <Create Date,,>
-- Description:remove a row from dbo.ETL_Package
-- =============================================
CREATE PROCEDURE [dbo].[DelETLPackage]
	@pPackageID int
AS
BEGIN
	
	SET NOCOUNT ON;

  DELETE FROM dbo.ETL_Package
  WHERE PkgID = @pPackageID

END


GO
/****** Object:  StoredProcedure [dbo].[DelStageSchedule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Grants
-- Create date: <Create Date,,>
-- Description:	remove stage and associated schedule.
-- =============================================
CREATE PROCEDURE [dbo].[DelStageSchedule] 

	@pStageID int
AS
BEGIN

	SET NOCOUNT ON;

 IF exists(SELECT st.StageID
           FROM dbo.DQMF_Stage st
           INNER JOIN dbo.DQMF_Schedule SCH
                  ON SCH.STAGEID = ST.STAGEID
           INNER JOIN dbo.DQMF_BizRuleSchedule BRS
                  ON BRS.ScheduleID = SCH.DQMF_ScheduleId
           WHERE ST.STAGEID = @pStageID) 
  BEGIN
      RAISERROR ( 'There are still Biz Rules associated with this Schedule Can not delete',16,1 )
  END
  ELSE
  BEGIN
          DELETE FROM  dbo.DQMF_Schedule 
                WHERE STAGEID = @pStageID

		  DELETE FROM dbo.DQMF_Stage
                WHERE STAGEID = @pStageID

  END
END

GO
/****** Object:  StoredProcedure [dbo].[dt_adduserobject]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Add an object to the dtproperties table
*/
create procedure [dbo].[dt_adduserobject]
as
	set nocount on
	/*
	** Create the user object if it does not exist already
	*/
	begin transaction
		insert dbo.dtproperties (property) VALUES ('DtgSchemaOBJECT')
		update dbo.dtproperties set objectid=@@identity 
			where id=@@identity and property='DtgSchemaOBJECT'
	commit
	return @@identity

GO
/****** Object:  StoredProcedure [dbo].[dt_droppropertiesbyid]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Drop one or all the associated properties of an object or an attribute 
**
**	dt_dropproperties objid, null or '' -- drop all properties of the object itself
**	dt_dropproperties objid, property -- drop the property
*/
create procedure [dbo].[dt_droppropertiesbyid]
	@id int,
	@property varchar(64)
as
	set nocount on

	if (@property is null) or (@property = '')
		delete from dbo.dtproperties where objectid=@id
	else
		delete from dbo.dtproperties 
			where objectid=@id and property=@property


GO
/****** Object:  StoredProcedure [dbo].[dt_dropuserobjectbyid]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Drop an object from the dbo.dtproperties table
*/
create procedure [dbo].[dt_dropuserobjectbyid]
	@id int
as
	set nocount on
	delete from dbo.dtproperties where objectid=@id

GO
/****** Object:  StoredProcedure [dbo].[dt_generateansiname]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* 
**	Generate an ansi name that is unique in the dtproperties.value column 
*/ 
create procedure [dbo].[dt_generateansiname](@name varchar(255) output) 
as 
	declare @prologue varchar(20) 
	declare @indexstring varchar(20) 
	declare @index integer 
 
	set @prologue = 'MSDT-A-' 
	set @index = 1 
 
	while 1 = 1 
	begin 
		set @indexstring = cast(@index as varchar(20)) 
		set @name = @prologue + @indexstring 
		if not exists (select value from dtproperties where value = @name) 
			break 
		 
		set @index = @index + 1 
 
		if (@index = 10000) 
			goto TooMany 
	end 
 
Leave: 
 
	return 
 
TooMany: 
 
	set @name = 'DIAGRAM' 
	goto Leave 

GO
/****** Object:  StoredProcedure [dbo].[dt_getobjwithprop]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Retrieve the owner object(s) of a given property
*/
create procedure [dbo].[dt_getobjwithprop]
	@property varchar(30),
	@value varchar(255)
as
	set nocount on

	if (@property is null) or (@property = '')
	begin
		raiserror('Must specify a property name.',-1,-1)
		return (1)
	end

	if (@value is null)
		select objectid id from dbo.dtproperties
			where property=@property

	else
		select objectid id from dbo.dtproperties
			where property=@property and value=@value

GO
/****** Object:  StoredProcedure [dbo].[dt_getobjwithprop_u]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Retrieve the owner object(s) of a given property
*/
create procedure [dbo].[dt_getobjwithprop_u]
	@property varchar(30),
	@uvalue nvarchar(255)
as
	set nocount on

	if (@property is null) or (@property = '')
	begin
		raiserror('Must specify a property name.',-1,-1)
		return (1)
	end

	if (@uvalue is null)
		select objectid id from dbo.dtproperties
			where property=@property

	else
		select objectid id from dbo.dtproperties
			where property=@property and uvalue=@uvalue

GO
/****** Object:  StoredProcedure [dbo].[dt_getpropertiesbyid]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Retrieve properties by id's
**
**	dt_getproperties objid, null or '' -- retrieve all properties of the object itself
**	dt_getproperties objid, property -- retrieve the property specified
*/
create procedure [dbo].[dt_getpropertiesbyid]
	@id int,
	@property varchar(64)
as
	set nocount on

	if (@property is null) or (@property = '')
		select property, version, value, lvalue
			from dbo.dtproperties
			where  @id=objectid
	else
		select property, version, value, lvalue
			from dbo.dtproperties
			where  @id=objectid and @property=property

GO
/****** Object:  StoredProcedure [dbo].[dt_getpropertiesbyid_u]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	Retrieve properties by id's
**
**	dt_getproperties objid, null or '' -- retrieve all properties of the object itself
**	dt_getproperties objid, property -- retrieve the property specified
*/
create procedure [dbo].[dt_getpropertiesbyid_u]
	@id int,
	@property varchar(64)
as
	set nocount on

	if (@property is null) or (@property = '')
		select property, version, uvalue, lvalue
			from dbo.dtproperties
			where  @id=objectid
	else
		select property, version, uvalue, lvalue
			from dbo.dtproperties
			where  @id=objectid and @property=property

GO
/****** Object:  StoredProcedure [dbo].[dt_setpropertybyid]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	If the property already exists, reset the value; otherwise add property
**		id -- the id in sysobjects of the object
**		property -- the name of the property
**		value -- the text value of the property
**		lvalue -- the binary value of the property (image)
*/
create procedure [dbo].[dt_setpropertybyid]
	@id int,
	@property varchar(64),
	@value varchar(255),
	@lvalue image
as
	set nocount on
	declare @uvalue nvarchar(255) 
	set @uvalue = convert(nvarchar(255), @value) 
	if exists (select * from dbo.dtproperties 
			where objectid=@id and property=@property)
	begin
		--
		-- bump the version count for this row as we update it
		--
		update dbo.dtproperties set value=@value, uvalue=@uvalue, lvalue=@lvalue, version=version+1
			where objectid=@id and property=@property
	end
	else
	begin
		--
		-- version count is auto-set to 0 on initial insert
		--
		insert dbo.dtproperties (property, objectid, value, uvalue, lvalue)
			values (@property, @id, @value, @uvalue, @lvalue)
	end


GO
/****** Object:  StoredProcedure [dbo].[dt_setpropertybyid_u]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	If the property already exists, reset the value; otherwise add property
**		id -- the id in sysobjects of the object
**		property -- the name of the property
**		uvalue -- the text value of the property
**		lvalue -- the binary value of the property (image)
*/
create procedure [dbo].[dt_setpropertybyid_u]
	@id int,
	@property varchar(64),
	@uvalue nvarchar(255),
	@lvalue image
as
	set nocount on
	-- 
	-- If we are writing the name property, find the ansi equivalent. 
	-- If there is no lossless translation, generate an ansi name. 
	-- 
	declare @avalue varchar(255) 
	set @avalue = null 
	if (@uvalue is not null) 
	begin 
		if (convert(nvarchar(255), convert(varchar(255), @uvalue)) = @uvalue) 
		begin 
			set @avalue = convert(varchar(255), @uvalue) 
		end 
		else 
		begin 
			if 'DtgSchemaNAME' = @property 
			begin 
				exec dbo.dt_generateansiname @avalue output 
			end 
		end 
	end 
	if exists (select * from dbo.dtproperties 
			where objectid=@id and property=@property)
	begin
		--
		-- bump the version count for this row as we update it
		--
		update dbo.dtproperties set value=@avalue, uvalue=@uvalue, lvalue=@lvalue, version=version+1
			where objectid=@id and property=@property
	end
	else
	begin
		--
		-- version count is auto-set to 0 on initial insert
		--
		insert dbo.dtproperties (property, objectid, value, uvalue, lvalue)
			values (@property, @id, @avalue, @uvalue, @lvalue)
	end

GO
/****** Object:  StoredProcedure [dbo].[dt_verstamp006]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	This procedure returns the version number of the stored
**    procedures used by legacy versions of the Microsoft
**	Visual Database Tools.  Version is 7.0.00.
*/
create procedure [dbo].[dt_verstamp006]
as
	select 7000

GO
/****** Object:  StoredProcedure [dbo].[dt_verstamp007]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
**	This procedure returns the version number of the stored
**    procedures used by the the Microsoft Visual Database Tools.
**	Version is 7.0.05.
*/
create procedure [dbo].[dt_verstamp007]
as
	select 7005

GO
/****** Object:  StoredProcedure [dbo].[ExecDataCorrections]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--EXECUTE [DQMF].[dbo].[ExecDataCorrections] @SubjectAreaID =45  ,@Debug = 2 ,@IsDaily = 1 
--SELECT * FROM dbo.DQMF_DataCorrectionMapping m WHERE m.IsActive = 1
--SELECT * FROM dbo.DQMF_DataCorrectionMapping m WHERE m.ErrorReasonSkipMapping IS NOT NULL

CREATE PROCEDURE [dbo].[ExecDataCorrections] 
				@SubjectAreaID int = 0,
				@IsDaily int = 0,
				@Debug int = 0
AS

IF @Debug = 0
	SET NOCOUNT ON

BEGIN
	
	DECLARE @SQLStr varchar(max),
			@Message varchar(max)

	SET @SQLStr = 'DISABLE TRIGGER [dbo].[TrDQMF_DataCorrectionMappingUpdate] ON [dbo].[DQMF_DataCorrectionMapping]'
		EXEC(@SQLStr)

    ----------------------------------------------------------------------------------
	IF @Debug > 0 RAISERROR('--Update FactTableObjectAttributeId FROM dbo.DQMF_BizRule WHERE BRId = 9000)----', 0, 1 ) WITH NOWAIT
	DECLARE @PC_ObjectAttributeID int
	SELECT @PC_ObjectAttributeID = ObjectAttributeID 
	--, DatabaseName, ObjectSchemaName , ObjectPhysicalName, AttributePhysicalName
	FROM dbo.vwMD_PhyscialName 
	WHERE DatabaseName = 'DSDW'
	  AND ObjectSchemaName = 'Secure'
	  AND ObjectPhysicalName = 'CurrentPatientFact'
	  AND AttributePhysicalName = 'PostalCodeID'
	--SELECT @PC_ObjectAttributeID

	IF @PC_ObjectAttributeID > 0
	   AND (SELECT ISNULL(FactTableObjectAttributeId,0) FROM dbo.DQMF_BizRule WHERE BRId = 9000) <> @PC_ObjectAttributeID
		UPDATE b
			SET FactTableObjectAttributeId = @PC_ObjectAttributeID
		FROM dbo.DQMF_BizRule b
		WHERE b.BRId = 9000

	---set skip to exclude ----------------------------------------------------------------------------------
	IF @Debug > 0 RAISERROR('--SET ErrorReasonSkipMapping ----', 0, 1 ) WITH NOWAIT	
	UPDATE m
		SET ErrorReasonSkipMapping = 'IsFacilityIDApplied set for both 1 and 0 by BRID, PreviousValue' 
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	WHERE m.IsActive = 1
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND m.IsFacilityIDApplied = 0
	  AND m.BRID IN (SELECT d.BRID
					FROM dbo.DQMF_DataCorrectionMapping d
					WHERE d.IsActive = 1
					  AND d.ErrorReasonSkipMapping IS NULL
					  AND d.BRID = m.BRID
					  AND d.PreviousValue = m.PreviousValue
					GROUP BY d.BRID
					HAVING COUNT(DISTINCT d.IsFacilityIDApplied) > 1)

	;WITH d as (SELECT BRID, PreviousValue, IsFacilityIDApplied, FacilityID,IsEffectiveDateApplied, EffectiveStartDateID, EffectiveEndDateID
				FROM dbo.DQMF_DataCorrectionMapping
				WHERE IsActive = 1
				  AND ErrorReasonSkipMapping IS NULL 
				GROUP BY BRID, PreviousValue, IsFacilityIDApplied, FacilityID,IsEffectiveDateApplied, EffectiveStartDateID, EffectiveEndDateID
				HAVING COUNT(*) > 1)

	UPDATE m
		SET ErrorReasonSkipMapping = 'Duplicate by BRID, PreviousValue, IsFacilityIDApplied, FacilityID, IsEffectiveDateApplied, EffectiveStartDateID, EffectiveEndDateID'
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN d ON d.BRID = m.BRID AND (d.PreviousValue = m.PreviousValue OR (d.PreviousValue IS NULL AND m.PreviousValue IS NULL))
								    AND (d.FacilityID = m.FacilityID OR (d.FacilityID IS NULL AND m.FacilityID IS NULL))
									AND (d.IsEffectiveDateApplied = m.IsEffectiveDateApplied OR (d.IsEffectiveDateApplied IS NULL AND m.IsEffectiveDateApplied IS NULL))
									AND (d.EffectiveStartDateID = m.EffectiveStartDateID OR (d.EffectiveStartDateID IS NULL AND m.EffectiveStartDateID IS NULL))
									AND (d.EffectiveEndDateID = m.EffectiveEndDateID OR (d.EffectiveEndDateID IS NULL AND m.EffectiveEndDateID IS NULL))
	WHERE m.IsActive = 1
	  AND m.ErrorReasonSkipMapping IS NULL

	UPDATE m
		SET ErrorReasonSkipMapping = 'IsEffectiveDateApplied = 1 and (EffectiveStartDateID IS NULL OR m.EffectiveEndDateID IS NULL)'
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	WHERE m.IsActive = 1
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND m.IsEffectiveDateApplied = 1
	  AND (m.EffectiveStartDateID IS NULL OR m.EffectiveEndDateID IS NULL)
 

	UPDATE m
		SET ErrorReasonSkipMapping = 'IsFacilityIDApplied = 1 and FacilityID IS NULL'
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	WHERE m.IsActive = 1
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND m.IsFacilityIDApplied = 1 
	  AND m.FacilityID IS NULL
	  

	UPDATE m
		SET ErrorReasonSkipMapping = 'IsFacilityIDApplied = 0 and FacilityID IS NOT NULL'
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	WHERE m.IsActive = 1
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND m.IsFacilityIDApplied = 0 
	  AND m.FacilityID IS NOT NULL
	  

	UPDATE m
  		SET ErrorReasonSkipMapping = 'FactTableObjectAttributeId: ' + CASE WHEN b.FactTableObjectAttributeId IS NULL THEN '' ELSE CONVERT(varchar(10),b.FactTableObjectAttributeId) END + ' does not exists as ObjectAttribute in DSDW'
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN dbo.DQMF_BizRule b ON b.BRID = m.BRID
	WHERE m.IsActive = 1
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND (b.FactTableObjectAttributeId IS NULL
	   OR NOT EXISTS (SELECT * 
					  FROM [dbo].[vwMD_PhyscialName] md 
					  WHERE md.[ObjectAttributeID] = b.FactTableObjectAttributeId
					  AND md.DatabaseID = 2)) --dsdw	

	UPDATE m
  		SET ErrorReasonSkipMapping = 'Table: DSDW.' +md.ObjectSchemaName+'.'+md.ObjectPhysicalName+ ' does not exists'
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN dbo.DQMF_BizRule b ON b.BRID = m.BRID
	INNER JOIN [dbo].[vwMD_PhyscialName] md on md.[ObjectAttributeID] = b.FactTableObjectAttributeId
	WHERE m.IsActive = 1
	  AND md.DatabaseID = 2 --dsdw
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND NOT EXISTS (SELECT * 
						FROM DSDW.INFORMATION_SCHEMA.TABLES t 
						WHERE t.TABLE_TYPE = 'BASE TABLE' 
						  AND TABLE_SCHEMA = md.ObjectSchemaName
						  AND t.TABLE_NAME  = md.ObjectPhysicalName)

	 UPDATE m
  		SET ErrorReasonSkipMapping = 'Column: ' + AttributePhysicalName + ' does not exists in table DSDW.' +ObjectSchemaName+'.'+ObjectPhysicalName
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN dbo.DQMF_BizRule b ON b.BRID = m.BRID
	INNER JOIN [dbo].[vwMD_PhyscialName] md on md.[ObjectAttributeID] = b.FactTableObjectAttributeId
	WHERE m.IsActive = 1
	  AND md.DatabaseID = 2 --dsdw
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND NOT EXISTS(SELECT * 
						 FROM DSDW.INFORMATION_SCHEMA.COLUMNS c 
						  WHERE c.TABLE_SCHEMA = md.ObjectSchemaName 
							AND c.TABLE_NAME = md.ObjectPhysicalName
							AND COLUMN_NAME = md.AttributePhysicalName)

	UPDATE m
		SET ErrorReasonSkipMapping = 'IsEffectiveDateApplied = 1 and KeyDateField: ' + ISNULL(k.AttributePhysicalName,'')+ ' not exists in table DSDW.' +ObjectSchemaName+'.'+ObjectPhysicalName
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN dbo.DQMF_BizRule b ON b.BRID = m.BRID
	INNER JOIN [dbo].[vwMD_PhyscialName] md on md.[ObjectAttributeID] = b.FactTableObjectAttributeId
	LEFT JOIN [dbo].[MD_ObjectAttribute] k ON k.ObjectAttributeID = md.KeyDateObjectAttributeID
	WHERE m.IsActive = 1
	  AND md.DatabaseID = 2 --dsdw
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND m.IsEffectiveDateApplied = 1
	  AND (k.ObjectAttributeID IS NULL 
	   OR  RTRIM(k.AttributePhysicalName) NOT IN (SELECT COLUMN_NAME
													 FROM DSDW.INFORMATION_SCHEMA.COLUMNS c 
													  WHERE c.TABLE_SCHEMA = md.ObjectSchemaName 
														AND c.TABLE_NAME = md.ObjectPhysicalName))
												
	 UPDATE m
  			SET ErrorReasonSkipMapping = 'IsFacilityIDApplied = 1 AND Non FacilityID Column in Fact table DSDW.' +ObjectSchemaName+'.'+ObjectPhysicalName
		   ,SkipMappingStartDate = GETDATE() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN dbo.DQMF_BizRule b ON b.BRID = m.BRID
	INNER JOIN [dbo].[vwMD_PhyscialName] md on md.[ObjectAttributeID] = b.FactTableObjectAttributeId
	WHERE m.IsActive = 1
	  AND md.DatabaseID = 2 --dsdw
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND IsFacilityIDApplied = 1
	  AND NOT EXISTS(SELECT * 
						 FROM DSDW.INFORMATION_SCHEMA.COLUMNS c 
						  WHERE c.TABLE_SCHEMA = md.ObjectSchemaName 
							AND c.TABLE_NAME = md.ObjectPhysicalName
							AND COLUMN_NAME = 'FacilityID')

	----------------------------------------------------------------------------------------------------------
	IF (@SubjectAreaID = 0 OR @SubjectAreaID = 2)	
		BEGIN
			IF @Debug > 0 RAISERROR('--DataCorrection for PowerRiver chief complaints----', 0, 1 ) WITH NOWAIT
			UPDATE a
				SET IsForDQ = 1
				   ,IsCorrected = 1
			FROM dbo.ETLBizruleAuditFact a 
			CROSS APPLY (SELECT b.brid
						 FROM dbo.DQMF_BizRule b 
						 WHERE b.BRID = a.BRID
						   AND b.GUID IN ('8C237554-214A-4376-8685-147A2348C4AC', -- BRID: 111598 - Lookup ChiefComplaintId prior to NACRS version change
										  '69A7F940-75C3-44B9-AF38-C9BF85C25B1C')-- BRID: 112647 - Lookup ChiefComplaintId post NACRS version change
						) br
			WHERE ISNULL(a.IsForDQ,0) <> 1 
			   OR ISNULL(a.IsCorrected,0) <> 1 
		END
	----------------------------------------------------------------------------------------------------------
	BEGIN
		IF @Debug > 0 RAISERROR('--DataCorrection for BR Lookup Dim.Date or Dim.Time ----', 0, 1 ) WITH NOWAIT
			;WITH Bizrule as (SELECT m.brid, m.PreviousValue
								FROM dbo.DQMF_DataCorrectionMapping m
								INNER JOIN dbo.DQMF_BizRule b ON b.BRId = m.BRID
								WHERE m.IsActive = 1
								AND b.SourceObjectPhysicalName IN ('Dim.Time','Dim.Date'))

			UPDATE a
				SET IsForDQ = 1
					,IsCorrected = 1
			FROM dbo.ETLBizruleAuditFact a 
			INNER JOIN Bizrule b ON b.BRID = a.BRID AND ISNULL(b.PreviousValue,'NULL-NULL') = ISNULL(a.PreviousValue,'NULL-NULL')
			WHERE ISNULL(a.IsForDQ,0) <> 1 
				OR ISNULL(a.IsCorrected,0) <> 1 
	END	
	----------------------------------------------------------------------------------------------------------
	BEGIN
		IF @Debug > 0 RAISERROR('--DataCorrection for BRId 9000 with PostalCode in (OutofC, OutofP)----' , 0, 1 ) WITH NOWAIT
			UPDATE a
				SET IsForDQ = m.IsForDQ
					,IsCorrected = 1
			FROM dbo.DQMF_DataCorrectionMapping m
			INNER JOIN dbo.ETLBizruleAuditFact a ON a.BRId = m.BRID AND a.PreviousValue = m.PreviousValue
			WHERE m.BRId = 9000
				AND m.MapToId IN (125522, -- OutofC
								  125523) -- OutofP
				AND (ISNULL(a.IsForDQ,0) <> m.IsForDQ OR ISNULL(a.IsCorrected,0) <> 1 )
	END	
	----------------------------------------------------------------------------------------------------------
	IF @Debug > 0 RAISERROR('--Populate table dbo.DQMF_DataCorrectionWorking---', 0, 1 ) WITH NOWAIT	
	
	DECLARE @TempTableName varchar(100)
	IF @SubjectAreaID = 0 
		BEGIN
			TRUNCATE TABLE dbo.DQMF_DataCorrectionWorking -- Truncate working table when Correct all subject areas
			SET @TempTableName = 'DQMF_DataCorrection_ALLSubjectArea'
		END
	ELSE
		BEGIN
			DELETE dbo.DQMF_DataCorrectionWorking WHERE SubjectAreaID = @SubjectAreaID

			SELECT @TempTableName = 'DQMF_DataCorrection_' + REPLACE(SubjectAreaName,' ','')
			FROM dbo.MD_SubjectArea
			WHERE SubjectAreaID = @SubjectAreaID
		END
	IF NOT EXISTS (SELECT * FROM sys.objects o WHERE o.[Schema_id] = 1  AND o.[Type] = 'U' AND o.[Name] = @TempTableName)
	BEGIN
		SET @SQLStr = 'CREATE TABLE dbo.' + @TempTableName +'(
						[ETLId] [bigint] NOT NULL,
						[MapToID] [int] NULL,
						[IsForDQ] [bit] NULL,
						[IsFacilityIDApplied] [bit] NULL,
						[FacilityID] [int] NULL,
						[IsEffectiveDateApplied] [bit] NULL,
						[EffectiveStartDateID] [int] NULL,
						[EffectiveEndDateID] [int] NULL)
			
			CREATE CLUSTERED INDEX #Idx_' + @TempTableName +' ON dbo.' + @TempTableName +'
				([ETLId] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
            '
		EXEC (@SQLStr)
	END

	;WITH Exclude_Bizrule as (SELECT b.brid 
							  FROM dbo.DQMF_BizRule b
							  WHERE (b.SourceObjectPhysicalName IN ('Dim.Time','Dim.Date')
								 OR  b.GUID IN ('8C237554-214A-4376-8685-147A2348C4AC', -- BRID: 111598 - Lookup ChiefComplaintId prior to NACRS version change
											    '69A7F940-75C3-44B9-AF38-C9BF85C25B1C') -- BRID: 112647 - Lookup ChiefComplaintId post NACRS version change
									)
							    AND EXISTS(SELECT 1
										   FROM dbo.DQMF_DataCorrectionMapping m
										   WHERE m.BRID = b.BRId
										     AND m.IsActive = 1)
							 )

	INSERT INTO dbo.DQMF_DataCorrectionWorking
	SELECT	@SubjectAreaID,
			m.BRID,
			m.IsFacilityIDApplied,
			m.FacilityID, 
			m.IsEffectiveDateApplied,
			m.EffectiveStartDateID,
			m.EffectiveEndDateID,
			m.PreviousValue,	
			m.MapToID,
			m.IsFirstRun,
			'DSDW.'+md.ObjectSchemaName+'.'+md.ObjectPhysicalName UpdateTableName,
			md.AttributePhysicalName UpdateFieldName,
			md.ObjectID,
			m.IsForDQ,
			m.DataCorrectionMappingID
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN dbo.DQMF_BizRule b ON b.BRID = m.BRID
	INNER JOIN [dbo].[vwMD_PhyscialName] md on md.[ObjectAttributeID] = b.FactTableObjectAttributeId
	WHERE m.IsActive = 1 
	  AND md.DatabaseID = 2 --dsdw
	  AND (m.SubjectAreaID = @SubjectAreaID
	   OR (@SubjectAreaID = 0 AND m.SubjectAreaID <> 90)) -- Exclude SubjectArea 'Secure' when @SubjectAreaID = 0
	  AND m.ErrorReasonSkipMapping IS NULL
	  AND b.brid NOT IN (SELECT brid FROM Exclude_Bizrule)
	ORDER BY m.SubjectAreaID, md.ObjectSchemaName,md.ObjectPhysicalName,md.AttributePhysicalName

	IF @Debug > 0 RAISERROR('--Exclue DataCorrection for BRId 9000 with PostalCode in (OutofC, OutofP)----' , 0, 1 ) WITH NOWAIT
	DELETE w
	FROM dbo.DQMF_DataCorrectionWorking w
	WHERE w.SubjectAreaID = 90 -- Secure
	  AND w.Brid = 9000
	  AND w.MapToId IN (125522, -- OutofC
					    125523) -- OutofP
	---------------------------------------------------------
	DECLARE @CurrentDate as datetime, @MinETLID as bigint

	SET @MinETLID = 0
	IF @IsDaily = 1 
		-- GET @MinETLID = YesterdayMaxETLID+1 
		SELECT @MinETLID = convert(bigint,ConfiguredValue) +1 FROM msdb.dbo.SSIS_Config m WHERE ConfigurationFilter = 'DQMF_DataCorrection'
	
	---------------------------------------------------------
	IF @Debug > 0 RAISERROR('--Loop through table: dbo.DQMF_DataCorrectionWorking to EXEC dbo.SetDataCorrection ----', 0, 1 ) WITH NOWAIT

	DECLARE @pBRID as int
	WHILE EXISTS (SELECT TOP 1 BRID FROM dbo.DQMF_DataCorrectionWorking WHERE SubjectAreaID = @SubjectAreaID)
	BEGIN
		SELECT TOP 1 @pBRID = BRID FROM dbo.DQMF_DataCorrectionWorking WHERE SubjectAreaID = @SubjectAreaID
		
		EXEC dbo.SetDataCorrection  @pTempTableName = @TempTableName,
									@pSubjectAreaID = @SubjectAreaID,
									@pBRID = @pBRID,
									@pMinETLID = @MinETLID,
									@Debug = @Debug
		
	END
	
	SET @SQLStr = 'ENABLE TRIGGER [dbo].[TrDQMF_DataCorrectionMappingUpdate] ON [dbo].[DQMF_DataCorrectionMapping]'
		EXEC(@SQLStr)

	--Drop @pTempTableName
	IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.'+@TempTableName) AND type in (N'U'))
	BEGIN
		SET @SQLStr = 'DROP TABLE dbo.'+@TempTableName
		EXEC(@SQLStr)
	END
	------------------------------------------------------------
	
	IF @Debug > 0 RAISERROR('--------------------PROCEDURE [dbo].[ExecDataCorrections] END-----------------', 0, 1 ) WITH NOWAIT

END
GO
/****** Object:  StoredProcedure [dbo].[ExecPackagebyStageName]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*	-- Test Script

	EXEC [dbo].[ExecPackagebyStageName]  
		 @pPkgName = 'SystemVerification'
		,@pStageName = 'DimensionVerification'
		,@Debug = 4
*/

CREATE PROCEDURE [dbo].[ExecPackagebyStageName] 
	@pPkgName varchar(100)
   ,@pStageName varchar(MAX) = 'ALL' --Default to ALL - which will exec all Active Stages
									 --Individual Stage name or multiple Stage name separate by comma; ie 'StageName1, StageName2'
   ,@Debug int = 0


AS
BEGIN

SET NOCOUNT ON

	DECLARE @sql varchar(MAX)
	DECLARE @ActionSQL varchar(MAX) 
	DECLARE @StageName varchar(200)
	
	DECLARE @pPkgExecKeyOut int, @pExtractFileKeyOut int
	
	DECLARE @tblStageName TABLE (RowNumber int, StageName varchar(max))

	IF @pStageName = 'ALL'
		INSERT INTO @tblStageName
			SELECT DISTINCT t.StageOrder, t.StageName
			FROM DQMF.dbo.DQMF_Schedule AS s 
			INNER JOIN DQMF.dbo.ETL_Package p ON p.PkgID =s.Pkgkey
			INNER JOIN DQMF.dbo.DQMF_Stage AS t ON s.StageID = t.StageID
			WHERE p.PkgName = @pPkgName
			  AND s.IsScheduleActive = 1
			ORDER BY t.StageOrder
	ELSE
		INSERT INTO @tblStageName
			SELECT pos, LTRIM(RTRIM(element)) AS GUID FROM dbo.fn_SplitTSQL(@pStageName, N',')

	--------------------------------------------------
	
	--Task: Create DQMF Batch (PkgExecKey)
	EXEC [dbo].[SetAuditPkgExecution]
				@pPkgExecKey  = null
			   ,@pParentPkgExecKey  = null
			   ,@pPkgName = @pPkgName
			   ,@pPkgVersionMajor = 1
			   ,@pPkgVersionMinor = 0
			   ,@pIsProcessStart = 1
			   ,@pIsPackageSuccessful = 0
			   ,@pPkgExecKeyOut = @pPkgExecKeyOut OUTPUT

	--Task: Create ExtractFileId
	DECLARE @date smalldatetime
	SET @date = getdate()
	EXEC [dbo].[SetAuditExtractFile]
				@pPkgExecKey = @pPkgExecKeyOut
			   ,@pExtractFileKey = null
			   ,@pExtractFilePhysicalLocation = @pPkgName 
			   ,@pIsProcessStart = 1
			   ,@pExtractFileCreatedDT = @date
			   ,@pIsProcessSuccess = 0
			   ,@pExtractFileKeyOut = @pExtractFileKeyOut OUTPUT


	DECLARE cursor_StageName CURSOR FORWARD_ONLY 
	FOR 
	SELECT StageName FROM @tblStageName
	
	OPEN cursor_StageName
	FETCH NEXT FROM cursor_StageName INTO @StageName
	WHILE @@FETCH_STATUS <> -1
	BEGIN		
		
		PRINT 'ExecDQMFBizRule - ' + @StageName

			--Task: ExecDQMFBizRule 
			EXEC DSDW.[dbo].[ExecDQMFBizRule] 
				 @pStageName = @StageName
				,@pExtractFileKey = @pExtractFileKeyOut
				,@debug = @debug -- output [ExecDQMFBizRule]

		FETCH NEXT FROM cursor_StageName INTO @StageName
	END
	CLOSE cursor_StageName
	DEALLOCATE cursor_StageName

	
--Task: Set Batch Success
	EXEC [dbo].[SetAuditPkgExecution]
            @pPkgExecKey = @pPkgExecKeyOut
           ,@pParentPkgExecKey = null
           ,@pPkgVersionMajor = null
           ,@pPkgVersionMinor = null
           ,@pPkgName = null
           ,@pIsProcessStart = 0
           ,@pIsPackageSuccessful = 1
           ,@pPkgExecKeyout = null

END

GO
/****** Object:  StoredProcedure [dbo].[GenBizRuleByStage]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[GenBizRuleByStage] @StageName varchar(100), @sGUID Nvarchar(MAX)= NULL, @debug INT = 0
/* =============================================
 Author: James.Pua
 Create date: 07-Jan-2010
 Description: Generate deployment script for ETL Package using setbizrule and setbizrulemapping sp
 -- Add new column: [FactTableObjectAttributeId] by DR2383 - DQMF Auto data fix mappings 
  -- Add new column: [SecondaryFactTableObjectAttributeId] by DR7130 - DQMF

	Program flow
	------------
	Print Insert ETL_Package
	Print DQMF_Schedule
			- Insert Stage
			- Insert DQMF_Schedule
			- Insert BR
				
 Change History:
 <Date>			<Alias>		<Desc>
	2011/12/05	James		Create to use setbizrule and setbizrulemapping sp, remove @KeepBRID =1 parameter
	2016/04/01  Alan		Add flag to set package to active all the time
      Usage:

            -- All BRs
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1'  
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadBiWeeklyLabourHrCstFactStage1'
			EXEC [dbo].[GenBizRuleByStage]  @StageName = 'ADTCMart Staging'

          -- Single GUID
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1', @sGUID='2EFEDF0C-3C49-4292-B54B-6DEDF2A2FDF8'   

            -- Multiple GUID
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1', @sGUID='2EFEDF0C-3C49-4292-B54B-6DEDF2A2FDF8,3F691376-587B-4757-9F6C-D079F54A79C0'  
            
            -- Bad GUID
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1', @sGUID='This-is-a-bad-guid'

            -- Valid GUID but not belong to this stage
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1', @sGUID='78BA46D3-2F4A-4E1F-932B-CD2FF3C8808E'

            -- @Debug=1 to show more info.
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1', @debug=1
            EXEC [dbo].[GenBizRuleByStage]  @StageName = 'LoadGLAccountFactBudgetStage1', @sGUID='2EFEDF0C-3C49-4292-B54B-6DEDF2A2FDF8,3F691376-587B-4757-9F6C-D079F54A79C0', @Debug=1      

*/
 AS
BEGIN
SET NOCOUNT ON

DECLARE @PkgName varchar(100), @PkgDescription varchar(max)
/*
DECLARE @debug int
SELECT @PkgName = 'LoadBiWeeklyLabourHrCstFact', @debug =1
*/

DECLARE  @sql varchar(MAX)
--SET @PkgName  = 'LGMainT7'

DECLARE @ActionSQL varchar(max)

DECLARE @CrLf varchar(2)
SET @CrLf = CHAR(10) 

DECLARE @PkgID int, @PkgKey int
DECLARE @ScheduleID int

DECLARE @DQMF_ScheduleId INT, @StageID  INT, @DatabaseId INT, @TableId INT, @IsScheduleActive INT
DECLARE @StageDescription varchar(max), @StageOrder int
DECLARE @CreatedBy varchar(100), @UpdatedBy varchar(100)

/* If bizrule guid is provided, check if the bizrule is indeed belong to the stage */
/* Replace the CR LF from the GUID string */
SET @sGUID = LTRIM(RTRIM(@sGUID))
SET @sGUID = REPLACE(@sGUID, CHAR(13), '')
SET @sGUID = REPLACE(@sGUID, CHAR(10), '')
DECLARE @tblGUID TABLE (RowNumber int, GUID varchar(max))

IF @Debug >0 
	SELECT @sGUID AS [@sGUID]
	
IF LEN(@sGUID) > 0
BEGIN 
	INSERT @tblGUID SELECT pos, LTRIM(RTRIM(element)) AS GUID FROM dbo.fn_SplitTSQL(@sGUID, N',')

	IF @Debug >0 
		SELECT * FROM @tblGUID

	IF EXISTS(
	SELECT BR.BRID, BR.GUID 
	FROM @tblGUID tblGUID LEFT JOIN dbo.DQMF_BizRule BR ON tblGUID.GUID=BR.GUID
	WHERE BR.BRID IS NULL)
	BEGIN 
		SELECT tblGUID.GUID, 'Can''t find matching GUID in dbo.DQMF_BizRule' 
		FROM @tblGUID tblGUID LEFT JOIN dbo.DQMF_BizRule BR ON tblGUID.GUID=BR.GUID
		WHERE BR.BRID IS NULL
		RAISERROR ('1 or more GUID bizrule not found.',12, 1)
		RETURN
	END

	
	IF EXISTS (SELECT * FROM @tblGUID tblGUID LEFT JOIN 
									(
										SELECT BR.GUID FROM 
										DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID	
										INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
										INNER JOIN dbo.DQMF_bizruleschedule BRSCH ON BRSCH.ScheduleID=Sch.DQMF_ScheduleId
										INNER JOIN dbo.DQMF_BizRule BR ON BRSCH.BRID = BR.BRID 
										WHERE Stage.StageName=@StageName 
									) R ON tblGUID.GUID=R.GUID WHERE R.GUID IS NULL)
		BEGIN 
			SELECT tblGUID.GUID AS [GUID Not Belong to this stage]  FROM @tblGUID tblGUID LEFT JOIN 
									(
										SELECT BR.GUID FROM 
										DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID	
										INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
										INNER JOIN dbo.DQMF_bizruleschedule BRSCH ON BRSCH.ScheduleID=Sch.DQMF_ScheduleId
										INNER JOIN dbo.DQMF_BizRule BR ON BRSCH.BRID = BR.BRID 
										WHERE Stage.StageName=@StageName 
									) R ON tblGUID.GUID=R.GUID WHERE R.GUID IS NULL

			RAISERROR ('1 or more GUID bizrule not in this stage.',12, 1)
			RETURN
		END
END

SELECT @PkgID = PkgID, @PkgKey = PkgID, @ScheduleID = Sch.DQMF_ScheduleId, @StageId = Sch.StageId, @PkgName= PkgName, @PkgDescription=PkgDescription, @CreatedBy =REPLACE(Pkg.CreatedBy,'''',''''''), @UpdatedBy=REPLACE(Pkg.UpdatedBy,'''','''''')
FROM DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
WHERE Stage.StageName=@StageName


/**********************************************************/

IF @Debug >0 
	SELECT @PkgID AS PkgID, @PkgKey AS PkgKey, @ScheduleID AS ScheduleID, @StageId AS StageId, @PkgName AS PkgName


IF @PkgID IS NULL 
	BEGIN
		RAISERROR ('Package "%s" Not Found!!!', 10, 0, @PkgName) WITH NOWAIT
		RETURN
	END 

--DECLARE @sql varchar(max)
PRINT 'USE DQMF' 
PRINT 'GO' 
PRINT 'DECLARE @PkgName varchar(100), @PkgDescription varchar(max),@PkgKey int, @PkgID int, @DQMF_ScheduleId INT, @StageID INT ' 
PRINT 'DECLARE @ActionSQL varchar(MAX), @CreatedBy varchar(100), @UpdatedBy varchar(100) '
PRINT 'DECLARE @StageName varchar(100), @StageDescription  varchar(max)'
PRINT 'DECLARE @StageOrder  smallint'
PRINT 'DECLARE @DatabaseId int'
PRINT 'DECLARE @TableId int'
PRINT 'DECLARE @IsScheduleActive bit'
PRINT 'DECLARE @GUID varchar(50) '
PRINT 'DECLARE @BRID INT'+ @CrLf 

--PRINT 'DECLARE @sGUID varchar(200), @iJoinNumber int, @sSourceLookupExpression varchar(1000), @sDimensionLookupExpression varchar(1000), @bIsSourcePreviousValue bit' + @CrLf + @CrLf

PRINT 'SET @PkgName =''' + REPLACE(@PkgName, '''','''''') + '''' 
PRINT 'SET @StageName =''' + REPLACE(@StageName , '''','''''') + '''' 

PRINT 'IF NOT EXISTS ( SELECT * FROM dbo.ETL_Package WHERE PkgName=@PkgName)' 
PRINT 'BEGIN' 
PRINT 'INSERT dbo.ETL_Package (PkgName, PkgDescription, CreatedBy, CreatedDT, UpdatedBy, UpdatedDT, IsActive)  VALUES ' 
PRINT '(' 
PRINT CASE WHEN @PkgName IS NULL THEN 'NULL' ELSE '''' + REPLACE(@PkgName,'''','''''') + '''' END + ', ' 
PRINT CASE WHEN @PkgDescription IS NULL THEN 'NULL' ELSE '''' + REPLACE(@PkgDescription,'''','''''') + '''' END + ', ' 
PRINT CASE WHEN @CreatedBy IS NULL THEN 'NULL' ELSE '''' + REPLACE(@CreatedBy,'''','''''')  + '''' END + ', ' 
PRINT 'GETDATE(), ' 
PRINT CASE WHEN @UpdatedBy IS NULL THEN 'NULL' ELSE '''' + REPLACE(@UpdatedBy,'''','''''')  + '''' END + ', ' 
PRINT 'GETDATE(),1' 
PRINT ')' 
PRINT 'END' + @CrLf

PRINT 'SELECT @PkgId = PkgId, @PkgKey=PkgId FROM dbo.ETL_Package WHERE PkgName=@PkgName ' 

SELECT @DQMF_ScheduleId=Sch.DQMF_ScheduleId, @StageID=Sch.StageID, @DatabaseId=Sch.DatabaseId, @TableId=Sch.TableId, @IsScheduleActive=Sch.IsScheduleActive, @CreatedBy =REPLACE(CreatedBy,'''',''''''), @UpdatedBy=REPLACE(UpdatedBy,'''','''''')
FROM DQMF_Schedule Sch --INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
WHERE StageID = @StageId 

	/* Print the 'Setting the stage information' */

	PRINT 'SET @DatabaseId = ' + CAST(@DatabaseId AS varchar(50))
	PRINT 'SET @TableId = ' + CAST(@TableId AS varchar(50))
	PRINT 'SET @IsScheduleActive = ' + CAST(@IsScheduleActive AS varchar(50))
	PRINT 'SET @CreatedBy = ''' + @CreatedBy  + ''''
	PRINT 'SET @UpdatedBy = ''' + @UpdatedBy  + ''''	

	SELECT @StageName = REPLACE(StageName, '''',''''''), @StageDescription=REPLACE(StageDescription, '''',''''''), @StageOrder=StageOrder 
	FROM dbo.DQMF_Stage WHERE StageID = @StageID

	PRINT 'SET @StageName= ''' + @StageName + ''''
	PRINT 'SET @StageDescription= ' + CASE WHEN @StageDescription IS NULL THEN 'NULL' ELSE  '''' + @StageDescription + '''' END 
	PRINT 'SET @StageOrder= ' + CASE WHEN @StageOrder IS NULL THEN 'NULL' ELSE CAST(@StageOrder AS varchar(20)) END
	PRINT 'SET @StageID = NULL'
	PRINT 'SET @DQMF_ScheduleId = NULL'

	PRINT 'SELECT @StageID=StageID FROM dbo.DQMF_Stage WHERE StageName =@StageName '
	PRINT 'SELECT @DQMF_ScheduleId = Sch.DQMF_ScheduleId 
FROM DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
WHERE StageName = @StageName '

	/* Printing the scheddule information */

PRINT '
EXECUTE [DQMF].[dbo].[SetStageSchedule] 
   @pStageID=@StageID
  ,@pStageName=@StageName
  ,@pStageDescription=@StageDescription
  ,@pStageOrder=@StageOrder
  ,@pDQMF_ScheduleId=@DQMF_ScheduleId
  ,@pDatabaseId=@DatabaseId
  ,@pTableId=@TableId
  ,@pPkgKey=@PkgKey
  ,@pIsScheduleActive=@IsScheduleActive
  ,@pCreatedBy=@CreatedBy
  ,@pUpdatedBy=@UpdatedBy
'
PRINT ''
	PRINT '/* This script will try to re-get all variables */'
PRINT ''
	PRINT 
'SELECT @DatabaseId = Sch.DatabaseId, @TableId=Sch.TableID, @IsScheduleActive=Sch.IsScheduleActive, @CreatedBy = Sch.CreatedBy, @UpdatedBy=Sch.UpdatedBy, @StageID = Stage.StageID, @StageDescription = Stage.StageDescription, @StageOrder = Stage.StageOrder, @DQMF_ScheduleId = Sch.DQMF_ScheduleId 
FROM DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
WHERE StageName = @StageName '

		PRINT '' 
		-- We do not want to delete all rules that bind to this schedule since this script generation is base on stage+rules 

	/* 
		Use cursor here because if we are going to generate all the br with the ;with result as ()... print @sql method
		there is size limitation in xml string. So I just print the one at a time br, slow but it should not cause error
	 */
	DECLARE @BRID INT
	DECLARE @GUID varchar(36)
	DECLARE BRcsr CURSOR FORWARD_ONLY 
	FOR 
	SELECT BR.BRID, BR.GUID 
	FROM dbo.DQMF_BizRuleSchedule BRSCD INNER JOIN dbo.DQMF_BizRule BR ON BRSCD.BRID=BR.BRID 
	WHERE ScheduleID = @DQMF_ScheduleId AND (LEN(@sGUID) = 0 OR @sGUID IS NULL OR BR.GUID IN (SELECT GUID FROM @tblGUID))

	OPEN BRcsr
	FETCH NEXT FROM BRcsr INTO @BRID, @GUID
	WHILE @@FETCH_STATUS <> -1
	BEGIN		
			set @sql =''

			PRINT ''
			PRINT 'SET @GUID = ''' + @GUID + ''''
			PRINT 'SELECT @BRID=BRID FROM dbo.DQMF_BizRule WHERE GUID=@GUID '
			PRINT ''
			SELECT @sql = 
				'EXEC [dbo].[SetBizRule] ' + @CrLf +			
				'@pBRId=@BRID, ' + @CrLf +			 
				'@pShortNameOfTest=' + CASE WHEN [ShortNameOfTest] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ShortNameOfTest], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pRuleDesc=' + CASE WHEN [RuleDesc] IS NULL THEN 'NULL' ELSE '''' + REPLACE([RuleDesc], '''','''''') + ''''   END + ', ' + @CrLf + 
				'@pConditionSQL=' + CASE WHEN [ConditionSQL] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ConditionSQL], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pActionID=' + CASE WHEN [ActionID] IS NULL THEN 'NULL' ELSE CAST([ActionID] AS VARCHAR(10)) END + ', ' + @CrLf +
				'@pActionSQL=@ActionSQL,' + @CrLf +
				'@pOlsonTypeID=' + CASE WHEN [OlsonTypeID] IS NULL THEN 'NULL' ELSE CAST([OlsonTypeID] AS VARCHAR(10)) END + ', ' + @CrLf +
				'@pSeverityTypeID=' +CASE WHEN [SeverityTypeID] IS NULL THEN 'NULL' ELSE CAST([SeverityTypeID] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pSequence=' +CASE WHEN [Sequence] IS NULL THEN 'NULL' ELSE CAST([Sequence] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pDefaultValue=' +CASE WHEN [DefaultValue] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DefaultValue], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pDatabaseId=' +CASE WHEN [DatabaseId] IS NULL THEN 'NULL' ELSE CAST([DatabaseId] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pTargetObjectPhysicalName=' +CASE WHEN [TargetObjectPhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([TargetObjectPhysicalName] AS VARCHAR(100))  + '''' END  + ', ' + @CrLf +
				'@pTargetAttributePhysicalName=' +CASE WHEN [TargetObjectAttributePhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([TargetObjectAttributePhysicalName] AS VARCHAR(100))  + '''' END   + ', ' + @CrLf +
				'@pSourceObjectPhysicalName=' +CASE WHEN [SourceObjectPhysicalName] IS NULL THEN 'NULL' ELSE '''' + REPLACE(CAST([SourceObjectPhysicalName] AS VARCHAR(100)), '''','''''')  + '''' END   + ', ' + @CrLf +
				'@pSourceAttributePhysicalName=' +CASE WHEN [SourceAttributePhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([SourceAttributePhysicalName] AS VARCHAR(100))  + ''''  END  + ', ' + @CrLf +
				'@pIsActive=' +CASE WHEN [IsActive] IS NULL THEN 'NULL' ELSE CAST([IsActive] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pComment=' +CASE WHEN [Comment] IS NULL THEN 'NULL' ELSE '''' + REPLACE([Comment], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pCreatedBy=' +'''' + REPLACE(ISNULL([CreatedBy],SUSER_NAME()), '''','''''') + ''''  + ', ' + @CrLf +
				'@pUpdatedBy=@UpdatedBy,' + @CrLf +
				'@pIsLogged='	+		CASE WHEN [IsLogged] IS NULL THEN 'NULL' ELSE CAST([IsLogged] AS varchar(20)) END + ', ' 	+ @CrLf +
				'@pGUID=@GUID' + ', ' + @CrLf +
				'@pFactTableObjectAttributeId=' +CASE WHEN [FactTableObjectAttributeId] IS NULL THEN 'NULL' ELSE CAST([FactTableObjectAttributeId] AS VARCHAR(10))  END  + ', ' + @CrLf +
				--'@pSecondaryFactTableObjectAttributeId=' +CASE WHEN [SecondaryFactTableObjectAttributeId] IS NULL THEN 'NULL' ELSE CAST([SecondaryFactTableObjectAttributeId] AS VARCHAR(10))  END  + ', ' + @CrLf +
				'@pBusinessKeyExpression=' +CASE WHEN [BusinessKeyExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE(CAST([BusinessKeyExpression] AS VARCHAR(500)), '''','''''') + ''''  END 
			
			FROM dbo.DQMF_BizRule BR 
			WHERE BRID = @BRID
					
			SELECT @ActionSQL = 'SET @ActionSQL = ' + CASE WHEN [ActionSQL] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ActionSQL], '''','''''') + ''''   END +  @CrLf 
			FROM dbo.DQMF_BizRule BizRule
			WHERE BRID = @BRID --= 15721 

			EXEC dbo.PrintTextLine @strOut = @ActionSQL

			EXEC dbo.PrintTextLine @strOut = @sql

			PRINT ''
			PRINT 'IF NOT EXISTS (SELECT * FROM dbo.DQMF_BizRuleSchedule BRS INNER JOIN dbo.DQMF_BizRule BR ON BRS.BRID=BR.BRID WHERE scheduleid= @DQMF_ScheduleId AND BR.GUID=@GUID)'

			PRINT 'INSERT dbo.DQMF_BizRuleSchedule (BRID, ScheduleID) SELECT (SELECT BRID FROM DQMF_BizRule WHERE GUID=@GUID) AS BRID, @DQMF_ScheduleId '

			PRINT  @CrLf

			PRINT 'DELETE BRM FROM dbo.DQMF_BizRuleLookupMapping BRM INNER JOIN dbo.DQMF_BizRule BR ON BRM.BRID = BR.BRID WHERE BR.GUID =@GUID '+ @CrLf		

			DECLARE BRMappingCsr CURSOR FORWARD_ONLY 
			FOR 
			SELECT BRId, JoinNumber FROM dbo.DQMF_BizRuleLookupMapping WHERE BRID = @BRID

			DECLARE @mappingBRID int, @mappingJoinNumber int

			OPEN BRMappingCsr
			FETCH NEXT FROM BRMappingCsr INTO @mappingBRID, @mappingJoinNumber
			WHILE @@FETCH_STATUS <> -1
			BEGIN

/*				
				[dbo].[SetDQMFBizRuleLookupMapping] 
				@pGUID=@sGUID												-- varchar(200) ???
				@pJoinNumber = @iJoinNumber,								-- int,
				@pSourceLookupExpression = @sSourceLookupExpression,		-- varchar(1000),
				@pDimensionLookupExpression = @sDimensionLookupExpression,	-- varchar(1000),
				@pIsSourcePreviousValue = @bIsSourcePreviousValue			-- bit
*/

				SELECT @sql = 'EXEC [dbo].[SetDQMFBizRuleLookupMapping]  ' + @CrLf +
				'@pGUID= @GUID'  + ', ' + @CrLf +
				'@pJoinNumber = ' + CASE WHEN [JoinNumber] IS NULL THEN 'NULL' ELSE CAST([JoinNumber] AS varchar(10)) END + ', ' + @CrLf +
				'@pSourceLookupExpression = ' + CASE WHEN [SourceLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([SourceLookupExpression], '''','''''') + ''''  END  + ', ' + @CrLf +
				'@pDimensionLookupExpression = ' + CASE WHEN [DimensionLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DimensionLookupExpression], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pIsSourcePreviousValue = ' + CASE WHEN [IsSourcePreviousValue] IS NULL THEN 'NULL' ELSE CAST([IsSourcePreviousValue] AS VARCHAR(10)) END  + @CrLf 
				FROM dbo.DQMF_BizRuleLookupMapping BizRule
				WHERE BizRule.BRID = @mappingBRID AND BizRule.JoinNumber = @mappingJoinNumber

				EXEC dbo.PrintTextLine @strOut =@sql

				FETCH NEXT FROM BRMappingCsr INTO @mappingBRID, @mappingJoinNumber
			END
			CLOSE BRMappingCsr
			DEALLOCATE BRMappingCsr
		FETCH NEXT FROM BRcsr INTO @BRID, @GUID
	END
	CLOSE BRcsr
	DEALLOCATE BRcsr


	PRINT '-- End of stage ' + @StageName + @CrLf

PRINT '-- End of Package ' + @PkgName


END

GO
/****** Object:  StoredProcedure [dbo].[GenBizRuleScript]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GenBizRuleScript] @sGUID Nvarchar(MAX)
/*

	EXEC GenBizRuleScript '2814BD7E-67EA-4676-B3C6-95CFD6519C8D'
	EXEC GenBizRuleScript '2814BD7E-67EA-4676-B3C6-95CFD6519C8D,636802D1-1A10-4F8A-8ADA-0B617E1F85C8'
	EXEC GenBizRuleScript '2EFEDF0C-3C49-4292-B54B-6DEDF2A2FDF8, 3F691376-587B-4757-9F6C-D079F54A79C0, 40B14817-1A28-4C7A-965E-2CE3A628CB0B, AFB039E0-AE8B-4907-8A13-26F57C6634CF, D3B8ADC2-783E-46BC-860B-99215659B5E3, FFB737AB-4223-4971-A40A-D298C3B2E4E9'
	-- Add new column: [FactTableObjectAttributeId] by DR2383 - DQMF Auto data fix mappings 
*/
AS
BEGIN

SET NOCOUNT ON
/*
For testing.

DECLARE @sGUID NVARCHAR(MAX)
SET @sGUID = '2EFEDF0C-3C49-4292-B54B-6DEDF2A2FDF8, 3F691376-587B-4757-9F6C-D079F54A79C0, 40B14817-1A28-4C7A-965E-2CE3A628CB0B, AFB039E0-AE8B-4907-8A13-26F57C6634CF, D3B8ADC2-783E-46BC-860B-99215659B5E3, FFB737AB-4223-4971-A40A-D298C3B2E4E9'

*/

	DECLARE @sql varchar(MAX)
	DECLARE @ActionSQL varchar(MAX) 
	DECLARE @BRID INT
	DECLARE @GUID varchar(36)
	DECLARE @CreatedBy varchar(50)
	DECLARE @CrLf varchar(2)
	SET @CrLf = CHAR(10) 
	

	/* Replace the CR LF from the GUID string */
	SET @sGUID = REPLACE(@sGUID, CHAR(13), '')
	SET @sGUID = REPLACE(@sGUID, CHAR(10), '')
	

	DECLARE @tblGUID TABLE (RowNumber int, GUID varchar(max))
	INSERT @tblGUID SELECT pos, LTRIM(RTRIM(element)) AS GUID FROM dbo.fn_SplitTSQL(@sGUID, N',')

	IF EXISTS(
	SELECT BR.BRID, BR.GUID 
	FROM @tblGUID tblGUID LEFT JOIN dbo.DQMF_BizRule BR ON tblGUID.GUID=BR.GUID
	WHERE BR.BRID IS NULL)
	BEGIN 
		SELECT tblGUID.GUID, 'Can''t find matching GUID in dbo.DQMF_BizRule' 
		FROM @tblGUID tblGUID LEFT JOIN dbo.DQMF_BizRule BR ON tblGUID.GUID=BR.GUID
		WHERE BR.BRID IS NULL
		RAISERROR ('1 or more GUID bizrule not found.',12, 1)
		RETURN
	END




	DECLARE BRcsr CURSOR FORWARD_ONLY 
	FOR 
	SELECT BR.BRID, BR.GUID , BR.CreatedBy
	FROM dbo.DQMF_BizRule BR INNER JOIN @tblGUID tblGUID ON BR.GUID=tblGUID.GUID
	
	PRINT 'USE DQMF'
	PRINT 'GO'
	PRINT ''
	PRINT 'SET NOCOUNT ON'
	PRINT 'DECLARE @ActionSQL VARCHAR(MAX)'
	PRINT 'DECLARE @UpdatedBy sysname, @CreatedBy sysname'
	PRINT 'SELECT @UpdatedBy=''' + SUSER_NAME() + '''' 
	PRINT 'DECLARE @BRID INT'
	PRINT 'DECLARE @GUID VARCHAR(50)'

	OPEN BRcsr
	FETCH NEXT FROM BRcsr INTO @BRID, @GUID, @CreatedBy
	WHILE @@FETCH_STATUS <> -1
	BEGIN		
			set @sql =''

			PRINT 'SET @GUID = ''' + @GUID + ''''
			PRINT ''
			PRINT 'SELECT @BRID=BRID FROM dbo.DQMF_BizRule WHERE GUID=@GUID'
			PRINT ''
			PRINT 'SELECT @CreatedBy=''' + ISNULL(@CreatedBy, SUSER_NAME()) + ''''
			SELECT @sql = 
				'EXEC [dbo].[SetBizRule] ' + @CrLf +			
				'@pBRId=@BRID, ' + @CrLf +			 
				'@pShortNameOfTest=' + CASE WHEN [ShortNameOfTest] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ShortNameOfTest], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pRuleDesc=' + CASE WHEN [RuleDesc] IS NULL THEN 'NULL' ELSE '''' + REPLACE([RuleDesc], '''','''''') + ''''   END + ', ' + @CrLf + 
				'@pConditionSQL=' + CASE WHEN [ConditionSQL] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ConditionSQL], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pActionID=' + CASE WHEN [ActionID] IS NULL THEN 'NULL' ELSE CAST([ActionID] AS VARCHAR(10)) END + ', ' + @CrLf +
				'@pActionSQL=@ActionSQL,' + @CrLf +
				'@pOlsonTypeID=' + CASE WHEN [OlsonTypeID] IS NULL THEN 'NULL' ELSE CAST([OlsonTypeID] AS VARCHAR(10)) END + ', ' + @CrLf +
				'@pSeverityTypeID=' +CASE WHEN [SeverityTypeID] IS NULL THEN 'NULL' ELSE CAST([SeverityTypeID] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pSequence=' +CASE WHEN [Sequence] IS NULL THEN 'NULL' ELSE CAST([Sequence] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pDefaultValue=' +CASE WHEN [DefaultValue] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DefaultValue], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pDatabaseId=' +CASE WHEN [DatabaseId] IS NULL THEN 'NULL' ELSE CAST([DatabaseId] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pTargetObjectPhysicalName=' +CASE WHEN [TargetObjectPhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([TargetObjectPhysicalName] AS VARCHAR(100))  + '''' END  + ', ' + @CrLf +
				'@pTargetAttributePhysicalName=' +CASE WHEN [TargetObjectAttributePhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([TargetObjectAttributePhysicalName] AS VARCHAR(100))  + '''' END   + ', ' + @CrLf +
				'@pSourceObjectPhysicalName=' +CASE WHEN [SourceObjectPhysicalName] IS NULL THEN 'NULL' ELSE '''' + REPLACE(CAST([SourceObjectPhysicalName] AS VARCHAR(100)), '''','''''')  + '''' END   + ', ' + @CrLf +
				'@pSourceAttributePhysicalName=' +CASE WHEN [SourceAttributePhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([SourceAttributePhysicalName] AS VARCHAR(100))  + ''''  END  + ', ' + @CrLf +
				'@pIsActive=' +CASE WHEN [IsActive] IS NULL THEN 'NULL' ELSE CAST([IsActive] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pComment=' +CASE WHEN [Comment] IS NULL THEN 'NULL' ELSE '''' + REPLACE([Comment], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pCreatedBy=@CreatedBy,' + @CrLf +
				'@pUpdatedBy=@UpdatedBy,' + @CrLf +
				'@pIsLogged='	+		CASE WHEN [IsLogged] IS NULL THEN 'NULL' ELSE CAST([IsLogged] AS varchar(20)) END + ', ' 	+ @CrLf +
				'@pGUID=@GUID ' + ', ' + @CrLf +
				'@pFactTableObjectAttributeId=' +CASE WHEN [FactTableObjectAttributeId] IS NULL THEN 'NULL' ELSE CAST([FactTableObjectAttributeId] AS VARCHAR(10))  END + ', ' 	+ @CrLf +
				'@pBusinessKeyExpression=' +CASE WHEN [BusinessKeyExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE(CAST([BusinessKeyExpression] AS VARCHAR(500)), '''','''''') + ''''  END 
			
			FROM dbo.DQMF_BizRule BR 
			WHERE BRID = @BRID
					
			SELECT @ActionSQL = 'SET @ActionSQL = ' + CASE WHEN [ActionSQL] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ActionSQL], '''','''''') + ''''   END +  @CrLf 
			FROM dbo.DQMF_BizRule BizRule
			WHERE BRID = @BRID --= 15721 

			EXEC dbo.PrintTextLine @strOut = @ActionSQL

			EXEC dbo.PrintTextLine @strOut = @sql

--			PRINT  @CrLf

			-- Here
			PRINT 'DELETE BRM FROM dbo.DQMF_BizRuleLookupMapping BRM INNER JOIN dbo.DQMF_BizRule BR ON BRM.BRID = BR.BRID WHERE BR.GUID =@GUID '+ @CrLf

			DECLARE BRMappingCsr CURSOR FORWARD_ONLY 
			FOR 
			SELECT BRId, JoinNumber FROM dbo.DQMF_BizRuleLookupMapping WHERE BRID = @BRID

			DECLARE @mappingBRID int, @mappingJoinNumber int

			OPEN BRMappingCsr
			FETCH NEXT FROM BRMappingCsr INTO @mappingBRID, @mappingJoinNumber
			WHILE @@FETCH_STATUS <> -1
			BEGIN
				SELECT @sql = 'EXEC [dbo].[SetDQMFBizRuleLookupMapping]  ' + @CrLf +
				'@pGUID= @GUID, ' + @CrLf +
				'@pJoinNumber = ' + CASE WHEN [JoinNumber] IS NULL THEN 'NULL' ELSE CAST([JoinNumber] AS varchar(10)) END + ', ' + @CrLf +
				'@pSourceLookupExpression = ' + CASE WHEN [SourceLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([SourceLookupExpression], '''','''''') + ''''  END  + ', ' + @CrLf +
				'@pDimensionLookupExpression = ' + CASE WHEN [DimensionLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DimensionLookupExpression], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pIsSourcePreviousValue = ' + CASE WHEN [IsSourcePreviousValue] IS NULL THEN 'NULL' ELSE CAST([IsSourcePreviousValue] AS VARCHAR(10)) END  + @CrLf 
				FROM dbo.DQMF_BizRuleLookupMapping BizRule
				WHERE BizRule.BRID = @mappingBRID AND BizRule.JoinNumber = @mappingJoinNumber

				EXEC dbo.PrintTextLine @strOut =@sql

				FETCH NEXT FROM BRMappingCsr INTO @mappingBRID, @mappingJoinNumber
			END
			CLOSE BRMappingCsr
			DEALLOCATE BRMappingCsr

		FETCH NEXT FROM BRcsr INTO @BRID, @GUID, @CreatedBy
	END
	CLOSE BRcsr
	DEALLOCATE BRcsr



END
GO
/****** Object:  StoredProcedure [dbo].[GenETLPackageInsert]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GenETLPackageInsert] @PkgName varchar(100), @debug INT = 0
/* =============================================
 Author: James.Pua
 Create date: 07-Jan-2010
 Description: Generate deployment script for ETL Package
 -- Add new column: [FactTableObjectAttributeId] by DR2383 - DQMF Auto data fix mappings 

	Program flow
	------------
	Print Insert ETL_Package
	Print DQMF_Schedule
			- Insert Stage
			- Insert DQMF_Schedule
			- Insert BR

				
 Change History:
 <Date>			<Alias>		<Desc>
	2011/12/05 James Change to use setbizrule and setbizrulemapping sp, remove @KeepBRID =1 parameter

	Usage:
		EXEC DQMF..[GenETLPackageInsert] @PkgName = 'LoadGLAccountFact_Budget'

		EXEC DQMF..[GenETLPackageInsert] @PkgName = 'ADTCMart Populate'
		EXEC DQMF..[GenETLPackageInsert] @PkgName = 'LoadHCRSData'

	2016/03/18 Adrian Procter
			Changed script to use @GUID variable to make it cleaner
		    Changed INSERT dbo.ETL_Package to add additional parameter, IsActive, and default to 1
	20160322	DG
			Add BusinessKeyExp 
			Set NOCOUNT


*/
/* 
DECLARE @PkgName varchar(100)
DECLARE @debug int
SELECT @PkgName = 'SystemVerification', @debug =1
*/ AS
BEGIN
SET NOCOUNT ON

DECLARE  @sql varchar(MAX)
--SET @PkgName  = 'LGMainT7'

DECLARE @ActionSQL varchar(max)

DECLARE @CrLf varchar(2)
SET @CrLf = CHAR(10) 

DECLARE @PkgID int, @PkgKey int, @PkgDescription varchar(max)
DECLARE @ScheduleID int

DECLARE @DQMF_ScheduleId INT, @StageID  INT, @DatabaseId INT, @TableId INT, @IsScheduleActive INT
DECLARE @StageName varchar(100), @StageDescription varchar(max), @StageOrder int
DECLARE @CreatedBy varchar(100), @UpdatedBy varchar(100)

SELECT @PkgID = PkgID, @PkgKey = PkgID, @PkgDescription=PkgDescription, @CreatedBy = CreatedBy , @UpdatedBy =UpdatedBy
	FROM dbo.ETL_Package
	WHERE PkgName = @PkgName  

IF @debug > 0
	SELECT @PkgID AS [@PkgID], @PkgKey AS [@PkgKey]

IF @PkgID IS NULL 
	BEGIN
		RAISERROR ('Package "%s" Not Found!!!', 10, 0, @PkgName) WITH NOWAIT
		RETURN
	END 

--DECLARE @sql varchar(max)
PRINT 'USE DQMF' 
PRINT 'GO' 
PRINT 'DECLARE @PkgName varchar(100), @PkgDescription varchar(max),@PkgKey int, @PkgID int, @DQMF_ScheduleId INT, @StageID INT ' 
PRINT 'DECLARE @ActionSQL varchar(MAX), @CreatedBy varchar(100), @UpdatedBy varchar(100) '
PRINT 'DECLARE @StageName varchar(100), @StageDescription  varchar(max)'
PRINT 'DECLARE @StageOrder  smallint'
PRINT 'DECLARE @DatabaseId int'
PRINT 'DECLARE @TableId int'
PRINT 'DECLARE @IsScheduleActive bit'
PRINT 'DECLARE @GUID CHAR(36)'
PRINT 'DECLARE @BRID INT'+ @CrLf 

--PRINT 'DECLARE @sGUID varchar(200), @iJoinNumber int, @sSourceLookupExpression varchar(1000), @sDimensionLookupExpression varchar(1000), @bIsSourcePreviousValue bit' + @CrLf + @CrLf

PRINT 'SET @PkgName =''' + REPLACE(@PkgName, '''','''''') + '''' 
PRINT 'SET @StageName =''' + REPLACE(@StageName , '''','''''') + '''' 
PRINT 'SET @PkgDescription =''' + REPLACE(@PkgDescription,'''','''''') + '''' 
PRINT 'SET @CreatedBy =''' + REPLACE(@CreatedBy,'''','''''') + '''' 
PRINT 'SET @UpdatedBy =''' + REPLACE(@UpdatedBy,'''','''''') + '''' 

PRINT 'IF NOT EXISTS ( SELECT * FROM dbo.ETL_Package WHERE PkgName=@PkgName)' 
PRINT 'BEGIN' 
PRINT 'INSERT dbo.ETL_Package (PkgName, PkgDescription, CreatedBy, CreatedDT, UpdatedBy, UpdatedDT, IsActive)  VALUES ' 
PRINT '(' 
PRINT '		@PkgName, @PkgDescription, @CreatedBy, GETDATE(), @UpdatedBy, GETDATE(), 1' 
PRINT ')' 
PRINT 'END' + @CrLf

PRINT 'SELECT @PkgId = PkgId, @PkgKey=PkgId FROM dbo.ETL_Package WHERE PkgName=@PkgName ' 

/*
SELECT @DQMF_ScheduleId=Sch.DQMF_ScheduleId, @StageID=Sch.StageID, @DatabaseId=Sch.DatabaseId, @TableId=Sch.TableId, @IsScheduleActive=Sch.IsScheduleActive, @CreatedBy =REPLACE(CreatedBy,'''',''''''), @UpdatedBy=REPLACE(UpdatedBy,'''','''''')
FROM DQMF_Schedule Sch --INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
WHERE StageID = @StageId 
select * from dqmf_stage where stagename='LoadHCRS SetPatient BRID 9000-9008'
*/

DECLARE mycsr CURSOR FORWARD_ONLY 
FOR 
SELECT Sch.DQMF_ScheduleId, Sch.StageID, Sch.DatabaseId, Sch.TableId, Sch.IsScheduleActive, REPLACE(CreatedBy,'''','''''') as CreatedBy, REPLACE(UpdatedBy,'''','''''') as UpdatedBy
FROM DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
WHERE PkgKey = @pkgkey 
ORDER BY Stage.StageOrder

OPEN mycsr 
FETCH NEXT FROM mycsr INTO @DQMF_ScheduleId, @StageID, @DatabaseId, @TableId, @IsScheduleActive, @CreatedBy, @UpdatedBy
WHILE @@FETCH_STATUS =0
BEGIN
	/* Print the 'Setting the stage information' */

	PRINT 'SET @DatabaseId = ' + CAST(@DatabaseId AS varchar(50))
	PRINT 'SET @TableId = ' + CAST(@TableId AS varchar(50))
	PRINT 'SET @IsScheduleActive = ' + CAST(@IsScheduleActive AS varchar(50))
	PRINT 'SET @CreatedBy = ''' + @CreatedBy  + ''''
	PRINT 'SET @UpdatedBy = ''' + @UpdatedBy  + ''''	

	SELECT @StageName = REPLACE(StageName, '''',''''''), @StageDescription=REPLACE(StageDescription, '''',''''''), @StageOrder=StageOrder 
	FROM dbo.DQMF_Stage WHERE StageID = @StageID

	PRINT 'SET @StageName= ''' + @StageName + ''''
	PRINT 'SET @StageDescription= ' + CASE WHEN @StageDescription IS NULL THEN 'NULL' ELSE  '''' + @StageDescription + '''' END 
	PRINT 'SET @StageOrder= ' + CASE WHEN @StageOrder IS NULL THEN 'NULL' ELSE CAST(@StageOrder AS varchar(20)) END
	PRINT 'SET @StageID = NULL'
	PRINT 'SET @DQMF_ScheduleId = NULL'

	PRINT 'SELECT @StageID=StageID FROM dbo.DQMF_Stage WHERE StageName =@StageName '
	PRINT 'SELECT @DQMF_ScheduleId = Sch.DQMF_ScheduleId 
FROM DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
WHERE StageName = @StageName '

	/* Printing the schedule information */

	PRINT '
	EXECUTE [DQMF].[dbo].[SetStageSchedule] 
	   @pStageID=@StageID
	  ,@pStageName=@StageName
	  ,@pStageDescription=@StageDescription
	  ,@pStageOrder=@StageOrder
	  ,@pDQMF_ScheduleId=@DQMF_ScheduleId
	  ,@pDatabaseId=@DatabaseId
	  ,@pTableId=@TableId
	  ,@pPkgKey=@PkgKey
	  ,@pIsScheduleActive=@IsScheduleActive
	  ,@pCreatedBy=@CreatedBy
	  ,@pUpdatedBy=@UpdatedBy
	'
	PRINT ''
		PRINT '/* This script will try to re-get all variables */'
	PRINT ''
		PRINT 
	'SELECT @DatabaseId = Sch.DatabaseId, @TableId=Sch.TableID, @IsScheduleActive=Sch.IsScheduleActive, @CreatedBy = Sch.CreatedBy, @UpdatedBy=Sch.UpdatedBy, @StageID = Stage.StageID, @StageDescription = Stage.StageDescription, @StageOrder = Stage.StageOrder, @DQMF_ScheduleId = Sch.DQMF_ScheduleId 
	FROM DQMF_Schedule Sch INNER JOIN dbo.DQMF_Stage Stage ON Sch.StageID=Stage.StageID
	INNER JOIN dbo.ETL_Package Pkg ON Sch.PkgKey=Pkg.PkgID
	WHERE StageName = @StageName '
		PRINT '' 
		PRINT 'DELETE FROM dbo.DQMF_BizRuleSchedule WHERE ScheduleID = @DQMF_ScheduleId'

	/* Print the Business Rules information*/

	DECLARE @All_GUIDs varchar(max)
	SET @All_GUIDs =''
	SELECT @All_GUIDs = @All_GUIDs  + CASE WHEN @All_GUIDs ='' THEN '' ELSE ', ' END + '''' + CAST(BR.GUID AS varchar(36)) + '''' FROM dbo.DQMF_bizruleschedule BRSCH INNER JOIN dbo.DQMF_BizRule BR ON BRSCH.BRID = BR.BRID where scheduleid=@DQMF_ScheduleId 

/* Now we do not want to delete and reinsert */	
/*
	PRINT 'DELETE dbo.DQMF_BizRule WHERE GUID IN (' 
	EXEC dbo.PrintTextLine @strOut = @All_GUIDs 
	PRINT  ')' + @CrLf
*/

	/* 
		Use cursor here because if we are going to generate all the br with the ;with result as ()... print @sql method
		there is size limitation in xml string. So I just print the one at a time br, slow but it should not cause error
	 */
	DECLARE @BRID INT
	DECLARE @GUID varchar(36)
	DECLARE BRcsr CURSOR FORWARD_ONLY 
	FOR 
	SELECT BR.BRID, BR.GUID 
	FROM dbo.DQMF_BizRuleSchedule BRSCD INNER JOIN dbo.DQMF_BizRule BR ON BRSCD.BRID=BR.BRID 
	WHERE ScheduleID = @DQMF_ScheduleId 

	OPEN BRcsr
	FETCH NEXT FROM BRcsr INTO @BRID, @GUID
	WHILE @@FETCH_STATUS <> -1
	BEGIN		
			set @sql =''

			PRINT 'SELECT @GUID=''' + @GUID + ''''
			PRINT 'SELECT @BRID=BRID FROM dbo.DQMF_BizRule WHERE GUID=@GUID'
			PRINT ''
			SELECT @sql = 
				'EXEC [dbo].[SetBizRule] ' + @CrLf +			
				'@pBRId=@BRID, ' + @CrLf +			 
				'@pShortNameOfTest=' + CASE WHEN [ShortNameOfTest] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ShortNameOfTest], '''','''''') + '''' END + ', ' + @CrLf +
				'@pRuleDesc=' + CASE WHEN [RuleDesc] IS NULL THEN 'NULL' ELSE '''' + REPLACE([RuleDesc], '''','''''') + ''''  END  + ', ' + @CrLf +
				'@pConditionSQL=' + CASE WHEN [ConditionSQL] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ConditionSQL], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pActionID=' + CASE WHEN [ActionID] IS NULL THEN 'NULL' ELSE CAST([ActionID] AS VARCHAR(10)) END + ', ' + @CrLf +
				'@pActionSQL=@ActionSQL,' + @CrLf +
				'@pOlsonTypeID=' + CASE WHEN [OlsonTypeID] IS NULL THEN 'NULL' ELSE CAST([OlsonTypeID] AS VARCHAR(10)) END + ', ' + @CrLf +
				'@pSeverityTypeID=' +CASE WHEN [SeverityTypeID] IS NULL THEN 'NULL' ELSE CAST([SeverityTypeID] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pSequence=' +CASE WHEN [Sequence] IS NULL THEN 'NULL' ELSE CAST([Sequence] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pDefaultValue=' +CASE WHEN [DefaultValue] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DefaultValue], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pDatabaseId=' +CASE WHEN [DatabaseId] IS NULL THEN 'NULL' ELSE CAST([DatabaseId] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pTargetObjectPhysicalName=' +CASE WHEN [TargetObjectPhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([TargetObjectPhysicalName] AS VARCHAR(100))  + '''' END  + ', ' + @CrLf +
				'@pTargetAttributePhysicalName=' +CASE WHEN [TargetObjectAttributePhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([TargetObjectAttributePhysicalName] AS VARCHAR(100))  + '''' END   + ', ' + @CrLf +
				'@pSourceObjectPhysicalName=' +CASE WHEN [SourceObjectPhysicalName] IS NULL THEN 'NULL' ELSE '''' + REPLACE(CAST([SourceObjectPhysicalName] AS VARCHAR(100)), '''','''''')  + '''' END   + ', ' + @CrLf +
				'@pSourceAttributePhysicalName=' +CASE WHEN [SourceAttributePhysicalName] IS NULL THEN 'NULL' ELSE '''' + CAST([SourceAttributePhysicalName] AS VARCHAR(100))  + ''''  END  + ', ' + @CrLf +
				'@pIsActive=' +CASE WHEN [IsActive] IS NULL THEN 'NULL' ELSE CAST([IsActive] AS VARCHAR(10))  END + ', ' + @CrLf +
				'@pComment=' +CASE WHEN [Comment] IS NULL THEN 'NULL' ELSE '''' + REPLACE([Comment], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pCreatedBy=' + '''' + REPLACE(ISNULL([CreatedBy],SUSER_NAME()), '''','''''') + '''' + ', ' + @CrLf +
				'@pUpdatedBy=@UpdatedBy,' + @CrLf +
				'@pIsLogged='	+ CASE WHEN [IsLogged] IS NULL THEN 'NULL' ELSE CAST([IsLogged] AS varchar(20)) END + ', ' 	+ @CrLf +
				'@pGUID=@GUID, ' 	+ @CrLf +
				'@pFactTableObjectAttributeId=' +CASE WHEN [FactTableObjectAttributeId] IS NULL THEN 'NULL' ELSE CAST([FactTableObjectAttributeId] AS VARCHAR(10))  END +', ' + @CrLF+
				'@pBusinessKeyExpression=' +CASE WHEN [BusinessKeyExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE(CAST([BusinessKeyExpression] AS VARCHAR(500)), '''','''''') + ''''  END 
			FROM dbo.DQMF_BizRule BR 
			WHERE BRID = @BRID
					
			SELECT @ActionSQL = 'SET @ActionSQL = ' + CASE WHEN [ActionSQL] IS NULL THEN 'NULL' ELSE '''' + REPLACE([ActionSQL], '''','''''') + ''''   END +  @CrLf 
			FROM dbo.DQMF_BizRule BizRule
			WHERE BRID = @BRID --= 15721 

			EXEC dbo.PrintTextLine @strOut = @ActionSQL

			EXEC dbo.PrintTextLine @strOut = @sql

			SELECT @sql = @CrLf
			SELECT @sql = @sql + 'IF NOT EXISTS (SELECT * FROM dbo.DQMF_BizRuleSchedule bsc INNER JOIN dbo.DQMF_BizRule br ON bsc.BRID=br.BRID WHERE scheduleid= @DQMF_ScheduleId AND br.BRID=(SELECT BRID FROM DQMF_BizRule WHERE GUID=@GUID))' + @CrLf 
			SELECT @sql = @sql + 'INSERT dbo.DQMF_BizRuleSchedule (BRID, ScheduleID) SELECT (SELECT BRID FROM DQMF_BizRule WHERE GUID=@GUID) AS BRID, @DQMF_ScheduleId ' + @CrLf 
				 FROM dbo.DQMF_bizruleschedule brsc INNER JOIN dbo.DQMF_Bizrule br on brsc.BRID = br.BRID WHERE scheduleid= @DQMF_ScheduleId AND br.GUID = @GUID

			-- SET @sql = REPLACE(@sql, 'TheMarker', '')
			EXEC dbo.PrintTextLine @sql 

			PRINT  @CrLf

			-- Here
			PRINT 'DELETE BRM FROM dbo.DQMF_BizRuleLookupMapping BRM INNER JOIN dbo.DQMF_BizRule BR ON BRM.BRID = BR.BRID WHERE BR.GUID = @GUID'+ @CrLf

			DECLARE BRMappingCsr CURSOR FORWARD_ONLY 
			FOR 
			SELECT BRId, JoinNumber FROM dbo.DQMF_BizRuleLookupMapping WHERE BRID = @BRID

			DECLARE @mappingBRID int, @mappingJoinNumber int

			OPEN BRMappingCsr
			FETCH NEXT FROM BRMappingCsr INTO @mappingBRID, @mappingJoinNumber
			WHILE @@FETCH_STATUS <> -1
			BEGIN

/*				
				[dbo].[SetDQMFBizRuleLookupMapping] 
				@pGUID=@sGUID												-- varchar(200) ???
				@pJoinNumber = @iJoinNumber,								-- int,
				@pSourceLookupExpression = @sSourceLookupExpression,		-- varchar(1000),
				@pDimensionLookupExpression = @sDimensionLookupExpression,	-- varchar(1000),
				@pIsSourcePreviousValue = @bIsSourcePreviousValue			-- bit
*/

				SELECT @sql = 'EXEC [dbo].[SetDQMFBizRuleLookupMapping]  ' + @CrLf +
				'@pGUID= ''' + @GUID  + ''', ' + @CrLf +
				'@pJoinNumber = ' + CASE WHEN [JoinNumber] IS NULL THEN 'NULL' ELSE CAST([JoinNumber] AS varchar(10)) END + ', ' + @CrLf +
				'@pSourceLookupExpression = ' + CASE WHEN [SourceLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([SourceLookupExpression], '''','''''') + ''''  END  + ', ' + @CrLf +
				'@pDimensionLookupExpression = ' + CASE WHEN [DimensionLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DimensionLookupExpression], '''','''''') + ''''   END + ', ' + @CrLf +
				'@pIsSourcePreviousValue = ' + CASE WHEN [IsSourcePreviousValue] IS NULL THEN 'NULL' ELSE CAST([IsSourcePreviousValue] AS VARCHAR(10)) END  + @CrLf 
				FROM dbo.DQMF_BizRuleLookupMapping BizRule
				WHERE BizRule.BRID = @mappingBRID AND BizRule.JoinNumber = @mappingJoinNumber

/*

				SELECT @sql = 'INSERT dbo.DQMF_BizRuleLookupMapping (
				[BRId], 
				[JoinNumber], 
				[SourceLookupExpression], 
				[DimensionLookupExpression], 
				[IsSourcePreviousValue]) ' + 
				' SELECT ' + @CrLf +
				'( SELECT BRID FROM dbo.DQMF_BizRule WHERE GUID =''' + @GUID + ''') AS BRID,' + @CrLf +
				CASE WHEN [JoinNumber] IS NULL THEN 'NULL' ELSE CAST([JoinNumber] AS varchar(10)) END + ' AS [JoinNumber], ' + @CrLf +
				CASE WHEN [SourceLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([SourceLookupExpression], '''','''''') + ''''  END  + ' AS [SourceLookupExpression], ' + @CrLf +
				CASE WHEN [DimensionLookupExpression] IS NULL THEN 'NULL' ELSE '''' + REPLACE([DimensionLookupExpression], '''','''''') + ''''   END + ' AS [DimensionLookupExpression], ' + @CrLf +
				CASE WHEN [IsSourcePreviousValue] IS NULL THEN 'NULL' ELSE CAST([IsSourcePreviousValue] AS VARCHAR(10)) END  
				+ ' AS [IsSourcePreviousValue]' + @CrLf 
				FROM dbo.DQMF_BizRuleLookupMapping BizRule
				WHERE BizRule.BRID = @mappingBRID AND BizRule.JoinNumber = @mappingJoinNumber
*/

				EXEC dbo.PrintTextLine @strOut =@sql

				FETCH NEXT FROM BRMappingCsr INTO @mappingBRID, @mappingJoinNumber
			END
			CLOSE BRMappingCsr
			DEALLOCATE BRMappingCsr
		FETCH NEXT FROM BRcsr INTO @BRID, @GUID
	END
	CLOSE BRcsr
	DEALLOCATE BRcsr


	PRINT '-- End of stage ' + @StageName + @CrLf
	FETCH NEXT FROM mycsr INTO @DQMF_ScheduleId, @StageID, @DatabaseId, @TableId, @IsScheduleActive, @CreatedBy, @UpdatedBy
	--FETCH NEXT FROM mycsr INTO @DQMF_ScheduleId, @StageID, @DatabaseId, @TableId, @IsScheduleActive
END
CLOSE mycsr 
DEALLOCATE mycsr 
PRINT '-- End of Package ' + @PkgName

END

GO
/****** Object:  StoredProcedure [dbo].[GetBizRuleAuditResult]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [dbo].[GetBizRuleAuditResult] 
                   @pFactTableName  varchar(200)='ED.VisitArea' 
					,@pBRName varchar(200)=null				 
AS

DECLARE @SQLStr varchar(max)

--search based on the name:
if not exists(select 1 from DQMF.dbo.DQMF_bizrule where cast(BRID as varchar(100)) = @pBRName)
SET @SQLStr = 'SELECT BRID
				, ShortNameOfTest
				, PreviousValue
				, PreviousAndNewValueCount
				, NewValue
				, TargetObjectPhysicalName 
			FROM  
				AuditResult.BRAuditRowCount  BRAuditRowCount
			WHERE 
				targetObjectPhysicalName ='''+@pFactTableName+'''
				and (rtrim('''+@pBRName+''') ='''' or ShortNameOfTest like ''%'+@pBRName+'%'')
						
			ORDER BY ShortNameOfTest , PreviousAndNewValueCount desc'


--search based on the BRID:
if  exists(select 1 from DQMF.dbo.DQMF_bizrule where cast(BRID as varchar(100)) = @pBRName)
SET @SQLStr = 'SELECT BRID
				, ShortNameOfTest
				, PreviousValue
				, PreviousAndNewValueCount
				, NewValue
				, TargetObjectPhysicalName 
			FROM  
				AuditResult.BRAuditRowCount  BRAuditRowCount
			WHERE 
				targetObjectPhysicalName ='''+@pFactTableName+'''
				and  BRID = '+@pBRName+'
						
			ORDER BY ShortNameOfTest, PreviousAndNewValueCount desc'
	print(@SQLStr)
	exec(@SQLStr)

GO
/****** Object:  StoredProcedure [dbo].[getBizRuleDefaulttest]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[getBizRuleDefaulttest]
as
DECLARE @BRID int, @DefaultValue varchar(100),@PackageName varchar(100),@SQLStr  varchar(max)
SET @PackageName = 'LGH-CensusT-1' 
SET @SQLStr = 'CREATE TABLE [' + @PackageName + 'BizRuleDefault] (PackageName varchar(100))'
EXEC (@SQLStr)
SET @SQLStr = 'INSERT [' + @PackageName + 'BizRuleDefault] (PackageName ) SELECT ''' + @PackageName + ''''
print @SQLStr
EXEC (@SQLStr)
 
SELECT  br.BRID,DefaultValue into #Values from dbo.DQMF_BizRule br
inner join dbo.DQMF_BizRuleSchedule brsc on br.BRID = brsc.BRID 
inner join dbo.DQMF_Schedule sc on sc.DQMF_ScheduleId = ScheduleID
inner join dbo.ETL_Package pk on pk.PkgID = sc.PkgKey
where PkgName = @PackageName AND ActionID = 0

WHILE EXISTS (Select BRID FROM  #Values)
BEGIN
     SET @BRID = (SELECT Top 1 BRID FROM #Values)
     SET @DefaultValue = (SELECT top 1 DefaultValue FROM #Values)

    SET @SQLStr = 'ALTER TABLE [' + @PackageName + 'BizRuleDefault] ADD BR'+ convert(varchar(20),@BRID) +'  VARCHAR(20)'
    EXEC (@SQLStr)
    SET @SQLStr = 'UPDATE [' + @PackageName + 'BizRuleDefault] SET BR'+ convert(varchar(20),@BRID) +'   = ''' + @DefaultValue +''''
    print @SQLStr
    EXEC (@SQLStr)
    delete from #Values where @BRID = BRID
END
DROp Table #Values
SET @SQLStr = 'SELECT * FROM [' + @PackageName + 'BizRuleDefault]'
EXEC (@SQLStr)
SET @SQLStr = 'DROP TABLE [' + @PackageName + 'BizRuleDefault]'
EXEC (@SQLStr)
GO
/****** Object:  StoredProcedure [dbo].[getBizrulesOnFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[getBizrulesOnFact]  
	@FactTableName varchar(100) = 'ED.VisitFact'
	,@BizRuleName varchar(100) = ''
as 

	declare @sql varchar(max)
		
		if exists (select 1 from AuditResult.BRAuditRowCount where cast(BRID as varchar(100)) =@BizRuleName )
		set @sql = 'select TargetObjectPhysicalName
			,BRID
			,ShortNameOfTest
			,cast(BRID as varchar(100))+'' ''+ShortNameOfTest FullName
			,sum(PreviousAndNewValueCount) TotalBRVs
			from AuditResult.BRAuditRowCount
				where TargetObjectPhysicalName ='''+@FactTableName+'''
				and cast(BRID as varchar(100)) = ('+@BizRuleName+')
				group by TargetObjectPhysicalName
			,BRID
			,ShortNameOfTest
		ORDER BY BRID
'
else	
		set @sql = 'select TargetObjectPhysicalName
			,BRID
			,ShortNameOfTest
			,cast(BRID as varchar(100))+'' ''+ShortNameOfTest FullName
			,sum(PreviousAndNewValueCount) TotalBRVs
			from AuditResult.BRAuditRowCount
				where TargetObjectPhysicalName ='''+@FactTableName+'''
				and ShortNameOfTest like ''%'+@BizRuleName+'%''
				group by TargetObjectPhysicalName
			,BRID
			,ShortNameOfTest
		ORDER BY BRID
'
		print( @sql)
			execute(@sql)
			

GO
/****** Object:  StoredProcedure [dbo].[GetBRVDrillDown]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetBRVDrillDown]  
                   @pFactTableName  varchar(200) ,
                   @pBRID int,
                   @pPreviousValue varchar(500)

AS

DECLARE @SQLStr varchar(max), @previousvalue varchar(1000)

SET @previousvalue = (
					SELECT 
						case  
							When @pPreviousValue is null 
							THEN ' AND PreviousValue IS NULL ' 
							ELSE 'AND PreviousValue = ''' + ISNULL(@pPreviousValue,0) + '''' END)
print @previousvalue
SET @SQLStr = 'SELECT 
               BRA.PreviousValue
              ,BRA.NewValue
              ,BRA.ETLID        
               FROM DSDW.'+@pFactTableName+' fact 
                        INNER JOIN dbo.ETLBizRuleAuditFact BRA
                               ON fact.ETLAuditID = BRA.ETLID                       
                WHERE (isCorrected is null or isCorrected = 0 )
                       ' + @previousvalue + '
                       AND BRA.BRID ='+cast(@pBRID as varchar(10))
                             
EXEC(@SQLStr)

/*
[GetBRVDrillDown]  
                   @pFactTableName  = 'ed.visitarea' ,
                   @pBRID = 1366,
                   @pPreviousValue  = ''
*/

GO
/****** Object:  StoredProcedure [dbo].[GetDQMFScheduleID]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Grant S
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetDQMFScheduleID]
	@pStageName varchar(50),
    @pScheduleID int output
AS
BEGIN
	SET NOCOUNT ON;
   SET @pScheduleID = (SELECT DQMF_ScheduleId 
                         FROM dbo.DQMF_Schedule sc
                              INNER JOIN dbo.DQMF_Stage st 
                                    ON sc.StageID = st.StageID
                        WHERE StageName = @pStageName)
END


GO
/****** Object:  StoredProcedure [dbo].[GetETLAuditIdInfo]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
 Author:		            Daniel Pepermans
 Create date:               24 Sep 2010
 Description:	            Returns ETL audit information given a fact table query.
 Change History:
<Date>                  <Alias>                <Desc>
 =============================================*/
CREATE PROCEDURE [dbo].[GetETLAuditIdInfo]
    @ETLAuditId bigint = NULL,
    @Query nvarchar(max) = NULL
AS  

SET NOCOUNT ON

DECLARE 
        @ExtractFileKey bigint,
        @PkgExecKey bigint,
        @stmt nvarchar(2000)

CREATE TABLE #ETLAudit(
    ETLAuditId bigint NOT NULL )

IF @Query IS NOT NULL
BEGIN
    SET @stmt = N'SELECT ETLAuditId AS ''Extract Record'', * FROM ' + @Query
    EXEC sp_executesql @stmt = @stmt

    SET @stmt = N'SELECT ETLAuditId FROM ' + @Query
    INSERT INTO #ETLAudit( ETLAuditId )
    EXEC sp_executesql @stmt = @stmt

END
ELSE IF @ETLAuditId IS NOT NULL
BEGIN
    INSERT INTO #ETLAudit( ETLAuditId )
    VALUES( @ETLAuditId )
END
ELSE
BEGIN
    RAISERROR( 'GetETLAuditIdInfo: You must specify either @ETLAuditId or @Query!', 16, 0 )
    RETURN 1
END

SELECT ESR.ETLId AS 'ETL Staging Record', ESR.PkgExecKey, ESR.ExtractFileKey, ESR.ProcessedDT, ESR.MergedETLID
FROM ETLStagingRecord ESR
    JOIN #ETLAudit A
        ON A.ETLAuditId = ESR.ETLId

SELECT A.ETLAuditId AS 'Audit Extract File', AEF.*
FROM ETLStagingRecord ESR
    JOIN #ETLAudit A
        ON A.ETLAuditId = ESR.ETLId
    JOIN AuditExtractFile AEF
        ON AEF.ExtractFileKey = ESR.ExtractFileKey

SELECT A.ETLAuditId AS 'Audit Package Execution', APE.*
FROM ETLStagingRecord ESR
    JOIN #ETLAudit A
        ON A.ETLAuditId = ESR.ETLId
    JOIN AuditPkgExecution APE
        ON APE.PkgExecKey = ESR.PkgExecKey

SELECT F.ETLId AS 'Biz Rule Audit Fact', S2.StageName, F.DQMF_ScheduleId, F.BRId, BR.ShortNameOfTest, F.PreviousValue, F.NewValue, F.ActionID, F.PkgExecKey
FROM ETLBizRuleAuditFact F
    JOIN DQMF_BizRule BR
        ON BR.BRId = F.BRId
    JOIN DQMF_BizRuleSchedule BRS
        ON BRS.BRId = BR.BRId
    JOIN DQMF_Schedule S
        ON S.DQMF_ScheduleId = BRS.ScheduleId
    JOIN DQMF_Stage S2
        ON S2.StageId = S.StageId
    JOIN #ETLAudit A
        ON A.ETLAuditId = F.ETLId

GO
/****** Object:  StoredProcedure [dbo].[GetFailedBizRuleValue]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
--Aug 20 2012 Alan --  Update routine to allow column name to be passed in to allow the client 
--						to work where the ‘TargetObjectAttributePhysicalName’ is different for 
--						between the Staging and fact tables -- Jul 23 2012 
--
--Sep 20 2012 Alan --  Updated routine to use VisitStartDateID instead of RegistrationDateID because 
--						number of records (Powell River) where RegistrationDateID was Null.  RegistrationDateID 
--						was wrong field to use
--Nov 26 2012 Alan --  Remove 'PreviousValue is not null AND ' from criteria in @SQLStr
--
-- =============================================
CREATE PROCEDURE  [dbo].[GetFailedBizRuleValue]  
	 @pBizRuleName varchar(100)
    ,@pFactTableName varchar(100)
    ,@pFactColumnName varchar(100) = ''
    ,@pRuleActionType int = 0
    ,@pExcludeList varchar(500) = ''
    ,@pShowCorrected  bit = 0

AS
BEGIN

	SET NOCOUNT ON;
DECLARE @SQLStr as varchar(4000)
        ,@FactFieldName varchar(100)
        ,@DateField varchar(100)
        ,@PatientJoin varchar(max)
        , @PatientWhere varchar(max)
       ,@BRID int

SELECT  @FactFieldName = TargetObjectAttributePhysicalName, @BRID = BRID
FROM dbo.DQMF_BizRule   BR 
WHERE  convert(varchar(10),BR.BRID) + ' - ' + ShortNameOfTest  = @pBizRuleName

if isnull(@pFactColumnName,'') <> ''
	set @FactFieldName = @pFactColumnName

  SELECT @DateField = case @pFactTableName
					  --WHEN 'ED.VisitFAct' THEN 'RegistrationDateID'
                      WHEN 'ED.VisitFAct' THEN 'VisitStartDateID'
                      WHEN 'ADTC.AdmissionFact' THEN 'AdmissionDateID'
                      WHEN 'ADTC.CensusFact'  THEN 'CensusDateID'
                      WHEN 'Adtc.DischargeFact' THEN 'DischargeDateID'
                      WHEN 'Adtc.TransferFact' THEN 'TransferDateID'
                      WHEN 'ADR.AbstractAcuteFact' THEN 'DischargeDateID'
                      ELSE 'Unknown' END


IF @DateField <> 'Unknown' 
	and @pFactTableName not in ('ADTC.CensusFact','Adtc.TransferFact')
BEGIN
	SET @PatientJoin = 'INNER JOIN DSDW.DIM.PATIENT PAT ON PAT.PATIENTID = FACT.PATIENTID'
    SET @PatientWhere = 'AND PAT.SOURCECREATEDDATE = (SELECT MAX(SOURCECREATEDDATE) FROM DSDW.DIM.PATIENT 
                                  WHERE fact.patientID = patientID and SOURCECREATEDDATE <=  FACT.' + @DateField +') '
END
ELSE
BEGIN
    SET @PatientJoin = ''
    SET @PatientWhere = ''
END

IF EXISTS (SELECT * FROM  DSDW.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA + '.'+ TABLE_NAME = rtrim(@pFactTableName) AND COLUMN_NAME = 'FacilityID')         
BEGIN
	SET  @SQLStr =   'SELECT distinct   PreviousValue,' + @FactFieldName + ' CurrentValue, FacilityID, ISForDQ ,ISCorrected  FROM  
		   dbo.DQMF_BizRule   BR  INNER JOIN dbo.ETLBizRuleAuditFact BRAF
		  ON BRAF.BRID = BR.BRID  INNER JOIN DSDW.' + @pFactTableName + ' FACT  
		  ON FACT.ETLAuditID = BRAF.ETLID ' + @PatientJoin + '  
	  WHERE   PreviousValue not in (select ListValue from dbo.fntCSVList(''' + @pExcludeList +''')) 
         ' +@PatientWhere +'
		 AND (ISCorrected <= ' + convert(varchar(1),@pShowCorrected) +' OR ISCorrected is NUll)  
		 AND BR.BRID = ' + convert(varchar(10),@BRID) + ' ORDER BY PreviousValue'
END ELSE
BEGIN

SET  @SQLStr =   'SELECT distinct  PreviousValue,' + @FactFieldName + ' CurrentValue,0, ISForDQ ,ISCorrected  FROM  
		   dbo.DQMF_BizRule   BR  INNER JOIN dbo.ETLBizRuleAuditFact BRAF
		  ON BRAF.BRID = BR.BRID  INNER JOIN DSDW.' + @pFactTableName + ' FACT  
		  ON FACT.ETLAuditID = BRAF.ETLID  ' + @PatientJoin + ' 
	  WHERE PreviousValue not in (select ListValue from dbo.fntCSVList(''' + @pExcludeList +''')) 
         ' +@PatientWhere +'
		 AND (ISCorrected <= ' + convert(varchar(1),@pShowCorrected) +' OR ISCorrected is NUll) 
		 AND BR.BRID = ' + convert(varchar(10),@BRID) + ' ORDER BY PreviousValue'
END
print @SQLStr
EXEC (@SQLStr)
END


/*
[GetFailedBizRuleValue] @pBizRuleName = '111937 - AdmissionDrID Lookup',
@pFactTableName = 'ADTC.AdmissionFact',
@pRuleActionType  = 0,
@pExcludeList = ''

select * from dbo.DQMF_BizRule BR  where convert(varchar(10),BR.BRID) + ' - ' + ShortNameOfTest =  '1118 - Accident Date Lookup'
SELECT  distinct TargetObjectAttributePhysicalName
FROM dbo.DQMF_BizRule   BR 
WHERE  convert(varchar(10),BRID) + ' - ' + ShortNameOfTest  = '1118 - Accident Date Lookup'


SELECT  top 100 PreviousValue,AccidentDateID CurrentValue,0, ISForDQ ,ISCorrected  FROM  
		   dbo.DQMF_BizRule   BR  INNER JOIN dbo.ETLBizRuleAuditFact BRAF
		  ON BRAF.BRID = BR.BRID  INNER JOIN DSDW.ED.VisitFact FACT  
		  ON FACT.ETLAuditID = BRAF.ETLID  
	  WHERE  PreviousValue is not null AND PreviousValue not in (select ListValue from dbo.fntCSVList('')) 
		 AND (ISCorrected <= 0 OR ISCorrected is NUll) 
		 AND  convert(varchar(10),BR.BRID) + ' - ' + ShortNameOfTest =  '1118 - Accident Date Lookup' ORDER BY PreviousValue

select ListValue from dbo.fntCSVList('')
*/








GO
/****** Object:  StoredProcedure [dbo].[GetMDObjectAttribute]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		GrantS
-- Create date: 5-21-2010
-- Description:	Retruns 1 to n rows from MD_ObjectAttribute based on ObjectAttributeID,
---            ObjectID or AttributeID or AttributePhysicalName
-- =============================================
CREATE PROCEDURE [dbo].[GetMDObjectAttribute]

	@pObjectAttributeID int = null, 
	@pObjectID int = null,
    @pAttributeID int = null,
    @pAttributePhysicalName varchar(50) = null
AS
BEGIN
	SELECT [ObjectID]
		  ,[ObjectAttributeID]
		  ,[AttributeID]
		  ,[AttributeDetailID]
		  ,[Sequence]
		  ,[AttributePhysicalName]
		  ,[Datatype]
		  ,[AttributeLength]
		  ,[AttibuteExampleValues]
		  ,[AttributeComment]
		  ,[AttributeDefaultValue]
		  ,[AttributeETLRulesDescription]
		  ,[AttributeUsageTips]
		  ,[ISActive]
		  ,[BaselineCreatedDT]
		  ,[BaselineIntegerMean]
		  ,[BaselineIntegerUpperControlLimit]
		  ,[BaselineIntegerLowerControlLimit]
		  ,[BaselineRealMean]
		  ,[BaselineRealUpperControlLimit]
		  ,[BaselineRealLowerControlLimit]
		  ,[PercentMissing]
		  ,[ContentMap]
		  ,[QualityIndicator]
		  ,[CreatedBy]
		  ,[CreatedDT]
		  ,[UpdatedBy]
		  ,[UpdatedDT]
	  FROM [DQMF].[dbo].[MD_ObjectAttribute]
      WHERE ObjectAttributeID = ISNULL(@pObjectAttributeID,ObjectAttributeID)
        AND ObjectID  = ISNULL(@pObjectID,ObjectID )
        AND AttributeID = ISNULL(@pAttributeID,AttributeID)
        AND AttributePhysicalName = ISNULL(@pAttributePhysicalName,AttributePhysicalName)
END

GO
/****** Object:  StoredProcedure [dbo].[GetMDOject]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Grants
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetMDOject]
@pObjectID int = null,
@pObjectName varchar(50) = null,
@pObjectType varchar(50) = null,
@pObjectPurpose varchar(50) = null
	
AS
BEGIN

	SET NOCOUNT ON;

	SELECT *
     FROM dbo.MD_Object
     WHERE ObjectPhysicalName = ISNULL(@pObjectName,ObjectPhysicalName)
       AND ObjectID = ISNULL(@pObjectID,ObjectID) 
       AND ObjectType = ISNULL(@pObjectType,ObjectType) 
       AND ObjectPurpose = ISNULL(@pObjectPurpose,ObjectPurpose) 
END


GO
/****** Object:  StoredProcedure [dbo].[getMigratingObjects]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		David George
-- Create date: 20150409
-- Description:	returns a table-valued list of objects that are intended to be migrated between environments.
--              proc is called from a ssis package which executes the transfer
-- =============================================
CREATE PROCEDURE [dbo].[getMigratingObjects] 
          @pDatabaseName varchar(50) = 'DQMF',
          @pCopyData bit = 1    ,
          @Debug tinyint = 3
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT  ObjectPhysicalName,
			ObjectSchemaName, 
			'[' + ObjectSchemaName + '].[' + ObjectPhysicalName + ']' QualifiedTableName 
	 FROM msdb..TablesToCopy
	WHERE ObjectDBName = @pDatabaseName
      AND IsActive = 1    
END


GO
/****** Object:  StoredProcedure [dbo].[GetPackageBizRule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Grant Stephens
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetPackageBizRule] 
	@pPakageName  varchar(100),
    @pRuleActionType int
AS
BEGIN

	SET NOCOUNT ON;


	SELECT BR.[BRId] ,
	BR.[ShortNameOfTest] ,
        BR.RuleDesc,
	BR.[ConditionSQL] ,
	BR.[ActionID] ,
	BR.[ActionSQL] ,
	BR.[OlsonTypeID] ,
	BR.[SeverityTypeID] ,
	BR.[Sequence] ,
	BR.[DefaultValue] ,
	BR.[DatabaseId],
	BR.[TargetObjectPhysicalName],
	BR.[TargetObjectAttributePhysicalName],
	BR.[SourceObjectPhysicalName]  ,
	BR.[SourceAttributePhysicalName] ,
	BR.[IsActive] ,
        BR.Comment,
	BR.[CreatedBy] ,
	BR.[CreatedDT] ,
	BR.[UpdatedBy] ,
	BR.[UpdatedDT]
FROM  
       dbo.DQMF_BizRule   BR
        INNER JOIN dbo.DQMF_BizRuleSchedule BRS
      On BR.BRID = BRS.BRID
        INNER JOIN dbo.DQMF_Schedule SCH
      ON SCH.DQMF_ScheduleId = BRS.ScheduleID
        INNER JOIN dbo.ETL_Package PAC
      ON PAC.PkgID = SCH.PkgKey
     WHERE PkgName = @pPakageName 
           AND ActionID = @pRuleActionType

END
/*
exec GetPackageBizRule @pPakageID  = 77,
    @pRuleActionType = 0
*/

GO
/****** Object:  StoredProcedure [dbo].[GetPkgExecID]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetPkgExecID]
	@pExtractFileID bigint
   ,@pPkgExecID bigint output
AS
BEGIN
   SET NOCOUNT ON;
   SET @pPkgExecID = (SELECT PkgExecKey
					  FROM dbo.AuditExtractFile
					  WHERE ExtractFileKey = @pExtractFileID )

END

GO
/****** Object:  StoredProcedure [dbo].[GETQualityMetricRating]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
------------------------------------------------
/* -- Testing
declare @parameterstring varchar(max), @site varchar(5), @Date varchar(max), @shift varchar(5)

set	@site = 'VGH'
set	@shift = '%'
SET @Date =  '20110501'

SELECT @parameterstring =
' SELECT e.ETLAuditID FROM EDMART.dbo.ED_Visit e  
  INNER JOIN EDMART.Dim.Facility f ON E.facilityid = f.facilityid 
  LEFT OUTER JOIN  EDMART.Dim.Time DT on e.StartTimeID = DT.TimeID 
  WHERE f.facilityshortname = ''' + @site + ''' 
    AND StartdateID = CONVERT(varchar(8),convert(smalldatetime,''' + @Date +'''),112) 
    AND ShiftType_12Hr LIKE ''' + @shift + '''' --as parameterstring

--print (@parameterstring)

EXEC dbo.GETQualityMetricRating
	@pQualityRatingId = 11,
	@pParameterString = @parameterstring,
	@pIsSummary = 0

*/
------------------------------------------------

CREATE procedure [dbo].[GETQualityMetricRating]
@pQualityRatingId int,
@pParameterString varchar(max),
@pIsSummary bit = 1
AS
DECLARE  @SQLStr varchar(max)

IF @pIsSummary = 1
BEGIN
	CREATE TABLE #temp (QMRating float,QualityRatingId int,ParameterString varchar(max));

	SELECT @SQLStr = 'WITH ReportETLID AS (' + @pParameterString +')
	INSERT #temp 
	SELECT ISNULL(CONVERT(float,(COUNT(a.ETLAuditID) - sum(COALESCE (b.ETLAuditID/b.ETLAuditID,0))))/CONVERT(float,COUNT(a.ETLAuditID))  * 100,100) QMRating
	,'+ CONVERT(varchar(10), @pQualityRatingId) + ' QualityRatingId
    , ''' + replace(@pParameterString,'''','''''') + '''ParameterString 
	FROM ReportETLID a 
	LEFT OUTER JOIN dbo.ETLStagingRecordQualityRating b ON a.ETLAuditID = b.ETLAuditID AND QualityRatingId = ' + CONVERT(varchar(10),@pQualityRatingId) 

    exec (@SQLStr)
	SELECT * FROM #temp
END

IF @pIsSummary = 0 
BEGIN

	CREATE TABLE #Total (TotalRecords int)

	SELECT @SQLStr = 'WITH ReportETLID AS (' + @pParameterString +')
	
	INSERT INTO #Total
	SELECT COUNT(a.ETLAuditID) TotalRecords
	FROM ReportETLID a '

	EXEC (@SQLStr)
		
	---------------------------------------------
	CREATE TABLE #temptwo (BRId int
					  ,RuleName varchar(100)
					  ,RuleDesc varchar(250)
					  ,ETLAuditID bigint
					  ,FactTableObjectAttributeId int);

	SELECT @SQLStr = 'With ReportETLID AS (' + @pParameterString +')
	INSERT #temptwo 
	SELECT b.brid
		  ,b.ShortNameOfTest RuleName
		  ,b.RuleDesc
		  ,rpt.ETLAuditID
		  ,b.FactTableObjectAttributeId
	FROM ReportETLID rpt
	INNER JOIN dbo.ETLStagingRecordQualityRating qa ON qa.ETLAuditID = rpt.ETLAuditID
	INNER JOIN dbo.AuditQulaityRatingBizRule qaBR ON qaBR.QualityRatingID = qa.QualityRatingID
	CROSS APPLY (SELECT TOP 1 a.BRId
				 FROM dbo.ETLBizruleAuditFact a
				 WHERE a.ETLID = rpt.ETLAuditID 
				   AND a.BRId = qaBR.BRId) AuditFact
    INNER JOIN dbo.DQMF_BizRule b ON b.BRId = AuditFact.BRId 
	WHERE qaBR.QualityRatingID = ' + CONVERT(varchar(10),@pQualityRatingId) 
	
	exec (@SQLStr)

	--Output
	SELECT 0 SortOrder
		  ,t.brid as brid
		  ,t.RuleName
		  ,CASE WHEN t.RuleDesc = '' THEN NULL ELSE t.RuleDesc END RuleDesc
		  ,(SELECT MD.DatabaseName + '.'+ MD.ObjectSchemaName + '.'+ MD.ObjectPhysicalName + '.'+ MD.AttributePhysicalName 
			FROM dbo.vwMD_PhyscialName MD 
			WHERE MD.ObjectAttributeID = t.FactTableObjectAttributeId) FactTableAttributeName
		  ,COUNT(t.ETLAuditID) Records
		  ,(SELECT TotalRecords FROM #Total) TotalRecords
		FROM #temptwo t
	GROUP BY t.brid,t.RuleName,t.RuleDesc, t.FactTableObjectAttributeId
	----------------------------------------------
	UNION ALL -- Total
	----------------------------------------------
	SELECT 1 SortOrder
		  ,NULL as brid
		  ,'Total Count of Violations' RuleName
		  ,NULL RuleDesc
		  ,NULL FactTableAttributeName
		  ,COUNT(t.ETLAuditID) Records
		  ,(SELECT TotalRecords FROM #Total) TotalRecords
		FROM #temptwo t
	----------------------------------------------
	UNION ALL -- Total
	----------------------------------------------
	SELECT 2 SortOrder
		  ,NULL as brid
		  ,'Total Unique Records with Violation' 
		  ,NULL RuleDesc
		  ,NULL FactTableAttributeName
		  ,COUNT(DISTINCT t.ETLAuditID) Records
		  ,(SELECT TotalRecords FROM #Total) TotalRecords
		FROM #temptwo t
	ORDER BY 1, 6 DESC
	
	DROP TABLE #temptwo
	DROP TABLE #Total
	
END
GO
/****** Object:  StoredProcedure [dbo].[GetStageBizRule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Grant Stephens
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetStageBizRule] 
	@pStageName  varchar(100),
    @pRuleActionType int = null
AS
BEGIN

	SET NOCOUNT ON;


	SELECT BR.[BRId] ,
	BR.[ShortNameOfTest] ,
        BR.RuleDesc,
	BR.[ConditionSQL] ,
	BR.[ActionID] ,
	BR.[ActionSQL] ,
	BR.[OlsonTypeID] ,
	BR.[SeverityTypeID] ,
	BR.[Sequence] ,
	BR.[DefaultValue] ,
	BR.[DatabaseId],
	BR.[TargetObjectPhysicalName],
	BR.[TargetObjectAttributePhysicalName],
	BR.[SourceObjectPhysicalName]  ,
	BR.[SourceAttributePhysicalName] ,
	BR.[IsActive] ,
        BR.Comment,
	BR.[CreatedBy] ,
	BR.[CreatedDT] ,
	BR.[UpdatedBy] ,
	BR.[UpdatedDT]
FROM  
       dbo.DQMF_BizRule   BR
        INNER JOIN dbo.DQMF_BizRuleSchedule BRS
      On BR.BRID = BRS.BRID
        INNER JOIN dbo.DQMF_Schedule SCH
      ON SCH.DQMF_ScheduleId = BRS.ScheduleID
        INNER JOIN dbo.DQMF_Stage Stage
      ON Stage.StageID = SCH.StageID
     WHERE StageName = @pStageName 
           AND ActionID = ISnull(@pRuleActionType,ActionID)

END
/*
exec GetPackageBizRule @pPakageID  = 77,
    @pRuleActionType = 0
*/




GO
/****** Object:  StoredProcedure [dbo].[GetStageID]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetStageID]
(
@pStageName varchar(50),
@pStageOrder int,
@pStageID int output
)
AS
BEGIN

    select @pStageID = stageid
    from dqmf.dbo.DQMF_Stage s
    WHERE s.stagename = @pStageName
    AND   s.StageOrder = @pStageOrder

    IF (ISNULL(@pStageID,0) = 0)
    BEGIN
		
        --select @pStageID = max(stageid)+1    -- if not using IDENTITY
        --from dqmf.dbo.DQMF_Stage s
        INSERT INTO dqmf.dbo.DQMF_Stage VALUES (@pStageName, @pStageName, @pStageOrder)

		select @pStageID = stageid
		from dqmf.dbo.DQMF_Stage s
		WHERE s.stagename = @pStageName
		AND   s.StageOrder = @pStageOrder

    END
END

GO
/****** Object:  StoredProcedure [dbo].[GetStartETLID]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetStartETLID] 
	@pRecordCount bigint,
    @pAuditControl varchar(50) = 'VCHA',
    @pStartID bigint output,
    @pEndId  bigint output
AS
BEGIN
	SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    BEGIN TRANSACTION
			SET @pStartID = (SELECT LastValueFor_ETLId + 1 
                               FROM dbo.ETL_AuditControl
                              WHERE ETL_AuditControlRecord = @pAuditControl)
            SET @pEndId = @pStartID + @pRecordCount - 1
            UPDATE dbo.ETL_AuditControl 
               SET LastValueFor_ETLId = @pEndId
              WHERE ETL_AuditControlRecord = @pAuditControl 
   COMMIT TRANSACTION
END


GO
/****** Object:  StoredProcedure [dbo].[getSubjectAreaFactTableList]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[getSubjectAreaFactTableList]
	@pSubjectAreaID int = null
as
if exists  (select 1 where @pSubjectAreaID is null) 
	SELECT  MD_Object.SubjectAreaID,MD_SubjectArea.SubjectAreaName, ' ' TableName
				FROM dbo.MD_Object MD_Object 
				join dbo.MD_SubjectArea on MD_Object.SubjectAreaID = MD_SubjectArea.SubjectAreaID
					and ((@pSubjectAreaID is null) or  (MD_SubjectArea.SubjectAreaID = @pSubjectAreaID))
	where ObjectPurpose ='Fact'
	group by  MD_Object.SubjectAreaID,MD_SubjectArea.SubjectAreaName
order by  MD_SubjectArea.SubjectAreaName,MD_Object.SubjectAreaID
else 
SELECT MD_Object.SubjectAreaID,MD_SubjectArea.SubjectAreaName, ObjectSchemaName + '.'+ ObjectPhysicalName TableName
				FROM dbo.MD_Object MD_Object 
				join dbo.MD_SubjectArea on MD_Object.SubjectAreaID = MD_SubjectArea.SubjectAreaID
					and ((@pSubjectAreaID is null) or  (MD_SubjectArea.SubjectAreaID = @pSubjectAreaID))
	where ObjectPurpose ='Fact'
order by TableName

/*
this code actually checks if the data is available in the summary table first: 
SELECT MD_SubjectArea.SubjectAreaID,SubjectAreaName FROM dbo.MD_SubjectArea
join  (
			SELECT MD_Object.SubjectAreaID, ObjectSchemaName + '.'+ ObjectPhysicalName TableName
			FROM dbo.MD_Object MD_Object
			join 
			(
			select TargetObjectPhysicalName TableName  from AuditResult.BRAuditRowCount
			group by TargetObjectPhysicalName ) tablesThatAreSummarized
			 on ObjectSchemaName + '.'+ ObjectPhysicalName  = tablesThatAreSummarized.TableName  

) Tables
on Tables.SubjectAreaID = MD_SubjectArea.SubjectAreaID
group by MD_SubjectArea.SubjectAreaID,SubjectAreaName 
order by SubjectAreaName
*/
GO
/****** Object:  StoredProcedure [dbo].[InsBizRuleSchedule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		GRants
-- Create date: <Create Date,,>
-- Description:	 insert row to Biz rule Schedule
-- =============================================
CREATE PROCEDURE [dbo].[InsBizRuleSchedule]
    @pGUID varchar(200),
    @pScheduleID int
AS
BEGIN

	SET NOCOUNT ON;
if not exists(SELECT * FROM dbo.DQMF_BizRuleSchedule brs
                INNER JOIN  dbo.DQMF_BizRule br on br.BRID = brs.BRID
            WHERE GUID = @pGUID AND ScheduleID = @pScheduleID)
    INSERT dbo.DQMF_BizRuleSchedule (BRID, ScheduleID)
    SELECT BRID,@pScheduleID FROM  dbo.DQMF_BizRule WHERE GUID = @pGUID
END



GO
/****** Object:  StoredProcedure [dbo].[InsETLBizRuleAuditFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[InsETLBizRuleAuditFact]
	       @pETLId int
           ,@pDQMF_ScheduleId int
           ,@pBRId int
           ,@pDatebaseId int
           ,@pTableId int
           ,@pAttributeId int
           ,@pPreviousValue varchar(50)
           ,@pNewValue varchar(50)
           ,@pOlsonTypeID int
           ,@pActionID int
           ,@pSeverityTypeID int
           ,@pNegativeRating tinyint
AS
BEGIN
SET NOCOUNT ON;




INSERT INTO [DQMF].[dbo].[ETLBizRuleAuditFact]
           ([ETLId]
           ,[DQMF_ScheduleId]
           ,[BRId]
           ,[DatebaseId]
           ,[TableId]
           ,[AttributeId]
           ,[PreviousValue]
           ,[NewValue]
           ,[OlsonTypeID]
           ,[ActionID]
           ,[SeverityTypeID]
           ,[NegativeRating])
     VALUES
           ( @pETLId, 
            @pDQMF_ScheduleId, 
            @pBRId, 
            @pDatebaseId,
            @pTableId,
            @pAttributeId, 
            @pPreviousValue, 
            @pNewValue, 
            @pOlsonTypeID, 
            @pActionID, 
            @pSeverityTypeID, 
            @pNegativeRating)
END


GO
/****** Object:  StoredProcedure [dbo].[InsETLStagingRecord]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[InsETLStagingRecord]
             @pETLId bigint,
             @pPkgExecKey bigint
             ,@pExtractFileKey bigint
AS
             
INSERT INTO [DQMF].[dbo].[ETLStagingRecord]
           ([ETLId]
           ,[PkgExecKey]
           ,[ExtractFileKey]
           ,[ProcessedDT])
     VALUES
           (@pETLId
           ,@pPkgExecKey
           ,@pExtractFileKey
           ,GETDATE())



GO
/****** Object:  StoredProcedure [dbo].[MD_PopulateDataLoadingDetail]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[MD_PopulateDataLoadingDetail] 
(@RefreshDate datetime = null,
@pSubjectArea varchar(20) = null)

as

--Declare @RefreshDateID int
--Declare @pSubjectArea varchar(20)
Declare @SQLText nvarchar(max),
		@SubjectArea varchar(100),
		@DataSource varchar(100),
		@FactTable varchar(100)

--set @pSubjectArea = null

Delete from dqmf.dbo.MD_DataLoadingDetail
where (SubjectArea like @pSubjectArea + '%' or 'All' = isnull(@pSubjectArea,'All'))
AND (LoadDate >= convert(varchar(20),isnull(@RefreshDate,'01/01/1980')))


DECLARE c_1 CURSOR FAST_FORWARD LOCAL FOR
Select SubjectArea,SDATable,'SDA' as DataSource, FactName 
from DQMF.dbo.MD_DataLoadingStructure
where (SubjectArea = @pSubjectArea or 'ALL' = isNull(@pSubjectArea,'ALL'))
union all
Select SubjectArea,DSDWTable,'DSDW' as DataSource, FactName 
from DQMF.dbo.MD_DataLoadingStructure
where (SubjectArea = @pSubjectArea or 'ALL' = isNull(@pSubjectArea,'ALL'))
union all
Select SubjectArea,MartTable,'Mart' as DataSource, FactName
from DQMF.dbo.MD_DataLoadingStructure
where (SubjectArea = @pSubjectArea or 'ALL' = isNull(@pSubjectArea,'ALL'))

OPEN c_1

    FETCH NEXT FROM c_1 INTO @SubjectArea,@SQLText,@DataSource,@FactTable
    WHILE @@FETCH_STATUS <> -1
    BEGIN
		set @SQLText =  'insert into dqmf.dbo.MD_DataLoadingDetail (SubjectArea, RecordSet, FactName, PackageName,FileName, LoadDate,KeyDateID, RecordCount) 
				select ''' + @SubjectArea + ''' as SubjectArea,''' +  @DataSource + ''' as RecordSet,''' + @FactTable + ''' as FactTable,*
					from (' + @SQLText + ') as Dta where LoadDate >= ''' + convert(varchar(20),isnull(@RefreshDate,'01/01/1980')) + ''' order by 2 desc,1'
		print @SubjectArea + ': -' +  @SQLText
		EXEC sp_executesql @stmt = @SQLText
		FETCH NEXT FROM c_1 INTO @SubjectArea,@SQLText,@DataSource,@FactTable
	END
	
CLOSE c_1
DEALLOCATE c_1



GO
/****** Object:  StoredProcedure [dbo].[PackageMonitor]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[PackageMonitor]
(
	@PkgName varchar(100)
)
as

Select Pkgname,ExecStartDT,ExecStopDT,ExtractFilePhysicalLocation,ABRE.BRID,BR.ShortNameOfTest,ABRE.ExecutionDate 
from DQMF.[dbo].[AuditPkgExecution] AE with (nolock)
left outer join DQMF.[dbo].[AuditExtractFile] AEF  with (nolock) on AE.PkgExecKey = AEF.PkgExecKey
left outer join DQMF.[dbo].[AuditBizRuleExecution] ABRE  with (nolock) on AEF.ExtractFileKey = ABRE.ExtractFileKey
left outer join DQMF.dbo.DQMF_BizRule BR  with (nolock) on ABRE.BRID = BR.BRID
where AE.PkgExecKey = (Select top 1 PkgExecKey 
from [dbo].[AuditPkgExecution] AE
where PkgName = @PkgName
order by ExecStartDT desc)
order by ABRE.ExecutionDate desc

--exec dbo.PackageMonitor 'PopulateED_Visit'
GO
/****** Object:  StoredProcedure [dbo].[Populate_AuditDataCorrectionMapping]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--select * from dbo.MD_SubjectArea
--EXECUTE [DQMF].[dbo].[Populate_AuditDataCorrectionMapping] @SubjectAreaID = 90 ,@Debug = 2
--EXECUTE [DQMF].[dbo].[Populate_AuditDataCorrectionMapping] @Debug = 2
--SELECT * FROM [dbo].[AuditDataCorrectionWorking]
--SELECT * FROM dbo.AuditDataCorrectionMapping 

CREATE PROCEDURE [dbo].[Populate_AuditDataCorrectionMapping]
				@SubjectAreaID int = NULL,
				@Debug int = 0
AS

BEGIN

DECLARE @SQLStr varchar(max)
,@BRID int
,@DimTableName varchar(max)
,@DimIDFieldName  varchar(max)
,@DimCodeFieldName varchar(max)
,@DimDescFieldName varchar(max)
,@FactTableName  varchar(max)
,@FactTableCorrectionFieldName varchar(max)
,@IsFacilityIDApplied bit

IF @Debug = 0 
	SET NOCOUNT ON

---------------------------------------------------------------------------------------------
--Drop working table
SET @SQLStr =
	'IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[AuditDataCorrectionWorking]'') AND type in (N''U''))
	 DROP TABLE [dbo].[AuditDataCorrectionWorking]'
EXEC (@SQLStr)
---------------------------------------------------------------------------------------------
SELECT DISTINCT 
 m.SubjectAreaID
,b.BRID 
,b.SourceObjectPhysicalName DimTableName
,b.SourceAttributePhysicalName DimIDFieldName
,CASE WHEN b.SourceObjectPhysicalName = 'Dim.EDDx' THEN 'DiagnosisCode'
	  WHEN b.SourceObjectPhysicalName IN ('Dim.Doctor','Dim.vwDoctor') THEN 'DrCode'	
	  WHEN b.SourceObjectPhysicalName = 'Dim.Date' THEN 'DateID'
	  WHEN b.SourceObjectPhysicalName = 'Dim.Time' THEN 'Time24Hr' 
	  WHEN LEFT(lkup.DimensionLookupExpression,2) = 'D.' THEN RIGHT(lkup.DimensionLookupExpression,LEN(lkup.DimensionLookupExpression)-2)
      ELSE lkup.DimensionLookupExpression 
  END DimCodeFieldName
,MD.DatabaseName +'.'+MD.ObjectSchemaName +'.'+MD.ObjectPhysicalName FactTableName
,MD.AttributePhysicalName FactTableCorrectionFieldName
,m.IsFacilityIDApplied
INTO [dbo].[AuditDataCorrectionWorking]
FROM dbo.DQMF_DataCorrectionMapping m
INNER JOIN dbo.DQMF_BizRule b ON b.brid = m.brid
INNER JOIN dbo.DQMF_BizRuleLookupMapping lkup ON lkup.brid = b.brid AND lkup.IsSourcePreviousValue = 1
INNER JOIN dbo.vwMD_PhyscialName MD ON MD.ObjectAttributeID = b.FactTableObjectAttributeId
WHERE m.IsActive = 1
  AND m.ErrorReasonSkipMapping IS NULL
  AND (@SubjectAreaID IS NULL OR m.SubjectAreaID = @SubjectAreaID)
  AND b.GUID NOT IN ('8C237554-214A-4376-8685-147A2348C4AC', -- BRID: 111598 - Lookup ChiefComplaintId prior to NACRS version change
				     '69A7F940-75C3-44B9-AF38-C9BF85C25B1C')-- BRID: 112647 - Lookup ChiefComplaintId post NACRS version change
ORDER BY m.SubjectAreaID, b.BRID 

----------------------------------------------------------
IF @Debug > 0 RAISERROR('--Delete table dbo.AuditDataCorrectionMapping ----', 0, 1 ) WITH NOWAIT

IF @SubjectAreaID IS NULL 
	TRUNCATE TABLE dbo.AuditDataCorrectionMapping
ELSE 
	DELETE dbo.AuditDataCorrectionMapping WHERE SubjectAreaID = @SubjectAreaID
---------------------------------------------------------------------------------------------
--Drop Index
IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AuditDataCorrectionMapping]') AND NAME = 'IDX1_AuditDataCorrectionMapping')
	DROP INDEX [IDX1_AuditDataCorrectionMapping] ON [dbo].[AuditDataCorrectionMapping] WITH ( ONLINE = OFF )
----------------------------------------------------------------------------------------------
WHILE EXISTS (SELECT TOP 1 * FROM [dbo].[AuditDataCorrectionWorking])

BEGIN
	SET @DimDescFieldName = ''
	SELECT TOP 1 @BRID = b.BRID
				,@DimTableName = b.DimTableName
				,@DimIDFieldName = b.DimIDFieldName
				,@DimCodeFieldName = b.DimCodeFieldName
				,@DimDescFieldName = CASE WHEN @DimTableName LIKE '%(SELECT%' THEN ''
										  WHEN @DimTableName = 'Dim.EDDx' THEN 'Diagnosis'	
										  ELSE ISNULL((SELECT TOP 1 c.COLUMN_NAME
													   FROM DSDW.INFORMATION_SCHEMA.COLUMNS c 
													   WHERE c.TABLE_SCHEMA +'.'+ c.TABLE_NAME = b.DimTableName
														 AND (c.COLUMN_NAME LIKE '%Desc%' OR c.COLUMN_NAME LIKE '%Name%')),'')
										  END
				,@FactTableName = b.FactTableName
                ,@FactTableCorrectionFieldName = b.FactTableCorrectionFieldName
				,@IsFacilityIDApplied = b.IsFacilityIDApplied
	FROM [dbo].[AuditDataCorrectionWorking] b 
	
SELECT @SQLStr = 
'INSERT INTO dbo.AuditDataCorrectionMapping ' + CHAR(13)+
'SELECT m.SubjectAreaID,
 m.Brid, '+ CHAR(13)+
 ''''+@FactTableName +''''+ ' FactTableName,'+ CHAR(13)+
 ''''+@FactTableCorrectionFieldName +''''+ ' FactTableCorrectionFieldName,'+ CHAR(13)+
 CASE WHEN @IsFacilityIDApplied = 0 THEN 'NULL' ELSE 'm.FacilityID' END + ' FacilityID,'+  CHAR(13)+
 ' f.'+@FactTableCorrectionFieldName +' FactTableID,
 m.MapToID,
 COUNT(f.ETLAuditID) as Cases,'+ CHAR(13)+
 ''''+@DimTableName +''''+  ' DimTableName,'+ CHAR(13)+
 ''''+@DimCodeFieldName +''''+  ' DimCodeFieldName,'+ CHAR(13)+
 ''''+@DimDescFieldName +''''+  ' DimDescFieldName,'+ CHAR(13)+
 CASE WHEN @DimCodeFieldName LIKE '%(%' THEN @DimCodeFieldName ELSE ' d.'+@DimCodeFieldName END +' DimTableCode,'+ CHAR(13)+
 CASE WHEN @DimDescFieldName = '' THEN ' NULL' ELSE ' d.'+@DimDescFieldName END +' DimTableDesc,
 m.PreviousValue, 
 m.DataCorrectionMappingID
 FROM dbo.DQMF_DataCorrectionMapping m
 CROSS APPLY (SELECT DISTINCT ETLID
			  FROM dbo.ETLBizruleAuditFact a 
			  WHERE a.BRID = m.BRID 
				AND ISNULL(a.PreviousValue,''NULL-NULL'') = ISNULL(m.PreviousValue,''NULL-NULL'')) audit
 INNER JOIN ' + @FactTableName + ' f ON f.ETLAuditID = audit.ETLID
 INNER JOIN ' + REPLACE(REPLACE(REPLACE(REPLACE(@DimTableName,'Dim.','DSDW.Dim.'),'[Dim].','DSDW.Dim.'),'Map.','DSDW.Map.'),'[Map].','DSDW.Map.')+' d ON d.' + @DimIDFieldName + ' = f.'+@FactTableCorrectionFieldName + '
 WHERE m.brid = ' + CAST(@BRID as varchar(15)) +'
   AND m.IsActive = 1
   '+CASE WHEN @IsFacilityIDApplied = 0 THEN '' ELSE 'AND m.FacilityID = f.FacilityID' END +'
 GROUP BY m.SubjectAreaID
		 ,m.Brid
		 '+CASE WHEN @IsFacilityIDApplied = 0 THEN '' ELSE ',m.FacilityID' END +'
	     ,f.'+ @FactTableCorrectionFieldName +'
		 ,m.MapToID
         ,'+ CASE WHEN @DimCodeFieldName LIKE '%(%' THEN @DimCodeFieldName ELSE 'd.'+@DimCodeFieldName END + 
		   +CASE WHEN @DimDescFieldName = '' THEN '' ELSE CHAR(13)+'         ,d.'+@DimDescFieldName END +'
         ,m.PreviousValue
		 ,m.DataCorrectionMappingID'

	EXEC (@SQLStr)

	IF @Debug > 0 PRINT(@SQLStr)

	DELETE [dbo].[AuditDataCorrectionWorking] WHERE BRID = @BRID 

END

DROP TABLE [dbo].[AuditDataCorrectionWorking]
--------------------------------------------------------------------------------------------
IF (@SubjectAreaID IS NULL OR @SubjectAreaID = 0 OR @SubjectAreaID = 2)	
	BEGIN
		IF @Debug > 0 RAISERROR('--2 ChiefComplaint BR for PowerRiver----', 0, 1 ) WITH NOWAIT

		INSERT INTO dbo.AuditDataCorrectionMapping 
		SELECT m.SubjectAreaID,
		 m.Brid,
		 'DSDW.ED.CurrentVisitFact' FactTableName,
		 'ChiefComplaintID' FactTableCorrectionFieldName,
		 m.FacilityID,
		 f.ChiefComplaintID FactTableID,
		 m.MapToID,
		 COUNT(f.ETLAuditID) as Cases,
		 'Dim.ChiefComplaint' DimTableName,
		 'ChiefComplaintCode' DimCodeFieldName,
		 'ChiefComplaintDescription' DimDescFieldName,
		 d.ChiefComplaintCode DimTableCode,
		 d.ChiefComplaintDescription DimTableDesc,
		 m.PreviousValue, 
		 m.DataCorrectionMappingID
		 FROM dbo.DQMF_DataCorrectionMapping m
		 CROSS APPLY (SELECT DISTINCT a.ETLID
					  FROM dbo.ETLBizruleAuditFact a 
					  WHERE a.BRID = m.BRID 
						AND ISNULL(a.PreviousValue,'NULL-NULL') = ISNULL(m.PreviousValue,'NULL-NULL')) audit
		 INNER JOIN DSDW.ED.CurrentVisitFact f ON f.ETLAuditID = audit.ETLID
		 INNER JOIN DSDW.Dim.ChiefComplaint d ON d.ChiefComplaintID = f.ChiefComplaintID
		 WHERE m.IsActive = 1
		   AND m.brid IN (111598  -- Lookup ChiefComplaintId prior to NACRS version change
						 ,112647) -- Lookup ChiefComplaintId post NACRS version change
		 GROUP BY m.SubjectAreaID,
				  m.Brid,
				  m.FacilityID,
				  f.ChiefComplaintID,
				  m.MapToID,
				  d.ChiefComplaintCode,
				  d.ChiefComplaintDescription,
				  m.PreviousValue, 
				  m.DataCorrectionMappingID
	END
--------------------------------------------------------------------------------------------
IF (@SubjectAreaID IS NULL OR @SubjectAreaID = 0 OR @SubjectAreaID = 90)	
	BEGIN
		IF @Debug > 0 RAISERROR('--3 BR 9000 PostalCode ---', 0, 1 ) WITH NOWAIT

		INSERT INTO dbo.AuditDataCorrectionMapping 
		SELECT m.SubjectAreaID,
		 m.Brid,
		 'DSDW.Secure.CurrentPatientFact' FactTableName,
		 'PostalCodeID' FactTableCorrectionFieldName,
		 m.FacilityID,
		 f.PostalCodeID FactTableID,
		 m.MapToID,
		 COUNT(f.ETLAuditID) as Cases,
		 'Dim.PostalCode' DimTableName,
		 'PostalCode' DimCodeFieldName,
		 'PostalCode' DimDescFieldName,
		 d.PostalCode DimTableCode,
		 d.PostalCode DimTableDesc,
		 m.PreviousValue, 
		 m.DataCorrectionMappingID
		 FROM dbo.DQMF_DataCorrectionMapping m
		 CROSS APPLY (SELECT DISTINCT a.ETLID
					  FROM dbo.ETLBizruleAuditFact a WITH (NOLOCK)
					  WHERE a.BRID = m.BRID 
						AND ISNULL(a.PreviousValue,'NULL-NULL') = ISNULL(m.PreviousValue,'NULL-NULL')) audit
		 INNER JOIN DSDW.Secure.CurrentPatientFact f WITH (NOLOCK) ON f.ETLAuditID = audit.ETLID
		 INNER JOIN DSDW.Dim.PostalCode d ON d.PostalCodeID = f.PostalCodeID
		 WHERE m.IsActive = 1
		   AND m.BRID = 9000
		 GROUP BY m.SubjectAreaID,
				  m.Brid,
				  m.FacilityID,
				  f.PostalCodeID,
				  m.MapToID,
				  d.PostalCode,
				  m.PreviousValue, 
				  m.DataCorrectionMappingID
	END
---------------------------------------------------------------------------------------------
-- Create Index
 CREATE NONCLUSTERED INDEX [IDX1_AuditDataCorrectionMapping] ON [dbo].[AuditDataCorrectionMapping]
	(SubjectAreaID ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
----------------------------------------------------------
IF @Debug = 0 
SET NOCOUNT OFF 

END


GO
/****** Object:  StoredProcedure [dbo].[Populate_DQMF_DataCorrectionMapping]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--EXECUTE [DQMF].[dbo].[Populate_DQMF_DataCorrectionMapping] @Debug = 2
--SELECT * FROM dbo.DQMF_DataCorrectionMapping m WHERE m.Updatedby = 'Procedure: Populate_DQMF_DataCorrectionMapping'

CREATE PROCEDURE [dbo].[Populate_DQMF_DataCorrectionMapping] 
				@Debug int = 0
AS

BEGIN

DECLARE @SQLStr varchar(max), @BRID int, @LookupCodeFieldName varchar(max) 
	   ,@DimTableName varchar(max), @ReturnIDFieldName varchar(max)

IF @Debug = 0 
	SET NOCOUNT ON

SET @SQLStr = 'DISABLE TRIGGER [dbo].[TrDQMF_DataCorrectionMappingUpdate] ON [dbo].[DQMF_DataCorrectionMapping]'
	EXEC(@SQLStr)


IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DQMF_DataCorrectionMapping]') AND name = N'IDX1_DQMF_DataCorrectionMapping')
	BEGIN
		SET @SQLStr = 'DROP INDEX [IDX1_DQMF_DataCorrectionMapping] ON [dbo].[DQMF_DataCorrectionMapping]'
		EXEC(@SQLStr)
	END

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DQMF_DataCorrectionMapping]') AND name = N'IDX2_DQMF_DataCorrectionMapping')
	BEGIN
		SET @SQLStr = 'DROP INDEX [IDX2_DQMF_DataCorrectionMapping] ON [dbo].[DQMF_DataCorrectionMapping]'
		EXEC(@SQLStr)
	END

IF @Debug > 0 RAISERROR('--Create Index on IsActive to table: dbo.DQMF_DataCorrectionMapping----', 0, 1 ) WITH NOWAIT 
SET @SQLStr = 'CREATE NONCLUSTERED INDEX [IDX2_DQMF_DataCorrectionMapping] ON [dbo].[DQMF_DataCorrectionMapping]
				(	[IsActive] ASC
				)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
				'
EXEC(@SQLStr)

IF @Debug > 0 RAISERROR('--DELETE records from dbo.DQMF_DataCorrectionMapping----', 0, 1 ) WITH NOWAIT
DELETE m
FROM dbo.DQMF_DataCorrectionMapping m 
WHERE m.IsActive IS NULL 
  AND m.ErrorReasonSkipMapping IS NOT NULL

----------------------------------------------------
--Create temp table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('[dbo].[ETLBizruleAuditFact_DCM]') AND type in (N'U'))
	CREATE TABLE dbo.ETLBizruleAuditFact_DCM(
			[BRID] [int] NOT NULL,
			[PreviousValue] varchar(100) NOT NULL,

	CONSTRAINT [PK_ETLBizruleAuditFact_DCM] PRIMARY KEY CLUSTERED 
		(BRID ASC, [PreviousValue]ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
ELSE 
	TRUNCATE TABLE dbo.ETLBizruleAuditFact_DCM
----------------------------------------------------
INSERT INTO dbo.ETLBizruleAuditFact_DCM
SELECT DISTINCT a.brid, PreviousValue = ISNULL(a.PreviousValue,'NULL-NULL')
FROM dbo.ETLBizruleAuditFact a WITH (NOLOCK)
INNER JOIN dbo.DQMF_DataCorrectionMapping m ON a.BRID = m.BRID 

DELETE m
FROM dbo.DQMF_DataCorrectionMapping m 
LEFT JOIN dbo.ETLBizruleAuditFact_DCM a ON a.brid = m.brid AND a.PreviousValue = ISNULL(m.PreviousValue,'NULL-NULL')
WHERE a.brid IS NULL
  AND (m.IsActive IS NULL
   OR  m.SourceDecision LIKE '%automatically set IsActive = 1; IsCorrected = 1%')

DROP TABLE dbo.ETLBizruleAuditFact_DCM
   
-------------------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('--Update FactTableObjectAttributeId FROM dbo.DQMF_BizRule WHERE BRId = 9000)----', 0, 1 ) WITH NOWAIT
	DECLARE @PC_ObjectAttributeID int
	SELECT @PC_ObjectAttributeID = ObjectAttributeID 
	--, DatabaseName, ObjectSchemaName , ObjectPhysicalName, AttributePhysicalName
	FROM dbo.vwMD_PhyscialName 
	WHERE DatabaseName = 'DSDW'
	  AND ObjectSchemaName = 'Secure'
	  AND ObjectPhysicalName = 'CurrentPatientFact'
	  AND AttributePhysicalName = 'PostalCodeID'
	--SELECT @PC_ObjectAttributeID

	IF @PC_ObjectAttributeID > 0
	   AND (SELECT ISNULL(FactTableObjectAttributeId,0) FROM dbo.DQMF_BizRule WHERE BRId = 9000) <> @PC_ObjectAttributeID
		UPDATE b
			SET FactTableObjectAttributeId = @PC_ObjectAttributeID
		FROM dbo.DQMF_BizRule b
		WHERE b.BRId = 9000
-------------------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('--Add records from dbo.ETLBizruleAuditFact to dbo.DQMF_DataCorrectionMapping----', 0, 1 ) WITH NOWAIT
--TRUNCATE TABLE dbo.DQMF_DataCorrectionMapping
	
	;WITH Bizrule AS (SELECT MD.SubjectAreaID
						   ,b.BRId
						   ,CASE WHEN EXISTS(SELECT 1
											FROM dbo.MD_ObjectAttribute fac
											WHERE fac.AttributePhysicalName = 'FacilityID'
											  AND fac.ObjectID = MD.ObjectID
											  AND fac.IsActive = 1) THEN 1 ELSE 0 END IsFacilityIDApplied
						  ,ISNULL(MD.SubjectAreaStewardContact,'') ReferredTo
					 FROM dbo.DQMF_BizRule b
					 CROSS APPLY (SELECT vw.SubjectAreaID, vw.SubjectAreaStewardContact,vw.ObjectID
								  FROM dbo.vwMD_PhyscialName vw
								  WHERE vw.ObjectAttributeID = b.FactTableObjectAttributeId
									AND vw.DatabaseId = 2 -- DSDW only
									AND vw.ObjectType = 'Table'
									AND vw.ObjectSchemaName <> 'Dim') MD
					 WHERE (b.ActionID = 0 OR b.Brid = 9000)
					   AND b.FactTableObjectAttributeId > 0)


	INSERT INTO dbo.DQMF_DataCorrectionMapping
		(  SubjectAreaID
		  ,BRId
		  ,PreviousValue
		  ,IsFacilityIDApplied
		  ,MapToID
		  ,IsForDQ
		  ,IsFirstRun
		  ,SourceDecision
		  ,ReferredTo
		  ,IsEffectiveDateApplied
		  ,UpdatedBy
		  ,UpdatedDate
		  ,CreatedBy
		  ,CreatedDate)

	SELECT m.SubjectAreaID
		  ,m.BRId
		  ,m.PreviousValue
		  ,m.IsFacilityIDApplied
		  ,0 MapToID
		  ,1 IsForDQ
		  ,0 IsFirstRun
		  ,'' SourceDecision
		  ,m.ReferredTo
		  ,0 IsEffectiveDateApplied
		  ,suser_sname() UpdatedBy
		  ,getdate() UpdatedDate
		  ,suser_sname() CreatedBy
		  ,getdate() CreatedDate
	FROM (SELECT DISTINCT b.SubjectAreaID
						 ,b.BRId
						 ,a.PreviousValue
						 ,b.IsFacilityIDApplied
						 ,b.ReferredTo
			FROM Bizrule b
			INNER JOIN dbo.ETLBizruleAuditFact a WITH (NOLOCK) ON a.BRId = b.BRId
			WHERE NOT EXISTS (SELECT 1
	 						  FROM dbo.DQMF_DataCorrectionMapping dcm
							  WHERE dcm.BRID = a.BRID
								AND ISNULL(dcm.PreviousValue,'NULL-NULL') = ISNULL(a.PreviousValue,'NULL-NULL'))
			) m

---------------------------------------------------------------------------------------------
UPDATE m
	SET IsActive = 1
	   ,IsFirstRun = 0
	   ,IsForDQ = 1
	   ,FacilityID = 8 -- Power River
	   ,SourceDecision = 'Map to ID0 - All chief complaints will knowingly fail this rule because PR does not use the regional list.  They are being logged at the request of Peter Kaloupis.'
FROM dbo.DQMF_DataCorrectionMapping m
WHERE m.BRID IN (SELECT b.BRID
				 FROM dbo.DQMF_BizRule b
				 WHERE b.GUID IN ('8C237554-214A-4376-8685-147A2348C4AC', -- BRID: 111598 - Lookup ChiefComplaintId prior to NACRS version change
				 		 	      '69A7F940-75C3-44B9-AF38-C9BF85C25B1C')) -- BRID: 112647 - Lookup ChiefComplaintId post NACRS version change
  AND m.IsActive IS NULL

---------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('-- BRId 9000 - PostalCode Set MapToId = (125522 - OutofC, 125523 - OutofP)----' , 0, 1 ) WITH NOWAIT

	;WITH NonBCPostalCode as (SELECT DISTINCT a.BRId, a.PreviousValue, a.NewValue
							  FROM dbo.ETLBizruleAuditFact a WITH (NOLOCK) 
							  WHERE a.BRId = 9000
							    AND a.NewValue IN ('125522'  -- OutofC
												  ,'125523') -- OutofP
							  )	
	UPDATE m
		SET IsActive = 1
		   ,IsFirstRun = 0
		   ,IsForDQ = 0
		   ,MapToId = p.NewValue
		   ,SourceDecision = 'Map to PostalCodeID '+ CASE WHEN p.NewValue = '125522' THEN '125522 - OutofC' ELSE '125523 - OutofP' END
							+'– automatically set IsActive = 1; IsCorrected = 1.  Only manual data change can correct these issues'
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN NonBCPostalCode p ON p.BRId = m.BRID AND p.PreviousValue = m.PreviousValue
	WHERE m.BRID = 9000
      AND m.MapToId <> p.NewValue
---------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('--BRId 9000 - PostalCode Set MapToId = (125527 - UnkBC) ----' , 0, 1 ) WITH NOWAIT

	;WITH UnkBCPostalCode as (SELECT DISTINCT a.BRId, a.PreviousValue, a.NewValue
							  FROM dbo.ETLBizruleAuditFact a WITH (NOLOCK) 
							  WHERE a.BRId = 9000
							    AND a.NewValue = '125527' -- UnkBC
							  )	
	UPDATE m
		SET IsForDQ = 0
		   ,MapToId = p.NewValue
		   ,SourceDecision = 'Map to PostalCodeID 125527 - UnkBC default from dbo.ETLBizruleAuditFact.NewValue'
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN UnkBCPostalCode p ON p.BRId = m.BRID AND p.PreviousValue = m.PreviousValue
	WHERE m.IsActive IS NULL
	  AND m.BRID = 9000 -- Postal Code Lookup
	  AND m.MapToId = 0
      
---------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('--Update MapToID with sugestion valid BC PostalCodeID----', 0, 1 ) WITH NOWAIT
	UPDATE m
			SET  MapToID = d.PostalCodeID
				,SourceDecision = 'Map to ID' + CONVERT(varchar(20),d.PostalCodeId) + ' - PostalCode ' + d.PostalCode
				,IsFirstRun = 1
				,IsForDQ = CASE WHEN d.PostalCodeID > 0 THEN 0 ELSE 1 END
				,CreatedBy = 'Procedure: Populate_DQMF_DataCorrectionMapping'
				,UpdatedDate = getdate() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN DSDW.Dim.PostalCode d ON d.PostalCode = REPLACE(m.PreviousValue,' ','')
	WHERE m.IsActive IS NULL
	  AND m.BRID = 9000 -- Postal Code Lookup
	  AND m.MapToId NOT IN (125522,	--OutofC
							125523)	--OutofP
	  AND LEN(LTRIM(RTRIM(d.PostalCode))) = 6 
	  AND LEFT(d.PostalCode,1) = 'V'
	  AND (m.MapToID <> d.PostalCodeID OR SourceDecision <> 'Map to ID' + CONVERT(varchar(20),d.PostalCodeId) + ' - PostalCode ' + d.PostalCode)
---------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('--Populate table #BizRuleLookupMapping with Dim----', 0, 1 ) WITH NOWAIT

SELECT DISTINCT b.BRID, b.SourceObjectPhysicalName 
			   ,lkup.DimensionLookupExpression LookupCodeFieldName, b.SourceAttributePhysicalName ReturnIDFieldName
	INTO #BizRuleLookupMapping
FROM dbo.DQMF_DataCorrectionMapping m
INNER JOIN dbo.DQMF_BizRule b ON b.brid = m.brid
INNER JOIN dbo.DQMF_BizRuleLookupMapping lkup ON lkup.brid = b.brid AND lkup.IsSourcePreviousValue = 1
WHERE m.IsActive IS NULL
  AND RIGHT(RTRIM(b.SourceAttributePhysicalName),2) = 'ID'
  AND b.SourceObjectPhysicalName NOT IN ('Dim.Time','Dim.Date')
  AND LEFT(b.SourceObjectPhysicalName,1) <> '('
  AND ISNULL(m.PreviousValue,'') > ''
  AND lkup.DimensionLookupExpression <> lkup.SourceLookupExpression
  AND NOT EXISTS (SELECT * 
				  FROM dbo.DQMF_BizRuleLookupMapping lkup2 
				  WHERE lkup2.brid = b.BRID 
					AND lkup2.IsSourcePreviousValue = 0
					AND (LEFT(lkup2.DimensionLookupExpression,2) IN ('F.','S.')
					     OR lkup2.DimensionLookupExpression LIKE '%CONVERT%'
						 OR lkup2.DimensionLookupExpression LIKE '%CAST%'
						 OR lkup2.DimensionLookupExpression LIKE '%CASE%'
						 OR lkup2.SourceLookupExpression LIKE '%CONVERT%'
						 OR lkup2.SourceLookupExpression LIKE '%CAST%'
						 OR lkup2.SourceLookupExpression LIKE '%CASE%'
						 OR lkup2.SourceLookupExpression LIKE '%F.%'
						 OR lkup2.SourceLookupExpression LIKE '%S.%'))
  
----------------------------------------------------------
WHILE EXISTS (SELECT * FROM #BizRuleLookupMapping b)
BEGIN
	SELECT TOP 1 @BRID = b.BRID
				,@DimTableName = b.SourceObjectPhysicalName
				,@LookupCodeFieldName = b.LookupCodeFieldName
				,@ReturnIDFieldName = b.ReturnIDFieldName
	FROM #BizRuleLookupMapping b 
	
	SELECT @SQLStr = 
	'UPDATE m
		SET  MapToID = d.' + @ReturnIDFieldName +'
			,IsFirstRun = 1
			,IsForDQ = CASE WHEN d.' + @ReturnIDFieldName +' > 0 THEN 0 ELSE 1 END
			,CreatedBy = '+ ''''+  'Procedure: Populate_DQMF_DataCorrectionMapping' + ''''+'
			,UpdatedDate = getdate() 
	FROM dbo.DQMF_DataCorrectionMapping m
	INNER JOIN DSDW.' + @DimTableName + ' d ON ' + @LookupCodeFieldName + ' = m.PreviousValue
	WHERE m.IsActive IS NULL
	  AND m.MapToID <> d.' + @ReturnIDFieldName +'
	  AND m.brid = ' + CAST(@BRID as varchar(15))

	IF EXISTS (SELECT * FROM dbo.DQMF_BizRuleLookupMapping lkup WHERE lkup.brid = @BRID AND lkup.IsSourcePreviousValue = 0)

		SELECT @SQLStr = @SQLStr + CHAR(13) +
				+ '      AND ' 
				+ CASE WHEN lkup.DimensionLookupExpression = 'IsActive' THEN 'd.IsActive' ELSE lkup.DimensionLookupExpression END
				+ ' = ' + REPLACE(lkup.SourceLookupExpression,'Dim.','DSDW.Dim.')
		FROM dbo.DQMF_BizRuleLookupMapping lkup 
		WHERE lkup.brid = @BRID 
		  AND lkup.IsSourcePreviousValue = 0
	
	EXEC (@SQLStr)
	IF @Debug > 0 PRINT(@SQLStr)

	DELETE #BizRuleLookupMapping WHERE BRID = @BRID 

END

DROP TABLE #BizRuleLookupMapping
-------------------------------------------------------
IF @Debug > 0 RAISERROR('--Pull FacilityID from Fact tables----', 0, 1 ) WITH NOWAIT

SELECT DISTINCT c.BRID
,'SELECT DISTINCT a.BRID, a.PreviousValue, v.FacilityID
INTO #BizruleFacilityID
FROM dbo.ETLBizruleAuditFact a WITH (NOLOCK)
INNER JOIN ' + MD.UpdateTableName + ' v ON v.ETLAuditID = a.ETLID
WHERE v.FacilityID > 0
  AND a.BRID = ' +CAST(c.BRID as varchar(20)) as SQLStr
INTO #UpdateTable
FROM dbo.DQMF_DataCorrectionMapping c
INNER JOIN dbo.DQMF_BizRule b ON b.BRId = c.BRId
CROSS APPLY (SELECT vw.DatabaseName+'.'+vw.ObjectSchemaName+'.'+vw.ObjectPhysicalName UpdateTableName
			 FROM dbo.vwMD_PhyscialName vw
			 WHERE vw.ObjectAttributeID = b.FactTableObjectAttributeId
			   AND vw.AttributePhysicalName <> 'FacilityID'	
			   AND EXISTS (SELECT 1
						   FROM dbo.MD_ObjectAttribute fac 
						   WHERE fac.AttributePhysicalName = 'FacilityID'
                             AND fac.ObjectID =  vw.ObjectID)) MD
WHERE c.IsFacilityIDApplied = 1

WHILE EXISTS (SELECT BRID FROM #UpdateTable) 
BEGIN

		SELECT TOP 1
		 @BRID = t.BRID  
		,@SQLStr = t.SQLStr
		FROM #UpdateTable t
		
		SET @SQLStr = @SQLStr +CHAR(13) +'
		UPDATE c
			SET FacilityID = fac.FacilityID
			   ,ErrorReasonSkipMapping = NULL
			   ,SkipMappingStartDate = NULL
			   ,CreatedBy = ''Procedure: Populate_DQMF_DataCorrectionMapping'' 
			   ,UpdatedDate = getdate() 
		FROM dbo.DQMF_DataCorrectionMapping c 
		CROSS APPLY (SELECT TOP 1 f.FacilityID
					 FROM #BizruleFacilityID f 
					 WHERE f.BRID = c.BRID 
					   AND ISNULL(f.PreviousValue,''NULL-NULL'') = ISNULL(c.PreviousValue,''NULL-NULL'')
					 ORDER BY f.FacilityID DESC) fac
		WHERE c.FacilityID IS NULL 
				  
		INSERT INTO dbo.DQMF_DataCorrectionMapping
			(  SubjectAreaID
			  ,PreviousValue
			  ,BRId
			  ,IsFacilityIDApplied
			  ,FacilityID
			  ,MapToID
			  ,IsForDQ
			  ,IsFirstRun
			  ,SourceDecision
			  ,ReferredTo
			  ,IsEffectiveDateApplied
			  ,UpdatedBy
			  ,UpdatedDate
			  ,CreatedBy
			  ,CreatedDate)
		SELECT c.SubjectAreaID
			  ,c.PreviousValue
			  ,c.BRId
			  ,c.IsFacilityIDApplied
			  ,b.FacilityID
			  ,c.MapToID
			  ,c.IsForDQ
			  ,c.IsFirstRun
			  ,'''' SourceDecision
			  ,c.ReferredTo
			  ,0 IsEffectiveDateApplied
			  ,suser_sname() UpdatedBy
			  ,getdate() UpdatedDate
			  ,''Procedure: Populate_DQMF_DataCorrectionMapping'' CreatedBy
			  ,getdate() CreatedDate
		FROM #BizruleFacilityID b
		CROSS APPLY (SELECT TOP 1 m.*
					 FROM dbo.DQMF_DataCorrectionMapping m
					 WHERE m.BRID = b.BRId
					   AND ISNULL(m.PreviousValue,''NULL-NULL'') = ISNULL(b.PreviousValue,''NULL-NULL'')
					  ) c
		WHERE NOT EXISTS (SELECT *
						  FROM dbo.DQMF_DataCorrectionMapping x
						  WHERE x.BRID = b.BRId
							AND ISNULL(x.PreviousValue,''NULL-NULL'') = ISNULL(b.PreviousValue,''NULL-NULL'')
							AND x.FacilityID = b.FacilityID)

		DROP TABLE #BizruleFacilityID
		'

		EXEC (@SQLStr)

		DELETE #UpdateTable WHERE BRID = @BRID
END

DROP TABLE #UpdateTable

---------------------------------------------------------------------------------------------
IF @Debug > 0 RAISERROR('--Set IsActive = 1 to BR with SourceObjectPhysicalName in (Dim.Date,Dim.Time)----', 0, 1 ) WITH NOWAIT
	UPDATE m
		SET IsActive = 1
		   ,IsFirstRun = 0
		   ,IsForDQ = 1
		   ,SourceDecision = 'Map to ID0 – automatically set IsActive = 1; IsCorrected = 1.  Only manual data change can correct these issues'
	FROM dbo.DQMF_DataCorrectionMapping m
	WHERE m.BRID IN (SELECT b.BRID
					 FROM dbo.DQMF_BizRule b
					 WHERE b.SourceObjectPhysicalName IN ('Dim.Time','Dim.Date'))
	  AND m.IsActive IS NULL
----------------------------------------------------------------------------------------------

SET @SQLStr = 'ENABLE TRIGGER [dbo].[TrDQMF_DataCorrectionMappingUpdate] ON [dbo].[DQMF_DataCorrectionMapping]'
	EXEC(@SQLStr)

IF @Debug > 0 RAISERROR('--Create Index on BRID to table: dbo.DQMF_DataCorrectionMapping----', 0, 1 ) WITH NOWAIT
	SET @SQLStr = 'CREATE NONCLUSTERED INDEX [IDX1_DQMF_DataCorrectionMapping] ON [dbo].[DQMF_DataCorrectionMapping]
					(
						[BRID] ASC
					)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'
	EXEC(@SQLStr)
	

IF @Debug = 0 
SET NOCOUNT OFF

END


GO
/****** Object:  StoredProcedure [dbo].[Populate_ETLStagingRecordQualityRating]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--EXECUTE [DQMF].[dbo].[Populate_ETLStagingRecordQualityRating] @IsRefresh = 1
--SELECT * FROM dbo.ETLStagingRecordQualityRating  m

CREATE PROCEDURE [dbo].[Populate_ETLStagingRecordQualityRating] 
			    @IsRefresh int = 0
AS

IF @IsRefresh = 1
	BEGIN
	  TRUNCATE TABLE dbo.ETLStagingRecordQualityRating
	-- Drop Primary Key
	IF  EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ETLStagingRecordQualityRating]') AND name = N'Pk_ETLStagingRecordQualityRating')
		ALTER TABLE [dbo].[ETLStagingRecordQualityRating] DROP CONSTRAINT [Pk_ETLStagingRecordQualityRating]
   
		--Populate data
		INSERT [dbo].[ETLStagingRecordQualityRating]
			(ETLAuditId, QualityRatingId)
			SELECT DISTINCT 
				 a.ETLId
				,q.QualityRatingID 
			FROM dbo.AuditQulaityRatingBizRule q
			INNER JOIN dbo.ETLBizruleAuditFact a ON a.BRId = q.BRId


		--Add Primary Key
		ALTER TABLE [dbo].[ETLStagingRecordQualityRating] ADD  CONSTRAINT [Pk_ETLStagingRecordQualityRating] PRIMARY KEY CLUSTERED 
		(
			ETLAuditId, QualityRatingId
		)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 80) ON [PRIMARY]

	END
ELSE
	BEGIN
		INSERT [dbo].[ETLStagingRecordQualityRating]
			(ETLAuditId, QualityRatingId)
			SELECT DISTINCT 
				 a.ETLId
				,q.QualityRatingID 
			FROM dbo.AuditQulaityRatingBizRule q
			INNER JOIN dbo.ETLBizruleAuditFact a ON a.BRId = q.BRId
			WHERE NOT EXISTS (SELECT 1
							  FROM dbo.ETLStagingRecordQualityRating r
							  WHERE r.ETLAuditId = a.ETLId
								AND r.QualityRatingID = q.QualityRatingId)

	END
GO
/****** Object:  StoredProcedure [dbo].[PrintTextLine]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PrintTextLine] @strOut VARCHAR(MAX) , @Debug int = 0
AS
/*
declare @sql varchar(max)
set @sql =REPLICATE('ABC'+ char(13)+char(10), 1000) + 'Properly End?'+ char(13) + 'A'
EXEC [dbo].[PrintTextLine] @sql, 0
EXEC [dbo].[PrintTextLine] @sql, 1
*/
BEGIN
DECLARE @line_start_pos int, @line_break_pos int
DECLARE @str_to_print varchar(MAX)
DECLARE @msg varchar(max)
SET @line_break_pos = 0 
SET @line_start_pos = 0
SELECT @line_break_pos   = CHARINDEX(CHAR(10), @strOut)
DECLARE @i int
SET @i = 1
DECLARE @bExitNow int
--SELECT @line_break_pos
IF LEN (@strOut) < 4000
BEGIN
	IF @Debug <> 0 
		PRINT 'Debug: Using shortcut' 
	SET @bExitNow = -1
	PRINT @strOut
END
ELSE IF @line_break_pos = 0 
BEGIN
	SET @bExitNow = -1
	SELECT @str_to_print = SUBSTRING(@strOut, @line_start_pos, LEN(@strOut) + 1)
		
	PRINT @str_to_print 

END
ELSE 
BEGIN 
	SET @bExitNow = 0

WHILE @line_start_pos   < LEN(@strOut) AND @bExitNow = 0
BEGIN
	set @msg = 'Line ' + CAST(@i as varchar(20)) + ': Start at ' + cast(@line_start_pos as varchar(20))  + ' Break at ' + cast(@line_break_pos as varchar(20)) 
	IF @debug = 1
	RAISERROR (@msg  , 10, 12) with nowait

	IF @debug = 1
	BEGIN
		SET @msg = 'Prev character ascii is : ' + CAST(ASCII(SUBSTRING(@strout, @line_break_pos-1,1)) AS varchar(20))
		RAISERROR (@msg  , 10, 12) with nowait
	END

	-- If previous character is carriage return then skip it
	IF SUBSTRING(@strout, @line_break_pos-1,1) = CHAR(13)
		SELECT @str_to_print = SUBSTRING(@strOut, @line_start_pos, @line_break_pos - @line_start_pos - 1)
	ELSE
		SELECT @str_to_print = SUBSTRING(@strOut, @line_start_pos, @line_break_pos - @line_start_pos)

	SET @line_start_pos = @line_break_pos+1
	
	PRINT @str_to_print 
	
	SELECT @line_break_pos   = CHARINDEX(CHAR(10), @strOut, @line_start_pos +1)
	SET @i = @i+1

	IF @line_break_pos  = 0 
	BEGIN
		SET @bExitNow = -1
	END

END
--select @line_start_pos
IF @line_start_pos <= LEN(@strOut) AND @line_start_pos > 0
BEGIN
	SET @msg = 'Line ' + CAST(@i as varchar(20)) + ': Start at ' + cast(@line_start_pos as varchar(20))  + ' Break at ' + cast(@line_break_pos as varchar(20)) 

	IF @debug = 1
	RAISERROR (@msg  , 10, 12) with nowait

	SELECT @str_to_print = SUBSTRING(@strOut, @line_start_pos, LEN(@strOut))
		
	PRINT @str_to_print 
END
END
END

GO
/****** Object:  StoredProcedure [dbo].[SetAuditExtractFile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[SetAuditExtractFile]
            @pPkgExecKey bigint
           ,@pExtractFileKey bigint
           ,@pExtractFilePhysicalLocation varchar (250)
           ,@pIsProcessStart bit
           ,@pExtractFileCreatedDT smalldatetime
           ,@pIsProcessSuccess bit
           ,@pExtractFileKeyOut int output

AS
SET NOCOUNT ON;
IF @pIsProcessStart = 1
BEGIN
	INSERT INTO [DQMF].[dbo].[AuditExtractFile]
           ([PkgExecKey]
           ,[ExtractFilePhysicalLocation]
           ,[ExtractFileProcessStartDT]
           ,[ExtractFileProcessStopDT]
           ,[ExtractFileCreatedDT]
           ,[IsProcessSuccess])
     VALUES
           (@pPkgExecKey
           ,@pExtractFilePhysicalLocation
           ,GETDATE()
           ,null
           ,@pExtractFileCreatedDT
           ,0)

    SET @pExtractFileKeyOut = @@IDENTITY
END

IF @pIsProcessStart = 0
BEGIN
    UPDATE [DQMF].[dbo].[AuditExtractFile]
       SET ExtractFileProcessStopDT = GETDATE(),
           IsProcessSuccess = ISNULL(@pIsProcessSuccess,0)
     WHERE ExtractFileKey = @pExtractFileKey
END


SELECT @pExtractFileKeyOut ExtractFileKey


/*

[dbo].[SetAuditExtractFile]
            @pPkgExecKey  = 1
           ,@pExtractFileKey = null
           ,@pExtractFilePhysicalLocation = 'test'
           ,@pIsProcessStart  = 1
           ,@pExtractFileCreatedDT  = '1/1/2009'
           ,@pIsProcessSuccess  = 0
           ,@pExtractFileKeyOut = null


*/

GO
/****** Object:  StoredProcedure [dbo].[SetAuditPkgExecution]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[SetAuditPkgExecution]
            @pPkgExecKey bigint = null
           ,@pParentPkgExecKey bigint = null
           ,@pPkgName varchar(100)
           ,@pPkgVersionMajor smallint
           ,@pPkgVersionMinor smallint = 0
           ,@pIsProcessStart bit
           ,@pIsPackageSuccessful bit
           ,@pPkgExecKeyOut int output
AS
SET NOCOUNT ON;

IF @pIsProcessStart = 1
BEGIN

    IF NOT EXISTS( SELECT *
                FROM dbo.ETL_Package
                WHERE PkgName = @pPkgName )
    BEGIN
        RAISERROR( 'DQMF SetAuditPkgExecution: The package name "%s" does not exist in the DQMF ETL_Package table!', 16, 1, @pPkgName )
        PRINT '' -- sometimes needed due to ssis bug
        RETURN 1
    END

     INSERT INTO [DQMF].[dbo].[AuditPkgExecution]
           ([ParentPkgExecKey]
           ,[PkgName]
           ,[PkgKey]
           ,[PkgVersionMajor]
           ,[PkgVersionMinor]
           ,[ExecStartDT]
           ,[ExecStopDT]
           ,[IsPackageSuccessful])
     SELECT @pParentPkgExecKey
           ,@pPkgName
           ,PkgID
           ,@pPkgVersionMajor
           ,@pPkgVersionMinor
           ,GETDATE()
           ,null
           ,0
       FROM dbo.ETL_Package
      WHERE PkgName = @pPkgName

    SET @pPkgExecKeyOut = @@IDENTITY
END

IF @pIsProcessStart = 0
BEGIN

    UPDATE  dbo.AuditPkgExecution
       SET ExecStopDT = GETDATE()
           ,IsPackageSuccessful = @pIsPackageSuccessful
     WHERE PkgExecKey = @pPkgExecKey
END

SELECT @pPkgExecKeyOut PkgExecKey

/*
DEClaRE @pPkgExecKeyout  bigint

exec [SetAuditPkgExecution]
            @pPkgExecKey = null
           ,@pParentPkgExecKey = null
           ,@pPkgName = 'EmergencyPCIST1Parent'
           ,@pPkgVersionMajor = 1
           ,@pPkgVersionMinor  = 1
           ,@pIsProcessStart  = 1
           ,@pIsPackageSuccessful  = 0
           ,@pPkgExecKeyout  = @pPkgExecKeyout   output

SELECT @pPkgExecKeyout


*/


GO
/****** Object:  StoredProcedure [dbo].[SetBizRule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		grants
-- Create date: <Create Date,,>
-- Description:	Inserts or Updates a Biz rule record
--
-- Changes:
--        Add new column: [FactTableObjectAttributeId] by DR2383 - DQMF Auto data fix mappings 
-- Lien:  Change Update to check for at least 1 change in column to update. DR2708 - Store Procedure DQMF.dbo.SetBizRule
-- Lien:  Increase column RuleDesc to varchar(300) -- DR2704 - NACRS - Fiscal 2014-15 Changes
-- DG:    remove analyst controlled fields from update
-- =============================================
CREATE PROCEDURE [dbo].[SetBizRule]
                 @pBRId int,
                 @pShortNameOfTest varchar(100),
                 @pRuleDesc varchar(300),
                 @pConditionSQL varchar(max),
                 @pActionID int,
                 @pActionSQL varchar(max),
                 @pOlsonTypeID int,
                 @pSeverityTypeID int,
                 @pSequence int,
                 @pDefaultValue varchar(max),
                 @pDatabaseId int,
                 @pSourceObjectPhysicalName varchar(100),
                 @pTargetObjectPhysicalName varchar(100),
                 @pSourceAttributePhysicalName varchar(100),
                 @pTargetAttributePhysicalName varchar(100),
                 @pIsActive bit,
                 @pComment varchar(1000),
                 @pCreatedBy varchar(50),
                 @pUpdatedBy varchar(50),
                 @pIsLogged bit = 1,
                 @pGUID varchar(200),
				 @pFactTableObjectAttributeId int = 0,
				 @pBusinessKeyExpression varchar(500) = null
AS  
BEGIN

	SET NOCOUNT ON;

    IF EXISTS (SELECT BRId FROM dbo.DQMF_BizRule WHERE @pGUID = GUID)
    BEGIN
            UPDATE dbo.DQMF_BizRule
               SET ConditionSQL = @pConditionSQL,
                   ActionID = @pActionID,
                   ActionSQL = @pActionSQL,
                   OlsonTypeID = @pOlsonTypeID,
                   SeverityTypeID = @pSeverityTypeID,
                   Sequence = @pSequence,
                   DefaultValue = @pDefaultValue,
                   DatabaseId = @pDatabaseId,
                   SourceObjectPhysicalName = @pSourceObjectPhysicalName,
                   TargetObjectPhysicalName = @pTargetObjectPhysicalName,
                   SourceAttributePhysicalName = @pSourceAttributePhysicalName,
                   TargetObjectAttributePhysicalName = @pTargetAttributePhysicalName,
				   BusinessKeyExpression = @pBusinessKeyExpression,
                   UpdatedBy = @pUpdatedBy,
                   UpdatedDT = GETDATE(),
                   IsActive = @pIsActive
                   --Comment = @pComment,
                   --IsLogged = @pIsLogged,
				   --FactTableObjectAttributeId = @pFactTableObjectAttributeId
				   --ShortNameOfTest = @pShortNameOfTest,
                   --RuleDesc = @pRuleDesc,
             WHERE @pGUID = GUID
			 AND (
               ISNULL(ConditionSQL,'NULL-NULL') <> ISNULL(@pConditionSQL,'NULL-NULL')
               OR ISNULL(ActionID,9) <> ISNULL(@pActionID,9)
               OR ISNULL(ActionSQL,'NULL-NULL') <> ISNULL(@pActionSQL,'NULL-NULL')
               OR ISNULL(OlsonTypeID,9) <> ISNULL(@pOlsonTypeID,9)
               OR ISNULL(SeverityTypeID,9) <> ISNULL(@pSeverityTypeID,9)
               OR ISNULL(Sequence,9999999) <> ISNULL(@pSequence,9999999)
               OR ISNULL(DefaultValue,'NULL-NULL') <> ISNULL(@pDefaultValue,'NULL-NULL')
               OR ISNULL(DatabaseId,9999999) <> ISNULL(@pDatabaseId,9999999)
               OR ISNULL(SourceObjectPhysicalName,'NULL-NULL') <> ISNULL(@pSourceObjectPhysicalName,'NULL-NULL')
               OR ISNULL(TargetObjectPhysicalName,'NULL-NULL') <> ISNULL(@pTargetObjectPhysicalName,'NULL-NULL')
               OR ISNULL(SourceAttributePhysicalName,'NULL-NULL') <> ISNULL(@pSourceAttributePhysicalName,'NULL-NULL')
               OR ISNULL(TargetObjectAttributePhysicalName,'NULL-NULL') <> ISNULL(@pTargetAttributePhysicalName,'NULL-NULL')
               OR ISNULL(BusinessKeyExpression,'NULL-NULL') <> ISNULL(@pBusinessKeyExpression,'NULL-NULL')
               OR ISNULL(IsActive,9) <> ISNULL(@pIsActive,9)
			   --OR ISNULL(ShortNameOfTest,'NULL-NULL') <> ISNULL(@pShortNameOfTest,'NULL-NULL')
               --OR ISNULL(RuleDesc,'NULL-NULL') <> ISNULL(@pRuleDesc,'NULL-NULL')
               --OR ISNULL(Comment,'NULL-NULL') <> ISNULL(@pComment,'NULL-NULL')
               --OR ISNULL(UpdatedBy,'NULL-NULL') <> ISNULL(@pUpdatedBy,'NULL-NULL')
               --OR ISNULL(IsLogged,9) <> ISNULL(@pIsLogged,9)
               --OR ISNULL(FactTableObjectAttributeId,9999999) <> ISNULL(@pFactTableObjectAttributeId,9999999)
			   )

   END 
   ELSE
   BEGIN

           INSERT dbo.DQMF_BizRule (BRId ,
                                    ShortNameOfTest ,
                                    RuleDesc,
                                    ConditionSQL ,
                                    ActionID ,
                                    ActionSQL ,
                                    OlsonTypeID ,
                                    SeverityTypeID ,
                                    Sequence ,
                                    DefaultValue,
                                    DatabaseId ,
                                    SourceObjectPhysicalName ,
                                    TargetObjectPhysicalName ,
                                    SourceAttributePhysicalName ,
                                    TargetObjectAttributePhysicalName,
                                    IsActive ,
                                    Comment,
                                    CreatedBy ,
                                    CreatedDT,
                                    UpdatedBy,
                                    UpdatedDT,
                                    IsLogged,
									FactTableObjectAttributeId,
									BusinessKeyExpression,
                                    GUID  )

							   SELECT  MAX(BRID) + 1  ,
									 @pShortNameOfTest ,
                                     @pRuleDesc,
									 @pConditionSQL ,
									 @pActionID ,
									 @pActionSQL ,
									 @pOlsonTypeID ,
									 @pSeverityTypeID ,
									 @pSequence ,
									 @pDefaultValue ,
									 @pDatabaseId ,
									 @pSourceObjectPhysicalName ,
									 @pTargetObjectPhysicalName ,
									 @pSourceAttributePhysicalName ,
									 @pTargetAttributePhysicalName ,
									 @pIsActive ,
                                     @pComment,
									 @pCreatedBy ,
									 GETDATE(),
									 @pUpdatedBy,
									 GETDATE(),
                                     @pIsLogged, 
									 @pFactTableObjectAttributeId,
									 @pBusinessKeyExpression,
                                     ISNull(@pGUID,NEWID())
                              FROM dbo.DQMF_BizRule

    END


END


GO
/****** Object:  StoredProcedure [dbo].[SetBRAuditRowCount]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SetBRAuditRowCount]  
as 
--get all the BRIDs and previous values of all the fact tables:
select * 
	into  #DSDWFactTableNames 
	from 
		 DQMF.dbo.MD_Object
		join --only return tables that have the ETLAuditID column name)
			(select * from DSDW.information_schema.columns where column_name = 'ETLAuditID') InformationSchema
			on InformationSchema.table_name = ObjectPhysicalName
			and InformationSchema.table_schema=ObjectSchemaName
where 
		ObjectPurpose = 'Fact'
		and databaseid = (select databaseid from MD_Database where databaseName ='DSDW')

	--for each fact table fill out the AuditResult.BRAuditRowCount table
	while exists (select top 1 * from #DSDWFactTableNames)
		begin

			declare @sql varchar(max)		
			declare @TableName varchar(100)
			declare @schemaName varchar(100)
				
				select top 1 
					@TableName = ObjectPhysicalName 
					,@schemaName = ObjectSchemaName
				from #DSDWFactTableNames
				

		set @sql = '
	insert into AuditResult.BRAuditRowCount
	SELECT 
		'''+@schemaName+'.'+@TableName+''' TargetObjectPhysicalName
		, BRA.BRID
		, BR.ShortNameOfTest
		, count(1) PreviousAndNewValueCount
		, PreviousValue
		, NewValue
       FROM 
			DSDW.'+@schemaName+'.'+@TableName+' fact  with (nolock) 
	   INNER JOIN 
			dbo.ETLBizRuleAuditFact BRA  with (nolock) 
       ON fact.ETLAuditID = BRA.ETLID				
	   INNER JOIN 
			dbo.DQMF_BizRule BR   with (nolock) 
			ON BR.BRID = BRA.BRID
        WHERE 
			isCorrected is null or isCorrected = 0 
        GROUP BY 
			PreviousValue
			, BRA.BRID
			, BR.ShortNameOfTest 
			, NewValue
		ORDER BY BRA.BRID
'
		--print @sql	
			execute(@sql)
			
				delete from #DSDWFactTableNames 
					where @TableName = ObjectPhysicalName 
					and  ObjectSchemaName = @schemaName
		end 

		drop table #DSDWFactTableNames

GO
/****** Object:  StoredProcedure [dbo].[SetDataCorrection]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SetDataCorrection] @pTempTableName varchar(100),
										  @pSubjectAreaID int,
										  @pBRID int,
										  @pMinETLID bigint,
									  	  @Debug int = 0
AS

DECLARE @SQLStr varchar(max)
	   ,@MsgStr varchar(max)
	   ,@UpdateTableName varchar(100)
	   ,@UpdateFieldName varchar(100)
	   ,@KeyDateFieldName varchar(100)
	   ,@LineFeed varchar(10)
--------------------------------------------------
BEGIN
	
		SELECT TOP 1
			   @UpdateTableName = UpdateTableName
			  ,@UpdateFieldName = UpdateFieldName
		FROM dbo.DQMF_DataCorrectionWorking w 
		WHERE w.SubjectAreaID = @pSubjectAreaID
		  AND w.BRID = @pBRID

		SELECT TOP 1 @KeyDateFieldName = kday.AttributePhysicalName
		FROM dbo.DQMF_DataCorrectionWorking w
		CROSS APPLY (SELECT kfield.AttributePhysicalName
				     FROM [dbo].[vwMD_PhyscialName] k
				     INNER JOIN [dbo].[MD_ObjectAttribute] kfield ON kfield.ObjectAttributeID = k.KeyDateObjectAttributeID
				     WHERE k.ObjectID = w.ObjectID) kday
		WHERE w.SubjectAreaID = @pSubjectAreaID
		  AND w.BRID = @pBRID
		  AND w.IsEffectiveDateApplied = 1
		
		----------------------------------------------------------------------------------------------------
		IF @Debug > 0
			BEGIN
				SET @LineFeed = CHAR(13)
				SET @MsgStr = @LineFeed +@LineFeed 
							 + 'BR'+ CAST(@pBRID as varchar(20))
							 + ' Fact Table: ' + @UpdateTableName 
							 + ' Column: ' + @UpdateFieldName 
							 + ' ----------------------------------------------------------------------'
				RAISERROR(@MsgStr, 0, 1 ) WITH NOWAIT
			END
		-----------------------------------------------------------
		IF @Debug > 0 RAISERROR('1.Populate table: @pTempTableName', 0, 1 ) WITH NOWAIT
			BEGIN
			    SET @SQLStr =  'TRUNCATE TABLE ' + @pTempTableName 
				EXEC(@SQLStr)

				SET @SQLStr = '
				INSERT INTO ' + @pTempTableName + '
				SELECT DISTINCT r.ETLId, w.MapToID, w.IsForDQ, 
								w.IsFacilityIDApplied, w.FacilityID,
								w.IsEffectiveDateApplied, w.EffectiveStartDateID, w.EffectiveEndDateID
				FROM dbo.DQMF_DataCorrectionWorking w
				CROSS APPLY (SELECT a.ETLId
							 FROM dbo.ETLBizruleAuditFact a WITH (NOLOCK) 
							 WHERE a.BRID = w.BRID
							   '
                 IF @pMinETLID > 0 
					SET @SQLStr = @SQLStr + 'AND a.ETLId >= ' + CAST(@pMinETLID as varchar(20))

				SET @SQLStr = @SQLStr +
							   '
							   AND (a.PreviousValue = w.PreviousValue OR (a.PreviousValue IS NULL AND w.PreviousValue IS NULL))
							   AND (w.IsFirstRun = 1 OR a.IsCorrected IS NULL OR a.IsCorrected <> 1)) r 
				WHERE w.SubjectAreaID = ' + CAST(@pSubjectAreaID as varchar(20))+'
				  AND w.BRID = ' + CAST(@pBRID as varchar(20))+'
				  '
				IF @Debug > 0 RAISERROR(@SQLStr, 0, 1 ) WITH NOWAIT
				EXEC(@SQLStr)	
			END
		--------------------------------
		IF @Debug > 0 RAISERROR('2.Delete records from table: @pTempTableName which do not meet criteria in Fact table)', 0, 1 ) WITH NOWAIT
			BEGIN	
				SET @SQLStr = ''

				--IsFacilityIDApplied = 0 AND IsEffectiveDateApplied = 0
				IF EXISTS (SELECT TOP 1 w.BRID FROM dbo.DQMF_DataCorrectionWorking w WHERE w.SubjectAreaID = @pSubjectAreaID AND w.BRID = @pBRID AND w.IsFacilityIDApplied = 0 AND w.IsEffectiveDateApplied = 0)
					SET @SQLStr = @SQLStr +'
						DELETE w
						FROM ' + @pTempTableName + ' w
						WHERE w.IsFacilityIDApplied = 0 
						  AND w.IsEffectiveDateApplied = 0 
						  AND NOT EXISTS (SELECT *
										  FROM ' + @UpdateTableName + ' f 
										  WHERE f.ETLAuditID = w.ETLID)
						'
				--IsFacilityIDApplied = 1 AND IsEffectiveDateApplied = 0
				IF EXISTS (SELECT TOP 1 w.BRID FROM dbo.DQMF_DataCorrectionWorking w WHERE w.SubjectAreaID = @pSubjectAreaID AND w.BRID = @pBRID AND w.IsFacilityIDApplied = 1 AND w.IsEffectiveDateApplied = 0)
					SET @SQLStr = @SQLStr +'
						DELETE w
						FROM ' + @pTempTableName + ' w
						WHERE w.IsFacilityIDApplied = 1 
						  AND w.IsEffectiveDateApplied = 0 
						  AND NOT EXISTS (SELECT *
										  FROM ' + @UpdateTableName + ' f 
										  WHERE f.ETLAuditID = w.ETLID
											AND f.FacilityID = w.FacilityID)
						'
				--IsFacilityIDApplied = 1 AND IsEffectiveDateApplied = 1
				IF EXISTS (SELECT TOP 1 w.BRID FROM dbo.DQMF_DataCorrectionWorking w WHERE w.SubjectAreaID = @pSubjectAreaID AND w.BRID = @pBRID AND w.IsFacilityIDApplied = 1 AND w.IsEffectiveDateApplied = 1)
					SET @SQLStr = @SQLStr +'
						DELETE w
						FROM ' + @pTempTableName + ' w
						WHERE w.IsFacilityIDApplied = 1 
						  AND w.IsEffectiveDateApplied = 1 
						  AND NOT EXISTS (SELECT *
										  FROM ' + @UpdateTableName + ' f 
										  WHERE f.ETLAuditID = w.ETLID
											AND f.FacilityID = w.FacilityID
											AND f.'+@KeyDateFieldName + ' BETWEEN w.EffectiveStartDateID AND w.EffectiveEndDateID)
						'
				--IsFacilityIDApplied = 0 AND IsEffectiveDateApplied = 1
				IF EXISTS (SELECT TOP 1 w.BRID FROM dbo.DQMF_DataCorrectionWorking w WHERE w.SubjectAreaID = @pSubjectAreaID AND w.BRID = @pBRID AND w.IsFacilityIDApplied = 0 AND w.IsEffectiveDateApplied = 1)
					SET @SQLStr = @SQLStr +'
					DELETE w
					FROM ' + @pTempTableName + ' w
					WHERE w.IsFacilityIDApplied = 0 
					  AND w.IsEffectiveDateApplied = 1 
					  AND NOT EXISTS (SELECT *
									  FROM ' + @UpdateTableName + ' f 
									  WHERE f.ETLAuditID = w.ETLID
										AND f.'+@KeyDateFieldName + ' BETWEEN w.EffectiveStartDateID AND w.EffectiveEndDateID)
					'
				IF @Debug > 0 RAISERROR(@SQLStr, 0, 1 ) WITH NOWAIT 
				EXEC(@SQLStr)						  
			END
		--------------------------------
		IF @Debug > 0 RAISERROR('3.Update Fact table -----------------------------------------', 0, 1 ) WITH NOWAIT
			BEGIN	
				SET @SQLStr ='	UPDATE f' + CHAR(13)+
							    '		SET ' + @UpdateFieldName + ' = CONVERT(VARCHAR(15),c.MapToID) '+ CHAR(13)+
							    '	FROM ' + @UpdateTableName + ' f ' + CHAR(13)+
								'	INNER JOIN ' + @pTempTableName + ' c ON f.ETLAuditID = c.ETLID '+ CHAR(13)+
								'	WHERE f.'+@UpdateFieldName + ' <> + CONVERT(VARCHAR(15),c.MapToID)'+ CHAR(13)+
								'	   OR f.'+@UpdateFieldName + ' IS NULL '

				IF @Debug > 0 RAISERROR(@SQLStr, 0, 1 ) WITH NOWAIT
				EXEC(@SQLStr)
			END
		
		--------------------------------
		IF @Debug > 0 RAISERROR('4.dbo.ETLBizruleAuditFact SET IsForDQ AND IsCorrected value', 0, 1 ) WITH NOWAIT
			BEGIN
				SET @SQLStr ='
				UPDATE a
				SET IsForDQ = c.IsForDQ,
					IsCorrected = 1
				FROM dbo.ETLBizruleAuditFact a 
				INNER JOIN ' + @pTempTableName + ' c ON c.ETLId = a.ETLId 
				WHERE a.BRID = ' + CAST(@pBRID as varchar(20))+'
				  AND ((a.IsForDQ IS NULL OR a.IsForDQ <> c.IsForDQ)
				   OR  (a.IsCorrected IS NULL OR a.IsCorrected <> 1))
				'
				IF @Debug > 0 RAISERROR(@SQLStr, 0, 1 ) WITH NOWAIT
				EXEC(@SQLStr)
            END
		
		--------------------------------
		-- SET IsFirstRun = 0
		IF @Debug > 0 RAISERROR('5.UPDATE dbo.DQMF_DataCorrectionMapping SET @pIsFirstRun = 0', 0, 1 ) WITH NOWAIT
			IF EXISTS (SELECT IsFirstRun FROM dbo.DQMF_DataCorrectionWorking w WHERE w.SubjectAreaID = @pSubjectAreaID AND w.BRID = @pBRID AND w.IsFirstRun = 1)
				BEGIN
					UPDATE m
						SET IsFirstRun = 0
					FROM dbo.DQMF_DataCorrectionMapping m 
					CROSS APPLY (SELECT w.DataCorrectionMappingID 
								 FROM dbo.DQMF_DataCorrectionWorking w 
								 WHERE m.DataCorrectionMappingID = w.DataCorrectionMappingID 
								  AND w.SubjectAreaID = @pSubjectAreaID 
								  AND w.BRID = @pBRID 
								  AND w.IsFirstRun = 1) t
					WHERE m.BRID = @pBRID
					  AND m.IsFirstRun = 1
				END
		--------------------------------
		IF @Debug > 0 RAISERROR('6.DELETE FROM dbo.DQMF_DataCorrectionWorking', 0, 1 ) WITH NOWAIT
			BEGIN
				DELETE w 
				FROM dbo.DQMF_DataCorrectionWorking w 
				WHERE w.SubjectAreaID = @pSubjectAreaID 
					AND w.BRID = @pBRID
			END
		

	  --IF @Debug > 0 RAISERROR('---------------------PROCEDURE [dbo].[SetDataCorrection] END-----------------', 0, 1 ) WITH NOWAIT

	
END
GO
/****** Object:  StoredProcedure [dbo].[SetDimIDFKValue]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Grant Stephens
-- Create date: <Create Date,,>
-- Description:	Updates fact table records with a new value for a dimID based on BizRuleAuditFact rows

--Alan --  Update routine to allow column name to be passed in to allow the client 
--         to work where the ‘TargetObjectAttributePhysicalName’ is different for 
--         between the Staging and fact tables -- Jul 23 2012
--Alan --  DR2334 - Update routine to track sql executed by the client
       --  Add check to see if previous value is null and allow routine to handle it.
--Jeff -- Adding execute AS to allow users to update Fact tables
-- =============================================
CREATE PROCEDURE [dbo].[SetDimIDFKValue] 
	 @pBizRuleName varchar(100)
    ,@pStageName varchar(100) = null
    ,@pFactTableName varchar(100)
    ,@pFactColumnName varchar(100) = ''
    ,@pDimID int
    ,@pPreviousValue varchar(100)
    ,@pLocationID varchar(10)
    ,@pIsForDQ bit = 0
	,@pUsername varchar(100) =  null

 AS
BEGIN

	SET NOCOUNT ON;
DECLARE @SQLStr  varchar(4000)
        ,@FactField varchar(100)
        ,@DateField varchar(100)
        ,@LocationField varchar(100)
        ,@BRID int
        ,@PreviousValueIsNull varchar(100)

if @pPreviousValue is null
	set @PreviousValueIsNull = 'PreviousValue = null'
else
    set @PreviousValueIsNull = 'PreviousValue = ''' + @pPreviousValue + ''''

SELECT @FactField = BR.TargetObjectAttributePhysicalName, @BRID = BRID FROM  
       dbo.DQMF_BizRule   BR
     WHERE convert(varchar(10),BR.BRID) + ' - ' + ShortNameOfTest  = @pBizRuleName

if isnull(@pFactColumnName,'') <> ''
	set @FactField = @pFactColumnName

SELECT @LocationField = case @pFactTableName
                        WHEN 'ADR.FactAcuteAbstract' THEN 'ProviderID'
                        ELSE 'FACILITYID' END
IF @pLocationID = 0
BEGIN
SET @LocationField = ''
END ELSE
BEGIN
SET @LocationField = 'AND FACT.' + @LocationField + ' = ' + convert(varchar(10),@pLocationID) 
END

IF @FactField = 'PostalCodeID'
BEGIN
 
  SELECT @DateField = case @pFactTableName
                      WHEN 'ED.VisitFAct' THEN 'RegistrationDateID'
                      WHEN 'ADTC.AdmissionFact' THEN 'AdmissionDateID'
                      WHEN 'ADTC.CensusFact'  THEN 'CensusDateID'
                      WHEN 'Adtc.DischargeFact' THEN 'DischargeDateID'
                      WHEN 'Adtc.TransferFact' THEN 'TransferDateID'
                      WHEN 'ADR.AbstractAcuteFact' THEN 'DischargeDateID'
                      ELSE 'Unknown' END

SET  @SQLStr = 'UPDATE DSDW.DIM.PATIENT SET ' + @FactField + ' = ' + convert(varchar(10),@pDimID) + '  FROM  
     dbo.ETLBizRuleAuditFact BRAF  
       INNER JOIN DSDW.' + @pFactTableName + ' FACT  
                 ON FACT.ETLAuditID = BRAF.ETLID 
       INNER JOIN DSDW.DIM.PATIENT PAT 
                 ON PAT.PATIENTID = FACT.PATIENTID 
  WHERE  BRID = ' + convert(varchar(10),@BRID) + ' 
      AND PAT.SOURCECREATEDDATE = (SELECT MAX(SOURCECREATEDDATE) FROM DSDW.DIM.PATIENT 
                                  WHERE fact.patientID = patientID and SOURCECREATEDDATE <=  FACT.' + @DateField +')                                                                 
       AND ' + @PreviousValueIsNull

END ELSE
BEGIN
SET  @SQLStr =   'UPDATE DSDW.' + @pFactTableName + ' SET ' + @FactField + ' = ' + convert(varchar(10),@pDimID) + '  FROM  
        dbo.ETLBizRuleAuditFact BRAF
       INNER JOIN DSDW.' + @pFactTableName + ' FACT  ON FACT.ETLAuditID = BRAF.ETLID 
  WHERE  BRID = ' + convert(varchar(10),@BRID) + ' ' + @LocationField + '  AND ' + @PreviousValueIsNull
END
BEGIN TRY
	BEGIN TRAN

	insert into dbo.ETLBizRuleAuditFactUpdateLog
	(Username,UpdateDate,SQLTextExecuted)
	values (@pUsername,getdate(),@SQLStr)

	exec  (@SQLStr)

	SET  @SQLStr = 'UPDATE dbo.ETLBizRuleAuditFact
	SET ISCorrected = 1
		,ISForDQ = ' + convert(varchar(1),@pISForDQ) + '
	FROM   dbo.ETLBizRuleAuditFact BRAF
			INNER JOIN DSDW.' + @pFactTableName + ' FACT  ON FACT.ETLAuditID = BRAF.ETLID
	  WHERE  BRID = ' + convert(varchar(10),@BRID) + ' ' + @LocationField +  '
		  AND ' + @PreviousValueIsNull

	--Track sql Executed by Client on fact table
	insert into dbo.ETLBizRuleAuditFactUpdateLog
	(Username,UpdateDate,SQLTextExecuted)
	values (@pUsername,getdate(),@SQLStr)

	EXEC (@SQLStr)
    COMMIT TRAN
END TRY

BEGIN CATCH

  ROLLBACK TRAN
  DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int
  SELECT @ErrMsg = ERROR_MESSAGE(),
         @ErrSeverity = ERROR_SEVERITY()
  RAISERROR(@ErrMsg, @ErrSeverity, 1)

END CATCH

END





GO
/****** Object:  StoredProcedure [dbo].[SetDQMFBizRuleLookupMapping]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		GrantS
-- Create date: 5-20-2010
-- Description:	Insert or Delete to the DQMF_BizRuleLookupMapping table
-- =============================================
CREATE PROCEDURE [dbo].[SetDQMFBizRuleLookupMapping] 
	 @pGUID varchar(200), 
	 @pJoinNumber int,
     @pSourceLookupExpression varchar(1000),
     @pDimensionLookupExpression varchar(1000),
     @pIsSourcePreviousValue bit
AS
BEGIN

If  Exists (SELECT br.BRID FROM DQMF_BizRuleLookupMapping brm INNER JOIN DQMF_BizRule br on brm.brid = br.brid WHERE GUID = @pGUID AND JoinNumber = @pJoinNumber)
BEGIN
	UPDATE [DQMF].[dbo].[DQMF_BizRuleLookupMapping]
	SET [BRId] = br.BRID
      ,[JoinNumber] = @pJoinNumber
      ,[SourceLookupExpression] = @pSourceLookupExpression
      ,[DimensionLookupExpression] = @pDimensionLookupExpression
      ,IsSourcePreviousValue = isnull(@pIsSourcePreviousValue,0)
    FROM DQMF_BizRuleLookupMapping brm INNER JOIN DQMF_BizRule br on brm.brid = br.brid
	WHERE GUID = @pGUID AND JoinNumber = @pJoinNumber
END
ELSE BEGIN
    INSERT INTO [DQMF].[dbo].[DQMF_BizRuleLookupMapping]
           ([BRId]
           ,[JoinNumber]
           ,[SourceLookupExpression]
           ,[DimensionLookupExpression]
           ,IsSourcePreviousValue)
     SELECT
           BRID , 
	       @pJoinNumber ,
           @pSourceLookupExpression ,
           @pDimensionLookupExpression ,
           isnull(@pIsSourcePreviousValue,0)
       FROM DQMF_BizRule
       WHERE GUID = @pGUID
	
END
END



GO
/****** Object:  StoredProcedure [dbo].[SetEtlPackage]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		GRANT STEPHENS
-- Create date: <Create Date,,>
-- Description:	INSERTS OR UPDATES ROWS IN dbo.ETL_Package
-- =============================================
CREATE PROCEDURE [dbo].[SetEtlPackage] 
    @pPkgID int
   ,@pPkgName varchar(100)
   ,@pPkgDescription varchar(500)
   ,@pCreatedBy varchar(50)
   ,@pUpdatedBy varchar(50)
    ,@pIsLocking bit = 0
AS
BEGIN
	
	SET NOCOUNT ON;

    IF EXISTS (SELECT * FROM dbo.ETL_Package WHERE PkgID = @pPkgID)
    BEGIN
         UPDATE dbo.ETL_Package
         SET PkgName = @pPkgName
             ,PkgDescription = @pPkgDescription
             ,UpdatedBy  = @pUpdatedBy 
             ,UpdatedDT = GETDATE()
             ,IsLocking = @pIsLocking
          WHERE PkgID = @pPkgID
	END ELSE
    BEGIN
         INSERT dbo.ETL_Package (PkgName
                                 ,PkgDescription
                                 ,CreatedBy
                                 ,CreatedDT
                                 ,UpdatedBy 
                                 ,UpdatedDT
                                 ,IsLocking)
             SELECT @pPkgName
                   ,@pPkgDescription
                   ,@pCreatedBy
                   ,GETDATE()
                   ,@pCreatedBy
                   ,GETDATE()
                   ,@pIsLocking
     END

END



GO
/****** Object:  StoredProcedure [dbo].[SetMDObject]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SetMDObject]
	@pDatabaseName varchar(50) = NULL, -- Optional
	@pDebug int = 0                    -- Optional
AS

BEGIN
	-- Create working table from sys.objects and sys.schemas.
	IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_Object_Working') AND type IN ('U'))
		BEGIN
			SELECT o.*, s.name AS SchemaName 
			INTO dbo.MD_Object_Working
			FROM sys.objects o
			INNER JOIN sys.schemas s
			ON o.schema_id = s.schema_id
			WHERE o.type IN ('ZZ');
		END;

	TRUNCATE TABLE dbo.MD_Object_Working;

	IF @pDebug = -1 -- Create temporary table MD_Object_Test for sanity check.
		BEGIN
			IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_Object_Test') AND type IN ('U'))
				BEGIN
					DROP TABLE dbo.MD_Object_Test;
				END;
			
			IF @pDebug <> 0 RAISERROR('Create temporary table MD_Object_Test.', 0, 1) WITH NOWAIT;

			SELECT o.*, NULL IsNewRecord, NULL IsPKUpdated, NULL IsObjectInDBUpdated
			INTO dbo.MD_Object_Test
			FROM dbo.MD_Object o;

			-- Default the three extra fields to 0 for existing records.
			UPDATE t
			SET  IsNewRecord = 0
				,IsPKUpdated = 0
				,IsObjectInDBUpdated = 0
			FROM dbo.MD_Object_Test t
		END;

	-- Table variable for storing MD_Database records for looping.
	DECLARE @MD_Database TABLE
	(
		DatabaseID int NOT NULL,
		DatabaseName varchar(50) NOT NULL
	);

	INSERT INTO @MD_Database(DatabaseID, DatabaseName)
	SELECT DatabaseID, LTRIM(RTRIM(DatabaseName))
	FROM   dbo.MD_Database
	WHERE  (DatabaseName = @pDatabaseName OR @pDatabaseName IS NULL);

	DECLARE @DatabaseID int;
	DECLARE @DatabaseName varchar(50);
	DECLARE @MaxObjectID int;
	DECLARE @SQLstring varchar(max);
	DECLARE @preObjID int;
	DECLARE @curObjID int;
	DECLARE @prePKey nvarchar(255);
	DECLARE @curPKey nvarchar(255);

	-- Table variable for storing object_id (from catalog views, not from MD_Object table) of records having primary keys.
	DECLARE @RecordWithPK TABLE
	(
		Obj_ID int NOT NULL
	);

	SET @DatabaseID = NULL;
	SET @DatabaseID = (SELECT MIN(DatabaseID) FROM @MD_Database); -- Get the first DatabaseID for the loop.

	IF @DatabaseID IS NULL
		BEGIN
			RAISERROR('The MD_Database table is empty OR the database name provided is incorrect.', 0, 1) WITH NOWAIT;
			DROP TABLE dbo.MD_Object_Working;
			RETURN;
		END;

	WHILE @DatabaseID IS NOT NULL
		BEGIN
			SET @DatabaseName = (SELECT DatabaseName FROM @MD_Database WHERE DatabaseID = @DatabaseID);

			IF @pDebug <> 0 RAISERROR('======================================================================', 0, 1) WITH NOWAIT;
			IF @pDebug <> 0 RAISERROR('DatabaseID = %i, DatabaseName = %s.', 0, 1, @DatabaseID, @DatabaseName) WITH NOWAIT;
		
			IF DB_ID(@DatabaseName) IS NULL -- Database does not exist.  Set IsObjectInDB to 0 for its objects in MD_Object table.
				BEGIN
					IF @pDebug <> -1 -- Normal run.
						BEGIN
							UPDATE o
							   SET IsObjectInDB = 0
								  ,UpdatedBy = SYSTEM_USER
								  ,UpdatedDT = GETDATE()
							  FROM dbo.MD_Object o 
							 WHERE o.DatabaseID = @DatabaseID
							   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
							   AND (o.IsObjectInDB = 1 OR o.IsObjectInDB IS NULL);
						END

					ELSE-- Update temporary table MD_Object_Test instead of MD_Object.
						BEGIN
							UPDATE o
							   SET IsObjectInDB = 0
								  ,IsObjectInDBUpdated = 1
								  ,UpdatedBy = SYSTEM_USER
								  ,UpdatedDT = GETDATE()
							  FROM dbo.MD_Object_Test o 
							 WHERE o.DatabaseID = @DatabaseID
							   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
							   AND (o.IsObjectInDB = 1 OR o.IsObjectInDB IS NULL);
						END;

					RAISERROR('Database object %s in MD_Database table does not exist.  Its MD_Object records, if any, have been updated so that the IsObjectInDB field is set to 0.', 0, 1, @DatabaseName) WITH NOWAIT;
				END

			ELSE -- Database exists.
				BEGIN
					TRUNCATE TABLE dbo.MD_Object_Working;

					SET @SQLstring = '
					INSERT INTO dbo.MD_Object_Working
					SELECT DISTINCT o.*, s.name AS SchemaName 
					FROM ' + @DatabaseName + '.sys.objects o
					INNER JOIN ' + @DatabaseName + '.sys.schemas s ON o.schema_id = s.schema_id
					LEFT OUTER JOIN ' + @DatabaseName + '.sys.extended_properties e ON o.object_id = e.major_id
					WHERE s.name <> ''sys''
					AND o.name <> ''sysdiagrams''
					AND ISNULL(o.is_ms_shipped, 0) = 0
					AND ISNULL(e.name, '''') <> ''microsoft_database_tools_support''
					AND o.type IN 
					(''U'', ''V'', ''P'', ''PC'', ''X'', ''TA'', ''TR'', ''AF'', ''FN'', ''FS'', ''FT'', ''IF'', ''TF'');
					'
					--  The first three lines in the WHERE clause exclude system objects.

					--  Meanings of the object type values are:
					--  U = Table (user-defined)
					--  V = View
					--  P = SQL Stored Procedure
					-- PC = Assembly (CLR) stored-procedure
					--  X = Extended stored procedure
					-- TA = Assembly (CLR) DML trigger
					-- TR = SQL DML trigger 
					-- AF = Aggregate function (CLR)
					-- FN = SQL scalar function
					-- FS = Assembly (CLR) scalar-function
					-- FT = Assembly (CLR) table-valued function
					-- IF = SQL inline table-valued function
					-- TF = SQL table-valued-function

					IF @pDebug <> 0 RAISERROR('Populate working table.', 0, 1) WITH NOWAIT;
					IF @pDebug <> 0 RAISERROR(@SQLstring, 0, 1) WITH NOWAIT;
				
					EXEC (@SQLstring);

					---------------------------------------------------------------------------------------------------------------------
					-- 1. Set IsObjectInDB to 1 for objects that exist in working table.
					IF @pDebug <> 0 RAISERROR('1. Set IsObjectInDB to 1 for objects that exist in working table.', 0, 1) WITH NOWAIT;

					IF @pDebug <> -1 -- Normal run.
						UPDATE o
   						   SET IsObjectInDB = 1
							  ,UpdatedBy = SYSTEM_USER
							  ,UpdatedDT = GETDATE()
						  FROM dbo.MD_Object_Working w INNER JOIN dbo.MD_Object o 
						    ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
						   AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
						 WHERE o.DatabaseID = @DatabaseID
						   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
						   AND ISNULL(o.IsObjectInDB, 0) <> 1;

					ELSE -- Update temporary table MD_Object_Test instead of MD_Object.
						UPDATE o
						   SET IsObjectInDB = 1
							  ,IsObjectInDBUpdated = 1
							  ,UpdatedBy = SYSTEM_USER
							  ,UpdatedDT = GETDATE()
						  FROM dbo.MD_Object_Working w INNER JOIN dbo.MD_Object_Test o 
						    ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
						   AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
						 WHERE o.DatabaseID = @DatabaseID
						   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
						   AND ISNULL(o.IsObjectInDB, 0) <> 1;

					---------------------------------------------------------------------------------------------------------------------
					-- 2. Set IsObjectInDB to 0 for objects that do not exist in working table.
					IF @pDebug <> 0 RAISERROR('2. Set IsObjectInDB to 0 for objects that do not exist in working table.', 0, 1) WITH NOWAIT;

					IF @pDebug <> -1 -- Normal run.
						UPDATE o
						   SET IsObjectInDB = 0
							  ,UpdatedBy = SYSTEM_USER
							  ,UpdatedDT = GETDATE()
						  FROM dbo.MD_Object o 
						 WHERE o.DatabaseID = @DatabaseID
						   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
						   AND (o.IsObjectInDB = 1 OR o.IsObjectInDB IS NULL)
						   AND NOT EXISTS (SELECT *
										     FROM dbo.MD_Object_Working w
										    WHERE w.SchemaName = LTRIM(RTRIM(ISNULL(o.ObjectSchemaName, '')))
											  AND w.name = LTRIM(RTRIM(ISNULL(o.ObjectPhysicalName, ''))));

					ELSE-- Update temporary table MD_Object_Test instead of MD_Object.
						UPDATE o
						   SET IsObjectInDB = 0
							  ,IsObjectInDBUpdated = 1
							  ,UpdatedBy = SYSTEM_USER
							  ,UpdatedDT = GETDATE()
						  FROM dbo.MD_Object_Test o 
						 WHERE o.DatabaseID = @DatabaseID
						   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
						   AND (o.IsObjectInDB = 1 OR o.IsObjectInDB IS NULL)
						   AND NOT EXISTS (SELECT *
											 FROM dbo.MD_Object_Working w
										    WHERE w.SchemaName = LTRIM(RTRIM(ISNULL(o.ObjectSchemaName, '')))
											  AND w.name = LTRIM(RTRIM(ISNULL(o.ObjectPhysicalName, ''))));
							
					---------------------------------------------------------------------------------------------------------------------
					-- 3. Create new object records.
					IF @pDebug <> 0 RAISERROR('3. Create new object records.', 0, 1) WITH NOWAIT;

					IF @pDebug <> -1 -- Normal run.
						BEGIN
							SET @MaxObjectID = (SELECT MAX(ObjectID) FROM dbo.MD_Object); -- Get the maximum ObjectID.
  				
							INSERT INTO dbo.MD_Object
								  (DatabaseID
								  ,SubjectAreaID
								  ,ObjectID
								  ,ObjectDisplayName
								  ,ObjectSchemaName
								  ,ObjectPhysicalName
								  ,ObjectType
								  ,ObjectPurpose
								  ,IsActive
								  ,IsObjectInDB
								  ,CreatedBy
								  ,CreatedDT
								  ,UpdatedBy
								  ,UpdatedDT)

							SELECT DatabaseID = @DatabaseID
								  ,SubjectAreaID = 0 -- Needs manual update by user later.
								  ,ObjectID = ROW_NUMBER() OVER (ORDER BY w.SchemaName, w.name) + @MaxObjectID
								  ,ObjectDisplayName = LEFT(w.SchemaName + '.' + w.name, 50)
								  ,ObjectSchemaName = LEFT(w.SchemaName, 50)
								  ,ObjectPhysicalName = w.name
								  ,ObjectType = CASE 
													WHEN w.type = 'U'  THEN 'Table' 
													WHEN w.type = 'V'  THEN 'View' 
													WHEN w.type = 'P'  THEN 'Stored Procedure' 
													WHEN w.type = 'PC' THEN 'Stored Procedure' 
													WHEN w.type = 'X'  THEN 'Stored Procedure' 
													WHEN w.type = 'TA' THEN 'Trigger'
													WHEN w.type = 'TR' THEN 'Trigger' 
													WHEN w.type = 'AF' THEN 'Function' 
													WHEN w.type = 'FN' THEN 'Function' 
													WHEN w.type = 'FS' THEN 'Function' 
													WHEN w.type = 'FT' THEN 'Function' 
													WHEN w.type = 'IF' THEN 'Function' 
													WHEN w.type = 'TF' THEN 'Function' 
													ELSE ''
												END
								  ,ObjectPurpose = CASE 
													   WHEN w.SchemaName = 'Dim' AND @DatabaseName = 'DSDW' AND (w.type = 'U' OR w.type = 'V') THEN 'Dimension Source'
													   WHEN w.SchemaName <> 'Dim' AND w.type = 'U' AND w.name LIKE '%View' THEN 'View Source Table'
													   WHEN w.SchemaName <> 'Dim' AND w.type = 'U' AND w.name LIKE '%Fact' THEN 'Fact'
													   ELSE ''
												   END
								  ,IsActive = 1 
								  ,IsObjectInDB = 1
								  ,CreatedBy = SYSTEM_USER
								  ,CreatedDT = GETDATE()
								  ,UpdatedBy = SYSTEM_USER
								  ,UpdatedDT = GETDATE()

							FROM dbo.MD_Object_Working w
							WHERE NOT EXISTS (SELECT *
											  FROM dbo.MD_Object o
											  WHERE o.DatabaseID = @DatabaseID
												AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
												AND LTRIM(RTRIM(ISNULL(o.ObjectSchemaName, ''))) = w.SchemaName
												AND LTRIM(RTRIM(ISNULL(o.ObjectPhysicalName, ''))) = w.name)
			  
						END

					ELSE -- Create new records in temporary table MD_Object_Test instead of MD_Object.
						BEGIN
							SET @MaxObjectID = (SELECT MAX(ObjectID) FROM dbo.MD_Object_Test); -- Get the maximum ObjectID.

							INSERT INTO dbo.MD_Object_Test
								  (DatabaseID
								  ,SubjectAreaID
								  ,ObjectID
								  ,ObjectDisplayName
								  ,ObjectSchemaName
								  ,ObjectPhysicalName
								  ,ObjectType
								  ,ObjectPurpose
								  ,IsActive
								  ,IsNewRecord
								  ,IsObjectInDB
								  ,CreatedBy
								  ,CreatedDT
								  ,UpdatedBy
								  ,UpdatedDT)

							SELECT DatabaseID = @DatabaseID
								  ,SubjectAreaID = 0
								  ,ObjectID = ROW_NUMBER() OVER (ORDER BY w.SchemaName, w.name) + @MaxObjectID
								  ,ObjectDisplayName = LEFT(w.SchemaName + '.' + w.name, 50)
								  ,ObjectSchemaName = LEFT(w.SchemaName, 50)
								  ,ObjectPhysicalName = w.name
								  ,ObjectType = CASE 
													WHEN w.type = 'U'  THEN 'Table' 
													WHEN w.type = 'V'  THEN 'View' 
													WHEN w.type = 'P'  THEN 'Stored Procedure' 
													WHEN w.type = 'PC' THEN 'Stored Procedure' 
													WHEN w.type = 'X'  THEN 'Stored Procedure' 
													WHEN w.type = 'TA' THEN 'Trigger'
													WHEN w.type = 'TR' THEN 'Trigger' 
													WHEN w.type = 'AF' THEN 'Function' 
													WHEN w.type = 'FN' THEN 'Function' 
													WHEN w.type = 'FS' THEN 'Function' 
													WHEN w.type = 'FT' THEN 'Function' 
													WHEN w.type = 'IF' THEN 'Function' 
													WHEN w.type = 'TF' THEN 'Function' 
													ELSE ''
												END
								  ,ObjectPurpose = CASE 
													   WHEN w.SchemaName = 'Dim' AND @DatabaseName = 'DSDW' AND (w.type = 'U' OR w.type = 'V') THEN 'Dimension Source'
													   WHEN w.SchemaName <> 'Dim' AND w.type = 'U' AND w.name LIKE '%View' THEN 'View Source Table'
													   WHEN w.SchemaName <> 'Dim' AND w.type = 'U' AND w.name LIKE '%Fact' THEN 'Fact'
													   ELSE ''
												   END
								  ,IsActive = 1
								  ,IsNewRecord = 1
								  ,IsObjectInDB = 1
								  ,CreatedBy = SYSTEM_USER
								  ,CreatedDT = GETDATE()
								  ,UpdatedBy = SYSTEM_USER
								  ,UpdatedDT = GETDATE()

							FROM dbo.MD_Object_Working w
							WHERE NOT EXISTS (SELECT *
											  FROM dbo.MD_Object_Test o
											  WHERE o.DatabaseID = @DatabaseID
												AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View', 'Stored Procedure', 'Trigger', 'Function')
												AND LTRIM(RTRIM(ISNULL(o.ObjectSchemaName, ''))) = w.SchemaName
												AND LTRIM(RTRIM(ISNULL(o.ObjectPhysicalName, ''))) = w.name);
															  
						END;

					---------------------------------------------------------------------------------------------------------------------
					-- 4. Populate/Update ObjectPKField.
					IF @pDebug <> 0 RAISERROR('4. Populate/Update ObjectPKField.', 0, 1) WITH NOWAIT;

					DELETE FROM @RecordWithPK; -- Make sure table variable is empty.

					SET @preObjID = 0;
					SET @curObjID = 0;
					SET @prePKey = '';
					SET @curPKey = '';

					SET @SQLstring = '
					DECLARE PK_Cursor CURSOR FORWARD_ONLY STATIC
					FOR 
					SELECT i.object_id AS TableObjID, c.name AS PKey
					FROM ' + @DatabaseName + '.sys.indexes i
					INNER JOIN ' + @DatabaseName + '.sys.index_columns ic
					   ON i.object_id = ic.object_id AND i.index_id = ic.index_id
					INNER JOIN ' + @DatabaseName + '.sys.columns c
					   ON ic.object_id = c.object_id AND ic.column_id = c.column_id
					WHERE i.is_primary_key = 1
					  AND i.object_id IN (SELECT w.object_id FROM dbo.MD_Object_Working w
										  WHERE w.type = ''U'')
					ORDER BY i.object_id, c.column_id;
					'

					IF @pDebug <> 0 RAISERROR(@SQLstring, 0, 1) WITH NOWAIT;
				
					EXEC (@SQLstring);

					OPEN PK_Cursor;
					FETCH NEXT FROM PK_Cursor INTO @curObjID, @curPKey;

					WHILE @@FETCH_STATUS = 0

						BEGIN
							--IF @pDebug <> 0 RAISERROR('@preObjID = %i, @prePKey = %s, @curObjID = %i, @curPKey = %s', 0, 1, @preObjID, @prePKey, @curObjID, @curPKey) WITH NOWAIT;

							INSERT INTO @RecordWithPK(Obj_ID) VALUES (@curObjID);		

							IF @preObjID = 0 -- Current record is the first record.
								BEGIN
									--IF @pDebug <> 0 RAISERROR('Current record is the first record.', 0, 1) WITH NOWAIT;
									SET @preObjID = @curObjID;
									SET @prePKey = @curPKey;
								END
							ELSE -- Current record is not the first record.
								BEGIN	
									IF @curObjID = @preObjID
										BEGIN
											--IF @pDebug <> 0 RAISERROR('Concatenating ObjectPKField values.', 0, 1) WITH NOWAIT;
											SET @prePKey = @prePKey + ', ' + @curPKey;
										END
									ELSE
										BEGIN
											IF @pDebug <> -1 -- Normal run.
												BEGIN
													--IF @pDebug <> 0 RAISERROR('Updating ObjectPKField.', 0, 1) WITH NOWAIT;

													UPDATE o -- Write the previous record.
													   SET ObjectPKField = LEFT(@prePKey, 255)
														  ,UpdatedBy = SYSTEM_USER
														  ,UpdatedDT = GETDATE()
													  FROM dbo.MD_Object o INNER JOIN dbo.MD_Object_Working w
													    ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
													   AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
													 WHERE o.DatabaseID = @DatabaseID
													   AND LTRIM(RTRIM(o.ObjectType)) = 'Table'
													   --AND (o.IsActive = 1 OR (o.SubjectAreaID = 0 AND o.CreatedBy = SYSTEM_USER)) -- Only update active records or records inserted by this stored procedure.
													   AND RTRIM(ISNULL(o.ObjectPKField, '')) <> LEFT(@prePKey, 255) -- Do not use LTRIM so that primary keys with leading spaces will be updated.
													   AND w.object_id = @preObjID;
												END

											ELSE -- Update records in temporary table MD_Object_Test instead of MD_Object.
												BEGIN
													UPDATE o -- Write the previous record.
													   SET ObjectPKField = LEFT(@prePKey, 255)
														  ,IsPKUpdated = CASE WHEN o.IsNewRecord = 1 THEN NULL ELSE 1 END  -- Do not set this field for new records.
														  ,UpdatedBy = SYSTEM_USER
														  ,UpdatedDT = GETDATE()
													  FROM dbo.MD_Object_Test o INNER JOIN dbo.MD_Object_Working w
													    ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
													   AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
													 WHERE o.DatabaseID = @DatabaseID
													   AND LTRIM(RTRIM(o.ObjectType)) = 'Table'
													   --AND (o.IsActive = 1 OR (o.SubjectAreaID = 0 AND o.CreatedBy = SYSTEM_USER)) -- Only update active records or records inserted by this stored procedure.
													   AND RTRIM(ISNULL(o.ObjectPKField, '')) <> LEFT(@prePKey, 255) -- Do not use LTRIM so that primary keys with leading spaces will be updated.
													   AND w.object_id = @preObjID;
												END;

											SET @preObjID = @curObjID;
											SET @prePKey = @curPKey;
										END;
								END;

							FETCH NEXT FROM PK_Cursor INTO @curObjID, @curPKey;
							
							IF @@FETCH_STATUS <> 0 -- Current record is the last record.
								BEGIN
									IF @pDebug <> -1 -- Normal run.
										BEGIN
											--IF @pDebug <> 0 RAISERROR('Updating ObjectPKField of last record.', 0, 1) WITH NOWAIT;

											UPDATE o -- Write the last record.
											  SET  ObjectPKField = CASE WHEN @curObjID = @preObjID THEN LEFT(@prePKey, 255) ELSE LEFT(@curPKey, 255) END
												  ,UpdatedBy = SYSTEM_USER
												  ,UpdatedDT = GETDATE()
											  FROM dbo.MD_Object o INNER JOIN dbo.MD_Object_Working w
												ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
											   AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
											 WHERE o.DatabaseID = @DatabaseID
											   AND LTRIM(RTRIM(o.ObjectType)) = 'Table'
											   --AND (o.IsActive = 1 OR (o.SubjectAreaID = 0 AND o.CreatedBy = SYSTEM_USER)) -- Only update active records or records inserted by this stored procedure.
											   AND LTRIM(RTRIM(ISNULL(o.ObjectPKField, ''))) <> CASE WHEN @curObjID = @preObjID THEN LEFT(@prePKey, 255) ELSE LEFT(@curPKey, 255) END
											   AND w.object_id = @curObjID;
										END

									ELSE -- Update records in temporary table MD_Object_Test instead of MD_Object.
										BEGIN
											UPDATE o -- Write the last record.
											  SET  ObjectPKField = CASE WHEN @curObjID = @preObjID THEN LEFT(@prePKey, 255) ELSE LEFT(@curPKey, 255) END
												  ,IsPKUpdated = CASE WHEN o.IsNewRecord = 1 THEN NULL ELSE 1 END -- Do not set this field for new records.
												  ,UpdatedBy = SYSTEM_USER
												  ,UpdatedDT = GETDATE()
											  FROM dbo.MD_Object_Test o INNER JOIN dbo.MD_Object_Working w
												ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
											   AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
											 WHERE o.DatabaseID = @DatabaseID
											   AND LTRIM(RTRIM(o.ObjectType)) = 'Table'
											   --AND (o.IsActive = 1 OR (o.SubjectAreaID = 0 AND o.CreatedBy = SYSTEM_USER)) -- Only update active records or records inserted by this stored procedure.
											   AND LTRIM(RTRIM(ISNULL(o.ObjectPKField, ''))) <> CASE WHEN @curObjID = @preObjID THEN LEFT(@prePKey, 255) ELSE LEFT(@curPKey, 255) END
											   AND w.object_id = @curObjID;
										END;
								END;
						END; -- End of cursor WHILE loop.
				
					CLOSE PK_Cursor;
					DEALLOCATE PK_Cursor;

					-- Set ObjectPKField to NULL for table objects that do not have primary keys.
					IF @pDebug <> -1 -- Normal run.
						BEGIN
							UPDATE o 
							SET  ObjectPKField = NULL
								,UpdatedBy = SYSTEM_USER
								,UpdatedDT = GETDATE()
							FROM dbo.MD_Object o INNER JOIN dbo.MD_Object_Working w
							ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
							AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
							WHERE o.DatabaseID = @DatabaseID
							AND LTRIM(RTRIM(o.ObjectType)) = 'Table'
							AND o.ObjectPKField IS NOT NULL
							AND NOT EXISTS (SELECT * 
											FROM @RecordWithPK pk
											WHERE pk.Obj_ID = w.object_id);
						END

					ELSE -- Update records in temporary table MD_Object_Test instead of MD_Object.
						BEGIN
							UPDATE o 
							SET  ObjectPKField = NULL
								,IsPKUpdated = CASE WHEN o.IsNewRecord = 1 THEN NULL ELSE 1 END -- Do not set this field for new records.
								,UpdatedBy = SYSTEM_USER
								,UpdatedDT = GETDATE()
							FROM dbo.MD_Object_Test o INNER JOIN dbo.MD_Object_Working w
							ON LTRIM(RTRIM(o.ObjectPhysicalName)) = w.name
							AND LTRIM(RTRIM(o.ObjectSchemaName)) = w.SchemaName 
							WHERE o.DatabaseID = @DatabaseID
							AND LTRIM(RTRIM(o.ObjectType)) = 'Table'
							AND o.ObjectPKField IS NOT NULL
							AND NOT EXISTS (SELECT * 
											FROM @RecordWithPK pk
											WHERE pk.Obj_ID = w.object_id);
						END;

					---------------------------------------------------------------------------------------------------------------------
				END;

			-- Get the next DatabaseID for the loop.
			SET @DatabaseID = (SELECT MIN(DatabaseID) FROM @MD_Database WHERE DatabaseID > @DatabaseID);

		END; -- End of outer WHILE loop.

	IF @pDebug = 0 DROP TABLE dbo.MD_Object_Working;

	--IF @pDebug <> -1
	--	BEGIN
	--		IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_Object_Test') AND type IN ('U'))
	--			DROP TABLE dbo.MD_Object_Test;
	--	END;
	
	IF @pDebug <> -1
		RAISERROR('Update of MD_Object table is complete.', 0, 1) WITH NOWAIT;
	ELSE
		RAISERROR('Update of MD_Object_Test table is complete.', 0, 1) WITH NOWAIT;

END; -- End of Alter Procedure statement.

GO
/****** Object:  StoredProcedure [dbo].[SetMDObjectAttribute]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SetMDObjectAttribute]
	@pObjectID int = NULL, -- Optional
	@pDebug int = 0        -- Optional
AS

BEGIN

	IF @pDebug = -1 -- MD_Object_Test table must exist for the creation of MD_ObjectAttribute_Test table.
		BEGIN
			IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_Object_Test') AND type IN ('U'))
				BEGIN
					RAISERROR('The table MD_Object_Test does not exist.  Run stored procedure DQMF.dbo.SetMDObject with parameter @pDebug = -1 to create that table before running SetMDObjectAttribute with @pDebug = -1.', 0, 1) WITH NOWAIT;
					RETURN;
				END
		END;


	-- Create working table from system views.
	IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_ObjectAttribute_Working') AND type IN ('U'))
		BEGIN
			SELECT s.name AS ObjectSchema
				  ,o.name AS ObjectPhysicalName
				  ,c.name AS AttributePhysicalName
				  ,t.name AS DataType
				  ,CONVERT(varchar(10), c.Max_Length) AS AttributeLength
				  ,CONVERT(varchar(10), c.column_id) AS Sequence
			INTO dbo.MD_ObjectAttribute_Working
			FROM sys.objects o
			LEFT OUTER JOIN sys.columns c on o.object_id = c.object_id
			LEFT OUTER JOIN sys.schemas s on o.schema_id = s.schema_id
			LEFT OUTER JOIN sys.types t on c.system_type_id = t.system_type_id
			WHERE o.name = 'No Table';
		END;

	TRUNCATE TABLE dbo.MD_ObjectAttribute_Working;

	IF @pDebug = -1 -- Create temporary table MD_ObjectAttribute_Test for sanity check.
		BEGIN
			IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_ObjectAttribute_Test') AND type IN ('U'))
				BEGIN
					DROP TABLE dbo.MD_ObjectAttribute_Test;
				END;

			IF @pDebug <> 0 RAISERROR('Create temporary table MD_ObjectAttribute_Test.', 0, 1) WITH NOWAIT;

			SELECT a.*, NULL IsNewRecord, NULL IsActiveUpdated, NULL IsADSUpdated
			INTO dbo.MD_ObjectAttribute_Test
			FROM dbo.MD_ObjectAttribute a;

			-- Default the three extra fields to 0 for existing records.
			UPDATE t
			SET  IsNewRecord = 0
				,IsActiveUpdated = 0
				,IsADSUpdated = 0
			FROM dbo.MD_ObjectAttribute_Test t
		END;

    -----------------------------------------------------------------------------------------------------------------------------
	-- Delete duplicate attribute records.
	IF @pDebug <> 0 RAISERROR('Delete duplicate attribute records.', 0, 1) WITH NOWAIT;

	IF @pDebug <> -1 -- Normal run.
		BEGIN
			DELETE a
			FROM dbo.MD_ObjectAttribute a
			WHERE a.ObjectAttributeID NOT IN (SELECT MIN(oa.ObjectAttributeID)
										      FROM dbo.MD_ObjectAttribute oa
										      GROUP BY oa.ObjectID, oa.AttributePhysicalName)
			AND NOT EXISTS (SELECT *
							FROM DQMF.dbo.DQMF_BizRule br
							WHERE br.FactTableObjectAttributeId = a.ObjectAttributeID
							OR br.SecondaryFactTableObjectAttributeId = a.ObjectAttributeID);
		END
	ELSE -- Update MD_ObjectAttribute_Test instead of MD_ObjectAttribute
		BEGIN
			DELETE a
			FROM dbo.MD_ObjectAttribute_Test a
			WHERE a.ObjectAttributeID NOT IN (SELECT MIN(oa.ObjectAttributeID)
										      FROM dbo.MD_ObjectAttribute_Test oa
										      GROUP BY oa.ObjectID, oa.AttributePhysicalName)
			AND NOT EXISTS (SELECT *
							FROM DQMF.dbo.DQMF_BizRule br
							WHERE br.FactTableObjectAttributeId = a.ObjectAttributeID
							OR br.SecondaryFactTableObjectAttributeId = a.ObjectAttributeID);
		END;

    -----------------------------------------------------------------------------------------------------------------------------
	-- Delete orphan records whose ObjectIDs do not exist in MD_Object or MD_Object_Test table.
	IF @pDebug <> -1 -- Normal run.
		BEGIN
			IF @pDebug <> 0 RAISERROR('Delete orphan records whose ObjectIDs do not exist in MD_Object table.', 0, 1) WITH NOWAIT;

			DELETE a
			FROM dbo.MD_ObjectAttribute a
			WHERE NOT EXISTS (SELECT *
							  FROM dbo.MD_Object o
							  WHERE o.ObjectID = a.ObjectID);
		END
	ELSE -- Update MD_ObjectAttribute_Test instead of MD_ObjectAttribute
		BEGIN
			RAISERROR('Delete orphan records whose ObjectIDs do not exist in MD_Object_Test table.', 0, 1) WITH NOWAIT;

			DELETE a
			FROM dbo.MD_ObjectAttribute_Test a
			WHERE NOT EXISTS (SELECT *
							  FROM dbo.MD_Object_Test o
							  WHERE o.ObjectID = a.ObjectID);
		END;

    -----------------------------------------------------------------------------------------------------------------------------
	-- Delete records belonging to objects whose ObjectType is Stored Procedure, Function, or Trigger.
	IF @pDebug <> 0 RAISERROR('Delete records belonging to objects whose ObjectType is Stored Procedure, Function, or Trigger.', 0, 1) WITH NOWAIT;

	IF @pDebug <> -1 -- Normal run.
		BEGIN
			DELETE a
			FROM dbo.MD_ObjectAttribute a
			WHERE EXISTS (SELECT *
						  FROM dbo.MD_Object o
						  WHERE o.ObjectID = a.ObjectID
						  AND LTRIM(RTRIM(o.ObjectType)) IN ('Stored Procedure', 'Function', 'Trigger'));
		END
	ELSE -- Update MD_ObjectAttribute_Test instead of MD_ObjectAttribute
		BEGIN
			DELETE a
			FROM dbo.MD_ObjectAttribute_Test a
			WHERE EXISTS (SELECT *
						  FROM dbo.MD_Object_Test o
						  WHERE o.ObjectID = a.ObjectID
						  AND LTRIM(RTRIM(o.ObjectType)) IN ('Stored Procedure', 'Function', 'Trigger'));
		END;
    -----------------------------------------------------------------------------------------------------------------------------

	-- Table variable for storing MD_Object records for looping.
	DECLARE @MD_Object TABLE
	(
		DatabaseName varchar(50) NOT NULL,
		ObjectID int NOT NULL,
		ObjectSchemaName varchar(50) NOT NULL,
		ObjectPhysicalName varchar(255) NOT NULL
	);

	IF @pDebug <> 0 RAISERROR('Populate @MD_Object Table variable for WHILE loop.', 0, 1) WITH NOWAIT;

	IF @pDebug <> -1 -- Normal run.
		BEGIN
			INSERT INTO @MD_Object(DatabaseName, ObjectID, ObjectSchemaName, ObjectPhysicalName)
			SELECT LTRIM(RTRIM(d.DatabaseName))
				  ,o.ObjectID
				  ,LTRIM(RTRIM(o.ObjectSchemaName))
				  ,LTRIM(RTRIM(o.ObjectPhysicalName))
			  FROM dbo.MD_Object o INNER JOIN dbo.MD_Database d
				ON o.DatabaseID = d.DatabaseID
			 WHERE LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View') -- Only look at table and view objects.
			   AND (o.ObjectID = @pObjectID OR @pObjectID IS NULL);
		END
	ELSE -- Use MD_Object_Test table instead of MD_Object table.
		BEGIN
			INSERT INTO @MD_Object(DatabaseName, ObjectID, ObjectSchemaName, ObjectPhysicalName)
			SELECT LTRIM(RTRIM(d.DatabaseName))
				  ,o.ObjectID
				  ,LTRIM(RTRIM(o.ObjectSchemaName))
				  ,LTRIM(RTRIM(o.ObjectPhysicalName))
			  FROM dbo.MD_Object_Test o INNER JOIN dbo.MD_Database d
				ON o.DatabaseID = d.DatabaseID
			 WHERE LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View') -- Only look at table and view objects.
			   AND (o.ObjectID = @pObjectID OR @pObjectID IS NULL);
		END;

	DECLARE @DatabaseName varchar(50);
	DECLARE @ObjectID int;
	DECLARE @ObjectPhysicalName varchar(255);
	DECLARE @ObjectSchemaName varchar(50);
	DECLARE @WorkingTableCount int;
	DECLARE @MaxObjectAttributeID int;
	DECLARE @SQLstring varchar(max);

	SET @ObjectID = NULL;
	SET @ObjectID = (SELECT MIN(ObjectID) FROM @MD_Object); -- Get the first ObjectID for the loop.

	IF @ObjectID IS NULL
		BEGIN
			RAISERROR('No object to process or the ObjectID provided is incorrect.', 0, 1) WITH NOWAIT;
			DROP TABLE dbo.MD_ObjectAttribute_Working;
			RETURN;
		END;

	WHILE @ObjectID IS NOT NULL
		BEGIN

			SET @DatabaseName = (SELECT DatabaseName FROM @MD_Object WHERE ObjectID = @ObjectID);
			SET @ObjectSchemaName = (SELECT ObjectSchemaName FROM @MD_Object WHERE ObjectID = @ObjectID);
			SET @ObjectPhysicalName = (SELECT ObjectPhysicalName FROM @MD_Object WHERE ObjectID = @ObjectID);
		
			IF @pDebug <> 0 RAISERROR('=========================================================================================================', 0, 1) WITH NOWAIT;
			IF @pDebug <> 0 RAISERROR('DatabaseName = %s, ObjectID = %i, ObjectSchemaName = %s, ObjectPhysicalName = %s.', 0, 1, @DatabaseName, @ObjectID, @ObjectSchemaName, @ObjectPhysicalName) WITH NOWAIT;

			IF DB_ID(@DatabaseName) IS NULL -- Database object does not exist.  Set all relating attributes to inactive.
				BEGIN
					IF @pDebug <> -1 -- Normal run.
						BEGIN
							UPDATE a
							   SET IsActive = 0
								  ,UpdatedBy = SYSTEM_USER
								  ,UpdatedDT = GETDATE()
							  FROM dbo.MD_ObjectAttribute a 
							       INNER JOIN dbo.MD_Object o ON a.ObjectID = o.ObjectID
							       INNER JOIN dbo.MD_Database d ON o.DatabaseId = d.DatabaseId
							 WHERE ISNULL(a.IsActive, 1) <> 0
							   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View')
							   AND a.ObjectID = @ObjectID
							   AND d.DatabaseName = @DatabaseName;
						END

					ELSE -- Update temporary table MD_ObjectAttribute_Test instead of MD_ObjectAttribute.
						BEGIN
							UPDATE a
							   SET IsActive = 0
								  ,IsActiveUpdated = 1
								  ,UpdatedBy = SYSTEM_USER
								  ,UpdatedDT = GETDATE()
							  FROM dbo.MD_ObjectAttribute_Test a 
							       INNER JOIN dbo.MD_Object_Test o ON a.ObjectID = o.ObjectID
							       INNER JOIN dbo.MD_Database d ON o.DatabaseId = d.DatabaseId
							 WHERE ISNULL(a.IsActive, 1) <> 0
							   AND LTRIM(RTRIM(o.ObjectType)) IN ('Table', 'View')
							   AND a.ObjectID = @ObjectID
							   AND d.DatabaseName = @DatabaseName;
						END;

					RAISERROR('Database object %s and table/view object %s.%s (ObjectID %i) do not exist (although their records exist in the MD tables).  The attribute records, if any, linked to the table/view object have been deactivated.', 0, 1, @DatabaseName, @ObjectSchemaName, @ObjectPhysicalName, @ObjectID) WITH NOWAIT;
				END

			ELSE -- Database exists.
				BEGIN
					TRUNCATE TABLE dbo.MD_ObjectAttribute_Working;

					SET @SQLstring = '
					INSERT INTO dbo.MD_ObjectAttribute_Working
					SELECT s.name AS ObjectSchema
						  ,o.name AS ObjectPhysicalName
						  ,c.name AS AttributePhysicalName
						  ,t.name AS DataType
						  ,CASE t.name
								WHEN ''char''        THEN CONVERT(varchar(10), c.Max_Length) 
								WHEN ''varchar''     THEN CONVERT(varchar(10), IIF(c.Max_Length = -1, 8000, c.Max_Length)) 
								WHEN ''nchar''       THEN CONVERT(varchar(10), c.Max_Length/2) 
								WHEN ''nvarchar''    THEN CONVERT(varchar(10), IIF(c.Max_Length = -1, 8000, c.Max_Length/2)) 
								WHEN ''text''        THEN ''8000'' 
								WHEN ''ntext''       THEN ''8000'' 
								WHEN ''sql_variant'' THEN ''8000'' 
								WHEN ''xml''         THEN ''8000''
								ELSE ''0''
						   END AS AttributeLength
						  ,CONVERT(varchar(10), c.column_id) AS Sequence
					FROM ' + @DatabaseName + '.sys.objects o
					LEFT OUTER JOIN ' + @DatabaseName + '.sys.columns c on o.object_id = c.object_id
					LEFT OUTER JOIN ' + @DatabaseName + '.sys.schemas s on o.schema_id = s.schema_id
					LEFT OUTER JOIN ' + @DatabaseName + '.sys.types t on c.system_type_id = t.system_type_id
					WHERE t.name <> ''sysname''
					AND s.name = ''' + @ObjectSchemaName + '''
					AND o.name = ''' + @ObjectPhysicalName + '''
					';

					IF @pDebug <> 0 RAISERROR('Populate working table', 0, 1) WITH NOWAIT;
					IF @pDebug <> 0 RAISERROR(@SQLstring, 0, 1) WITH NOWAIT;

					EXEC (@SQLstring);

					SET @WorkingTableCount = (SELECT COUNT(*) FROM dbo.MD_ObjectAttribute_Working);

					IF @WorkingTableCount > 0  -- @ObjectPhysicalName exists.
						BEGIN
							--------------------------------------------------------------------------------------------------------------------------------
							-- 1. Activate inactive attributes that exist in working table.
							IF @pDebug <> 0 RAISERROR('1. Activate inactive attributes that exist in working table.', 0, 1) WITH NOWAIT;

							IF @pDebug <> -1 -- Normal run.
								BEGIN
									UPDATE a
									   SET IsActive = 1
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute_Working w INNER JOIN dbo.MD_ObjectAttribute a 
										ON w.AttributePhysicalName = LTRIM(RTRIM(a.AttributePhysicalName))
									 WHERE a.ObjectID = @ObjectID
									   AND ISNULL(a.IsActive, 0) <> 1;
								 END

							ELSE -- Update temporary table MD_ObjectAttribute_Test instead of MD_ObjectAttribute.
								BEGIN
									UPDATE a
									   SET IsActive = 1
										  ,IsActiveUpdated = 1
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute_Working w INNER JOIN dbo.MD_ObjectAttribute_Test a 
										ON w.AttributePhysicalName = LTRIM(RTRIM(a.AttributePhysicalName))
									 WHERE a.ObjectID = @ObjectID
									   AND ISNULL(a.IsActive, 0) <> 1;
								 END;

							--------------------------------------------------------------------------------------------------------------------------------
							-- 2. Deactivate attributes that do not exist in working table.
							IF @pDebug <> 0 RAISERROR('2. Deactivate attributes that do not exist in working table.', 0, 1) WITH NOWAIT;

							IF @pDebug <> -1 -- Normal run.
								BEGIN
									UPDATE a
									   SET IsActive = 0
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute a 
									 WHERE a.ObjectID = @ObjectID
									   AND ISNULL(a.IsActive, 1) <> 0
									   AND NOT EXISTS (SELECT *
													   FROM dbo.MD_ObjectAttribute_Working w
													   WHERE w.AttributePhysicalName = LTRIM(RTRIM(ISNULL(a.AttributePhysicalName, ''))));
								END

							ELSE -- Update temporary table MD_ObjectAttribute_Test instead of MD_ObjectAttribute.
								BEGIN
									UPDATE a
									   SET IsActive = 0
									      ,IsActiveUpdated = 1
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute_Test a 
									 WHERE a.ObjectID = @ObjectID
									   AND ISNULL(a.IsActive, 1) <> 0
									   AND NOT EXISTS (SELECT *
													   FROM dbo.MD_ObjectAttribute_Working w
													   WHERE w.AttributePhysicalName = LTRIM(RTRIM(ISNULL(a.AttributePhysicalName, ''))));
								END;

							--------------------------------------------------------------------------------------------------------------------------------
							-- 3. Create new attribute records.
							IF @pDebug <> 0 RAISERROR('3. Create new attribute records.', 0, 1) WITH NOWAIT;

							IF @pDebug <> -1 -- Normal run.
								BEGIN
									SET @MaxObjectAttributeID = (SELECT MAX(ObjectAttributeID) FROM dbo.MD_ObjectAttribute); -- Get the maximum ObjectAttributeID.

									INSERT INTO dbo.MD_ObjectAttribute
										  (ObjectID
										  ,ObjectAttributeID
										  ,AttributeID
										  ,Sequence
										  ,AttributePhysicalName
										  ,Datatype
										  ,AttributeLength
										  ,IsActive
										  ,CreatedBy
										  ,CreatedDT)

									SELECT ObjectID = @ObjectID
										  ,ObjectAttributeID = ROW_NUMBER() OVER (ORDER BY w.Sequence) + @MaxObjectAttributeID
										  ,AttributeID = 0 -- AttributeID is a required field.
										  ,Sequence
										  ,AttributePhysicalName
										  ,DataType
										  ,AttributeLength
										  ,IsActive = 1
										  ,CreatedBy = SYSTEM_USER
										  ,CreatedDT = GETDATE()

									FROM dbo.MD_ObjectAttribute_Working w
									WHERE NOT EXISTS (SELECT *
													  FROM  dbo.MD_ObjectAttribute a
													  WHERE a.ObjectID = @ObjectID
														AND LTRIM(RTRIM(ISNULL(a.AttributePhysicalName, ''))) = w.AttributePhysicalName);
								END

							ELSE -- Update temporary table MD_ObjectAttribute_Test instead of MD_ObjectAttribute.
								BEGIN

									SET @MaxObjectAttributeID = (SELECT MAX(ObjectAttributeID) FROM dbo.MD_ObjectAttribute_Test); -- Get the maximum ObjectAttributeID.

									INSERT INTO dbo.MD_ObjectAttribute_Test
										  (ObjectID
										  ,ObjectAttributeID
										  ,AttributeID
										  ,Sequence
										  ,AttributePhysicalName
										  ,Datatype
										  ,AttributeLength
										  ,IsActive
										  ,IsNewRecord
										  ,CreatedBy
										  ,CreatedDT)

									SELECT ObjectID = @ObjectID
										  ,ObjectAttributeID = ROW_NUMBER() OVER (ORDER BY w.Sequence) + @MaxObjectAttributeID
										  ,AttributeID = 0 -- AttributeID is a required field.
										  ,Sequence
										  ,AttributePhysicalName
										  ,DataType
										  ,AttributeLength
										  ,IsActive = 1
										  ,IsNewRecord = 1
										  ,CreatedBy = SYSTEM_USER
										  ,CreatedDT = GETDATE()

									FROM dbo.MD_ObjectAttribute_Working w
									WHERE NOT EXISTS (SELECT *
													  FROM  dbo.MD_ObjectAttribute_Test a
													  WHERE a.ObjectID = @ObjectID
														AND LTRIM(RTRIM(ISNULL(a.AttributePhysicalName, ''))) = w.AttributePhysicalName);
								END;

							--------------------------------------------------------------------------------------------------------------------------------
							-- 4. Update AttributeLength, DataType, and/or Sequence
							IF @pDebug <> 0 RAISERROR('4. Update AttributeLength, DataType, and/or Sequence', 0, 1) WITH NOWAIT;

							IF @pDebug <> -1 -- Normal run.
								BEGIN
									UPDATE a
									   SET Sequence = w.Sequence
										  ,DataType = w.DataType
										  ,AttributeLength = w.AttributeLength
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute_Working w INNER JOIN dbo.MD_ObjectAttribute a 
										ON w.AttributePhysicalName = LTRIM(RTRIM(a.AttributePhysicalName))
									 WHERE a.ObjectID = @ObjectID
									   AND a.IsActive = 1
									   AND (a.Sequence <> w.Sequence
										OR a.Datatype <> w.DataType
										OR a.AttributeLength <> w.AttributeLength);
								END

							ELSE -- Update temporary table MD_ObjectAttribute_Test instead of MD_ObjectAttribute.
								BEGIN
									UPDATE a
									   SET Sequence = w.Sequence
										  ,DataType = w.DataType
										  ,AttributeLength = w.AttributeLength
										  ,IsADSUpdated = CASE WHEN a.IsNewRecord = 1 THEN NULL ELSE 1 END -- Do not set this field for new records.
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute_Working w INNER JOIN dbo.MD_ObjectAttribute_Test a 
										ON w.AttributePhysicalName = LTRIM(RTRIM(a.AttributePhysicalName))
									 WHERE a.ObjectID = @ObjectID
									   AND a.IsActive = 1
									   AND (a.Sequence <> w.Sequence
										OR a.Datatype <> w.DataType
										OR a.AttributeLength <> w.AttributeLength);
								END;
						END

					ELSE -- @WorkingTableCount = 0. @ObjectPhysicalName does not exist.
						BEGIN
							IF @pDebug <> -1 -- Normal run.
								BEGIN
									UPDATE a
									   SET IsActive = 0
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute a 
									 WHERE a.ObjectID = @ObjectID
									   AND ISNULL(a.IsActive, 1) <> 0;
								END

							ELSE -- Update temporary table MD_ObjectAttribute_Test instead of MD_ObjectAttribute.
								BEGIN
									UPDATE a
									   SET IsActive = 0
									      ,IsActiveUpdated = 1
										  ,UpdatedBy = SYSTEM_USER
										  ,UpdatedDT = GETDATE()
									  FROM dbo.MD_ObjectAttribute_Test a 
									 WHERE a.ObjectID = @ObjectID
									   AND ISNULL(a.IsActive, 1) <> 0;
								END;

							RAISERROR('The table/view object %s.%s with ObjectID %i does not exist.  Its attributes, if any, have been deactivated.', 0, 1, @ObjectSchemaName, @ObjectPhysicalName, @ObjectID) WITH NOWAIT;
						END;
				END;

			-- Get the next ObjectID for the loop.
			SET @ObjectID = (SELECT MIN(ObjectID) FROM @MD_Object WHERE ObjectID > @ObjectID);

		END; -- End of While loop.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	IF @pDebug = 0 DROP TABLE dbo.MD_ObjectAttribute_Working;

	--IF @pDebug <> -1
	--	BEGIN
	--		IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.MD_ObjectAttribute_Test') AND type IN ('U'))
	--			DROP TABLE dbo.MD_ObjectAttribute_Test;
	--	END;
	
	IF @pDebug <> -1
		RAISERROR('Update of MD_ObjectAttribute table is complete.', 0, 1) WITH NOWAIT;
	ELSE
		RAISERROR('Update of MD_ObjectAttribute_Test table is complete.', 0, 1) WITH NOWAIT;

END; -- End of Alter Procedure statement.

GO
/****** Object:  StoredProcedure [dbo].[SetStageSchedule]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		GrantS
-- Create date: <Create Date,,>
-- Description:	Updates and Inserts data to teh Stage and Schedule tables
--              done in one process as it is a one to one relationship
-- =============================================
CREATE PROCEDURE [dbo].[SetStageSchedule]
@pStageID int,
@pStageName varchar(50),
@pStageDescription  varchar(max),
@pStageOrder  smallint,
@pDQMF_ScheduleId int,
@pDatabaseId int,
@pTableId int,
@pPkgKey int,
@pIsScheduleActive bit,
@pCreatedBy varchar(50),
@pUpdatedBy varchar(50)
	
AS
BEGIN
	SET NOCOUNT ON;
DECLARE @STAGEID INT,
        @SCHEDULEID int

	IF exists (SELECT StageID FROM dbo.DQMF_Stage WHERE StageID = @pStageID)
	BEGIN
         UPDATE dbo.DQMF_Stage
            SET StageName = @pStageName,
                StageDescription = @pStageDescription,
                StageOrder = @pStageOrder
          WHERE StageID = @pStageID
       IF exists(SELECT StageID FROM dbo.DQMF_Schedule WHERE StageID = @pStageID)
       BEGIN
          UPDATE dbo.DQMF_Schedule
            SET  DatabaseId = @pDatabaseId,
                 TableId = @pTableId,
                 PkgKey = @pPkgKey,
                 IsScheduleActive = @pIsScheduleActive,
                 UpdatedBy = @pUpdatedBy,
                 UpdatedDT = GETDATE()
          WHERE StageID = @pStageID
        END ELSE
        BEGIN
            INSERT dbo.DQMF_Schedule (StageID,
                                    DatabaseId,
                                    TableId,
                                    PkgKey,
                                    IsScheduleActive,
                                    CreatedBy,
                                    CreatedDT,
                                    UpdatedBy,
                                    UpdatedDT)
          SELECT @pStageID,
                 @pDatabaseId ,
                 @pTableId ,
                 @pPkgKey ,
                 @pIsScheduleActive ,
                 @pCreatedBy ,
                 GETDATE(),
                 @pUpdatedBy,
                 GETDATE()

         END
     
        SET @STAGEID = @pStageID
        SET @SCHEDULEID = (SELECT DQMF_ScheduleId 
                             FROM dbo.DQMF_Schedule
                             WHERE StageID = @pStageID)
      
    END
    ELSE
    BEGIN

          INSERT dbo.DQMF_Stage (StageName,
                                 StageDescription,
                                 StageOrder)
          SELECT  @pStageName,
                  @pStageDescription,
                  @pStageOrder
           
          SET @STAGEID = @@IDENTITY

          INSERT dbo.DQMF_Schedule (StageID,
                                    DatabaseId,
                                    TableId,
                                    PkgKey,
                                    IsScheduleActive,
                                    CreatedBy,
                                    CreatedDT,
                                    UpdatedBy,
                                    UpdatedDT)
          SELECT @STAGEID,
                 @pDatabaseId ,
                 @pTableId ,
                 @pPkgKey ,
                 @pIsScheduleActive ,
                 @pCreatedBy ,
                 GETDATE(),
                 @pUpdatedBy,
                 GETDATE()

         SET @SCHEDULEID = @@IDENTITY


    END

         SELECT @STAGEID STAGEID,@SCHEDULEID SCHEDULEID
END



GO
/****** Object:  StoredProcedure [dbo].[SSIS_Config_MergeEnvironments]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*	Replace multiple environment configuration records with one global record
	If no value is supplied as a parameter, the first value found for any environment is used
*/
CREATE PROCEDURE [dbo].[SSIS_Config_MergeEnvironments]
	@ConfigurationFilter	NVARCHAR(100),
	@PackagePath			NVARCHAR(255),
	@NewValue				NVARCHAR(1000) = NULL
AS
	SET NOCOUNT ON
	
	DECLARE @OldConfig TABLE (
		ConfiguredValueType NVARCHAR(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
		ConfiguredValue NVARCHAR(1000) NULL)

	INSERT INTO @OldConfig (
		ConfiguredValueType,
		ConfiguredValue)
	SELECT TOP 1
			ConfiguredValueType,
			-- The parameter value will be used for all environments, if specified
			-- Otherwise the first defined value from an existing record is used
			COALESCE(@NewValue, ConfiguredValue) AS ConfiguredValue
	FROM dbo.SSIS_Config_base
	WHERE ConfigurationFilter = @ConfigurationFilter AND PackagePath = @PackagePath
	ORDER BY EnvironmentEnum

	IF @@ROWCOUNT = 0 BEGIN
		RAISERROR('No records exist for the given filter and path.', 16,1)
	END ELSE BEGIN
		BEGIN TRAN
		BEGIN TRY
			DELETE dbo.SSIS_Config_base
			WHERE ConfigurationFilter = @ConfigurationFilter AND PackagePath = @PackagePath

			INSERT INTO dbo.SSIS_Config_base (
				ConfigurationFilter,
				PackagePath,
				ConfiguredValueType,
				ConfiguredValue,
				EnvironmentEnum) 
			SELECT @ConfigurationFilter, @PackagePath, ConfiguredValueType, ConfiguredValue, 0
			FROM @OldConfig
			
			COMMIT
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK
			EXEC [master].dbo.RethrowError
		END CATCH
	END

GO
/****** Object:  StoredProcedure [dbo].[SSIS_Config_SetValues]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*	Update configuration item values for multiple environments
	Only existing records will be updated, missing records will not be created by specifying their value
	
	The first value argument (@AllValues) will update all environments, unless superceded by an argument for a specific environment
	
	USAGE:
	-- Update value in all environments
	EXEC dbo.SSIS_Config_SetValues 'Filter',N'Path',N'New value' 
	
	-- Update value in a single environment
	-- The @AllValues parameter (3rd param) must be NULL to leave other environments untouched
	EXEC dbo.SSIS_Config_SetValues 'Filter',N'Path',NULL, NULL, NULL, N'New value' 
	EXEC dbo.SSIS_Config_SetValues 'Filter',N'Path',@TestValue = N'New value' -- Same thing (single update) using named parameter
	
	-- Update all environments with a standard value and one exception
	EXEC dbo.SSIS_Config_SetValues 'Filter',N'Path',N'New value', @DevValue = N'New value' 
*/
CREATE PROCEDURE [dbo].[SSIS_Config_SetValues]
	@ConfigurationFilter	NVARCHAR(100),
	@PackagePath			NVARCHAR(255),
	@AllValues				NVARCHAR(1000) = NULL,
	@ProdValue				NVARCHAR(1000) = NULL,
	@DevValue				NVARCHAR(1000) = NULL,
	@TestValue				NVARCHAR(1000) = NULL
AS
	SET NOCOUNT ON
	
	UPDATE b SET ConfiguredValue = e.ConfiguredValue
	FROM dbo.SSIS_Config_base b
	INNER JOIN (
		SELECT CAST(0 AS TINYINT) AS EnvironmentEnum, @AllValues AS ConfiguredValue
		UNION ALL SELECT CAST(1 AS TINYINT) AS EnvironmentEnum, ISNULL(@ProdValue, @AllValues) AS ConfiguredValue
		UNION ALL SELECT CAST(2 AS TINYINT) AS EnvironmentEnum, ISNULL(@DevValue, @AllValues) AS ConfiguredValue
		UNION ALL SELECT CAST(3 AS TINYINT) AS EnvironmentEnum, ISNULL(@TestValue, @AllValues) AS ConfiguredValue ) e
	ON b.ConfigurationFilter = @ConfigurationFilter AND b.PackagePath = @PackagePath AND b.EnvironmentEnum = e.EnvironmentEnum 
		-- This last condition excludes records that don't need to be updated, 
		--  and records where no argument (default or specific) was provided
		AND b.ConfiguredValue <> e.ConfiguredValue

GO
/****** Object:  StoredProcedure [dbo].[SSIS_Config_SplitEnvironments]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*	Create separate configuration records for each environment from existing record(s)
	The global environment record (EnvironmentEnum=0) must exist
	If specific environment records exist, their values are preserved unless overridden by procedure parameters


	EXEC [dbo].[SSIS_Config_SplitEnvironments] 
	@ConfigurationFilter = 'TestMultiServerConfiguration', 
	@PackagePath = '\Package.Variables[User::Greeting].Properties[Value]',
	@ProdValue = 'Production Value',
	@DevValue = 'Development Value',
	@TestValue = 'Test Value'
	
SELECT * FROM dbo.SSIS_Config

*/
CREATE PROCEDURE [dbo].[SSIS_Config_SplitEnvironments]
	@ConfigurationFilter	NVARCHAR(100),
	@PackagePath			NVARCHAR(255),
	@ProdValue				NVARCHAR(1000) = NULL,
	@DevValue				NVARCHAR(1000) = NULL,
	@TestValue				NVARCHAR(1000) = NULL
AS
	SET NOCOUNT ON
	
	DECLARE @NewConfig TABLE (
		ConfiguredValueType NVARCHAR(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
		ConfiguredValue NVARCHAR(1000) NULL,
		EnvironmentEnum TINYINT NOT NULL )

	-- Create the new configuration records for each environment from existing records
	INSERT INTO @NewConfig (
		ConfiguredValueType,
		ConfiguredValue,
		EnvironmentEnum )
	SELECT	a.ConfiguredValueType,
			-- The new value for each environment will be the first of:
			--	The parameter value, if specified
			--	The current value for the specific environment, if the record already exists
			--	The current global value (EnvironmentEnum=0)
			COALESCE(e.ConfiguredValue, b.ConfiguredValue, a.ConfiguredValue) AS ConfiguredValue, 
			e.EnvironmentEnum
	FROM dbo.SSIS_Config_base a
	CROSS JOIN (
		SELECT CAST(1 AS TINYINT) AS EnvironmentEnum, @ProdValue AS ConfiguredValue
		UNION ALL SELECT CAST(2 AS TINYINT) AS EnvironmentEnum, @DevValue AS ConfiguredValue
		UNION ALL SELECT CAST(3 AS TINYINT) AS EnvironmentEnum, @TestValue AS ConfiguredValue ) e
	LEFT JOIN dbo.SSIS_Config_base b ON b.ConfigurationFilter = @ConfigurationFilter AND b.PackagePath = @PackagePath
									AND b.EnvironmentEnum = e.EnvironmentEnum
	WHERE a.ConfigurationFilter = @ConfigurationFilter AND a.PackagePath = @PackagePath AND a.EnvironmentEnum = 0

	IF @@ROWCOUNT = 0 BEGIN
		RAISERROR('No global record exists for the given filter and path.', 16,1)
	END ELSE BEGIN
		BEGIN TRAN
		BEGIN TRY
			-- Delete all existing configuration records for this item
			DELETE dbo.SSIS_Config_base
			WHERE ConfigurationFilter = @ConfigurationFilter AND PackagePath = @PackagePath

			INSERT INTO dbo.SSIS_Config_base (
				ConfigurationFilter,
				PackagePath,
				ConfiguredValueType,
				ConfiguredValue,
				EnvironmentEnum) 
			SELECT @ConfigurationFilter, @PackagePath, ConfiguredValueType, ConfiguredValue, EnvironmentEnum	
			FROM @NewConfig

			COMMIT
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK
			EXEC [master].dbo.RethrowError
		END CATCH
	END


GO
/****** Object:  StoredProcedure [dbo].[UpdAuditDQRating]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[UpdAuditDQRating]
AS
DECLARE @SQLStr as varchar(max), 
@PopTableName varchar(100),
@PopulationCnt bigint,
@BRID int,
@FailureCnt bigint

DECLARE @Population As Table (PopulationTableName varchar(100), PopulationCnt bigint)
DEClARE @BRFailures AS Table (BRID int, FailureCnt bigint)

--GET THE FACT POPULATIONS
WHILE EXISTS (SELECT PopulationFactTableName FROM dbo.AuditQualityRating 
               WHERE   PopulationFactTableName not in (SELECT PopulationTableName FROM @Population))
BEGIN
    SET @PopTableName = (SELECT TOP 1 PopulationFactTableName FROM dbo.AuditQualityRating 
                          WHERE PopulationFactTableName not in (SELECT PopulationTableName FROM @Population))
    SET @SQLStr = 'SELECT ''' + @PopTableName + ''',Count(*) FROM ' + @PopTableName 
    INSERT  @Population exec(@SQLStr)
END
SELECT * from @Population

--GET BR FAILURE COUNTS
WHILE EXISTS (SELECT BRID FROM  dbo.AuditQulaityRatingBizRule
               WHERE BRID not in (SELECT BRID FROM @BRFailures))
BEGIN
     SET @BRID = (SELECT TOP 1 BRID FROM  dbo.AuditQulaityRatingBizRule
               WHERE BRID not in (SELECT BRID FROM @BRFailures))
     SET @PopTableName = (SELECT  distinct PopulationFactTableName 
                           FROM dbo.AuditQualityRating a INNER JOIN dbo.AuditQulaityRatingBizRule b
                                    ON a.QualityRatingID = b.QualityRatingID WHERE BRID = @BRID)
    SET @SQLStr = 'SELECT ' + convert(varchar(10),@BRID) + ',Count(Distinct ETLID) FROM dbo.ETLBizRuleAuditFact aFact'+
                   ' INNER JOIN ' + @PopTableName + ' fact on ETLAUDITID = ETLID  WHERE BRID = ' + convert(varchar(10),@BRID)
print   @SQLStr  
INSERT  @BRFailures exec(@SQLStr)
END
SELECT * FROM @BRFailures a inner join dbo.AuditQulaityRatingBizRule b on a.BRID = b.BRID
where QualityRatingID = 1
--Calulate Rating
;WITH FinalRatings AS(
select RatingScore =  100 - (100*(SUM(BRF.FailureCnt)/(SUM(PopulationCnt * PopulationModifier))))
      ,PopulationRatio = sum(PopulationModifier)
      ,AQR.QualityRatingID
FROM @BRFailures BRF 
     INNER JOIN dbo.AuditQulaityRatingBizRule RBR ON BRF.BRID= RBR.BRID
     INNER JOIN dbo.AuditQualityRating AQR ON  RBR.QualityRatingID   = AQR.QualityRatingID
     INNER JOIN  @Population POP on POP.PopulationTableName = AQR.PopulationFactTableName
GROUP BY AQR.QualityRatingID)
UPDATE dbo.AuditQualityRating
SET RatingScore = FinalRatings.RatingScore,
    PopulationRatio = FinalRatings.PopulationRatio,
    CalculationDate = getdate()
FROM dbo.AuditQualityRating INNER JOIN FinalRatings
     ON AuditQualityRating.QualityRatingID = FinalRatings.QualityRatingID



GO
/****** Object:  StoredProcedure [dbo].[UpdAuditDQRatingByFacility]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- EXECUTE dbo.UpdAuditDQRatingByFacility

CREATE PROCEDURE [dbo].[UpdAuditDQRatingByFacility]
AS

SET NOCOUNT ON

DECLARE @SQLStr as varchar(max), 
@PopTableName varchar(100),
@PopulationCnt bigint,
@QualityRatingID int,
@FailureCnt bigint

DECLARE @Population As Table (PopulationTableName varchar(100),FAcilityID int, PopulationCnt bigint)
DEClARE @BRFailures AS Table (QualityRatingID int,FAcilityID int, FailureCnt bigint)

DECLARE @TblPopulation As Table (PopulationTableName varchar(100))
DEClARE @TblQualityRating AS Table (QualityRatingID int)

--GET THE FACT POPULATIONS
WHILE EXISTS (SELECT PopulationFactTableName FROM dbo.AuditQualityRating 
               WHERE  ISActive = 1 and  PopulationFactTableName not in (SELECT PopulationTableName FROM @TblPopulation))
BEGIN
    SET @PopTableName = (SELECT TOP 1 PopulationFactTableName FROM dbo.AuditQualityRating 
                          WHERE ISActive = 1 and PopulationFactTableName not in (SELECT PopulationTableName FROM @TblPopulation))
    SET @SQLStr = 'SELECT ''' + @PopTableName + ''',FacilityID,Count(*) FROM ' + @PopTableName  + ' group by FacilityID'
    INSERT @Population exec(@SQLStr)
	INSERT @TblPopulation SELECT @PopTableName
END


--GET BR FAILURE COUNTS
WHILE EXISTS (SELECT QualityRatingID FROM  dbo.AuditQualityRating
               WHERE ISActive = 1 And QualityRatingID not in (SELECT QualityRatingID FROM @TblQualityRating))
BEGIN
     SET @QualityRatingID = (SELECT TOP 1 QualityRatingID FROM  dbo.AuditQualityRating
               WHERE ISActive = 1 And QualityRatingID not in (SELECT QualityRatingID FROM @TblQualityRating))
     SET @PopTableName = (SELECT PopulationFactTableName 
                           FROM dbo.AuditQualityRating  WHERE ISActive = 1 And QualityRatingID = @QualityRatingID)
    SET @SQLStr = 'SELECT ' + convert(varchar(10),@QualityRatingID) + ',FacilityID,Count(Distinct ETLID) FROM dbo.ETLBizRuleAuditFact aFact'+
                   ' INNER JOIN ' + @PopTableName + ' fact on ETLAUDITID = ETLID  WHERE BRID in (SELECT BRID FROM dbo.AuditQulaityRatingBizRule WHERE QualityRatingID = ' + convert(varchar(10),@QualityRatingID) + ') group by facilityID'

	INSERT @BRFailures exec(@SQLStr)
	INSERT INTO @TblQualityRating SELECT @QualityRatingID

END


--Calulate Rating

;WITH FinalRatings AS(
select RatingScore =  (100- (100 * sum(convert(float,(BRF.FailureCnt)))/sum(convert(float,(PopulationCnt)))))
      ,BRF.QualityRatingID
FROM @BRFailures BRF 
     INNER JOIN  dbo.AuditQualityRating AQR ON  BRF.QualityRatingID   = AQR.QualityRatingID
     INNER JOIN  @Population POP on POP.PopulationTableName = AQR.PopulationFactTableName and BRF.FacilityID = POP.FacilityID
GROUP BY BRF.QualityRatingID)
UPDATE dbo.AuditQualityRating
SET RatingScore = FinalRatings.RatingScore,
    CalculationDate = getdate()
FROM dbo.AuditQualityRating INNER JOIN FinalRatings
     ON AuditQualityRating.QualityRatingID = FinalRatings.QualityRatingID

Truncate Table dbo.AuditFacilityQualityRating

INSERT dbo.AuditFacilityQualityRating (FacilityID,QualityRatingID,RatingScore)
SELECT BRF.facilityID,BRF.QualityRatingID,100- (100 * convert(float,(BRF.FailureCnt))/convert(float,(PopulationCnt)))
FROM @BRFailures BRF 
     INNER JOIN  dbo.AuditQualityRating AQR ON  BRF.QualityRatingID   = AQR.QualityRatingID
     INNER JOIN  @Population POP on POP.PopulationTableName = AQR.PopulationFactTableName and BRF.FacilityID = POP.FacilityID

--SELECT 2,ISNULL(FacilityID,0),ISNUll(Count(Distinct ETLID),0) FROM dbo.ETLBizRuleAuditFact aFact INNER JOIN DSDW.ED.VisitArea fact on ETLAUDITID = ETLID  WHERE BRID in (SELECT BRID FROM dbo.AuditQulaityRatingBizRule WHERE QualityRatingID = 2) group by facilityID

SET NOCOUNT OFF

GO
/****** Object:  UserDefinedFunction [dbo].[fntCSVList]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
 Author:		            Grant S
 Create date:               8/6/2006
 Description:	            converts CSV list to a table
 Change History:
<Date>                  <Alias>                <Desc>
 =============================================*/

CREATE FUNCTION  [dbo].[fntCSVList]
(
	@pCSVList  varchar(4000)
)
RETURNS @ParsedList TABLE 
(
	ListValue varchar(250)
)
AS
BEGIN
	Set @pCSVList = @pCSVList + ','
while Len(@pCSVList) > 1
begin
insert @ParsedList
select substring(@pCSVList,1,charindex(',',@pCSVList)-1)
set @pCSVList = substring(@pCSVList,charindex(',',@pCSVList) + 1 ,4000)
end
	
	RETURN 
END


GO
/****** Object:  UserDefinedFunction [dbo].[udf_TitleCase]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =============================================
 Author:		            Lien Le
 Create date:               01-Apr-2013
 Description:	            Convert string to mixed case

Change History:
<Date>                  <Alias>                <Desc>
2013.04.01              Lien Le                Initial version  - released in DR2307

 =============================================*/

CREATE FUNCTION [dbo].[udf_TitleCase] (@InputString VARCHAR(4000) )
RETURNS VARCHAR(4000)
AS
BEGIN
DECLARE @Index INT
DECLARE @Char CHAR(1)
DECLARE @OutputString VARCHAR(255)
SET @OutputString = LOWER(@InputString)
SET @Index = 2
SET @OutputString =
STUFF(@OutputString, 1, 1,UPPER(SUBSTRING(@InputString,1,1)))
WHILE @Index <= LEN(@InputString)
BEGIN
SET @Char = SUBSTRING(@InputString, @Index, 1)
IF @Char IN (' ', ';', ':', '!', '?', ',', '.', '_', '-', '/', '&','''','(')
IF @Index + 1 <= LEN(@InputString)
BEGIN
IF @Char != ''''
OR
UPPER(SUBSTRING(@InputString, @Index + 1, 1)) != 'S'
SET @OutputString =
STUFF(@OutputString, @Index + 1, 1,UPPER(SUBSTRING(@InputString, @Index + 1, 1)))
END
SET @Index = @Index + 1
END
RETURN ISNULL(@OutputString,'')
END


GO
/****** Object:  Table [AuditResult].[BRAuditRowCount]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [AuditResult].[BRAuditRowCount](
	[TargetObjectPhysicalName] [varchar](800) NOT NULL,
	[BRID] [int] NOT NULL,
	[ShortNameOfTest] [varchar](800) NULL,
	[PreviousAndNewValueCount] [int] NULL,
	[PreviousValue] [varchar](800) NULL,
	[newValue] [varchar](800) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCMrtAdmitDischProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCMrtAdmitDischProfile](
	[Site] [varchar](3) NULL,
	[FacilityId] [int] NULL,
	[FiscalYear] [int] NULL,
	[AdjustedAdmissionFiscalYear] [int] NULL,
	[AdjustedAdmissionDateId] [int] NULL,
	[AdjustedAdmissionTimeId] [int] NULL,
	[AdjustedDischargeFiscalYear] [int] NULL,
	[AdjustedDischargeDateId] [int] NULL,
	[AdjustedDischargeTimeId] [int] NULL,
	[AdjustedDischargeDispositionId] [int] NULL,
	[LOSDays] [int] NULL,
	[LOSDayId] [int] NULL,
	[AccountTypeID] [int] NULL,
	[AdmissionGenderId] [int] NULL,
	[AdmissionAgeID] [int] NULL,
	[AdmissionFacilityID] [int] NULL,
	[AdmissionNursingUnitId] [int] NULL,
	[AdmissionNursingUnitFinanceMISID] [int] NULL,
	[AdmissionRoom] [varchar](50) NULL,
	[AdmissionBed] [varchar](50) NULL,
	[AdmittingDrId] [int] NULL,
	[ArrivalModeCodeId] [int] NULL,
	[AdmissionSourceCodeId] [int] NULL,
	[AdmissionCategoryCodeId] [int] NULL,
	[AdmissionAttendingDrId] [int] NULL,
	[AdmissionPatientServiceCodeId] [int] NULL,
	[AdmissionAccountTypeId] [int] NULL,
	[AdmissionAccountSubTypeId] [int] NULL,
	[AdmissionPatientTeamId] [int] NULL,
	[AdmissionAlertCodeId] [int] NULL,
	[AdmissionInfectiousDiseaseCodeId] [int] NULL,
	[AdmissionReadmissionRiskFlagID] [int] NULL,
	[DischargeGenderId] [int] NULL,
	[DischargeAgeId] [int] NULL,
	[DischargeFacilityID] [int] NULL,
	[DischargeNursingUnitId] [int] NULL,
	[DischargeRoom] [varchar](50) NULL,
	[DischargeBed] [varchar](50) NULL,
	[DischargeDispositionCodeId] [int] NULL,
	[DischargeAttendingDrId] [int] NULL,
	[DischargePatientServiceCodeId] [int] NULL,
	[DischargeAccountTypeId] [int] NULL,
	[DischargeAccountSubTypeId] [int] NULL,
	[DischargePatientTeamId] [int] NULL,
	[DischargeAlertCodeId] [int] NULL,
	[DischargeInfectiousDiseaseCodeId] [int] NULL,
	[DischargeReadmissionRiskFlagID] [int] NULL,
	[IsTrauma] [bit] NULL,
	[DischargePayor1ID] [int] NULL,
	[DischargePayor2ID] [int] NULL,
	[DischargePayor3ID] [int] NULL,
	[AdjustedGenderId] [int] NULL,
	[AdjustedBirthDateId] [int] NULL,
	[FamilyDoctorName] [varchar](100) NULL,
	[FamilyDoctorCode] [varchar](50) NULL,
	[IsHomeless] [bit] NULL,
	[IsHomeless_PHC] [bit] NULL,
	[AdjustedPostalCodeID] [int] NULL,
	[LHAID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCMrtCensusProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCMrtCensusProfile](
	[Site] [varchar](3) NULL,
	[FacilityId] [int] NULL,
	[FiscalYear] [int] NULL,
	[CensusDateID] [int] NULL,
	[IsSameDay] [bit] NULL,
	[IsOutsideRelevantRange] [bit] NULL,
	[AdmitToCensusDays] [int] NULL,
	[AdmitToCensusDayID] [int] NULL,
	[NursingUnitID] [int] NULL,
	[Bed] [varchar](50) NULL,
	[Room] [varchar](50) NULL,
	[AttendDoctorID] [int] NULL,
	[PatientServiceCodeID] [int] NULL,
	[IsOutpatient] [bit] NULL,
	[AccountTypeID] [int] NULL,
	[AcctSubTypeID] [int] NULL,
	[PatientTeamID] [int] NULL,
	[AlertCodeID] [int] NULL,
	[InfectiousDiseaseCodeID] [int] NULL,
	[ReadmissionRiskFlagID] [int] NULL,
	[IsTrauma] [bit] NULL,
	[AdjustedGenderID] [int] NULL,
	[AgeID] [int] NULL,
	[LHAID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCMrtCombineActivityFlatProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCMrtCombineActivityFlatProfile](
	[Site] [varchar](3) NULL,
	[FromFacilityID] [int] NULL,
	[FacilityId] [int] NULL,
	[FiscalYear] [int] NULL,
	[ActivityDateID] [int] NULL,
	[ActivityTimeID] [int] NULL,
	[IsOutsideRelevantRange] [bit] NULL,
	[IsFacilityChange] [bit] NULL,
	[IsNursingUnitChange] [bit] NULL,
	[FromNursingUnitID] [int] NULL,
	[ToNursingUnitID] [int] NULL,
	[IsRoomChange] [bit] NULL,
	[FromRoom] [varchar](50) NULL,
	[ToRoom] [varchar](50) NULL,
	[IsBedChange] [bit] NULL,
	[FromBed] [varchar](50) NULL,
	[ToBed] [varchar](50) NULL,
	[IsAccountTypeChange] [bit] NULL,
	[FromAccountTypeID] [int] NULL,
	[ToAccountTypeID] [int] NULL,
	[IsAccountSubTypeChange] [bit] NULL,
	[FromAccountSubTypeID] [int] NULL,
	[ToAccountSubTypeID] [int] NULL,
	[IsPatientServiceChange] [bit] NULL,
	[FromPatientServiceCodeID] [int] NULL,
	[ToPatientServiceCodeID] [int] NULL,
	[IsAttendingDrChange] [bit] NULL,
	[FromAttendingDrID] [int] NULL,
	[ToAttendingDrID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCMrtTransferProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCMrtTransferProfile](
	[Site] [varchar](3) NULL,
	[FromFacilityID] [int] NULL,
	[FacilityId] [int] NULL,
	[FiscalYear] [int] NULL,
	[TransferDateID] [int] NULL,
	[TransferTimeID] [int] NULL,
	[TransferCreateDateID] [int] NULL,
	[TransferCreateTimeID] [int] NULL,
	[IsSameDay] [bit] NULL,
	[IsOutsideRelevantRange] [bit] NULL,
	[IsLocationTransfer] [bit] NULL,
	[FromNursingUnitID] [int] NULL,
	[ToNursingUnitID] [int] NULL,
	[IsBedTransfer] [bit] NULL,
	[FromRoom] [varchar](50) NULL,
	[ToRoom] [varchar](50) NULL,
	[FromBed] [varchar](50) NULL,
	[ToBed] [varchar](50) NULL,
	[FromPatientServiceCodeID] [int] NULL,
	[ToPatientServiceCodeID] [int] NULL,
	[AttendDoctorID] [int] NULL,
	[IsOutpatient] [bit] NULL,
	[AccountTypeID] [int] NULL,
	[AcctSubTypeID] [int] NULL,
	[PatientTeamID] [int] NULL,
	[AlertCodeId] [int] NULL,
	[InfectiousDiseaseCodeID] [int] NULL,
	[ReadmissionRiskFlagID] [int] NULL,
	[AdjustedGenderID] [int] NULL,
	[AgeID] [int] NULL,
	[LHAID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCSDAMckStarAdmitProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCSDAMckStarAdmitProfile](
	[AdmitDate] [varchar](50) NULL,
	[AdmitCategory] [varchar](5) NULL,
	[PatientType] [varchar](5) NULL,
	[PatientTypeIndicator] [varchar](50) NULL,
	[NursingUnit] [varchar](50) NULL,
	[AdmitDrServ] [varchar](60) NULL,
	[AttendDrServ] [varchar](60) NULL,
	[PatientServ] [varchar](50) NULL,
	[Gender] [char](1) NULL,
	[StrAge] [varchar](50) NULL,
	[FromFacility] [varchar](50) NULL,
	[Facility] [varchar](50) NULL,
	[ALCFlag] [varchar](50) NULL,
	[ChiefComplaint] [varchar](255) NULL,
	[IFDCode] [varchar](50) NULL,
	[AdmitSource] [varchar](50) NULL,
	[BirthDate] [varchar](255) NULL,
	[NursingUnitDesc] [varchar](50) NULL,
	[IsManualUpdate] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCSDAMckStarCensusProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCSDAMckStarCensusProfile](
	[CensusDate] [varchar](50) NULL,
	[NursingUnit] [varchar](255) NULL,
	[Gender] [varchar](255) NULL,
	[Age] [varchar](255) NULL,
	[PatientType] [varchar](255) NULL,
	[ServiceCode] [varchar](255) NULL,
	[AttendDrServ] [varchar](255) NULL,
	[AttendDrServDesc] [varchar](255) NULL,
	[AdmitCategory] [varchar](255) NULL,
	[ChiefComplaint] [varchar](255) NULL,
	[Facility] [varchar](255) NULL,
	[AdmitSource] [varchar](255) NULL,
	[MRSAFlag] [varchar](255) NULL,
	[CareType] [varchar](3) NULL,
	[NursingUnitDesc] [varchar](50) NULL,
	[IsManualUpdate] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCSDAMckStarDischProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCSDAMckStarDischProfile](
	[NursingUnit] [varchar](30) NULL,
	[PatientType] [varchar](50) NULL,
	[PatientTypeIndicator] [varchar](5) NULL,
	[PatientServ] [varchar](50) NULL,
	[Gender] [char](1) NULL,
	[StrAge] [varchar](3) NULL,
	[AttendDrServ] [varchar](100) NULL,
	[AdmitCategory] [varchar](5) NULL,
	[AdmitDiagnosis] [varchar](255) NULL,
	[DischargeDate] [varchar](50) NULL,
	[DischargeStatus] [varchar](50) NULL,
	[Facility] [varchar](5) NULL,
	[MRSAFlag] [varchar](50) NULL,
	[HCProvince] [varchar](50) NULL,
	[NursingUnitDesc] [varchar](50) NULL,
	[IsManualUpdate] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ADTCSDAMckStarTransProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ADTCSDAMckStarTransProfile](
	[Gender] [varchar](1) NULL,
	[Age] [varchar](3) NULL,
	[PatientType] [varchar](3) NULL,
	[AdmitType] [varchar](1) NULL,
	[StationCodeTransferFrom] [varchar](5) NULL,
	[ClinicSiteFrom] [varchar](75) NULL,
	[ServiceCodeFrom] [varchar](50) NULL,
	[AttendDrServ] [varchar](60) NULL,
	[StationCodeTransferTo] [varchar](5) NULL,
	[ClinicSiteTo] [varchar](75) NULL,
	[ServiceCodeTo] [varchar](50) NULL,
	[TransferDate] [varchar](10) NULL,
	[AdmitDiagnosis] [varchar](70) NULL,
	[MRSAFlag] [varchar](1) NULL,
	[StationCodeTransferFromDesc] [varchar](50) NULL,
	[StationCodeTransferToDesc] [varchar](50) NULL,
	[IsManualUpdate] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ColumnNullRatios]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ColumnNullRatios](
	[ColumnNullRatiosID] [int] IDENTITY(1,1) NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[NullCount] [nvarchar](max) NULL,
	[ProfileSummaryID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ColumnNullRatiosHistoric]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ColumnNullRatiosHistoric](
	[ColumnNullRatiosID] [int] NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[NullCount] [nvarchar](max) NULL,
	[ProfileSummaryID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ColumnNullRatiosold]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ColumnNullRatiosold](
	[ColumnNullRatiosID] [int] IDENTITY(1,1) NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[NullCount] [nvarchar](max) NULL,
	[ProfileSummaryID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ColumnNullRatiosID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ColumnStatistics]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ColumnStatistics](
	[ColumnStatisticsID] [int] IDENTITY(1,1) NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[MinValue] [nvarchar](255) NULL,
	[MaxValue] [nvarchar](255) NULL,
	[Mean] [nvarchar](255) NULL,
	[StdDev] [nvarchar](255) NULL,
	[ProfileSummaryID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ColumnStatisticsHistoric]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ColumnStatisticsHistoric](
	[ColumnStatisticsID] [int] NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[MinValue] [nvarchar](255) NULL,
	[MaxValue] [nvarchar](255) NULL,
	[Mean] [nvarchar](255) NULL,
	[StdDev] [nvarchar](255) NULL,
	[ProfileSummaryID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ColumnStatisticsold]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ColumnStatisticsold](
	[ColumnStatisticsID] [int] IDENTITY(1,1) NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[MinValue] [nvarchar](255) NULL,
	[MaxValue] [nvarchar](255) NULL,
	[Mean] [nvarchar](255) NULL,
	[StdDev] [nvarchar](255) NULL,
	[ProfileSummaryID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ColumnStatisticsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[CommServiceFactProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[CommServiceFactProfile](
	[DateAcceptedForServiceID] [int] NULL,
	[CaseOpenedDateID] [int] NOT NULL,
	[ServiceStartDateID] [int] NOT NULL,
	[ServiceEndDateID] [int] NULL,
	[BedRefusalDateID] [int] NULL,
	[TempRateReductionStartDateID] [int] NULL,
	[TempRateReductionEndDateID] [int] NULL,
	[TempRateReductionEffectiveDateID] [int] NULL,
	[ServiceTypeID] [int] NOT NULL,
	[LocalReportingOfficeID] [int] NOT NULL,
	[ServiceDeliverySettingID] [int] NULL,
	[ReferralSourceLookupID] [int] NULL,
	[ProviderID] [int] NULL,
	[IADLDifficultyScaleID] [int] NULL,
	[CognitivePerformanceScaleID] [int] NULL,
	[ADLSelfPerformanceScaleID] [int] NULL,
	[MAPLeScoreID] [int] NULL,
	[ClientGroupID] [int] NOT NULL,
	[ServiceProviderCategoryCodeID] [int] NULL,
	[ReasonEndingServiceCodeID] [int] NULL,
	[ResidentialCareDailyRateID] [int] NULL,
	[DischargeDispositionCodeID] [int] NULL,
	[ADLLongFormScale] [tinyint] NULL,
	[IADLInvolvementScale] [tinyint] NULL,
	[IsTempRateReduction] [bit] NOT NULL,
	[TempRateReductionAmount] [decimal](9, 2) NULL,
	[AssistedLivingMonthlyCharge] [decimal](9, 2) NULL,
	[HomeSupportClientContribution] [decimal](9, 2) NULL,
	[IsCSILClient] [bit] NOT NULL,
	[InterraiAssessmentID] [int] NULL,
	[SourceSystemClientID] [int] NULL,
	[SourceSystemServiceKey] [varchar](10) NOT NULL,
	[SourceCreatedDate] [datetime] NOT NULL,
	[ReferralReasonID] [int] NOT NULL,
	[ReferralPriorityID] [int] NOT NULL,
	[InterventionID ] [int] NULL,
	[HomeSupportClusterID] [int] NULL,
	[CHESSScaleID] [int] NULL,
	[FiscalYearLong] [int] NULL,
	[FacilityID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[CommServiceVisitProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[CommServiceVisitProfile](
	[VisitDateID] [int] NOT NULL,
	[VisitTypeID] [int] NOT NULL,
	[ServiceHours] [decimal](9, 2) NULL,
	[ServiceDays] [decimal](9, 2) NULL,
	[SourceSystemClientID] [int] NOT NULL,
	[SourceSystemServiceKey] [varchar](10) NOT NULL,
	[SourceSystemActualKey] [varchar](10) NOT NULL,
	[SourceCreatedDate] [int] NOT NULL,
	[FiscalYear] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[DADMrtAbstractProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[DADMrtAbstractProfile](
	[ChartNumber] [varchar](50) NULL,
	[AcctNum] [varchar](50) NULL,
	[PHN] [varchar](50) NULL,
	[VisitHCN] [varchar](12) NULL,
	[BatchYear] [smallint] NULL,
	[BatchPeriod] [smallint] NULL,
	[InstitutionNumberID] [int] NULL,
	[FacilityID] [int] NOT NULL,
	[AdmitDateID] [int] NULL,
	[AdmittimeID] [int] NULL,
	[DischargeDateID] [int] NULL,
	[DischargeTimeID] [int] NULL,
	[LOSID] [int] NULL,
	[LOSDaysID] [int] NULL,
	[LOS] [int] NULL,
	[AcuteDays] [int] NULL,
	[ALCDays] [int] NULL,
	[AccountTypeID] [int] NULL,
	[LGHPatientTypeID] [int] NULL,
	[ProvinceIssuingHCN] [varchar](2) NULL,
	[VisitPayorID] [int] NULL,
	[BirthDateID] [int] NULL,
	[PatientAge] [varchar](255) NULL,
	[GenderID] [int] NULL,
	[PostalCode] [varchar](20) NULL,
	[PostalCodeNA] [varchar](20) NULL,
	[InstitutionToID] [int] NULL,
	[InstToTypeID] [int] NULL,
	[LGHInstitutionToID] [int] NULL,
	[InstitutionFromID] [int] NULL,
	[LGHInstitutionFromID] [int] NULL,
	[InstFromTypeID] [int] NULL,
	[DischargeDispositionID] [int] NULL,
	[AdmissionCategoryID] [int] NULL,
	[EntryID] [int] NULL,
	[ReadmissionCategoryID] [int] NULL,
	[ArrivalModeID] [int] NULL,
	[MainPtServiceID] [int] NULL,
	[VGHMainPtSubSvcID] [int] NULL,
	[LeftERDateID] [int] NULL,
	[LeftERTimeID] [int] NULL,
	[ERWaitElapsedTimeID] [int] NULL,
	[UnknownERDisTime] [varchar](1) NULL,
	[AdmitNursingUnitID] [int] NULL,
	[DischNursingUnitID] [int] NULL,
	[InvoluntaryAdmit] [varchar](1) NULL,
	[DeathInOR] [varchar](1) NULL,
	[Autopsy] [varchar](1) NULL,
	[BirthorAdmWeight] [int] NULL,
	[Gestationinweeks] [int] NULL,
	[MomBabyRec1] [varchar](10) NULL,
	[MomBabyRec2] [varchar](10) NULL,
	[MomBabyRec3] [varchar](10) NULL,
	[MomBabyRec4] [varchar](10) NULL,
	[MomBabyRec5] [varchar](10) NULL,
	[CMGPlusID] [int] NULL,
	[MCCPlusID] [int] NULL,
	[ComorbidityLevelID] [int] NULL,
	[AgeCategoryID] [int] NULL,
	[ELOS] [float] NULL,
	[FlaggedIntervCount] [int] NULL,
	[IntervEventCount] [int] NULL,
	[InterventOOHCount] [int] NULL,
	[InptRIWAtypID] [int] NULL,
	[InpatientRILevelID] [int] NULL,
	[CaseWeight] [float] NULL,
	[ReimbAcuLOS] [int] NULL,
	[Trim] [int] NULL,
	[TypicalRIW] [float] NULL,
	[VendorAgeCat] [varchar](5) NULL,
	[CMGStatusID] [int] NULL,
	[OrganRetrievalPt] [varchar](1) NULL,
	[ProjectNumber] [int] NULL,
	[Liver] [int] NULL,
	[Heart] [int] NULL,
	[Pancreas] [int] NULL,
	[PancIsletCells] [int] NULL,
	[HeartValves] [int] NULL,
	[Bowel] [int] NULL,
	[Cornea] [int] NULL,
	[Skin] [int] NULL,
	[Bone] [int] NULL,
	[Other] [int] NULL,
	[PrivateClinicProviderId] [int] NULL,
	[EDRegistrationDateID] [int] NULL,
	[EDRegistrationTimeID] [int] NULL,
	[MedReconciliationID] [int] NULL,
	[MajorAmbClusterID] [int] NULL,
	[CompAmbClassSysID] [int] NULL,
	[AmbltryCostWeight] [float] NULL,
	[VendMITTotalCount] [int] NULL,
	[GlasgowComaScale] [float] NULL,
	[TrsfrPtServ1ID] [int] NULL,
	[TrsfrStartDate1ID] [int] NULL,
	[TrsfrStartTime1ID] [int] NULL,
	[TrsfrEndDate1ID] [int] NULL,
	[TrsfrEndTime1ID] [int] NULL,
	[TrsfrServiceDays1] [int] NULL,
	[TrsfrPtServ2ID] [int] NULL,
	[TrsfrStartDate2ID] [int] NULL,
	[TrsfrStartTime2ID] [int] NULL,
	[TrsfrEndDate2ID] [int] NULL,
	[TrsfrEndTime2ID] [int] NULL,
	[TrsfrServiceDays2] [int] NULL,
	[TrsfrPtServ3ID] [int] NULL,
	[TrsfrStartDate3ID] [int] NULL,
	[TrsfrStartTime3ID] [int] NULL,
	[TrsfrEndDate3ID] [int] NULL,
	[TrsfrEndTime3ID] [int] NULL,
	[TrsfrServiceDays3] [int] NULL,
	[FactType] [varchar](1) NULL,
	[MACID] [int] NULL,
	[DischGFSNursingUnit] [varchar](255) NULL,
	[AdmitGFSNursingUnit] [varchar](255) NULL,
	[GFSPatientServiceCodeID] [varchar](255) NULL,
	[GFSAdmitCategory] [int] NULL,
	[GFSDischCategory] [int] NULL,
	[GFSAdmitHealthUnit] [varchar](255) NULL,
	[GFSDischHealthUnit] [varchar](255) NULL,
	[MHFollowupForm] [int] NULL,
	[MHFollowupDate] [varchar](255) NULL,
	[MethodologyYear] [varchar](50) NULL,
	[MethodologyVersion] [varchar](50) NULL,
	[BatchNumber] [varchar](50) NULL,
	[AbstractNumber] [varchar](50) NULL,
	[DADTransactionID] [varchar](50) NULL,
	[FICardioversionFlag] [varchar](50) NULL,
	[FICellSaverFlag] [varchar](50) NULL,
	[FIChemotherapyFlag] [varchar](50) NULL,
	[FIDialysisFlag] [varchar](50) NULL,
	[FIHeartResuscitationFlag] [varchar](50) NULL,
	[FIInvasiveVentilationGE96Flag] [varchar](50) NULL,
	[FIInvasiveVentilationLT96Flag] [varchar](50) NULL,
	[FIFeedingTubeFlag] [varchar](50) NULL,
	[FIParacentesisFlag] [varchar](50) NULL,
	[FIParenteralNutritionFlag] [varchar](50) NULL,
	[FIPleurocentesisFlag] [varchar](50) NULL,
	[FIRadiotherapyFlag] [varchar](50) NULL,
	[FITracheostomyFlag] [varchar](50) NULL,
	[FIVascularAccessDeviceFlag] [varchar](50) NULL,
	[FIBiopsyFlag] [varchar](50) NULL,
	[FIEndoscopyFlag] [varchar](50) NULL,
	[AdmitLocationID] [int] NULL,
	[DischargeLocationID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[DADMrtAcuteProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[DADMrtAcuteProfile](
	[FiscalYear] [int] NULL,
	[FiscalYearLong] [char](5) NULL,
	[BatchYear] [smallint] NOT NULL,
	[BatchPeriod] [smallint] NOT NULL,
	[AcuteDays] [int] NULL,
	[ALCDays] [int] NULL,
	[RIW] [float] NULL,
	[DPG_RIW] [float] NULL,
	[ELOS] [numeric](9, 1) NULL,
	[IsDeathInOR] [bit] NULL,
	[IsNewborn] [int] NOT NULL,
	[IsOncology] [bit] NULL,
	[IsTrauma] [bit] NULL,
	[IsUnplandRetToOR] [bit] NULL,
	[IsUnplandRetToAcute] [bit] NULL,
	[LOS] [int] NULL,
	[TrimLOS] [int] NULL,
	[LosMinusELOS] [numeric](9, 1) NULL,
	[LOSGrouping] [varchar](50) NULL,
	[CMGPlus_ComorbidityLevel] [float] NULL,
	[CMGPlus_FlaggedInterventionCount] [float] NULL,
	[CMGPlus_InterventionEventCount] [float] NULL,
	[CMGPlus_InterventionOOHCount] [float] NULL,
	[AdmissionDate] [int] NULL,
	[AdmissionTime] [char](5) NULL,
	[AdmissionNurseUnitCode] [varchar](100) NULL,
	[AdmissionNurseUnitDesc] [varchar](255) NULL,
	[admissionCategoryCode] [varchar](2) NULL,
	[AdmissionCategoryDescription] [varchar](100) NULL,
	[AdmitDrServ] [varchar](255) NULL,
	[AdmitPtProgSrv] [varchar](255) NULL,
	[AnesthesiaCode] [varchar](50) NULL,
	[AnesthesiaDesc] [varchar](255) NULL,
	[CMGCode] [char](3) NULL,
	[CMGDesc] [varchar](4000) NULL,
	[CMGGradeAssignment] [varchar](50) NULL,
	[CMGSubGradeAssignment] [varchar](50) NULL,
	[CMGPlusRILCode] [int] NULL,
	[CMGPlusRILDescription] [varchar](255) NULL,
	[DischargeDate] [datetime] NULL,
	[DischargeTime] [char](5) NULL,
	[DischargeDispositionCode] [char](2) NULL,
	[DischargeDispositionDescription] [varchar](255) NULL,
	[DrCode] [varchar](50) NULL,
	[DrName] [varchar](50) NULL,
	[DrService] [varchar](255) NULL,
	[DrServiceGroup] [varchar](50) NULL,
	[EntryCode] [varchar](50) NULL,
	[EntryCodeDesc] [varchar](50) NULL,
	[Gender] [varchar](25) NULL,
	[InstitutionName] [varchar](100) NULL,
	[InstitutionNum] [char](5) NULL,
	[ToInstitutionName] [varchar](100) NULL,
	[ToInstitutionNum] [char](5) NULL,
	[FromInstitutionName] [varchar](100) NULL,
	[FromInstitutionNum] [char](5) NULL,
	[MainPtServ] [varchar](255) NULL,
	[MainPtServDesc] [varchar](255) NULL,
	[SubServiceCode] [varchar](10) NULL,
	[SubServiceDesc] [varchar](50) NULL,
	[MCC] [varchar](2) NULL,
	[MCCDesc] [varchar](max) NULL,
	[NurseUnitCode] [varchar](100) NULL,
	[NurseUnitDesc] [varchar](255) NULL,
	[ProxyTertiaryCode] [varchar](1) NULL,
	[ProxyTertiaryDesc] [varchar](4000) NULL,
	[ReAdmissionCode] [varchar](10) NULL,
	[ReAdmissionDesc] [varchar](75) NULL,
	[StatusTypeCode] [varchar](255) NULL,
	[StatusTypeDesc] [varchar](255) NULL,
	[StatusTypeTypical] [varchar](50) NULL,
	[TrsfrPtServ1] [varchar](255) NULL,
	[TrsfrPtServ1Desc] [varchar](255) NULL,
	[TrsfrPtServ2] [varchar](255) NULL,
	[TrsfrPtServ2Desc] [varchar](255) NULL,
	[TrsfrPtServ3] [varchar](255) NULL,
	[TrsfrPtServ3Desc] [varchar](255) NULL,
	[LHAName] [varchar](100) NULL,
	[HSDAName] [varchar](100) NULL,
	[HealthAuthorityName] [varchar](50) NULL,
	[Age] [smallint] NULL,
	[CMGPlusAgeGroup] [varchar](20) NULL,
	[Px1Code] [varchar](20) NULL,
	[Px1Desc] [varchar](4000) NULL,
	[PXDate1] [int] NULL,
	[Px2Code] [varchar](20) NULL,
	[Px2Desc] [varchar](4000) NULL,
	[PXDate2] [int] NULL,
	[Px3Code] [varchar](20) NULL,
	[Px3Desc] [varchar](4000) NULL,
	[PXDate3] [int] NULL,
	[Px4Code] [varchar](20) NULL,
	[Px4Desc] [varchar](4000) NULL,
	[PXDate4] [int] NULL,
	[Px5Code] [varchar](20) NULL,
	[Px5Desc] [varchar](4000) NULL,
	[PXDate5] [int] NULL,
	[Px6Code] [varchar](20) NULL,
	[Px6Desc] [varchar](4000) NULL,
	[PXDate6] [int] NULL,
	[Px7Code] [varchar](20) NULL,
	[Px7Desc] [varchar](4000) NULL,
	[PXDate7] [int] NULL,
	[Px8Code] [varchar](20) NULL,
	[Px8Desc] [varchar](4000) NULL,
	[PXDate8] [int] NULL,
	[Px9Code] [varchar](20) NULL,
	[Px9Desc] [varchar](4000) NULL,
	[PXDate9] [int] NULL,
	[Px10Code] [varchar](20) NULL,
	[Px10Desc] [varchar](4000) NULL,
	[PXDate10] [int] NULL,
	[Px11Code] [varchar](20) NULL,
	[Px11Desc] [varchar](4000) NULL,
	[PXDate11] [int] NULL,
	[Px12Code] [varchar](20) NULL,
	[Px12Desc] [varchar](4000) NULL,
	[PXDate12] [int] NULL,
	[Px13Code] [varchar](20) NULL,
	[Px13Desc] [varchar](4000) NULL,
	[PXDate13] [int] NULL,
	[Px14Code] [varchar](20) NULL,
	[Px14Desc] [varchar](4000) NULL,
	[PXDate14] [int] NULL,
	[Px15Code] [varchar](20) NULL,
	[Px15Desc] [varchar](4000) NULL,
	[PXDate15] [int] NULL,
	[Px16Code] [varchar](20) NULL,
	[Px16Desc] [varchar](4000) NULL,
	[PXDate16] [int] NULL,
	[Px17Code] [varchar](20) NULL,
	[Px17Desc] [varchar](4000) NULL,
	[PXDate17] [int] NULL,
	[Px18Code] [varchar](20) NULL,
	[Px18Desc] [varchar](4000) NULL,
	[PXDate18] [int] NULL,
	[Px19Code] [varchar](20) NULL,
	[Px19Desc] [varchar](4000) NULL,
	[PXDate19] [int] NULL,
	[Px20Code] [varchar](20) NULL,
	[Px20Desc] [varchar](4000) NULL,
	[PXDate20] [int] NULL,
	[Dx1Code] [varchar](20) NULL,
	[Dx1Desc] [varchar](4000) NULL,
	[DXType1] [varchar](356) NULL,
	[Dx2Code] [varchar](20) NULL,
	[Dx2Desc] [varchar](4000) NULL,
	[DXType2] [varchar](356) NULL,
	[Dx3Code] [varchar](20) NULL,
	[Dx3Desc] [varchar](4000) NULL,
	[DXType3] [varchar](356) NULL,
	[Dx4Code] [varchar](20) NULL,
	[Dx4Desc] [varchar](4000) NULL,
	[DXType4] [varchar](356) NULL,
	[Dx5Code] [varchar](20) NULL,
	[Dx5Desc] [varchar](4000) NULL,
	[DXType5] [varchar](356) NULL,
	[Dx6Code] [varchar](20) NULL,
	[Dx6Desc] [varchar](4000) NULL,
	[DXType6] [varchar](356) NULL,
	[Dx7Code] [varchar](20) NULL,
	[Dx7Desc] [varchar](4000) NULL,
	[DXType7] [varchar](356) NULL,
	[Dx8Code] [varchar](20) NULL,
	[Dx8Desc] [varchar](4000) NULL,
	[DXType8] [varchar](356) NULL,
	[Dx9Code] [varchar](20) NULL,
	[Dx9Desc] [varchar](4000) NULL,
	[DXType9] [varchar](356) NULL,
	[Dx10Code] [varchar](20) NULL,
	[Dx10Desc] [varchar](4000) NULL,
	[DXType10] [varchar](356) NULL,
	[Dx11Code] [varchar](20) NULL,
	[Dx11Desc] [varchar](4000) NULL,
	[DXType11] [varchar](356) NULL,
	[Dx12Code] [varchar](20) NULL,
	[Dx12Desc] [varchar](4000) NULL,
	[DXType12] [varchar](356) NULL,
	[Dx13Code] [varchar](20) NULL,
	[Dx13Desc] [varchar](4000) NULL,
	[DXType13] [varchar](356) NULL,
	[Dx14Code] [varchar](20) NULL,
	[Dx14Desc] [varchar](4000) NULL,
	[DXType14] [varchar](356) NULL,
	[Dx15Code] [varchar](20) NULL,
	[Dx15Desc] [varchar](4000) NULL,
	[DXType15] [varchar](356) NULL,
	[Dx16Code] [varchar](20) NULL,
	[Dx16Desc] [varchar](4000) NULL,
	[DXType16] [varchar](356) NULL,
	[Dx17Code] [varchar](20) NULL,
	[Dx17Desc] [varchar](4000) NULL,
	[DXType17] [varchar](356) NULL,
	[Dx18Code] [varchar](20) NULL,
	[Dx18Desc] [varchar](4000) NULL,
	[DXType18] [varchar](356) NULL,
	[Dx19Code] [varchar](20) NULL,
	[Dx19Desc] [varchar](4000) NULL,
	[DXType19] [varchar](356) NULL,
	[Dx20Code] [varchar](20) NULL,
	[Dx20Desc] [varchar](4000) NULL,
	[DXType20] [varchar](356) NULL,
	[Dx21Code] [varchar](20) NULL,
	[Dx21Desc] [varchar](4000) NULL,
	[DXType21] [varchar](356) NULL,
	[Dx22Code] [varchar](20) NULL,
	[Dx22Desc] [varchar](4000) NULL,
	[DXType22] [varchar](356) NULL,
	[Dx23Code] [varchar](20) NULL,
	[Dx23Desc] [varchar](4000) NULL,
	[DXType23] [varchar](356) NULL,
	[Dx24Code] [varchar](20) NULL,
	[Dx24Desc] [varchar](4000) NULL,
	[DXType24] [varchar](356) NULL,
	[Dx25Code] [varchar](20) NULL,
	[Dx25Desc] [varchar](4000) NULL,
	[DXType25] [varchar](356) NULL,
	[SCU1Code] [varchar](50) NULL,
	[SCUDays1] [float] NULL,
	[SCUHours1] [float] NULL,
	[SCUAdmitTime1] [datetime] NULL,
	[SCUDischTime1] [datetime] NULL,
	[IsSCUDeath1] [bit] NULL,
	[SCU2Code] [varchar](50) NULL,
	[SCUDays2] [float] NULL,
	[SCUHours2] [float] NULL,
	[SCUAdmitTime2] [datetime] NULL,
	[SCUDischTime2] [datetime] NULL,
	[IsSCUDeath2] [bit] NULL,
	[SCU3Code] [varchar](50) NULL,
	[SCUDays3] [float] NULL,
	[SCUHours3] [float] NULL,
	[SCUAdmitTime3] [datetime] NULL,
	[SCUDischTime3] [datetime] NULL,
	[IsSCUDeath3] [bit] NULL,
	[SCU4Code] [varchar](50) NULL,
	[SCUDays4] [float] NULL,
	[SCUHours4] [float] NULL,
	[SCUAdmitTime4] [datetime] NULL,
	[SCUDischTime4] [datetime] NULL,
	[IsSCUDeath4] [bit] NULL,
	[SCU5Code] [varchar](50) NULL,
	[SCUDays5] [float] NULL,
	[SCUHours5] [float] NULL,
	[SCUAdmitTime5] [datetime] NULL,
	[SCUDischTime5] [datetime] NULL,
	[IsSCUDeath5] [bit] NULL,
	[SCU6Code] [varchar](50) NULL,
	[SCUDays6] [float] NULL,
	[SCUHours6] [float] NULL,
	[SCUAdmitTime6] [datetime] NULL,
	[SCUDischTime6] [datetime] NULL,
	[IsSCUDeath6] [bit] NULL,
	[MRCareProgramCode] [varchar](255) NULL,
	[MRCareTeamCode] [varchar](255) NULL,
	[MedReconciliation] [varchar](50) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[DADMrtDayCareProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[DADMrtDayCareProfile](
	[FiscalYear] [int] NULL,
	[FiscalYearLong] [char](5) NULL,
	[BatchYear] [smallint] NOT NULL,
	[BatchPeriod] [smallint] NOT NULL,
	[RIW] [float] NULL,
	[DPG_RIW] [float] NULL,
	[LOS] [int] NULL,
	[LOSHours] [int] NULL,
	[IsDeathInOR] [bit] NOT NULL,
	[AdmissionDate] [int] NULL,
	[AdmissionTime] [char](5) NULL,
	[AdmissionNurseUnitCode] [varchar](100) NULL,
	[AdmissionNurseUnitDesc] [varchar](255) NULL,
	[admissionCategoryCode] [varchar](2) NULL,
	[AdmissionCategoryDescription] [varchar](100) NULL,
	[AdmitDrServ] [varchar](255) NULL,
	[AnesthesiaCode] [varchar](50) NULL,
	[AnesthesiaDesc] [varchar](255) NULL,
	[DPGCode] [varchar](255) NULL,
	[DPGDesc] [varchar](255) NULL,
	[DischargeDate] [datetime] NULL,
	[DischargeTime] [char](5) NULL,
	[DischargeDispositionCode] [char](2) NULL,
	[DischargeDispositionDescription] [varchar](255) NULL,
	[DrCode] [varchar](50) NULL,
	[DrName] [varchar](50) NULL,
	[DrService] [varchar](255) NULL,
	[DrServiceGroup] [varchar](50) NULL,
	[EntryCode] [varchar](50) NULL,
	[EntryCodeDesc] [varchar](50) NULL,
	[Gender] [varchar](25) NULL,
	[InstitutionName] [varchar](100) NULL,
	[InstitutionNum] [char](5) NULL,
	[ToInstitutionName] [varchar](100) NULL,
	[ToInstitutionNum] [char](5) NULL,
	[FromInstitutionName] [varchar](100) NULL,
	[FromInstitutionNum] [char](5) NULL,
	[MainPtServ] [varchar](255) NULL,
	[MainPtServDesc] [varchar](255) NULL,
	[SubServiceCode] [varchar](10) NULL,
	[SubServiceDesc] [varchar](50) NULL,
	[MCC] [varchar](2) NULL,
	[MCCDesc] [varchar](max) NULL,
	[NurseUnitCode] [varchar](100) NULL,
	[NurseUnitDesc] [varchar](255) NULL,
	[LHAName] [varchar](100) NULL,
	[HSDAName] [varchar](100) NULL,
	[HealthAuthorityName] [varchar](50) NULL,
	[Age] [smallint] NULL,
	[CMGPlusAgeGroup] [varchar](20) NULL,
	[Px1Code] [varchar](20) NULL,
	[Px1Desc] [varchar](4000) NULL,
	[Px2Code] [varchar](20) NULL,
	[Px2Desc] [varchar](4000) NULL,
	[Px3Code] [varchar](20) NULL,
	[Px3Desc] [varchar](4000) NULL,
	[Px4Code] [varchar](20) NULL,
	[Px4Desc] [varchar](4000) NULL,
	[Px5Code] [varchar](20) NULL,
	[Px5Desc] [varchar](4000) NULL,
	[Px6Code] [varchar](20) NULL,
	[Px6Desc] [varchar](4000) NULL,
	[Px7Code] [varchar](20) NULL,
	[Px7Desc] [varchar](4000) NULL,
	[Px8Code] [varchar](20) NULL,
	[Px8Desc] [varchar](4000) NULL,
	[Px9Code] [varchar](20) NULL,
	[Px9Desc] [varchar](4000) NULL,
	[Px10Code] [varchar](20) NULL,
	[Px10Desc] [varchar](4000) NULL,
	[Px11Code] [varchar](20) NULL,
	[Px11Desc] [varchar](4000) NULL,
	[Px12Code] [varchar](20) NULL,
	[Px12Desc] [varchar](4000) NULL,
	[Px13Code] [varchar](20) NULL,
	[Px13Desc] [varchar](4000) NULL,
	[Px14Code] [varchar](20) NULL,
	[Px14Desc] [varchar](4000) NULL,
	[Px15Code] [varchar](20) NULL,
	[Px15Desc] [varchar](4000) NULL,
	[Px16Code] [varchar](20) NULL,
	[Px16Desc] [varchar](4000) NULL,
	[Px17Code] [varchar](20) NULL,
	[Px17Desc] [varchar](4000) NULL,
	[Px18Code] [varchar](20) NULL,
	[Px18Desc] [varchar](4000) NULL,
	[Px19Code] [varchar](20) NULL,
	[Px19Desc] [varchar](4000) NULL,
	[Px20Code] [varchar](20) NULL,
	[Px20Desc] [varchar](4000) NULL,
	[Dx1Code] [varchar](20) NULL,
	[Dx1Desc] [varchar](4000) NULL,
	[DXType1] [varchar](356) NULL,
	[Dx2Code] [varchar](20) NULL,
	[Dx2Desc] [varchar](4000) NULL,
	[DXType2] [varchar](356) NULL,
	[Dx3Code] [varchar](20) NULL,
	[Dx3Desc] [varchar](4000) NULL,
	[DXType3] [varchar](356) NULL,
	[Dx4Code] [varchar](20) NULL,
	[Dx4Desc] [varchar](4000) NULL,
	[DXType4] [varchar](356) NULL,
	[Dx5Code] [varchar](20) NULL,
	[Dx5Desc] [varchar](4000) NULL,
	[DXType5] [varchar](356) NULL,
	[Dx6Code] [varchar](20) NULL,
	[Dx6Desc] [varchar](4000) NULL,
	[DXType6] [varchar](356) NULL,
	[Dx7Code] [varchar](20) NULL,
	[Dx7Desc] [varchar](4000) NULL,
	[DXType7] [varchar](356) NULL,
	[Dx8Code] [varchar](20) NULL,
	[Dx8Desc] [varchar](4000) NULL,
	[DXType8] [varchar](356) NULL,
	[Dx9Code] [varchar](20) NULL,
	[Dx9Desc] [varchar](4000) NULL,
	[DXType9] [varchar](356) NULL,
	[Dx10Code] [varchar](20) NULL,
	[Dx10Desc] [varchar](4000) NULL,
	[DXType10] [varchar](356) NULL,
	[Dx11Code] [varchar](20) NULL,
	[Dx11Desc] [varchar](4000) NULL,
	[DXType11] [varchar](356) NULL,
	[Dx12Code] [varchar](20) NULL,
	[Dx12Desc] [varchar](4000) NULL,
	[DXType12] [varchar](356) NULL,
	[Dx13Code] [varchar](20) NULL,
	[Dx13Desc] [varchar](4000) NULL,
	[DXType13] [varchar](356) NULL,
	[Dx14Code] [varchar](20) NULL,
	[Dx14Desc] [varchar](4000) NULL,
	[DXType14] [varchar](356) NULL,
	[Dx15Code] [varchar](20) NULL,
	[Dx15Desc] [varchar](4000) NULL,
	[DXType15] [varchar](356) NULL,
	[Dx16Code] [varchar](20) NULL,
	[Dx16Desc] [varchar](4000) NULL,
	[DXType16] [varchar](356) NULL,
	[Dx17Code] [varchar](20) NULL,
	[Dx17Desc] [varchar](4000) NULL,
	[DXType17] [varchar](356) NULL,
	[Dx18Code] [varchar](20) NULL,
	[Dx18Desc] [varchar](4000) NULL,
	[DXType18] [varchar](356) NULL,
	[Dx19Code] [varchar](20) NULL,
	[Dx19Desc] [varchar](4000) NULL,
	[DXType19] [varchar](356) NULL,
	[Dx20Code] [varchar](20) NULL,
	[Dx20Desc] [varchar](4000) NULL,
	[DXType20] [varchar](356) NULL,
	[Dx21Code] [varchar](20) NULL,
	[Dx21Desc] [varchar](4000) NULL,
	[DXType21] [varchar](356) NULL,
	[Dx22Code] [varchar](20) NULL,
	[Dx22Desc] [varchar](4000) NULL,
	[DXType22] [varchar](356) NULL,
	[Dx23Code] [varchar](20) NULL,
	[Dx23Desc] [varchar](4000) NULL,
	[DXType23] [varchar](356) NULL,
	[Dx24Code] [varchar](20) NULL,
	[Dx24Desc] [varchar](4000) NULL,
	[DXType24] [varchar](356) NULL,
	[Dx25Code] [varchar](20) NULL,
	[Dx25Desc] [varchar](4000) NULL,
	[DXType25] [varchar](356) NULL,
	[MRCareProgramCode] [varchar](255) NULL,
	[MRCareTeamCode] [varchar](255) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[DADMrtPxProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[DADMrtPxProfile](
	[PxOrderNo] [tinyint] NULL,
	[PXID] [bigint] NULL,
	[PxLocID] [int] NULL,
	[PxAttributeLocID] [int] NULL,
	[PxAttributeExtID] [int] NULL,
	[PxAttributeStatID] [int] NULL,
	[PxDoctorID] [int] NULL,
	[PxAnesthesiaID] [int] NULL,
	[PxMonth] [int] NULL,
	[IsPxUnplandRetToOR] [bit] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[DADMrtRehabProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[DADMrtRehabProfile](
	[FiscalYear] [int] NULL,
	[FiscalYearLong] [char](5) NULL,
	[BatchYear] [smallint] NOT NULL,
	[BatchPeriod] [smallint] NOT NULL,
	[AcuteDays] [int] NULL,
	[ALCDays] [int] NULL,
	[RIW] [float] NULL,
	[LOS] [int] NULL,
	[LOSGrouping] [varchar](50) NULL,
	[AdmissionDate] [datetime] NULL,
	[AdmissionTime] [char](5) NULL,
	[AdmissionNurseUnitCode] [varchar](100) NULL,
	[AdmissionNurseUnitDesc] [varchar](255) NULL,
	[admissionCategoryCode] [varchar](2) NULL,
	[AdmissionCategoryDescription] [varchar](100) NULL,
	[AdmitDrServ] [varchar](255) NULL,
	[AnesthesiaCode] [varchar](50) NULL,
	[AnesthesiaDesc] [varchar](255) NULL,
	[DischargeDate] [datetime] NULL,
	[DischargeTime] [char](5) NULL,
	[DischargeDispositionCode] [char](2) NULL,
	[DischargeDispositionDescription] [varchar](255) NULL,
	[DrCode] [varchar](50) NULL,
	[DrName] [varchar](50) NULL,
	[DrService] [varchar](255) NULL,
	[DrServiceGroup] [varchar](50) NULL,
	[EntryCode] [varchar](50) NULL,
	[EntryCodeDesc] [varchar](50) NULL,
	[Gender] [varchar](25) NULL,
	[InstitutionName] [varchar](100) NULL,
	[InstitutionNum] [char](5) NULL,
	[ToInstitutionName] [varchar](100) NULL,
	[ToInstitutionNum] [char](5) NULL,
	[FromInstitutionName] [varchar](100) NULL,
	[FromInstitutionNum] [char](5) NULL,
	[MainPtServ] [varchar](255) NULL,
	[MainPtServDesc] [varchar](255) NULL,
	[SubServiceCode] [varchar](10) NULL,
	[SubServiceDesc] [varchar](50) NULL,
	[NurseUnitCode] [varchar](100) NULL,
	[NurseUnitDesc] [varchar](255) NULL,
	[ReAdmissionCode] [varchar](10) NULL,
	[ReAdmissionDesc] [varchar](75) NULL,
	[StatusTypeCode] [varchar](255) NULL,
	[StatusTypeDesc] [varchar](255) NULL,
	[StatusTypeTypical] [varchar](50) NULL,
	[LHAName] [varchar](100) NULL,
	[HSDAName] [varchar](100) NULL,
	[HealthAuthorityName] [varchar](50) NULL,
	[PostalCode] [varchar](6) NULL,
	[Age] [smallint] NULL,
	[CMGPlusAgeGroup] [varchar](20) NULL,
	[Px1Code] [varchar](20) NULL,
	[Px1Desc] [varchar](4000) NULL,
	[Px2Code] [varchar](20) NULL,
	[Px2Desc] [varchar](4000) NULL,
	[Px3Code] [varchar](20) NULL,
	[Px3Desc] [varchar](4000) NULL,
	[Px4Code] [varchar](20) NULL,
	[Px4Desc] [varchar](4000) NULL,
	[Px5Code] [varchar](20) NULL,
	[Px5Desc] [varchar](4000) NULL,
	[Px6Code] [varchar](20) NULL,
	[Px6Desc] [varchar](4000) NULL,
	[Px7Code] [varchar](20) NULL,
	[Px7Desc] [varchar](4000) NULL,
	[Px8Code] [varchar](20) NULL,
	[Px8Desc] [varchar](4000) NULL,
	[Px9Code] [varchar](20) NULL,
	[Px9Desc] [varchar](4000) NULL,
	[Px10Code] [varchar](20) NULL,
	[Px10Desc] [varchar](4000) NULL,
	[Px11Code] [varchar](20) NULL,
	[Px11Desc] [varchar](4000) NULL,
	[Px12Code] [varchar](20) NULL,
	[Px12Desc] [varchar](4000) NULL,
	[Px13Code] [varchar](20) NULL,
	[Px13Desc] [varchar](4000) NULL,
	[Px14Code] [varchar](20) NULL,
	[Px14Desc] [varchar](4000) NULL,
	[Px15Code] [varchar](20) NULL,
	[Px15Desc] [varchar](4000) NULL,
	[Px16Code] [varchar](20) NULL,
	[Px16Desc] [varchar](4000) NULL,
	[Px17Code] [varchar](20) NULL,
	[Px17Desc] [varchar](4000) NULL,
	[Px18Code] [varchar](20) NULL,
	[Px18Desc] [varchar](4000) NULL,
	[Px19Code] [varchar](20) NULL,
	[Px19Desc] [varchar](4000) NULL,
	[Px20Code] [varchar](20) NULL,
	[Px20Desc] [varchar](4000) NULL,
	[Dx1Code] [varchar](20) NULL,
	[Dx1Desc] [varchar](4000) NULL,
	[DXType1] [varchar](356) NULL,
	[Dx2Code] [varchar](20) NULL,
	[Dx2Desc] [varchar](4000) NULL,
	[DXType2] [varchar](356) NULL,
	[Dx3Code] [varchar](20) NULL,
	[Dx3Desc] [varchar](4000) NULL,
	[DXType3] [varchar](356) NULL,
	[Dx4Code] [varchar](20) NULL,
	[Dx4Desc] [varchar](4000) NULL,
	[DXType4] [varchar](356) NULL,
	[Dx5Code] [varchar](20) NULL,
	[Dx5Desc] [varchar](4000) NULL,
	[DXType5] [varchar](356) NULL,
	[Dx6Code] [varchar](20) NULL,
	[Dx6Desc] [varchar](4000) NULL,
	[DXType6] [varchar](356) NULL,
	[Dx7Code] [varchar](20) NULL,
	[Dx7Desc] [varchar](4000) NULL,
	[DXType7] [varchar](356) NULL,
	[Dx8Code] [varchar](20) NULL,
	[Dx8Desc] [varchar](4000) NULL,
	[DXType8] [varchar](356) NULL,
	[Dx9Code] [varchar](20) NULL,
	[Dx9Desc] [varchar](4000) NULL,
	[DXType9] [varchar](356) NULL,
	[Dx10Code] [varchar](20) NULL,
	[Dx10Desc] [varchar](4000) NULL,
	[DXType10] [varchar](356) NULL,
	[Dx11Code] [varchar](20) NULL,
	[Dx11Desc] [varchar](4000) NULL,
	[DXType11] [varchar](356) NULL,
	[Dx12Code] [varchar](20) NULL,
	[Dx12Desc] [varchar](4000) NULL,
	[DXType12] [varchar](356) NULL,
	[Dx13Code] [varchar](20) NULL,
	[Dx13Desc] [varchar](4000) NULL,
	[DXType13] [varchar](356) NULL,
	[Dx14Code] [varchar](20) NULL,
	[Dx14Desc] [varchar](4000) NULL,
	[DXType14] [varchar](356) NULL,
	[Dx15Code] [varchar](20) NULL,
	[Dx15Desc] [varchar](4000) NULL,
	[DXType15] [varchar](356) NULL,
	[Dx16Code] [varchar](20) NULL,
	[Dx16Desc] [varchar](4000) NULL,
	[DXType16] [varchar](356) NULL,
	[Dx17Code] [varchar](20) NULL,
	[Dx17Desc] [varchar](4000) NULL,
	[DXType17] [varchar](356) NULL,
	[Dx18Code] [varchar](20) NULL,
	[Dx18Desc] [varchar](4000) NULL,
	[DXType18] [varchar](356) NULL,
	[Dx19Code] [varchar](20) NULL,
	[Dx19Desc] [varchar](4000) NULL,
	[DXType19] [varchar](356) NULL,
	[Dx20Code] [varchar](20) NULL,
	[Dx20Desc] [varchar](4000) NULL,
	[DXType20] [varchar](356) NULL,
	[Dx21Code] [varchar](20) NULL,
	[Dx21Desc] [varchar](4000) NULL,
	[DXType21] [varchar](356) NULL,
	[Dx22Code] [varchar](20) NULL,
	[Dx22Desc] [varchar](4000) NULL,
	[DXType22] [varchar](356) NULL,
	[Dx23Code] [varchar](20) NULL,
	[Dx23Desc] [varchar](4000) NULL,
	[DXType23] [varchar](356) NULL,
	[Dx24Code] [varchar](20) NULL,
	[Dx24Desc] [varchar](4000) NULL,
	[DXType24] [varchar](356) NULL,
	[Dx25Code] [varchar](20) NULL,
	[Dx25Desc] [varchar](4000) NULL,
	[DXType25] [varchar](356) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[EDMrtVisitAreaProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[EDMrtVisitAreaProfile](
	[Site] [varchar](3) NULL,
	[FacilityID] [int] NULL,
	[IsFrozen] [int] NULL,
	[FiscalYearLong] [int] NULL,
	[EmergencyAreaDateID] [int] NOT NULL,
	[EmergencyAreaTimeID] [int] NOT NULL,
	[EmergencyAreaID] [int] NOT NULL,
	[VisitAreaTypeID] [int] NULL,
	[IsAreaOutsideVisit] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[EDMrtVisitProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[EDMrtVisitProfile](
	[SourceSystemCode] [varchar](20) NULL,
	[Site] [varchar](3) NULL,
	[FacilityID] [int] NULL,
	[IsFrozen] [int] NULL,
	[FiscalYearLong] [int] NULL,
	[VisitKeyDateID] [int] NULL,
	[AccidentCodeID] [int] NULL,
	[AccidentDateID] [int] NULL,
	[AccidentTimeID] [int] NULL,
	[AccountTypeID] [int] NULL,
	[AccountSubTypeID] [int] NULL,
	[ADENurseID] [int] NULL,
	[ADEPharmacistID] [int] NULL,
	[AdmissionSourceCodeID] [int] NULL,
	[AdmittedFlag] [bit] NULL,
	[AgeID] [int] NULL,
	[ArrivalModeCodeID] [int] NULL,
	[ArrivalDateID] [int] NULL,
	[ArrivalTimeID] [int] NULL,
	[ArrivalToMDElapsedTimeID] [int] NULL,
	[ArrivaltoTriageElapsedTimeID] [int] NULL,
	[AssignedAreaDateID] [int] NULL,
	[AssignedAreaTimeID] [int] NULL,
	[BedRequestDateID] [int] NULL,
	[BedRequestTimeID] [int] NULL,
	[BedRequesttoDispositionElapsedTimeID] [int] NULL,
	[BedRequestToInpatientCDUElapsedTimeID] [int] NULL,
	[CDUFlag] [varchar](10) NULL,
	[CDUType] [varchar](20) NULL,
	[CDULOSElapsedTimeID] [int] NULL,
	[CDUtoBedRequestElapsedTimeID] [int] NULL,
	[CharlsonIndexID] [int] NULL,
	[IsCharlsonComputed] [bit] NULL,
	[ChiefComplaintID] [int] NULL,
	[ChiefComplaint2ID] [int] NULL,
	[ConsultationRequestDateID] [int] NULL,
	[ConsultationRequestTimeID] [int] NULL,
	[ConsultationServiceCodeID] [int] NULL,
	[ConsultCalltoBedRequestElapsedTimeID] [int] NULL,
	[ConsultcalltoDispositionElapsedTimeID] [int] NULL,
	[ConsultCallToInpatientCDUElapsedTimeID] [int] NULL,
	[COTAcuityModifierID] [int] NULL,
	[CountryCode] [char](2) NULL,
	[CTAS_123NonAdmit] [int] NULL,
	[CTAS_123NonAdmitLWBS] [int] NULL,
	[CTAS_123NonAdmitLWBSWithinTarget] [int] NULL,
	[CTAS_123NonAdmitMissedTarget30min] [int] NULL,
	[CTAS_123NonAdmitWithinTarget] [int] NULL,
	[CTAS_45NonAdmit] [int] NULL,
	[CTAS_45NonAdmitLWBS] [int] NULL,
	[CTAS_45NonAdmitLWBSWithinTarget] [int] NULL,
	[CTAS_45NonAdmitMissedTarget15min] [int] NULL,
	[CTAS_45NonAdmitWithinTarget] [int] NULL,
	[CTAS_AdmitMissedTarget60min] [int] NULL,
	[CTAS_AdmitWithinTarget] [int] NULL,
	[CTAS_DDFEAdmit] [int] NULL,
	[CTAS_DDFEAdmitWithinTarget] [int] NULL,
	[DischargeDiagnosisID] [int] NULL,
	[DischargeDispositionCodeID] [int] NULL,
	[DischargeModeID] [int] NULL,
	[DispositionDateID] [int] NULL,
	[DispositionTimeID] [int] NULL,
	[DoctorID] [int] NULL,
	[DoctorID_Original] [int] NULL,
	[DTUCriteria] [varchar](1) NULL,
	[EarliestCDUdateID] [int] NULL,
	[EarliestCDUtimeID] [int] NULL,
	[EmergencyStatusID] [int] NULL,
	[EMGID] [int] NULL,
	[FirstVisitFlag] [bit] NULL,
	[FirstEmergencyAreaDateID] [int] NULL,
	[FirstEmergencyAreaTimeID] [int] NULL,
	[FirstEmergencyAreaID] [int] NULL,
	[FirstEmergencyAreaVisitAreaTypeID] [int] NULL,
	[FirstEmergencyAreaExclTriageDateID] [int] NULL,
	[FirstEmergencyAreaExclTriageTimeID] [int] NULL,
	[FirstEmergencyAreaExclTriageAreaID] [int] NULL,
	[FirstEmergencyAreaExclTriageVisitAreaTypeID] [int] NULL,
	[FSA] [char](3) NULL,
	[FstCareProviderDateID] [int] NULL,
	[FstCareProviderTimeID] [int] NULL,
	[FstCareProviderToBedRequestElapsedTimeID] [int] NULL,
	[FstCareProviderToConsultCallElapsedTimeID] [int] NULL,
	[FstCareProviderToDispositionElapsedTimeID] [int] NULL,
	[FstCareProviderToInpatientCDUElapsedTimeID] [int] NULL,
	[GenderID] [tinyint] NULL,
	[InfectiousDiseaseCodeID] [int] NULL,
	[InpatientAdmittingDoctorID] [int] NULL,
	[InpatientAttendingDoctorID] [int] NULL,
	[InpatientBed] [varchar](30) NULL,
	[InpatientDateID] [int] NULL,
	[InpatientTimeID] [int] NULL,
	[InpatientDiagnosis] [varchar](40) NULL,
	[InpatientLocationCostCenterID] [int] NULL,
	[InpatientNursingUnitID] [int] NULL,
	[InpatientServiceCodeID] [int] NULL,
	[InpatientTeamID] [int] NULL,
	[IsAutoAccident] [bit] NULL,
	[IsHomeless] [bit] NULL,
	[IsHomeless_PHC] [bit] NULL,
	[IsOtherAccident] [bit] NULL,
	[IsSingleSiteVisit] [bit] NULL,
	[IsThirdPartyLiability] [bit] NULL,
	[IsTrauma] [bit] NULL,
	[IsWorkAccident] [bit] NULL,
	[LanguageID] [int] NULL,
	[LastEmergencyAreaDateID] [int] NULL,
	[LastEmergencyAreaTimeID] [int] NULL,
	[LastEmergencyAreaID] [int] NULL,
	[LastEmergencyAreaVisitAreaTypeID] [int] NULL,
	[LatestCDUOutDateID] [int] NULL,
	[LatestCDUOutTimeID] [int] NULL,
	[LHAID] [int] NULL,
	[LOS_ElapsedTimeID] [int] NULL,
	[LWBS] [int] NULL,
	[MDtoBedRequestElapsedTimeID] [int] NULL,
	[MDtoConsultcallElapsedTimeID] [int] NULL,
	[MDtoDispositionElapsedTimeID] [int] NULL,
	[PatientServiceCodeID] [int] NULL,
	[Payor1ID] [int] NULL,
	[Payor2ID] [int] NULL,
	[Payor3ID] [int] NULL,
	[ProvinceCode] [char](2) NULL,
	[Readmission_AnySite_ElapsedTimeID] [int] NULL,
	[Readmission_sameSite_ElapsedTimeID] [int] NULL,
	[RegistrationDateID] [int] NULL,
	[RegistrationTimeID] [int] NULL,
	[RegistrationDateID_Original] [int] NULL,
	[RegistrationTimeID_Original] [int] NULL,
	[ReligionID] [int] NULL,
	[SeenByDoctorDateID] [int] NULL,
	[SeenBYDoctorTimeID] [int] NULL,
	[SeenbyGeriTriageDateID] [int] NULL,
	[SeenbyGeriTriageTimeID] [int] NULL,
	[SeenByNurseDateID] [int] NULL,
	[SeenByNurseTimeID] [int] NULL,
	[SeenByResDateID] [int] NULL,
	[SeenByResTimeID] [int] NULL,
	[SeenByStudentDateID] [int] NULL,
	[SeenByStudentTimeID] [int] NULL,
	[StartDateID] [int] NULL,
	[StartTimeID] [int] NULL,
	[StarttoBedRequestElapsedTimeID] [int] NULL,
	[StarttoDispositionElapsedTimeID] [int] NULL,
	[StarttoDispositionExclCDUElapsedTimeID] [int] NULL,
	[StarttoDispositionExclCDUtoBedRequestElapsedTimeID] [int] NULL,
	[StarttoMDElapsedTimeID] [int] NULL,
	[SystemDateID] [int] NULL,
	[SystemTimeID] [int] NULL,
	[TriageAcuityID] [int] NULL,
	[TriageDateID] [int] NULL,
	[TriageTimeID] [int] NULL,
	[Triageto1stCareProviderElapsedTimeID] [int] NULL,
	[TriagetoBedrequestElapsedTimeID] [int] NULL,
	[TriagetoDispositionElapsedTimeID] [int] NULL,
	[TriageToDispositionWithHUBElapsedTimeID] [int] NULL,
	[TriagetoMDElapsedTimeID] [int] NULL,
	[VirtualInpatientLocationCostCenterID] [int] NULL,
	[VirtualInpatientNursingUnitID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[LOSFactProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[LOSFactProfile](
	[FacilityID] [int] NULL,
	[AdmissionDateID] [int] NULL,
	[DischargeDateID] [int] NULL,
	[NursingUnitID] [int] NULL,
	[MaxCensusDateID] [int] NULL,
	[CostCenterBusinessUnitEntitySiteID] [int] NULL,
	[IsCustomCostCenter] [bit] NULL,
	[LOS] [int] NULL,
	[ALCDays] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[MHAMRRExtractClientFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[MHAMRRExtractClientFact](
	[FiscalYear] [char](9) NOT NULL,
	[FiscalPeriod] [char](2) NOT NULL,
	[C3City] [char](30) NULL,
	[C4Province] [char](2) NULL,
	[C7Gender] [char](1) NULL,
	[C8MaritalStatus] [char](2) NULL,
	[C9Height] [char](3) NULL,
	[C10Weight] [char](3) NULL,
	[C11HouseholdComposition] [char](2) NULL,
	[C12AboriginalIdentityIndicator] [char](2) NULL,
	[C13AboriginalIdentityGroup] [char](2) NULL,
	[C14FirstNationsStatusIndicator] [char](2) NULL,
	[C15FirstNationsOnReserveIndicator] [char](2) NULL,
	[C16LevelOfEducationCompleted] [char](2) NULL,
	[C17CurrentEducation] [char](2) NULL,
	[C18EmploymentStatus] [char](2) NULL,
	[C19EmploymentHours] [char](2) NULL,
	[C20WCBSickDisabilityFlag] [char](2) NULL,
	[C21DurationWCBSickDisability] [char](2) NULL,
	[C22CriminalJusticeInvolvement] [char](2) NULL,
	[C23NatureOfCriminalJustice] [char](2) NULL,
	[C24LegalStatusFirstField] [char](2) NULL,
	[C25LegalStatusSecondField] [char](2) NULL,
	[C26EstimatedAge] [char](2) NULL,
	[C27HistoryOfSuicideAttempts] [char](2) NULL,
	[C28HistoryOfViolence] [char](2) NULL,
	[C29AgeFirstUseOfAlcohol] [char](2) NULL,
	[C30AgeFirstUseOfTobacco] [char](2) NULL,
	[C31AgeFirstUseOfMarijuana] [char](2) NULL,
	[C32AgeFirstUseOfDrugs] [char](2) NULL,
	[IsMCFD] [bit] NULL,
	[AgeAtPeriodEnd] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[MHAMRRExtractDiagnosisFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[MHAMRRExtractDiagnosisFact](
	[FiscalYear] [char](9) NOT NULL,
	[FiscalPeriod] [char](2) NOT NULL,
	[D3GAFScoreEnrolment] [char](3) NULL,
	[D4GAFScoreDischarge] [char](3) NULL,
	[D5Axis1FirstAtEnrolment] [char](6) NULL,
	[D6Axis1FirstAtDischarge] [char](6) NULL,
	[D7Axis1SecondAtEnrolment] [char](6) NULL,
	[D8Axis1SecondAtDischarge] [char](6) NULL,
	[D9Axis1OtherAtEnrolment] [char](6) NULL,
	[D10Axis1OtherAtDischarge] [char](6) NULL,
	[D11Axis2FirstAtEnrolment] [char](6) NULL,
	[D12Axis2FirstAtDischarge] [char](6) NULL,
	[D13Axis2SecondAtEnrolment] [char](6) NULL,
	[D14Axis2SecondAtDischarge] [char](6) NULL,
	[D15ClinicianImpression] [char](2) NULL,
	[IsMCFD] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[MHAMRRExtractHoNoSFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[MHAMRRExtractHoNoSFact](
	[FiscalYear] [char](9) NOT NULL,
	[FiscalPeriod] [char](2) NOT NULL,
	[N3BehaviouralDisturbance] [char](2) NULL,
	[N4NonAccidentalSelfInjury] [char](2) NULL,
	[N5ProblemsWithAlcoholSubstanceSolventUse] [char](2) NULL,
	[N6CognitiveProblems] [char](2) NULL,
	[N7ProblemsWithPhysicalIllnessOrDisability] [char](2) NULL,
	[N8ProblemsWithHallucinationDelusionOrFalseBelief] [char](2) NULL,
	[N9ProblemsWithDepressionSymptoms] [char](2) NULL,
	[N10ProblemsWithSocialFamilyOrSupportiveRelationships] [char](2) NULL,
	[N11ProblemsWithActivitiesOfDailyLiving] [char](2) NULL,
	[N12OverallProblemsWithLivingConditions] [char](2) NULL,
	[N13ProblemsWithWorkAndLeisure] [char](2) NULL,
	[N14ProblemsWithOverActivityAttentionOrConcentration] [char](2) NULL,
	[N15ProblemsWithScholasticOrLanguageSkills] [char](2) NULL,
	[N16ProblemsWithNonOrganicSomaticSymptoms] [char](2) NULL,
	[N17ProblemsWithEmotionalAndRelatedSymptoms] [char](2) NULL,
	[N18ProblemsWithPeerRelationships] [char](2) NULL,
	[N19ProblemsWithSelfCareAndIndependence] [char](2) NULL,
	[N20ProblemsWithPoorAttendance] [char](2) NULL,
	[N21ProblemsWithKnowledgeOfChildDifficulties] [char](2) NULL,
	[N22BehaviouralProblemsDirectedAtOthers] [char](2) NULL,
	[N23BehaviouralProblemsDirectedAtSelf] [char](2) NULL,
	[N24OtherMentalAndBehaviouralProblems] [char](2) NULL,
	[N25AttentionAndConcentration] [char](2) NULL,
	[N26MemoryAndOrientation] [char](2) NULL,
	[N27CommunicationsUnderstanding] [char](2) NULL,
	[N28CommunicationsExpression] [char](2) NULL,
	[N29HallucinationsAndDelusions] [char](2) NULL,
	[N30MoodChanges] [char](2) NULL,
	[N31ProblemsWithSleeping] [char](2) NULL,
	[N32ProblemsWithEatingAndDrinking] [char](2) NULL,
	[N33PhysicalProblems] [char](2) NULL,
	[N34Seizures] [char](2) NULL,
	[N35ActivitiesOfDailyLivingAtHome] [char](2) NULL,
	[N36ActivitiesOfDailyLivingOutsideHome] [char](2) NULL,
	[N37LevelOfSelfCare] [char](2) NULL,
	[N38ProblemsWithRelationships] [char](2) NULL,
	[N39OccupationAndActivities] [char](2) NULL,
	[N40ManiaHypomania] [char](2) NULL,
	[N41Anxiety] [char](2) NULL,
	[N44EatingDisorder] [char](2) NULL,
	[N45LackOfInformation] [char](2) NULL,
	[IsMCFD] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[MHAMRRExtractServiceEpisodeFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[MHAMRRExtractServiceEpisodeFact](
	[FiscalYear] [char](9) NOT NULL,
	[FiscalPeriod] [char](2) NOT NULL,
	[S2ServiceType] [char](2) NULL,
	[S3ReferralSource] [char](2) NULL,
	[S9NumberOfServiceEventsInPeriod] [char](3) NULL,
	[S10LivingArrangement] [char](2) NULL,
	[S11AcuteInpatientSecureRoom] [char](2) NULL,
	[S12AcuteInpatientTransport] [char](2) NULL,
	[S13MHAAffectedRelationship] [char](2) NULL,
	[S14ServiceAgencyLocationCode] [char](20) NULL,
	[S15TypeOfCBTIntervention] [char](2) NULL,
	[S16TypeOfDBTIntervention] [char](2) NULL,
	[S19ReasonForEndingService] [char](2) NULL,
	[S20DateHospitalToCommunityContact] [char](10) NULL,
	[S21ReasonNoCommunityFollowUpContact] [char](2) NULL,
	[S22Pregnancy] [char](2) NULL,
	[S23Parenting] [char](2) NULL,
	[S24SuicideAttempt] [char](2) NULL,
	[S25Violence] [char](2) NULL,
	[S26PeerSupportService] [char](2) NULL,
	[S27FASD] [char](2) NULL,
	[ParisTeamCode] [varchar](10) NULL,
	[CommunityRegionCode] [varchar](20) NULL,
	[CommunityProgramCode] [varchar](20) NULL,
	[ServiceEpisodeType] [varchar](2) NULL,
	[ServiceEpisodeReferralReasonCode] [varchar](20) NULL,
	[IsMCFD] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[MHAMRRExtractServiceEventFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[MHAMRRExtractServiceEventFact](
	[FiscalYear] [char](9) NOT NULL,
	[FiscalPeriod] [char](2) NOT NULL,
	[ServiceEventType] [varchar](5) NULL,
	[IsMCFD] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[MHAMRRExtractSubstanceUseFact]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[MHAMRRExtractSubstanceUseFact](
	[FiscalYear] [char](9) NOT NULL,
	[FiscalPeriod] [char](2) NOT NULL,
	[U3SubstanceUse] [char](2) NULL,
	[U4StageOfChange] [char](2) NULL,
	[U5AvgCigarettesDrinks30DaysPrior] [char](2) NULL,
	[U6DaysDrinkingOrDrugs30DaysPrior] [char](2) NULL,
	[U7PrimaryMethodOfSubstanceIntake] [char](2) NULL,
	[U8SharingNeedles30DaysPrior] [char](2) NULL,
	[U9SourceOfSubstance] [char](2) NULL,
	[U10PrimarySubstanceUsed] [char](2) NULL,
	[IsMCFD] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ORCaseCostingView]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ORCaseCostingView](
	[IsScheduled] [bit] NULL,
	[SurgeryPerformedDate] [datetime] NULL,
	[FiscalYear] [char](5) NULL,
	[FiscalPeriod] [varchar](20) NULL,
	[FacilityLongName] [varchar](100) NULL,
	[ORRoomCode] [varchar](100) NULL,
	[ORLocationDesc] [varchar](100) NULL,
	[ServiceDescription] [varchar](100) NULL,
	[LoggedMainSurgeonCode] [varchar](50) NULL,
	[LoggedMainSurgeonName] [varchar](50) NULL,
	[LoggedMainSurgeonSpecialty] [varchar](255) NULL,
	[LoggedPx1Code] [varchar](20) NULL,
	[LoggedPx1Desc] [varchar](500) NULL,
	[LoggedPx2Code] [varchar](20) NULL,
	[LoggedPx2Desc] [varchar](500) NULL,
	[LoggedPx3Code] [varchar](20) NULL,
	[LoggedPx3Desc] [varchar](500) NULL,
	[LoggedSPRPx1Code] [varchar](20) NULL,
	[LoggedSPRPx1Desc] [varchar](500) NULL,
	[LoggedSPRPx2Code] [varchar](20) NULL,
	[LoggedSPRPx2Desc] [varchar](500) NULL,
	[LoggedSPRPx3Code] [varchar](20) NULL,
	[LoggedSPRPx3Desc] [varchar](500) NULL,
	[LoggedSurgeon1Code] [varchar](50) NULL,
	[LoggedSurgeon1Name] [varchar](50) NULL,
	[LoggedSurgeon2Code] [varchar](50) NULL,
	[LoggedSurgeon2Name] [varchar](50) NULL,
	[LoggedSurgeon3Code] [varchar](50) NULL,
	[LoggedSurgeon3Name] [varchar](50) NULL,
	[PatientInDateTime] [datetime] NULL,
	[PatientOutDateTime] [datetime] NULL,
	[PatientInOutElapsedTimeMinutes] [int] NULL,
	[SurgeryStartDateTime] [datetime] NULL,
	[SurgeryStopDateTime] [datetime] NULL,
	[SurgeryElapsedTimeMinutes] [int] NULL,
	[ResourceNum] [varchar](50) NULL,
	[ResourceDesc] [varchar](255) NULL,
	[ResourceType] [varchar](100) NULL,
	[ProductCategory] [varchar](100) NULL,
	[CaseCostingExtractDateId] [int] NULL,
	[CompleteFileExtractDate] [datetime] NULL,
	[Impl_Lot] [varchar](50) NULL,
	[Impl_Side] [varchar](50) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ORMrtCompletedCaseProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ORMrtCompletedCaseProfile](
	[ORRoomCode] [varchar](100) NULL,
	[SurgeryPerformedDate] [datetime] NULL,
	[BookingFormReceivedDate] [int] NULL,
	[SurgeryDecisionDate] [int] NULL,
	[FiscalYear] [char](5) NULL,
	[FiscalPeriod] [varchar](20) NULL,
	[StatIndicator] [varchar](15) NULL,
	[PatientStatusDetail] [varchar](10) NULL,
	[PatientStatusRollup] [char](1) NULL,
	[SurgeryPriorityDesc] [varchar](100) NULL,
	[IsAddon] [smallint] NULL,
	[FullCode] [char](6) NULL,
	[DiagnosisDescription] [varchar](500) NULL,
	[DXDescription70] [varchar](100) NULL,
	[DxTargetInWeeks] [varchar](50) NULL,
	[ASAScoreCode] [varchar](2) NULL,
	[ASAScoreDesc] [varchar](100) NULL,
	[ScheduledMainSurgeonId] [int] NULL,
	[ScheduledMainSurgeonCode] [varchar](50) NULL,
	[ScheduledMainSurgeonName] [varchar](50) NULL,
	[LoggedMainSurgeonId] [int] NULL,
	[LoggedMainSurgeonCode] [varchar](50) NULL,
	[LoggedMainSurgeonName] [varchar](50) NULL,
	[LoggedMainSurgeonSpecialty] [varchar](255) NULL,
	[ScheduledAnesthetistId] [int] NULL,
	[ScheduledAnesthetistCode] [varchar](50) NULL,
	[ScheduledAnesthetistName] [varchar](50) NULL,
	[LoggedAnesthetistId] [int] NULL,
	[LoggedAnesthetistCode] [varchar](50) NULL,
	[LoggedAnesthetistName] [varchar](50) NULL,
	[LoggedSecondAnesthetistId] [int] NULL,
	[LoggedSecondAnesthetistCode] [varchar](50) NULL,
	[LoggedSecondAnesthetistName] [varchar](50) NULL,
	[LoggedThirdAnesthetistId] [int] NULL,
	[LoggedThirdAnesthetistCode] [varchar](50) NULL,
	[LoggedThirdAnesthetistName] [varchar](50) NULL,
	[LoggedTEEAnesthetistId] [int] NULL,
	[LoggedTEEAnesthetistCode] [varchar](50) NULL,
	[LoggedTEEAnesthetistName] [varchar](50) NULL,
	[ServiceCode] [varchar](10) NULL,
	[ServiceDescription] [varchar](100) NULL,
	[ScheduledPx1Code] [varchar](20) NULL,
	[ScheduledPx1Desc] [varchar](500) NULL,
	[ScheduledSPRPx1Code] [varchar](20) NULL,
	[ScheduledSPRPx1Desc] [varchar](500) NULL,
	[LoggedPx1Code] [varchar](20) NULL,
	[LoggedPx1Desc] [varchar](500) NULL,
	[LoggedSPRPx1Code] [varchar](20) NULL,
	[LoggedSPRPx1Desc] [varchar](500) NULL,
	[LoggedPx2Code] [varchar](20) NULL,
	[LoggedPx2Desc] [varchar](500) NULL,
	[LoggedSPRPx2Code] [varchar](20) NULL,
	[LoggedSPRPx2Desc] [varchar](500) NULL,
	[LoggedPx3Code] [varchar](20) NULL,
	[LoggedPx3Desc] [varchar](500) NULL,
	[LoggedSPRPx3Code] [varchar](20) NULL,
	[LoggedSPRPx3Desc] [varchar](500) NULL,
	[LoggedSurgeon1Id] [int] NULL,
	[LoggedSurgeon1Code] [varchar](50) NULL,
	[LoggedSurgeon1Name] [varchar](50) NULL,
	[LoggedSurgeon2Id] [int] NULL,
	[LoggedSurgeon2Code] [varchar](50) NULL,
	[LoggedSurgeon2Name] [varchar](50) NULL,
	[LoggedSurgeon3Id] [int] NULL,
	[LoggedSurgeon3Code] [varchar](50) NULL,
	[LoggedSurgeon3Name] [varchar](50) NULL,
	[HoldingStartDateTime] [int] NULL,
	[HoldingEndDateTime] [int] NULL,
	[HoldingAreaElapsedTimeMinutes] [int] NULL,
	[SetupStartDateTime] [int] NULL,
	[SetupEndDateTime] [int] NULL,
	[SetupElapsedTimeMinutes] [int] NULL,
	[PatientInDateTime] [int] NULL,
	[PatientOutDateTime] [int] NULL,
	[PatientInOutElapsedTimeMinutes] [int] NULL,
	[PreviousPatientOutDateTime] [int] NULL,
	[ORTotalElapsedTimeMinutes] [int] NULL,
	[PreviousPatientOutDateTime_DS] [int] NULL,
	[ORTotalElapsedTimeMinutes_DS] [int] NULL,
	[AnesthesiaStartDateTime] [int] NULL,
	[AnesthesiaStopDateTime] [int] NULL,
	[AnesthesiaElapsedTimeMinutes] [int] NULL,
	[AnesthesiologistStopDateTime] [int] NULL,
	[AnesthesiologistElapsedTimeMinutes] [int] NULL,
	[SurgeryStartDateTime] [int] NULL,
	[SurgeryStopDateTime] [int] NULL,
	[SurgeryElapsedTimeMinutes] [int] NULL,
	[CleanupStartDateTime] [int] NULL,
	[CleanupEndDateTime] [int] NULL,
	[CleanupElapsedTimeMinutes] [int] NULL,
	[PARInDateTime] [int] NULL,
	[PAROutDateTime] [int] NULL,
	[PARElapsedTimeMinutes] [int] NULL,
	[SDCPostOpInDateTime] [int] NULL,
	[SDCPostOpOutDateTime] [int] NULL,
	[SDCPostOpElapsedTimeMinutes] [int] NULL,
	[UnitPtFrom] [varchar](255) NULL,
	[SpecialFunding] [varchar](255) NULL,
	[LoggedProcType] [varchar](255) NULL,
	[CancerStatusCode] [varchar](20) NULL,
	[OrigEmergBkgReqDateTime] [int] NULL,
	[FinalEmergBkgReqDateTime] [int] NULL,
	[IsSweeperRoom] [bit] NULL,
	[UnavailableFromDate] [int] NULL,
	[UnavailableToDate] [int] NULL,
	[UnavailableElapsedDay] [int] NULL,
	[SurgWaitElapsedDay] [int] NULL,
	[IsMeetingTarget] [bit] NULL,
	[SurgWaitElapsedDay_BkgCard] [int] NULL,
	[IsMeetingTarget_BkgCard] [bit] NULL,
	[UnavailableReasonDesc] [varchar](100) NULL,
	[LoggedThirdAnesthetist2Id] [int] NULL,
	[LoggedThirdAnesthetist2Code] [varchar](50) NULL,
	[LoggedThirdAnesthetist2Name] [varchar](50) NULL,
	[LoggedThirdAnesthetist3Id] [int] NULL,
	[LoggedThirdAnesthetist3Code] [varchar](50) NULL,
	[LoggedThirdAnesthetist3Name] [varchar](50) NULL,
	[LoggedTEEAnesthetist2Id] [int] NULL,
	[LoggedTEEAnesthetist2Code] [varchar](50) NULL,
	[LoggedTEEAnesthetist2Name] [varchar](50) NULL,
	[LoggedTEEAnesthetist3Id] [int] NULL,
	[LoggedTEEAnesthetist3Code] [varchar](50) NULL,
	[LoggedTEEAnesthetist3Name] [varchar](50) NULL,
	[FacilityLongName] [varchar](100) NULL,
	[ORLocationDesc] [varchar](100) NULL,
	[Site] [varchar](100) NULL,
	[SpecialGroup] [varchar](100) NULL,
	[SpecialFlag] [varchar](100) NULL,
	[IsSwingRoom] [bit] NULL,
	[Anesthesia] [varchar](50) NULL,
	[isSSCL1] [bit] NULL,
	[isSSCL2] [bit] NULL,
	[isSSCL3] [bit] NULL,
	[SurgeryTypeName] [varchar](55) NULL,
	[LocalHealthAuthority] [varchar](100) NULL,
	[ServiceDeliveryArea] [varchar](100) NULL,
	[HealthAuthority] [varchar](50) NULL,
	[Age] [smallint] NULL,
	[CIHIAgeGroup2] [varchar](20) NULL,
	[GenderDesc] [varchar](25) NULL,
	[IsScheduled] [bit] NULL,
	[MedicationDesc] [varchar](255) NULL,
	[AntibioticPreOpDateTime] [int] NULL,
	[AntibioticPreOpEndDateTime] [int] NULL,
	[AntibioticSurgeryElapsedTimeMinutes] [int] NULL,
	[WoundPx1Desc] [varchar](50) NULL,
	[WoundPx2Desc] [varchar](50) NULL,
	[WoundPx3Desc] [varchar](50) NULL,
	[IsPreopAssess] [bit] NULL,
	[ClinStage] [varchar](50) NULL,
	[IsCancRecur] [bit] NULL,
	[IsFirstCase] [int] NOT NULL,
	[IsAntibioticNotRequired] [bit] NULL,
	[IsPHCMajorSurgery] [bit] NULL,
	[BirthYear] [int] NULL,
	[ORType] [varchar](25) NULL,
	[ORLocationGroup] [varchar](25) NULL,
	[ORRoomGroup] [varchar](25) NULL,
	[LoggedPxCount] [int] NULL,
	[IsCostingCase] [bit] NULL,
	[EstimatedCleanupElapsedTimeMinutes] [int] NULL,
	[EstimatedPatientInOutElapsedTimeMinutes] [int] NULL,
	[EstimatedSetupElapsedTimeMinutes] [int] NULL,
	[EstimatedTotalElapsedTimeMinutes] [int] NULL,
	[PatientVersionID] [int] NULL,
	[IsCostExpected] [bit] NULL,
	[ReferralDate] [datetime] NULL,
	[FirstConsultDate] [datetime] NULL,
	[OrigPriorityDesc] [varchar](50) NULL,
	[SurgRequiredElapsedTimeMinutes] [int] NULL,
	[ReferralToFirstConsultElapsedDay] [int] NULL,
	[FirstConsultToBkgCardElapsedDay] [int] NULL,
	[ExtractFileDate] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ORWaitListProfile]    Script Date: 6/4/2016 1:54:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ORWaitListProfile](
	[Site] [varchar](3) NULL,
	[FacilityLongName] [varchar](100) NULL,
	[ORRoomCode] [varchar](100) NULL,
	[ORLocation] [varchar](100) NULL,
	[ORType] [varchar](25) NULL,
	[ORLocationGroup] [varchar](25) NULL,
	[ORRoomGroup] [varchar](25) NULL,
	[CaseScheduledToOccurDate] [datetime] NULL,
	[ReferralDate] [datetime] NULL,
	[FirstConsultDate] [datetime] NULL,
	[BookingFormReceivedDate] [datetime] NULL,
	[DecisionDate] [datetime] NULL,
	[CaseEnteredInORMISDate] [datetime] NULL,
	[FiscalYear] [char](5) NULL,
	[FiscalPeriod] [varchar](20) NULL,
	[StatIndicator] [varchar](15) NULL,
	[CaseModifiedDate] [datetime] NULL,
	[PatientStatusDetail] [varchar](10) NULL,
	[PatientStatusRollup] [char](1) NULL,
	[SurgeryPriorityDesc] [varchar](100) NULL,
	[IsSPRCase] [bit] NULL,
	[ScheduledSurgeryStartDateTime] [datetime] NULL,
	[ScheduledSurgeryStopDateTime] [datetime] NULL,
	[FullCode] [char](6) NULL,
	[DiagnosisDescription] [varchar](500) NULL,
	[DXDescription70] [varchar](100) NULL,
	[DxTargetInWeeks] [varchar](50) NULL,
	[PreopDx] [varchar](255) NULL,
	[ScheduledMainSurgeonName] [varchar](50) NULL,
	[ScheduledORServiceId] [int] NULL,
	[ServiceCode] [varchar](10) NULL,
	[ServiceDescription] [varchar](100) NULL,
	[ScheduledPx1Desc] [varchar](500) NULL,
	[ScheduledSPRPx1Desc] [varchar](500) NULL,
	[ScheduledPx2Desc] [varchar](500) NULL,
	[ScheduledSPRPx2Desc] [varchar](500) NULL,
	[ScheduledPx3Desc] [varchar](500) NULL,
	[ScheduledSPRPx3Desc] [varchar](500) NULL,
	[ScheduledPx4Desc] [varchar](500) NULL,
	[ScheduledSPRPx4Desc] [varchar](500) NULL,
	[ScheduledPx5Desc] [varchar](500) NULL,
	[ScheduledSPRPx5Desc] [varchar](500) NULL,
	[EstimatedLOS_days] [int] NULL,
	[IsICUbed] [bit] NULL,
	[PayorDescription] [varchar](50) NULL,
	[IsSwingRoom] [bit] NULL,
	[SchedPxCount] [smallint] NULL,
	[Anesthesia] [varchar](50) NULL,
	[IsCaseLogged] [bit] NULL,
	[UnavailableFromDate1] [datetime] NULL,
	[UnavailableToDate1] [datetime] NULL,
	[UnavailableReason1Code] [varchar](20) NULL,
	[UnavailableFromDT2] [datetime] NULL,
	[UnavailableToDate2] [datetime] NULL,
	[UnavailableReason2Code] [varchar](20) NULL,
	[UnavailableFromDate3] [datetime] NULL,
	[UnavailableToDate3] [datetime] NULL,
	[UnavailableReason3Code] [varchar](20) NULL,
	[CancerStatusCode] [varchar](20) NULL,
	[IsCancerAssess] [bit] NULL,
	[ClinStage] [varchar](50) NULL,
	[IsCancRecur] [bit] NULL,
	[ScheduledSetupStartDateTime] [datetime] NULL,
	[ScheduledSetupStopDateTime] [datetime] NULL,
	[ScheduledPatientInRoomDateTime] [datetime] NULL,
	[ScheduledPatientOutRoomDateTime] [datetime] NULL,
	[ScheduledCleanupStartDateTime] [datetime] NULL,
	[ScheduledCleanupStopDateTime] [datetime] NULL,
	[ORPx1SideCode] [varchar](35) NULL,
	[ORPx2SideCode] [varchar](35) NULL,
	[ORPx3SideCode] [varchar](35) NULL,
	[ORPx4SideCode] [varchar](35) NULL,
	[ORPx5SideCode] [varchar](35) NULL,
	[ExtractFileDate] [datetime] NULL,
	[GenderDesc] [varchar](25) NULL,
	[LocalHealthAuthority] [varchar](100) NULL,
	[ServiceDeliveryArea] [varchar](100) NULL,
	[HealthAuthority] [varchar](50) NULL,
	[Age] [smallint] NULL,
	[CIHIAgeGroup2] [varchar](20) NULL,
	[BirthYear] [int] NULL,
	[UnavailableElapsedDay1] [int] NULL,
	[UnavailableElapsedDay2] [int] NULL,
	[UnavailableElapsedDay3] [int] NULL,
	[ScheduledSurgeryElapsedTimeMinutes] [int] NULL,
	[ScheduledSetupElapsedTimeMinutes] [int] NULL,
	[ScheduledPatientInOutElapsedTimeMinutes] [int] NULL,
	[ScheduledCleanupElapsedTimeMinutes] [int] NULL,
	[ReferralToFirstConsultElapsedDay] [int] NULL,
	[FirstConsultToBkgCardElapsedDay] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[PatientContProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[PatientContProfile](
	[SourceFactTable] [varchar](100) NULL,
	[SourceDate] [int] NULL,
	[EDAdmit] [bit] NULL,
	[FacilityID] [smallint] NULL,
	[ServiceEndDate] [int] NULL,
	[SourceGroup] [varchar](255) NULL,
	[IsKnownToHCC] [bit] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[PharmaAdmin1Profile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[PharmaAdmin1Profile](
	[FacilityCode] [varchar](50) NULL,
	[FacilityName] [varchar](50) NULL,
	[DateID] [int] NULL,
	[TransferType] [varchar](50) NULL,
	[TransactionBillingTimestamp] [varchar](50) NULL,
	[NursingCenter] [varchar](50) NULL,
	[CostCenter] [varchar](50) NULL,
	[ICDCode] [varchar](50) NULL,
	[OMNIID] [varchar](50) NULL,
	[OMNIName] [varchar](50) NULL,
	[UserID] [varchar](50) NULL,
	[UserName] [varchar](50) NULL,
	[WitnessID] [varchar](50) NULL,
	[WitnessName] [varchar](50) NULL,
	[IsAlergy] [varchar](50) NULL,
	[IsNullType] [varchar](50) NULL,
	[QuantityIssued] [varchar](50) NULL,
	[QuantityOnhand] [varchar](50) NULL,
	[QuantityWasted] [varchar](50) NULL,
	[QuantityRequested] [varchar](50) NULL,
	[QuantityCountedback] [varchar](50) NULL,
	[IsIssuedToDischargedPatients] [varchar](50) NULL,
	[IsMedicationOverridden] [varchar](50) NULL,
	[ReturnReason] [varchar](50) NULL,
	[DoseAmount] [varchar](50) NULL,
	[ActualDoseAmount] [varchar](50) NULL,
	[IsDoseTransaction] [varchar](50) NULL,
	[IsItemScanType] [varchar](50) NULL,
	[IsItemScanOverride] [varchar](50) NULL,
	[TotalItemQuantityOnhand] [varchar](50) NULL,
	[MedicationScheduledTimestamp] [varchar](50) NULL,
	[IsAlertDispensingItem] [varchar](50) NULL,
	[FiscalYearlong] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[PharmaAdmin2Profile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[PharmaAdmin2Profile](
	[FacilityCode] [varchar](50) NULL,
	[FacilityName] [varchar](50) NULL,
	[PharmacyDescription] [varchar](50) NULL,
	[DateID] [varchar](50) NULL,
	[TransferType] [varchar](50) NULL,
	[ChargeID] [varchar](50) NULL,
	[UnitOfIssue] [varchar](50) NULL,
	[UnitCost] [varchar](50) NULL,
	[UnitPrice] [varchar](50) NULL,
	[SNTracking] [varchar](50) NULL,
	[IsWasteWitnessRequied] [varchar](50) NULL,
	[IsRestockWitnessRequired] [varchar](50) NULL,
	[IsAccessRestricted] [varchar](50) NULL,
	[IsMedicationOrderRequired] [varchar](50) NULL,
	[IsFirstDoseAtOrderStart] [varchar](50) NULL,
	[MedicationOrderPhysicianID] [varchar](50) NULL,
	[MedicationOrderPharmacistID] [varchar](50) NULL,
	[ComponentType] [varchar](50) NULL,
	[DrugCode] [varchar](50) NULL,
	[DrugName] [varchar](50) NULL,
	[DrugDose] [varchar](50) NULL,
	[DrugDoseMax] [varchar](50) NULL,
	[DrugDoseUnit] [varchar](50) NULL,
	[Route] [varchar](50) NULL,
	[DrugStrength] [varchar](50) NULL,
	[DrugStrengthUnit] [varchar](50) NULL,
	[DrugAdministrationAmount] [varchar](50) NULL,
	[Frequency] [varchar](50) NULL,
	[Interval] [varchar](50) NULL,
	[Duration] [varchar](50) NULL,
	[DosageForm] [varchar](50) NULL,
	[AdministrationTimes] [varchar](50) NULL,
	[DrugAdministrationUnits] [varchar](50) NULL,
	[IsMedicationOrderAlerted] [varchar](50) NULL,
	[DispensePackageMethod] [varchar](50) NULL,
	[DrugDoseUnits] [varchar](50) NULL,
	[IsMedicationEarlyWindow] [varchar](50) NULL,
	[IsMedicationLateWindow] [varchar](50) NULL,
	[MedicationScheduledDays] [varchar](50) NULL,
	[MedicationOrderingPhysianID] [varchar](50) NULL,
	[MedicationPSStatus] [varchar](50) NULL,
	[MedicationQuantity] [varchar](50) NULL,
	[MedicationOrderStatus] [varchar](50) NULL,
	[MedicationTotalVolumeUnits] [varchar](50) NULL,
	[MedicationTotalVolume] [varchar](50) NULL,
	[AdministrationInstructions] [varchar](50) NULL,
	[MedicationBaseVolumeAmount] [varchar](50) NULL,
	[MedicationBaseVolumeUnits] [varchar](50) NULL,
	[MedicationBaseDosageForm] [varchar](50) NULL,
	[ConcatPharmacyDosageSuffix] [varchar](50) NULL,
	[MedicationBaseStrength] [varchar](50) NULL,
	[MedicationBaseStrengthUnits] [varchar](50) NULL,
	[MedicationBaseTotalVolume] [varchar](50) NULL,
	[MedicationBaseTotalVolumeUnits] [varchar](50) NULL,
	[PRN] [varchar](50) NULL,
	[OrderStartTime] [varchar](50) NULL,
	[OrderEndTime] [varchar](50) NULL,
	[ItemControlLevel] [varchar](50) NULL,
	[ItemChargeType] [varchar](50) NULL,
	[TransactionType] [varchar](50) NULL,
	[TransactionSubType] [varchar](50) NULL,
	[TransactionDueType] [varchar](50) NULL,
	[FiscalYearLong] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ProfileComments]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ProfileComments](
	[ProfileCommentsID] [int] NOT NULL,
	[DatabaseID] [int] NULL,
	[ObjectID] [int] NULL,
	[ObjectAttributeID] [int] NULL,
	[ProfileObservation] [varchar](max) NULL,
	[BusinessKnowledge] [varchar](max) NULL,
 CONSTRAINT [PK_ProfileComments] PRIMARY KEY CLUSTERED 
(
	[ProfileCommentsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ProfileDefinition]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [DataProfile].[ProfileDefinition](
	[ProfileID] [int] IDENTITY(1,1) NOT NULL,
	[Environment] [varchar](50) NULL,
	[ProfileName] [varchar](50) NULL,
	[SourceTable] [varchar](50) NULL,
	[DestinationTable] [varchar](50) NULL,
	[FilterCriteria] [varchar](max) NULL,
	[SubjectAreaID] [int] NULL,
	[IsActive] [bit] NULL,
	[IncludeColNullProfile] [bit] NULL,
	[IncludeColStatisticsProfile] [bit] NULL,
	[IncludeValueDistributionProfile] [bit] NULL,
 CONSTRAINT [PK_ProfileDefinition] PRIMARY KEY CLUSTERED 
(
	[ProfileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [DataProfile].[ProfileSummary]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ProfileSummary](
	[ProfileSummaryID] [int] IDENTITY(1,1) NOT NULL,
	[ProfileID] [int] NULL,
	[NumOfRows] [int] NULL,
	[CreatedDT] [int] NULL,
	[CreatedDTTM] [datetime] NULL,
 CONSTRAINT [PK_ProfileSummary] PRIMARY KEY CLUSTERED 
(
	[ProfileSummaryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ValueDistribution]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ValueDistribution](
	[ValueDistributionsID] [bigint] IDENTITY(1,1) NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[NumberOfDistinctValues] [nvarchar](255) NULL,
	[Value] [nvarchar](1000) NULL,
	[CountOfValue] [nvarchar](255) NULL,
	[ProfileSummaryID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ValueDistributionsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [DataProfile].[ValueDistributionHistoric]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [DataProfile].[ValueDistributionHistoric](
	[ValueDistributionsID] [bigint] NOT NULL,
	[ColumnName] [nvarchar](255) NULL,
	[NumberOfDistinctValues] [nvarchar](255) NULL,
	[Value] [nvarchar](255) NULL,
	[CountOfValue] [nvarchar](255) NULL,
	[ProfileSummaryID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ValueDistributionsID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[AuditBizRuleAction4Execution]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AuditBizRuleAction4Execution](
	[BRID] [int] NOT NULL,
	[ExtractFileKey] [bigint] NOT NULL,
	[ActionSQL] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[AuditBizRuleExecution]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuditBizRuleExecution](
	[BRID] [int] NOT NULL,
	[ExecutionDate] [smalldatetime] NOT NULL,
	[ExtractFileKey] [bigint] NOT NULL,
	[ExecSequence] [bigint] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_AuditBizRuleExecution] PRIMARY KEY CLUSTERED 
(
	[ExecSequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[AuditDataCorrectionMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AuditDataCorrectionMapping](
	[SubjectAreaID] [int] NOT NULL,
	[BRID] [int] NOT NULL,
	[FactTableName] [varchar](100) NULL,
	[FactTableCorrectionFieldName] [varchar](100) NULL,
	[FacilityID] [int] NULL,
	[FactTableID] [int] NULL,
	[MapToID] [int] NULL,
	[Cases] [int] NULL,
	[DimTableName] [varchar](100) NULL,
	[DimCodeFieldName] [varchar](100) NULL,
	[DimDescFieldName] [varchar](100) NULL,
	[DimTableCode] [varchar](100) NULL,
	[DimTableDesc] [varchar](max) NULL,
	[PreviousValue] [varchar](100) NULL,
	[DataCorrectionMappingID] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[AuditExtractFile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AuditExtractFile](
	[ExtractFileKey] [bigint] IDENTITY(1,1) NOT NULL,
	[PkgExecKey] [bigint] NOT NULL CONSTRAINT [DF__AuditExtr__PkgEx__4AB81AF0]  DEFAULT ((0)),
	[ExtractFilePhysicalLocation] [varchar](250) NOT NULL,
	[ExtractFileProcessStartDT] [smalldatetime] NULL,
	[ExtractFileProcessStopDT] [smalldatetime] NULL,
	[ExtractFileCreatedDT] [smalldatetime] NULL,
	[IsProcessSuccess] [bit] NOT NULL CONSTRAINT [DF__AuditExtr__IsFil__4BAC3F29]  DEFAULT ((0)),
 CONSTRAINT [IDX1_AuditExtractFile_PK] PRIMARY KEY CLUSTERED 
(
	[ExtractFileKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[AuditFacilityQualityRating]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuditFacilityQualityRating](
	[FacilityID] [int] NULL,
	[QualityRatingID] [int] NULL,
	[RatingScore] [numeric](18, 2) NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[AuditPkgExecution]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AuditPkgExecution](
	[PkgExecKey] [bigint] IDENTITY(1,1) NOT NULL,
	[ParentPkgExecKey] [bigint] NULL CONSTRAINT [DF__AuditPkgE__Paren__00551192]  DEFAULT ((0)),
	[PkgName] [varchar](100) NOT NULL,
	[PkgKey] [int] NOT NULL CONSTRAINT [DF__AuditPkgE__PkgKe__014935CB]  DEFAULT ((0)),
	[PkgVersionMajor] [smallint] NULL CONSTRAINT [DF__AuditPkgE__PkgVe__023D5A04]  DEFAULT ((0)),
	[PkgVersionMinor] [smallint] NULL CONSTRAINT [DF__AuditPkgE__PkgVe__03317E3D]  DEFAULT ((0)),
	[ExecStartDT] [smalldatetime] NOT NULL,
	[ExecStopDT] [smalldatetime] NULL,
	[IsPackageSuccessful] [bit] NOT NULL CONSTRAINT [DF__AuditPkgE__IsPac__0425A276]  DEFAULT ((0))
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[AuditQualityRating]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AuditQualityRating](
	[QualityRatingID] [int] IDENTITY(1,1) NOT NULL,
	[SubjectAreaId] [bigint] NULL,
	[RatingName] [varchar](50) NULL,
	[RatingScore] [numeric](18, 3) NULL,
	[PopulationRatio] [numeric](18, 3) NULL,
	[RatioDescription] [varchar](max) NULL,
	[RatioUsage] [varchar](max) NULL,
	[CalculationDate] [smalldatetime] NULL,
	[PopulationFactTableName] [varchar](100) NULL,
	[IsActive] [bit] NULL CONSTRAINT [DF_AuditQualityRating_IsActive]  DEFAULT ((1)),
	[SourceGroupFilter] [varchar](100) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[AuditQulaityRatingBizRule]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuditQulaityRatingBizRule](
	[BRID] [int] NOT NULL,
	[QualityRatingID] [int] NOT NULL,
	[PopulationModifier] [decimal](18, 3) NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[AuditTableProcessing]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AuditTableProcessing](
	[TableProcessKey] [bigint] IDENTITY(1,1) NOT NULL,
	[PkgExecKey] [bigint] NOT NULL,
	[DatabaseName] [nvarchar](50) NOT NULL,
	[TableName] [nvarchar](100) NOT NULL,
	[ExtractRowCnt] [int] NOT NULL,
	[ExtractCheckValue1] [float] NULL,
	[ExtractCheckValue2] [float] NULL,
	[InsertStdRowCnt] [int] NOT NULL,
	[InsertStdCheckValue1] [float] NULL,
	[InsertStdCheckValue2] [float] NULL,
	[InsertNonStdRowCnt] [int] NOT NULL,
	[InsertNonStdCheckValue1] [float] NULL,
	[InsertNonStdCheckValue2] [float] NULL,
	[UpdateRowCnt] [int] NOT NULL,
	[ErrorRowCnt] [int] NOT NULL,
	[TableInitialRowCnt] [int] NOT NULL,
	[TableFinalRowCnt] [int] NOT NULL,
	[IsSuccessfulProcessing] [bit] NOT NULL,
	[IsSuccessfulASPProcessing] [bit] NOT NULL,
 CONSTRAINT [aaaaaAuditTableProcessing_PK] PRIMARY KEY NONCLUSTERED 
(
	[TableProcessKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DQMF_Action]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_Action](
	[ActionID] [int] NOT NULL,
	[ActionName] [varchar](50) NOT NULL,
	[ActionDescription] [varchar](max) NULL,
 CONSTRAINT [PK_DQMF_Action] PRIMARY KEY CLUSTERED 
(
	[ActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_BackFill]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DQMF_BackFill](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
	[LastProcessingDate] [smalldatetime] NOT NULL,
	[EndProcessingDate] [smalldatetime] NOT NULL,
	[BatchSize] [int] NULL,
 CONSTRAINT [PK_DQMF_BackFill] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DQMF_BizRule]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_BizRule](
	[BRId] [int] NOT NULL,
	[ShortNameOfTest] [varchar](100) NULL,
	[RuleDesc] [varchar](300) NULL,
	[ConditionSQL] [varchar](max) NULL,
	[ActionID] [int] NULL,
	[ActionSQL] [varchar](max) NULL,
	[OlsonTypeID] [int] NULL,
	[SeverityTypeID] [int] NULL,
	[Sequence] [int] NULL CONSTRAINT [DF__DQMF_BizR__Seque__20C1E124]  DEFAULT ((100)),
	[DefaultValue] [varchar](max) NULL,
	[DatabaseId] [int] NULL CONSTRAINT [DF__DQMF_BizR__Datab__21B6055D]  DEFAULT ((0)),
	[TargetObjectPhysicalName] [varchar](100) NULL,
	[TargetObjectAttributePhysicalName] [varchar](100) NULL,
	[SourceObjectPhysicalName] [varchar](100) NULL,
	[SourceAttributePhysicalName] [varchar](100) NULL,
	[IsActive] [bit] NULL CONSTRAINT [DF__DQMF_BizR__RuleS__24927208]  DEFAULT ((0)),
	[Comment] [varchar](1000) NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL CONSTRAINT [DF_DQMF_BizRule_UpdatedDT]  DEFAULT (getdate()),
	[IsLogged] [bit] NOT NULL CONSTRAINT [DF_DQMF_BizRule_IsLogged]  DEFAULT ((1)),
	[GUID] [varchar](200) NOT NULL,
	[FactTableObjectAttributeId] [int] NULL,
	[FactTableObjectAttributeName] [varchar](200) NULL,
	[SecondaryFactTableObjectAttributeId] [int] NULL,
	[SecondaryFactTableObjectAttributeName] [varchar](200) NULL,
	[BusinessKeyExpression] [varchar](500) NULL,
 CONSTRAINT [PK_DQMF_BizRule] PRIMARY KEY CLUSTERED 
(
	[BRId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_BizRuleLookupMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DQMF_BizRuleLookupMapping](
	[BRId] [int] NOT NULL,
	[JoinNumber] [int] NOT NULL,
	[SourceLookupExpression] [nvarchar](1000) NOT NULL,
	[DimensionLookupExpression] [nvarchar](1000) NOT NULL,
	[IsSourcePreviousValue] [bit] NOT NULL CONSTRAINT [DF_DQMF_BizRuleLookupMapping_IsSourcePreviousValue]  DEFAULT ((1)),
 CONSTRAINT [Pkc_DQMF_BizRuleLookupMapping] PRIMARY KEY CLUSTERED 
(
	[BRId] ASC,
	[JoinNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DQMF_BizRuleSchedule]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DQMF_BizRuleSchedule](
	[BRID] [int] NULL,
	[ScheduleID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DQMF_DataCorrectionMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_DataCorrectionMapping](
	[DataCorrectionMappingID] [int] IDENTITY(1,1) NOT NULL,
	[SubjectAreaID] [int] NOT NULL,
	[BRID] [int] NOT NULL,
	[PreviousValue] [varchar](100) NULL,
	[IsFacilityIDApplied] [bit] NOT NULL,
	[FacilityID] [int] NULL,
	[MapToID] [int] NOT NULL,
	[IsForDQ] [tinyint] NOT NULL,
	[IsFirstRun] [bit] NOT NULL,
	[IsActive] [tinyint] NULL,
	[SourceDecision] [varchar](400) NOT NULL,
	[ReferredTo] [varchar](100) NOT NULL,
	[IsEffectiveDateApplied] [bit] NOT NULL,
	[EffectiveStartDateID] [int] NULL,
	[EffectiveEndDateID] [int] NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDate] [smalldatetime] NOT NULL,
	[UpdatedBy] [varchar](50) NOT NULL,
	[UpdatedDate] [smalldatetime] NOT NULL,
	[ErrorReasonSkipMapping] [varchar](200) NULL,
	[SkipMappingStartDate] [smalldatetime] NULL,
 CONSTRAINT [PK_DQMF_DataCorrectionMapping] PRIMARY KEY CLUSTERED 
(
	[DataCorrectionMappingID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_DataCorrectionWorking]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_DataCorrectionWorking](
	[SubjectAreaID] [int] NULL,
	[BRID] [int] NULL,
	[IsFacilityIDApplied] [bit] NULL,
	[FacilityID] [int] NULL,
	[IsEffectiveDateApplied] [bit] NULL,
	[EffectiveStartDateID] [int] NULL,
	[EffectiveEndDateID] [int] NULL,
	[PreviousValue] [varchar](100) NULL,
	[MapToID] [int] NULL,
	[IsFirstRun] [bit] NULL,
	[UpdateTableName] [varchar](100) NULL,
	[UpdateFieldName] [varchar](100) NULL,
	[ObjectID] [int] NULL,
	[IsForDQ] [bit] NULL,
	[DataCorrectionMappingID] [int] NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_OlsonType]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_OlsonType](
	[OlsonTypeName] [varchar](50) NOT NULL,
	[OlsonTypeDescription] [varchar](max) NOT NULL,
	[SortOrder] [smallint] NOT NULL,
 CONSTRAINT [aaaaaDQMF_OlsonType_PK] PRIMARY KEY NONCLUSTERED 
(
	[OlsonTypeName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_Schedule]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_Schedule](
	[DQMF_ScheduleId] [int] IDENTITY(1,1) NOT NULL,
	[StageID] [int] NULL,
	[DatabaseId] [int] NOT NULL CONSTRAINT [DF__DQMF_Sche__Datab__36B12243]  DEFAULT ((0)),
	[TableId] [int] NOT NULL CONSTRAINT [DF__DQMF_Sche__Table__37A5467C]  DEFAULT ((0)),
	[PkgKey] [int] NOT NULL CONSTRAINT [DF__DQMF_Sche__PkgKe__38996AB5]  DEFAULT ((0)),
	[IsScheduleActive] [bit] NOT NULL CONSTRAINT [DF__DQMF_Sche__IsSch__398D8EEE]  DEFAULT ((0)),
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDT] [datetime] NOT NULL,
	[UpdatedBy] [varchar](50) NOT NULL,
	[UpdatedDT] [datetime] NOT NULL,
 CONSTRAINT [Pk_DQMFSchedule] PRIMARY KEY NONCLUSTERED 
(
	[DQMF_ScheduleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_Severity]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_Severity](
	[SeverityTypeID] [int] NOT NULL,
	[SeverityTypeName] [varchar](50) NOT NULL,
	[SeverityTypeDescription] [varchar](max) NOT NULL,
	[NegativeRating] [int] NOT NULL CONSTRAINT [DF__DQMF_Seve__Negat__44FF419A]  DEFAULT ((0)),
	[SortOrder] [smallint] NOT NULL CONSTRAINT [DF__DQMF_Seve__SortO__45F365D3]  DEFAULT ((0)),
 CONSTRAINT [PK_DQMF_Severity] PRIMARY KEY CLUSTERED 
(
	[SeverityTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[DQMF_Stage]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DQMF_Stage](
	[StageID] [int] IDENTITY(1,1) NOT NULL,
	[StageName] [varchar](50) NOT NULL,
	[StageDescription] [varchar](max) NOT NULL,
	[StageOrder] [smallint] NOT NULL CONSTRAINT [DF__DQMF_Stag__Stage__151B244E]  DEFAULT ((0)),
 CONSTRAINT [PK_DQMF_Stage] PRIMARY KEY CLUSTERED 
(
	[StageID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[dtproperties]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[dtproperties](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[objectid] [int] NULL,
	[property] [varchar](64) NOT NULL,
	[value] [varchar](255) NULL,
	[uvalue] [nvarchar](255) NULL,
	[lvalue] [image] NULL,
	[version] [int] NOT NULL,
 CONSTRAINT [pk_dtproperties] PRIMARY KEY CLUSTERED 
(
	[id] ASC,
	[property] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ETL_AuditControl]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ETL_AuditControl](
	[ETL_AuditControlRecord] [varchar](50) NOT NULL,
	[LastValueFor_ETLId] [bigint] NOT NULL CONSTRAINT [DF__ETL_Audit__LastV__5070F446]  DEFAULT ((0)),
 CONSTRAINT [aaaaaETL_AuditControl_PK] PRIMARY KEY NONCLUSTERED 
(
	[ETL_AuditControlRecord] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ETL_Package]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ETL_Package](
	[PkgID] [int] IDENTITY(1,1) NOT NULL,
	[PkgName] [varchar](100) NOT NULL,
	[PkgDescription] [varchar](max) NOT NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDT] [datetime] NOT NULL,
	[UpdatedBy] [varchar](50) NOT NULL,
	[UpdatedDT] [datetime] NOT NULL,
	[IsLocking] [bit] NULL,
	[isActive] [bit] NULL,
 CONSTRAINT [aaaaaETL_Package_PK] PRIMARY KEY NONCLUSTERED 
(
	[PkgID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ETL_PackageMapToSourceSystem]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ETL_PackageMapToSourceSystem](
	[PkgKey] [int] NOT NULL,
	[SourceSystemSeparator] [varchar](20) NULL,
	[SourceSystemCode] [varchar](20) NOT NULL,
	[SourceSystemName] [varchar](100) NOT NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDT] [datetime] NOT NULL,
	[UpdatedBy] [varchar](50) NOT NULL,
	[UpdatedDT] [datetime] NOT NULL,
	[PackageMapToSourceSystemID] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_ETL_PackageMapToSourceSystem] PRIMARY KEY CLUSTERED 
(
	[PackageMapToSourceSystemID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ETLBizruleAuditFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ETLBizruleAuditFact](
	[ETLId] [bigint] NULL,
	[DQMF_ScheduleId] [int] NOT NULL,
	[BRId] [int] NOT NULL,
	[DatebaseId] [int] NULL,
	[TableId] [int] NULL,
	[AttributeId] [int] NULL,
	[PreviousValue] [varchar](50) NULL,
	[NewValue] [varchar](50) NULL,
	[OlsonTypeID] [int] NULL,
	[ActionID] [int] NULL,
	[SeverityTypeID] [int] NULL,
	[NegativeRating] [tinyint] NULL,
	[ISCorrected] [bit] NULL,
	[PkgExecKey] [bigint] NULL,
	[ISFORDQ] [bit] NULL,
	[BusinessKey] [varchar](500) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ETLStagingRecord]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ETLStagingRecord](
	[ETLId] [bigint] NOT NULL,
	[PkgExecKey] [bigint] NOT NULL,
	[ExtractFileKey] [bigint] NOT NULL,
	[ProcessedDT] [datetime] NOT NULL,
	[MergedETLID] [bigint] NULL,
 CONSTRAINT [PK_ETLStagingRecord] PRIMARY KEY CLUSTERED 
(
	[ETLId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ETLStagingRecordQualityRating]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ETLStagingRecordQualityRating](
	[ETLAuditId] [bigint] NOT NULL,
	[QualityRatingId] [int] NOT NULL,
 CONSTRAINT [Pk_ETLStagingRecordQualityRating] PRIMARY KEY CLUSTERED 
(
	[ETLAuditId] ASC,
	[QualityRatingId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[FileLoadCount]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[FileLoadCount](
	[DataFeed] [varchar](8) NOT NULL,
	[ExtractFileProcessStartDT] [smalldatetime] NULL,
	[filekey] [int] NULL,
	[DQMFCount] [int] NULL,
	[DSDWCount] [int] NULL,
	[EDMARTCount] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_Attribute]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_Attribute](
	[AttributeID] [int] IDENTITY(548,1) NOT NULL,
	[AttributeDisplayName] [varchar](500) NOT NULL,
	[AttributeGroupName] [varchar](500) NULL,
	[AlternativeDescription] [varchar](500) NULL,
	[AttributeLongDescription] [varchar](2000) NULL,
	[DescriptionSource] [varchar](100) NULL,
	[AttibuteExampleValues] [varchar](max) NULL,
	[AttributeUsageTips] [varchar](2000) NULL,
	[AttributeStewardContact] [varchar](50) NULL,
	[ISConfidental] [bit] NULL,
	[ISActive] [bit] NULL,
	[IsInternalUse] [bit] NULL,
	[ISDecay] [bit] NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
	[AttributeAlias] [nvarchar](500) NULL,
 CONSTRAINT [PkcMD_Attribute] PRIMARY KEY CLUSTERED 
(
	[AttributeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_AttributeChapter]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_AttributeChapter](
	[AttributeChapterID] [int] NULL,
	[AttributeChapterName] [varchar](50) NULL,
	[AttributeChapterDesc] [varchar](100) NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreateDate] [smalldatetime] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_AttributeChapterAttribute]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MD_AttributeChapterAttribute](
	[AttributeChapterID] [int] NULL,
	[AttributeID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[MD_AttributeChapterObject]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MD_AttributeChapterObject](
	[AttributeChapterID] [int] NULL,
	[ObjectID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[MD_AttributeDetail]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_AttributeDetail](
	[AttributeDetailID] [int] IDENTITY(800,1) NOT NULL,
	[AttributeID] [int] NOT NULL,
	[AttributeDisplayName] [varchar](500) NOT NULL,
	[AttributeAlias] [nvarchar](500) NULL,
	[ISConfidental] [bit] NULL,
	[AttributeGroupName] [varchar](75) NULL,
	[AlternativeDescription] [varchar](250) NULL,
	[AttributeLongDescription] [varchar](2000) NULL,
	[DescriptionSource] [varchar](500) NULL,
	[AttibuteExampleValues] [varchar](max) NULL,
	[AttributeUsageTips] [varchar](2000) NULL,
	[AttributeStewardContact] [varchar](50) NULL,
	[ISActive] [bit] NULL,
	[IsInternalUse] [bit] NULL,
	[ISDecay] [bit] NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
 CONSTRAINT [PkcMD_AttributeDetail] PRIMARY KEY CLUSTERED 
(
	[AttributeDetailID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_Audit]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_Audit](
	[AuditID] [int] IDENTITY(1,1) NOT NULL,
	[UserName] [varchar](100) NULL,
	[Date] [datetime] NULL,
	[MD_Table] [varchar](100) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_Database]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_Database](
	[DatabaseId] [int] NOT NULL,
	[DatabaseName] [varchar](50) NOT NULL,
	[DatabaseShortDescription] [varchar](250) NOT NULL,
	[DatabaseLongDescription] [varchar](max) NULL,
	[DatabaseType] [varchar](50) NULL,
	[IsActive] [bit] NULL,
 CONSTRAINT [aaaaaMD_Database_PK] PRIMARY KEY NONCLUSTERED 
(
	[DatabaseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_DataLoadingDetail]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_DataLoadingDetail](
	[DataLoadingDetailID] [int] IDENTITY(1,1) NOT NULL,
	[SubjectArea] [varchar](100) NULL,
	[RecordSet] [varchar](100) NULL,
	[FactName] [varchar](100) NULL,
	[PackageName] [varchar](100) NULL,
	[FileName] [varchar](200) NULL,
	[LoadDate] [datetime] NULL,
	[KeyDateID] [int] NULL,
	[RecordCount] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_DataLoadingStructure]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_DataLoadingStructure](
	[DataLoadingID] [int] IDENTITY(1,1) NOT NULL,
	[SubjectArea] [varchar](100) NULL,
	[FactName] [varchar](100) NULL,
	[SDATable] [varchar](max) NULL,
	[DSDWTable] [varchar](max) NULL,
	[MartTable] [varchar](max) NULL,
	[SummaryDataQuery] [varchar](max) NULL,
	[RedLimit] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_Object]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_Object](
	[DatabaseId] [int] NOT NULL,
	[SubjectAreaID] [int] NOT NULL,
	[ObjectID] [int] NOT NULL,
	[ObjectDisplayName] [varchar](50) NOT NULL,
	[ObjectSchemaName] [varchar](50) NULL,
	[ObjectPhysicalName] [varchar](255) NULL,
	[ObjectPKField] [varchar](255) NULL,
	[ObjectType] [varchar](50) NOT NULL,
	[ObjectPurpose] [varchar](50) NOT NULL,
	[ObjectShortDescription] [varchar](250) NULL,
	[ObjectLongDescription] [varchar](2000) NULL,
	[ObjectUsageTips] [varchar](max) NULL,
	[ObjectStewardContact] [varchar](50) NULL,
	[LastRefreshDate] [datetime] NULL,
	[UpdateFrequency] [varchar](5) NULL,
	[ObjectOutputLocation] [varchar](1000) NULL,
	[ObjectOutputRecipients] [varchar](max) NULL,
	[IsActive] [bit] NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDT] [datetime] NOT NULL,
	[UpdatedBy] [nvarchar](50) NOT NULL,
	[UpdatedDT] [datetime] NOT NULL,
	[KeyDateObjectAttributeID] [int] NULL,
	[IsObjectInDB] [bit] NULL,
 CONSTRAINT [PkcMD_Object] PRIMARY KEY CLUSTERED 
(
	[ObjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_Object_Org]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_Object_Org](
	[DatabaseId] [int] NOT NULL,
	[SubjectAreaID] [int] NOT NULL,
	[ObjectID] [int] NOT NULL,
	[ObjectDisplayName] [varchar](50) NOT NULL,
	[ObjectSchemaName] [varchar](50) NULL,
	[ObjectPhysicalName] [varchar](255) NULL,
	[ObjectPKField] [varchar](255) NULL,
	[ObjectType] [varchar](50) NOT NULL,
	[ObjectPurpose] [varchar](50) NOT NULL,
	[ObjectShortDescription] [varchar](250) NULL,
	[ObjectLongDescription] [varchar](2000) NULL,
	[ObjectUsageTips] [varchar](max) NULL,
	[ObjectStewardContact] [varchar](50) NULL,
	[LastRefreshDate] [datetime] NULL,
	[UpdateFrequency] [varchar](5) NULL,
	[ObjectOutputLocation] [varchar](1000) NULL,
	[ObjectOutputRecipients] [varchar](max) NULL,
	[IsActive] [bit] NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDT] [datetime] NOT NULL,
	[UpdatedBy] [nvarchar](50) NOT NULL,
	[UpdatedDT] [datetime] NOT NULL,
	[KeyDateObjectAttributeID] [int] NULL,
	[IsObjectInDB] [bit] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_Object_Test]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_Object_Test](
	[DatabaseId] [int] NOT NULL,
	[SubjectAreaID] [int] NOT NULL,
	[ObjectID] [int] NOT NULL,
	[ObjectDisplayName] [varchar](50) NOT NULL,
	[ObjectSchemaName] [varchar](50) NULL,
	[ObjectPhysicalName] [varchar](255) NULL,
	[ObjectPKField] [varchar](255) NULL,
	[ObjectType] [varchar](50) NOT NULL,
	[ObjectPurpose] [varchar](50) NOT NULL,
	[ObjectShortDescription] [varchar](250) NULL,
	[ObjectLongDescription] [varchar](2000) NULL,
	[ObjectUsageTips] [varchar](max) NULL,
	[ObjectStewardContact] [varchar](50) NULL,
	[LastRefreshDate] [datetime] NULL,
	[UpdateFrequency] [varchar](5) NULL,
	[ObjectOutputLocation] [varchar](1000) NULL,
	[ObjectOutputRecipients] [varchar](max) NULL,
	[IsActive] [bit] NULL,
	[CreatedBy] [varchar](50) NOT NULL,
	[CreatedDT] [datetime] NOT NULL,
	[UpdatedBy] [nvarchar](50) NOT NULL,
	[UpdatedDT] [datetime] NOT NULL,
	[KeyDateObjectAttributeID] [int] NULL,
	[IsObjectInDB] [bit] NULL,
	[IsNewRecord] [int] NULL,
	[IsPKUpdated] [int] NULL,
	[IsObjectInDBUpdated] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_ObjectAttribute]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_ObjectAttribute](
	[ObjectID] [int] NOT NULL,
	[ObjectAttributeID] [int] NOT NULL,
	[AttributeID] [int] NOT NULL,
	[AttributeDetailID] [int] NULL,
	[Sequence] [smallint] NOT NULL,
	[AttributePhysicalName] [varchar](500) NULL,
	[Datatype] [varchar](50) NOT NULL,
	[AttributeLength] [smallint] NOT NULL,
	[AttibuteExampleValues] [varchar](max) NULL,
	[AttributeComment] [varchar](2000) NULL,
	[AttributeDefaultValue] [varchar](100) NULL,
	[AttributeETLRulesDescription] [varchar](max) NULL,
	[AttributeUsageTips] [varchar](max) NULL,
	[ISActive] [bit] NULL,
	[BaselineCreatedDT] [datetime] NULL,
	[BaselineIntegerMean] [bigint] NULL,
	[BaselineIntegerUpperControlLimit] [bigint] NULL,
	[BaselineIntegerLowerControlLimit] [bigint] NULL,
	[BaselineRealMean] [float] NULL,
	[BaselineRealUpperControlLimit] [float] NULL,
	[BaselineRealLowerControlLimit] [float] NULL,
	[PercentMissing] [numeric](10, 2) NULL,
	[ContentMap] [varchar](max) NULL,
	[QualityIndicator] [int] NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
	[FKTableObjectID] [bigint] NULL,
 CONSTRAINT [PkcMD_ObjectAttribute] PRIMARY KEY CLUSTERED 
(
	[ObjectAttributeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_ObjectAttribute_Org]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_ObjectAttribute_Org](
	[ObjectID] [int] NOT NULL,
	[ObjectAttributeID] [int] NOT NULL,
	[AttributeID] [int] NOT NULL,
	[AttributeDetailID] [int] NULL,
	[Sequence] [smallint] NOT NULL,
	[AttributePhysicalName] [varchar](500) NULL,
	[Datatype] [varchar](50) NOT NULL,
	[AttributeLength] [smallint] NOT NULL,
	[AttibuteExampleValues] [varchar](max) NULL,
	[AttributeComment] [varchar](2000) NULL,
	[AttributeDefaultValue] [varchar](100) NULL,
	[AttributeETLRulesDescription] [varchar](max) NULL,
	[AttributeUsageTips] [varchar](max) NULL,
	[ISActive] [bit] NULL,
	[BaselineCreatedDT] [datetime] NULL,
	[BaselineIntegerMean] [bigint] NULL,
	[BaselineIntegerUpperControlLimit] [bigint] NULL,
	[BaselineIntegerLowerControlLimit] [bigint] NULL,
	[BaselineRealMean] [float] NULL,
	[BaselineRealUpperControlLimit] [float] NULL,
	[BaselineRealLowerControlLimit] [float] NULL,
	[PercentMissing] [numeric](10, 2) NULL,
	[ContentMap] [varchar](max) NULL,
	[QualityIndicator] [int] NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
	[FKTableObjectID] [bigint] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_ObjectAttribute_Test]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_ObjectAttribute_Test](
	[ObjectID] [int] NOT NULL,
	[ObjectAttributeID] [int] NOT NULL,
	[AttributeID] [int] NOT NULL,
	[AttributeDetailID] [int] NULL,
	[Sequence] [smallint] NOT NULL,
	[AttributePhysicalName] [varchar](500) NULL,
	[Datatype] [varchar](50) NOT NULL,
	[AttributeLength] [smallint] NOT NULL,
	[AttibuteExampleValues] [varchar](max) NULL,
	[AttributeComment] [varchar](2000) NULL,
	[AttributeDefaultValue] [varchar](100) NULL,
	[AttributeETLRulesDescription] [varchar](max) NULL,
	[AttributeUsageTips] [varchar](max) NULL,
	[ISActive] [bit] NULL,
	[BaselineCreatedDT] [datetime] NULL,
	[BaselineIntegerMean] [bigint] NULL,
	[BaselineIntegerUpperControlLimit] [bigint] NULL,
	[BaselineIntegerLowerControlLimit] [bigint] NULL,
	[BaselineRealMean] [float] NULL,
	[BaselineRealUpperControlLimit] [float] NULL,
	[BaselineRealLowerControlLimit] [float] NULL,
	[PercentMissing] [numeric](10, 2) NULL,
	[ContentMap] [varchar](max) NULL,
	[QualityIndicator] [int] NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
	[FKTableObjectID] [bigint] NULL,
	[IsNewRecord] [int] NULL,
	[IsActiveUpdated] [int] NULL,
	[IsADSUpdated] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_SignificantEvent]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_SignificantEvent](
	[SignificantEventID] [bigint] IDENTITY(1,1) NOT NULL,
	[SubjectAreID] [bigint] NOT NULL,
	[EventShortDescription] [varchar](50) NULL,
	[EventLongDescription] [varchar](2000) NOT NULL,
	[EventStartDate] [smalldatetime] NOT NULL,
	[EventEndDate] [smalldatetime] NULL,
	[Category] [varchar](50) NULL,
	[COMMENT] [varchar](max) NULL,
	[IsActive] [bit] NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
 CONSTRAINT [MD_SignificantEvent_PK] PRIMARY KEY NONCLUSTERED 
(
	[SignificantEventID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MD_SubjectArea]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[MD_SubjectArea](
	[DatabaseID] [int] NOT NULL,
	[SubjectAreaID] [int] NOT NULL,
	[SubjectAreaName] [varchar](50) NULL,
	[SubjectAreaShortDescription] [varchar](250) NULL,
	[SubjectAreaLongDescription] [ntext] NULL,
	[BusinessProcessArea] [varchar](50) NULL,
	[ISActive] [varchar](5) NULL,
	[SubjectAreaStewardContact] [varchar](50) NULL,
	[SubjectAreaBusinessContact] [varchar](500) NULL,
	[CreatedBy] [varchar](50) NULL,
	[CreatedDT] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDT] [datetime] NULL,
 CONSTRAINT [PkcMD_SubjectArea] PRIMARY KEY CLUSTERED 
(
	[SubjectAreaID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[User]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[User](
	[UserID] [int] NOT NULL,
	[Login] [varchar](200) NOT NULL,
	[FirstName] [varchar](200) NULL,
	[LastName] [varchar](200) NULL,
	[Title] [varchar](200) NULL,
	[Department] [varchar](200) NULL,
	[Entity] [varchar](200) NULL,
	[Phone] [varchar](200) NULL,
	[Email] [varchar](200) NULL,
	[Disable] [varchar](200) NULL,
	[DefaultDatabase] [varchar](200) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserGroup]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserGroup](
	[GroupID] [int] NOT NULL,
	[GroupName] [varchar](200) NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserGroupMembership]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserGroupMembership](
	[GroupMembershipID] [int] NOT NULL,
	[GroupID] [int] NOT NULL,
	[UserID] [int] NOT NULL,
	[MembershipStartDate] [datetime] NULL,
	[MembershipEndDate] [datetime] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UserObjectParameter]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserObjectParameter](
	[UserObjectParameterID] [int] NOT NULL,
	[ParameterName] [varchar](100) NULL,
	[DefaultValue] [varchar](max) NULL,
	[ParameterSQL] [varchar](max) NULL,
	[IsRestricted] [bit] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserObjectParameterObjectAttribute]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserObjectParameterObjectAttribute](
	[UserObjectParameterID] [int] NULL,
	[ObjectAttributeID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UserObjectParameterValue]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserObjectParameterValue](
	[UserObjectParameterValueID] [int] NOT NULL,
	[UserID] [int] NOT NULL,
	[DefaultValue] [varchar](max) NULL,
	[ConditionSQL] [varchar](max) NULL,
	[UserObjectParameterID] [int] NULL,
	[ObjectAttributeID] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [MD].[ReportData]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [MD].[ReportData](
	[ReportDataID] [int] IDENTITY(1,1) NOT NULL,
	[ReportName] [varchar](100) NULL,
	[DataSetName] [varchar](50) NULL,
	[DataSourceName] [varchar](50) NULL,
	[CommandText] [varchar](max) NULL,
	[UpdatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ReportDataID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  UserDefinedFunction [dbo].[fn_nums]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fn_nums](@n AS BIGINT) RETURNS TABLE
AS
RETURN
  WITH
  L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
  L1   AS(SELECT 1 AS c FROM L0 AS A, L0 AS B),
  L2   AS(SELECT 1 AS c FROM L1 AS A, L1 AS B),
  L3   AS(SELECT 1 AS c FROM L2 AS A, L2 AS B),
  L4   AS(SELECT 1 AS c FROM L3 AS A, L3 AS B),
  L5   AS(SELECT 1 AS c FROM L4 AS A, L4 AS B),
  Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY c) AS n FROM L5)
  SELECT n FROM Nums WHERE n <= @n;

GO
/****** Object:  UserDefinedFunction [dbo].[fn_SplitTSQL]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fn_SplitTSQL]
  (@string NVARCHAR(MAX), @separator NCHAR(1) = N',') RETURNS TABLE
AS
RETURN
  SELECT
    n - LEN(REPLACE(LEFT(array, n), @separator, '')) + 1 AS pos,
    SUBSTRING(array, n,
      CHARINDEX(@separator, array + @separator, n) - n) AS element
  FROM (SELECT @string AS array) AS D
    JOIN dbo.fn_Nums(LEN(@string))
      ON n <= LEN(array)
      AND SUBSTRING(@separator + array, n, 1) = @separator;

GO
/****** Object:  View [DataProfile].[vwADTCAdmitDischProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT TOP 10 * FROM [DataProfile].[vwADTCAdmitDischProfile]

CREATE VIEW [DataProfile].[vwADTCAdmitDischProfile]
AS

SELECT 
	 [Site] = f.[Site]
	,[FacilityId] = f.[FacilityId]
	,[FiscalYear] = COALESCE(a.FiscalYearLong,d.FiscalYearLong)

	,[AdjustedAdmissionFiscalYear] = a.FiscalYearLong
	,[AdjustedAdmissionDateId] = f.[AdjustedAdmissionDateId]
	,[AdjustedAdmissionTimeId] = f.[AdjustedAdmissionTimeId]

	,[AdjustedDischargeFiscalYear] = d.FiscalYearLong
	,[AdjustedDischargeDateId] = f.[AdjustedDischargeDateId]
	,[AdjustedDischargeTimeId] = f.[AdjustedDischargeTimeId]
	,[AdjustedDischargeDispositionId] = f.[AdjustedDischargeDispositionId]
	,[LOSDays] = f.[LOSDays]
	,[LOSDayId] = f.[LOSDayId]
	,[AccountTypeID] = f.[AccountTypeID]
	,[AdmissionGenderId] = f.[AdmissionGenderId]
	,[AdmissionAgeID] = f.[AdmissionAgeID]
	,[AdmissionFacilityID] = f.[AdmissionFacilityID]
	,[AdmissionNursingUnitId] = f.[AdmissionNursingUnitId]
	,[AdmissionNursingUnitFinanceMISID] = f.[AdmissionNursingUnitFinanceMISID]
	,[AdmissionRoom] = f.[AdmissionRoom]
	,[AdmissionBed] = f.[AdmissionBed]
	,[AdmittingDrId] = f.[AdmittingDrId]
	,[ArrivalModeCodeId] = f.[ArrivalModeCodeId]
	,[AdmissionSourceCodeId] = f.[AdmissionSourceCodeId]
	,[AdmissionCategoryCodeId] = f.[AdmissionCategoryCodeId]
	,[AdmissionAttendingDrId] = f.[AdmissionAttendingDrId]
	,[AdmissionPatientServiceCodeId] = f.[AdmissionPatientServiceCodeId]
	,[AdmissionAccountTypeId] = f.[AdmissionAccountTypeId]
	,[AdmissionAccountSubTypeId] = f.[AdmissionAccountSubTypeId]
	,[AdmissionPatientTeamId] = f.[AdmissionPatientTeamId]
	,[AdmissionAlertCodeId] = f.[AdmissionAlertCodeId]
	,[AdmissionInfectiousDiseaseCodeId] = f.[AdmissionInfectiousDiseaseCodeId]
	,[AdmissionReadmissionRiskFlagID] = f.[AdmissionReadmissionRiskFlagID]
	,[DischargeGenderId] = f.[DischargeGenderId]
	,[DischargeAgeId] = f.[DischargeAgeId]
	,[DischargeFacilityID] = f.[DischargeFacilityID]
	,[DischargeNursingUnitId] = f.[DischargeNursingUnitId]
	,[DischargeRoom] = f.[DischargeRoom]
	,[DischargeBed] = f.[DischargeBed]
	,[DischargeDispositionCodeId] = f.[DischargeDispositionCodeId]
	,[DischargeAttendingDrId] = f.[DischargeAttendingDrId]
	,[DischargePatientServiceCodeId] = f.[DischargePatientServiceCodeId]
	,[DischargeAccountTypeId] = f.[DischargeAccountTypeId]
	,[DischargeAccountSubTypeId] = f.[DischargeAccountSubTypeId]
	,[DischargePatientTeamId] = f.[DischargePatientTeamId]
	,[DischargeAlertCodeId] = f.[DischargeAlertCodeId]
	,[DischargeInfectiousDiseaseCodeId] = f.[DischargeInfectiousDiseaseCodeId]
	,[DischargeReadmissionRiskFlagID] = f.[DischargeReadmissionRiskFlagID]
	,[IsTrauma] = f.[IsTrauma]
	,[DischargePayor1ID] = f.[DischargePayor1ID]
	,[DischargePayor2ID] = f.[DischargePayor2ID]
	,[DischargePayor3ID] = f.[DischargePayor3ID]

	,[AdjustedGenderId] = f.[AdjustedGenderId]
	,[AdjustedBirthDateId] = pt.[AdjustedBirthDateId]
	,[FamilyDoctorName] = pt.[FamilyDoctorName]
	,[FamilyDoctorCode] = pt.[FamilyDoctorCode]
	,[IsHomeless] = pt.[IsHomeless]
	,[IsHomeless_PHC] = pt.[IsHomeless_PHC]
	,[AdjustedPostalCodeID] = pt.[AdjustedPostalCodeID]
	,[LHAID] = f.[LHAID]
	
  FROM [ADTCMart].[ADTC].[AdmissionDischargeFact] f
  INNER JOIN [ADTCMart].[Secure].[ADTCPatientFactView] pt ON pt.ETLAuditId = f.ETLAuditId
  LEFT JOIN [ADTCMart].[Dim].[Date] a ON a.DateID = f.AdjustedAdmissionDateID
  LEFT JOIN [ADTCMart].[Dim].[Date] d ON d.DateID = f.AdjustedDischargeDateID


GO
/****** Object:  View [DataProfile].[vwADTCCensusProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT TOP 10 * FROM [DataProfile].[vwADTCCensusProfile]

CREATE VIEW [DataProfile].[vwADTCCensusProfile]
AS
  
SELECT 
	 [Site] = f.[Site]
	,[FacilityId] = f.[FacilityId]
	,[FiscalYear] = d.[FiscalYearLong]
	,[CensusDateID] = f.[CensusDateID]
	,[IsSameDay] = f.[IsSameDay]
	,[IsOutsideRelevantRange] = f.[IsOutsideRelevantRange]
	,[AdmitToCensusDays] = f.[AdmitToCensusDays]
	,[AdmitToCensusDayID] = f.[AdmitToCensusDayID]
	,[NursingUnitID] = f.[NursingUnitID]
	,[Bed] = f.[Bed]
	,[Room] = f.[Room]
	,[AttendDoctorID] = f.[AttendDoctorID]
	,[PatientServiceCodeID] = f.[PatientServiceCodeID]
	,[IsOutpatient] = f.[IsOutpatient]
	,[AccountTypeID] = f.[AccountTypeID]
	,[AcctSubTypeID] = f.[AcctSubTypeID]
	,[PatientTeamID] = f.[PatientTeamID]
	,[AlertCodeID] = f.[AlertCodeID]
	,[InfectiousDiseaseCodeID] = f.[InfectiousDiseaseCodeID]
	,[ReadmissionRiskFlagID] = f.[ReadmissionRiskFlagID]
	,[IsTrauma] = f.[IsTrauma]
	,[AdjustedGenderID] = f.[AdjustedGenderID]
	,[AgeID] = f.[AgeID]
	,[LHAID] = f.[LHAID]

  FROM [ADTCMart].[ADTC].[CensusFact] f
  INNER JOIN [ADTCMart].[Dim].[Date] d ON d.DateID = f.CensusDateID
  

GO
/****** Object:  View [DataProfile].[vwADTCCombineActivityFlatProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT TOP 10 * FROM [DataProfile].[vwADTCCombineActivityFlatProfile]

CREATE VIEW [DataProfile].[vwADTCCombineActivityFlatProfile]
AS
  
SELECT 
	 [Site] = f.[Site]
	,[FromFacilityID] = f.[FromFacilityID]
	,[FacilityId] = f.[FacilityId]
	,[FiscalYear] = d.[FiscalYearLong]
	,[ActivityDateID] = f.[ActivityDateID]
	,[ActivityTimeID] = f.[ActivityTimeID]
	,[IsOutsideRelevantRange] = f.[IsOutsideRelevantRange]
	,[IsFacilityChange] = f.[IsFacilityChange]
	,[IsNursingUnitChange] = f.[IsNursingUnitChange]
	,[FromNursingUnitID] = f.[FromNursingUnitID]
	,[ToNursingUnitID] = f.[ToNursingUnitID]
	,[IsRoomChange] = f.[IsRoomChange]
	,[FromRoom] = f.[FromRoom]
	,[ToRoom] = f.[ToRoom]
	,[IsBedChange] = f.[IsBedChange]
	,[FromBed] = f.[FromBed]
	,[ToBed] = f.[ToBed]
	,[IsAccountTypeChange] = f.[IsAccountTypeChange]
	,[FromAccountTypeID] = f.[FromAccountTypeID]
	,[ToAccountTypeID] = f.[ToAccountTypeID]
	,[IsAccountSubTypeChange] = f.[IsAccountSubTypeChange]
	,[FromAccountSubTypeID] = f.[FromAccountSubTypeID]
	,[ToAccountSubTypeID] = f.[ToAccountSubTypeID]
	,[IsPatientServiceChange] = f.[IsPatientServiceChange]
	,[FromPatientServiceCodeID] = f.[FromPatientServiceCodeID]
	,[ToPatientServiceCodeID] = f.[ToPatientServiceCodeID]
	,[IsAttendingDrChange] = f.[IsAttendingDrChange]
	,[FromAttendingDrID] = f.[FromAttendingDrID]
	,[ToAttendingDrID] = f.[ToAttendingDrID]

  FROM [ADTCMart].[ADTC].[CombineActivityFlat] f
  INNER JOIN [ADTCMart].[Dim].[Date] d ON d.DateID = f.[ActivityDateID]
  

GO
/****** Object:  View [DataProfile].[vwADTCSDAMckStarAdmitProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [DataProfile].[vwADTCSDAMckStarAdmitProfile]
as
SELECT [AdmitCategory]
      ,[PatientType]
      ,[PatientTypeIndicator]
      ,[NursingUnit]
      ,[AdmitDrServ]
      ,[AttendDrServ]
      ,[PatientServ]
      ,[Gender]
      ,[StrAge]
      ,[FromFacility]
      ,[Facility]
      ,[ALCFlag]
      ,[ChiefComplaint]
      ,[IFDCode]
      ,[AdmitSource]
      ,[BirthDate]
      ,[NursingUnitDesc]
      ,[IsManualUpdate]
  FROM [DataProfile].[ADTCSDAMckStarAdmitProfile]

GO
/****** Object:  View [DataProfile].[vwADTCSDAMckStarCensusProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create view [DataProfile].[vwADTCSDAMckStarCensusProfile]
as
SELECT [AccountTypeID]
      ,[PatientServiceID]
      ,[IsTrauma]
      ,[FacilityID]
      ,[InfectiousDiseaseID]
      ,[PatientTeamID]
      ,[NursingUnitID]
      ,[Bed]
      ,[Room]
      ,[AttendDoctorID]
      ,[CensusDateID]
      ,[AcctSubTypeID]
      ,[LOSDayID]
      ,[AlertId]
      ,[FiscalYear]
  FROM [DataProfile].[ADTCMrtCensusProfile]


GO
/****** Object:  View [DataProfile].[vwADTCSDAMckStarDischProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create view [DataProfile].[vwADTCSDAMckStarDischProfile]
as
SELECT [NursingUnit]
      ,[PatientType]
      ,[PatientTypeIndicator]
      ,[PatientServ]
      ,[Gender]
      ,[StrAge]
      ,[AttendDrServ]
      ,[AdmitCategory]
      ,[AdmitDiagnosis]
      ,[DischargeStatus]
      ,[Facility]
      ,[MRSAFlag]
      ,[HCProvince]
      ,[NursingUnitDesc]
      ,[IsManualUpdate]
  FROM [DataProfile].[ADTCSDAMckStarDischProfile]


GO
/****** Object:  View [DataProfile].[vwADTCSDAMckStarTransProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [DataProfile].[vwADTCSDAMckStarTransProfile]
as

SELECT [Gender]
      ,[Age]
      ,[PatientType]
      ,[AdmitType]
      ,[StationCodeTransferFrom]
      ,[ClinicSiteFrom]
      ,[ServiceCodeFrom]
      ,[AttendDrServ]
      ,[StationCodeTransferTo]
      ,[ClinicSiteTo]
      ,[ServiceCodeTo]
      ,[AdmitDiagnosis]
      ,[MRSAFlag]
      ,[StationCodeTransferFromDesc]
      ,[StationCodeTransferToDesc]
      ,[IsManualUpdate]
  FROM [DataProfile].[ADTCSDAMckStarTransProfile]


GO
/****** Object:  View [DataProfile].[vwADTCTransferProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT TOP 10 * FROM [DataProfile].[vwADTCTransferProfile]

CREATE VIEW [DataProfile].[vwADTCTransferProfile]
AS
  
SELECT 
	 [Site] = f.[Site]
	,[FromFacilityID] = f.[FromFacilityID]
	,[FacilityId] = f.[FacilityId]
	,[FiscalYear] = d.[FiscalYearLong]
	,[TransferDateID] = f.[TransferDateID]
	,[TransferTimeID] = f.[TransferTimeID]
	,[TransferCreateDateID] = f.[TransferCreateDateID]
	,[TransferCreateTimeID] = f.[TransferCreateTimeID]
	,[IsSameDay] = f.[IsSameDay]
	,[IsOutsideRelevantRange] = f.[IsOutsideRelevantRange]
	,[IsLocationTransfer] = f.[IsLocationTransfer]
	,[FromNursingUnitID] = f.[FromNursingUnitID]
	,[ToNursingUnitID] = f.[ToNursingUnitID]
	,[IsBedTransfer] = f.[IsBedTransfer]
	,[FromRoom] = f.[FromRoom]
	,[ToRoom] = f.[ToRoom]
	,[FromBed] = f.[FromBed]
	,[ToBed] = f.[ToBed]
	,[FromPatientServiceCodeID] = f.[FromPatientServiceCodeID]
	,[ToPatientServiceCodeID] = f.[ToPatientServiceCodeID]
	,[AttendDoctorID] = f.[AttendDoctorID]
	,[IsOutpatient] = f.[IsOutpatient]
	,[AccountTypeID] = f.[AccountTypeID]
	,[AcctSubTypeID] = f.[AcctSubTypeID]
	,[PatientTeamID] = f.[PatientTeamID]
	,[AlertCodeId] = f.[AlertCodeId]
	,[InfectiousDiseaseCodeID] = f.[InfectiousDiseaseCodeID]
	,[ReadmissionRiskFlagID] = f.[ReadmissionRiskFlagID]
	,[AdjustedGenderID] = f.[AdjustedGenderID]
	,[AgeID] = f.[AgeID]
	,[LHAID] = f.[LHAID]

  FROM [ADTCMart].[ADTC].[TransferFact] f
  INNER JOIN [ADTCMart].[Dim].[Date] d ON d.DateID = f.TransferDateID
  

GO
/****** Object:  View [DataProfile].[vwCommunityServiceProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View [DataProfile].[vwCommunityServiceProfile]
as
SELECT [DateAcceptedForServiceID]
      ,[CaseOpenedDateID]
      ,[ServiceStartDateID]
      ,[ServiceEndDateID]
      ,[BedRefusalDateID]
      ,[TempRateReductionStartDateID]
      ,[TempRateReductionEndDateID]
      ,[TempRateReductionEffectiveDateID]
      ,[ServiceTypeID]
      ,[LocalReportingOfficeID]
      ,[ServiceDeliverySettingID]
      ,[ReferralSourceLookupID]
      ,F.[ProviderID]
      ,[IADLDifficultyScaleID]
      ,[CognitivePerformanceScaleID]
      ,[ADLSelfPerformanceScaleID]
      ,[MAPLeScoreID]
      ,[ClientGroupID]
      ,[ServiceProviderCategoryCodeID]
      ,[ReasonEndingServiceCodeID]
      ,[ResidentialCareDailyRateID]
      ,[DischargeDispositionCodeID]
      ,[ADLLongFormScale]
      ,[IADLInvolvementScale]
      ,[IsTempRateReduction]
      ,[TempRateReductionAmount]
      ,[AssistedLivingMonthlyCharge]
      ,[HomeSupportClientContribution]
      ,[IsCSILClient]
      ,[InterraiAssessmentID]
      ,[SourceSystemClientID]
      ,'' [SourceSystemServiceKey]
      ,[SourceCreatedDate]
      ,[ReferralReasonID]
      ,[ReferralPriorityID]
      ,[InterventionID ]
      ,[HomeSupportClusterID]
      ,[CHESSScaleID]
	  ,D.FiscalYearLong as FiscalYear
	  ,P.FacilityID
  FROM [DSDW].[Community].[ServiceFact] F
	left outer join DSDW.Dim.Date D on F.ServiceStartDateID = D.DateID
	left outer join DSDW.Dim.Provider P on F.ProviderID = P.ProviderID 
GO
/****** Object:  View [DataProfile].[vwCommunityServiceVisitProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View [DataProfile].[vwCommunityServiceVisitProfile]
as
SELECT [VisitDateID]
      ,[VisitTypeID]
      ,[ServiceHours]
      ,[ServiceDays]
      ,'' [SourceSystemClientID]
      ,[SourceSystemServiceKey]
      ,'' [SourceSystemActualKey]
      ,left(convert(varchar(10),[SourceCreatedDate],112),6) [SourceCreatedDate]
	  , D.FiscalYEarLong as FiscalYear
  FROM [DSDW].[Community].[ServiceVisitFact] F
	inner join DSDW.Dim.Date D on F.VisitDateID = D.DateID
GO
/****** Object:  View [DataProfile].[vwDADAbstractProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [DataProfile].[vwDADAbstractProfile]
as
SELECT [ChartNumber]
      ,[AcctNum]
      ,[PHN]
      ,[VisitHCN]
      ,[BatchYear]
      ,[BatchPeriod]
      ,[InstitutionNumberID]
      ,[FacilityID]
      ,[AdmitDateID]
      ,[AdmittimeID]
      ,[DischargeDateID]
      ,[DischargeTimeID]
      ,[LOSID]
      ,[LOSDaysID]
      ,[LOS]
      ,[AcuteDays]
      ,[ALCDays]
      ,[AccountTypeID]
      ,[LGHPatientTypeID]
      ,[ProvinceIssuingHCN]
      ,[VisitPayorID]
      ,[BirthDateID]
      ,[PatientAge]
      ,[GenderID]
      ,[PostalCode]
      ,[PostalCodeNA]
      ,[InstitutionToID]
      ,[InstToTypeID]
      ,[LGHInstitutionToID]
      ,[InstitutionFromID]
      ,[LGHInstitutionFromID]
      ,[InstFromTypeID]
      ,[DischargeDispositionID]
      ,[AdmissionCategoryID]
      ,[EntryID]
      ,[ReadmissionCategoryID]
      ,[ArrivalModeID]
      ,[MainPtServiceID]
      ,[VGHMainPtSubSvcID]
      ,[LeftERDateID]
      ,[LeftERTimeID]
      ,[ERWaitElapsedTimeID]
      ,[UnknownERDisTime]
      ,[AdmitNursingUnitID]
      ,[DischNursingUnitID]
      ,[InvoluntaryAdmit]
      ,[DeathInOR]
      ,[Autopsy]
      ,[BirthorAdmWeight]
      ,[Gestationinweeks]
      ,[MomBabyRec1]
      ,[MomBabyRec2]
      ,[MomBabyRec3]
      ,[MomBabyRec4]
      ,[MomBabyRec5]
      ,[CMGPlusID]
      ,[MCCPlusID]
      ,[ComorbidityLevelID]
      ,[AgeCategoryID]
      ,[ELOS]
      ,[FlaggedIntervCount]
      ,[IntervEventCount]
      ,[InterventOOHCount]
      ,[InptRIWAtypID]
      ,[InpatientRILevelID]
      ,[CaseWeight]
      ,[ReimbAcuLOS]
      ,[Trim]
      ,[TypicalRIW]
      ,[VendorAgeCat]
      ,[CMGStatusID]
      ,[OrganRetrievalPt]
      ,[ProjectNumber]
      ,[Liver]
      ,[Heart]
      ,[Pancreas]
      ,[PancIsletCells]
      ,[HeartValves]
      ,[Bowel]
      ,[Cornea]
      ,[Skin]
      ,[Bone]
      ,[Other]
      ,[PrivateClinicProviderId]
      ,[EDRegistrationDateID]
      ,[EDRegistrationTimeID]
      ,[MedReconciliationID]
      ,[MajorAmbClusterID]
      ,[CompAmbClassSysID]
      ,[AmbltryCostWeight]
      ,[VendMITTotalCount]
      ,[GlasgowComaScale]
      ,[TrsfrPtServ1ID]
      ,[TrsfrStartDate1ID]
      ,[TrsfrStartTime1ID]
      ,[TrsfrEndDate1ID]
      ,[TrsfrEndTime1ID]
      ,[TrsfrServiceDays1]
      ,[TrsfrPtServ2ID]
      ,[TrsfrStartDate2ID]
      ,[TrsfrStartTime2ID]
      ,[TrsfrEndDate2ID]
      ,[TrsfrEndTime2ID]
      ,[TrsfrServiceDays2]
      ,[TrsfrPtServ3ID]
      ,[TrsfrStartDate3ID]
      ,[TrsfrStartTime3ID]
      ,[TrsfrEndDate3ID]
      ,[TrsfrEndTime3ID]
      ,[TrsfrServiceDays3]
      ,[FactType]
      ,[MACID]
      ,[DischGFSNursingUnit]
      ,[AdmitGFSNursingUnit]
      ,[GFSPatientServiceCodeID]
      ,[GFSAdmitCategory]
      ,[GFSDischCategory]
      ,[GFSAdmitHealthUnit]
      ,[GFSDischHealthUnit]
      ,[MHFollowupForm]
      ,[MHFollowupDate]
      ,[MethodologyYear]
      ,[MethodologyVersion]
      ,[BatchNumber]
      ,[AbstractNumber]
      ,[DADTransactionID]
      ,[FICardioversionFlag]
      ,[FICellSaverFlag]
      ,[FIChemotherapyFlag]
      ,[FIDialysisFlag]
      ,[FIHeartResuscitationFlag]
      ,[FIInvasiveVentilationGE96Flag]
      ,[FIInvasiveVentilationLT96Flag]
      ,[FIFeedingTubeFlag]
      ,[FIParacentesisFlag]
      ,[FIParenteralNutritionFlag]
      ,[FIPleurocentesisFlag]
      ,[FIRadiotherapyFlag]
      ,[FITracheostomyFlag]
      ,[FIVascularAccessDeviceFlag]
      ,[FIBiopsyFlag]
      ,[FIEndoscopyFlag]
	  ,[AdmitLocationID]
	  ,[DischargeLocationID]
  FROM [ADRMart].[ADR].[AbstractFact]

GO
/****** Object:  View [DataProfile].[vwDADAcuteProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View [DataProfile].[vwDADAcuteProfile]
as
SELECT [FiscalYear]
      ,[FiscalYearLong]
      ,[BatchYear]
      ,[BatchPeriod]
      ,[AcuteDays]
      ,[ALCDays]
      ,[RIW]
      ,[DPG_RIW]
      ,[ELOS]
      ,[IsDeathInOR]
      ,[IsNewborn]
      ,[IsOncology]
      ,[IsTrauma]
      ,[IsUnplandRetToOR]
      ,[IsUnplandRetToAcute]
      ,[LOS]
      ,[TrimLOS]
      ,[LosMinusELOS]
      ,[LOSGrouping]
      ,[CMGPlus_ComorbidityLevel]
      ,[CMGPlus_FlaggedInterventionCount]
      ,[CMGPlus_InterventionEventCount]
      ,[CMGPlus_InterventionOOHCount]
      ,left(convert(varchar(10),[AdmissionDate],112),6) [AdmissionDate]
      ,[AdmissionTime]
      ,[AdmissionNurseUnitCode]
      ,[AdmissionNurseUnitDesc]
      ,[admissionCategoryCode]
      ,[AdmissionCategoryDescription]
      ,[AdmitDrServ]
      ,[AdmitPtProgSrv]
      ,[AnesthesiaCode]
      ,[AnesthesiaDesc]
      ,[CMGCode]
      ,[CMGDesc]
      ,[CMGGradeAssignment]
      ,[CMGSubGradeAssignment]
      ,[CMGPlusRILCode]
      ,[CMGPlusRILDescription]
      ,[DischargeDate]
      ,[DischargeTime]
      ,[DischargeDispositionCode]
      ,[DischargeDispositionDescription]
      ,[DrCode]
      ,[DrName]
      ,[DrService]
      ,[DrServiceGroup]
      ,[EntryCode]
      ,[EntryCodeDesc]
      ,[Gender]
      ,[InstitutionName]
      ,[InstitutionNum]
      ,[ToInstitutionName]
      ,[ToInstitutionNum]
      ,[FromInstitutionName]
      ,[FromInstitutionNum]
      ,[MainPtServ]
      ,[MainPtServDesc]
      ,[SubServiceCode]
      ,[SubServiceDesc]
      ,[MCC]
      ,[MCCDesc]
      ,[NurseUnitCode]
      ,[NurseUnitDesc]
      ,[ProxyTertiaryCode]
      ,[ProxyTertiaryDesc]
      ,[ReAdmissionCode]
      ,[ReAdmissionDesc]
      ,[StatusTypeCode]
      ,[StatusTypeDesc]
      ,[StatusTypeTypical]
      ,[TrsfrPtServ1]
      ,[TrsfrPtServ1Desc]
      ,[TrsfrPtServ2]
      ,[TrsfrPtServ2Desc]
      ,[TrsfrPtServ3]
      ,[TrsfrPtServ3Desc]
      ,[LHAName]
      ,[HSDAName]
      ,[HealthAuthorityName]
      ,[Age]
      ,[CMGPlusAgeGroup]
      ,[Px1Code]
      ,[Px1Desc]
      ,left(convert(varchar(10),[PXDate1],112),6) [PXDate1]
      ,[Px2Code]
      ,[Px2Desc]
      ,left(convert(varchar(10),[PXDate2],112),6) [PXDate2]
      ,[Px3Code]
      ,[Px3Desc]
      ,left(convert(varchar(10),[PXDate3],112),6) [PXDate3]
      ,[Px4Code]
      ,[Px4Desc]
      ,left(convert(varchar(10),[PXDate4],112),6) [PXDate4]
      ,[Px5Code]
      ,[Px5Desc]
      ,left(convert(varchar(10),[PXDate5],112),6) [PXDate5]
      ,[Px6Code]
      ,[Px6Desc]
      ,left(convert(varchar(10),[PXDate6],112),6) [PXDate6]
      ,[Px7Code]
      ,[Px7Desc]
      ,left(convert(varchar(10),[PXDate7],112),6) [PXDate7]
      ,[Px8Code]
      ,[Px8Desc]
      ,left(convert(varchar(10),[PXDate8],112),6) [PXDate8]
      ,[Px9Code]
      ,[Px9Desc]
      ,left(convert(varchar(10),[PXDate9],112),6) [PXDate9]
      ,[Px10Code]
      ,[Px10Desc]
      ,left(convert(varchar(10),[PXDate10],112),6) [PXDate10]
      ,[Px11Code]
      ,[Px11Desc]
      ,left(convert(varchar(10),[PXDate11],112),6) [PXDate11]
      ,[Px12Code]
      ,[Px12Desc]
      ,left(convert(varchar(10),[PXDate12],112),6) [PXDate12]
      ,[Px13Code]
      ,[Px13Desc]
      ,left(convert(varchar(10),[PXDate13],112),6) [PXDate13]
      ,[Px14Code]
      ,[Px14Desc]
      ,left(convert(varchar(10),[PXDate14],112),6) [PXDate14]
      ,[Px15Code]
      ,[Px15Desc]
      ,left(convert(varchar(10),[PXDate15],112),6) [PXDate15]
      ,[Px16Code]
      ,[Px16Desc]
      ,left(convert(varchar(10),[PXDate16],112),6) [PXDate16]
      ,[Px17Code]
      ,[Px17Desc]
      ,left(convert(varchar(10),[PXDate17],112),6) [PXDate17]
      ,[Px18Code]
      ,[Px18Desc]
      ,left(convert(varchar(10),[PXDate18],112),6) [PXDate18]
      ,[Px19Code]
      ,[Px19Desc]
      ,left(convert(varchar(10),[PXDate19],112),6) [PXDate19]
      ,[Px20Code]
      ,[Px20Desc]
      ,left(convert(varchar(10),[PXDate20],112),6) [PXDate20]
      ,[Dx1Code]
      ,[Dx1Desc]
      ,[DXType1]
      ,[Dx2Code]
      ,[Dx2Desc]
      ,[DXType2]
      ,[Dx3Code]
      ,[Dx3Desc]
      ,[DXType3]
      ,[Dx4Code]
      ,[Dx4Desc]
      ,[DXType4]
      ,[Dx5Code]
      ,[Dx5Desc]
      ,[DXType5]
      ,[Dx6Code]
      ,[Dx6Desc]
      ,[DXType6]
      ,[Dx7Code]
      ,[Dx7Desc]
      ,[DXType7]
      ,[Dx8Code]
      ,[Dx8Desc]
      ,[DXType8]
      ,[Dx9Code]
      ,[Dx9Desc]
      ,[DXType9]
      ,[Dx10Code]
      ,[Dx10Desc]
      ,[DXType10]
      ,[Dx11Code]
      ,[Dx11Desc]
      ,[DXType11]
      ,[Dx12Code]
      ,[Dx12Desc]
      ,[DXType12]
      ,[Dx13Code]
      ,[Dx13Desc]
      ,[DXType13]
      ,[Dx14Code]
      ,[Dx14Desc]
      ,[DXType14]
      ,[Dx15Code]
      ,[Dx15Desc]
      ,[DXType15]
      ,[Dx16Code]
      ,[Dx16Desc]
      ,[DXType16]
      ,[Dx17Code]
      ,[Dx17Desc]
      ,[DXType17]
      ,[Dx18Code]
      ,[Dx18Desc]
      ,[DXType18]
      ,[Dx19Code]
      ,[Dx19Desc]
      ,[DXType19]
      ,[Dx20Code]
      ,[Dx20Desc]
      ,[DXType20]
      ,[Dx21Code]
      ,[Dx21Desc]
      ,[DXType21]
      ,[Dx22Code]
      ,[Dx22Desc]
      ,[DXType22]
      ,[Dx23Code]
      ,[Dx23Desc]
      ,[DXType23]
      ,[Dx24Code]
      ,[Dx24Desc]
      ,[DXType24]
      ,[Dx25Code]
      ,[Dx25Desc]
      ,[DXType25]
      ,[SCU1Code]
      ,[SCUDays1]
      ,[SCUHours1]
      ,[SCUAdmitTime1]
      ,[SCUDischTime1]
      ,[IsSCUDeath1]
      ,[SCU2Code]
      ,[SCUDays2]
      ,[SCUHours2]
      ,[SCUAdmitTime2]
      ,[SCUDischTime2]
      ,[IsSCUDeath2]
      ,[SCU3Code]
      ,[SCUDays3]
      ,[SCUHours3]
      ,[SCUAdmitTime3]
      ,[SCUDischTime3]
      ,[IsSCUDeath3]
      ,[SCU4Code]
      ,[SCUDays4]
      ,[SCUHours4]
      ,[SCUAdmitTime4]
      ,[SCUDischTime4]
      ,[IsSCUDeath4]
      ,[SCU5Code]
      ,[SCUDays5]
      ,[SCUHours5]
      ,[SCUAdmitTime5]
      ,[SCUDischTime5]
      ,[IsSCUDeath5]
      ,[SCU6Code]
      ,[SCUDays6]
      ,[SCUHours6]
      ,[SCUAdmitTime6]
      ,[SCUDischTime6]
      ,[IsSCUDeath6]
      ,[MRCareProgramCode]
      ,[MRCareTeamCode]
      ,[MedReconciliation]
  FROM [ADRMart].[dbo].[AcuteFullDADView]
GO
/****** Object:  View [DataProfile].[vwDADDaycareProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [DataProfile].[vwDADDaycareProfile]
as
SELECT [FiscalYear]
      ,[FiscalYearLong]
      ,[BatchYear]
      ,[BatchPeriod]
      ,[RIW]
      ,[DPG_RIW]
      ,[LOS]
      ,[LOSHours]
      ,[IsDeathInOR]
      ,left(convert(varchar(10),[AdmissionDate],112),6)  [AdmissionDate]
      ,[AdmissionTime]
      ,[AdmissionNurseUnitCode]
      ,[AdmissionNurseUnitDesc]
      ,[admissionCategoryCode]
      ,[AdmissionCategoryDescription]
      ,[AdmitDrServ]
      ,[AnesthesiaCode]
      ,[AnesthesiaDesc]
      ,[DPGCode]
      ,[DPGDesc]
      ,[DischargeDate]
      ,[DischargeTime]
      ,[DischargeDispositionCode]
      ,[DischargeDispositionDescription]
      ,[DrCode]
      ,[DrName]
      ,[DrService]
      ,[DrServiceGroup]
      ,[EntryCode]
      ,[EntryCodeDesc]
      ,[Gender]
      ,[InstitutionName]
      ,[InstitutionNum]
      ,[ToInstitutionName]
      ,[ToInstitutionNum]
      ,[FromInstitutionName]
      ,[FromInstitutionNum]
      ,[MainPtServ]
      ,[MainPtServDesc]
      ,[SubServiceCode]
      ,[SubServiceDesc]
      ,[MCC]
      ,[MCCDesc]
      ,[NurseUnitCode]
      ,[NurseUnitDesc]
      ,[LHAName]
      ,[HSDAName]
      ,[HealthAuthorityName]
      ,[Age]
      ,[CMGPlusAgeGroup]
      ,[Px1Code]
      ,[Px1Desc]
      ,[Px2Code]
      ,[Px2Desc]
      ,[Px3Code]
      ,[Px3Desc]
      ,[Px4Code]
      ,[Px4Desc]
      ,[Px5Code]
      ,[Px5Desc]
      ,[Px6Code]
      ,[Px6Desc]
      ,[Px7Code]
      ,[Px7Desc]
      ,[Px8Code]
      ,[Px8Desc]
      ,[Px9Code]
      ,[Px9Desc]
      ,[Px10Code]
      ,[Px10Desc]
      ,[Px11Code]
      ,[Px11Desc]
      ,[Px12Code]
      ,[Px12Desc]
      ,[Px13Code]
      ,[Px13Desc]
      ,[Px14Code]
      ,[Px14Desc]
      ,[Px15Code]
      ,[Px15Desc]
      ,[Px16Code]
      ,[Px16Desc]
      ,[Px17Code]
      ,[Px17Desc]
      ,[Px18Code]
      ,[Px18Desc]
      ,[Px19Code]
      ,[Px19Desc]
      ,[Px20Code]
      ,[Px20Desc]
      ,[Dx1Code]
      ,[Dx1Desc]
      ,[DXType1]
      ,[Dx2Code]
      ,[Dx2Desc]
      ,[DXType2]
      ,[Dx3Code]
      ,[Dx3Desc]
      ,[DXType3]
      ,[Dx4Code]
      ,[Dx4Desc]
      ,[DXType4]
      ,[Dx5Code]
      ,[Dx5Desc]
      ,[DXType5]
      ,[Dx6Code]
      ,[Dx6Desc]
      ,[DXType6]
      ,[Dx7Code]
      ,[Dx7Desc]
      ,[DXType7]
      ,[Dx8Code]
      ,[Dx8Desc]
      ,[DXType8]
      ,[Dx9Code]
      ,[Dx9Desc]
      ,[DXType9]
      ,[Dx10Code]
      ,[Dx10Desc]
      ,[DXType10]
      ,[Dx11Code]
      ,[Dx11Desc]
      ,[DXType11]
      ,[Dx12Code]
      ,[Dx12Desc]
      ,[DXType12]
      ,[Dx13Code]
      ,[Dx13Desc]
      ,[DXType13]
      ,[Dx14Code]
      ,[Dx14Desc]
      ,[DXType14]
      ,[Dx15Code]
      ,[Dx15Desc]
      ,[DXType15]
      ,[Dx16Code]
      ,[Dx16Desc]
      ,[DXType16]
      ,[Dx17Code]
      ,[Dx17Desc]
      ,[DXType17]
      ,[Dx18Code]
      ,[Dx18Desc]
      ,[DXType18]
      ,[Dx19Code]
      ,[Dx19Desc]
      ,[DXType19]
      ,[Dx20Code]
      ,[Dx20Desc]
      ,[DXType20]
      ,[Dx21Code]
      ,[Dx21Desc]
      ,[DXType21]
      ,[Dx22Code]
      ,[Dx22Desc]
      ,[DXType22]
      ,[Dx23Code]
      ,[Dx23Desc]
      ,[DXType23]
      ,[Dx24Code]
      ,[Dx24Desc]
      ,[DXType24]
      ,[Dx25Code]
      ,[Dx25Desc]
      ,[DXType25]
      ,[MRCareProgramCode]
      ,[MRCareTeamCode]
  FROM [ADRMart].[dbo].[DayCareFullDADView]
GO
/****** Object:  View [DataProfile].[vwDADPxProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [DataProfile].[vwDADPxProfile]
as

Select PxOrderNo,PXID,PxLocID,PxAttributeLocID,
	PxAttributeExtID,PxAttributeStatID,[PxDoctorID],
	PxAnesthesiaID,Left(PxDateID,6) PxMonth,IsPxUnplandRetToOR
from ADRMart.ADR.AbstractPxFact
GO
/****** Object:  View [DataProfile].[vwDADRehabProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
Create view [DataProfile].[vwDADRehabProfile]
as
SELECT [FiscalYear]
      ,[FiscalYearLong]
      ,[BatchYear]
      ,[BatchPeriod]
      ,[AcuteDays]
      ,[ALCDays]
      ,[RIW]
      ,[LOS]
      ,[LOSGrouping]
      ,[AdmissionDate]
      ,[AdmissionTime]
      ,[AdmissionNurseUnitCode]
      ,[AdmissionNurseUnitDesc]
      ,[admissionCategoryCode]
      ,[AdmissionCategoryDescription]
      ,[AdmitDrServ]
      ,[AnesthesiaCode]
      ,[AnesthesiaDesc]
      ,[DischargeDate]
      ,[DischargeTime]
      ,[DischargeDispositionCode]
      ,[DischargeDispositionDescription]
      ,[DrCode]
      ,[DrName]
      ,[DrService]
      ,[DrServiceGroup]
      ,[EntryCode]
      ,[EntryCodeDesc]
      ,[Gender]
      ,[InstitutionName]
      ,[InstitutionNum]
      ,[ToInstitutionName]
      ,[ToInstitutionNum]
      ,[FromInstitutionName]
      ,[FromInstitutionNum]
      ,[MainPtServ]
      ,[MainPtServDesc]
      ,[SubServiceCode]
      ,[SubServiceDesc]
      ,[NurseUnitCode]
      ,[NurseUnitDesc]
      ,[ReAdmissionCode]
      ,[ReAdmissionDesc]
      ,[StatusTypeCode]
      ,[StatusTypeDesc]
      ,[StatusTypeTypical]
      ,[LHAName]
      ,[HSDAName]
      ,[HealthAuthorityName]
      ,[PostalCode]
      ,[Age]
      ,[CMGPlusAgeGroup]
      ,[Px1Code]
      ,[Px1Desc]
      ,[Px2Code]
      ,[Px2Desc]
      ,[Px3Code]
      ,[Px3Desc]
      ,[Px4Code]
      ,[Px4Desc]
      ,[Px5Code]
      ,[Px5Desc]
      ,[Px6Code]
      ,[Px6Desc]
      ,[Px7Code]
      ,[Px7Desc]
      ,[Px8Code]
      ,[Px8Desc]
      ,[Px9Code]
      ,[Px9Desc]
      ,[Px10Code]
      ,[Px10Desc]
      ,[Px11Code]
      ,[Px11Desc]
      ,[Px12Code]
      ,[Px12Desc]
      ,[Px13Code]
      ,[Px13Desc]
      ,[Px14Code]
      ,[Px14Desc]
      ,[Px15Code]
      ,[Px15Desc]
      ,[Px16Code]
      ,[Px16Desc]
      ,[Px17Code]
      ,[Px17Desc]
      ,[Px18Code]
      ,[Px18Desc]
      ,[Px19Code]
      ,[Px19Desc]
      ,[Px20Code]
      ,[Px20Desc]
      ,[Dx1Code]
      ,[Dx1Desc]
      ,[DXType1]
      ,[Dx2Code]
      ,[Dx2Desc]
      ,[DXType2]
      ,[Dx3Code]
      ,[Dx3Desc]
      ,[DXType3]
      ,[Dx4Code]
      ,[Dx4Desc]
      ,[DXType4]
      ,[Dx5Code]
      ,[Dx5Desc]
      ,[DXType5]
      ,[Dx6Code]
      ,[Dx6Desc]
      ,[DXType6]
      ,[Dx7Code]
      ,[Dx7Desc]
      ,[DXType7]
      ,[Dx8Code]
      ,[Dx8Desc]
      ,[DXType8]
      ,[Dx9Code]
      ,[Dx9Desc]
      ,[DXType9]
      ,[Dx10Code]
      ,[Dx10Desc]
      ,[DXType10]
      ,[Dx11Code]
      ,[Dx11Desc]
      ,[DXType11]
      ,[Dx12Code]
      ,[Dx12Desc]
      ,[DXType12]
      ,[Dx13Code]
      ,[Dx13Desc]
      ,[DXType13]
      ,[Dx14Code]
      ,[Dx14Desc]
      ,[DXType14]
      ,[Dx15Code]
      ,[Dx15Desc]
      ,[DXType15]
      ,[Dx16Code]
      ,[Dx16Desc]
      ,[DXType16]
      ,[Dx17Code]
      ,[Dx17Desc]
      ,[DXType17]
      ,[Dx18Code]
      ,[Dx18Desc]
      ,[DXType18]
      ,[Dx19Code]
      ,[Dx19Desc]
      ,[DXType19]
      ,[Dx20Code]
      ,[Dx20Desc]
      ,[DXType20]
      ,[Dx21Code]
      ,[Dx21Desc]
      ,[DXType21]
      ,[Dx22Code]
      ,[Dx22Desc]
      ,[DXType22]
      ,[Dx23Code]
      ,[Dx23Desc]
      ,[DXType23]
      ,[Dx24Code]
      ,[Dx24Desc]
      ,[DXType24]
      ,[Dx25Code]
      ,[Dx25Desc]
      ,[DXType25]
  FROM [ADRMart].[dbo].[RehabFullDADView]
GO
/****** Object:  View [DataProfile].[vwEDVisitAreaProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT TOP 10 * FROM [DataProfile].[vwEDVisitAreaProfile]

CREATE VIEW [DataProfile].[vwEDVisitAreaProfile]
AS

SELECT [Site] = a.Site
      ,[FacilityID] = a.FacilityID
      ,[IsFrozen] = a.IsFrozen
      ,[FiscalYearLong] = d.FiscalYearLong
      ,[EmergencyAreaDateID] = LEFT(CONVERT(varchar(10),a.EmergencyAreaDateID,112),6)
      ,[EmergencyAreaTimeID] = a.EmergencyAreaTimeID
      ,[EmergencyAreaID] = a.EmergencyAreaID
      ,[VisitAreaTypeID] = a.VisitAreaTypeID
      ,[IsAreaOutsideVisit] = a.IsAreaOutsideVisit
  
FROM EDMart.dbo.EDVisitArea a
INNER JOIN EDMart.Dim.Date d on d.DateID = a.EmergencyAreaDateID

GO
/****** Object:  View [DataProfile].[vwEDVisitProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT TOP 10 * FROM [DataProfile].[vwEDVisitProfile]

/*******************************************************************
***  Created as part of a routine to create data profiles       ***
***  for various EDVist fact table - Alan						***
***																***
***  Script Date: 07/24/2012									***
***																***
*** July 24 2012  --  Dropped VisitEditDate Change request 21	***
***					  Also adjust to account for the removal of ***
***					  columns as a result of DR2206				***
*******************************************************************/
CREATE VIEW [DataProfile].[vwEDVisitProfile]
AS

SELECT [SourceSystemCode] = f.SourceSystemCode
	,[Site] = f.Site
	,[FacilityID] = f.FacilityID
	,[IsFrozen] = f.IsFrozen
	,[FiscalYearLong] = d.FiscalYearLong
	,[VisitKeyDateID] = f.VisitKeyDateID
	,[AccidentCodeID] = f.AccidentCodeID
	,[AccidentDateID] = LEFT(CONVERT(varchar(10),f.AccidentDateID,112),6)
	,[AccidentTimeID] = f.AccidentTimeID
	,[AccountTypeID] = f.AccountTypeID
	,[AccountSubTypeID] = f.AccountSubTypeID
	,[ADENurseID] = f.ADENurseID
	,[ADEPharmacistID] = f.ADEPharmacistID
	,[AdmissionSourceCodeID] = f.AdmissionSourceCodeID
	,[AdmittedFlag] = f.AdmittedFlag
	,[AgeID] = f.AgeID
	,[ArrivalModeCodeID] = f.ArrivalModeCodeID
	,[ArrivalDateID] = LEFT(CONVERT(varchar(10),f.ArrivalDateID,112),6)
	,[ArrivalTimeID] = f.ArrivalTimeID
	,[ArrivalToMDElapsedTimeID] = f.ArrivalToMDElapsedTimeID
	,[ArrivaltoTriageElapsedTimeID] = f.ArrivaltoTriageElapsedTimeID
	,[AssignedAreaDateID] = LEFT(CONVERT(varchar(10),f.AssignedAreaDateID,112),6)
	,[AssignedAreaTimeID] = f.AssignedAreaTimeID
	,[BedRequestDateID] = LEFT(CONVERT(varchar(10),f.BedRequestDateID,112),6)
	,[BedRequestTimeID] = f.BedRequestTimeID
	,[BedRequesttoDispositionElapsedTimeID] = f.BedRequesttoDispositionElapsedTimeID
	,[BedRequestToInpatientCDUElapsedTimeID] = f.BedRequestToInpatientCDUElapsedTimeID
	,[CDUFlag] = f.CDUFlag
	,[CDUType] = f.CDUType
	,[CDULOSElapsedTimeID] = f.CDULOSElapsedTimeID
	,[CDUtoBedRequestElapsedTimeID] = f.CDUtoBedRequestElapsedTimeID
	,[CharlsonIndexID] = f.CharlsonIndexID
	,[IsCharlsonComputed] = f.IsCharlsonComputed
	,[ChiefComplaintID] = f.ChiefComplaintID
	,[ChiefComplaint2ID] = f.ChiefComplaint2ID
	,[ConsultationRequestDateID] = LEFT(CONVERT(varchar(10),f.ConsultationRequestDateID,112),6)
	,[ConsultationRequestTimeID] = f.ConsultationRequestTimeID
	,[ConsultationServiceCodeID] = f.ConsultationServiceCodeID
	,[ConsultCalltoBedRequestElapsedTimeID] = f.ConsultCalltoBedRequestElapsedTimeID
	,[ConsultcalltoDispositionElapsedTimeID] = f.ConsultcalltoDispositionElapsedTimeID
	,[ConsultCallToInpatientCDUElapsedTimeID] = f.ConsultCallToInpatientCDUElapsedTimeID
	,[COTAcuityModifierID] = f.COTAcuityModifierID
	,[CountryCode] = pt.CountryCode
	,[CTAS_123NonAdmit] = f.CTAS_123NonAdmit
	,[CTAS_123NonAdmitLWBS] = f.CTAS_123NonAdmitLWBS
	,[CTAS_123NonAdmitLWBSWithinTarget] = f.CTAS_123NonAdmitLWBSWithinTarget
	,[CTAS_123NonAdmitMissedTarget30min] = f.CTAS_123NonAdmitMissedTarget30min
	,[CTAS_123NonAdmitWithinTarget] = f.CTAS_123NonAdmitWithinTarget
	,[CTAS_45NonAdmit] = f.CTAS_45NonAdmit
	,[CTAS_45NonAdmitLWBS] = f.CTAS_45NonAdmitLWBS
	,[CTAS_45NonAdmitLWBSWithinTarget] = f.CTAS_45NonAdmitLWBSWithinTarget
	,[CTAS_45NonAdmitMissedTarget15min] = f.CTAS_45NonAdmitMissedTarget15min
	,[CTAS_45NonAdmitWithinTarget] = f.CTAS_45NonAdmitWithinTarget
	,[CTAS_AdmitMissedTarget60min] = f.CTAS_AdmitMissedTarget60min
	,[CTAS_AdmitWithinTarget] = f.CTAS_AdmitWithinTarget
	,[CTAS_DDFEAdmit] = f.CTAS_DDFEAdmit
	,[CTAS_DDFEAdmitWithinTarget] = f.CTAS_DDFEAdmitWithinTarget
	,[DischargeDiagnosisID] = f.DischargeDiagnosisID
	,[DischargeDispositionCodeID] = f.DischargeDispositionCodeID
	,[DischargeModeID] = f.DischargeModeID
	,[DispositionDateID] = LEFT(CONVERT(varchar(10),f.DispositionDateID,112),6)
	,[DispositionTimeID] = f.DispositionTimeID
	,[DoctorID] = f.DoctorID
	,[DoctorID_Original] = f.DoctorID_Original
	,[DTUCriteria] = f.DTUCriteria
	,[EarliestCDUdateID] = LEFT(CONVERT(varchar(10),f.EarliestCDUdateID,112),6)
	,[EarliestCDUtimeID] = f.EarliestCDUtimeID
	,[EmergencyStatusID] = f.EmergencyStatusID
	,[EMGID] = f.EMGID
	,[FirstVisitFlag] = f.FirstVisitFlag
	,[FirstEmergencyAreaDateID] = LEFT(CONVERT(varchar(10),f.FirstEmergencyAreaDateID,112),6)
	,[FirstEmergencyAreaTimeID] = f.FirstEmergencyAreaTimeID
	,[FirstEmergencyAreaID] = f.FirstEmergencyAreaID
	,[FirstEmergencyAreaVisitAreaTypeID] = f.FirstEmergencyAreaVisitAreaTypeID
	,[FirstEmergencyAreaExclTriageDateID] = LEFT(CONVERT(varchar(10),f.FirstEmergencyAreaExclTriageDateID,112),6)
	,[FirstEmergencyAreaExclTriageTimeID] = f.FirstEmergencyAreaExclTriageTimeID
	,[FirstEmergencyAreaExclTriageAreaID] = f.FirstEmergencyAreaExclTriageAreaID
	,[FirstEmergencyAreaExclTriageVisitAreaTypeID] = f.FirstEmergencyAreaExclTriageVisitAreaTypeID
	,[FSA] = f.FSA
	,[FstCareProviderDateID] = LEFT(CONVERT(varchar(10),f.FstCareProviderdateid,112),6)
	,[FstCareProviderTimeID] = f.FstCareProviderTimeID
	,[FstCareProviderToBedRequestElapsedTimeID] = f.FstCareProviderToBedRequestElapsedTimeID
	,[FstCareProviderToConsultCallElapsedTimeID] = f.FstCareProviderToConsultCallElapsedTimeID
	,[FstCareProviderToDispositionElapsedTimeID] = f.FstCareProviderToDispositionElapsedTimeID
	,[FstCareProviderToInpatientCDUElapsedTimeID] = f.FstCareProviderToInpatientCDUElapsedTimeID
	,[GenderID] = pt.GenderID
	,[InfectiousDiseaseCodeID] = f.InfectiousDiseaseCodeID
	,[InpatientAdmittingDoctorID] = f.InpatientAdmittingDoctorID
	,[InpatientAttendingDoctorID] = f.InpatientAttendingDoctorID
	,[InpatientBed] = f.InpatientBed
	,[InpatientDateID] = LEFT(CONVERT(varchar(10),f.InpatientDateID,112),6)
	,[InpatientTimeID] = f.InpatientTimeID
	,[InpatientDiagnosis] = f.InpatientDiagnosis
	,[InpatientLocationCostCenterID] = f.InpatientLocationCostCenterID
	,[InpatientNursingUnitID] = f.InpatientNursingUnitID
	,[InpatientServiceCodeID] = f.InpatientServiceCodeID
	,[InpatientTeamID] = f.InpatientTeamID
	,[IsAutoAccident] = f.IsAutoAccident
	,[IsHomeless] = pt.IsHomeless
	,[IsHomeless_PHC] = pt.IsHomelessPHC
	,[IsOtherAccident] = f.IsOtherAccident
	,[IsSingleSiteVisit] = f.IsSingleSiteVisit
	,[IsThirdPartyLiability] = f.IsThirdPartyLiability
	,[IsTrauma] = f.IsTrauma
	,[IsWorkAccident] = f.IsWorkAccident
	,[LanguageID] = pt.LanguageID
	,[LastEmergencyAreaDateID] = LEFT(CONVERT(varchar(10),f.LastEmergencyAreaDateID,112),6)
	,[LastEmergencyAreaTimeID] = f.LastEmergencyAreaTimeID
	,[LastEmergencyAreaID] = f.LastEmergencyAreaID
	,[LastEmergencyAreaVisitAreaTypeID] = f.LastEmergencyAreaVisitAreaTypeID
	,[LatestCDUOutDateID] = LEFT(CONVERT(varchar(10),f.LatestCDUOutDateID,112),6)
	,[LatestCDUOutTimeID] = f.LatestCDUOutTimeID
	,[LHAID] = f.LHAID
	,[LOS_ElapsedTimeID] = f.LOS_ElapsedTimeID
	,[LWBS] = f.LWBS
	,[MDtoBedRequestElapsedTimeID] = f.MDtoBedRequestElapsedTimeID
	,[MDtoConsultcallElapsedTimeID] = f.MDtoConsultcallElapsedTimeID
	,[MDtoDispositionElapsedTimeID] = f.MDtoDispositionElapsedTimeID
	,[PatientServiceCodeID] = f.PatientServiceCodeID
	,[Payor1ID] = f.Payor1ID
	,[Payor2ID] = f.Payor2ID
	,[Payor3ID] = f.Payor3ID
	,[ProvinceCode] = pt.ProvinceCode
	,[Readmission_AnySite_ElapsedTimeID] = f.Readmission_AnySite_ElapsedTimeID
	,[Readmission_sameSite_ElapsedTimeID] = f.Readmission_sameSite_ElapsedTimeID
	,[RegistrationDateID] = LEFT(CONVERT(varchar(10),f.RegistrationDateID,112),6)
	,[RegistrationTimeID] = f.RegistrationTimeID
	,[RegistrationDateID_Original] = LEFT(CONVERT(varchar(10),f.RegistrationDateID_Original,112),6)
	,[RegistrationTimeID_Original] = f.RegistrationTimeID_Original
	,[ReligionID] = pt.ReligionID
	,[SeenByDoctorDateID] = LEFT(CONVERT(varchar(10),f.SeenByDoctorDateID,112),6)
	,[SeenBYDoctorTimeID] = f.SeenByDoctorTimeID
	,[SeenbyGeriTriageDateID] = LEFT(CONVERT(varchar(10),f.SeenbyGeriTriageDateID,112),6)
	,[SeenbyGeriTriageTimeID] = f.SeenbyGeriTriageTimeID
	,[SeenByNurseDateID] = LEFT(CONVERT(varchar(10),f.SeenByNurseDateID,112),6)
	,[SeenByNurseTimeID] = f.SeenByNurseTimeID
	,[SeenByResDateID] = LEFT(CONVERT(varchar(10),f.SeenByResDateID,112),6)
	,[SeenByResTimeID] = f.SeenByResTimeID
	,[SeenByStudentDateID] = LEFT(CONVERT(varchar(10),f.SeenByStudentDateID,112),6)
	,[SeenByStudentTimeID] = f.SeenByStudentTimeID
	,[StartDateID] = LEFT(CONVERT(varchar(10),f.StartDateID,112),6)
	,[StartTimeID] = f.StartTimeID
	,[StarttoBedRequestElapsedTimeID] = f.StarttoBedRequestElapsedTimeID
	,[StarttoDispositionElapsedTimeID] = f.StarttoDispositionElapsedTimeID
	,[StarttoDispositionExclCDUElapsedTimeID] = f.StarttoDispositionExclCDUElapsedTimeID
	,[StarttoDispositionExclCDUtoBedRequestElapsedTimeID] = f.StarttoDispositionExclCDUtoBedRequestElapsedTimeID
	,[StarttoMDElapsedTimeID] = f.StarttoMDElapsedTimeID
	,[SystemDateID] = LEFT(CONVERT(varchar(10),f.SystemDateID,112),6)
	,[SystemTimeID] = f.SystemTimeID
	,[TriageAcuityID] = f.TriageAcuityID
	,[TriageDateID] = LEFT(CONVERT(varchar(10),f.TriageDateID,112),6)
	,[TriageTimeID] = f.TriageTimeID
	,[Triageto1stCareProviderElapsedTimeID] = f.Triageto1stCareProviderElapsedTimeID
	,[TriagetoBedrequestElapsedTimeID] = f.TriagetoBedrequestElapsedTimeID
	,[TriagetoDispositionElapsedTimeID] = f.TriagetoDispositionElapsedTimeID
	,[TriageToDispositionWithHUBElapsedTimeID] = f.TriageToDispositionWithHUBElapsedTimeID
	,[TriagetoMDElapsedTimeID] = f.TriagetoMDElapsedTimeID
	,[VirtualInpatientLocationCostCenterID] = f.VirtualInpatientLocationCostCenterID
	,[VirtualInpatientNursingUnitID] = f.VirtualInpatientNursingUnitID
	
FROM EDMart.dbo.ED_Visit f
INNER JOIN EDMart.Secure.EDPatientFactView pt ON pt.ETLAuditID = f.ETLAuditID
INNER JOIN EDMart.Dim.Date d ON d.DateID = f.VisitKeyDateID

GO
/****** Object:  View [DataProfile].[vwLOSFactProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwLOSFactProfile]
as

select 
FacilityID
,left(convert(varchar(10),[AdmissionDateID],112),6) AdmissionDateID
,left(convert(varchar(10),[DischargeDateID],112),6) DischargeDateID
,NursingUnitID
,left(convert(varchar(10),[MaxCensusDateID],112),6) MaxCensusDateID
,CostCenterBusinessUnitEntitySiteID
,IsCustomCostCenter
,LOS
,ALCDays
from DSDW.LOS.LOSFact



GO
/****** Object:  View [DataProfile].[vwMHAMRRExtractClientFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwMHAMRRExtractClientFact]
AS
SELECT [FiscalYear]
	,[FiscalPeriod]
	-- ,[ExtractFileID]
	-- ,[SourceSystemClientID]
	--,[A2SourceUpdateDate]
	--,[A3DeleteFlag]
	--,[C1HAClientNumber]
	--,[C2PHN]
	,[C3City]
	,[C4Province]
	--,[C5PostalCode]
	--,[C6BirthDate]
	,[C7Gender]
	,[C8MaritalStatus]
	,[C9Height]
	,[C10Weight]
	,[C11HouseholdComposition]
	,[C12AboriginalIdentityIndicator]
	,[C13AboriginalIdentityGroup]
	,[C14FirstNationsStatusIndicator]
	,[C15FirstNationsOnReserveIndicator]
	,[C16LevelOfEducationCompleted]
	,[C17CurrentEducation]
	,[C18EmploymentStatus]
	,[C19EmploymentHours]
	,[C20WCBSickDisabilityFlag]
	,[C21DurationWCBSickDisability]
	,[C22CriminalJusticeInvolvement]
	,[C23NatureOfCriminalJustice]
	,[C24LegalStatusFirstField]
	,[C25LegalStatusSecondField]
	,[C26EstimatedAge]
	,[C27HistoryOfSuicideAttempts]
	,[C28HistoryOfViolence]
	,[C29AgeFirstUseOfAlcohol]
	,[C30AgeFirstUseOfTobacco]
	,[C31AgeFirstUseOfMarijuana]
	,[C32AgeFirstUseOfDrugs]
	,[IsMCFD]
	,[AgeAtPeriodEnd]
--  ,[ETLAuditID]
FROM [ExternalExtractProcessing].[MHAMRR].[ExtractClientFact]

GO
/****** Object:  View [DataProfile].[vwMHAMRRExtractDiagnosisFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwMHAMRRExtractDiagnosisFact]
AS
SELECT  [FiscalYear]
      ,[FiscalPeriod]
      --,[ExtractFileID]
      --,[SourceSystemClientID]
      --,[S1HAServiceEpisodeKey]
      --,[A3DeleteFlag]
      --,[SourceAdmissionAssessmentID]
      --,[SourceAdmissionDiagnosisID]
      --,[SourceDischargeAssessmentID]
      --,[SourceDischargeDiagnosisID]
      --,[A2SourceUpdateDate]
      --,[D1DateOfDiagnosisEnrolment]
      --,[D2DateOfDiagnosisDischarge]
      ,[D3GAFScoreEnrolment]
      ,[D4GAFScoreDischarge]
      ,[D5Axis1FirstAtEnrolment]
      ,[D6Axis1FirstAtDischarge]
      ,[D7Axis1SecondAtEnrolment]
      ,[D8Axis1SecondAtDischarge]
      ,[D9Axis1OtherAtEnrolment]
      ,[D10Axis1OtherAtDischarge]
      ,[D11Axis2FirstAtEnrolment]
      ,[D12Axis2FirstAtDischarge]
      ,[D13Axis2SecondAtEnrolment]
      ,[D14Axis2SecondAtDischarge]
      ,[D15ClinicianImpression]
      ,[IsMCFD]
  FROM [ExternalExtractProcessing].[MHAMRR].[ExtractDiagnosisFact]

GO
/****** Object:  View [DataProfile].[vwMHAMRRExtractHoNoSFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwMHAMRRExtractHoNoSFact]
AS
SELECT  [FiscalYear]
      ,[FiscalPeriod]
      --,[ExtractFileID]
      --,[SourceReferralID]
      --,[SourceAssessmentID]
      --,[A3DeleteFlag]
      --,[A2SourceUpdateDate]
      --,[S1HAServiceEpisodeKey]
      --,[N1HAHoNoSRecordKey]
      --,[N2DateOfHoNoSAssmt]
      ,[N3BehaviouralDisturbance]
      ,[N4NonAccidentalSelfInjury]
      ,[N5ProblemsWithAlcoholSubstanceSolventUse]
      ,[N6CognitiveProblems]
      ,[N7ProblemsWithPhysicalIllnessOrDisability]
      ,[N8ProblemsWithHallucinationDelusionOrFalseBelief]
      ,[N9ProblemsWithDepressionSymptoms]
      ,[N10ProblemsWithSocialFamilyOrSupportiveRelationships]
      ,[N11ProblemsWithActivitiesOfDailyLiving]
      ,[N12OverallProblemsWithLivingConditions]
      ,[N13ProblemsWithWorkAndLeisure]
      ,[N14ProblemsWithOverActivityAttentionOrConcentration]
      ,[N15ProblemsWithScholasticOrLanguageSkills]
      ,[N16ProblemsWithNonOrganicSomaticSymptoms]
      ,[N17ProblemsWithEmotionalAndRelatedSymptoms]
      ,[N18ProblemsWithPeerRelationships]
      ,[N19ProblemsWithSelfCareAndIndependence]
      ,[N20ProblemsWithPoorAttendance]
      ,[N21ProblemsWithKnowledgeOfChildDifficulties]
      ,[N22BehaviouralProblemsDirectedAtOthers]
      ,[N23BehaviouralProblemsDirectedAtSelf]
      ,[N24OtherMentalAndBehaviouralProblems]
      ,[N25AttentionAndConcentration]
      ,[N26MemoryAndOrientation]
      ,[N27CommunicationsUnderstanding]
      ,[N28CommunicationsExpression]
      ,[N29HallucinationsAndDelusions]
      ,[N30MoodChanges]
      ,[N31ProblemsWithSleeping]
      ,[N32ProblemsWithEatingAndDrinking]
      ,[N33PhysicalProblems]
      ,[N34Seizures]
      ,[N35ActivitiesOfDailyLivingAtHome]
      ,[N36ActivitiesOfDailyLivingOutsideHome]
      ,[N37LevelOfSelfCare]
      ,[N38ProblemsWithRelationships]
      ,[N39OccupationAndActivities]
      ,[N40ManiaHypomania]
      ,[N41Anxiety]
      ,[N44EatingDisorder]
      ,[N45LackOfInformation]
      ,[IsMCFD]
      --,[ETLAuditID]
  FROM [ExternalExtractProcessing].[MHAMRR].[ExtractHoNoSFact]

GO
/****** Object:  View [DataProfile].[vwMHAMRRExtractServiceEpisodeFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwMHAMRRExtractServiceEpisodeFact]
AS
SELECT  [FiscalYear]
      ,[FiscalPeriod]
      --,[ExtractFileID]
      --,[SourceSystemClientID]
      --,[S1HAServiceEpisodeKey]
      --,[A2SourceUpdateDate]
      --,[A3DeleteFlag]
      --,[C1HAClientNumber]
      --,[SourceReferralID]
      --,[SourceCaseNoteHeaderID]
      ,[S2ServiceType]
      ,[S3ReferralSource]
      --,[S4ReferralDate]
      --,[S5DateOfFirstContact]
      --,[S6DateOfFirstService]
      --,[S7DateOfFirstServiceEventInPeriod]
      --,[S8DateOfLastServiceEventInPeriod]
      ,[S9NumberOfServiceEventsInPeriod]
      ,[S10LivingArrangement]
      ,[S11AcuteInpatientSecureRoom]
      ,[S12AcuteInpatientTransport]
      ,[S13MHAAffectedRelationship]
      ,[S14ServiceAgencyLocationCode]
      ,[S15TypeOfCBTIntervention]
      ,[S16TypeOfDBTIntervention]
      --,[S17DateExtendedLeaveEnds]
      --,[S18DateDischarged]
      ,[S19ReasonForEndingService]
      ,[S20DateHospitalToCommunityContact]
      ,[S21ReasonNoCommunityFollowUpContact]
      ,[S22Pregnancy]
      ,[S23Parenting]
      ,[S24SuicideAttempt]
      ,[S25Violence]
      ,[S26PeerSupportService]
      ,[S27FASD]
      ,[ParisTeamCode]
      ,[CommunityRegionCode]
      ,[CommunityProgramCode]
      ,[ServiceEpisodeType]
      ,[ServiceEpisodeReferralReasonCode]
      ,[IsMCFD]
      --,[ETLAuditID]
  FROM [ExternalExtractProcessing].[MHAMRR].[ExtractServiceEpisodeFact]

GO
/****** Object:  View [DataProfile].[vwMHAMRRExtractServiceEventFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwMHAMRRExtractServiceEventFact]
AS
SELECT  [FiscalYear]
      ,[FiscalPeriod]
      --,[ExtractFileID]
      --,[A2SourceUpdateDate]
      --,[A3DeleteFlag]
      --,[S1HAServiceEpisodeKey]
      --,[T1HAServiceEventKey]
      --,[T2ServiceEventDateTime]
      ,[ServiceEventType]
      --,[SourceServiceEventKey]
      ,[IsMCFD]
  FROM [ExternalExtractProcessing].[MHAMRR].[ExtractServiceEventFact]

GO
/****** Object:  View [DataProfile].[vwMHAMRRExtractSubstanceUseFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [DataProfile].[vwMHAMRRExtractSubstanceUseFact]
AS
SELECT  [FiscalYear]
      ,[FiscalPeriod]
      --,[ExtractFileID]
      --,[SourceAssessmentID]
      --,[A2SourceUpdateDate]
      --,[A3DeleteFlag]
      --,[S1HAServiceEpisodeKey]
      --,[U1SubstanceUseRecordKey]
      --,[U2DateOfSubstanceUseAssmt]
      ,[U3SubstanceUse]
      ,[U4StageOfChange]
      ,[U5AvgCigarettesDrinks30DaysPrior]
      ,[U6DaysDrinkingOrDrugs30DaysPrior]
      ,[U7PrimaryMethodOfSubstanceIntake]
      ,[U8SharingNeedles30DaysPrior]
      ,[U9SourceOfSubstance]
      ,[U10PrimarySubstanceUsed]
      ,[IsMCFD]
      --,[ETLAuditID]
  FROM [ExternalExtractProcessing].[MHAMRR].[ExtractSubstanceUseFact]

GO
/****** Object:  View [DataProfile].[vwORCaseCosting]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


Create View [DataProfile].[vwORCaseCosting]
as
SELECT [IsScheduled]
      ,[SurgeryPerformedDate]
      ,[FiscalYear]
      ,[FiscalPeriod]
      ,[FacilityLongName]
      ,[ORRoomCode]
      ,[ORLocationDesc]
      ,[ServiceDescription]
      ,[LoggedMainSurgeonCode]
      ,[LoggedMainSurgeonName]
      ,[LoggedMainSurgeonSpecialty]
      ,[LoggedPx1Code]
      ,[LoggedPx1Desc]
      ,[LoggedPx2Code]
      ,[LoggedPx2Desc]
      ,[LoggedPx3Code]
      ,[LoggedPx3Desc]
      ,[LoggedSPRPx1Code]
      ,[LoggedSPRPx1Desc]
      ,[LoggedSPRPx2Code]
      ,[LoggedSPRPx2Desc]
      ,[LoggedSPRPx3Code]
      ,[LoggedSPRPx3Desc]
      ,[LoggedSurgeon1Code]
      ,[LoggedSurgeon1Name]
      ,[LoggedSurgeon2Code]
      ,[LoggedSurgeon2Name]
      ,[LoggedSurgeon3Code]
      ,[LoggedSurgeon3Name]
      ,[PatientInDateTime]
      ,[PatientOutDateTime]
      ,[PatientInOutElapsedTimeMinutes]
      ,[SurgeryStartDateTime]
      ,[SurgeryStopDateTime]
      ,[SurgeryElapsedTimeMinutes]
      ,[ResourceNum]
      ,[ResourceDesc]
      ,[ResourceType]
      ,[ProductCategory]
      --,[UnitPurchase]
      --,[UnitCost]
      --,[PlannedQuantity]
      --,[UsedQuantity]
      --,[WastedQuantity]
      --,[ReturnedQuantity]
      --,[TotalQuantity]
      --,[TotalCost]
      ,[CaseCostingExtractDateId]
      ,[CompleteFileExtractDate]
	  ,[Impl_Lot]
	  ,[Impl_Side]
  FROM ORMart.[dbo].[CaseCostingView]



GO
/****** Object:  View [DataProfile].[vwORCompCasesProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO






Create view [DataProfile].[vwORCompCasesProfile]
as
SELECT [ORRoomCode]
      ,[SurgeryPerformedDate]
      ,left(convert(varchar(10),[BookingFormReceivedDate],112),6) [BookingFormReceivedDate]
      ,left(convert(varchar(10),[SurgeryDecisionDate],112),6) [SurgeryDecisionDate]
      ,[FiscalYear]
      ,[FiscalPeriod]
      ,[StatIndicator]
      ,[PatientStatusDetail]
      ,[PatientStatusRollup]
      ,[SurgeryPriorityDesc]
      ,[IsAddon]
      ,[FullCode]
      ,[DiagnosisDescription]
      ,[DXDescription70]
      ,[DxTargetInWeeks]
      ,[ASAScoreCode]
      ,[ASAScoreDesc]
      ,[ScheduledMainSurgeonId]
      ,[ScheduledMainSurgeonCode]
      ,[ScheduledMainSurgeonName]
      ,[LoggedMainSurgeonId]
      ,[LoggedMainSurgeonCode]
      ,[LoggedMainSurgeonName]
	  ,[LoggedMainSurgeonSpecialty]
      ,[ScheduledAnesthetistId]
      ,[ScheduledAnesthetistCode]
      ,[ScheduledAnesthetistName]
      ,[LoggedAnesthetistId]
      ,[LoggedAnesthetistCode]
      ,[LoggedAnesthetistName]
      ,[LoggedSecondAnesthetistId]
      ,[LoggedSecondAnesthetistCode]
      ,[LoggedSecondAnesthetistName]
      ,[LoggedThirdAnesthetistId]
      ,[LoggedThirdAnesthetistCode]
      ,[LoggedThirdAnesthetistName]
      ,[LoggedTEEAnesthetistId]
      ,[LoggedTEEAnesthetistCode]
      ,[LoggedTEEAnesthetistName]
      ,[ServiceCode]
      ,[ServiceDescription]
      ,[ScheduledPx1Code]
      ,[ScheduledPx1Desc]
      ,[ScheduledSPRPx1Code]
      ,[ScheduledSPRPx1Desc]
      ,[LoggedPx1Code]
      ,[LoggedPx1Desc]
      ,[LoggedSPRPx1Code]
      ,[LoggedSPRPx1Desc]
      ,[LoggedPx2Code]
      ,[LoggedPx2Desc]
      ,[LoggedSPRPx2Code]
      ,[LoggedSPRPx2Desc]
      ,[LoggedPx3Code]
      ,[LoggedPx3Desc]
      ,[LoggedSPRPx3Code]
      ,[LoggedSPRPx3Desc]
      ,[LoggedSurgeon1Id]
      ,[LoggedSurgeon1Code]
      ,[LoggedSurgeon1Name]
      ,[LoggedSurgeon2Id]
      ,[LoggedSurgeon2Code]
      ,[LoggedSurgeon2Name]
      ,[LoggedSurgeon3Id]
      ,[LoggedSurgeon3Code]
      ,[LoggedSurgeon3Name]
      ,left(convert(varchar(10),[HoldingStartDateTime],112),6) [HoldingStartDateTime]
      ,left(convert(varchar(10),[HoldingEndDateTime],112),6) [HoldingEndDateTime]
      ,[HoldingAreaElapsedTimeMinutes]
      ,left(convert(varchar(10),[SetupStartDateTime],112),6) [SetupStartDateTime]
      ,left(convert(varchar(10),[SetupEndDateTime],112),6) [SetupEndDateTime]
      ,[SetupElapsedTimeMinutes]
      ,left(convert(varchar(10),[PatientInDateTime],112),6) [PatientInDateTime]
      ,left(convert(varchar(10),[PatientOutDateTime],112),6) [PatientOutDateTime]
      ,[PatientInOutElapsedTimeMinutes]
      ,left(convert(varchar(10),[PreviousPatientOutDateTime],112),6) [PreviousPatientOutDateTime]
      ,[ORTotalElapsedTimeMinutes]
      ,left(convert(varchar(10),[PreviousPatientOutDateTime_DS],112),6) [PreviousPatientOutDateTime_DS]
      ,[ORTotalElapsedTimeMinutes_DS]
      ,left(convert(varchar(10),[AnesthesiaStartDateTime],112),6) [AnesthesiaStartDateTime]
      ,left(convert(varchar(10),[AnesthesiaStopDateTime],112),6) [AnesthesiaStopDateTime]
      ,[AnesthesiaElapsedTimeMinutes]
      ,left(convert(varchar(10),[AnesthesiologistStopDateTime],112),6) [AnesthesiologistStopDateTime]
      ,left(convert(varchar(10),[AnesthesiologistElapsedTimeMinutes],112),6) [AnesthesiologistElapsedTimeMinutes]
      ,left(convert(varchar(10),[SurgeryStartDateTime],112),6) [SurgeryStartDateTime]
      ,left(convert(varchar(10),[SurgeryStopDateTime],112),6) [SurgeryStopDateTime]
      ,[SurgeryElapsedTimeMinutes]
      ,left(convert(varchar(10),[CleanupStartDateTime],112),6) [CleanupStartDateTime]
      ,left(convert(varchar(10),[CleanupEndDateTime],112),6) [CleanupEndDateTime]
      ,[CleanupElapsedTimeMinutes]
      ,left(convert(varchar(10),[PARInDateTime],112),6) [PARInDateTime]
      ,left(convert(varchar(10),[PAROutDateTime],112),6) [PAROutDateTime]
      ,[PARElapsedTimeMinutes]
      ,left(convert(varchar(10),[SDCPostOpInDateTime],112),6) [SDCPostOpInDateTime]
      ,left(convert(varchar(10),[SDCPostOpOutDateTime],112),6) [SDCPostOpOutDateTime]
      ,[SDCPostOpElapsedTimeMinutes]
      ,[UnitPtFrom]
      ,[SpecialFunding]
      ,[LoggedProcType]
      ,[CancerStatusCode]
      ,left(convert(varchar(10),[OrigEmergBkgReqDateTime],112),6) [OrigEmergBkgReqDateTime]
      ,left(convert(varchar(10),[FinalEmergBkgReqDateTime],112),6) [FinalEmergBkgReqDateTime]
      ,[IsSweeperRoom]
      ,left(convert(varchar(10),[UnavailableFromDate],112),6) [UnavailableFromDate]
      ,left(convert(varchar(10),[UnavailableToDate],112),6) [UnavailableToDate]
      ,[UnavailableElapsedDay]
      ,[SurgWaitElapsedDay]
      ,[IsMeetingTarget]
      ,[SurgWaitElapsedDay_BkgCard]
      ,[IsMeetingTarget_BkgCard]
      ,[UnavailableReasonDesc]
      ,[LoggedThirdAnesthetist2Id]
      ,[LoggedThirdAnesthetist2Code]
      ,[LoggedThirdAnesthetist2Name]
      ,[LoggedThirdAnesthetist3Id]
      ,[LoggedThirdAnesthetist3Code]
      ,[LoggedThirdAnesthetist3Name]
      ,[LoggedTEEAnesthetist2Id]
      ,[LoggedTEEAnesthetist2Code]
      ,[LoggedTEEAnesthetist2Name]
      ,[LoggedTEEAnesthetist3Id]
      ,[LoggedTEEAnesthetist3Code]
      ,[LoggedTEEAnesthetist3Name]
      ,[FacilityLongName]
      ,[ORLocationDesc]
      ,[Site]
      ,[SpecialGroup]
      ,[SpecialFlag]
      ,[IsSwingRoom]
      ,[Anesthesia]
      ,[isSSCL1]
      ,[isSSCL2]
      ,[isSSCL3]
      ,[SurgeryTypeName]
      ,[LocalHealthAuthority]
      ,[ServiceDeliveryArea]
      ,[HealthAuthority]
      ,[Age]
      ,[CIHIAgeGroup2]
      ,[GenderDesc]
      ,[IsScheduled]
      ,[MedicationDesc]
      ,left(convert(varchar(10),[AntibioticPreOpDateTime],112),6) [AntibioticPreOpDateTime]
      ,left(convert(varchar(10),[AntibioticPreOpEndDateTime],112),6) [AntibioticPreOpEndDateTime]
      ,[AntibioticSurgeryElapsedTimeMinutes]
      ,[WoundPx1Desc]
      ,[WoundPx2Desc]
      ,[WoundPx3Desc]
      ,[IsPreopAssess]
      ,[ClinStage]
      ,[IsCancRecur]
      ,[IsFirstCase]
      ,[IsAntibioticNotRequired]
	  ,[IsPHCMajorSurgery]
	  ,[BirthYear]
	  ,[ORType]
	  ,[ORLocationGroup]
	  ,[ORRoomGroup]
	  ,[LoggedPxCount]
      ,[IsCostingCase]
	  ,[EstimatedCleanupElapsedTimeMinutes]
	  ,[EstimatedPatientInOutElapsedTimeMinutes] 
	  ,[EstimatedSetupElapsedTimeMinutes]
	  ,[EstimatedTotalElapsedTimeMinutes]
	  ,'' [PatientVersionID]
	  ,[IsCostExpected]
	  ,[ReferralDate]
	  ,[FirstConsultDate]
	  ,[OrigPriorityDesc]
	  ,[SurgRequiredElapsedTimeMinutes] 
	  ,[ReferralToFirstConsultElapsedDay]
	  ,[FirstConsultToBkgCardElapsedDay]
      ,left(convert(varchar(10),[ExtractFileDate],112),6) [ExtractFileDate] 
  FROM [ORMart].[dbo].[RegionalORCompletedCaseView]






GO
/****** Object:  View [DataProfile].[vwORWaitListProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [DataProfile].[vwORWaitListProfile] as 

SELECT [Site]
      ,[FacilityLongName]
      ,[ORRoomCode]
      ,[ORLocation]
      ,[ORType]
      ,[ORLocationGroup]
      ,[ORRoomGroup]
      ,[CaseScheduledToOccurDate]
      ,[ReferralDate]
      ,[FirstConsultDate]
      ,[BookingFormReceivedDate]
      ,[DecisionDate]
      ,[CaseEnteredInORMISDate]
      ,[FiscalYear]
      ,[FiscalPeriod]
      ,[StatIndicator]
      ,[CaseModifiedDate]
      ,[PatientStatusDetail]
      ,[PatientStatusRollup]
      ,[SurgeryPriorityDesc]
      ,[IsSPRCase]
      ,[ScheduledSurgeryStartDateTime]
      ,[ScheduledSurgeryStopDateTime]
      ,[FullCode]
      ,[DiagnosisDescription]
      ,[DXDescription70]
      ,[DxTargetInWeeks]
      ,[PreopDx]
      ,[ScheduledMainSurgeonName]
	  ,[ServiceCode]
      ,[ScheduledORServiceId]
      ,[ServiceDescription]
      ,[ScheduledPx1Desc]
      ,[ScheduledSPRPx1Desc]
      ,[ScheduledPx2Desc]
      ,[ScheduledSPRPx2Desc]
      ,[ScheduledPx3Desc]
      ,[ScheduledSPRPx3Desc]
      ,[ScheduledPx4Desc]
      ,[ScheduledSPRPx4Desc]
      ,[ScheduledPx5Desc]
      ,[ScheduledSPRPx5Desc]
      ,[EstimatedLOS_days]
      ,[IsICUbed]
      ,[PayorDescription]
      ,[IsSwingRoom]
      ,[SchedPxCount]
      ,[Anesthesia]
      ,[IsCaseLogged]
      ,[UnavailableFromDate1]
      ,[UnavailableToDate1]
      ,[UnavailableReason1Code]
      ,[UnavailableFromDT2]
      ,[UnavailableToDate2]
      ,[UnavailableReason2Code]
      ,[UnavailableFromDate3]
      ,[UnavailableToDate3]
      ,[UnavailableReason3Code]
      ,[CancerStatusCode]
      ,[IsCancerAssess]
      ,[ClinStage]
      ,[IsCancRecur]
      ,[ScheduledSetupStartDateTime]
      ,[ScheduledSetupStopDateTime]
      ,[ScheduledPatientInRoomDateTime]
      ,[ScheduledPatientOutRoomDateTime]
      ,[ScheduledCleanupStartDateTime]
      ,[ScheduledCleanupStopDateTime]
      ,[ORPx1SideCode]
      ,[ORPx2SideCode]
      ,[ORPx3SideCode]
      ,[ORPx4SideCode]
      ,[ORPx5SideCode]
      ,[ExtractFileDate]
      ,[GenderDesc]
      ,[LocalHealthAuthority]
      ,[ServiceDeliveryArea]
      ,[HealthAuthority]
      ,[Age]
      ,[CIHIAgeGroup2]
      ,[BirthYear]
      ,[UnavailableElapsedDay1]
      ,[UnavailableElapsedDay2]
      ,[UnavailableElapsedDay3]
      ,[ScheduledSurgeryElapsedTimeMinutes]
      ,[ScheduledSetupElapsedTimeMinutes]
      ,[ScheduledPatientInOutElapsedTimeMinutes]
      ,[ScheduledCleanupElapsedTimeMinutes]
      ,[ReferralToFirstConsultElapsedDay]
      ,[FirstConsultToBkgCardElapsedDay]
  FROM ORMart.[dbo].[RegionalORWaitlistCaseView]


GO
/****** Object:  View [DataProfile].[vwPatientContProfile]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [DataProfile].[vwPatientContProfile]
as
SELECT [SourceFactTable]
     ,[SourceDate] 
	,[EDAdmit] 
	,FacilityID
	,[ServiceEndDate] 
	,[SourceGroup] 
	,[IsKnownToHCC] 
  FROM [DSDW].[Map].[PatientContinuum]

GO
/****** Object:  View [DataProfile].[vwPharmacyAdmin1]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View [DataProfile].[vwPharmacyAdmin1]
as
SELECT [FacilityCode]
      ,[FacilityName]
      ,D.dateID
      ,[TransferType]
      ,[TransactionBillingTimestamp]
      ,[NursingCenter]
      ,[CostCenter]
      ,[ICDCode]
      ,[OMNIID]
      ,[OMNIName]
      ,[UserID]
      ,[UserName]
      ,[WitnessID]
      ,[WitnessName]
      ,[IsAlergy]
      ,[IsNullType]
      ,[QuantityIssued]
      ,[QuantityOnhand]
      ,[QuantityWasted]
      ,[QuantityRequested]
      ,[QuantityCountedback]
      ,[IsIssuedToDischargedPatients]
      ,[IsMedicationOverridden]
      ,[ReturnReason]
      ,[DoseAmount]
      ,[ActualDoseAmount]
      ,[IsDoseTransaction]
      ,[IsItemScanType]
      ,[IsItemScanOverride]
      ,[TotalItemQuantityOnhand]
      ,[MedicationScheduledTimestamp]
      ,[IsAlertDispensingItem]
	  ,FiscalYearLong
  FROM [SourceDataArchive].[Pharmacy].[VAAdmin1] F
left outer join DSDW.Dim.Date D on left(TransactionTimestamp,8) = D.DateID

union all

SELECT [FacilityCode]
      ,[FacilityName]
      ,D.dateID
      ,[TransferType]
      ,[TransactionBillingTimestamp]
      ,[NursingCenter]
      ,[CostCenter]
      ,[ICDCode]
      ,[OMNIID]
      ,[OMNIName]
      ,[UserID]
      ,[UserName]
      ,[WitnessID]
      ,[WitnessName]
      ,[IsAlergy]
      ,[IsNullType]
      ,[QuantityIssued]
      ,[QuantityOnhand]
      ,[QuantityWasted]
      ,[QuantityRequested]
      ,[QuantityCountedback]
      ,[IsIssuedToDischargedPatients]
      ,[IsMedicationOverridden]
      ,[ReturnReason]
      ,[DoseAmount]
      ,[ActualDoseAmount]
      ,[IsDoseTransaction]
      ,[IsItemScanType]
      ,[IsItemScanOverride]
      ,[TotalItemQuantityOnhand]
      ,[MedicationScheduledTimestamp]
      ,[IsAlertDispensingItem]
	  ,FiscalYearLong
  FROM [SourceDataArchive].[Pharmacy].[LGHAdmin1] F
left outer join DSDW.Dim.Date D on left(TransactionTimestamp,8) = D.DateID

Union all

SELECT [FacilityCode]
      ,[FacilityName]
      ,D.dateID
      ,[TransferType]
      ,[TransactionBillingTimestamp]
      ,[NursingCenter]
      ,[CostCenter]
      ,[ICDCode]
      ,[OMNIID]
      ,[OMNIName]
      ,[UserID]
      ,[UserName]
      ,[WitnessID]
      ,[WitnessName]
      ,[IsAlergy]
      ,[IsNullType]
      ,[QuantityIssued]
      ,[QuantityOnhand]
      ,[QuantityWasted]
      ,[QuantityRequested]
      ,[QuantityCountedback]
      ,[IsIssuedToDischargedPatients]
      ,[IsMedicationOverridden]
      ,[ReturnReason]
      ,[DoseAmount]
      ,[ActualDoseAmount]
      ,[IsDoseTransaction]
      ,[IsItemScanType]
      ,[IsItemScanOverride]
      ,[TotalItemQuantityOnhand]
      ,[MedicationScheduledTimestamp]
      ,[IsAlertDispensingItem]
	  ,FiscalYearLong
  FROM [SourceDataArchive].[Pharmacy].[PHCAdmin1] F
left outer join DSDW.Dim.Date D on left(TransactionTimestamp,8) = D.DateID

GO
/****** Object:  View [DataProfile].[vwPharmacyAdmin2]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
Create View [DataProfile].[vwPharmacyAdmin2]
as
SELECT [FacilityCode]
      ,[FacilityName]
      ,[PharmacyDescription]
      ,D.dateID
      ,[TransferType]
      ,[ChargeID]
      ,[UnitOfIssue]
      ,[UnitCost]
      ,[UnitPrice]
      ,[SNTracking]
      ,[IsWasteWitnessRequied]
      ,[IsRestockWitnessRequired]
      ,[IsAccessRestricted]
      ,[IsMedicationOrderRequired]
      ,[IsFirstDoseAtOrderStart]
      ,[MedicationOrderPhysicianID]
      ,[MedicationOrderPharmacistID]
      ,[ComponentType]
      ,[DrugCode]
      ,[DrugName]
      ,[DrugDose]
      ,[DrugDoseMax]
      ,[DrugDoseUnit]
      ,[Route]
      ,[DrugStrength]
      ,[DrugStrengthUnit]
      ,[DrugAdministrationAmount]
      ,[Frequency]
      ,[Interval]
      ,[Duration]
      ,[DosageForm]
      ,[AdministrationTimes]
      ,[DrugAdministrationUnits]
      ,[IsMedicationOrderAlerted]
      ,[DispensePackageMethod]
      ,[DrugDoseUnits]
      ,[IsMedicationEarlyWindow]
      ,[IsMedicationLateWindow]
      ,[MedicationScheduledDays]
      ,[MedicationOrderingPhysianID]
      ,[MedicationPSStatus]
      ,[MedicationQuantity]
      ,[MedicationOrderStatus]
      ,[MedicationTotalVolumeUnits]
      ,[MedicationTotalVolume]
      ,[AdministrationInstructions]
      ,[MedicationBaseVolumeAmount]
      ,[MedicationBaseVolumeUnits]
      ,[MedicationBaseDosageForm]
      ,[ConcatPharmacyDosageSuffix]
      ,[MedicationBaseStrength]
      ,[MedicationBaseStrengthUnits]
      ,[MedicationBaseTotalVolume]
      ,[MedicationBaseTotalVolumeUnits]
      ,[PRN]
      ,[OrderStartTime]
      ,[OrderEndTime]
      ,[ItemControlLevel]
      ,[ItemChargeType]
      ,[TransactionType]
      ,[TransactionSubType]
      ,[TransactionDueType]
      ,FiscalYearLong
  FROM [SourceDataArchive].[Pharmacy].[LGHAdmin2] F
left outer join DSDW.Dim.Date D on left(TransactionTimestamp,8) = D.DateID


union all 

SELECT [FacilityCode]
      ,[FacilityName]
      ,[PharmacyDescription]
      ,D.dateID
      ,[TransferType]
      ,[ChargeID]
      ,[UnitOfIssue]
      ,[UnitCost]
      ,[UnitPrice]
      ,[SNTracking]
      ,[IsWasteWitnessRequied]
      ,[IsRestockWitnessRequired]
      ,[IsAccessRestricted]
      ,[IsMedicationOrderRequired]
      ,[IsFirstDoseAtOrderStart]
      ,[MedicationOrderPhysicianID]
      ,[MedicationOrderPharmacistID]
      ,[ComponentType]
      ,[DrugCode]
      ,[DrugName]
      ,[DrugDose]
      ,[DrugDoseMax]
      ,[DrugDoseUnit]
      ,[Route]
      ,[DrugStrength]
      ,[DrugStrengthUnit]
      ,[DrugAdministrationAmount]
      ,[Frequency]
      ,[Interval]
      ,[Duration]
      ,[DosageForm]
      ,[AdministrationTimes]
      ,[DrugAdministrationUnits]
      ,[IsMedicationOrderAlerted]
      ,[DispensePackageMethod]
      ,[DrugDoseUnits]
      ,[IsMedicationEarlyWindow]
      ,[IsMedicationLateWindow]
      ,[MedicationScheduledDays]
      ,[MedicationOrderingPhysianID]
      ,[MedicationPSStatus]
      ,[MedicationQuantity]
      ,[MedicationOrderStatus]
      ,[MedicationTotalVolumeUnits]
      ,[MedicationTotalVolume]
      ,[AdministrationInstructions]
      ,[MedicationBaseVolumeAmount]
      ,[MedicationBaseVolumeUnits]
      ,[MedicationBaseDosageForm]
      ,[ConcatPharmacyDosageSuffix]
      ,[MedicationBaseStrength]
      ,[MedicationBaseStrengthUnits]
      ,[MedicationBaseTotalVolume]
      ,[MedicationBaseTotalVolumeUnits]
      ,[PRN]
      ,[OrderStartTime]
      ,[OrderEndTime]
      ,[ItemControlLevel]
      ,[ItemChargeType]
      ,[TransactionType]
      ,[TransactionSubType]
      ,[TransactionDueType]
      ,FiscalYearLong
  FROM [SourceDataArchive].[Pharmacy].[VAAdmin2] F
left outer join DSDW.Dim.Date D on left(TransactionTimestamp,8) = D.DateID


union all

SELECT [FacilityCode]
      ,[FacilityName]
      ,[PharmacyDescription]
      ,D.dateID
      ,[TransferType]
      ,[ChargeID]
      ,[UnitOfIssue]
      ,[UnitCost]
      ,[UnitPrice]
      ,[SNTracking]
      ,[IsWasteWitnessRequied]
      ,[IsRestockWitnessRequired]
      ,[IsAccessRestricted]
      ,[IsMedicationOrderRequired]
      ,[IsFirstDoseAtOrderStart]
      ,[MedicationOrderPhysicianID]
      ,[MedicationOrderPharmacistID]
      ,[ComponentType]
      ,[DrugCode]
      ,[DrugName]
      ,[DrugDose]
      ,[DrugDoseMax]
      ,[DrugDoseUnit]
      ,[Route]
      ,[DrugStrength]
      ,[DrugStrengthUnit]
      ,[DrugAdministrationAmount]
      ,[Frequency]
      ,[Interval]
      ,[Duration]
      ,[DosageForm]
      ,[AdministrationTimes]
      ,[DrugAdministrationUnits]
      ,[IsMedicationOrderAlerted]
      ,[DispensePackageMethod]
      ,[DrugDoseUnits]
      ,[IsMedicationEarlyWindow]
      ,[IsMedicationLateWindow]
      ,[MedicationScheduledDays]
      ,[MedicationOrderingPhysianID]
      ,[MedicationPSStatus]
      ,[MedicationQuantity]
      ,[MedicationOrderStatus]
      ,[MedicationTotalVolumeUnits]
      ,[MedicationTotalVolume]
      ,[AdministrationInstructions]
      ,[MedicationBaseVolumeAmount]
      ,[MedicationBaseVolumeUnits]
      ,[MedicationBaseDosageForm]
      ,[ConcatPharmacyDosageSuffix]
      ,[MedicationBaseStrength]
      ,[MedicationBaseStrengthUnits]
      ,[MedicationBaseTotalVolume]
      ,[MedicationBaseTotalVolumeUnits]
      ,[PRN]
      ,[OrderStartTime]
      ,[OrderEndTime]
      ,[ItemControlLevel]
      ,[ItemChargeType]
      ,[TransactionType]
      ,[TransactionSubType]
      ,[TransactionDueType]
      ,FiscalYearLong
  FROM [SourceDataArchive].[Pharmacy].[PHCAdmin2] F
left outer join DSDW.Dim.Date D on left(TransactionTimestamp,8) = D.DateID

GO
/****** Object:  View [dbo].[vwBizRules]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 create  view [dbo].[vwBizRules] as  
select PkgName,STageName,scheduleID,BR.*,JoinNumber,SourceLookupExpression,DimensionLookupExpression,IsSourcePreviousValue
from DQMF.dbo.DQMF_BizRule BR
	inner join DQMF.dbo.DQMF_BizRuleSchedule BRS on BR.BRID = BRS.BRID
	inner join DQMF.dbo.DQMF_Schedule S on BRS.ScheduleId = S.DQMF_ScheduleId
	inner join DQMF.dbo.DQMF_Stage St on S.StageID = St.StageID
	inner join DQMF.dbo.ETL_Package P on S.PkgKey = P.PkgID
	left outer join DQMF.dbo.DQMF_BizRuleLookupMapping BRLM on BR.BRID = BRLM.BRID
GO
/****** Object:  View [dbo].[vwBizRuleWithNoFactTableObjectAttributeId]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT * FROM [dbo].[vwBizRuleWithNoFactTableObjectAttributeId]
CREATE VIEW [dbo].[vwBizRuleWithNoFactTableObjectAttributeId]
AS

 SELECT p.PkgName, IsPackageActive = p.IsActive,t.StageName, IsScheduleActive = s.IsScheduleActive, s.DQMF_ScheduleID,
		b.BRId, 
		b.ShortNameOfTest, 
		b.RuleDesc, 
		b.TargetObjectPhysicalName,
		b.TargetObjectAttributePhysicalName,
		b.FactTableObjectAttributeId, b.FactTableObjectAttributeName,
		[MD FactTableObjectAttribute] = MD.[DatabaseName] +'.'+MD.[ObjectSchemaName]+'.'+[ObjectPhysicalName]+'.'+[AttributePhysicalName],
		[MD FactTableObjectType] = MD.ObjectType,
		b.ActionID, 
		b.SourceObjectPhysicalName,
		SourcePreviousValue = m.SourceLookupExpression,
		b.GUID,
		IsBRActive  = b.IsActive,
		b.IsLogged
FROM DQMF.dbo.DQMF_Stage AS t
INNER JOIN DQMF.dbo.DQMF_Schedule AS s on s.StageID = t.StageID 
INNER JOIN DQMF.dbo.DQMF_BizRuleSchedule sb on sb.ScheduleID = s.DQMF_ScheduleID
INNER JOIN DQMF.dbo.ETL_Package p ON p.PkgID =s.Pkgkey
INNER JOIN DQMF.dbo.DQMF_BizRule b on sb.brid = b.brid
LEFT JOIN dbo.DQMF_BizRuleLookupMapping m ON m.brid = b.brid AND m.IsSourcePreviousValue = 1
LEFT JOIN dbo.vwMD_PhyscialName MD ON MD.ObjectAttributeID = b.FactTableObjectAttributeId
WHERE b.IsActive = 1 
  AND b.ActionID IN (0,1,2) 
  AND b.IsLogged = 1
  AND (ISNULL(b.FactTableObjectAttributeId,0) = 0
   OR ISNULL(MD.ObjectType,'') <> 'Table')
			


GO
/****** Object:  View [dbo].[vwETLBizruleAuditFact]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View [dbo].[vwETLBizruleAuditFact] 
AS
Select *
FROM [DQMF].[dbo].[ETLBizruleAuditFact] WITH (NOLOCK)
GO
/****** Object:  View [dbo].[vwGetQualityRating]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW  [dbo].[vwGetQualityRating]
as
	select  RatingName, RBR.BRID, ShortNameOfTest, RuleDesc,ETLID
	from dqmf.dbo.etlbizruleauditfact BRF 
		inner join dqmf.dbo.auditqulaityratingbizrule RBR on BRF.brid = RBR.brid 
		inner join dqmf.dbo.AuditQualityRating AQR on RBR.qualityratingid = AQR.qualityratingid 
		left outer join dbo.DQMF_BizRule BR on RBR.BRid = BR.BRid
GO
/****** Object:  View [dbo].[vwMD_PhyscialName]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SELECT * FROM [dbo].[vwMD_PhyscialName]
-- SELECT distinct ObjectType FROM [dbo].[vwMD_PhyscialName]
CREATE VIEW [dbo].[vwMD_PhyscialName]
AS

SELECT sb.SubjectAreaName, sb.SubjectAreaStewardContact
,LTRIM(RTRIM(db.DatabaseName)) DatabaseName
,LTRIM(RTRIM(o.ObjectType)) ObjectType
,LTRIM(RTRIM(o.ObjectSchemaName)) ObjectSchemaName
,LTRIM(RTRIM(o.ObjectPhysicalName)) ObjectPhysicalName
,LTRIM(RTRIM(oa.AttributePhysicalName)) AttributePhysicalName

,o.DatabaseID, o.SubjectAreaID, o.ObjectID, o.KeyDateObjectAttributeID
,oa.ObjectAttributeID, oa.sequence
,oa.IsActive IsObjectAttributeActive
,o.IsActive IsObjectActive
,o.IsObjectInDB
FROM dbo.MD_ObjectAttribute oa 
INNER JOIN dbo.MD_Object o ON o.ObjectID = oa.ObjectID
INNER JOIN dbo.MD_Database db ON db.DatabaseID = o.DatabaseID
INNER JOIN dbo.MD_SubjectArea sb ON sb.SubjectAreaID = o.SubjectAreaID
--WHERE oa.IsActive = 1
--  AND o.IsObjectInDB = 1
GO
/****** Object:  Index [IX_BRID]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE CLUSTERED INDEX [IX_BRID] ON [dbo].[AuditBizRuleAction4Execution]
(
	[BRID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [PK_AuditPkgExecution]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE UNIQUE CLUSTERED INDEX [PK_AuditPkgExecution] ON [dbo].[AuditPkgExecution]
(
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF, FILLFACTOR = 80) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IDX1_ProfileDefinition_Environment]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_ProfileDefinition_Environment] ON [DataProfile].[ProfileDefinition]
(
	[Environment] ASC
)
INCLUDE ( 	[ProfileID],
	[DestinationTable]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX1_ProfileSummary_CreatedDT]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_ProfileSummary_CreatedDT] ON [DataProfile].[ProfileSummary]
(
	[ProfileID] ASC
)
INCLUDE ( 	[CreatedDT]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX1_BRID]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_BRID] ON [dbo].[AuditBizRuleExecution]
(
	[BRID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX1_AuditDataCorrectionMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_AuditDataCorrectionMapping] ON [dbo].[AuditDataCorrectionMapping]
(
	[SubjectAreaID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [PkgExecKey]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [PkgExecKey] ON [dbo].[AuditExtractFile]
(
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [ETL_PackageAuditPkgExecution]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [ETL_PackageAuditPkgExecution] ON [dbo].[AuditPkgExecution]
(
	[PkgKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [ParentPkgExecKey]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [ParentPkgExecKey] ON [dbo].[AuditPkgExecution]
(
	[ParentPkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [PkgGUID]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [PkgGUID] ON [dbo].[AuditPkgExecution]
(
	[PkgKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [TableProcessKey]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [TableProcessKey] ON [dbo].[AuditPkgExecution]
(
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [AuditPkgExecutionAuditTableProcessing]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [AuditPkgExecutionAuditTableProcessing] ON [dbo].[AuditTableProcessing]
(
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [PkgExecKey]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [PkgExecKey] ON [dbo].[AuditTableProcessing]
(
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [TableProcessKey]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [TableProcessKey] ON [dbo].[AuditTableProcessing]
(
	[TableProcessKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [DatabaseId]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [DatabaseId] ON [dbo].[DQMF_BizRule]
(
	[DatabaseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [DQMF_ActionDQMF_BizRule]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [DQMF_ActionDQMF_BizRule] ON [dbo].[DQMF_BizRule]
(
	[ActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX1_DQMF_DataCorrectionMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_DQMF_DataCorrectionMapping] ON [dbo].[DQMF_DataCorrectionMapping]
(
	[BRID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX2_DQMF_DataCorrectionMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX2_DQMF_DataCorrectionMapping] ON [dbo].[DQMF_DataCorrectionMapping]
(
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX1_DQMF_DataCorrectionWorking]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_DQMF_DataCorrectionWorking] ON [dbo].[DQMF_DataCorrectionWorking]
(
	[SubjectAreaID] ASC,
	[BRID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX2_DQMF_DataCorrectionWorking]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX2_DQMF_DataCorrectionWorking] ON [dbo].[DQMF_DataCorrectionWorking]
(
	[SubjectAreaID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [ETL_PackageDQMF_Schedule]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [ETL_PackageDQMF_Schedule] ON [dbo].[DQMF_Schedule]
(
	[PkgKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [MD_DatabaseDQMF_Schedule]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [MD_DatabaseDQMF_Schedule] ON [dbo].[DQMF_Schedule]
(
	[DatabaseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [PkgKey]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [PkgKey] ON [dbo].[DQMF_Schedule]
(
	[PkgKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [TableId]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [TableId] ON [dbo].[DQMF_Schedule]
(
	[TableId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IDU_DQMFStage]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IDU_DQMFStage] ON [dbo].[DQMF_Stage]
(
	[StageName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF, FILLFACTOR = 80) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [ETLStagingKeySequenceId]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [ETLStagingKeySequenceId] ON [dbo].[ETL_AuditControl]
(
	[ETL_AuditControlRecord] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [LastValueFor_ETLId]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [LastValueFor_ETLId] ON [dbo].[ETL_AuditControl]
(
	[LastValueFor_ETLId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IDX1_AduitFact]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX1_AduitFact] ON [dbo].[ETLBizruleAuditFact]
(
	[BRId] ASC
)
INCLUDE ( 	[ETLId],
	[PreviousValue],
	[ISCorrected]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX2_AduitFact]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX2_AduitFact] ON [dbo].[ETLBizruleAuditFact]
(
	[ETLId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX2_ETLStagingRecord]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX2_ETLStagingRecord] ON [dbo].[ETLStagingRecord]
(
	[MergedETLID] ASC,
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF, FILLFACTOR = 80) ON [PRIMARY]
GO
/****** Object:  Index [IDX3_ETLStagingRecord]    Script Date: 6/4/2016 1:54:47 PM ******/
CREATE NONCLUSTERED INDEX [IDX3_ETLStagingRecord] ON [dbo].[ETLStagingRecord]
(
	[ETLId] ASC,
	[PkgExecKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF, FILLFACTOR = 80) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__PkgEx__08EA5793]  DEFAULT ((0)) FOR [PkgExecKey]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Extra__09DE7BCC]  DEFAULT ((0)) FOR [ExtractRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Extra__0AD2A005]  DEFAULT ((0)) FOR [ExtractCheckValue1]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Extra__0BC6C43E]  DEFAULT ((0)) FOR [ExtractCheckValue2]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Inser__0CBAE877]  DEFAULT ((0)) FOR [InsertStdRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Inser__0DAF0CB0]  DEFAULT ((0)) FOR [InsertStdCheckValue1]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Inser__0EA330E9]  DEFAULT ((0)) FOR [InsertStdCheckValue2]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Inser__0F975522]  DEFAULT ((0)) FOR [InsertNonStdRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Inser__108B795B]  DEFAULT ((0)) FOR [InsertNonStdCheckValue1]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Inser__117F9D94]  DEFAULT ((0)) FOR [InsertNonStdCheckValue2]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Updat__1273C1CD]  DEFAULT ((0)) FOR [UpdateRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Error__1367E606]  DEFAULT ((0)) FOR [ErrorRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Table__145C0A3F]  DEFAULT ((0)) FOR [TableInitialRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__Table__15502E78]  DEFAULT ((0)) FOR [TableFinalRowCnt]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__IsSuc__164452B1]  DEFAULT ((0)) FOR [IsSuccessfulProcessing]
GO
ALTER TABLE [dbo].[AuditTableProcessing] ADD  CONSTRAINT [DF__AuditTabl__IsSuc__173876EA]  DEFAULT ((0)) FOR [IsSuccessfulASPProcessing]
GO
ALTER TABLE [dbo].[DQMF_OlsonType] ADD  CONSTRAINT [DF__DQMF_Olso__SortO__31EC6D26]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [dbo].[dtproperties] ADD  DEFAULT ((0)) FOR [version]
GO
ALTER TABLE [dbo].[DQMF_Schedule]  WITH CHECK ADD  CONSTRAINT [FK_DQMF_Schedule_ETL_Package] FOREIGN KEY([PkgKey])
REFERENCES [dbo].[ETL_Package] ([PkgID])
GO
ALTER TABLE [dbo].[DQMF_Schedule] CHECK CONSTRAINT [FK_DQMF_Schedule_ETL_Package]
GO
/****** Object:  Trigger [dbo].[tr_FactTableObjectAttributeName]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[tr_FactTableObjectAttributeName]
ON [dbo].[DQMF_BizRule]
FOR INSERT,UPDATE AS
BEGIN
  UPDATE BR
   SET FactTableObjectAttributeName = OA.AttributePhysicalName
		,SecondaryFactTableObjectAttributeName = OA2.AttributePhysicalName
	From dbo.DQMF_BizRule BR
	inner join inserted I on BR.BRID = I.BRId
	inner join DQMF.dbo.MD_ObjectAttribute OA on BR.FactTableObjectAttributeId = OA.ObjectAttributeID
	left outer join DQMF.dbo.MD_ObjectAttribute OA2 on BR.SecondaryFactTableObjectAttributeID = OA2.ObjectAttributeID
	where BR.BRId = I.BRID 

END;

GO
/****** Object:  Trigger [dbo].[trg_DQMFBizrule_upd]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Created by: Jeff Sheppard
Create date: Aug 20 2014
Description: Trigger is used to force the update of the username and updatedt colukmns. specifically for when users set bizrules to active.
*/
CREATE TRIGGER [dbo].[trg_DQMFBizrule_upd]
ON [dbo].[DQMF_BizRule]
FOR UPDATE
AS
BEGIN

IF TRIGGER_NESTLEVEL() > 1 RETURN

UPDATE [dbo].[DQMF_BizRule]
SET [UpdatedBy] = SYSTEM_USER, [UpdatedDT] = GETDATE()
FROM [dbo].[DQMF_BizRule] B
INNER JOIN inserted i ON B.[BRId] = i.[BRId]

END

GO
/****** Object:  Trigger [dbo].[trDQMF_BizRuleLookupMapping]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE TRIGGER [dbo].[trDQMF_BizRuleLookupMapping] ON [dbo].[DQMF_BizRuleLookupMapping]
FOR INSERT, UPDATE
AS 
/*
	Prevent IsSourcePreviousValue was set to 1 or True for more than 1 row for a BRId 
	But this will not stop us from having No Row was set to IsSourcePreviousValue = 1 for a BRId
*/
BEGIN
IF EXISTS (
	SELECT BRID, COUNT(*) AS NumofRows
	FROM dbo.DQMF_BizRuleLookupMapping 
	WHERE IsSourcePreviousValue = 1 AND BRId IN (SELECT DISTINCT BRId FROM inserted)
	GROUP BY BRId
	HAVING COUNT(*) > 1
)
BEGIN
	RAISERROR (N'Can''t have more than one IsSourcePreviousValue set to True, deactivate current IsSourcePreviousValue first.', 10,1)
	ROLLBACK TRAN
END
END

GO
/****** Object:  Trigger [dbo].[TrDQMF_DataCorrectionMappingUpdate]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Lien le
-- Create date: Jun-6-2013
-- Description:	Trigger to set IsFirstRun = 1 where IsActive = 1 and either Field IsEffectiveDateApplied, IsActive, MapToID or IsForDQ is changed
-- =============================================
CREATE TRIGGER [dbo].[TrDQMF_DataCorrectionMappingUpdate] ON [dbo].[DQMF_DataCorrectionMapping]
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON
	
	UPDATE m
	 SET UpdatedDate = GETDATE()
		,UpdatedBy = suser_sname()
		,IsForDQ = CASE WHEN m.MapToID > 0 THEN 0 ELSE 1 END
		,IsFirstRun = CASE WHEN m.IsActive = 1
							AND (ISNULL(ins.IsActive,0) <> ISNULL(del.IsActive,0)
						     OR ins.MapToID <> del.MapToID 
						     OR ins.IsForDQ <> del.IsForDQ
							 OR ins.IsEffectiveDateApplied <> del.IsEffectiveDateApplied) THEN 1
							ELSE m.IsFirstRun
					  END
	FROM dbo.DQMF_DataCorrectionMapping m
	JOIN INSERTED ins ON ins.DataCorrectionMappingID = m.DataCorrectionMappingID
	JOIN DELETED  del ON del.DataCorrectionMappingID = m.DataCorrectionMappingID
	  

	SET NOCOUNT ON;
    
END

GO
/****** Object:  Trigger [dbo].[trg_MD_Audit_Database_ins_upd_del]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[trg_MD_Audit_Database_ins_upd_del] ON [dbo].[MD_Database] FOR INSERT, UPDATE, DELETE
AS

	DECLARE @UserName varchar(100);
	DECLARE @Date datetime;

	SET @UserName = (SELECT SYSTEM_USER);
	SET @Date = GETDATE()

BEGIN

INSERT into dbo.MD_Audit
(
UserName, Date, MD_Table
)
VALUES (@UserName, @Date, 'MD_Database')

END
GO
/****** Object:  Trigger [dbo].[trg_MD_Audit_Object_ins_upd_del]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[trg_MD_Audit_Object_ins_upd_del] ON [dbo].[MD_Object] FOR INSERT, UPDATE, DELETE
AS

	DECLARE @UserName varchar(100);
	DECLARE @Date datetime;

	SET @UserName = (SELECT SYSTEM_USER);
	SET @Date = GETDATE()

BEGIN

INSERT into dbo.MD_Audit
(
UserName, Date, MD_Table
)
VALUES (@UserName, @Date, 'MD_Objects')

END





GO
/****** Object:  Trigger [dbo].[trg_MD_Object_upd]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Created by: Jeff Sheppard
Create date: Aug 20 2014
Description: Trigger is used to force the update of the username and updatedt colukmns. specifically for when users set bizrules to active.
*/
Create TRIGGER [dbo].[trg_MD_Object_upd]
ON [dbo].[MD_Object]
FOR UPDATE
AS
BEGIN

IF TRIGGER_NESTLEVEL() > 1 RETURN

UPDATE [dbo].[MD_Object]
SET [UpdatedBy] = SYSTEM_USER, [UpdatedDT] = GETDATE()
FROM [dbo].[MD_Object] B
INNER JOIN inserted i ON B.[ObjectID] = i.[ObjectID]

END

GO
/****** Object:  Trigger [dbo].[trg_MD_Audit_SubjectArea_ins_upd_del]    Script Date: 6/4/2016 1:54:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [dbo].[trg_MD_Audit_SubjectArea_ins_upd_del] ON [dbo].[MD_SubjectArea] FOR INSERT, UPDATE, DELETE
AS

	DECLARE @UserName varchar(100);
	DECLARE @Date datetime;

	SET @UserName = (SELECT SYSTEM_USER);
	SET @Date = GETDATE()

BEGIN

INSERT into dbo.MD_Audit
(
UserName, Date, MD_Table
)
VALUES (@UserName, @Date, 'MD_SubjectArea')

END





GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'New row for every extract file' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractFileKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractFileKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK to the package execution table, i.e. the package instantiation that processed this file' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Physical disk address where file is stored' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractFilePhysicalLocation' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'250' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractFilePhysicalLocation' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFilePhysicalLocation'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that the package STARTS  processing this file' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractFileProcessStartDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractFileProcessStartDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that the package STOPS processing this file' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractFileProcessStopDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractFileProcessStopDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileProcessStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime the file was created at source' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractFileCreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractFileCreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'ExtractFileCreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Yes means okay to process, No means processing stopped' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'106' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Format', @value=N'Yes/No' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'IsFileGoodEnoughToProcess' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'IsFileGoodEnoughToProcess' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile', @level2type=N'COLUMN',@level2name=N'IsProcessSuccess'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/6/2009 5:51:14 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/8/2009 2:26:06 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'AuditExtractFile' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditExtractFile'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'New row every time a package is executed.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Optional key to invoking package.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ParentPkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ParentPkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ParentPkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of the package, which might change over time, example different versions' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'100' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique identifier of the package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgVersionMajor' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgVersionMajor' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMajor'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgVersionMinor' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgVersionMinor' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'PkgVersionMinor'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime at which the execution of this package started' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExecStartDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExecStartDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStartDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime at which the execution stopped' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExecStopDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExecStopDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'ExecStopDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Flag saying whether the package was successful or had to halt due to problems' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'106' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Format', @value=N'Yes/No' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'IsPackageSuccessful' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'IsPackageSuccessful' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution', @level2type=N'COLUMN',@level2name=N'IsPackageSuccessful'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'2/7/2009 5:14:27 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/20/2009 10:50:19 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'AuditPkgExecution' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditPkgExecution'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'New row everytime a table is manipulated during a package''s execution; i.e.  inserts, updates and deletes.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'TableProcessKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'TableProcessKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableProcessKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK to the package execution that is manipulating this table' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgExecKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'PkgExecKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of the database this process was run in.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DatabaseName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'DatabaseName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'DatabaseName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of the table, or the key?' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'TableName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'100' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'TableName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows in the extract' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Records important information about this table, examples are row count, average RIW, average patient age   Note: NON-INTEGER' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractCheckValue1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractCheckValue1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Yet another check value, useful over time as you look at the averages, row counts etc of each table, and start to establish patterns of acceptability' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ExtractCheckValue2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ExtractCheckValue2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ExtractCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows standardly inserted into the table' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'InsertStdRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'InsertStdRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Check value for rows standardly inserted' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'InsertStdCheckValue1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'InsertStdCheckValue1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Another check value' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'InsertStdCheckValue2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'9' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'InsertStdCheckValue2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows inserted into the table in a NON-STANDARD way, for example, maybe they needed fuzzy matching' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'InsertNonStdRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'InsertNonStdRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Check value for rows inserted NON-Standardly into the table' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'InsertNonStdCheckValue1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'11' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'InsertNonStdCheckValue1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue1'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Another check value, you can leave some or all the check values empty for some or all tables!!!!!!!!!!!!' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'InsertNonStdCheckValue2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'InsertNonStdCheckValue2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'InsertNonStdCheckValue2'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows updated' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdateRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'13' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdateRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'UpdateRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows that were in ERROR' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ErrorRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'14' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ErrorRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'ErrorRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows in the table BEFORE this package started manipulating the table' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'TableInitialRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'15' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'TableInitialRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableInitialRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Number of rows in the table AFTER this package finished, hopefully it bears a strong resemblance to Initial + Inserted counts  :)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'TableFinalRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'16' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'TableFinalRowCnt' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'TableFinalRowCnt'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'True if the package succeeded for this table, FALSE otherwise' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'106' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Format', @value=N'Yes/No' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'IsSuccessfulProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'IsSuccessfulProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'True if the OLAP processing succeeded on this table,      not sure if you want this column' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'106' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Format', @value=N'Yes/No' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'IsSuccessfulASPProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'18' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'IsSuccessfulASPProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing', @level2type=N'COLUMN',@level2name=N'IsSuccessfulASPProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'2/7/2009 5:34:14 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/7/2009 1:35:21 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'AuditTableProcessing'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name and key of the action to be performed if the condition is true' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ActionName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'30' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ActionName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Action' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'To be filled with a scintillating, yet somber, description of this action' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ActionDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ActionDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Action' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action', @level2type=N'COLUMN',@level2name=N'ActionDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/8/2009 11:38:43 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/8/2009 11:53:59 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_Action' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Action'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'衦ꌞ邘䘛誋磠섏歀' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Business Rule Unique Id' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'BRId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'BRId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'BRId'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'႑お鄪䇅冐娢�䅂' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Shortish name of the test, ex: "Check for Null" or "Check for Discharge b4 Admission"' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ShortNameOfTest' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'100' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ShortNameOfTest' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ShortNameOfTest'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'ﻗ랸싌䛏㥝؈둌' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Dynamic SQL to be tested for, " where AdmitDate > DischargeDate"' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ConditionSQL' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'250' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ConditionSQL' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ConditionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'㏮䲴ႇᜢ⛿掣' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK Action to be taken if ConditionSQL is true,ex: "Default", "Error", "Exception", "ControlLimit", "Impute"' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ActionName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'30' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ActionName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionID'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Dynamic SQL to be executed for Update, Default, etc' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ActionSQL' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'250' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ActionSQL' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'ActionSQL'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'쨿⛖泡䋧ẩ鸞ԝ�' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK name of the type of Olson test, see Jack Olson, "Data Quality: The Accuracy Dimension", 1-Colm, 2-Structure, 3-SimpleBR, 4-ComplexBr, 5-Value' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'OlsonTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'30' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'OlsonTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'OlsonTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'᪰餿ᝑ䄐㎾芈䗒' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK name of the severity type incurred when this BR lights up' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'SeverityTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'30' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'SeverityTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'SeverityTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'100' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Sequence number used to order business rules within a schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'Sequence' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'Sequence' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'Sequence'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK to the database containing table and attribute' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DatabaseId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'9' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'DatabaseId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'True if active, false if not to be run' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'106' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Format', @value=N'Yes/No' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'RuleStatus' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'RuleStatus' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'IsActive'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logon of person who created this record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'CreatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'13' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'CreatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that this record was created' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'CreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'14' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'CreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logon of person who last updated this record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'15' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that this record was created' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'16' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/6/2009 6:36:56 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/9/2009 5:31:17 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_BizRule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_BizRule'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'2055' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'抟ང䤾놥⡆' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Key and name of the type of Olson test, ex: "Column", "Structure"' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'OlsonTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'30' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'OlsonTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_OlsonType' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'7845' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'嗗錖霖䋢㞱녟ⵀ࿡' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Full description' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'OlsonTypeDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'OlsonTypeDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_OlsonType' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'OlsonTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'錳桰俎嚥䂚㱥쒶' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'SortOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'SortOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_OlsonType' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/8/2009 11:36:49 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/9/2009 2:24:16 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=N'DQMF_OlsonType.SortOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_OlsonType' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_OlsonType'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Primary key for the parent of business rule schedules' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_ScheduleId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'DQMF_ScheduleId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DQMF_ScheduleId'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK of the database in which this schedule may be run' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DatabaseId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'DatabaseId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'DatabaseId'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK of the table that this package is running against, used to create AuditTableProcessing' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'TableId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'TableId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'TableId'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'FK to the Package that will run this schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'PkgKey'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Yes if Schedule is active, false otherwise' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'106' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Format', @value=N'Yes/No' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'IsScheduleActive' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'IsScheduleActive' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'IsScheduleActive'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logon of person who created this record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'CreatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'CreatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that this record was created' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'CreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'7' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'CreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logon of person who last updated this record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that this record was created' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'9' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/8/2009 11:15:52 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/15/2009 1:22:16 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_Schedule' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Schedule'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Key and Name of severity metric generated when the business rule is invoked' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'SeverityTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'30' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'SeverityTypeName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Severity' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Please make it scintillating, eschew obdurate verbiage' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'SeverityTypeDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'SeverityTypeDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Severity' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SeverityTypeDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'0 means okay, 5 is ugly, 10 is too ugly to live, these values will be stamped on the ETLStagingBizRuleAuditFact' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'NegativeRating' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'NegativeRating' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Severity' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'NegativeRating'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'SortOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'SortOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Severity' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity', @level2type=N'COLUMN',@level2name=N'SortOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/8/2009 12:01:50 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/8/2009 1:30:09 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=N'DQMF_Severity.SortOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_Severity' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Severity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageID'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=2775 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Key of the table, name of the stage at which business rules are applied' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'StageName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'StageName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Stage' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Description of the stage, usually filled in with a dramatic flair, possibly 300 pages, or at least a novella. :)' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'StageDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'StageDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Stage' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Order in which the stages are run' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'StageOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'StageOrder' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'DQMF_Stage' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage', @level2type=N'COLUMN',@level2name=N'StageOrder'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/8/2009 11:18:54 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/9/2009 3:15:31 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=0x02 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Filter', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_FilterOnLoad', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_HideNewField', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=N'[DQMF_Stage].[StageName]' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOnLoad', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TableMaxRecords', @value=10000 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TotalsRow', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'DQMF_Stage' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'DQMF_Stage'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'ᦣ醦䆯狮點赇' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Always equal to "VCHA"' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ETL_AuditControlRecord' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'ETL_AuditControlRecord' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_AuditControl' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'ValidationRule', @value=N'"VCHA"' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'ValidationText', @value=N'Sorry there can only be one audit control record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'ETL_AuditControlRecord'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'DefaultValue', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'GUID', @value=N'䟸膚䔻䂬ꬶ﷨' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DecimalPlaces', @value=N'255' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The last value used in creating an ETLStagingRecord. Used in ETL process to assign a block of numbers.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'LastValueFor_ETLId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'LastValueFor_ETLId' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_AuditControl' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl', @level2type=N'COLUMN',@level2name=N'LastValueFor_ETLId'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/8/2009 2:43:11 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/8/2009 2:43:14 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ETL_AuditControl' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_AuditControl'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'17' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique primary key for packages' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgKey' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgID'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Name of the package - does  not include versions' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'100' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgName' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgName'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Full description of the package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'PkgDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'PkgDescription' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'12' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'PkgDescription'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logon of person who created this record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'CreatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'CreatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that this record was created' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'CreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'4' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'CreatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'CreatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Logon of person who last updated this record' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DisplayControl', @value=N'109' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'5' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'50' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdatedBy' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'10' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'UnicodeCompression', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedBy'
GO
EXEC sys.sp_addextendedproperty @name=N'AllowZeroLength', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'CollatingOrder', @value=N'1033' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnHidden', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnOrder', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'ColumnWidth', @value=N'-1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'DataUpdatable', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Datetime that this record was created' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMEMode', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_IMESentMode', @value=N'3' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'UpdatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'OrdinalPosition', @value=N'6' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Required', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Size', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceField', @value=N'UpdatedDT' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'SourceTable', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Type', @value=N'8' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package', @level2type=N'COLUMN',@level2name=N'UpdatedDT'
GO
EXEC sys.sp_addextendedproperty @name=N'Attributes', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'DateCreated', @value=N'4/9/2009 2:38:34 PM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'LastUpdated', @value=N'4/20/2009 10:50:19 AM' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=N'2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=N'False' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'Name', @value=N'ETL_Package' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'RecordCount', @value=N'0' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
EXEC sys.sp_addextendedproperty @name=N'Updatable', @value=N'True' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'ETL_Package'
GO
