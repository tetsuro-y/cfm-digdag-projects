BEGIN
;

--過去8日分のデータを削除(洗い替える)
DELETE FROM TAT_DB_RESULT_MASSMAIL
WHERE RMM_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS' OR RMM_SENDDT < DATE_TRUNC('MONTH','${pd_base_date}'::DATE + INTERVAL '-25MONTHS')
;
-------------------------------
--マスメールの集計結果をINSERT
-------------------------------
INSERT INTO TAT_DB_RESULT_MASSMAIL
SELECT
    CAMPAIGN_SEND
    ,SENDDT_SEND
    ,CNT_SEND_TOTAL
    ,CNT_SEND_PC
    ,CNT_SEND_MO
    ,CNT_OPEN
    ,CASE
         WHEN CNT_SEND_TOTAL > 0 THEN ROUND((CNT_OPEN * 1.0 / CNT_SEND_PC * 1.0) * 100, 2)
         ELSE 0
     END AS CNT_OPEN_PER    --開封率_PC
    ,NVL(CNT_CLICK_TOTAL, 0) AS CNT_CLICK_TOTAL
    ,NVL(CNT_CLICK_PC, 0) AS CNT_CLICK_PC
    ,NVL(CNT_CLICK_MO, 0) AS CNT_CLICK_MO
    ,NVL(CASE
         WHEN CNT_OPEN > 0 THEN ROUND((CNT_CLICK_PC * 1.0 / CNT_OPEN * 1.0) * 100, 2)
         ELSE 0
     END, 0) AS OPEN_CLICK_PER_PC    --開封流入率_PC
    ,NVL(CASE
         WHEN CNT_SEND_MO > 0 THEN ROUND((CNT_CLICK_MO * 1.0 / CNT_SEND_MO * 1.0) * 100, 2)
         ELSE 0
     END, 0) AS SEND_CLICK_PER_MO    --配信流入率_MO
    ,NVL(REVENUE_TOTAL, 0) AS REVENUE_TOTAL
    ,NVL(REVENUE_PC, 0) AS REVENUE_PC
    ,NVL(REVENUE_MO, 0) AS REVENUE_MO
FROM (
    SELECT
        CAMPAIGN_SEND       --キャンペーンID
        ,SENDDT_SEND        --配信日
        ,CNT_SEND_TOTAL     --配信数_全体
        ,CNT_SEND_PC        --配信数_PC
        ,CNT_SEND_MO        --配信数_MO
        ,CNT_OPEN           --開封数
        ,CNT_CLICK_TOTAL    --流入数_全体
        ,CNT_CLICK_PC       --流入数_PC
        ,CNT_CLICK_MO       --流入数_MO
        ,REVENUE_TOTAL      --経由売上_全体
        ,REVENUE_PC         --経由売上_PC
        ,REVENUE_MO         --経由売上_MO
    FROM
        (
            ----------------
            --配信数・開封数
            ----------------
            SELECT
                DATE_TRUNC('DAY', DELIVERYDT) AS SENDDT_SEND
                ,MPM_MAPPINGID AS CAMPAIGN_SEND
                ,COUNT(1) AS CNT_SEND_TOTAL
                ,COUNT(CASE WHEN MMD.MOBILEFLAG = 0 THEN MMDD.EMAILID ELSE NULL END) AS CNT_SEND_PC
                ,COUNT(CASE WHEN MMD.MOBILEFLAG = 1 THEN MMDD.EMAILID ELSE NULL END) AS CNT_SEND_MO
                ,COUNT(CASE WHEN MMD.MOBILEFLAG = 0 THEN OPENDT ELSE NULL END) AS CNT_OPEN
            FROM
                (
                    SELECT
                        ARTICLEID
                        ,MAILMAGCAMPAIGNID
                        ,MOBILEFLAG
                        ,DRAFTID
                        ,DELIVERYDT
                        ,UTMSOURCE
                    FROM
                        TUCMAILMAGDELIVERY
                    WHERE
                        DELIVERYDT >= CAST('${pd_base_date}' AS TIMESTAMP) + INTERVAL '-8DAYS'
                        AND DELIVERYDT < CAST('${pd_base_date}' AS TIMESTAMP)
                        AND MAILMAGCAMPAIGNID NOT IN(9000, 9010)
                ) AS MMD
                INNER JOIN TUCMAILMAGDELIVERYDETAIL AS MMDD ON MMD.ARTICLEID = MMDD.ARTICLEID
                INNER JOIN (
                    SELECT
                        MPM_CHANNELID
                        ,MPM_CHANNEL_DETAILID
                        ,MPM_PARAMETER
                        ,MPM_MAPPINGID
                    FROM
                        TAT_DB_MASTER_PARAMETER_MAPPING
                    WHERE
                        MPM_CHANNELID = 1
                        AND MPM_CHANNEL_DETAILID = 2
                ) AS MPM ON UTMSOURCE = MPM_PARAMETER
            WHERE
                DELIVERYDT >= CAST('${pd_base_date}' AS TIMESTAMP) + INTERVAL '-8DAYS'
                AND DELIVERYDT < CAST('${pd_base_date}' AS TIMESTAMP)
                AND MAILMAGCAMPAIGNID NOT IN(9000, 9010)
            GROUP BY
                SENDDT_SEND
                ,CAMPAIGN_SEND
        ) AS SEND_TEMP
        LEFT JOIN(
            ------------------
            --流入数・経由売上
            ------------------
            SELECT
                DATE_TRUNC('DAY', HVU_SENDDT) AS SENDDT_CLICK
                ,HVU_CAMPAIGNID AS CAMPAIGN_CLICK
                ,COUNT(DISTINCT CASE WHEN HVU_DEVICEID <> 99 THEN HVU_FULLVISITORID ELSE NULL END) AS CNT_CLICK_TOTAL
                ,COUNT(DISTINCT CASE WHEN HVU_DEVICEID = 2 THEN HVU_FULLVISITORID ELSE NULL END) AS CNT_CLICK_PC
                ,COUNT(DISTINCT CASE WHEN HVU_DEVICEID = 1 THEN HVU_FULLVISITORID ELSE NULL END) AS CNT_CLICK_MO
                ,SUM(CASE WHEN HVU_DEVICEID <> 99 THEN HVU_REVENUE ELSE NULL END) AS REVENUE_TOTAL
                ,SUM(CASE WHEN HVU_DEVICEID = 2 THEN HVU_REVENUE ELSE 0 END) AS REVENUE_PC
                ,SUM(CASE WHEN HVU_DEVICEID = 1 THEN HVU_REVENUE ELSE 0 END) AS REVENUE_MO
            FROM
                TAT_DB_HISTORY_VISIT_USER
            WHERE
                HVU_SENDDT >= CAST('${pd_base_date}' AS TIMESTAMP) + INTERVAL '-8DAYS'
                AND HVU_SENDDT < CAST('${pd_base_date}' AS TIMESTAMP)
                AND HVU_CHANNELID = 1
                AND HVU_CHANNEL_DETAILID = 2
            GROUP BY
                HVU_SENDDT
                ,HVU_CAMPAIGNID
        ) AS CLICK_TEMP ON SENDDT_SEND = SENDDT_CLICK AND CAMPAIGN_SEND = CAMPAIGN_CLICK
    ) AS MASS_MAIL
;

COMMIT
;
