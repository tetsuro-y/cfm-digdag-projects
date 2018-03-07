BEGIN
;

/* 配信数の集計 */
/* PUSHTYPECATEGORYID単位の配信数を取得 */
CREATE TEMP TABLE TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
(
    TPSP_SENDDT DATE
    ,TPSP_OSID BYTEINT
    ,TPSP_PUSHTYPECATEGORYID BYTEINT
    ,TPSP_ITEMID INTEGER
    ,TPSP_CNT_SEND INTEGER
)
DISTRIBUTE ON (TPSP_SENDDT, TPSP_OSID, TPSP_PUSHTYPECATEGORYID, TPSP_ITEMID)
;

INSERT INTO TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
SELECT
    MS_SENDDT
    ,MS_DEVICETYPEID
    ,MS_PUSHTYPECATEGORYID
    ,MS_ITEMID
    ,SUM(MS_CNT_SEND) /* MEMBERIDが存在しないデータ・存在するデータの合算 */
FROM (
         /* MEMBERIDが存在する配信データ */
         SELECT
              DATE_TRUNC('DAY', CONTACTDT) AS MS_SENDDT
             ,PNDEVICETYPEID AS MS_DEVICETYPEID
             ,PUSHTYPECATEGORYID AS MS_PUSHTYPECATEGORYID
             ,ITEMID AS MS_ITEMID
             ,NVL(COUNT(PNDEVICETYPEID), 0) AS MS_CNT_SEND
         FROM
             TPNPUSHAPPHISTORY
             INNER JOIN TPUSHNOTIFICATION ON PUSHNOTIFICATIONID = PNPUSHNOTIFICATIONID
         WHERE
             CONTACTDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
             AND CONTACTDT < '${pd_base_date}'::DATE
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
             MS_SENDDT
             ,MS_PUSHTYPECATEGORYID
             ,MS_DEVICETYPEID
             ,MS_ITEMID

         UNION ALL

         /* MEMBERIDが存在しない配信データ */
         SELECT
              DATE_TRUNC('DAY', CONTACTDT) AS MS_SENDDT
             ,PNDEVICETYPEID AS MS_DEVICETYPEID
             ,PUSHTYPECATEGORYID AS MS_PUSHTYPECATEGORYID
             ,ITEMID AS MS_ITEMID
             ,NVL(COUNT(PNDEVICETYPEID), 0) AS MS_CNT_SEND
         FROM
             TPNPUSHAPPHISTORY
             INNER JOIN TPUSHNOTIFICATION ON PUSHNOTIFICATIONID = PNPUSHNOTIFICATIONID
         WHERE
             CONTACTDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
             AND CONTACTDT < '${pd_base_date}'::DATE
             AND PUSHTYPECATEGORYID IN (1, 2, 3, 6)  /* 1:パーソナライズ、2:新着おまとめ、3:新着リアルタイム、6:マス */
             AND MEMBERID IS NULL
         GROUP BY
             MS_SENDDT
             ,MS_PUSHTYPECATEGORYID
             ,MS_DEVICETYPEID
             ,MS_ITEMID
     ) AS MEMBER_SEND /*PREFIX = MS */
GROUP BY
    MS_SENDDT
    ,MS_DEVICETYPEID
    ,MS_PUSHTYPECATEGORYID
    ,MS_ITEMID		
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
        AND HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
        AND HVU_SENDDT < '${pd_base_date}'::DATE
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
        AND HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
        AND HVU_SENDDT < '${pd_base_date}'::DATE
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
            ,SUM(TPSP_CNT_SEND) AS MSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 6 /* マス */
        GROUP BY
            MSD_SENDDT
            ,MSD_OSID
            ,MSD_PUSHTYPECATEGORYID
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
            ,SUM(TPSP_CNT_SEND) AS NSSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 2 /* 新着おまとめ */
        GROUP BY
            NSSD_SENDDT
            ,NSSD_OSID
            ,NSSD_PUSHTYPECATEGORYID
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
            ,SUM(TPSP_CNT_SEND) AS NRSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
        WHERE
            TPSP_PUSHTYPECATEGORYID = 3 /* 新着リアルタイム */
        GROUP BY
            NRSD_SENDDT
            ,NRSD_OSID
            ,NRSD_PUSHTYPECATEGORYID
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
    ,PSD_CNT_SEND
    ,PCD_CNT_CLICK
    ,PCD_REVENUE
FROM (
        SELECT
            TPSP_SENDDT AS PSD_SENDDT
            ,TPSP_OSID AS PSD_OSID
            ,TPSP_PUSHTYPECATEGORYID AS PSD_PUSHTYPECATEGORYID
            ,CAG_CAMPAIGNID AS PSD_CAMPAIGNID
            ,SUM(TPSP_CNT_SEND) AS PSD_CNT_SEND
        FROM
            TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
            INNER JOIN (
                /* TPNNOTICEDELIVERYからCAMPAIGNIDの抽出 */
                SELECT DISTINCT
                    TPSP_ITEMID AS CAG_ITEMID
                    ,PNDCAMPAIGNID AS CAG_CAMPAIGNID
                FROM TAT_DB_RESULT_TMP_PUSH_SEND_PUSHTYPE
                INNER JOIN TPNNOTICEDELIVERY ON PNDSEQID = TPSP_ITEMID
                WHERE 
                TPSP_PUSHTYPECATEGORYID = 1
            ) AS CAMPAIGN_GROUP /*PREFIX = CAG */
            ON CAG_ITEMID = TPSP_ITEMID
        WHERE
            TPSP_PUSHTYPECATEGORYID = 1 /* パーソナライズ */
        GROUP BY
            PSD_SENDDT
            ,PSD_OSID
            ,PSD_PUSHTYPECATEGORYID
            ,PSD_CAMPAIGNID
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
    AND PSD_CAMPAIGNID = PCD_CAMPAIGNID
;

/* 時間帯別配信・流入実績 */

/* 時間帯別配信数 */
/* 集計対象期間に存在するPUSHTYPECATEGORYID, DEVICETYPEID,ITEMIDを集約 */
/* 配信実績が存在しない時間帯のデータも作成したいため */
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_SEND_TMP_GROUP
(
    HSTG_HOUR BYTEINT
    ,HSTG_PUSHTYPECATEGORYID BYTEINT
    ,HSTG_DEVICETYPEID BYTEINT
    ,HSTG_ITEMID INTEGER
)
DISTRIBUTE ON (HSTG_HOUR, HSTG_PUSHTYPECATEGORYID, HSTG_DEVICETYPEID, HSTG_ITEMID)
;

INSERT INTO TAT_DB_RESULT_HOURLY_SEND_TMP_GROUP
SELECT
    MDH_HOUR AS HSTG_HOUR
    ,CG_PUSHTYPECATEGORYID AS CG_PUSHTYPECATEGORYID
    ,CG_DEVICETYPEID AS HSTG_DEVICETYPEID
    ,CG_ITEMID AS HSTG_ITEMID
FROM (
        SELECT
            PUSHTYPECATEGORYID AS CG_PUSHTYPECATEGORYID
            ,PNDEVICETYPEID AS CG_DEVICETYPEID
            ,ITEMID AS CG_ITEMID
        FROM 
            TPNPUSHAPPHISTORY
        INNER JOIN TPUSHNOTIFICATION ON PUSHNOTIFICATIONID = PNPUSHNOTIFICATIONID
        WHERE
            CONTACTDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND CONTACTDT < '${pd_base_date}'::DATE
            AND PUSHTYPECATEGORYID IN (1, 2, 3, 6)  /* 1:パーソナライズ、2:新着おまとめ、3:新着リアルタイム、6:マス */
        GROUP BY
            CG_PUSHTYPECATEGORYID
            ,CG_DEVICETYPEID
            ,CG_ITEMID
    ) AS CHANNEL_GROUP /*PREFIX = CG */
    CROSS JOIN TAT_DB_MASTER_DELIVERY_HOUR
;

/* 時間帯別流入数 */
/* 集計対象期間に存在するCHANNEL_DETAILID, CAMPAIGNID, OSIDを集約 */
/* 流入実績が存在しない時間帯のデータも作成したいため */
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_CLICK_TMP_GROUP
(
    HCTG_HOUR BYTEINT
    ,HCTG_CHANNEL_DETAILID BYTEINT
    ,HCTG_CAMPAIGNID INTEGER
    ,HCTG_OSID BYTEINT
)
DISTRIBUTE ON (HCTG_HOUR, HCTG_CHANNEL_DETAILID, HCTG_CAMPAIGNID, HCTG_OSID)
;

INSERT INTO TAT_DB_RESULT_HOURLY_CLICK_TMP_GROUP
SELECT
    MDH_HOUR AS HCTG_HOUR
    ,CG_CHANNEL_DETAILID AS HCTG_CHANNEL_DETAILID
    ,CG_CAMPAIGNID AS HCTG_CAMPAIGNID
    ,VI_OSID AS HCTG_OSID
FROM (
        SELECT
            HVU_CHANNEL_DETAILID AS CG_CHANNEL_DETAILID
            ,HVU_CAMPAIGNID AS CG_CAMPAIGNID
            ,HVU_OSID AS VI_OSID
        FROM
            TAT_DB_HISTORY_VISIT_USER
        WHERE 
            HVU_CHANNELID = 3  /* PUSH */
            AND HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND HVU_SENDDT < '${pd_base_date}'::DATE
        GROUP BY
            CG_CHANNEL_DETAILID
            ,CG_CAMPAIGNID
            ,VI_OSID
    ) AS CLICK_GROUP /*PREFIX = CG */
    CROSS JOIN TAT_DB_MASTER_DELIVERY_HOUR
;

/* 時間帯別配信数の集計 */
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_SEND_TMP
(
    HST_HOUR BYTEINT
    ,HST_PUSHTYPECATEGORYID BYTEINT
    ,HST_DEVICETYPEID BYTEINT
    ,HST_ITEMID INTEGER    
    ,HST_CNT_SEND INTEGER
)
DISTRIBUTE ON (HST_HOUR, HST_PUSHTYPECATEGORYID, HST_DEVICETYPEID, HST_ITEMID)
;

INSERT INTO TAT_DB_RESULT_HOURLY_SEND_TMP
SELECT
    HSTG_HOUR AS HST_HOUR
    ,HSTG_PUSHTYPECATEGORYID AS HST_PUSHTYPECATEGORYID
    ,HSTG_DEVICETYPEID AS HST_DEVICETYPEID
    ,HSTG_ITEMID AS HST_ITEMID
    ,NVL(HD_CNT_SEND, 0) AS HST_CNT_SEND
FROM TAT_DB_RESULT_HOURLY_SEND_TMP_GROUP
    LEFT JOIN (
        SELECT
            DATE_PART('HOUR', CONTACTDT) AS HD_HOUR
            ,PUSHTYPECATEGORYID AS HD_PUSHTYPECATEGORYID
            ,PNDEVICETYPEID AS HD_DEVICETYPEID
            ,ITEMID AS HD_ITEMID
            ,COUNT(HD_HOUR) AS HD_CNT_SEND
        FROM 
            TPNPUSHAPPHISTORY
        INNER JOIN TPUSHNOTIFICATION ON PUSHNOTIFICATIONID = PNPUSHNOTIFICATIONID
        WHERE
            CONTACTDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND CONTACTDT < '${pd_base_date}'::DATE
            AND PUSHTYPECATEGORYID IN (1, 2, 3, 6)  /* 1:パーソナライズ、2:新着おまとめ、3:新着リアルタイム、6:マス */
        GROUP BY 
            HD_HOUR
            ,HD_PUSHTYPECATEGORYID
            ,HD_DEVICETYPEID
            ,HD_ITEMID
    ) AS HOUR_SEND /*PREFIX = HD */ 
    ON HSTG_PUSHTYPECATEGORYID = HD_PUSHTYPECATEGORYID
    AND HSTG_DEVICETYPEID = HD_DEVICETYPEID
    AND HSTG_HOUR = HD_HOUR
    AND HSTG_ITEMID = HD_ITEMID
;

/* 時間帯別流入数の集計 */
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_CLICK_TMP
(
    HCT_HOUR BYTEINT
    ,HCT_CHANNEL_DETAILID BYTEINT
    ,HCT_CAMPAIGNID INTEGER
    ,HCT_OSID BYTEINT
    ,HCT_CNT_CLICK INTEGER
    ,HCT_CNT_CAMPAIGN INTEGER
)
DISTRIBUTE ON (HCT_HOUR, HCT_CHANNEL_DETAILID, HCT_CAMPAIGNID, HCT_OSID)
;

INSERT INTO TAT_DB_RESULT_HOURLY_CLICK_TMP
SELECT
    HCTG_HOUR AS HCT_HOUR
    ,HC_CHANNEL_DETAILID AS HCT_CHANNEL_DETAILID
    ,HC_CAMPAIGNID AS HCT_CAMPAIGNID
    ,HC_OSID AS  HCT_OSID
    ,NVL(HC_CNT_CLICK, 0) AS HCT_CNT_CLICK
    ,HCCC_CNT_CAMPAIGN AS HCT_CNT_CAMPAIGN
FROM TAT_DB_RESULT_HOURLY_CLICK_TMP_GROUP
    LEFT JOIN (
        SELECT
            DATE_PART('HOUR', HVU_VISITTIME) AS HC_HOUR_CLICK
            ,HVU_CHANNEL_DETAILID AS HC_CHANNEL_DETAILID
            ,HVU_CAMPAIGNID AS HC_CAMPAIGNID
            ,HVU_OSID AS HC_OSID
            ,COUNT(HVU_OSID) AS HC_CNT_CLICK
        FROM
            TAT_DB_HISTORY_VISIT_USER
        WHERE 
            HVU_CHANNELID = 3  /* PUSH */
            AND HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND HVU_SENDDT < '${pd_base_date}'::DATE
        GROUP BY
            HC_HOUR_CLICK
            ,HC_CHANNEL_DETAILID
            ,HC_CAMPAIGNID
            ,HC_OSID
    ) AS HOUR_CLICK /*PREFIX = HC */ 
    ON HCTG_HOUR = HC_HOUR_CLICK
    AND HCTG_CHANNEL_DETAILID = HC_CHANNEL_DETAILID
    AND HCTG_CAMPAIGNID = HC_CAMPAIGNID
    AND HCTG_OSID = HC_OSID
    INNER JOIN (
        /* 配信数をキャンペーン単位で割るために、対象時刻のキャンペーン数を取得 */
        SELECT 
            HCTG_HOUR AS HCCC_HOUR
            ,HCTG_CHANNEL_DETAILID AS HCCC_CHANNEL_DETAILID
            ,HCTG_OSID AS HCCC_OSID
            ,COUNT(DISTINCT HCTG_CAMPAIGNID) AS HCCC_CNT_CAMPAIGN
        FROM 
            TAT_DB_RESULT_HOURLY_CLICK_TMP_GROUP
        GROUP BY
            HCCC_HOUR
            ,HCCC_CHANNEL_DETAILID
            ,HCCC_OSID
    ) AS HOUR_CLICK_CAMPAIGN_CNT /* PREFIX = HCCC */
    ON HCTG_HOUR = HCCC_HOUR
    AND HC_CHANNEL_DETAILID = HCCC_CHANNEL_DETAILID
    AND HC_OSID = HCCC_OSID
WHERE
    HCT_CHANNEL_DETAILID IS NOT NULL
;

/* 時間帯別配信・流入の集計 */
CREATE TEMP TABLE TAT_DB_RESULT_PUSH_TMP_HOUR
(
    PTH_HOUR BYTEINT
    ,PTH_CHANNEL_DETAILID BYTEINT
    ,PTH_CAMPAIGNID INTEGER
    ,PTH_OSID BYTEINT
    ,PTH_CNT_SEND INTEGER
    ,PTH_CNT_CLICK INTEGER
)
DISTRIBUTE ON (PTH_HOUR, PTH_CHANNEL_DETAILID, PTH_CAMPAIGNID, PTH_OSID)
;

/* マス 時間帯別配信・流入の集計 */
INSERT INTO TAT_DB_RESULT_PUSH_TMP_HOUR
SELECT
    MHS_HOUR
    ,MHC_CHANNEL_DETAILID
    ,MHC_CAMPAIGNID
    ,MHC_OSID
    ,ROUND(MHS_CNT_SEND / MHC_CNT_CAMPAIGN, 0) /* 配信数を対象日のキャンペーン数で割る */
    ,MHC_CNT_CLICK
FROM (
        SELECT
            HST_HOUR AS MHS_HOUR
            ,HST_PUSHTYPECATEGORYID AS MHS_PUSHTYPECATEGORYID
            ,HST_DEVICETYPEID AS MHS_DEVICETYPEID
            ,SUM(HST_CNT_SEND) AS MHS_CNT_SEND
        FROM
            TAT_DB_RESULT_HOURLY_SEND_TMP
        WHERE
            HST_PUSHTYPECATEGORYID = 6 /* マス */
        GROUP BY
            MHS_HOUR
            ,MHS_PUSHTYPECATEGORYID
            ,MHS_DEVICETYPEID
    ) AS MASS_HOUR_SEND /* PREFIX = MHS */
    INNER JOIN (
        SELECT
            HCT_HOUR AS MHC_HOUR
            ,HCT_CHANNEL_DETAILID AS MHC_CHANNEL_DETAILID
            ,HCT_CAMPAIGNID AS MHC_CAMPAIGNID
            ,HCT_OSID AS MHC_OSID
            ,HCT_CNT_CLICK AS MHC_CNT_CLICK
            ,HCT_CNT_CAMPAIGN AS MHC_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_HOURLY_CLICK_TMP
        WHERE
            MHC_CHANNEL_DETAILID = 2 /* マス */
    ) AS MASS_HOUR_CLICK /*PREFIX = MHC */ 
    ON MHS_HOUR = MHC_HOUR
    AND MHS_DEVICETYPEID = MHC_OSID

UNION ALL

/* 新着おまとめ 時間帯別配信・流入の集計 */
SELECT
    NSHS_HOUR
    ,NSHC_CHANNEL_DETAILID
    ,NSHC_CAMPAIGNID
    ,NSHC_OSID
    ,NSHS_CNT_SEND
    ,NSHC_CNT_CLICK
FROM (
        SELECT
            HST_HOUR AS NSHS_HOUR
            ,HST_PUSHTYPECATEGORYID AS NSHS_PUSHTYPECATEGORYID
            ,HST_DEVICETYPEID AS NSHS_DEVICETYPEID
            ,SUM(HST_CNT_SEND) AS NSHS_CNT_SEND
        FROM
            TAT_DB_RESULT_HOURLY_SEND_TMP
        WHERE
            HST_PUSHTYPECATEGORYID = 2 /* 新着おまとめ */
        GROUP BY
            NSHS_HOUR
            ,NSHS_PUSHTYPECATEGORYID
            ,NSHS_DEVICETYPEID
    ) AS NEW_SUM_HOUR_SEND /* PREFIX = NSHS */
    INNER JOIN (
        SELECT
            HCT_HOUR AS NSHC_HOUR
            ,HCT_CHANNEL_DETAILID AS NSHC_CHANNEL_DETAILID
            ,HCT_CAMPAIGNID AS NSHC_CAMPAIGNID
            ,HCT_OSID AS NSHC_OSID
            ,HCT_CNT_CLICK AS NSHC_CNT_CLICK
            ,HCT_CNT_CAMPAIGN AS NSHC_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_HOURLY_CLICK_TMP
        WHERE
            NSHC_CHANNEL_DETAILID = 1 /* 新着 */
            AND NSHC_CAMPAIGNID = 1 /* 新着おまとめ */
    ) AS NEW_SUM_HOUR_CLICK /*PREFIX = NSHC */
    ON NSHS_HOUR = NSHC_HOUR
    AND NSHS_DEVICETYPEID = NSHC_OSID

UNION ALL

/* 新着リアルタイム 時間帯別配信・流入の集計 */
SELECT
    NRHS_HOUR
    ,NRHC_CHANNEL_DETAILID
    ,NRHC_CAMPAIGNID
    ,NRHC_OSID
    ,NRHS_CNT_SEND
    ,NRHC_CNT_CLICK
FROM (
        SELECT
            HST_HOUR AS NRHS_HOUR
            ,HST_PUSHTYPECATEGORYID AS NRHS_PUSHTYPECATEGORYID
            ,HST_DEVICETYPEID AS NRHS_DEVICETYPEID
            ,SUM(HST_CNT_SEND) AS NRHS_CNT_SEND
        FROM
            TAT_DB_RESULT_HOURLY_SEND_TMP
        WHERE
            HST_PUSHTYPECATEGORYID = 3 /* 新着リアルタイム */
        GROUP BY
            NRHS_HOUR
            ,NRHS_PUSHTYPECATEGORYID
            ,NRHS_DEVICETYPEID
    ) AS NEW_REALTIME_HOUR_SEND /* PREFIX = NRHS */
    INNER JOIN (
        SELECT
            HCT_HOUR AS NRHC_HOUR
            ,HCT_CHANNEL_DETAILID AS NRHC_CHANNEL_DETAILID
            ,HCT_CAMPAIGNID AS NRHC_CAMPAIGNID
            ,HCT_OSID AS NRHC_OSID
            ,HCT_CNT_CLICK AS NRHC_CNT_CLICK
            ,HCT_CNT_CAMPAIGN AS NRHC_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_HOURLY_CLICK_TMP
        WHERE
            NRHC_CHANNEL_DETAILID = 1 /* 新着 */
            AND NRHC_CAMPAIGNID = 3 /* 新着リアルタイム */
    ) AS NEW_REALTIME_HOUR_CLICK /*PREFIX = NRHC */
    ON NRHS_HOUR = NRHC_HOUR
    AND NRHS_DEVICETYPEID = NRHC_OSID

UNION ALL

/* パーソナライズPUSH 時間帯別配信・流入の集計 */
SELECT
    PHS_HOUR
    ,PHC_CHANNEL_DETAILID
    ,PHC_CAMPAIGNID
    ,PHC_OSID
    ,PHS_CNT_SEND
    ,PHC_CNT_CLICK
FROM (
        SELECT
            HST_HOUR AS PHS_HOUR
            ,HST_PUSHTYPECATEGORYID AS PHS_PUSHTYPECATEGORYID
            ,HST_DEVICETYPEID AS PHS_DEVICETYPEID
            ,CAG_CAMPAIGNID AS PHS_CAMPAIGNID
            ,SUM(HST_CNT_SEND) AS PHS_CNT_SEND
        FROM
            TAT_DB_RESULT_HOURLY_SEND_TMP
            INNER JOIN (
                /* TPNNOTICEDELIVERYからCAMPAIGNIDの抽出 */
                SELECT DISTINCT
                    HST_ITEMID AS CAG_ITEMID
                    ,PNDCAMPAIGNID AS CAG_CAMPAIGNID
                FROM TAT_DB_RESULT_HOURLY_SEND_TMP
                INNER JOIN TPNNOTICEDELIVERY ON PNDSEQID = HST_ITEMID
                WHERE
                  HST_PUSHTYPECATEGORYID = 1 /* パーソナライズ */
            ) AS CAMPAIGN_GROUP /*PREFIX = CAG */
            ON CAG_ITEMID = HST_ITEMID
        WHERE
            HST_PUSHTYPECATEGORYID = 1 /* パーソナライズ */
        GROUP BY
          PHS_HOUR
          ,PHS_PUSHTYPECATEGORYID
          ,PHS_DEVICETYPEID
          ,PHS_CAMPAIGNID
    ) AS PERSONALIZE_HOUR_SEND /* PREFIX = PHS */
    INNER JOIN (
        SELECT
            HCT_HOUR AS PHC_HOUR
            ,HCT_CHANNEL_DETAILID AS PHC_CHANNEL_DETAILID
            ,HCT_CAMPAIGNID AS PHC_CAMPAIGNID
            ,HCT_OSID AS PHC_OSID
            ,HCT_CNT_CLICK AS PHC_CNT_CLICK
            ,HCT_CNT_CAMPAIGN AS PHC_CNT_CAMPAIGN
        FROM
            TAT_DB_RESULT_HOURLY_CLICK_TMP
        WHERE
            PHC_CHANNEL_DETAILID = 4 /* パーソナライズ */
    ) AS PERSONALIZE_HOUR_CLICK /*PREFIX = PHC */
    ON PHS_HOUR = PHC_HOUR
    AND PHS_DEVICETYPEID = PHC_OSID
    AND PHS_CAMPAIGNID = PHC_CAMPAIGNID
;

/* 日次実績更新 */
DELETE
    FROM TAT_DB_RESULT_APPPUSH
WHERE
    RAP_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS' 
    OR RAP_SENDDT < DATE_TRUNC('MONTH','${pd_base_date}'::DATE + INTERVAL '-25MONTHS')
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

/* 時間帯別実績更新 */
DELETE
    FROM TAT_DB_RESULT_HOURLY
WHERE
    RHO_CHANNELID = 3 /* PUSH */
;

INSERT INTO TAT_DB_RESULT_HOURLY
SELECT
    PTH_HOUR
    ,3 AS PTH_CHANNELID /* PUSHのCHANNELID */
    ,PTH_CHANNEL_DETAILID
    ,PTH_CAMPAIGNID
    ,NULL AS PTH_DELIVCEID
    ,PTH_OSID
    ,PTH_CNT_SEND
    ,0 AS PTH_CNT_OPEN /* 開封数 */
    ,PTH_CNT_CLICK
    ,0 AS PTH_CNT_BUYITEM /* 購買商品数 */
FROM 
    TAT_DB_RESULT_PUSH_TMP_HOUR
;

COMMIT
;