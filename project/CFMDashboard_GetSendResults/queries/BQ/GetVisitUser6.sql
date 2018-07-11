SELECT
    NULL AS HVU_SENDDT
    ,HVU_CHANNELID
    ,HVU_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID
    ,NULL AS HVU_DEVICEID
    ,HVU_OSID
    ,HVU_FULLVISITORID
    ,NULL AS HVU_EMAILID
    ,NULL AS HVU_OFFERID
    ,STRFTIME_UTC_USEC(HVU_VISITTIME, "%Y/%m/%d %H:%M:%S") AS HVU_VISITTIME
    ,HVU_FULLVISITORID_CV
    ,HVU_REVENUE
FROM
    --サイトお知らせ_WEB
    (
    SELECT
        AD_VISITTIME AS HVU_VISITTIME
        ,AD_CHANNELID AS HVU_CHANNELID
        ,AD_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,AD_CAMPAIGNID AS HVU_CAMPAIGNID
        ,AD_FULLVISITORID AS HVU_FULLVISITORID
        ,CASE WHEN CD_FULLVISITORID IS NOT NULL THEN AD_FULLVISITORID ELSE NULL END AS HVU_FULLVISITORID_CV
        ,SUM(INTEGER(NVL(AD_REVENUE/1000000, 0))) AS HVU_REVENUE
    FROM (
        SELECT
            SNW_VISITTIME AS AD_VISITTIME
            ,MPM_CHANNELID AS AD_CHANNELID
            ,MPM_CHANNEL_DETAILID AS AD_CHANNEL_DETAILID
            ,MPM_MAPPINGID AS AD_CAMPAIGNID
            ,SNW_FULLVISITORID AS AD_FULLVISITORID
            ,SNW_VISITID AS AD_VISITID
            ,SNW_REVENUE AS AD_REVENUE
        FROM (
            SELECT
                FORMAT_UTC_USEC(VISITSTARTTIME * 1000000 + 32400000000) AS SNW_VISITTIME
                ,REGEXP_REPLACE(HITS.EVENTINFO.EVENTLABEL, R'!.*', '') AS SNW_EVENTLABEL--PPOSの可変部分を削除するため(EX)【24時間限定】あなただけのタイムセール実施中!(9月25日11：59まで))
                ,FULLVISITORID AS SNW_FULLVISITORID
                ,TOTALS.TOTALTRANSACTIONREVENUE AS SNW_REVENUE
                ,VISITID AS SNW_VISITID
            FROM
                TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
                ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
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
                ,SNW_VISITID
            ) AS SITENOTICE_WEB/*PREFIX = SNW*/
            INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON SNW_EVENTLABEL = MPM_PARAMETER
        WHERE
            MPM_CHANNELID = 4--サイトお知らせ(WEB)
    ) AS ACCESSDATA/*PREFIX=AD*/
    LEFT OUTER JOIN (
        SELECT
            FULLVISITORID AS CD_FULLVISITORID
            ,VISITID AS CD_VISITID
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            ,TABLE_DATE_RANGE([89629218.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
        WHERE
            TRAFFICSOURCE.SOURCE NOT IN ('ios', 'android')
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/app/') IS FALSE
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/sp/.*\?app=1') IS FALSE
            AND REGEXP_MATCH(HITS.PAGE.PAGEPATH, R'^zozo\.jp/(sp/)*_cart/(order/|shopping/)arigato\.html') --ARIGATOページ
        GROUP EACH BY
            CD_FULLVISITORID
            ,CD_VISITID
    ) AS CVDATA /*PREFIX=CD*/ ON AD_FULLVISITORID = CD_FULLVISITORID AND AD_VISITID = CD_VISITID
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_FULLVISITORID
        ,HVU_FULLVISITORID_CV
    ),
    --サイトお知らせ_アプリ
    (
    SELECT
        SNA_VISITTIME AS HVU_VISITTIME
        ,MPM_CHANNELID AS HVU_CHANNELID
        ,MPM_CHANNEL_DETAILID AS HVU_CHANNEL_DETAILID
        ,MPM_MAPPINGID AS HVU_CAMPAIGNID
        ,SNA_OS AS HVU_OSID
        ,SNA_FULLVISITORID AS HVU_FULLVISITORID
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
                TABLE_DATE_RANGE([90402834.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
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
                TABLE_DATE_RANGE([90303901.ga_sessions_],TIMESTAMP('${ga_start_date}'), TIMESTAMP('${ga_end_date}'))
            WHERE
                HITS.EVENTINFO.EVENTCATEGORY = 'notice'
            GROUP EACH BY
                SNA_VISITTIME
                ,SNA_EVENTLABEL
                ,SNA_FULLVISITORID)
        ) AS SITENOTICE_APP/*PREFIX = SNA*/
        INNER JOIN [durable-binder-547:ZZ_CFM.TAT_DB_MASTER_PARAMETER_MAPPING] AS MAPPING_TABLE ON SNA_EVENTLABEL = MPM_PARAMETER
    WHERE
		MPM_CHANNELID = 5
    GROUP EACH BY
        HVU_VISITTIME
        ,HVU_CHANNELID
        ,HVU_CHANNEL_DETAILID
        ,HVU_CAMPAIGNID
        ,HVU_OSID
        ,HVU_FULLVISITORID
    )