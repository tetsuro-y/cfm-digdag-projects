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
    --新着(TOWN)
    (
    SELECT
        MNT_VISITTIME AS VC_VISITTIME
        ,MNT_SENDDT AS VC_SENDDT
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,CASE
            WHEN MNT_DEVICE IN ('MO', 'mo') THEN 1
            WHEN MNT_DEVICE IN ('PC', 'pc') THEN 2
            ELSE NULL
         END AS VC_DEVICE
        ,MNT_EMAILID AS VC_EMAILID
        ,MNT_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(MNT_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS MNT_VISITTIME
            ,LEFT(trafficSource.campaign,8) AS MNT_SENDDT
            ,trafficSource.source AS MNT_SOURCE
            ,NTH(2,SPLIT(trafficSource.campaign, '_')) AS MNT_DEVICE
            ,INTEGER(SUBSTR(trafficSource.campaign,13,LENGTH(trafficSource.campaign)-(LENGTH(REGEXP_REPLACE(trafficSource.campaign,r'^\d+',''))+12))) AS MNT_EMAILID
            ,FULLVISITORID AS MNT_FULLVISITORID
            ,totals.totalTransactionRevenue AS MNT_REVENUE
            ,DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            trafficSource.medium = 'mailmag'
            AND trafficSource.source = 'ni_m'
    ) AS MAIL_NEWARRIVAL_TOWN/*PREFIX = MNT*/
    LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON MNT_SOURCE = PM_PARAMETER
    WHERE
        MNT_DEVICE IN ('PC' , 'MO', 'pc', 'mo')
        AND REGEXP_MATCH(STRING(MNT_EMAILID),'^[0-9]{1,}')
        AND DATEDIFF(DATE, MNT_SENDDT) >= 0
        AND DATEDIFF(DATE, MNT_SENDDT) <= 7--配信から7日以内の流入に絞る
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