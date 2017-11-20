SELECT
    STRFTIME_UTC_USEC(VC_VISITTIME, "%Y/%m/%d %H:%M:%S") AS VC_VISITTIME
    ,STRFTIME_UTC_USEC(VC_SENDDT, "%Y/%m/%d") AS VC_SENDDT
    ,VC_CHANNEL
    ,VC_CHANNEL_DETAIL
    ,VC_CAMPAIGNID
    ,NULL AS VC_DEVICE
    ,NULL AS VC_OS
    ,NULL AS VC_EMAILID
    ,VC_OFFERID
    ,VC_FULLVISITORID
    ,VC_REVENUE
FROM
    --LINE_マス
    (
    SELECT
        LM_VISITTIME AS VC_VISITTIME
        ,LM_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,LM_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(LM_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS LM_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS LM_SENDDT
            ,trafficSource.source AS LM_SOURCE
            ,FULLVISITORID AS LM_FULLVISITORID
            ,totals.totalTransactionRevenue AS LM_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'line'
            AND trafficSource.source = 'mm_l'
    ) AS LINE_MASS/*PREFIX = LM*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON LM_SOURCE = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, LM_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_FULLVISITORID
    ),
    --LINE_パーソナライズ_2.0
    (
    SELECT
        LPO_VISITTIME AS VC_VISITTIME
        ,LPO_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,LPO_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(LPO_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS LPO_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS LPO_SENDDT
            ,NTH(3,SPLIT(trafficSource.source, '_')) AS LPO_SOURCE
            ,FULLVISITORID AS LPO_FULLVISITORID
            ,totals.totalTransactionRevenue AS LPO_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'linepersonal'
            AND LENGTH(trafficSource.campaign) <= 12--2.0はOFFERIDがついていないので
    ) AS LINE_PERSONALIZE_OLD/*PREFIX = LPO*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON LPO_SOURCE = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, LPO_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_FULLVISITORID
    ),
    --LINE_パーソナライズ_3.0
    (
    SELECT
        LPN_VISITTIME AS VC_VISITTIME
        ,LPN_SENDDT AS VC_SENDDT
        ,2 AS VC_CHANNEL
        ,4 AS VC_CHANNEL_DETAIL
        ,INTEGER(LPN_CAMPAIGNID) AS VC_CAMPAIGNID
        ,INTEGER(LPN_OFFERID) AS VC_OFFERID
        ,LPN_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(LPN_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS LPN_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS LPN_SENDDT
            ,NTH(3,SPLIT(trafficSource.source, '_')) AS LPN_CAMPAIGNID
            ,NTH(2,SPLIT(trafficSource.campaign, '_')) AS LPN_OFFERID
            ,FULLVISITORID AS LPN_FULLVISITORID
            ,totals.totalTransactionRevenue AS LPN_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'linepersonal'
    ) AS LINE_PERSONALIZE_NEW/*PREFIX = LPN*/
    WHERE
        REGEXP_MATCH(STRING(LPN_OFFERID),'^[0-9]{2,}')
        AND DATEDIFF(DATE, LPN_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_OFFERID
        ,VC_FULLVISITORID
    ),
    --LINE_タイムライン
    (
    SELECT
        LT_VISITTIME AS VC_VISITTIME
        ,LT_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,LT_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(LT_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS LT_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS LT_SENDDT
            ,trafficSource.source AS LT_SOURCE
            ,FULLVISITORID AS LT_FULLVISITORID
            ,totals.totalTransactionRevenue AS LT_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'line'
            AND trafficSource.source = 'tl_l'
    ) AS LINE_TIMELINE/*PREFIX = LT*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON LT_SOURCE = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, LT_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_FULLVISITORID
    ),
    --LINE_リッチメニュー
    (
    SELECT
        LR_VISITTIME AS VC_VISITTIME
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,LR_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(LR_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS LR_VISITTIME
            ,trafficSource.source AS LR_SOURCE
            ,FULLVISITORID AS LR_FULLVISITORID
            ,totals.totalTransactionRevenue AS LR_REVENUE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'line'
            AND trafficSource.source = 'rm_l'
    ) AS LINE_RICHMENU/*PREFIX = LR*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON LR_SOURCE = PM_PARAMETER
    GROUP EACH BY
        VC_VISITTIME
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_FULLVISITORID
    )