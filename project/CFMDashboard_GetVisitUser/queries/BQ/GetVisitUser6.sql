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
        ,PM_MAPPINGID AS VC_CAMPAIGNID
        ,SNW_FULLVISITORID AS VC_FULLVISITORID
        ,SUM(INTEGER(NVL(SNW_REVENUE/1000000, 0))) AS VC_REVENUE
    FROM (
        SELECT
            FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS SNW_VISITTIME
            ,REGEXP_REPLACE(HITS.EVENTINFO.EVENTLABEL, R'!.*', '') AS SNW_EVENTLABEL--PPOSの可変部分を削除するため(EX)【24時間限定】あなただけのタイムセール実施中!(9月25日11：59まで))
            ,FULLVISITORID AS SNW_FULLVISITORID
            ,TOTALS.TOTALTRANSACTIONREVENUE AS SNW_REVENUE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('2017-11-21'), TIMESTAMP('2017-11-21'))--TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            HITS.EVENTINFO.EVENTCATEGORY = 'notice'
            --不審なデータを除外するため
            AND (REGEXP_MATCH(HITS.EVENTINFO.EVENTLABEL, R'ます|ました') OR REGEXP_MATCH(HITS.EVENTINFO.EVENTLABEL, R'あなただけの'))
            AND REGEXP_MATCH(HITS.EVENTINFO.EVENTLABEL, R'/') IS FALSE
            AND REGEXP_MATCH(HITS.EVENTINFO.EVENTLABEL, R'(數|殘|點)') IS FALSE
        GROUP EACH BY
            SNW_VISITTIME
            ,SNW_EVENTLABEL
            ,SNW_FULLVISITORID
            ,SNW_REVENUE
        ) AS SITENOTICE_WEB/*PREFIX = SNW*/
        INNER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON SNW_EVENTLABEL = PM_PARAMETER
    WHERE
		PM_CHANNEL = 4--サイトお知らせ(WEB)
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
        ,PM_MAPPINGID AS VC_CAMPAIGNID
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
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS SNA_VISITTIME
                ,HITS.EVENTINFO.EVENTLABEL AS SNA_EVENTLABEL
                ,1 AS SNA_OS
                ,FULLVISITORID AS SNA_FULLVISITORID
            FROM
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('2017-11-21'), TIMESTAMP('2017-11-21'))--TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                HITS.EVENTINFO.EVENTCATEGORY = 'notice'
            GROUP EACH BY
                SNA_VISITTIME
                ,SNA_EVENTLABEL
                ,SNA_FULLVISITORID),
            --Android
            (SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS SNA_VISITTIME
                ,HITS.EVENTINFO.EVENTLABEL AS SNA_EVENTLABEL
                ,2 AS SNA_OS
                ,FULLVISITORID AS SNA_FULLVISITORID
            FROM
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('2017-11-21'), TIMESTAMP('2017-11-21'))--TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                HITS.EVENTINFO.EVENTCATEGORY = 'notice'
            GROUP EACH BY
                SNA_VISITTIME
                ,SNA_EVENTLABEL
                ,SNA_FULLVISITORID)
        ) AS SITENOTICE_APP/*PREFIX = SNA*/
        INNER JOIN [durable-binder-547:ZZ_CFM.TAT_PARAMETERMAPPING] AS MAPPING_TABLE ON SNA_EVENTLABEL = PM_PARAMETER
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