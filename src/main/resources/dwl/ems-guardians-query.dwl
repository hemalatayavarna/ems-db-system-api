%dw 2.0
output application/java
---
"WITH vw_INTEGRATION_Guardian AS(
	SELECT st.EDID AS 'EDID',
		   CASE WHEN G1.ContactOrder IS NULL OR G1.ContactOrder=0 THEN 1
			ELSE G1.ContactOrder END AS 'Family_Parent_Guardian_No',
		   G1.PersonID AS 'Family_Parent_Guardian_ID',
		   G1.Title AS 'Family_Parent_Guardian_Salutation',
		   G1.Surname AS 'Family_Parent_Guardian_Last_Name',
		   G1.FirstName AS 'Family_Parent_Guardian_First_Name',
		   G1.PhoneNumber AS 'Family_Parent_Guardian_Phone',
		   G1.Mobile AS 'Family_Parent_Guardian_Mobile',
		   G1.Email AS 'Family_Parent_Guardian_Email',
		   (SELECT MAX(v) FROM (VALUES (G1.HasCustody),(lcf.LinkedCustodyFlag),(ccf.CommonCustodyFlag)) as value(v)) AS 'HasCustodyOrder',
		   (SELECT MAX(v) FROM (VALUES (G1.InterventionOrder),(lif.LinkedInterventionFlag),(cif.CommonInterventionFlag)) as value(v)) AS 'HasInterventionOrder',
		   (SELECT MAX(v) FROM (VALUES (e.UpdatedDate),(p.UpdatedDate),(G1.UpdatedDate),(lcf.UpdatedDate),(ccf.UpdatedDate),(lif.UpdatedDate),(cif.UpdatedDate)) as value(v)) as 'Last_Updated_On'
	FROM Student st
	LEFT JOIN Person p ON p.PersonId=st.PersonId
	JOIN 
			(select e1.PersonId, 
				e1.EnrolmentId, 
				e1.UpdatedDate,
				e1.SchoolId,
				ROW_Number() OVER(PARTITION BY e1.PersonId ORDER BY ed.status DESC, ed.FTE DESC, CONVERT(date,e1.StartDate,23) DESC) AS StuRank  
				from Enrolment e1 
				Join (select *,
					CASE WHEN EndDate < GETDATE() THEN 'N' ELSE 'Y' END AS 'status',
					ROW_Number() OVER(PARTITION BY EnrolmentID ORDER BY CONVERT(date,StartDate,23) DESC) AS Seq
				from EnrolmentDetail) ed on e1.EnrolmentId=ed.EnrolmentId and ed.Seq=1
			) e on st.PersonId=e.PersonId and e.StuRank=1
	LEFT JOIN (SELECT ec.EnrolmentId,
			  p.PersonID,
			  p.Title,
			  p.Surname,
			  p.FirstName,
			  ppn.PhoneNumber,
			  ppm.PhoneNumber as Mobile,
			  pe.Email,
			  ec.ContactOrder,
			  ec.HasCustody,
			  ec.InterventionOrder,
			  (SELECT MAX(v) FROM (VALUES (ec.UpdatedDate),(p.UpdatedDate),(pe.UpdatedDate),(ppn.UpdatedDate),(ppm.UpdatedDate)) as value(v)) as UpdatedDate
	   FROM EnrolmentContact ec
	   JOIN enrolment e ON e.enrolmentid=ec.enrolmentid
	   JOIN Person p ON p.PersonId=ec.PersonId
	   LEFT JOIN
		 (SELECT personid,
				 email,
				 UpdatedDate,
				 ROW_Number() OVER(PARTITION BY PersonID ORDER BY IsPrimary DESC, EmailCategoryId) AS Seq
		  FROM PersonEmail) pe ON pe.PersonId=p.PersonId
	   AND pe.seq = 1
	   LEFT JOIN
		 (SELECT personid,
				 phonenumber,
				 UpdatedDate,
				 ROW_NUMBER() OVER(PARTITION BY personid ORDER BY IsPrimary DESC, phonetypeID DESC) AS Seq
		  FROM PersonPhonenumber
		  WHERE phonetypeID IN (1, 11, 13)) ppn ON ppn.PersonId=p.PersonId
	   AND ppn.seq = 1
	   LEFT JOIN
		 (SELECT personid,
				 phonenumber,
				 UpdatedDate,
				 ROW_NUMBER() OVER(PARTITION BY personid ORDER BY IsPrimary DESC, phonetypeID DESC) AS Seq
		  FROM PersonPhonenumber
		  WHERE phonetypeID IN (12, 14, 15)) ppm ON ppm.PersonId=p.PersonId
	   AND ppm.seq=1) G1 ON G1.EnrolmentId=e.EnrolmentId
	LEFT JOIN (SELECT ar1.SchoolId, 
					ar1.PersonId, 
					ar1.CaregiverId,
					CASE WHEN COUNT(1)>0 THEN 1
					ELSE 0 END AS LinkedCustodyFlag,
					MAX(ar1.UpdatedDate) AS UpdatedDate
			FROM AccessRestriction ar1
			JOIN AccessAlertType at1 ON ar1.AccessAlertTypeId=at1.AccessAlertTypeId and ar1.SchoolId=at1.SchoolId
			WHERE at1.Name LIKE '%Legal%' and ar1.CaregiverId IS NOT NULL and ar1.Message LIKE '%Custody%' and (ar1.StartDate <= GETDATE() or ar1.StartDate is NULL) and (ar1.EndDate is NULL or ar1.EndDate >= GETDATE())
			GROUP BY ar1.SchoolId, 
					ar1.PersonId, 
					ar1.CaregiverId) lcf ON lcf.SchoolId=e.SchoolId and lcf.PersonId=e.PersonId and G1.PersonId=lcf.CaregiverId
	LEFT JOIN (SELECT ar2.SchoolId, 
					ar2.PersonId, 
					CASE WHEN COUNT(1)>0 THEN 1
					ELSE 0 END AS CommonCustodyFlag,
					MAX(ar2.UpdatedDate) AS UpdatedDate
			FROM AccessRestriction ar2
			JOIN AccessAlertType at2 ON ar2.AccessAlertTypeId=at2.AccessAlertTypeId and ar2.SchoolId=at2.SchoolId
			WHERE at2.Name LIKE '%Legal%' and ar2.CaregiverId IS NULL and ar2.Message LIKE '%Custody%' and (ar2.StartDate <= GETDATE() or ar2.StartDate is NULL) and (ar2.EndDate is NULL or ar2.EndDate >= GETDATE())
			GROUP BY ar2.SchoolId, 
					ar2.PersonId) ccf ON ccf.SchoolId=e.SchoolId and ccf.PersonId=e.PersonId
	LEFT JOIN (SELECT ar3.SchoolId, 
					ar3.PersonId, 
					ar3.CaregiverId,
					CASE WHEN COUNT(1)>0 THEN 1
					ELSE 0 END AS LinkedInterventionFlag,
					MAX(ar3.UpdatedDate) AS UpdatedDate
			FROM AccessRestriction ar3
			JOIN AccessAlertType at3 ON ar3.AccessAlertTypeId=at3.AccessAlertTypeId and ar3.SchoolId=at3.SchoolId
			WHERE at3.Name LIKE '%Legal%' and ar3.CaregiverId IS NOT NULL and ar3.Message LIKE '%Intervention%' and (ar3.StartDate <= GETDATE() or ar3.StartDate is NULL) and (ar3.EndDate is NULL or ar3.EndDate >= GETDATE())
			GROUP BY ar3.SchoolId, 
					ar3.PersonId, 
					ar3.CaregiverId) lif ON lif.SchoolId=e.SchoolId and lif.PersonId=e.PersonId and G1.PersonId=lif.CaregiverId
	LEFT JOIN (SELECT ar4.SchoolId, 
					ar4.PersonId, 
					CASE WHEN COUNT(1)>0 THEN 1
					ELSE 0 END AS CommonInterventionFlag,
					MAX(ar4.UpdatedDate) AS UpdatedDate
			FROM AccessRestriction ar4
			JOIN AccessAlertType at4 ON ar4.AccessAlertTypeId=at4.AccessAlertTypeId and ar4.SchoolId=at4.SchoolId
			WHERE at4.Name LIKE '%Legal%' and ar4.CaregiverId IS NULL and ar4.Message LIKE '%Intervention%' and (ar4.StartDate <= GETDATE() or ar4.StartDate is NULL) and (ar4.EndDate is NULL or ar4.EndDate >= GETDATE())
			GROUP BY ar4.SchoolId, 
					ar4.PersonId) cif ON cif.SchoolId=e.SchoolId and cif.PersonId=e.PersonId
)

SELECT * FROM vw_INTEGRATION_Guardian
WHERE Last_Updated_On >= '$(vars.lastUpdatedOn)'
ORDER BY EDID, Family_Parent_Guardian_No OFFSET $(vars.offset) ROWS FETCH NEXT $(vars.limit) ROWS ONLY"
