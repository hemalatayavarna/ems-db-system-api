%dw 2.0
output application/java
---
"WITH vw_INTEGRATION_Affiliate AS(
SELECT st.EDID AS 'EDID',
		s.ExternalCode AS 'Org_Unit_ID',
		s.Name AS 'School_Name',
		CASE WHEN e.EDED < GETDATE() THEN 'N' ELSE 'Y' END AS 'Enrolment_Status_ID',
		CASE WHEN ay.[Description] = 'Prep' THEN 'Reception' ELSE ay.Description END AS 'Year_Level',
		e.ESD AS 'Date_Enrolled',
		e.EDED AS 'Date_Left',
		e.FTE AS 'FTE',
		e.StuRank AS 'Multiple_Enrolment_RN',
		(SELECT MAX(v) FROM (VALUES (e.UpdatedDate),(s.UpdatedDate),(p.UpdatedDate),(ay.UpdatedDate)) as value(v)) as 'Last_Updated_On'
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
		) e on st.PersonId=e.PersonId
LEFT JOIN School s ON s.SchoolId=e.SchoolId
LEFT JOIN AcademicYearOfferedBySchool ayobs ON ayobs.AcademicYearOfferedBySchoolId=e.AcademicYearOfferedBySchoolId AND ayobs.SchoolId=s.SchoolId
LEFT JOIN AcademicYear ay ON ay.AcademicYearId=ayobs.AcademicYearId
)

SELECT * FROM vw_INTEGRATION_Affiliate
WHERE Last_Updated_On >= '$(vars.lastUpdatedOn)'
ORDER BY Org_Unit_ID, EDID OFFSET $(vars.offset) ROWS FETCH NEXT $(vars.limit) ROWS ONLY"
