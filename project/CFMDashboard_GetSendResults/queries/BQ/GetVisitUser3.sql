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
    --新着(USED)
    (
    SELECT
        MNU_VISITTIME AS HVU_VISITTIME
        ,MNU_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,CASE
            WHEN MNU_DEVICE = 'MO' THEN 1
            WHEN MNU_DEVICE = 'PC' THEN 2
        END AS HVU_DEVICEID
        ,INTEGER(MNU_EMAILID) AS HVU_EMAILID--新着メルマガは過去EMAILIDがついていなかった時期があるためNULLを除く条件は入れられない
        ,MNU_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(MNU_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MNU_VISITTIME
            ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MNU_SENDDT
            ,TRAFFICSOURCE.SOURCE AS MNU_SOURCE
            ,NTH(2, SPLIT(UPPER(TRAFFICSOURCE.CAMPAIGN), '_')) AS MNU_DEVICE
            ,SUBSTR(NTH(1, SPLIT(TRAFFICSOURCE.CAMPAIGN, '_')), 13) AS MNU_EMAILID
            ,FULLVISITORID AS MNU_FULLVISITORID
            ,TOTALS.TOTALTRANSACTIONREVENUE AS MNU_REVENUE
            ,DATE AS MNU_DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            TRAFFICSOURCE.MEDIUM = 'mailmag'
            AND TRAFFICSOURCE.SOURCE = 'ni_u_m'--CHANNELIDとCHANNELDETAILIDではTOWN/USEDの区別がつかないためベタ書き
    ) AS MAIL_NEWARRIVAL_USED/*PREFIX = MNU*/
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON MNU_SOURCE = MPM_PARAMETER
    WHERE
        MNU_DEVICE IN ('PC', 'MO')
        AND REGEXP_MATCH(MNU_EMAILID, R'^[0-9]{1,}')
        AND DATEDIFF(MNU_DATE, MNU_SENDDT) >= 0
        AND DATEDIFF(MNU_DATE, MNU_SENDDT) <= 7--配信から7日以内の流入に絞る
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