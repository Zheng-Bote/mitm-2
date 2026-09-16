SELECT 
    e.*, 
    COALESCE(ta_o.orgid, o.orgid) AS orgid, 
    COALESCE(ta_o.short, o.short) AS short, 
    COALESCE(ta_o.parent_org_id, o.parent_org_id) AS parent_org_id,
    
    COALESCE(ta_o.short, e.departmentcode) AS departmentcode,
    COALESCE(ta."COSTCENTER", e.costcenter) AS costcenter,
    COALESCE(ta."PERSONELLAREA", e.personellarea) AS personellarea,
    COALESCE(ta."COMPANYCODE", e.companycode) AS companycode

FROM employee e
LEFT JOIN org o 
    ON e.departmentcode = o.short
LEFT JOIN tmp_assignment ta 
    ON e.pernr::varchar = ta."PERNR" 
    AND to_date(ta."ENDDATE", 'DD.MM.YY') >= CURRENT_DATE 
    AND e.companycode IN ('A1', 'DE')
LEFT JOIN org ta_o 
    ON ta."ORGID" = ta_o.orgid;
