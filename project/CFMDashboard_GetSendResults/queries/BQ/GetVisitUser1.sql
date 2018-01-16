SELECT
    STRFTIME_UTC_USEC(HVU_SENDDT, "%Y/%m/%d") AS HVU_SENDDT
    ,HVU_CHANNELID
    ,HVU_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID
    ,HVU_DEVICEID
    ,NULL AS HVU_OSID
    ,HVU_FULLVISITORID
    ,HVU_EMAILID
    ,NULL AS HVU_OFFERID
    ,STRFTIME_UTC_USEC(HVU_VISITTIME, "%Y/%m/%d %H:%M:%S") AS HVU_VISITTIME
    ,HVU_REVENUE
FROM
    --マスメール
    (
    SELECT
        MM_VISITTIME AS HVU_VISITTIME
        ,MM_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,CASE
            WHEN MM_DEVICE = 'MO' THEN 1
            WHEN MM_DEVICE = 'PC' THEN 2
        END AS HVU_DEVICEID
        ,CASE
            WHEN MM_DEVICE = 'PC'
                 AND LENGTH(MM_CAMPAIGN) >= 13--YYYYMMDD_PC_以降にEMAILIDが入っているキャンペーンに絞る
                 AND REGEXP_MATCH(MM_EMAILID, R'^[0-9]{8}')
            THEN INTEGER(MM_EMAILID)
            ELSE NULL--MOなどEMAILIDがついていないパターンもあるのでNULLはあり得る
        END AS HVU_EMAILID
        ,MM_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(MM_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            MMB_VISITTIME AS MM_VISITTIME
            ,MMB_SENDDT AS MM_SENDDT
            ,MMB_SOURCE AS MM_SOURCE
            ,LEFT(MMB_DEVICE, 2) AS MM_DEVICE
            ,MMB_EMAILID AS MM_EMAILID
            ,MMB_FULLVISITORID AS MM_FULLVISITORID
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
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        ) AS MAIL_MASS_BASE/*PREFIX = MMB*/
    ) AS MAIL_MASS/*PREFIX = MM*/
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON MM_SOURCE = MPM_PARAMETER
    WHERE
        MM_DEVICE IN ('PC', 'MO')
        AND DATEDIFF(MM_DATE, MM_SENDDT) >= 0
        AND DATEDIFF(MM_DATE, MM_SENDDT) <= 7--配信から7日以内の流入に絞る
        AND MPM_CHANNELID = 1--メール
        AND MPM_CHANNEL_DETAILID = 2--マス
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_DEVICEID
        ,HVU_EMAILID
        ,HVU_FULLVISITORID
    )