BEGIN
;
/* PUSH 配信実績過去データ分の登録 */
CREATE TEMP TABLE TAT_DB_RESULT_PUSH_TMP_TERM AS
SELECT
    '20151101' AS TT_STARTDT
    ,'20180331' AS TT_ENDDT
;

/* 配信数の集計 */
/* PUSHTYPECATEGORYID単位の配信数を取得 */
CREATE TEMP TABLE TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
(
    TPSP_SENDDT DATE
    ,TPSP_OSID BYTEINT
    ,TPSP_PUSHTYPECATEGORYID BYTEINT
    ,TPSP_CNT_SEND INTEGER
)
DISTRIBUTE ON (TPSP_SENDDT, TPSP_OSID, TPSP_PUSHTYPECATEGORYID, TPSP_CNT_SEND)
;

INSERT INTO TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
SELECT
    EMS_SENDDT
    ,EMS_DEVICETYPEID
    ,EMS_PUSHTYPECATEGORYID
    ,NVL(EMS_CNT_SEND, 0) + NVL(NEMS_CNT_SEND, 0) /* MEMBERIDが存在しないデータ・存在するデータの合算 */
FROM (
    /* MEMBERIDが存在する配信データ */
    SELECT
        DATE_TRUNC('DAY', CONTACTDT) AS EMS_SENDDT
        ,PNDEVICETYPEID AS EMS_DEVICETYPEID
        ,PUSHTYPECATEGORYID AS EMS_PUSHTYPECATEGORYID
        ,COUNT(PNDEVICETYPEID) AS EMS_CNT_SEND
    FROM
        TPNPUSHAPPHISTORY
    INNER JOIN TPUSHNOTIFICATION ON PUSHNOTIFICATIONID = PNPUSHNOTIFICATIONID
    WHERE
        CONTACTDT >= (SELECT TT_STARTDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
        AND CONTACTDT < (SELECT TT_ENDDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
        AND PUSHTYPECATEGORYID IN (1, 2, 3, 6)  /* パーソナライズ、新着おまとめ、新着リアルタイム、マス */
        AND PUSHNOTIFICATIONID IN (
                /* https://paper.dropbox.com/doc/SQL-0SOkloZHInKaefYHUPxal
                 アプリのインストール・アンインストールを繰り返す等した場合1ユーザに対して複数レコードが存在し、
                 結果配信数が実際よりも多く計上されてしまう例があるため下記条件を記載してユーザを一意にする */
                SELECT UQPUSHNOTIFICATIONID
                FROM (
                        SELECT
                            PNPUSHNOTIFICATIONID AS UQPUSHNOTIFICATIONID
                            ,ROW_NUMBER() OVER (PARTITION BY PNMEMBERID ORDER BY PNMODIFYDT DESC) AS ROWNUMBER /* 最新のMODIFYDTのレコードを正とするため */
                        FROM
                            TPUSHNOTIFICATION
                    ) AS GETROWNUM
                WHERE
                    ROWNUMBER = 1
        )
    GROUP BY 
        EMS_SENDDT
        ,EMS_PUSHTYPECATEGORYID
        ,EMS_DEVICETYPEID
) AS EXIST_MEMBER_SEND /*PREFIX = EMS */
LEFT JOIN (
    /* MEMBERIDが存在しない配信データ */
    SELECT
        DATE_TRUNC('DAY', CONTACTDT) AS NEMS_SENDDT
        ,PNDEVICETYPEID AS NEMS_DEVICETYPEID
        ,PUSHTYPECATEGORYID AS MEMS_PUSHTYPECATEGORYID
        ,COUNT(PNDEVICETYPEID) AS NEMS_CNT_SEND
    FROM 
        TPNPUSHAPPHISTORY
    INNER JOIN TPUSHNOTIFICATION ON PUSHNOTIFICATIONID = PNPUSHNOTIFICATIONID
    WHERE
        CONTACTDT >= (SELECT TT_STARTDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
        AND CONTACTDT < (SELECT TT_ENDDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
        AND PUSHTYPECATEGORYID IN (1, 2, 3, 6)  /* 1:パーソナライズ、2:新着おまとめ、3:新着リアルタイム、6:マス */
        AND MEMBERID IS NULL
    GROUP BY 
        NEMS_SENDDT
        ,MEMS_PUSHTYPECATEGORYID
        ,NEMS_DEVICETYPEID
) AS NOT_EXIST_MEMBER_SEND /*PREFIX = NEMS */ 
    ON EMS_SENDDT = NEMS_SENDDT
    AND EMS_PUSHTYPECATEGORYID = MEMS_PUSHTYPECATEGORYID
    AND EMS_DEVICETYPEID = NEMS_DEVICETYPEID
;

/* 流入数の集計 */
/* CAMPAIGNID, CHANNEL_DETAILIDごとの流入数を集計 */
CREATE TEMP TABLE TAT_DB_RESULT_TMP_PUSH_CLICK_CAMPAIGN
(
    TPCC_CLICKDT DATE
    ,TPCC_OSID BYTEINT
    ,TPCC_CAMPAIGNID INTEGER
    ,TPCC_CHANNEL_DETAILID BYTEINT
    ,TPCC_CNT_CLICK INTEGER
    ,TPCC_REVENUE INTEGER
    ,TPCC_CNT_CAMPAIGN INTEGER
)
DISTRIBUTE ON (TPCC_CLICKDT, TPCC_OSID, TPCC_CAMPAIGNID, TPCC_CHANNEL_DETAILID)
;

INSERT INTO TAT_DB_RESULT_TMP_PUSH_CLICK_CAMPAIGN
SELECT
    CC_CLICKDT
    ,CC_OSID
    ,CC_CAMPAIGNID
    ,CC_CHANNEL_DETAILID
    ,NVL(CC_CNT_CLICK, 0)
    ,NVL(CC_REVENUE, 0)
    ,CCN_CNT_CAMPAIGN
FROM (
    SELECT 
        DATE_TRUNC('DAY', HVU_SENDDT) AS CC_CLICKDT
        ,HVU_OSID AS CC_OSID
        ,HVU_CAMPAIGNID AS CC_CAMPAIGNID
        ,COUNT(HVU_OSID) AS CC_CNT_CLICK
        ,SUM(HVU_REVENUE) AS CC_REVENUE
        ,HVU_CHANNEL_DETAILID AS CC_CHANNEL_DETAILID
    FROM
        TAT_DB_HISTORY_VISIT_USER
    WHERE 
        HVU_CHANNELID = 3 /* PUSH */
        AND HVU_SENDDT >= (SELECT TT_STARTDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
        AND HVU_SENDDT < (SELECT TT_ENDDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
    GROUP BY
        CC_CLICKDT
        ,CC_OSID
        ,CC_CAMPAIGNID
        ,CC_CHANNEL_DETAILID
) AS CLICK_CNT /* PREFIX = CC */
INNER JOIN (
    /* 配信数をキャンペーン単位で割るために、対象日付のキャンペーン数を取得 */
    SELECT
        HVU_SENDDT AS CCN_SENDDT
        ,HVU_CHANNEL_DETAILID AS CCN_CHANNEL_DETAILID
        ,COUNT(DISTINCT HVU_CAMPAIGNID) AS CCN_CNT_CAMPAIGN
    FROM
        TAT_DB_HISTORY_VISIT_USER
    WHERE
        HVU_CHANNELID = 3 /* PUSH */
        AND HVU_SENDDT >= (SELECT TT_STARTDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
        AND HVU_SENDDT < (SELECT TT_ENDDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
    GROUP BY
        CCN_SENDDT
        ,CCN_CHANNEL_DETAILID
) AS CAMPAIGN_CNT /* PREFIX = CCN */
    ON CC_CLICKDT = CCN_SENDDT
    AND CC_CHANNEL_DETAILID = CCN_CHANNEL_DETAILID
;

/* マス・新着・パーソナライズPUSH 配信数,流入数, 経由売上 */
CREATE TEMP TABLE TAT_DB_RESULT_PUSH_TMP_SEND
(
    PTS_SENDDT DATE
    ,PTS_CHANNEL_DETAILID BYTEINT
    ,PTS_CAMPAIGNID INTEGER
    ,PTS_OSID BYTEINT
    ,PTS_CNT_SEND INTEGER
    ,PTS_CNT_CLICK INTEGER
    ,PTS_REVENUE INTEGER
)
DISTRIBUTE ON (PTS_SENDDT, PTS_CHANNEL_DETAILID, PTS_CAMPAIGNID, PTS_OSID)
;

/* マス  配信数,流入数, 経由売上 */
INSERT INTO TAT_DB_RESULT_PUSH_TMP_SEND
SELECT
    MSD_SENDDT
    ,MCD_CHANNEL_DETAILID
    ,MCD_CAMPAIGNID
    ,MSD_OSID
    ,ROUND(MSD_CNT_SEND / MCD_CNT_CAMPAIGN, 0) /* 配信数を当日のキャンペーン数で割る */
    ,MCD_CNT_CLICK
    ,MCD_REVENUE
FROM (
        SELECT
            TPSP_SENDDT AS MSD_SENDDT
            ,TPSP_OSID AS MSD_OSID
            ,TPSP_PUSHTYPECATEGORYID AS MSD_PUSHTYPECATEGORYID
            ,TPSP_CNT_SEND AS MSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 6 /* マス */
    ) AS MASS_SENDDATA /* PREFIX = MSD */
    INNER JOIN (
        SELECT
            TPCC_CLICKDT AS MCD_CLICKDT
            ,TPCC_OSID AS MCD_OSID
            ,TPCC_CAMPAIGNID AS MCD_CAMPAIGNID
            ,TPCC_CHANNEL_DETAILID AS MCD_CHANNEL_DETAILID
            ,TPCC_CNT_CLICK AS MCD_CNT_CLICK
            ,TPCC_REVENUE AS MCD_REVENUE
            ,TPCC_CNT_CAMPAIGN AS MCD_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_TMP_PUSH_CLICK_CAMPAIGN
        WHERE
            TPCC_CHANNEL_DETAILID = 2 /* マス */
    ) AS MASS_CLICKDATA /*PREFIX = MCD */
    ON MSD_SENDDT = MCD_CLICKDT
    AND MSD_OSID = MCD_OSID

UNION ALL

/* 新着おまとめ  配信数,流入数, 経由売上 */
SELECT
    NSSD_SENDDT
    ,NSCD_CHANNEL_DETAILID
    ,NSCD_CAMPAIGNID
    ,NSSD_OSID
    ,NSSD_CNT_SEND
    ,NSCD_CNT_CLICK
    ,NSCD_REVENUE
FROM (
        SELECT
            TPSP_SENDDT AS NSSD_SENDDT
            ,TPSP_OSID AS NSSD_OSID
            ,TPSP_PUSHTYPECATEGORYID AS NSSD_PUSHTYPECATEGORYID
            ,TPSP_CNT_SEND AS NSSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 2 /* 新着おまとめ */
    ) AS NEW_SUM_SENDDATA /* PREFIX = NSSD */
    INNER JOIN (
        SELECT
            TPCC_CLICKDT AS NSCD_CLICKDT
            ,TPCC_OSID AS NSCD_OSID
            ,TPCC_CAMPAIGNID AS NSCD_CAMPAIGNID
            ,TPCC_CHANNEL_DETAILID AS NSCD_CHANNEL_DETAILID
            ,TPCC_CNT_CLICK AS NSCD_CNT_CLICK
            ,TPCC_REVENUE AS NSCD_REVENUE
            ,TPCC_CNT_CAMPAIGN AS NSCD_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_TMP_PUSH_CLICK_CAMPAIGN
        WHERE
            TPCC_CHANNEL_DETAILID = 1 /* 新着 */
            AND TPCC_CAMPAIGNID = 1 /* 新着おまとめ */
    ) AS NEW_SUM_CLICKDATA /*PREFIX = NSCD */ 
    ON NSSD_SENDDT = NSCD_CLICKDT
    AND NSSD_OSID = NSCD_OSID

UNION ALL

/* 新着リアルタイム  配信数,流入数, 経由売上 */
SELECT
    NRSD_SENDDT
    ,NRCD_CHANNEL_DETAILID
    ,NRCD_CAMPAIGNID
    ,NRSD_OSID
    ,NRSD_CNT_SEND
    ,NRCD_CNT_CLICK
    ,NRCD_REVENUE
FROM (
        SELECT
            TPSP_SENDDT AS NRSD_SENDDT
            ,TPSP_OSID AS NRSD_OSID
            ,TPSP_PUSHTYPECATEGORYID AS NRSD_PUSHTYPECATEGORYID
            ,TPSP_CNT_SEND AS NRSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 3 /* 新着リアルタイム */
    ) AS NEW_REALTIME_SENDDATA /* PREFIX = NRSD */
    INNER JOIN (
        SELECT
            TPCC_CLICKDT AS NRCD_CLICKDT
            ,TPCC_OSID AS NRCD_OSID
            ,TPCC_CAMPAIGNID AS NRCD_CAMPAIGNID
            ,TPCC_CHANNEL_DETAILID AS NRCD_CHANNEL_DETAILID
            ,TPCC_CNT_CLICK AS NRCD_CNT_CLICK
            ,TPCC_REVENUE AS NRCD_REVENUE
            ,TPCC_CNT_CAMPAIGN AS NRCD_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_TMP_PUSH_CLICK_CAMPAIGN
        WHERE
            TPCC_CHANNEL_DETAILID = 1 /* 新着 */
            AND TPCC_CAMPAIGNID = 2 /* 新着リアルタイム */
    ) AS NEW_REALTIME_CLICKDATA /*PREFIX = NRCD */
    ON NRSD_SENDDT = NRCD_CLICKDT
    AND NRSD_OSID = NRCD_OSID

UNION ALL

/* パーソナライズPUSH  配信数,流入数, 経由売上 */
SELECT
    PSD_SENDDT
    ,PCD_CHANNEL_DETAILID
    ,PCD_CAMPAIGNID
    ,PSD_OSID
    ,ROUND(PSD_CNT_SEND / PCD_CNT_CAMPAIGN, 0) /* 配信数を当日のキャンペーン数で割る */
    ,PCD_CNT_CLICK
    ,PCD_REVENUE
FROM (
        SELECT
            TPSP_SENDDT AS PSD_SENDDT
            ,TPSP_OSID AS PSD_OSID
            ,TPSP_PUSHTYPECATEGORYID AS PSD_PUSHTYPECATEGORYID
            ,TPSP_CNT_SEND AS PSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 1 /* パーソナライズ */
    ) AS PERSONALIZE_SENDDATA /* PREFIX = PSD */
    INNER JOIN (
        SELECT
            TPCC_CLICKDT AS PCD_CLICKDT
            ,TPCC_OSID AS PCD_OSID
            ,TPCC_CAMPAIGNID AS PCD_CAMPAIGNID
            ,TPCC_CHANNEL_DETAILID AS PCD_CHANNEL_DETAILID
            ,TPCC_CNT_CLICK AS PCD_CNT_CLICK
            ,TPCC_REVENUE AS PCD_REVENUE
            ,TPCC_CNT_CAMPAIGN AS PCD_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_TMP_PUSH_CLICK_CAMPAIGN
        WHERE
            TPCC_CHANNEL_DETAILID = 4 /* パーソナライズ */
    ) AS PERSONALIZE_CLICKDATA /*PREFIX = PCD */
    ON PSD_SENDDT = PCD_CLICKDT
    AND PSD_OSID = PCD_OSID
;

/* 日次実績更新 */
DELETE
    FROM TAT_DB_RESULT_APPPUSH
WHERE
    RAP_SENDDT >= (SELECT TT_STARTDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
    OR RAP_SENDDT < (SELECT TT_ENDDT::DATE FROM TAT_DB_RESULT_PUSH_TMP_TERM)
;

INSERT INTO TAT_DB_RESULT_APPPUSH
/* 実績格納用テーブルに保存 */
SELECT 
    PSI_CHANNEL_DETAILID AS RAP_CHANNEL_DETAILID
    ,PSI_CAMPAIGNID AS RAP_CAMPAIGNID
    ,PSI_SENDDT AS RAP_SENDDT
    ,(PSI_CNT_SEND + PSA_CNT_SEND) AS RAP_CNT_SEND_ALL
    ,PSI_CNT_SEND AS RAP_CNT_SEND_IOS
    ,PSA_CNT_SEND AS RAP_CNT_SEND_ANDROID
    ,(PSI_CNT_CLICK + PSA_CNT_CLICK) AS RAP_CNT_CLICK_ALL
    ,PSI_CNT_CLICK AS RAP_CNT_CLICK_IOS
    ,PSA_CNT_CLICK AS RAP_CNT_CLICK_ANDROID
    ,ROUND(100.0 * RAP_CNT_CLICK_IOS / RAP_CNT_SEND_IOS, 2) AS RAP_RATE_CLICK_PER_SEND_IOS
    ,ROUND(100.0 * RAP_CNT_CLICK_ANDROID / RAP_CNT_SEND_ANDROID, 2) AS RAP_RATE_CLICK_PER_SEND_ANDROID
    ,PSI_REVENUE + PSA_REVENUE AS RAP_REVENUE_TOTAL_ALL
    ,PSI_REVENUE AS RAP_REVENUE_IOS
    ,PSA_REVENUE AS RAP_REVENUE_ANDROID
FROM (
    SELECT
        PTS_SENDDT AS PSI_SENDDT
        ,PTS_CHANNEL_DETAILID AS PSI_CHANNEL_DETAILID
        ,PTS_CAMPAIGNID AS PSI_CAMPAIGNID
        ,PTS_CNT_SEND AS PSI_CNT_SEND
        ,PTS_CNT_CLICK AS PSI_CNT_CLICK
        ,PTS_REVENUE AS PSI_REVENUE
    FROM
        TAT_DB_RESULT_PUSH_TMP_SEND
    WHERE
        PTS_OSID = 1 /* IOS */
) AS PUSH_SEND_IOS /* PREFIX = PSI */
INNER JOIN (
    SELECT
        PTS_SENDDT AS PSA_SENDDT
        ,PTS_CHANNEL_DETAILID AS PSA_CHANNEL_DETAILID
        ,PTS_CAMPAIGNID AS PSA_CAMPAIGNID
        ,PTS_CNT_SEND AS PSA_CNT_SEND
        ,PTS_CNT_CLICK AS PSA_CNT_CLICK
        ,PTS_REVENUE AS PSA_REVENUE
    FROM
        TAT_DB_RESULT_PUSH_TMP_SEND
    WHERE
        PTS_OSID = 2 /* Android */
) AS PUSH_SEND_ANDROID /* PREFIX = PSA */ 
    ON PSI_SENDDT = PSA_SENDDT
    AND PSI_CHANNEL_DETAILID = PSA_CHANNEL_DETAILID
    AND PSI_CAMPAIGNID = PSA_CAMPAIGNID
;

COMMIT
;