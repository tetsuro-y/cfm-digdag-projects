SELECT
    STRFTIME_UTC_USEC(VC_VISITTIME, "%Y/%m/%d %H:%M:%S") AS VC_VISITTIME
    ,STRFTIME_UTC_USEC(VC_SENDDT, "%Y/%m/%d") AS VC_SENDDT
    ,VC_CHANNEL
    ,VC_CHANNEL_DETAIL
    ,VC_CAMPAIGNID
    ,NULL AS VC_DEVICE
    ,VC_OS
    ,NULL AS VC_EMAILID
    ,NULL AS VC_OFFERID
    ,VC_FULLVISITORID
    ,VC_REVENUE
FROM
    --PUSHウェブビュー(ウェブビュー遷移のマス:流入及び収益取得/その他：収益のみ取得）
    (
    SELECT
        PW_VISITTIME AS VC_VISITTIME
        ,PW_SENDDT AS VC_SENDDT
        ,CASE
            WHEN REGEXP_MATCH(PW_CAMPAIGN, r'PUSH_(M|S|N)\d{3}.*')THEN PM_CHANNEL
            WHEN REGEXP_MATCH(PW_CAMPAIGN, r'PUSH_P\d{3}.*')THEN 3
            ELSE NULL
        END AS VC_CHANNEL
        ,CASE
            WHEN REGEXP_MATCH(PW_CAMPAIGN, r'PUSH_(M|S|N)\d{3}.*')THEN PM_CHANNEL_DETAIL
            WHEN REGEXP_MATCH(PW_CAMPAIGN, r'PUSH_P\d{3}.*')THEN 4
            ELSE NULL
        END AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN REGEXP_MATCH(PW_CAMPAIGN, r'PUSH_(M|S|N)\d{3}.*') AND PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            WHEN REGEXP_MATCH(PW_CAMPAIGN, r'PUSH_P\d{3}.*') THEN INTEGER(PW_CAMPAIGNID)
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,CASE
            WHEN PW_OS = 'ios' THEN 1
            WHEN PW_OS = 'android' THEN 2
            ELSE NULL
        END AS VC_OS
        ,PW_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(PW_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PW_VISITTIME
            ,NTH(4,SPLIT(REGEXP_REPLACE(trafficSource.campaign, r'^.*-', ''), '_')) AS PW_SENDDT
            ,CASE
                WHEN REGEXP_MATCH(trafficSource.campaign, r'PUSH_(M|S|N)\d{3}.*')
                    THEN CONCAT(NTH(2,SPLIT(REGEXP_REPLACE(trafficSource.campaign, r'^.*-', ''), '_')),'_',NTH(3,SPLIT(REGEXP_REPLACE(trafficSource.campaign, r'^.*-', ''), '_')) )
                WHEN REGEXP_MATCH(trafficSource.campaign, r'PUSH_P\d{3}.*')
                    THEN NTH(1,SPLIT(REGEXP_REPLACE(trafficSource.campaign, r'^.*PUSH_P', ''), '_'))
                ELSE NULL
            END AS PW_CAMPAIGNID
            ,trafficSource.campaign AS PW_CAMPAIGN
            ,trafficSource.source AS PW_OS
            ,CASE
                WHEN REGEXP_MATCH(trafficSource.campaign, r'PUSH_M\d{3}.*') THEN FULLVISITORID
                ELSE NULL
            END AS PW_FULLVISITORID--ウェブビュー遷移のマスPUSHのみFULLVISITORIDを取得、それ以外は収益のみの取得
            ,totals.totalTransactionRevenue AS PW_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            trafficSource.source IN ('ios','android')
            AND REGEXP_MATCH(trafficSource.campaign, r'PUSH_(M|S|N|P)\d{3}.*')
    )AS PUSH_WEBVIEW/*PREFIX = PW*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON PW_CAMPAIGNID = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, PW_SENDDT) >= 0
        AND DATEDIFF(DATE, PW_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_OS
        ,VC_FULLVISITORID
    ),
    --マスPUSH_ネイティブ
    (
    SELECT
        PMN_VISITTIME AS VC_VISITTIME
        ,PMN_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,PMN_OS AS VC_OS
        ,PMN_FULLVISITORID AS VC_FULLVISITORID
    FROM (
        SELECT
            PMN_VISITTIME
            ,PMN_SENDDT
            ,PMN_CAMPAIGNID
            ,PMN_OS
            ,PMN_FULLVISITORID
            ,DATE
        FROM
            --PUSH_MASS_NATIVE/*PREFIX = PMN*/
            --iOS
            (SELECT
                FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PMN_VISITTIME
                ,NTH(3,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_S', ''), '_')) AS PMN_SENDDT
                ,CONCAT(NTH(1,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_')), '_', NTH(2,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_'))) AS PMN_CAMPAIGNID
                ,1 AS PMN_OS
                ,FULLVISITORID AS PMN_FULLVISITORID
                ,DATE
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName,'^.*push_type=PUSH_S')),
            --Android
            (SELECT
                FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PMN_VISITTIME
                ,NTH(3,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_S', ''), '_')) AS PMN_SENDDT
                ,CONCAT(NTH(1,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_')), '_', NTH(2,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_'))) AS PMN_CAMPAIGNID
                ,2 AS PMN_OS
                ,FULLVISITORID AS PMN_FULLVISITORID
                ,DATE
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName,'^.*push_type=PUSH_S'))
    ) AS VISIT
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON PMN_CAMPAIGNID = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, PMN_SENDDT) >= 0
        AND DATEDIFF(DATE, PMN_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_OS
        ,VC_FULLVISITORID
    ),
    --新着PUSH（おまとめ/リアルタイム）
    (
    SELECT
        PN_VISITTIME AS VC_VISITTIME
        ,PN_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,PN_OS AS VC_OS
        ,PN_FULLVISITORID AS VC_FULLVISITORID
    FROM (
        SELECT
            PN_VISITTIME
            ,PN_SENDDT
            ,PN_CAMPAIGNID
            ,PN_OS
            ,PN_FULLVISITORID
            ,DATE
        FROM
            --PUSH_NEWARRIVAL/*PREFIX = PN*/
            --iOS
            (SELECT
                FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PN_VISITTIME
                ,NTH(3,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_N', ''), '_')) AS PN_SENDDT
                ,CONCAT(NTH(1,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_')), '_', NTH(2,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_'))) AS PN_CAMPAIGNID
                ,1 AS PN_OS
                ,FULLVISITORID AS PN_FULLVISITORID
                ,DATE
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName,'^.*push_type=PUSH_N')),
            --Android
            (SELECT
                FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PN_VISITTIME
                ,NTH(3,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_N', ''), '_')) AS PN_SENDDT
                ,CONCAT(NTH(1,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_')), '_', NTH(2,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_', ''), '_'))) AS PN_CAMPAIGNID
                ,2 AS PN_OS
                ,FULLVISITORID AS PN_FULLVISITORID
                ,DATE
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName,'^.*push_type=PUSH_N'))
        ) AS VISIT
        LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON PN_CAMPAIGNID = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, PN_SENDDT) >= 0
        AND DATEDIFF(DATE, PN_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_OS
        ,VC_FULLVISITORID
    ),
    --パーソナライズPUSH
    (
    SELECT
        PP_VISITTIME AS VC_VISITTIME
        ,PP_SENDDT AS VC_SENDDT
        ,3 AS VC_CHANNEL
        ,4 AS VC_CHANNEL_DETAIL
        ,INTEGER(PP_CAMPAIGNID) AS VC_CAMPAIGNID
        ,PP_OS AS VC_OS
        ,PP_FULLVISITORID AS VC_FULLVISITORID
    FROM
        --PUSH_PERSONALIZE/*PREFIX = PP*/
        --iOS
        (SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PP_VISITTIME
            ,NTH(3,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_P', ''), '_')) AS PP_SENDDT
            ,NTH(1,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_P', ''), '_')) AS PP_CAMPAIGNID
            ,1 AS PP_OS
            ,FULLVISITORID AS PP_FULLVISITORID
            ,DATE
        FROM
            TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            REGEXP_MATCH(hits.appInfo.screenName,'^.*push_type=PUSH_P')),
        --Android
        (SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS PP_VISITTIME
            ,NTH(3,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_P', ''), '_')) AS PP_SENDDT
            ,NTH(1,SPLIT(REGEXP_REPLACE(hits.appInfo.screenName, r'^.*PUSH_P', ''), '_')) AS PP_CAMPAIGNID
            ,2 AS PP_OS
            ,FULLVISITORID AS PP_FULLVISITORID
            ,DATE
        FROM
            TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            REGEXP_MATCH(hits.appInfo.screenName,'^.*push_type=PUSH_P'))
    WHERE
        DATEDIFF(DATE, PP_SENDDT) >= 0
        AND DATEDIFF(DATE, PP_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_OS
        ,VC_FULLVISITORID
    )