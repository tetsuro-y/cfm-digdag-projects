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
    ,NULL AS HVU_EMAILID
    ,HVU_OFFERID
    ,STRFTIME_UTC_USEC(HVU_VISITTIME, "%Y/%m/%d %H:%M:%S") AS HVU_VISITTIME
    ,HVU_REVENUE
FROM
    --Pメール_2.0
    (
    SELECT
        MPO_VISITTIME AS HVU_VISITTIME
        ,MPO_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,CASE
            WHEN MPO_DEVICE = 'MO' THEN 1
            WHEN MPO_DEVICE = 'PC' THEN 2
            ELSE 99
        END AS HVU_DEVICEID
        ,MPO_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(MPO_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            MPOB_VISITTIME AS MPO_VISITTIME
            ,MPOB_SENDDT AS MPO_SENDDT
            ,LEFT(MPOB_SOURCE, 10) AS MPO_SOURCE
            ,LEFT(MPOB_DEVICE, 2) AS MPO_DEVICE
            ,MPOB_FULLVISITORID AS MPO_FULLVISITORID
            ,MPOB_REVENUE AS MPO_REVENUE
            ,MPOB_DATE AS MPO_DATE
        FROM (
            SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MPOB_VISITTIME
                ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MPOB_SENDDT
                ,NTH(3, SPLIT(TRAFFICSOURCE.SOURCE, '_')) AS MPOB_SOURCE
                ,NTH(5, SPLIT(UPPER(TRAFFICSOURCE.SOURCE), '_')) AS MPOB_DEVICE
                ,FULLVISITORID AS MPOB_FULLVISITORID
                ,TOTALS.TOTALTRANSACTIONREVENUE AS MPOB_REVENUE
                ,DATE AS MPOB_DATE
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
                ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                TRAFFICSOURCE.MEDIUM = 'mailpersonal'
        ) AS MAIL_PERSONALIZE_OLD_BASE/*PREFIX = MPOB*/
    ) AS MAIL_PERSONALIZE_OLD/*PREFIX = MPO*/
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON MPO_SOURCE = MPM_PARAMETER
    WHERE
        MPM_CHANNELID = 1--メール
        AND MPM_CHANNEL_DETAILID = 4--パーソナライズ
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_DEVICEID
        ,HVU_FULLVISITORID
    ),
    --Pメール_3.0
    (
    SELECT
        MPN_VISITTIME AS HVU_VISITTIME
        ,MPN_SENDDT AS HVU_SENDDT
        ,1 AS HVU_CHANNELID--メール
        ,4 AS HVU_CHANNEL_DETAILID--パーソナライズ
        ,INTEGER(MPN_CAMPAIGNID) AS HVU_CAMPAIGNID
        ,CASE
            WHEN MPN_DEVICE IN ('1', '2')
                THEN INTEGER(MPN_DEVICE)
            ELSE 99
        END AS HVU_DEVICEID
        ,CASE
            WHEN REGEXP_MATCH(MPN_OFFERID, R'^[0-9]{1,}')
                THEN INTEGER(MPN_OFFERID)
            ELSE NULL
        END AS HVU_OFFERID
        ,MPN_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(MPN_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
    SELECT
        FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MPN_VISITTIME
        ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MPN_SENDDT
        ,NTH(3, SPLIT(TRAFFICSOURCE.SOURCE, '_')) AS MPN_CAMPAIGNID
        ,NTH(4, SPLIT(TRAFFICSOURCE.SOURCE, '_')) AS MPN_DEVICE
        ,NTH(2, SPLIT(TRAFFICSOURCE.CAMPAIGN, '_')) AS MPN_OFFERID
        ,FULLVISITORID AS MPN_FULLVISITORID
        ,TOTALS.TOTALTRANSACTIONREVENUE AS MPN_REVENUE
        ,DATE AS MPN_DATE
    FROM
        TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
    WHERE
        TRAFFICSOURCE.MEDIUM = 'mailpersonal'
    ) AS MAIL_PERSONALIZE_NEW/*PREFIX = MPN*/
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_DEVICEID
        ,HVU_OFFERID
        ,HVU_FULLVISITORID
    ),
    --トランザクションメール
    (
    SELECT
        MT_VISITTIME AS HVU_VISITTIME
        ,MT_SENDDT AS HVU_SENDDT
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,MT_FULLVISITORID AS HVU_FULLVISITORID
        ,SUM(INTEGER(NVL(MT_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS MT_VISITTIME
            ,LEFT(TRAFFICSOURCE.CAMPAIGN, 8) AS MT_SENDDT
            ,TRAFFICSOURCE.SOURCE AS MT_SOURCE
            ,FULLVISITORID AS MT_FULLVISITORID
            ,TOTALS.TOTALTRANSACTIONREVENUE AS MT_REVENUE
            ,DATE AS MT_DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
    ) AS MAIL_TRANSACTION/*PREFIX = MT*/
    INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON MT_SOURCE = MPM_PARAMETER
    WHERE
        MPM_CHANNELID = 1--メール
        AND MPM_CHANNEL_DETAILID = 3--トランザクション
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_SENDDT
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_FULLVISITORID
    )