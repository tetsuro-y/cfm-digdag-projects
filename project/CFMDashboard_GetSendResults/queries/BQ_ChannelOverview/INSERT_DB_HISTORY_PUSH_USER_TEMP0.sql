--iOS
SELECT
    1 AS OSID
    ,FULLVISITORID
FROM
    TABLE_DATE_RANGE([90402834.ga_sessions_], DATE_ADD(DATE_ADD(CURRENT_DATE(), -1, 'DAY'), -1, 'YEAR'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
WHERE
    REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^.*push_type=PUSH_(N|P|S)')
GROUP EACH BY
    FULLVISITORID
