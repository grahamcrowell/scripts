
--;WITH xjoin AS (
--SELECT 
--	COUNT(DISTINCT fact1.SourceSystemClientID) AS DistinctClientCount
--	,fact1.LocalReportingOfficeID AS ID1
--	,fact2.LocalReportingOfficeID AS ID2
--FROM ReferralFact AS fact1
--CROSS JOIN ReferralFact AS fact2

--WHERE fact1.SourceSystemClientID = fact2.SourceSystemClientID
--AND fact1.LocalReportingOfficeID != fact2.LocalReportingOfficeID
--AND fact1.ReferralDateID <= fact2.DischargeDateID
--AND fact2.ReferralDateID <= fact1.DischargeDateID
--GROUP BY fact1.LocalReportingOfficeID
--	,fact2.LocalReportingOfficeID

--)
--SELECT xjoin.DistinctClientCount, dim1.ParisTeamName, dim2.ParisTeamName AS piv_col
--INTO #gcTemp
--FROM xjoin
--INNER JOIN Dim.LocalReportingOffice AS dim1
--ON xjoin.ID1 = dim1.LocalReportingOfficeID
--INNER JOIN Dim.LocalReportingOffice AS dim2
--ON xjoin.ID2 = dim2.LocalReportingOfficeID
--ORDER BY xjoin.DistinctClientCount DESC
--	,dim1.LocalReportingOfficeID
--	,dim2.LocalReportingOfficeID

DECLARE @cols nvarchar(max) = N''
SELECT @cols=STUFF((
SELECT N',['+ ParisTeamName +N']'
FROM Dim.LocalReportingOffice AS col
ORDER BY col.ParisTeamName
FOR XML PATH(N''), TYPE).value('.', 'nvarchar(max)'),1,1,'')
SELECT @cols
PRINT @cols



SELECT ParisTeamName, [1 AOA GENERIC],[3 AOA GENERIC],[4 AOA GENERIC],[520 - HEALTH PLANNERS],[520 - MENTAL HEALTH],[520 TEAM],[6 AOA GENERIC],[AOA-1 & 2 INTAKE],[AOA-1 AMBULATORY],[AOA-1 AMBULATORY SUNSET CLINIC],[AOA-1 DOWNTOWN SOUTH],[AOA-1 FAIRVIEW SLOPES],[AOA-1 NORTH WEST END],[AOA-1 SOUTH WEST END],[AOA-2 AMBULATORY],[AOA-2 AMBULATORY CLINIC-KETTLE],[AOA-2 AMBULATORY CLINIC-PENDER],[AOA-2 DOWNTOWN EASTSIDE],[AOA-2 GRANDVIEW],[AOA-2 STRATHCONA],[AOA-2 WOODLANDS],[AOA-3 AMBULATORY],[AOA-3 CEDAR COTTAGE],[AOA-3 HASTINGS-SUNRISE],[AOA-3 INTAKE],[AOA-3 RENFREW-COLLINGWOOD],[AOA-4 AMBULATORY],[AOA-4 DUNBAR-POINT GREY],[AOA-4 INTAKE],[AOA-4 KERRISDALE-ARBUTUS],[AOA-4 KITSILANO-SHAUGHNESSY],[AOA-5 AMBULATORY],[AOA-5 EAST TEAM],[AOA-5 INTAKE],[AOA-5 WEST TEAM],[AOA-6 AMBULATORY],[AOA-6 FRASERVIEW],[AOA-6 INTAKE],[AOA-6 KILLARNEY],[AOA-6 MARPOLE-OAKRIDGE],[AOA-6 SUNSET],[AOA-VAN ASSISTED LIVING WL],[AOA-VAN CAREGIVER SUPPORT],[AOA-VAN CDSM SUPPORT CLINIC],[AOA-VAN CENTRAL INTAKE],[AOA-VAN CHRONIC DISEASE MGMT],[AOA-VAN COMMUNITY DIABETIC ],[AOA-VAN COMPLEX CONSULTATION],[AOA-VAN CONTINENCE CLINIC],[AOA-VAN CSIL FINANCE],[AOA-VAN DR PETER CENTRE],[AOA-VAN ESD STROKE],[AOA-VAN EVENING/AFTER HOURS],[AOA-VAN FACILITY LIAISON],[AOA-VAN GERI TRANSITIONS],[AOA-VAN HEART TEAM],[AOA-VAN HSCL],[AOA-VAN INDIVIDUAL CONTRACTS],[AOA-VAN MASTECTOMY PT],[AOA-VAN PALLIATIVE ACCESS LINE],[AOA-VAN PALLIATIVE CONSULT],[AOA-VAN PHC COPD OUTREACH],[AOA-VAN PRIORITY ACCESS],[AOA-VAN PULMONARY REHAB TEAM],[AOA-VAN QUICK RESPONSE TEAM],[AOA-VAN REHAB WEEKEND],[AOA-VAN RESIDENTIAL CARE],[AOA-VAN SOUTH ASIAN DIABETIC],[AOA-VAN SOUTH ASIAN PAP CLINIC],[AOA-VAN SPEECH LANGUAGE],[AOA-VAN SPINAL CORD ULCER],[AOA-VAN SUPPORTED HOUSING WL],[AOA-VAN SUPRT HOUS. CONSULTANT],[AOA-VAN VGH COPD TRANSITION],[AS-1 THREE BRIDGES],[AS-2 GRANDVIEW WOODLAND],[AS-3 EVERGREEN],[AS-4 PACIFIC SPIRIT],[AS-VAN ACCESS CENTRAL],[AS-VAN ADDICTION HOUSING],[AS-VAN ADDICTION MATRIX PRG],[AS-VAN CAMBIE OLDER ADULT],[AS-VAN CHEM DEP RESOURCE TEAM],[AS-VAN DAYTOX],[AS-VAN DCHC],[AS-VAN DRUG COURT TX/RESOURCE],[AS-VAN INNER CITY OLDER ADULT],[AS-VAN PACIFIC SPIRIT],[AS-VAN PENDER],[AS-VAN RAINIER PROGRAM],[AS-VAN RAVENSONG],[AS-VAN RES TX SUPPORT RECOVERY],[AS-VAN SOUTH],[AS-VAN URT2],[AS-VAN VANCOUVER DETOX],[AS-VAN WITHDRAWAL MANAGEMENT],[AS-VAN WITHDRAWAL MGMT-HBL],[BURNABY CENTRE MH & ADDICTION],[CC-RMD AMBULATORY CARE CLINIC],[CC-RMD ASSISTED LIVING WL],[CC-RMD CENTRAL],[CC-RMD CHRONIC DISEASE MGMT],[CC-RMD COMM RESPIRATORY TEAM],[CC-RMD COMMUNITY TRANSITIONS],[CC-RMD CSIL FINANCE],[CC-RMD EARLY SUPPORTED DISCH],[CC-RMD EAST],[CC-RMD FACILITY LIAISON],[CC-RMD GERIATRIC ASSMT PROGRAM],[CC-RMD GERIATRIC TRANS. NURSE],[CC-RMD HSCL],[CC-RMD INTAKE],[CC-RMD INTEGRATED TRANSITION],[CC-RMD LIAISON],[CC-RMD NORTH],[CC-RMD PALLIATIVE CONSULT],[CC-RMD PRIORITY ACCESS],[CC-RMD RESIDENTIAL CARE],[CC-RMD SOUTH],[CC-RMD WEST],[CC-TEAM 1 RICHMOND],[CC-TEAM 2 RICHMOND],[CC-TEAM 3 RICHMOND],[CC-TEAM 4 RICHMOND],[CC-TEAM 5 RICHMOND],[CC-TEAM 6 RICHMOND],[CFH-0-2],[CFH-2-5],[CFH-AUDIOLOGY],[CFH-CHILD HEALTH CLINIC],[CFH-CHILDREN & YOUTH],[CFH-DENTAL],[CFH-HEALTH PROMOTION],[CFH-LIAISON],[CFH-MENTAL HEALTH PROMOTION],[CFH-NOAKES MATERNITY CLINIC],[CFH-NUTRITION],[CFH-SCHOOL SUPPORT],[CFH-SOCIAL WORK],[CFH-SPEECH LANGUAGE SERVICES],[CFH-VISION],[CFH-YOUTH CLINIC],[COMMUNICABLE DISEASE],[COMMUNICABLE DISEASE-B COOLA],[COMMUNICABLE DISEASE-NS],[COMMUNICABLE DISEASE-PR],[COMMUNICABLE DISEASE-SC],[COMMUNICABLE DISEASE-STS],[COMMUNITY HEALTH],[CONSULTANT VANCOUVER],[HC - HOME OXYGEN PROGRAM],[HC-BB BELLA BELLA],[HC-COASTAL CSIL FINANCE],[HC-NS AMBULATORY CENTRAL],[HC-NS AMBULATORY WEST],[HC-NS ASSISTED LIVING],[HC-NS COMPLEX REHAB],[HC-NS CSIL FINANCE],[HC-NS DISCHARGE COORDINATION],[HC-NS GERIATRIC SERVICES],[HC-NS HOSPICE],[HC-NS HSCL],[HC-NS INTAKE],[HC-NS NORTHEAST],[HC-NS PRIORITY ACCESS],[HC-NS RESPIRATORY EDUCATION],[HC-NS SOUTH],[HC-NS WEST],[HC-PR AMBULATORY CLINIC],[HC-PR HSCL],[HC-PR POWELL RIVER],[HC-PR PRI ACCESS/ASSIST LIVING],[HC-SC GIBSONS],[HC-SC HSCL],[HC-SC PENDER HARBOUR],[HC-SC PRI ACCESS/ASSIST LIVING],[HC-SC SECHELT],[HC-STS HSCL],[HC-STS INTAKE],[HC-STS PEMBERTON WHISTLER],[HC-STS PRI ACCESS/ASSIST LIVIN],[HC-STS SQUAMISH],[HC-VCH COMM REHAB & RESOURCE],[HHC-BC BELLA COOLA],[HOSPICE-RMD],[HOSPITAL - RMD SW TST],[HOSPITAL - VH PCU],[HOSPITAL - VH STAT],[HOSPITAL-VA CML],[HSG-CLINICAL TENANT SUPPORT],[HSG-HSG FIRST PLACEMENT TEAM],[ICY-1 0-5 & SCHOOL],[ICY-2 0-5 & SCHOOL],[ICY-3 0-5 & SCHOOL],[ICY-4 0-5 & SCHOOL],[ICY-5 0-5 & SCHOOL],[ICY-6 0-5 & SCHOOL],[ICY-AUDIOLOGY],[ICY-BUILDING BLOCKS],[ICY-DENTAL],[ICY-HEALTHIEST BABIES POSSIBLE],[ICY-HEALTHY ATTITUDES],[ICY-INFANT/CHILD MH],[ICY-LIAISON],[ICY-NEWBORN HOTLINE],[ICY-REGIONAL PEDIATRIC],[ICY-SAFE BABIES],[ICY-SPEECH LANGUAGE SERVICES],[ICY-VAN YOUTH CLINIC],[ICY-VISION],[ICY-YOUTH PREGNANCY PARENTING],[ICY-YOUTH PREGNANCY&PARENTING],[MH-ACCESS COM THROUGH ENGLISH],[MH-ACT/BRIDGING],[MH-ADHD PARENTING PRG],[MH-ADOLESCENT OUTREACH SERVICE],[MH-ALAN CASHMORE CTR],[MH-ALDERWOOD],[MH-ART STUDIO],[MH-BOUNDARIES],[MH-CART],[MH-CART OUTREACH],[MH-CEN FOR CONCURRENT DIS],[MH-CHILD & YOUTH INTAKE UNIT],[MH-COMMUNITY LINK PRG],[MH-COMMUNITY TRANSITION TEAM],[MH-CONNECT PARENT GROUP],[MH-COPP],[MH-CROSS CULTURAL PROGRAM],[MH-DEAF/WELL-BEING PRG],[MH-EARLY PSYCHOSIS INTERVENT],[MH-FOUNDATIONS],[MH-GVS],[MH-HAMBER HOUSE],[MH-HEALTH RECORDS],[MH-MCF CONTRACT (PAST)],[MH-MCF LIAISON],[MH-MH HOUSING SERVICES],[MH-MHES VANCOUVER],[MH-OLDER ADULT CENTRAL INTAKE],[MH-OLDER ADULT REHAB PRG],[MH-RHAP-CONTRACT],[MH-RMD ACUTE HOME BASED TX],[MH-RMD ADULT CONSULT CLINIC],[MH-RMD ADULT PROGRAM],[MH-RMD BRIDGE HOUSE],[MH-RMD C&Y CONSULT CLINIC],[MH-RMD CENTRAL INTAKE],[MH-RMD CHILD & ADOLESCENT PRG],[MH-RMD EARLY CHILDHOOD PRG],[MH-RMD EATING DISORDERS],[MH-RMD MHES],[MH-RMD OLDER ADULT PRG],[MH-RMD OUT-PATIENT DEPARTMENT],[MH-RMD REHAB & HOUSING],[MH-RMD SCHOOL PROGRAM],[MH-RMD TRANSITIONS],[MH-SAFER],[MH-T GRANDVIEW WOODLANDS],[MH-T KITSILANO],[MH-T NORTHEAST],[MH-T STRATHCONA],[MH-T WEST END],[MH-TROUT LAKE TRU],[MH-VAN ACUTE HOME BASED TX],[MH-VAN CAMBIE OLDER ADULT],[MH-VAN EATING DISORDERS],[MH-VAN FACES-FAMILY&COM ENHANC],[MH-VAN GPOT-GERI PSYCH OUTRCH],[MH-VAN INNER CITY OLDER ADULT],[MH-VAN MH ADULT INTAKE],[MH-VAN PACIFIC SPIRIT],[MH-VAN RAVENSONG],[MH-VAN SOUTH],[MH-VAN VGH OP PSYCHIATRY],[MH-VENTURE],[MH-VGH EMERG],[MH-VGH/UBCH PSYCHIATRY],[MH-VISTA],[MH-VISU],[MH-VSMH],[MH-YOUTH CONCURRENT DISORDERS],[MH-YOUTH HUB SITE],[MH-YOUTH-SIL],[MH-YRCS],[MHA-ADULT ADHD CLINIC
],[MHA-BC BELLA COOLA],[MHA-CHEZ SOI TRANSITION TEAM],[MHA-NS ACUTE HOME BASED TX],[MHA-NS ACUTE INPATIENT],[MHA-NS ADULT COMM SUPPORT SERV],[MHA-NS ASSESSMENT & TX SERVICE],[MHA-NS CENTRAL INTAKE],[MHA-NS CHILD & YOUTH],[MHA-NS COMM TRANSITION DAY PRG],[MHA-NS CONCURRENT DISORDERS],[MHA-NS FAMILY SUPPORT PROGRAM],[MHA-NS INTENSIVE YTH OUTREACH],[MHA-NS MAGNOLIA HOUSE],[MHA-NS OLDER ADULT],[MHA-NS PSYCH EMERG],[MHA-NS RAPS CLINIC],[MHA-NS REHAB SERVICES],[MHA-NS RESIDENTIAL SERVICES],[MHA-PHC INNER CITY YOUTH],[MHA-PHC SW],[MHA-PR ACUTE],[MHA-PR ADULT COMMUNITY MH&A],[MHA-PR OLDER ADULT],[MHA-PR RESIDENTIAL SERVICES],[MHA-PR YOUTH ADDICTIONS],[MHA-SC ACUTE],[MHA-SC ADULT COMMUNITY MH&A],[MHA-SC CRISIS RESPONSE],[MHA-SC OLDER ADULT],[MHA-SC RESIDENTIAL SERVICES],[MHA-SC YOUTH ADDICTIONS],[MHA-STS PEMB ADULT COMM SUPPRT],[MHA-STS PEMB ASTAT/ADDICTIONS],[MHA-STS PEMB CENTRAL INTAKE],[MHA-STS PEMB OLDER ADULT],[MHA-STS SQ ADULT COMM SUPPORT],[MHA-STS SQ ASTAT/ADDICTIONS],[MHA-STS SQ CENTRAL INTAKE],[MHA-STS SQ OLDER ADULT],[MHA-STS WHIS ADULT COMM SUPPRT],[MHA-STS WHIS ASTAT/ADDICTIONS],[MHA-STS WHIS CENTRAL INTAKE],[MHA-STS WHIS OLDER ADULT],[MHA-STS WHIS PSYCHIATRY],[MHA-STS YOUTH ADDICTIONS],[MHA-VAN ACCESS & ASSESS CENTER],[MHA-VAN ACT 4],[MHA-VAN ACT 5],[MHA-VAN ASSERTIVE COMMUNITY TX],[MHA-VAN ASSERTIVE OUTREACH],[MHA-VAN HEART TEAM],[MHA-VAN HOARDING TEAM],[MHA-VAN IPCC ASSERTIVE COMM TX],[MHA-VAN RAINCITY ACT],[MHA-Van Sacy Resiliency LRP],[MHA-VAN SACY YOUTH PREVENTION],[MX-X AHES HX],[MX-X ASSERTIVE COMMUNITY TEAM],[MX-X BLUNDELL HX],[MX-X BROADWAY CRU HX],[MX-X BROADWAY NORTH HX],[MX-X BROADWAY SOUTH HX],[MX-X DDP F&C HX],[MX-X DDP GERIATRICS HX],[MX-X DUAL DIAGNOSIS HX],[MX-X ICDTP HX],[MX-X IMPS HX],[MX-X JERICHO COUNSELING PRG HX],[MX-X JERICHO INTERVENTION PRG],[MX-X JERICHO MENTAL HEALTH PRG],[MX-X KILLARNEY PROJECT HX],[MX-X MHES-G HX],[MX-X MSN (MULTI SERVICE NETWOR],[MX-X NORTH SHORE RHAP],[MX-X OTHER PROV MH CENTRE HX],[MX-X RHAP/WELL BEING HX],[MX-X RICHMOND CRU HX],[MX-X RICHMOND HX],[MX-X RSCFP HX],[MX-X TEAM NOT KNOWN HX],[MX-X VISTA-BED SUPP HX],[MX-X VISTA-MEAL SUPP HX],[MX-X WESTERN INSTITUTE DEAF],[PARIS ADMIN],[PARIS TRAINERS],[PC-ACCESS 1],[PC-ACCESS TWO],[PC-CONTACT CENTRE],[PC-DAYTOX],[PC-NORTH],[PC-NS CHRONIC DISEASE MGMT],[PC-NS HEALTH CONNECTION],[PC-RAVEN SONG COMM SCREENING],[PC-RAVEN SONG PRENATAL CLINIC],[PC-RMD ANNE VOGEL],[PC-RMD GILWEST],[PC-SHEWAY],[PC-VAN 3 BRIDGES],[PC-VAN BRIDGE],[PC-VAN CROSSTOWN],[PC-VAN DCHC],[PC-VAN EVERGREEN],[PC-VAN PACIFIC SPIRIT],[PC-VAN PENDER],[PC-VAN PINE],[PC-VAN RAVENSONG],[PC-Van Res Care NP],[PC-VAN SOUTH],[PC-VAN SOUTH ASIAN PAP CLINIC],[PC-VAN-SHEWAY],[PC-VANCOUVER DETOX],[PH-BC AUDIOLOGY],[PH-BC BELLA COOLA],[PH-BC SAFE BELLA COOLA],[PH-BC VISION],[PH-BC YOUTH CLINIC],[PH-COASTAL HEPATOLOGY SERVICES],[PH-NS AUDIOLOGY],[PH-NS DENTAL],[PH-NS EATING DISORDERS],[PH-NS LIAISON],[PH-NS NORTH SHORE],[PH-NS PEDIATRIC RESOURCE TEAM],[PH-NS POSTPARTUM SUPPORTIVE TX],[PH-NS SPEECH LANGUAGE],[PH-NS VISION],[PH-NS YOUTH CLINIC],[PH-NURSE FAMILY PARTNERSHIP],[PH-PR AUDIOLOGY],[PH-PR DENTAL],[PH-PR LIAISON],[PH-PR NURSING SUPPORT SERVICES],[PH-PR POWELL RIVER],[PH-PR SAFE POWELL RIVER],[PH-PR SPEECH LANGUAGE SERVICES],[PH-PR VISION],[PH-PR YOUTH CLINIC],[PH-SC AUDIOLOGY],[PH-SC DENTAL],[PH-SC GIBSONS],[PH-SC LIAISON],[PH-SC NURSING SUPPORT SERVICES],[PH-SC SAFE SUNSHINE COAST],[PH-SC SECHELT],[PH-SC SPEECH LANGUAGE SERVICES],[PH-SC VISION],[PH-SC YOUTH CLINIC],[PH-STS AUDIOLOGY],[PH-STS DENTAL],[PH-STS LIAISON],[PH-STS NURSING SUPPORT SERVICE],[PH-STS PEMBERTON],[PH-STS SAFE SQUAMISH],[PH-STS SAFE WHISTLER-PEMBERTON],[PH-STS SPEECH LANGUAGE SERVICE],[PH-STS SQUAMISH],[PH-STS VISION],[PH-STS WHISTLER],[POS-VAN ALEXANDER ST COMM-TP],[POS-VAN DTES HOTEL TEAM ],[POS-VAN DTES SHELTER TEAM ],[RC-BB BELLA BELLA],[RC-BC BELLA COOLA],[RC-CLINICAL/ADMIN SUPPORT],[RC-NS CEDARVIEW LODGE],[RC-NS EVERGREEN 3 SOUTH],[RC-NS EVERGREEN HOUSE],[RC-NS KCC],[RC-RMD MINORU],[RC-SC EVERGREEN],[RC-SC OLIVE DEVAUD],[RC-SC SHORNCLIFFE],[RC-SC TOTEM LODGE],[RC-SC WILLINGDON CREEK VILLAGE],[RC-STS HILL TOP],[RC-VAN BANFIELD],[RC-VAN DOGWOOD],[RC-VAN GEORGE PEARSON],[RC-VAN PURDY],[RISE CONVERSION],[SECURITY AND ADMIN - MH],[SECURITY AND ADMIN - PC],[STANLEY HOTEL PROJECT],[STS SOCIAL WORK],[TCU - NS EVERGREEN],[TCU - RMD MINORU],[TCU - VAN BRADDAN],[TCU - VAN KOERNER 1],[TCU � SC TOTEM LODGE],[TMH-ADULT ASSESSMENT AND TX],[TMH-ADULT INTENSIVE REHAB],[TMH-ADULT REHAB],[TMH-CENTRAL ACCESS/DISCHARGE],[TMH-NEUROPSYC LT STABILIZATION],[TMH-OA ASSESSMENT AND TX],[TMH-SUMAC PLACE],[TRANSITION SERVICES TEAM],[Unknown],[URGENT RESPONSE TEAM],[VACCINE EVAULATION CENTRE],[VAN ABORIGINAL WELLNESS PRG],[VAN CTCT],[VAN HEALTH CONTACT CENTRE],[VAN ONSITE],[VAN-HOME VIVE PLUS],[VAN-HOME VIVE PROGRAM],[VAN-Immunodeficiency Clinic],[VAN-PENNSYLVANIA SUPP SUITES],[VAN-SHOP BY PHONE],[VAN-STOP TEAM],[VAN-VOLUNTEER SERVICES],[VANCOUVER FINANCE],[XICY-BUILDING BLOCKS],[XICY-REGIONAL PEDIATRICS-SW],[XMH-RMD LIONS MANOR],[XTST-MENTAL HEALTH],[YOUTH CLINIC 1 - EBYHC],[YOUTH CLINIC 2 - EAST VAN],[YOUTH CLINIC 2 - NORTH],[YOUTH CLINIC 3 - EVERGREEN],[YOUTH CLINIC 4 - BOULEVARD],[YOUTH CLINIC 5 - BYRC],[YOUTH CLINIC 5 - MID-MAIN],[YOUTH CLINIC 6 - KNIGHT ST],[YPPP-VAN EVERGREEN],[Z-CLIENT RELATIONS & RISK MGMT],[Z-HOSPICE-MAY, COTTAGE, MARION],[Z-HSG/MH HOUSING],[Z-MH MHES ADDICTION SERVICES],[Z-MH-AOA MH CLINICIANS],[Z-MH-SEXUAL MEDICINE],[Z-MH-T WEST SIDE],[Z-NS SW READ ONLY],[Z-PHC MH ELDER CARE],[Z-PHC-SW READ ONLY],[Z-READONLY CHRONIC DISEASE MGT],[Z-READONLY-VAN ACUT PSYCHIATRY],[Z-VA-READONLY ALLIED HEALTH],[Z-VAN-SW READ ONLY]
FROM
(SELECT *
FROM #gctemp) AS src
PIVOT
(
	AVG(src.DistinctClientCount)
FOR piv_col IN ([1 AOA GENERIC],[3 AOA GENERIC],[4 AOA GENERIC],[520 - HEALTH PLANNERS],[520 - MENTAL HEALTH],[520 TEAM],[6 AOA GENERIC],[AOA-1 & 2 INTAKE],[AOA-1 AMBULATORY],[AOA-1 AMBULATORY SUNSET CLINIC],[AOA-1 DOWNTOWN SOUTH],[AOA-1 FAIRVIEW SLOPES],[AOA-1 NORTH WEST END],[AOA-1 SOUTH WEST END],[AOA-2 AMBULATORY],[AOA-2 AMBULATORY CLINIC-KETTLE],[AOA-2 AMBULATORY CLINIC-PENDER],[AOA-2 DOWNTOWN EASTSIDE],[AOA-2 GRANDVIEW],[AOA-2 STRATHCONA],[AOA-2 WOODLANDS],[AOA-3 AMBULATORY],[AOA-3 CEDAR COTTAGE],[AOA-3 HASTINGS-SUNRISE],[AOA-3 INTAKE],[AOA-3 RENFREW-COLLINGWOOD],[AOA-4 AMBULATORY],[AOA-4 DUNBAR-POINT GREY],[AOA-4 INTAKE],[AOA-4 KERRISDALE-ARBUTUS],[AOA-4 KITSILANO-SHAUGHNESSY],[AOA-5 AMBULATORY],[AOA-5 EAST TEAM],[AOA-5 INTAKE],[AOA-5 WEST TEAM],[AOA-6 AMBULATORY],[AOA-6 FRASERVIEW],[AOA-6 INTAKE],[AOA-6 KILLARNEY],[AOA-6 MARPOLE-OAKRIDGE],[AOA-6 SUNSET],[AOA-VAN ASSISTED LIVING WL],[AOA-VAN CAREGIVER SUPPORT],[AOA-VAN CDSM SUPPORT CLINIC],[AOA-VAN CENTRAL INTAKE],[AOA-VAN CHRONIC DISEASE MGMT],[AOA-VAN COMMUNITY DIABETIC ],[AOA-VAN COMPLEX CONSULTATION],[AOA-VAN CONTINENCE CLINIC],[AOA-VAN CSIL FINANCE],[AOA-VAN DR PETER CENTRE],[AOA-VAN ESD STROKE],[AOA-VAN EVENING/AFTER HOURS],[AOA-VAN FACILITY LIAISON],[AOA-VAN GERI TRANSITIONS],[AOA-VAN HEART TEAM],[AOA-VAN HSCL],[AOA-VAN INDIVIDUAL CONTRACTS],[AOA-VAN MASTECTOMY PT],[AOA-VAN PALLIATIVE ACCESS LINE],[AOA-VAN PALLIATIVE CONSULT],[AOA-VAN PHC COPD OUTREACH],[AOA-VAN PRIORITY ACCESS],[AOA-VAN PULMONARY REHAB TEAM],[AOA-VAN QUICK RESPONSE TEAM],[AOA-VAN REHAB WEEKEND],[AOA-VAN RESIDENTIAL CARE],[AOA-VAN SOUTH ASIAN DIABETIC],[AOA-VAN SOUTH ASIAN PAP CLINIC],[AOA-VAN SPEECH LANGUAGE],[AOA-VAN SPINAL CORD ULCER],[AOA-VAN SUPPORTED HOUSING WL],[AOA-VAN SUPRT HOUS. CONSULTANT],[AOA-VAN VGH COPD TRANSITION],[AS-1 THREE BRIDGES],[AS-2 GRANDVIEW WOODLAND],[AS-3 EVERGREEN],[AS-4 PACIFIC SPIRIT],[AS-VAN ACCESS CENTRAL],[AS-VAN ADDICTION HOUSING],[AS-VAN ADDICTION MATRIX PRG],[AS-VAN CAMBIE OLDER ADULT],[AS-VAN CHEM DEP RESOURCE TEAM],[AS-VAN DAYTOX],[AS-VAN DCHC],[AS-VAN DRUG COURT TX/RESOURCE],[AS-VAN INNER CITY OLDER ADULT],[AS-VAN PACIFIC SPIRIT],[AS-VAN PENDER],[AS-VAN RAINIER PROGRAM],[AS-VAN RAVENSONG],[AS-VAN RES TX SUPPORT RECOVERY],[AS-VAN SOUTH],[AS-VAN URT2],[AS-VAN VANCOUVER DETOX],[AS-VAN WITHDRAWAL MANAGEMENT],[AS-VAN WITHDRAWAL MGMT-HBL],[BURNABY CENTRE MH & ADDICTION],[CC-RMD AMBULATORY CARE CLINIC],[CC-RMD ASSISTED LIVING WL],[CC-RMD CENTRAL],[CC-RMD CHRONIC DISEASE MGMT],[CC-RMD COMM RESPIRATORY TEAM],[CC-RMD COMMUNITY TRANSITIONS],[CC-RMD CSIL FINANCE],[CC-RMD EARLY SUPPORTED DISCH],[CC-RMD EAST],[CC-RMD FACILITY LIAISON],[CC-RMD GERIATRIC ASSMT PROGRAM],[CC-RMD GERIATRIC TRANS. NURSE],[CC-RMD HSCL],[CC-RMD INTAKE],[CC-RMD INTEGRATED TRANSITION],[CC-RMD LIAISON],[CC-RMD NORTH],[CC-RMD PALLIATIVE CONSULT],[CC-RMD PRIORITY ACCESS],[CC-RMD RESIDENTIAL CARE],[CC-RMD SOUTH],[CC-RMD WEST],[CC-TEAM 1 RICHMOND],[CC-TEAM 2 RICHMOND],[CC-TEAM 3 RICHMOND],[CC-TEAM 4 RICHMOND],[CC-TEAM 5 RICHMOND],[CC-TEAM 6 RICHMOND],[CFH-0-2],[CFH-2-5],[CFH-AUDIOLOGY],[CFH-CHILD HEALTH CLINIC],[CFH-CHILDREN & YOUTH],[CFH-DENTAL],[CFH-HEALTH PROMOTION],[CFH-LIAISON],[CFH-MENTAL HEALTH PROMOTION],[CFH-NOAKES MATERNITY CLINIC],[CFH-NUTRITION],[CFH-SCHOOL SUPPORT],[CFH-SOCIAL WORK],[CFH-SPEECH LANGUAGE SERVICES],[CFH-VISION],[CFH-YOUTH CLINIC],[COMMUNICABLE DISEASE],[COMMUNICABLE DISEASE-B COOLA],[COMMUNICABLE DISEASE-NS],[COMMUNICABLE DISEASE-PR],[COMMUNICABLE DISEASE-SC],[COMMUNICABLE DISEASE-STS],[COMMUNITY HEALTH],[CONSULTANT VANCOUVER],[HC - HOME OXYGEN PROGRAM],[HC-BB BELLA BELLA],[HC-COASTAL CSIL FINANCE],[HC-NS AMBULATORY CENTRAL],[HC-NS AMBULATORY WEST],[HC-NS ASSISTED LIVING],[HC-NS COMPLEX REHAB],[HC-NS CSIL FINANCE],[HC-NS DISCHARGE COORDINATION],[HC-NS GERIATRIC SERVICES],[HC-NS HOSPICE],[HC-NS HSCL],[HC-NS INTAKE],[HC-NS NORTHEAST],[HC-NS PRIORITY ACCESS],[HC-NS RESPIRATORY EDUCATION],[HC-NS SOUTH],[HC-NS WEST],[HC-PR AMBULATORY CLINIC],[HC-PR HSCL],[HC-PR POWELL RIVER],[HC-PR PRI ACCESS/ASSIST LIVING],[HC-SC GIBSONS],[HC-SC HSCL],[HC-SC PENDER HARBOUR],[HC-SC PRI ACCESS/ASSIST LIVING],[HC-SC SECHELT],[HC-STS HSCL],[HC-STS INTAKE],[HC-STS PEMBERTON WHISTLER],[HC-STS PRI ACCESS/ASSIST LIVIN],[HC-STS SQUAMISH],[HC-VCH COMM REHAB & RESOURCE],[HHC-BC BELLA COOLA],[HOSPICE-RMD],[HOSPITAL - RMD SW TST],[HOSPITAL - VH PCU],[HOSPITAL - VH STAT],[HOSPITAL-VA CML],[HSG-CLINICAL TENANT SUPPORT],[HSG-HSG FIRST PLACEMENT TEAM],[ICY-1 0-5 & SCHOOL],[ICY-2 0-5 & SCHOOL],[ICY-3 0-5 & SCHOOL],[ICY-4 0-5 & SCHOOL],[ICY-5 0-5 & SCHOOL],[ICY-6 0-5 & SCHOOL],[ICY-AUDIOLOGY],[ICY-BUILDING BLOCKS],[ICY-DENTAL],[ICY-HEALTHIEST BABIES POSSIBLE],[ICY-HEALTHY ATTITUDES],[ICY-INFANT/CHILD MH],[ICY-LIAISON],[ICY-NEWBORN HOTLINE],[ICY-REGIONAL PEDIATRIC],[ICY-SAFE BABIES],[ICY-SPEECH LANGUAGE SERVICES],[ICY-VAN YOUTH CLINIC],[ICY-VISION],[ICY-YOUTH PREGNANCY PARENTING],[ICY-YOUTH PREGNANCY&PARENTING],[MH-ACCESS COM THROUGH ENGLISH],[MH-ACT/BRIDGING],[MH-ADHD PARENTING PRG],[MH-ADOLESCENT OUTREACH SERVICE],[MH-ALAN CASHMORE CTR],[MH-ALDERWOOD],[MH-ART STUDIO],[MH-BOUNDARIES],[MH-CART],[MH-CART OUTREACH],[MH-CEN FOR CONCURRENT DIS],[MH-CHILD & YOUTH INTAKE UNIT],[MH-COMMUNITY LINK PRG],[MH-COMMUNITY TRANSITION TEAM],[MH-CONNECT PARENT GROUP],[MH-COPP],[MH-CROSS CULTURAL PROGRAM],[MH-DEAF/WELL-BEING PRG],[MH-EARLY PSYCHOSIS INTERVENT],[MH-FOUNDATIONS],[MH-GVS],[MH-HAMBER HOUSE],[MH-HEALTH RECORDS],[MH-MCF CONTRACT (PAST)],[MH-MCF LIAISON],[MH-MH HOUSING SERVICES],[MH-MHES VANCOUVER],[MH-OLDER ADULT CENTRAL INTAKE],[MH-OLDER ADULT REHAB PRG],[MH-RHAP-CONTRACT],[MH-RMD ACUTE HOME BASED TX],[MH-RMD ADULT CONSULT CLINIC],[MH-RMD ADULT PROGRAM],[MH-RMD BRIDGE HOUSE],[MH-RMD C&Y CONSULT CLINIC],[MH-RMD CENTRAL INTAKE],[MH-RMD CHILD & ADOLESCENT PRG],[MH-RMD EARLY CHILDHOOD PRG],[MH-RMD EATING DISORDERS],[MH-RMD MHES],[MH-RMD OLDER ADULT PRG],[MH-RMD OUT-PATIENT DEPARTMENT],[MH-RMD REHAB & HOUSING],[MH-RMD SCHOOL PROGRAM],[MH-RMD TRANSITIONS],[MH-SAFER],[MH-T GRANDVIEW WOODLANDS],[MH-T KITSILANO],[MH-T NORTHEAST],[MH-T STRATHCONA],[MH-T WEST END],[MH-TROUT LAKE TRU],[MH-VAN ACUTE HOME BASED TX],[MH-VAN CAMBIE OLDER ADULT],[MH-VAN EATING DISORDERS],[MH-VAN FACES-FAMILY&COM ENHANC],[MH-VAN GPOT-GERI PSYCH OUTRCH],[MH-VAN INNER CITY OLDER ADULT],[MH-VAN MH ADULT INTAKE],[MH-VAN PACIFIC SPIRIT],[MH-VAN RAVENSONG],[MH-VAN SOUTH],[MH-VAN VGH OP PSYCHIATRY],[MH-VENTURE],[MH-VGH EMERG],[MH-VGH/UBCH PSYCHIATRY],[MH-VISTA],[MH-VISU],[MH-VSMH],[MH-YOUTH CONCURRENT DISORDERS],[MH-YOUTH HUB SITE],[MH-YOUTH-SIL],[MH-YRCS],[MHA-ADULT ADHD CLINIC
],[MHA-BC BELLA COOLA],[MHA-CHEZ SOI TRANSITION TEAM],[MHA-NS ACUTE HOME BASED TX],[MHA-NS ACUTE INPATIENT],[MHA-NS ADULT COMM SUPPORT SERV],[MHA-NS ASSESSMENT & TX SERVICE],[MHA-NS CENTRAL INTAKE],[MHA-NS CHILD & YOUTH],[MHA-NS COMM TRANSITION DAY PRG],[MHA-NS CONCURRENT DISORDERS],[MHA-NS FAMILY SUPPORT PROGRAM],[MHA-NS INTENSIVE YTH OUTREACH],[MHA-NS MAGNOLIA HOUSE],[MHA-NS OLDER ADULT],[MHA-NS PSYCH EMERG],[MHA-NS RAPS CLINIC],[MHA-NS REHAB SERVICES],[MHA-NS RESIDENTIAL SERVICES],[MHA-PHC INNER CITY YOUTH],[MHA-PHC SW],[MHA-PR ACUTE],[MHA-PR ADULT COMMUNITY MH&A],[MHA-PR OLDER ADULT],[MHA-PR RESIDENTIAL SERVICES],[MHA-PR YOUTH ADDICTIONS],[MHA-SC ACUTE],[MHA-SC ADULT COMMUNITY MH&A],[MHA-SC CRISIS RESPONSE],[MHA-SC OLDER ADULT],[MHA-SC RESIDENTIAL SERVICES],[MHA-SC YOUTH ADDICTIONS],[MHA-STS PEMB ADULT COMM SUPPRT],[MHA-STS PEMB ASTAT/ADDICTIONS],[MHA-STS PEMB CENTRAL INTAKE],[MHA-STS PEMB OLDER ADULT],[MHA-STS SQ ADULT COMM SUPPORT],[MHA-STS SQ ASTAT/ADDICTIONS],[MHA-STS SQ CENTRAL INTAKE],[MHA-STS SQ OLDER ADULT],[MHA-STS WHIS ADULT COMM SUPPRT],[MHA-STS WHIS ASTAT/ADDICTIONS],[MHA-STS WHIS CENTRAL INTAKE],[MHA-STS WHIS OLDER ADULT],[MHA-STS WHIS PSYCHIATRY],[MHA-STS YOUTH ADDICTIONS],[MHA-VAN ACCESS & ASSESS CENTER],[MHA-VAN ACT 4],[MHA-VAN ACT 5],[MHA-VAN ASSERTIVE COMMUNITY TX],[MHA-VAN ASSERTIVE OUTREACH],[MHA-VAN HEART TEAM],[MHA-VAN HOARDING TEAM],[MHA-VAN IPCC ASSERTIVE COMM TX],[MHA-VAN RAINCITY ACT],[MHA-Van Sacy Resiliency LRP],[MHA-VAN SACY YOUTH PREVENTION],[MX-X AHES HX],[MX-X ASSERTIVE COMMUNITY TEAM],[MX-X BLUNDELL HX],[MX-X BROADWAY CRU HX],[MX-X BROADWAY NORTH HX],[MX-X BROADWAY SOUTH HX],[MX-X DDP F&C HX],[MX-X DDP GERIATRICS HX],[MX-X DUAL DIAGNOSIS HX],[MX-X ICDTP HX],[MX-X IMPS HX],[MX-X JERICHO COUNSELING PRG HX],[MX-X JERICHO INTERVENTION PRG],[MX-X JERICHO MENTAL HEALTH PRG],[MX-X KILLARNEY PROJECT HX],[MX-X MHES-G HX],[MX-X MSN (MULTI SERVICE NETWOR],[MX-X NORTH SHORE RHAP],[MX-X OTHER PROV MH CENTRE HX],[MX-X RHAP/WELL BEING HX],[MX-X RICHMOND CRU HX],[MX-X RICHMOND HX],[MX-X RSCFP HX],[MX-X TEAM NOT KNOWN HX],[MX-X VISTA-BED SUPP HX],[MX-X VISTA-MEAL SUPP HX],[MX-X WESTERN INSTITUTE DEAF],[PARIS ADMIN],[PARIS TRAINERS],[PC-ACCESS 1],[PC-ACCESS TWO],[PC-CONTACT CENTRE],[PC-DAYTOX],[PC-NORTH],[PC-NS CHRONIC DISEASE MGMT],[PC-NS HEALTH CONNECTION],[PC-RAVEN SONG COMM SCREENING],[PC-RAVEN SONG PRENATAL CLINIC],[PC-RMD ANNE VOGEL],[PC-RMD GILWEST],[PC-SHEWAY],[PC-VAN 3 BRIDGES],[PC-VAN BRIDGE],[PC-VAN CROSSTOWN],[PC-VAN DCHC],[PC-VAN EVERGREEN],[PC-VAN PACIFIC SPIRIT],[PC-VAN PENDER],[PC-VAN PINE],[PC-VAN RAVENSONG],[PC-Van Res Care NP],[PC-VAN SOUTH],[PC-VAN SOUTH ASIAN PAP CLINIC],[PC-VAN-SHEWAY],[PC-VANCOUVER DETOX],[PH-BC AUDIOLOGY],[PH-BC BELLA COOLA],[PH-BC SAFE BELLA COOLA],[PH-BC VISION],[PH-BC YOUTH CLINIC],[PH-COASTAL HEPATOLOGY SERVICES],[PH-NS AUDIOLOGY],[PH-NS DENTAL],[PH-NS EATING DISORDERS],[PH-NS LIAISON],[PH-NS NORTH SHORE],[PH-NS PEDIATRIC RESOURCE TEAM],[PH-NS POSTPARTUM SUPPORTIVE TX],[PH-NS SPEECH LANGUAGE],[PH-NS VISION],[PH-NS YOUTH CLINIC],[PH-NURSE FAMILY PARTNERSHIP],[PH-PR AUDIOLOGY],[PH-PR DENTAL],[PH-PR LIAISON],[PH-PR NURSING SUPPORT SERVICES],[PH-PR POWELL RIVER],[PH-PR SAFE POWELL RIVER],[PH-PR SPEECH LANGUAGE SERVICES],[PH-PR VISION],[PH-PR YOUTH CLINIC],[PH-SC AUDIOLOGY],[PH-SC DENTAL],[PH-SC GIBSONS],[PH-SC LIAISON],[PH-SC NURSING SUPPORT SERVICES],[PH-SC SAFE SUNSHINE COAST],[PH-SC SECHELT],[PH-SC SPEECH LANGUAGE SERVICES],[PH-SC VISION],[PH-SC YOUTH CLINIC],[PH-STS AUDIOLOGY],[PH-STS DENTAL],[PH-STS LIAISON],[PH-STS NURSING SUPPORT SERVICE],[PH-STS PEMBERTON],[PH-STS SAFE SQUAMISH],[PH-STS SAFE WHISTLER-PEMBERTON],[PH-STS SPEECH LANGUAGE SERVICE],[PH-STS SQUAMISH],[PH-STS VISION],[PH-STS WHISTLER],[POS-VAN ALEXANDER ST COMM-TP],[POS-VAN DTES HOTEL TEAM ],[POS-VAN DTES SHELTER TEAM ],[RC-BB BELLA BELLA],[RC-BC BELLA COOLA],[RC-CLINICAL/ADMIN SUPPORT],[RC-NS CEDARVIEW LODGE],[RC-NS EVERGREEN 3 SOUTH],[RC-NS EVERGREEN HOUSE],[RC-NS KCC],[RC-RMD MINORU],[RC-SC EVERGREEN],[RC-SC OLIVE DEVAUD],[RC-SC SHORNCLIFFE],[RC-SC TOTEM LODGE],[RC-SC WILLINGDON CREEK VILLAGE],[RC-STS HILL TOP],[RC-VAN BANFIELD],[RC-VAN DOGWOOD],[RC-VAN GEORGE PEARSON],[RC-VAN PURDY],[RISE CONVERSION],[SECURITY AND ADMIN - MH],[SECURITY AND ADMIN - PC],[STANLEY HOTEL PROJECT],[STS SOCIAL WORK],[TCU - NS EVERGREEN],[TCU - RMD MINORU],[TCU - VAN BRADDAN],[TCU - VAN KOERNER 1],[TCU � SC TOTEM LODGE],[TMH-ADULT ASSESSMENT AND TX],[TMH-ADULT INTENSIVE REHAB],[TMH-ADULT REHAB],[TMH-CENTRAL ACCESS/DISCHARGE],[TMH-NEUROPSYC LT STABILIZATION],[TMH-OA ASSESSMENT AND TX],[TMH-SUMAC PLACE],[TRANSITION SERVICES TEAM],[Unknown],[URGENT RESPONSE TEAM],[VACCINE EVAULATION CENTRE],[VAN ABORIGINAL WELLNESS PRG],[VAN CTCT],[VAN HEALTH CONTACT CENTRE],[VAN ONSITE],[VAN-HOME VIVE PLUS],[VAN-HOME VIVE PROGRAM],[VAN-Immunodeficiency Clinic],[VAN-PENNSYLVANIA SUPP SUITES],[VAN-SHOP BY PHONE],[VAN-STOP TEAM],[VAN-VOLUNTEER SERVICES],[VANCOUVER FINANCE],[XICY-BUILDING BLOCKS],[XICY-REGIONAL PEDIATRICS-SW],[XMH-RMD LIONS MANOR],[XTST-MENTAL HEALTH],[YOUTH CLINIC 1 - EBYHC],[YOUTH CLINIC 2 - EAST VAN],[YOUTH CLINIC 2 - NORTH],[YOUTH CLINIC 3 - EVERGREEN],[YOUTH CLINIC 4 - BOULEVARD],[YOUTH CLINIC 5 - BYRC],[YOUTH CLINIC 5 - MID-MAIN],[YOUTH CLINIC 6 - KNIGHT ST],[YPPP-VAN EVERGREEN],[Z-CLIENT RELATIONS & RISK MGMT],[Z-HOSPICE-MAY, COTTAGE, MARION],[Z-HSG/MH HOUSING],[Z-MH MHES ADDICTION SERVICES],[Z-MH-AOA MH CLINICIANS],[Z-MH-SEXUAL MEDICINE],[Z-MH-T WEST SIDE],[Z-NS SW READ ONLY],[Z-PHC MH ELDER CARE],[Z-PHC-SW READ ONLY],[Z-READONLY CHRONIC DISEASE MGT],[Z-READONLY-VAN ACUT PSYCHIATRY],[Z-VA-READONLY ALLIED HEALTH],[Z-VAN-SW READ ONLY])
) AS piv
