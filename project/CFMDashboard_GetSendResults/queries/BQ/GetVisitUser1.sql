SELECT
    CASE
        WHEN REGEXP_MATCH(HVU_SENDDT, R'^[0-9]{8}')
            THEN STRFTIME_UTC_USEC(HVU_SENDDT, "%Y/%m/%d")
        ELSE NULL
    END AS HVU_SENDDT
    ,HVU_CHANNELID
    ,HVU_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID
    ,HVU_DEVICEID
    ,NULL AS HVU_OSID
    ,HVU_FULLVISITORID
    ,HVU_EMAILID
    ,NULL AS HVU_OFFERID
    ,STRFTIME_UTC_USEC(HVU_VISITTIME, "%Y/%m/%d %H:%M:%S") AS HVU_VISITTIME
    ,HVU_CV_FULLVISITORID
    ,HVU_REVENUE
FROM
    --マスメール
    (
    SELECT
        AD_VISITTIME AS HVU_VISITTIME
        ,AD_SENDDT AS HVU_SENDDT
        ,AD_CHANNELID AS HVU_CHANNELID
        ,AD_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,AD_CAMPAIGNID AS HVU_CAMPAIGNID
        ,CASE
            WHEN AD_DEVICE = 'MO' THEN 1
            WHEN AD_DEVICE = 'PC' THEN 2
            ELSE 99
        END AS HVU_DEVICEID
        ,CASE
            WHEN AD_DEVICE = 'PC'
                 AND LENGTH(AD_CAMPAIGN) >= 13--YYYYADDD_PC_以降にEMAILIDが入っているキャンペーンに絞る
                 AND REGEXP_MATCH(AD_EMAILID, R'^[0-9]{8}')
            THEN INTEGER(AD_EMAILID)
            ELSE NULL--MOなどEMAILIDがついていないパターンもあるのでNULLはあり得る
        END AS HVU_EMAILID
        ,AD_FULLVISITORID AS HVU_FULLVISITORID
        ,CASE WHEN CD_FULLVISITORID IS NOT NULL THEN AD_FULLVISITORID ELSE NULL END AS HVU_CV_FULLVISITORID
        ,SUM(INTEGER(NVL(AD_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            MM_VISITTIME AS AD_VISITTIME
            ,MM_SENDDT AS AD_SENDDT
            ,MM_SOURCE AS AD_SOURCE
            ,MM_DEVICE AS AD_DEVICE
            ,MM_EMAILID AS AD_EMAILID
            ,MPM_CHANNELID AS AD_CHANNELID
            ,MPM_CHANNEL_DETAILID AS AD_CHANNEL_DETAILID
            ,MPM_MAPPINGID AS AD_CAMPAIGNID
            ,MM_FULLVISITORID AS AD_FULLVISITORID
            ,MM_VISITID AS AD_VISITID
            ,MM_REVENUE AS AD_REVENUE
            ,MM_CAMPAIGN AS AD_CAMPAIGN
        FROM (
            SELECT
                MMB_VISITTIME AS MM_VISITTIME
                ,MMB_SENDDT AS MM_SENDDT
                ,MMB_SOURCE AS MM_SOURCE
                ,LEFT(MMB_DEVICE, 2) AS MM_DEVICE
                ,MMB_EMAILID AS MM_EMAILID
                ,MMB_FULLVISITORID AS MM_FULLVISITORID
                ,MMB_VISITID AS MM_VISITID
                ,MMB_REVENUE AS MM_REVENUE
                ,MMB_DATE AS MM_DATE
                ,MMB_CAMPAIGN AS MM_CAMPAIGN
            FROM (
                SELECT
                    FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MMB_VISITTIME
                    ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MMB_SENDDT
                    ,TRAFFICSOURCE.SOURCE AS MMB_SOURCE
                    ,NTH(2, SPLIT(UPPER(TRAFFICSOURCE.CAMPAIGN), '_')) AS MMB_DEVICE
                    ,RIGHT(TRAFFICSOURCE.CAMPAIGN, 8) AS MMB_EMAILID
                    ,FULLVISITORID AS MMB_FULLVISITORID
                    ,TOTALS.TOTALTRANSACTIONREVENUE AS MMB_REVENUE
                    ,DATE AS MMB_DATE
                    ,TRAFFICSOURCE.CAMPAIGN AS MMB_CAMPAIGN
                    ,VISITID AS MMB_VISITID
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
                    ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            ) AS MAIL_MASS_BASE/*PREFIX = MMB*/
        ) AS MAIL_MASS/*PREFIX = MM*/
        INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON MM_SOURCE = MPM_PARAMETER
        WHERE
            MPM_CHANNELID = 1--メール
            AND MPM_CHANNEL_DETAILID = 2--マス
    ) AS ACCESSDATA/*PREFIX=AD*/
    LEFT OUTER JOIN (
        SELECT
            FULLVISITORID AS CD_FULLVISITORID
            ,VISITID AS CD_VISITID
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
        GROUP EACH BY
            CD_FULLVISITORID
            ,CD_VISITID
    ) AS CVDATA /*PREFIX=CD*/ ON AD_FULLVISITORID = CD_FULLVISITORID AND AD_VISITID = CD_VISITID
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_DEVICEID
        ,HVU_EMAILID
        ,HVU_FULLVISITORID
        ,HVU_CV_FULLVISITORID
    )