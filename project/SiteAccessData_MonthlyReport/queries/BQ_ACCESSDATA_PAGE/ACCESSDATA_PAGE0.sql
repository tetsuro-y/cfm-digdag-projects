SELECT
    STRFTIME_UTC_USEC(UTC_USEC_TO_MONTH(SAP_DT), "%Y/%m/%d") AS SAP_MONTH
    ,3 AS SAP_DEVICEID
    ,SAP_PAGECATEGORYID
    ,SUM(SAP_CNT_USER) AS SAP_CNT_USER
    ,SUM(SAP_PV) AS SAP_PV
    ,NULL AS SAP_BOUNCERATE
    ,NULL AS SAP_CVR
FROM (
    --ホーム（トップ）
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,1 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITNUMBER
            ,UNIQUEID
        FROM (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^home/(\d/)*(((wo)*men|kids)/)*(\?|$)')
                AND HITS.APPINFO.APPVERSION >= '5.4.0'
        ),
        (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^(goodshistory|newitemlist|favoritelist)/(\?|$)')
                AND HITS.APPINFO.APPVERSION <'5.4.0'
        ),
        (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^home/(\d/)*(((wo)*men|kids)/)*(\?|$)')
                AND HITS.APPINFO.APPVERSION >= '5.0.0'
        ),
        (
            SELECT
                VISITSTARTTIME
                ,FULLVISITORID
                ,VISITID
                ,HITS.HITNUMBER AS HITNUMBER
                ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^(goodshistory|newitemlist|favoritelist)/(\?|$)')
                AND HITS.APPINFO.APPVERSION <'5.0.0'
        )
    ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --検索結果_全体
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,2 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
        WHERE
            REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/')
            AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)') IS FALSE
    ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --検索結果_ブランド
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,4 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
        WHERE
            REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)p_tbid=\d+(&|$)')
            AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)') IS FALSE
    ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --検索結果_カテゴリ
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,5 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
        WHERE
            REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)p_tycid=\d+(&|$)')
            AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)p_tbid=\d+(&|$)') IS FALSE--検索結果_ブランドを除外
            AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)') IS FALSE
        ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --検索結果_その他
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,6 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
        WHERE
            REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/')
            AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/.*(\?|&)(p_tbid|p_tycid)=\d+(&|$)') IS FALSE--検索結果_ブランド及びカテゴリを除外
            AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)') IS FALSE
    ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --商品詳細
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,7 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
        WHERE
            REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^[^/]+/goods(-sale)*/\d+/(\?|$)')
    ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --その他
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,8 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
        WHERE
            HITS.TYPE = 'APPVIEW'
            AND (
                (
                    (
                    REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^home/(((wo)*men|kids)/)*(\?|$)') IS FALSE
                    AND (REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/') IS FALSE OR REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)'))--検索結果全般除外
                    AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^[^/]+/goods(-sale)*/\d+') IS FALSE
                    )
                    AND HITS.APPINFO.APPVERSION >= '5.4.0'
                )
                OR
                (
                    (
                    REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^(goodshistory|newitemlist|favoritelist)/(\?|$)') IS FALSE
                    AND (REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/') IS FALSE OR REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)'))--検索結果全般除外
                    AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^[^/]+/goods(-sale)*/\d+') IS FALSE
                    )
                    AND HITS.APPINFO.APPVERSION < '5.4.0'
                )
            )

    ),
    (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
        WHERE
            HITS.TYPE = 'APPVIEW'
            AND (
                (
                    (
                    REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^home/(((wo)*men|kids)/)*(\?|$)') IS FALSE
                    AND (REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/') IS FALSE OR REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)'))--検索結果全般除外
                    AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^[^/]+/goods(-sale)*/\d+') IS FALSE
                    )
                    AND HITS.APPINFO.APPVERSION >= '5.0.0'
                )
                OR
                (
                    (
                    REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^(goodshistory|newitemlist|favoritelist)/(\?|$)') IS FALSE
                    AND (REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^((home|favoritelist|newitemlist|favoritebrand|ranking|etc)/)*search/') IS FALSE OR REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^search/top($|\?)'))--検索結果全般除外
                    AND REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^[^/]+/goods(-sale)*/\d+') IS FALSE
                    )
                    AND HITS.APPINFO.APPVERSION < '5.0.0'
                )
            )

    )
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
),
(
    --全体
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAP_DT
        ,9 AS SAP_PAGECATEGORYID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAP_CNT_USER
        ,COUNT(UNIQUEID) AS SAP_PV
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,VISITID
            ,HITS.HITNUMBER AS HITNUMBER
            ,CONCAT(FULLVISITORID, STRING(VISITID), STRING(HITS.HITNUMBER)) AS UNIQUEID--閲覧回数分のレコードをカウントできるよう仮想IDをつくる
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--iOS
            ,TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--Android
    ) AS PAGE
    GROUP EACH BY
        SAP_DT
        ,SAP_PAGECATEGORYID
)
GROUP EACH BY
    SAP_MONTH
    ,SAP_DEVICEID
    ,SAP_PAGECATEGORYID