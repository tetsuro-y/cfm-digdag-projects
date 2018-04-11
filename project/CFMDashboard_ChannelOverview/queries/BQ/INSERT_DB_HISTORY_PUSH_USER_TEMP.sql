SELECT
    OSID
    ,FULLVISITORID
FROM (
    --iOS
    SELECT
        1 AS OSID
        ,FULLVISITORID
    FROM
        TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('2017-11-01'), TIMESTAMP('2017-11-10'))--日付部分は可変にして複数回同クエリをループさせる予定
    GROUP EACH BY
        FULLVISITORID
    ),
    --Android
    (SELECT
        2 AS OSID
        ,FULLVISITORID
    FROM
        TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('2017-11-01'), TIMESTAMP('2017-11-10'))--日付部分は可変にして複数回同クエリをループさせる予定
    GROUP EACH BY
      FULLVISITORID)