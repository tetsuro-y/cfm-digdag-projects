SELECT
    STRFTIME_UTC_USEC(UTC_USEC_TO_MONTH(SAP_DT), "%Y/%m/%d") AS SAP_MONTH
    ,SAP_DEVICEID
    ,SAP_PAGECATEGORYID
    ,SUM(SAP_CNT_USER) AS SAP_CNT_USER
    ,SUM(SAP_PV) AS SAP_PV
    ,ROUND(SUM(SAP_BOUNCECNT) / SUM(SAP_SESSIONCNT), 4) AS SAP_BOUNCERATE
    ,ROUND(SUM(SAP_CNT_CVUSER) / SUM(SAP_CNT_USER), 4) AS SAP_CVR
FROM (
    --トップ
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,1 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')--トップ
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')--トップ
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')--トップ
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --検索結果_全体
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,2 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_全体
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_全体
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_全体
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --検索結果_ショップ
        SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,3 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ショップ
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ショップ
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ショップ
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --検索結果_ブランド
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,4 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ブランド
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ブランド
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ブランド
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --検索結果_カテゴリ
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,5 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*category/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_カテゴリ
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*category/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_カテゴリ
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*category/[^/]+/')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_カテゴリ
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --検索結果_その他
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,6 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*search/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_その他
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*search/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_その他
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*search/')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_その他
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --商品詳細
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,7 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)') --商品詳細
            ) AS PAGE
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)') --商品詳細
            ) AS PAGE
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)') --商品詳細
        ) AS PAGE
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
),
(
    --その他
    SELECT
        UU_DT AS SAP_DT
        ,UU_DEVICEID AS SAP_DEVICEID
        ,8 AS SAP_PAGECATEGORYID
        ,UUCNT AS SAP_CNT_USER
        ,PVCNT AS SAP_PV
        ,SESSIONCNT AS SAP_SESSIONCNT
        ,BOUNCECNT AS SAP_BOUNCECNT
        ,CVUUCNT AS SAP_CNT_CVUSER
    FROM (
        SELECT
            UU_DT
            ,UU_DEVICEID
            ,UUCNT
            ,PVCNT
            ,SESSIONCNT
            ,BOUNCECNT
        FROM (
            --UU・PV
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS UU_DT
                ,DEVICEID AS UU_DEVICEID
                ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS UUCNT
                ,COUNT(UNIQUEID) AS PVCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITS.HITNUMBER AS HITNUMBER
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
                    ,HITS.PAGE.PAGEPATH AS PAGEPATH
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                GROUP EACH BY
                    VISITSTARTTIME
                    ,FULLVISITORID
                    ,VISITID
                    ,HITNUMBER
                    ,DEVICEID
                    ,UNIQUEID
                    ,PAGEPATH
            ) AS PAGE
            LEFT OUTER JOIN (
                --SAP_PAGECATEGORYID1～7に分類されているページは除外する
                SELECT
                    HITS.PAGE.PAGEPATH AS PAGEPATH
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')
                    OR
                        (
                        REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
                        AND
                        REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                        )
                    OR REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)')
                GROUP EACH BY
                    PAGEPATH
            ) AS EXCLUDE ON PAGE.PAGEPATH = EXCLUDE.PAGEPATH
        WHERE
            EXCLUDE.PAGEPATH IS NULL--EXCLUDEに含まれないページ
        GROUP BY
            UU_DT
            ,UU_DEVICEID
        ) AS UU
        --流入があれば少なくともセッションは必ず存在するのでINNER JOIN
        INNER JOIN (
        --直帰数・セッション数
            SELECT
                STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS BOUNCE_DT
                ,DEVICEID AS BOUNCE_DEVICEID
                ,SUM(NVL(BOUNCE, 0)) AS BOUNCECNT
                ,COUNT(VISITNUMBER) AS SESSIONCNT
            FROM (
                SELECT
                    VISITSTARTTIME
                    ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                    ,TOTALS.BOUNCES AS BOUNCE--直帰したセッションはここが1になる。その他はnull
                    ,VISITNUMBER--このユーザーのセッション数
                    ,HITS.PAGE.PAGEPATH AS PAGEPATH
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                    AND HITS.TYPE = 'PAGE'
                    AND HITS.ISENTRANCE IS TRUE
                GROUP EACH BY
                    VISITSTARTTIME
                    ,DEVICEID
                    ,BOUNCE
                    ,VISITNUMBER
                    ,PAGEPATH
            ) AS PAGE
            LEFT OUTER JOIN (
                --SAP_PAGECATEGORYID1～7に分類されているページは除外する
                SELECT
                    HITS.PAGE.PAGEPATH AS PAGEPATH
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
                WHERE
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')
                    OR
                        (
                        REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
                        AND
                        REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                        )
                    OR REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)')
                GROUP EACH BY
                    PAGEPATH
            ) AS EXCLUDE ON PAGE.PAGEPATH = EXCLUDE.PAGEPATH
            WHERE
                EXCLUDE.PAGEPATH IS NULL--EXCLUDEに含まれないページ
            GROUP BY
                BOUNCE_DT
                ,BOUNCE_DEVICEID
        ) AS BOUNCE ON UU_DT = BOUNCE_DT AND UU_DEVICEID = BOUNCE_DEVICEID
    ) AS VISITDATA
    --CVがない可能性もあるのでLEFT JOIN
    LEFT OUTER JOIN (
        SELECT
            STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS CV_DT
            ,DEVICEID AS CV_DEVICEID
            ,EXACT_COUNT_DISTINCT(CASE WHEN ARIGATO.FULLVISITORID IS NOT NULL AND PAGE.HITNUMBER < ARIGATO.HITNUMBER THEN PAGE.FULLVISITORID ELSE NULL END) AS CVUUCNT
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
                ,HITS.PAGE.PAGEPATH AS PAGEPATH
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND HITS.TYPE = 'PAGE'
            GROUP EACH BY
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITNUMBER
                ,DEVICEID
                ,PAGEPATH
        ) AS PAGE
        LEFT OUTER JOIN (
            --SAP_PAGECATEGORYID1～7に分類されているページは除外する
            SELECT
                HITS.PAGE.PAGEPATH AS PAGEPATH
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')
                OR
                    (
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
                    AND
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                    )
                OR REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)')
            GROUP EACH BY
                PAGEPATH
        ) AS EXCLUDE ON PAGE.PAGEPATH = EXCLUDE.PAGEPATH
        LEFT OUTER JOIN (
            SELECT
                FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
            WHERE
                TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
                AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
            GROUP EACH BY
                FULLVISITORID
                ,VISITID
                ,HITNUMBER
        ) AS ARIGATO ON PAGE.FULLVISITORID = ARIGATO.FULLVISITORID AND PAGE.VISITID = ARIGATO.VISITID
        WHERE
            EXCLUDE.PAGEPATH IS NULL--EXCLUDEに含まれないページ
        GROUP BY
            CV_DT
            ,CV_DEVICEID
    ) AS CVDATA ON UU_DT = CV_DT AND UU_DEVICEID = CV_DEVICEID
)
GROUP EACH BY
    SAP_MONTH
    ,SAP_DEVICEID
    ,SAP_PAGECATEGORYID