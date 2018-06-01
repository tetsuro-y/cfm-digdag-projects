--APP（ブランドのみ）
SELECT
    STRFTIME_UTC_USEC(UTC_USEC_TO_MONTH(DT), "%Y/%m/%d") AS MONTH
    ,BRANDID
    ,SUM(UUCNT) AS UUCNT
FROM (
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS DT
        ,REGEXP_REPLACE(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)p_tbid=', ''), R'&.*', '') AS BRANDID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
    FROM
        TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -2, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--前々月月初から前月末
        ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -2, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)p_tbid=\d+(&|$)')
        AND REGEXP_MATCH(REGEXP_REPLACE(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)p_tbid=', ''), R'&.*', ''), R'^[0-9]{1,}')
    GROUP EACH BY
        DT
        ,BRANDID
) AS GETDAILYDATA
GROUP EACH BY
    MONTH
    ,BRANDID