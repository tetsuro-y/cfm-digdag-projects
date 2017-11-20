SELECT
    STRFTIME_UTC_USEC(VC_VISITTIME, "%Y/%m/%d %H:%M:%S") AS VC_VISITTIME
    ,NULL AS VC_SENDDT
    ,VC_CHANNEL
    ,VC_CHANNEL_DETAIL
    ,VC_CAMPAIGNID
    ,NULL AS VC_DEVICE
    ,VC_OS
    ,NULL AS VC_EMAILID
    ,NULL AS VC_OFFERID
    ,VC_FULLVISITORID
    ,VC_REVENUE
FROM
    --サイトお知らせ_WEB
    (
    SELECT
        SNW_VISITTIME AS VC_VISITTIME
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,SNW_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(SNW_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS SNW_VISITTIME
            ,REGEXP_REPLACE(hits.eventInfo.eventLabel, r'!.*', '') AS SNW_EVENTLABEL--PPOSの可変部分を削除するため
            ,FULLVISITORID AS SNW_FULLVISITORID
            ,totals.totalTransactionRevenue AS SNW_REVENUE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
        WHERE
            hits.eventInfo.eventCategory = 'notice'
            --不審なデータを除外するため
            AND REGEXP_MATCH(hits.eventInfo.eventLabel,'ます|ました')
            AND REGEXP_MATCH(hits.eventInfo.eventLabel,'./*./') IS FALSE
            AND REGEXP_MATCH(hits.eventInfo.eventLabel,'./*(數|殘|點)') IS FALSE
        GROUP EACH BY
            SNW_VISITTIME
            ,SNW_EVENTLABEL
            ,SNW_FULLVISITORID
            ,SNW_REVENUE
        ) AS SITENOTICE_WEB/*PREFIX = SNW*/
        LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON SNW_EVENTLABEL = PM_PARAMETER
    WHERE
		PM_CHANNEL = 4
    GROUP EACH BY
        VC_VISITTIME
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_FULLVISITORID
    ),
    --サイトお知らせ_アプリ
    (
    SELECT
        SNA_VISITTIME AS VC_VISITTIME
        ,PM_CHANNEL AS VC_CHANNEL
        ,PM_CHANNEL_DETAIL AS VC_CHANNEL_DETAIL
        ,CASE
            WHEN PM_PARAMETER IS NOT NULL THEN PM_MAPPINGID
            ELSE NULL
        END AS VC_CAMPAIGNID
        ,SNA_OS AS VC_OS
        ,SNA_FULLVISITORID AS VC_FULLVISITORID
    FROM (
        SELECT
            SNA_VISITTIME
            ,SNA_EVENTLABEL
            ,SNA_OS
            ,SNA_FULLVISITORID
        FROM
            --iOS
            (SELECT
                FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS SNA_VISITTIME
                ,hits.eventInfo.eventLabel AS SNA_EVENTLABEL
                ,1 AS SNA_OS
                ,FULLVISITORID AS SNA_FULLVISITORID
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
            WHERE
                hits.eventInfo.eventCategory = 'notice'
            GROUP EACH BY
                SNA_VISITTIME
                ,SNA_EVENTLABEL
                ,SNA_FULLVISITORID),
            --Android
            (SELECT
                FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS SNA_VISITTIME
                ,hits.eventInfo.eventLabel AS SNA_EVENTLABEL
                ,2 AS SNA_OS
                ,FULLVISITORID AS SNA_FULLVISITORID
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],DATE_ADD(CURRENT_DATE(), -7, 'DAY'), DATE_ADD(CURRENT_DATE(), -1, 'DAY'))
            WHERE
                hits.eventInfo.eventCategory = 'notice'
            GROUP EACH BY
                SNA_VISITTIME
                ,SNA_EVENTLABEL
                ,SNA_FULLVISITORID)
        ) AS SITENOTICE_APP/*PREFIX = SNA*/
        LEFT OUTER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON SNA_EVENTLABEL = PM_PARAMETER
    WHERE
		PM_CHANNEL = 5
    GROUP EACH BY
        VC_VISITTIME
        ,VC_CHANNEL
        ,VC_CHANNEL_DETAIL
        ,VC_CAMPAIGNID
        ,VC_OS
        ,VC_FULLVISITORID
    )