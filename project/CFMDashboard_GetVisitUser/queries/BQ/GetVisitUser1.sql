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
        ,PM_MAPPINGID AS VC_CAMPAIGNID
        ,CASE
            WHEN MM_DEVICE = 'MO' THEN 1
            WHEN MM_DEVICE = 'PC' THEN 2
        END AS VC_DEVICE
        ,CASE
            WHEN MM_DEVICE = 'PC'
                 AND LENGTH(MM_CAMPAIGN) >= 13--YYYYMMDD_PC_以降にEMAILIDが入っているキャンペーンに絞る
                 AND REGEXP_MATCH(MM_EMAILID, R'^[0-9]{8}')
            THEN INTEGER(MM_EMAILID)
            ELSE NULL--MOなどEMAILIDがついていないパターンもあるのでNULLはあり得る
        END AS VC_EMAILID
        ,MM_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(MM_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MM_VISITTIME
            ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MM_SENDDT
            ,TRAFFICSOURCE.SOURCE AS MM_SOURCE
            ,NTH(2, SPLIT(UPPER(TRAFFICSOURCE.CAMPAIGN), '_')) AS MM_DEVICE
            ,RIGHT(TRAFFICSOURCE.CAMPAIGN, 8) AS MM_EMAILID
            ,FULLVISITORID AS MM_FULLVISITORID
            ,TOTALS.TOTALTRANSACTIONREVENUE AS MM_REVENUE
            ,DATE AS MM_DATE
            ,TRAFFICSOURCE.CAMPAIGN AS MM_CAMPAIGN
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
    ) AS MAIL_MASS/*PREFIX = MM*/
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON MM_SOURCE = PM_PARAMETER
    WHERE
        MM_DEVICE IN ('PC', 'MO')
        AND DATEDIFF(MM_DATE, MM_SENDDT) >= 0
        AND DATEDIFF(MM_DATE, MM_SENDDT) <= 7--配信から7日以内の流入に絞る
        AND PM_CHANNEL = 1--メール
        AND PM_CHANNEL_DETAIL = 2--マス
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