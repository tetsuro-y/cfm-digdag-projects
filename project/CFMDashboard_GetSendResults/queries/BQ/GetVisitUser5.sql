SELECT
    CASE
        WHEN REGEXP_MATCH(HVU_SENDDT, R'^[0-9]{8}')
            THEN STRFTIME_UTC_USEC(HVU_SENDDT, "%Y/%m/%d")
        ELSE NULL
    END AS HVU_SENDDT
    ,HVU_CHANNELID
    ,HVU_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID
    ,NULL AS HVU_DEVICEID
    ,HVU_OSID
    ,HVU_FULLVISITORID
    ,NULL AS HVU_EMAILID
    ,NULL AS HVU_OFFERID
    ,STRFTIME_UTC_USEC(HVU_VISITTIME, "%Y/%m/%d %H:%M:%S") AS HVU_VISITTIME
    ,NULL AS HVU_CV_FULLVISITORID
    ,HVU_REVENUE
FROM
    --PUSHウェブビュー(ウェブビュー遷移のマス:流入及び収益取得/その他：収益のみ取得）
    (
    SELECT
        PW_VISITTIME AS HVU_VISITTIME
        ,PW_SENDDT AS HVU_SENDDT
        ,3 AS HVU_CHANNELID--PUSH
        ,CASE
            WHEN PW_CAMPAIGNFLAG = 1 THEN MPM_CHANNEL_DETAILID
            WHEN PW_CAMPAIGNFLAG = 2 THEN 4--パーソナライズ
        END AS HVU_CHANNEL_DETAILID
        ,CASE
            WHEN PW_CAMPAIGNFLAG = 1 THEN MPM_MAPPINGID
            WHEN PW_CAMPAIGNFLAG = 2 THEN INTEGER(PW_CAMPAIGNID)
        END AS HVU_CAMPAIGNID
        ,PW_OS AS HVU_OSID
        ,PW_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(PW_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            PWB_VISITTIME AS PW_VISITTIME
            ,LEFT(PWB_SENDDT, 8) AS PW_SENDDT
            ,PWB_CAMPAIGNFLAG AS PW_CAMPAIGNFLAG
            ,PWB_CAMPAIGNID AS PW_CAMPAIGNID
            ,PWB_OS AS PW_OS
            ,PWB_FULLVISITORID AS PW_FULLVISITORID
            ,PWB_REVENUE AS PW_REVENUE
            ,PWB_DATE AS PW_DATE
        FROM (
            SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PWB_VISITTIME
                ,NTH(4, SPLIT(REGEXP_REPLACE(TRAFFICSOURCE.CAMPAIGN, R'^.*-', ''), '_')) AS PWB_SENDDT
                ,CASE
                    WHEN REGEXP_MATCH(TRAFFICSOURCE.CAMPAIGN, R'PUSH_(M|S|N)\d{3}.*') THEN 1--パーソナライズ以外
                    WHEN REGEXP_MATCH(TRAFFICSOURCE.CAMPAIGN, R'PUSH_P\d{3}.*') THEN 2--パーソナライズ
                END AS PWB_CAMPAIGNFLAG
                ,CASE
                    WHEN REGEXP_MATCH(TRAFFICSOURCE.CAMPAIGN, R'PUSH_(M|S|N)\d{3}.*')
                        THEN CONCAT(NTH(2, SPLIT(REGEXP_REPLACE(TRAFFICSOURCE.CAMPAIGN, R'^.*-', ''), '_')),'_',NTH(3,SPLIT(REGEXP_REPLACE(TRAFFICSOURCE.CAMPAIGN, R'^.*-', ''), '_')) )
                    WHEN REGEXP_MATCH(TRAFFICSOURCE.CAMPAIGN, R'PUSH_P\d{3}.*')
                        THEN NTH(1, SPLIT(REGEXP_REPLACE(TRAFFICSOURCE.CAMPAIGN, R'^.*PUSH_P', ''), '_'))
                    ELSE NULL
                END AS PWB_CAMPAIGNID
                ,CASE
                    WHEN TRAFFICSOURCE.SOURCE = 'ios' THEN 1
                    WHEN TRAFFICSOURCE.SOURCE = 'android' THEN 2
                END AS PWB_OS
                ,CASE
                    WHEN REGEXP_MATCH(TRAFFICSOURCE.CAMPAIGN, R'PUSH_M\d{3}.*') THEN FULLVISITORID
                    ELSE NULL
                END AS PWB_FULLVISITORID--ウェブビュー遷移のマスPUSHのみFULLVISITORIDを取得、それ以外は収益のみの取得
                ,TOTALS.TOTALTRANSACTIONREVENUE AS PWB_REVENUE
                ,DATE AS PWB_DATE
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
                ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                TRAFFICSOURCE.SOURCE IN ('ios', 'android')
                AND REGEXP_MATCH(TRAFFICSOURCE.CAMPAIGN, R'PUSH_(M|S|N|P)\d{3}.*')
        )AS PUSH_WEBVIEW_BASE/*PREFIX = PWB*/
    )AS PUSH_WEBVIEW/*PREFIX = PW*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON PW_CAMPAIGNID = MPM_PARAMETER--パーソナライズPUSHはマッピングテーブルとJOINできないのでLEFT JOIN
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_OSID
        ,HVU_FULLVISITORID
    ),
    --マスPUSH_ネイティブ
    (
    SELECT
        PMN_VISITTIME AS HVU_VISITTIME
        ,PMN_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,PMN_OS AS HVU_OSID
        ,PMN_FULLVISITORID AS HVU_FULLVISITORID
    FROM (
        SELECT
            PMN_VISITTIME
            ,LEFT(PMN_SENDDT_BASE, 8) AS PMN_SENDDT
            ,PMN_CAMPAIGNID
            ,PMN_OS
            ,PMN_FULLVISITORID
            ,PMN_DATE
        FROM
            --PUSH_MASS_NATIVE/*PREFIX = PMN*/
            --iOS
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PMN_VISITTIME
                ,NTH(3, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')) AS PMN_SENDDT_BASE
                ,CONCAT(NTH(1, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')), '_', NTH(2, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_'))) AS PMN_CAMPAIGNID
                ,1 AS PMN_OS
                ,FULLVISITORID AS PMN_FULLVISITORID
                ,DATE AS PMN_DATE
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName, R'^.*push_type=PUSH_S')),
            --Android
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PMN_VISITTIME
                ,NTH(3, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')) AS PMN_SENDDT_BASE
                ,CONCAT(NTH(1, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')), '_', NTH(2, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_'))) AS PMN_CAMPAIGNID
                ,2 AS PMN_OS
                ,FULLVISITORID AS PMN_FULLVISITORID
                ,DATE AS PMN_DATE
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName, R'^.*push_type=PUSH_S')),
    ) AS VISIT
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON PMN_CAMPAIGNID = MPM_PARAMETER
    WHERE
        MPM_CHANNELID = 3--PUSH
        AND MPM_CHANNEL_DETAILID = 2--マス
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_OSID
        ,HVU_FULLVISITORID
    ),
    --新着PUSH（おまとめ/リアルタイム）
    (
    SELECT
        PN_VISITTIME AS HVU_VISITTIME
        ,PN_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,PN_OS AS HVU_OSID
        ,PN_FULLVISITORID AS HVU_FULLVISITORID
    FROM (
        SELECT
            PN_VISITTIME
            ,LEFT(PN_SENDDT_BASE, 8) AS PN_SENDDT
            ,PN_CAMPAIGNID
            ,PN_OS
            ,PN_FULLVISITORID
            ,PN_DATE
        FROM
            --PUSH_NEWARRIVAL/*PREFIX = PN*/
            --iOS
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PN_VISITTIME
                ,NTH(3, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')) AS PN_SENDDT_BASE
                ,CONCAT(NTH(1, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')), '_', NTH(2, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_'))) AS PN_CAMPAIGNID
                ,1 AS PN_OS
                ,FULLVISITORID AS PN_FULLVISITORID
                ,DATE AS PN_DATE
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(hits.appInfo.screenName, R'^.*push_type=PUSH_N')),
            --Android
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PN_VISITTIME
                ,NTH(3, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')) AS PN_SENDDT_BASE
                ,CONCAT(NTH(1, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')), '_', NTH(2, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_'))) AS PN_CAMPAIGNID
                ,2 AS PN_OS
                ,FULLVISITORID AS PN_FULLVISITORID
                ,DATE AS PN_DATE
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^.*push_type=PUSH_N'))
        ) AS VISIT
        INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON PN_CAMPAIGNID = MPM_PARAMETER
    WHERE
        MPM_CHANNELID = 3--PUSH
        AND MPM_CHANNEL_DETAILID = 1--新着
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_OSID
        ,HVU_FULLVISITORID
    ),
    --パーソナライズPUSH
    (
    SELECT
        PP_VISITTIME AS HVU_VISITTIME
        ,PP_SENDDT AS HVU_SENDDT
        ,3 AS HVU_CHANNELID--PUSH
        ,4 AS HVU_CHANNEL_DETAILID--パーソナライズ
        ,INTEGER(PP_CAMPAIGNID) AS HVU_CAMPAIGNID
        ,PP_OS AS HVU_OSID
        ,PP_FULLVISITORID AS HVU_FULLVISITORID
    FROM (
        SELECT
            PP_VISITTIME
            ,LEFT(PP_SENDDT_BASE, 8) AS PP_SENDDT
            ,PP_CAMPAIGNID
            ,PP_OS
            ,PP_FULLVISITORID
            ,PP_DATE
        FROM
            --PUSH_PERSONALIZE/*PREFIX = PP*/
            --iOS
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PP_VISITTIME
                ,NTH(3, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')) AS PP_SENDDT_BASE
                ,NTH(1, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_P', ''), '_')) AS PP_CAMPAIGNID
                ,1 AS PP_OS
                ,FULLVISITORID AS PP_FULLVISITORID
                ,DATE AS PP_DATE
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^.*push_type=PUSH_P')),
            --Android
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS PP_VISITTIME
                ,NTH(3, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_', ''), '_')) AS PP_SENDDT_BASE
                ,NTH(1, SPLIT(REGEXP_REPLACE(HITS.APPINFO.SCREENNAME, R'^.*PUSH_P', ''), '_')) AS PP_CAMPAIGNID
                ,2 AS PP_OS
                ,FULLVISITORID AS PP_FULLVISITORID
                ,DATE AS PP_DATE
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                REGEXP_MATCH(HITS.APPINFO.SCREENNAME, R'^.*push_type=PUSH_P'))
        ) AS VISIT
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_OSID
        ,HVU_FULLVISITORID
    )