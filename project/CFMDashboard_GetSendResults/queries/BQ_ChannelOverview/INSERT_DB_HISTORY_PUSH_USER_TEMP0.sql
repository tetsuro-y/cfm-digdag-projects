--iOS
SELECT
    1 AS OSID
    ,FULLVISITORID
FROM
    TABLE_DATE_RANGE([90402834.ga_sessions_], DATE_ADD(DATE_ADD(CURRENT_DATE(), -1, 'DAY'), -1, 'YEAR'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
GROUP EACH BY
    FULLVISITORID
