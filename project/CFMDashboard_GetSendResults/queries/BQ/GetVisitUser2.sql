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
    --新着(TOWN)
    (
    SELECT
        MNT_VISITTIME AS HVU_VISITTIME
        ,MNT_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,CASE
            WHEN MNT_DEVICE  = 'MO' THEN 1
            WHEN MNT_DEVICE  = 'PC' THEN 2
            ELSE NULL
         END AS HVU_DEVICEID
        ,INTEGER(MNT_EMAILID) AS HVU_EMAILID--新着メルマガは過去EMAILIDがついていなかった時期があるためNULLを除く条件は入れられない
        ,MNT_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(MNT_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            MNTB_VISITTIME AS MNT_VISITTIME
            ,MNTB_SENDDT AS MNT_SENDDT
            ,MNTB_SOURCE AS MNT_SOURCE
            ,LEFT(MNTB_DEVICE, 2) AS MNT_DEVICE
            ,SUBSTR(MNTB_EMAILID, 13) AS MNT_EMAILID
            ,MNTB_FULLVISITORID AS MNT_FULLVISITORID
            ,MNTB_REVENUE AS MNT_REVENUE
            ,MNTB_DATE AS MNT_DATE
        FROM (
            SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MNTB_VISITTIME
                ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MNTB_SENDDT
                ,TRAFFICSOURCE.SOURCE AS MNTB_SOURCE
                ,NTH(2, SPLIT(UPPER(TRAFFICSOURCE.CAMPAIGN), '_')) AS MNTB_DEVICE
                ,NTH(1, SPLIT(TRAFFICSOURCE.CAMPAIGN, '_')) AS MNTB_EMAILID
                ,FULLVISITORID AS MNTB_FULLVISITORID
                ,TOTALS.TOTALTRANSACTIONREVENUE AS MNTB_REVENUE
                ,DATE AS MNTB_DATE
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                TRAFFICSOURCE.MEDIUM = 'mailmag'
                AND TRAFFICSOURCE.SOURCE = 'ni_m'--CHANNELIDとCHANNELDETAILIDではTOWN/USEDの区別がつかないためベタ書き
        ) AS MAIL_NEWARRIVAL_TOWN_BASE/*PREFIX = MNTB*/
    ) AS MAIL_NEWARRIVAL_TOWN/*PREFIX = MNT*/
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON MNT_SOURCE = MPM_PARAMETER
    WHERE
        MNT_DEVICE IN ('PC', 'MO')
        AND REGEXP_MATCH(MNT_EMAILID, R'^[0-9]{1,}')
        AND DATEDIFF(MNT_DATE, MNT_SENDDT) >= 0
        AND DATEDIFF(MNT_DATE, MNT_SENDDT) <= 7--配信から7日以内の流入に絞る
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