SELECT
    STRFTIME_UTC_USEC(VC_VISITTIME, "%Y/%m/%d %H:%M:%S") AS VC_VISITTIME
    ,STRFTIME_UTC_USEC(VC_SENDDT, "%Y/%m/%d") AS VC_SENDDT
    ,VC_CHANNEL
    ,VC_CHANNEL_DETAIL
    ,VC_CAMPAIGNID
    ,VC_DEVICE
    ,NULL AS VC_OS
    ,VC_EMAILID
    ,NULL AS VC_OFFERID
    ,VC_FULLVISITORID
    ,VC_REVENUE
FROM
    --マスメール
    (
    SELECT
        MM_VISITTIME AS VC_VISITTIME
        ,MM_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,CASE
            WHEN MM_DEVICE IN ('MO', 'mo') THEN 1
            WHEN MM_DEVICE IN ('PC', 'pc') THEN 2
            ELSE NULL
        END AS VC_DEVICE
        ,CASE
            WHEN MM_DEVICE IN ('PC', 'pc')
                 AND LENGTH(trafficSource.campaign) >= 9
                 AND REGEXP_MATCH(STRING(MM_EMAILID),'^[0-9]{8}')
            THEN INTEGER(MM_EMAILID)
            ELSE NULL
        END AS VC_EMAILID
        ,MM_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(MM_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS MM_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS MM_SENDDT
            ,trafficSource.source AS MM_SOURCE
            ,NTH(2,SPLIT(trafficSource.campaign, '_')) AS MM_DEVICE
            ,RIGHT(trafficSource.campaign,8) AS MM_EMAILID
            ,FULLVISITORID AS MM_FULLVISITORID
            ,totals.totalTransactionRevenue AS MM_REVENUE
            ,DATE
            ,trafficSource.campaign
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            trafficsource.medium = 'mailmag'
            AND LENGTH(trafficsource.source) = 4
            AND trafficsource.source NOT IN ('ni_m', 'ni_u_m', 'ag_m', 'sd_m', 'r1_m', 'r2_m', 'r3_m', 'r4_m', 'r5_m', 'r6_m', 'r7_m', 'r8_m', 'r9_m', 'b1_m', 'b2_m', 'b3_m', 'b4_m', 'b5_m', 'rc_m', 'o1_m', 'o2_m', 'o3_m', 'dc_m', 'dc_m_b', 'cs_q', 'ss_m', 'pa_m', 'cs_q', 'pl_m')
            AND RIGHT(trafficsource.source, 2) = '_m'
    ) AS MAIL_MASS/*PREFIX = MM*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON MM_SOURCE = PM_PARAMETER
    WHERE
        MM_DEVICE IN ('PC' , 'MO', 'pc', 'mo')
        AND DATEDIFF(DATE, MM_SENDDT) >= 0
        AND DATEDIFF(DATE, MM_SENDDT) <= 7--配信から7日以内の流入に絞る
    GROUP EACH BY
        VC_VISITTIME
        ,VC_SENDDT
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_DEVICE
        ,VC_EMAILID
        ,VC_FULLVISITORID
    )