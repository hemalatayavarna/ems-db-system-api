%dw 2.0
output application/java
---
"WITH vw_INTEGRATION_Student AS (
	SELECT st.EDID AS 'EDID',
		   s.ExternalCode AS 'Org_Unit_ID',
		   s.Name AS 'School_Name',
		   p.Surname AS 'Last_Name',
		   p.MiddleName AS 'Middle_Name',
		   p.FirstName AS 'First_Name',
		   p.PreferredName AS 'Preferred_Name',
		   p.Gender AS 'Gender_ID',
		   p.BirthDate AS 'Birth_Date',
		   CASE WHEN ay.[Description] = 'Prep' THEN 'Reception' ELSE ay.Description END AS 'Year_Level',
		   CASE
			   WHEN sd.DisabilityAlert = 1 THEN 'Y'
			   ELSE 'N'
		   END AS 'Disability_Status_ID',
		   CASE
			   WHEN e.Guardianship = 1 THEN 'Y'
			   ELSE 'N'
		   END AS 'CYPC_ID',
		  '' AS 'IsInternationalStudent',
		  pc.Description as 'Birth_Country',
		  (SELECT MAX(v) FROM (VALUES (ec.HasCustody),(ArCf.ARCustodyFlag)) as value(v)) AS 'HasCustodyOrder',
		  (SELECT MAX(v) FROM (VALUES (ec.InterventionOrder),(ArIf.ARInterventionFlag)) as value(v)) AS 'HasInterventionOrder',
		  (SELECT MAX(v) FROM (VALUES (e.UpdatedDate),(s.UpdatedDate),(p.UpdatedDate),(ay.UpdatedDate),(sd.UpdatedDate),(ArCf.UpdatedDate),(ArIf.UpdatedDate),(ec.UpdatedDate)) as value(v)) as 'Last_Updated_On'
	FROM Student st
	LEFT JOIN Person p ON p.PersonId=st.PersonId
	LEFT JOIN CountryLookup pc ON p.CountryID=pc.CountryID
	JOIN 
			(select e1.PersonId, 
				e1.EnrolmentId, 
				e1.StartDate as ESD, 
				ed.StartDate as EDSD, 
				e1.EndDate as EED, 
				ed.EndDate as EDED, 
				e1.SchoolId,
				e1.Guardianship,
				e1.UpdatedDate,
				ed.FTE,
				ed.AcademicYearOfferedBySchoolId,
				ROW_Number() OVER(PARTITION BY e1.PersonId ORDER BY ed.status DESC, ed.FTE DESC, CONVERT(date,e1.StartDate,23) DESC) AS StuRank  
				from Enrolment e1 
				Join (select *,
					CASE WHEN EndDate < GETDATE() THEN 'N' ELSE 'Y' END AS 'status',
					ROW_Number() OVER(PARTITION BY EnrolmentID ORDER BY CONVERT(date,StartDate,23) DESC) AS Seq
				from EnrolmentDetail) ed on e1.EnrolmentId=ed.EnrolmentId and ed.Seq=1
			) e on st.PersonId=e.PersonId and e.StuRank=1
	LEFT JOIN School s ON s.SchoolId=e.SchoolId
	LEFT JOIN (
			select *, ROW_Number() OVER(PARTITION BY PersonId ORDER BY UpdatedDate DESC) AS Seq 
				from StudentDisability) sd ON sd.PersonId=p.PersonId AND sd.SchoolId=s.SchoolId and Seq=1
	LEFT JOIN AcademicYearOfferedBySchool ayobs ON ayobs.AcademicYearOfferedBySchoolId=e.AcademicYearOfferedBySchoolId AND ayobs.SchoolId=s.SchoolId
	LEFT JOIN AcademicYear ay ON ay.AcademicYearId=ayobs.AcademicYearId
	LEFT JOIN (
			SELECT EnrolmentId, 
				MAX(CAST(HasCustody AS INT)) as HasCustody,
				MAX(CAST(InterventionOrder AS INT)) as InterventionOrder,
				MAX(UpdatedDate) as UpdatedDate
			from EnrolmentContact
			GROUP BY EnrolmentId) ec ON ec.EnrolmentId=e.EnrolmentId
	LEFT JOIN (
			SELECT ar1.SchoolId, 
					ar1.PersonId, 
					CASE WHEN COUNT(1)>0 THEN 1
					ELSE 0 END AS ARCustodyFlag,
					MAX(ar1.UpdatedDate) AS UpdatedDate
			FROM AccessRestriction ar1
			JOIN AccessAlertType at1 ON ar1.AccessAlertTypeId=at1.AccessAlertTypeId and ar1.SchoolId=at1.SchoolId
			WHERE at1.Name LIKE '%Legal%'and ar1.Message LIKE '%Custody%' and (ar1.StartDate <= GETDATE() or ar1.StartDate is NULL) and (ar1.EndDate is NULL or ar1.EndDate >= GETDATE())
			GROUP BY ar1.SchoolId, 
					ar1.PersonId) ArCf ON ArCf.SchoolId=e.SchoolId and ArCf.PersonId=e.PersonId
	LEFT JOIN (SELECT ar2.SchoolId, 
					ar2.PersonId, 
					CASE WHEN COUNT(1)>0 THEN 1
					ELSE 0 END AS ARInterventionFlag,
					MAX(ar2.UpdatedDate) AS UpdatedDate
			FROM AccessRestriction ar2
			JOIN AccessAlertType at2 ON ar2.AccessAlertTypeId=at2.AccessAlertTypeId and ar2.SchoolId=at2.SchoolId
			WHERE at2.Name LIKE '%Legal%'and ar2.Message LIKE '%Intervention%' and (ar2.StartDate <= GETDATE() or ar2.StartDate is NULL) and (ar2.EndDate is NULL or ar2.EndDate >= GETDATE())
			GROUP BY ar2.SchoolId, 
					ar2.PersonId) ArIf ON ArIf.SchoolId=e.SchoolId and ArIf.PersonId=e.PersonId
)

SELECT * from vw_INTEGRATION_Student 
WHERE Last_Updated_On >= '$(vars.lastUpdatedOn)'
ORDER BY Org_Unit_ID, EDID OFFSET $(vars.offset) ROWS FETCH NEXT $(vars.limit) ROWS ONLY"