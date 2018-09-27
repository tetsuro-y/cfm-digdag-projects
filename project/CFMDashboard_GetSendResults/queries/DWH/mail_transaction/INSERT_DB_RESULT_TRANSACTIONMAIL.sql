BEGIN
;

CREATE TEMP TABLE TAT_DB_TRANSACTION_TMP_MEMBER
(
    TM_EMAILID INTEGER,
    TM_MOBILEFLAG BYTEINT
)
DISTRIBUTE ON (TM_EMAILID)
;

--対象となる会員
INSERT INTO TAT_DB_TRANSACTION_TMP_MEMBER
SELECT
    MMEMAILID AS TM_EMAILID
    ,CASE
        WHEN RTRIM(MMEMAIL) LIKE '%docomo.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%ezweb.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%softbank.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%vodafone.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%disney.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%willcom.com'
            OR RTRIM(MMEMAIL) LIKE '%pdx.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%wcm.ne.jp'
            OR RTRIM(MMEMAIL) LIKE '%au.com'
            THEN 1 ELSE 0
     END AS TM_MOBILEFLAG
FROM
    TMEMBEREMAIL MM
    LEFT JOIN TMEMBER ME ON MM.MMMEMBERID = ME.MEMEMBERID
WHERE
    (ME.MEMALLID = 1 OR ME.MEMALLID IS NULL)
    AND MMMALLID = 1
;

--日次実績更新（日ごとの配信通数、開封通数、流入通数、経由売上）
DELETE FROM TAT_DB_RESULT_TRANSACTIONMAIL
WHERE RTR_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS' OR RTR_SENDDT < DATE_TRUNC('MONTH','${pd_base_date}'::DATE + INTERVAL '-25MONTHS');
;

INSERT INTO TAT_DB_RESULT_TRANSACTIONMAIL
SELECT
    DD_CAMPAIGNID                                         AS RTR_CAMPAIGNID
    ,DD_SENDDT                                            AS RTR_SENDDT
    ,DD_CNT_SEND_PC + DD_CNT_SEND_MO                      AS RTR_CNT_SEND_ALL
    ,DD_CNT_SEND_PC                                       AS RTR_CNT_SEND_PC
    ,DD_CNT_SEND_MO                                       AS RTR_CNT_SEND_MO
    ,DD_CNT_OPEN_PC                                       AS RTR_CNT_OPEN_PC
    ,ROUND(100.0 * DD_CNT_OPEN_PC / DD_CNT_SEND_PC, 2)    AS RTR_RATE_OPEN_PC
    ,NVL(VD_VISIT_TOTAL, 0)                               AS RTR_CNT_CLICK_ALL
    ,NULL                                                 AS RTR_CNT_CLICK_PC
    ,NULL                                                 AS RTR_CNT_CLICK_MO
    ,NVL(VD_CV_TOTAL, 0)                                  AS RTR_CNT_CV_ALL
    ,NULL                                                 AS RTR_CNT_CV_PC
    ,NULL                                                 AS RTR_CNT_CV_MO
    ,NULL                                                 AS RTR_RATE_CLICK_PER_OPEN_PC
    ,NULL                                                 AS RTR_RATE_CLICK_PER_SEND_MO
    ,ROUND(100.0 * VD_CV_TOTAL / VD_VISIT_TOTAL, 2)       AS RTR_RATE_CV_PER_CLICK_ALL
    ,NULL                                                 AS RTR_RATE_CV_PER_CLICK_PC
    ,NULL                                                 AS RTR_RATE_CV_PER_CLICK_MO
    ,NVL(VD_REVENUE_TOTAL, 0)                             AS RTR_REVENUE_TOTAL_ALL
    ,NULL                                                 AS RTR_REVENUE_TOTAL_PC
    ,NULL                                                 AS RTR_REVENUE_TOTAL_MO
FROM (
    SELECT
        TD_CAMPAIGNID AS DD_CAMPAIGNID
        ,TD_SENDDT AS DD_SENDDT
        ,TD_CHANNELID AS DD_CHANNELID
        ,COUNT(CASE WHEN TD_MOBILEFLAG = 0 THEN NVL(TD_EMAILID, 0) ELSE NULL END) AS DD_CNT_SEND_PC
        ,COUNT(CASE WHEN TD_MOBILEFLAG = 1 THEN NVL(TD_EMAILID, 0) ELSE NULL END) AS DD_CNT_SEND_MO
        ,COUNT(CASE WHEN TD_OPENFLAG IS NOT NULL THEN NVL(TD_EMAILID, 0) ELSE NULL END) AS DD_CNT_OPEN_PC
    FROM (
        SELECT
            CAST(TMDTRANSACTIONTYPE AS INTEGER) AS TD_CAMPAIGNID
            ,TMDMEMBERID AS TD_MEMBERID
            ,TMDEMAILID AS TD_EMAILID
            ,1 AS TD_CHANNELID
            ,TM_MOBILEFLAG AS TD_MOBILEFLAG
            ,TO_DATE(TMDCONTACTDT, 'YYYYMMDD') AS TD_SENDDT
            ,TMDOPENFLAG AS TD_OPENFLAG
        FROM
            TTRNEMAILDELIVERY
            INNER JOIN TAT_DB_TRANSACTION_TMP_MEMBER /* PREFIX=TM */ ON TMDEMAILID = TM_EMAILID
        WHERE
            TMDCONTACTDT::DATE >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND TMDCONTACTDT::DATE < '${pd_base_date}'::DATE
            AND TMDMALLID = 1
            AND TMDCONTACTDT IS NOT NULL
    ) AS BASE
    GROUP BY
        DD_CAMPAIGNID
        ,DD_SENDDT
        ,DD_CHANNELID
    ) AS DELIVERYDATA/*PREFIX = DD*/
    LEFT OUTER JOIN (
        SELECT
            HVU_SENDDT AS VD_SENDDT
            ,HVU_CAMPAIGNID AS VD_CAMPAIGNID
            ,HVU_CHANNELID AS VD_CHANNELID
            ,COUNT(HVU_FULLVISITORID) AS VD_VISIT_TOTAL
            ,COUNT(HVU_FULLVISITORID_CV) AS VD_CV_TOTAL
            ,SUM(HVU_REVENUE) AS VD_REVENUE_TOTAL
        FROM
            TAT_DB_HISTORY_VISIT_USER
        WHERE
            HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND HVU_CHANNELID = 1--メール
            AND HVU_CHANNEL_DETAILID = 3--トランザクション
            AND HVU_VISITTIME >= HVU_SENDDT::TIMESTAMP
        GROUP BY
            VD_SENDDT
            ,VD_CAMPAIGNID
            ,VD_CHANNELID
    ) AS VISITDATA /*PREFIX = VD*/ ON DD_SENDDT = VD_SENDDT
                            AND DD_CAMPAIGNID = VD_CAMPAIGNID
                            AND DD_CHANNELID = VD_CHANNELID
;

COMMIT
;