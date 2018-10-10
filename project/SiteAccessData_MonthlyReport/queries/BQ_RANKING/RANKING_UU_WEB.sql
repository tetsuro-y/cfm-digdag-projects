--ショップ・ブランド別UU
--WEBとAPPをいったんTEMP TABLEにいれる
--APPはTEMP TABLEに入れる時点でTTAGBRANDと紐づけてブランド名にする（そのときスペースや記号がある場合は消す）
--UPPERかけるなどしてWEBとAPPの表記で違いがないようにしてからブランド名でGROUP BYする

--月ごとのショップorブランドごとのUUを取得する
--WEB(ショップ＆ブランド）
SELECT
    STRFTIME_UTC_USEC(UTC_USEC_TO_MONTH(DT), "%Y/%m/%d") AS MONTH
    ,RANKING_CONTENTSID
    ,NAME
    ,SUM(UUCNT) AS UUCNT
FROM (
    SELECT
        STRFTIME_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000, "%Y/%m/%d") AS DT
        ,CASE
             WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                THEN 1--ショップ
            WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                THEN 2--ブランド
            ELSE NULL
        END AS RANKING_CONTENTSID
        ,CASE
            WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                THEN REGEXP_REPLACE(REGEXP_REPLACE(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/', ''), R'/.*', '')
            WHEN REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
                    AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                THEN REGEXP_REPLACE(REGEXP_REPLACE(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/', ''), R'/.*', '')
            ELSE NULL
        END AS NAME
        ,EXACT_COUNT_DISTINCT(PAGE.FULLVISITORID) AS UUCNT
    FROM (
        SELECT
            VISITSTARTTIME
            ,HITS.PAGE.PAGEPATH
            ,FULLVISITORID
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -2, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))--前々月月初から前月末
        WHERE
            TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
            AND (
                (
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*shop/[^/]+/')
                    AND
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                )
                OR
                (
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(((wo)*men|kids)-)*brand/[^/]+/')
                    AND
                    REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*(zozoused/)*(((wo)*men|kids|home)-)*(shop|brand|category)/(zozoused/(innerbrandlist|innershoplist|brand|news|category|$|\?|welcome|aboutsize|aboutcondition|default)|sizeguide(_.+)*\.html|request_mail\.html|innerbrandlist|innershoplist|default|\?|$|[^/]+/((no)*goods|requestnew|viewerHTML5\.html|viewerSimple\.html|(comingsoon|close)\.html))') IS FALSE
                )
            )
    ) AS PAGE
    LEFT OUTER JOIN (
        --Firefox ver38.0経由の不審な流入除外
        SELECT
            FULLVISITORID
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'MONTH'), DATE_ADD(TIMESTAMP(FORMAT_UTC_USEC(UTC_USEC_TO_MONTH(NOW()))), -1, 'DAY'))
        WHERE
            DEVICE.LANGUAGE = 'en-us'
            AND DEVICE.BROWSER = 'Firefox'
            AND DEVICE.BROWSERVERSION = '38.0'
        GROUP EACH BY
            FULLVISITORID
    ) AS EXCLUDE ON PAGE.FULLVISITORID = EXCLUDE.FULLVISITORID
    WHERE
        EXCLUDE.FULLVISITORID IS NULL
    GROUP EACH BY
        DT
        ,RANKING_CONTENTSID
        ,NAME
) AS GETDAILYDATA
GROUP EACH BY
    MONTH
    ,RANKING_CONTENTSID
    ,NAME