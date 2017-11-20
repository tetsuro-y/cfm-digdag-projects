SELECT
    STRFTIME_UTC_USEC(VC_VISITTIME, "%Y/%m/%d %H:%M:%S") AS VC_VISITTIME
    ,STRFTIME_UTC_USEC(VC_SENDDT, "%Y/%m/%d") AS VC_SENDDT
    ,VC_CHANNEL
    ,VC_CHANNEL_DETAIL
    ,VC_CAMPAIGNID
    ,VC_DEVICE
    ,NULL AS VC_OS
    ,NULL AS VC_EMAILID
    ,VC_OFFERID
    ,VC_FULLVISITORID
    ,VC_REVENUE
FROM
    --Pメール_2.0
    (
    SELECT
        MPO_VISITTIME AS VC_VISITTIME
        ,MPO_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,CASE
            WHEN MPO_DEVICE IN ('mo', 'MO') THEN 1
            WHEN MPO_DEVICE IN ('pc', 'PC') THEN 2
            ELSE NULL
        END AS VC_DEVICE
        ,MPO_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(MPO_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS MPO_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS MPO_SENDDT
            ,NTH(3,SPLIT(trafficSource.source, '_')) AS MPO_SOURCE
            ,NTH(5,SPLIT(trafficSource.source, '_')) AS MPO_DEVICE
            ,FULLVISITORID AS MPO_FULLVISITORID
            ,totals.totalTransactionRevenue AS MPO_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'mailpersonal'
    ) AS MAIL_PERSONALIZE_OLD/*PREFIX = MPO*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON MPO_SOURCE = PM_PARAMETER
    WHERE
        MPO_DEVICE IN ('PC' , 'MO', 'pc', 'mo')
        AND REGEXP_MATCH(MPO_SOURCE,'^C[0-9]{9}')--Cから始まるキャンペーンコード
        AND DATEDIFF(DATE, MPO_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_DEVICE
        ,VC_FULLVISITORID
    ),
    --Pメール_3.0
    (
    SELECT
        MPN_VISITTIME AS VC_VISITTIME
        ,MPN_SENDDT AS VC_SENDDT
        ,1 AS VC_CHANNEL
        ,4 AS VC_CHANNEL_DETAIL
        ,INTEGER(MPN_CAMPAIGNID) AS VC_CAMPAIGNID
        ,INTEGER(MPN_DEVICE) AS VC_DEVICE
        ,INTEGER(MPN_OFFERID) AS VC_OFFERID
        ,MPN_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(MPN_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
    SELECT
        FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS MPN_VISITTIME
        ,LEFT(trafficSource.campaign,8) AS MPN_SENDDT
        ,NTH(3,SPLIT(trafficSource.source, '_')) AS MPN_CAMPAIGNID
        ,NTH(4,SPLIT(trafficSource.source, '_')) AS MPN_DEVICE
        ,NTH(2,SPLIT(trafficSource.campaign, '_')) AS MPN_OFFERID
        ,FULLVISITORID AS MPN_FULLVISITORID
        ,totals.totalTransactionRevenue AS MPN_REVENUE
        ,DATE
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
    WHERE
        trafficsource.medium = 'mailpersonal'
    ) AS MAIL_PERSONALIZE_NEW/*PREFIX = MPN*/
    WHERE
        MPN_DEVICE IN ('1','2')
        AND REGEXP_MATCH(STRING(MPN_OFFERID),'^[0-9]{2,}')
        AND DATEDIFF(DATE, MPN_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_DEVICE
        ,VC_OFFERID
        ,VC_FULLVISITORID
    ),
    --トランザクションメール
    (
    SELECT
        MT_VISITTIME AS VC_VISITTIME
        ,MT_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,MT_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(MT_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS MT_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS MT_SENDDT
            ,trafficSource.source AS MT_SOURCE
            ,FULLVISITORID AS MT_FULLVISITORID
            ,totals.totalTransactionRevenue AS MT_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            trafficsource.medium = 'mailmag'
            AND trafficsource.source IN ('sd_m', 'rc_m', 'o1_m', 'o2_m', 'o3_m')
    ) AS MAIL_TRANSACTION/*PREFIX = MT*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON MT_SOURCE = PM_PARAMETER
    WHERE
        DATEDIFF(DATE, MT_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_FULLVISITORID
    )