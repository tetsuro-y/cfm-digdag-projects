SELECT
    STRFTIME_UTC_USEC(UTC_USEC_TO_MONTH(SAL_DT), "%Y/%m/%d") AS SAL_MONTH
    ,SAL_DEVICEID
    ,SAL_PAGECATEGORYID
    ,SAL_SOURCEID
    ,SUM(SAL_CNT_USER) AS SAL_CNT_USER
    ,ROUND(SUM(SAL_BOUNCECNT) / SUM(SAL_SESSIONCNT), 4) AS SAL_BOUNCERATE
FROM (
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,1 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*($|default\.html|\?)')--トップ
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,2 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids|home)-)*(shop|brand|category|search)/')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_全体
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,3 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ショップ
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,4 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_ブランド
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,5 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*category/[^/]+/')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_カテゴリ
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,6 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*search/')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE--検索結果_その他
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS SAL_DEVICEID
        ,7 AS SAL_PAGECATEGORYID
        ,CASE
            WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                    OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                    OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                    OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                THEN 1--Organic
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                THEN 2--Mail
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                THEN 3--AD
            WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                THEN 4--Direct
            WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                THEN 5--LINE
            ELSE 6--その他
        END AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
    WHERE
        TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
        AND HITS.TYPE = 'PAGE'
        AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*shop/[^/]+/goods(-sale)*/\d+/(\?|$)') --商品詳細
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
),
(
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS SAL_DT
        ,DEVICEID AS SAL_DEVICEID
        ,8 AS SAL_PAGECATEGORYID
        ,SOURCEID AS SAL_SOURCEID
        ,EXACT_COUNT_DISTINCT(FULLVISITORID) AS SAL_CNT_USER
        ,COUNT(VISITNUMBER) AS SAL_SESSIONCNT
        ,SUM(NVL(TOTALS.BOUNCES, 0)) AS SAL_BOUNCECNT
    FROM (
        SELECT
            VISITSTARTTIME
            ,FULLVISITORID
            ,CASE WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*') IS FALSE THEN 1 ELSE 2 END AS DEVICEID
            ,CASE
                WHEN TRAFFICSOURCE.MEDIUM = 'organic'
                        OR TRAFFICSOURCE.SOURCE = 'sp-search.auone.jp'
                        OR TRAFFICSOURCE.SOURCE = 'search.smt.docomo.ne.jp'
                        OR (REGEXP_MATCH(TRAFFICSOURCE.SOURCE, R'^search\.yahoo\.co\.jp') AND TRAFFICSOURCE.MEDIUM = 'referral')
                    THEN 1--Organic
                WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(mailpersonal|mailmag)')
                    THEN 2--Mail
                WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM,R'^(cpm|cpc|cpa|display|affiliate)$')
                    THEN 3--AD
                WHEN TRAFFICSOURCE.SOURCE = '(direct)' AND TRAFFICSOURCE.MEDIUM = '(none)' AND GEONETWORK.NETWORKLOCATION <> 'amazon data services japan'
                    THEN 4--Direct
                WHEN REGEXP_MATCH(TRAFFICSOURCE.MEDIUM, R'^(linepersonal|line)') AND TRAFFICSOURCE.MEDIUM <> 'usagionline'
                    THEN 5--LINE
                ELSE 6--その他
            END AS SOURCEID
            ,HITS.PAGE.PAGEPATH AS PAGEPATH
            ,TOTALS.BOUNCES
            ,VISITNUMBER
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
        WHERE
            TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
            AND HITS.TYPE = 'PAGE'
            AND HITS.ISENTRANCE IS TRUE--ランディングページに絞る
        GROUP EACH BY
            VISITSTARTTIME
            ,FULLVISITORID
            ,DEVICEID
            ,SOURCEID
            ,PAGEPATH
            ,TOTALS.BOUNCES
            ,VISITNUMBER
    ) AS PAGE
    LEFT OUTER JOIN (
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
    GROUP EACH BY
        SAL_DT
        ,SAL_DEVICEID
        ,SAL_PAGECATEGORYID
        ,SAL_SOURCEID
)
GROUP EACH BY
    SAL_MONTH
    ,SAL_DEVICEID
    ,SAL_PAGECATEGORYID
    ,SAL_SOURCEID