/* 処理開始 */
BEGIN
;

/* TOWN新着配信データ(直近8日) */
CREATE TEMP TABLE TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
(
    TD_CAMPAIGNID INTEGER,
    TD_MEMBERID INTEGER,
    TD_EMAILID INTEGER,
    TD_CHANNELID BYTEINT,
    TD_DEVICEID BYTEINT,
    TD_USERTYPEID BYTEINT,
    TD_SENDDT TIMESTAMP,
    TD_OPENDT TIMESTAMP,
    TD_CLICKDT TIMESTAMP
)
DISTRIBUTE ON (TD_CAMPAIGNID, TD_EMAILID, TD_SENDDT)
;

--対象となる配信データ
INSERT INTO TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
SELECT
    MMD.MAILMAGCAMPAIGNID AS TD_CAMPAIGNID
    ,MMMEMBERID AS TD_MEMBERID
    ,MMDD.EMAILID AS TD_EMAILID
    ,MPM_CHANNELID AS TD_CHANNELID
    ,CASE WHEN MMD.MOBILEFLAG = 0 THEN 2 ELSE MMD.MOBILEFLAG END AS TD_DEVICEID
    ,CASE 
        WHEN SL.CAMPAIGNID = 9000 THEN (CASE WHEN MMD.MOBILEFLAG = 0 THEN USERTYPE ELSE 99 END)--TOWNの場合ヘビー/ライト区分を使用
        WHEN SL.CAMPAIGNID = 9010 THEN (CASE WHEN MMD.MOBILEFLAG = 0 THEN 1 ELSE 99 END)--USEDの場合PCは全員ヘビー区分
    END AS TD_USERTYPEID
    ,MMD.DELIVERYDT AS TD_SENDDT
    ,MMDD.OPENDT AS TD_OPENDT
    ,NULL AS TD_CLICKDT
FROM
    TUCMAILMAGDELIVERY AS MMD
    INNER JOIN TUCMAILMAGDELIVERYDETAIL AS MMDD ON MMD.ARTICLEID = MMDD.ARTICLEID
    INNER JOIN (
        SELECT 
            9000 AS CAMPAIGNID
            ,CONTACTDT
            ,EMAILID
            ,USERTYPE
        FROM
            TUCNEWARRIVAL_TOWN_SENDLIST_MEMBER
        WHERE
            CONTACTDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
            AND CONTACTDT < '${pd_base_date}'::TIMESTAMP

        UNION ALL

        SELECT 
            9010 AS CAMPAIGNID
            ,CONTACTDT
            ,EMAILID
            ,USERTYPE
        FROM
            TUCNEWARRIVAL_USED_SENDLIST_MEMBER
        WHERE
            CONTACTDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
            AND CONTACTDT < '${pd_base_date}'::TIMESTAMP
    ) AS SL ON MMD.MAILMAGCAMPAIGNID = SL.CAMPAIGNID AND MMD.DELIVERYDT::DATE = SL.CONTACTDT AND MMDD.EMAILID = SL.EMAILID
    INNER JOIN TUCMAILMAGCAMPAIGN CP ON MMD.MAILMAGCAMPAIGNID = CP.MAILMAGCAMPAIGNID
    INNER JOIN TAT_DB_MASTER_PARAMETER_MAPPING ON MMD.MAILMAGCAMPAIGNID::VARCHAR(50) = MPM_MAPPINGID
    INNER JOIN TMEMBEREMAIL ON MMDD.EMAILID = MMEMAILID
WHERE
    DELIVERYDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
    AND DELIVERYDT < '${pd_base_date}'::TIMESTAMP
    AND MPM_CHANNELID = 1
    AND MPM_CHANNEL_DETAILID = 1
;

CREATE TEMP TABLE TAT_DB_RESULT_NEWARRIVAL_TMP_GOODSSENDLIST (
    TG_CAMPAIGNID INTEGER,
    TG_CONTACTDT DATE,
    TG_EMAILID INTEGER,
    TG_MEMBERID INTEGER,
    TG_GOODSID INTEGER
)
DISTRIBUTE ON (TG_CAMPAIGNID, TG_CONTACTDT, TG_EMAILID, TG_GOODSID)
;

INSERT INTO TAT_DB_RESULT_NEWARRIVAL_TMP_GOODSSENDLIST
SELECT
    TSG_CAMPAIGNID AS TG_CAMPAIGNID
    ,TSG_CONTACTDT AS TG_CONTACTDT
    ,TSG_EMAILID AS TG_EMAILID
    ,TD_MEMBERID AS TG_MEMBERID
    ,TSG_GOODSID AS TG_GOODSID
FROM (
    SELECT
        9000 AS TSG_CAMPAIGNID
        ,CONTACTDT AS TSG_CONTACTDT
        ,EMAILID AS TSG_EMAILID
        ,GOODSID AS TSG_GOODSID
    FROM
        TUCNEWARRIVAL_TOWN_SENDLIST_GOODS
    WHERE
        CONTACTDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
        AND CONTACTDT < '${pd_base_date}'::DATE

    UNION ALL

    SELECT
        9010 AS TSG_CAMPAIGNID
        ,CONTACTDT AS TSG_CONTACTDT
        ,EMAILID AS TSG_EMAILID
        ,GOODSID AS TSG_GOODSID
    FROM
        TUCNEWARRIVAL_USED_SENDLIST_GOODS
    WHERE
        CONTACTDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
        AND CONTACTDT < '${pd_base_date}'::DATE
) AS TSG
INNER JOIN (
    SELECT
        TD_CAMPAIGNID
        ,TD_SENDDT::DATE AS TD_SENDDT_TMP
        ,TD_EMAILID
        ,TD_MEMBERID
    FROM
        TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
    WHERE
        TD_CAMPAIGNID IN (9000, 9010)
    GROUP BY
        TD_CAMPAIGNID
        ,TD_SENDDT
        ,TD_EMAILID
        ,TD_MEMBERID
) AS TD ON TSG_CAMPAIGNID = TD_CAMPAIGNID AND TSG_CONTACTDT = TD_SENDDT_TMP AND TSG_EMAILID = TD_EMAILID
;

/* 直近8日の購買データ */
CREATE TEMP TABLE TAT_DB_RESULT_NEWARRIVAL_TMP_ORDER
(
    TO_ORDERDT TIMESTAMP,
    TO_MEMBERID INTEGER,
    TO_GOODSID INTEGER,
    TO_BUYPRICE INTEGER
)
DISTRIBUTE ON (TO_ORDERDT, TO_MEMBERID, TO_GOODSID)
;

INSERT INTO TAT_DB_RESULT_NEWARRIVAL_TMP_ORDER
SELECT
    ORORDERDT AS TO_ORDERDT
    ,ORMEMBERID AS TO_MEMBERID
    ,GOGOODSID AS TO_GOODSID
    ,SUM(ROUND(ODPRICE * (1 + ORUCHITAXRATE), 0) * ODQUANTITY) AS TO_BUYPRICE
FROM
    TORDER
    INNER JOIN TORDERDETAIL ON ORORDERID = ODORDERID
    INNER JOIN TSHOPSHELF ON ODSHELFID = SSSHELFID
    INNER JOIN TGOODSDETAIL ON SSGOODSDETAILID = GDGOODSDETAILID
    INNER JOIN TGOODS ON GDGOODSID = GOGOODSID
WHERE
    ORMALLID = 1
    AND ODCANCELFLAG = 0
    AND ODCANCELDT IS NULL
    AND ORORDERDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
GROUP BY
    TO_ORDERDT
    ,TO_MEMBERID
    ,TO_GOODSID
;

/* 直近8日のお気に入り登録データ */
CREATE TEMP TABLE TAT_DB_RESULT_NEWARRIVAL_TMP_FAV
(
    TF_MEMBERID INTEGER,
    TF_GOODSID INTEGER,
    TF_REGISTDT TIMESTAMP,
    TF_DELETEDT TIMESTAMP
)
DISTRIBUTE ON (TF_MEMBERID, TF_GOODSID, TF_REGISTDT)
;

INSERT INTO TAT_DB_RESULT_NEWARRIVAL_TMP_FAV
SELECT
    FLMEMBERID AS FGD_MEMBERID
    ,FLGOODSID AS FGD_GOODSID
    ,FLREGISTDT AS FGD_REGISTDT
    ,FLDELETEDT AS FGD_DELETEDT
FROM (
    SELECT
        FLMEMBERID
        ,FLGOODSID
        ,FLREGISTDT
        ,FLDELETEDT
        ,ROW_NUMBER() OVER(PARTITION BY FLFAVORITELISTID ORDER BY FLFLAG) AS ROWNUM
    FROM (
        SELECT
            FLFAVORITELISTID
            ,FLMEMBERID
            ,FLGOODSID
            ,FLREGISTDT
            ,FLDELETEDT
            ,1 AS FLFLAG
        FROM
            TFAVORITELIST
        WHERE
            FLREGISTDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
            AND FLGOODSDETAILID IS NOT NULL

        UNION ALL

        SELECT
            FLDFAVORITELISTID AS FLFAVORITELISTID
            ,FLDMEMBERID AS FLMEMBERID
            ,FLDGOODSID AS FLGOODSID
            ,FLDREGISTDT AS FLREGISTDT
            ,FLDDELETEDT AS FLDELETEDT
            ,2 AS FLFLAG
        FROM
            TFAVORITELIST_DELETE
        WHERE
            FLDREGISTDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
            AND FLDGOODSDETAILID IS NOT NULL
    ) AS FAVBASE
) AS GETNUM
WHERE
    ROWNUM = 1
GROUP BY
    FLMEMBERID
    ,FLGOODSID
    ,FLREGISTDT
    ,FLDELETEDT
;

/* 配信経由の購入・お気に入り登録をまとめる */
CREATE TEMP TABLE TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_ITEM
(
    TRI_SENDDT DATE,
    TRI_CAMPAIGNID INTEGER,
    TRI_CHANNELID BYTEINT,
    TRI_DEVICEID BYTEINT,
    TRI_USERTYPEID BYTEINT,
    TRI_UNIQUEGOODSID VARCHAR(30),
    TRI_MEMBERID INTEGER,
    TRI_ORDERDT TIMESTAMP,
    TRI_BUY_UNIQUEGOODSID VARCHAR(30),
    TRI_BUYPRICE INTEGER,
    TRI_FAV_UNIQUEGOODSID VARCHAR(30)
)
DISTRIBUTE ON (TRI_SENDDT, TRI_CAMPAIGNID, TRI_DEVICEID, TRI_UNIQUEGOODSID)
;

INSERT INTO TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_ITEM
SELECT DISTINCT
    SRM_SENDDT AS TRI_SENDDT
    ,SRM_CAMPAIGNID AS TRI_CAMPAIGNID
    ,SRM_CHANNELID AS TRI_CHANNELID
    ,SRM_DEVICEID AS TRI_DEVICEID
    ,SRM_USERTYPEID AS TRI_USERTYPEID
    ,SRM_UNIQUEGOODSID AS TRI_UNIQUEGOODSID
    /* 配信後に同一商品が配信・開封されていた場合は
       次の開封日より前のデータを対象とする */
    ,CASE WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL)
        THEN TO_MEMBERID
        ELSE NULL
    END AS TRI_MEMBERID
    ,CASE WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL)
        THEN TO_ORDERDT
        ELSE NULL
    END AS TRI_ORDERDT
    ,CASE WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL)
        THEN SRM_UNIQUEGOODSID
        ELSE NULL
    END AS TRI_BUY_UNIQUEGOODSID
    ,CASE WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL)
        THEN TO_BUYPRICE
        ELSE 0
    END AS TRI_BUYPRICE
    ,CASE WHEN TF_MEMBERID IS NOT NULL AND (TF_REGISTDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL)
        THEN SRM_UNIQUEGOODSID
        ELSE NULL
    END AS TRI_FAV_UNIQUEGOODSID
FROM (
    /* 配信毎の掲載商品と
       次に同一商品が配信・開封された日時を取得 */
    SELECT
        MO_SENDDT AS SRM_SENDDT
        ,MO_CAMPAIGNID AS SRM_CAMPAIGNID
        ,MO_CHANNELID AS SRM_CHANNELID
        ,MO_DEVICEID AS SRM_DEVICEID
        ,MO_USERTYPEID AS SRM_USERTYPEID
        ,MO_MEMBERID AS SRM_MEMBERID
        ,MO_OPENDT AS SRM_OPENDT
        ,GS_GOODSID AS SRM_GOODSID
        ,TO_CHAR(MO_SENDDT, 'YYYYMMDD') || MO_MEMBERID || '_' || GS_GOODSID AS SRM_UNIQUEGOODSID
        ,LEAD(MO_OPENDT) OVER(PARTITION BY MO_CAMPAIGNID, MO_MEMBERID, GS_GOODSID ORDER BY MO_OPENDT) AS SRM_LEADOPENDT
    FROM (
        --ZOZO会員の配信データに絞る
        SELECT DISTINCT
            TD_SENDDT::DATE AS MO_SENDDT
            ,TD_CAMPAIGNID AS MO_CAMPAIGNID
            ,TD_MEMBERID AS MO_MEMBERID
            ,TD_CHANNELID AS MO_CHANNELID
            ,TD_DEVICEID AS MO_DEVICEID
            ,TD_USERTYPEID AS MO_USERTYPEID
            ,TD_OPENDT AS MO_OPENDT
        FROM
            TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
        WHERE
            TD_MEMBERID IS NOT NULL--会員限定
            AND TD_DEVICEID = 2--PCのみ
    ) AS MAILOFFER /* PREFIX = MO */
    INNER JOIN (
        SELECT
            TG_CAMPAIGNID AS GS_CAMPAIGNID
            ,TG_CONTACTDT AS GS_SENDDT
            ,TG_MEMBERID AS GS_MEMBERID
            ,TG_GOODSID AS GS_GOODSID
        FROM
            TAT_DB_RESULT_NEWARRIVAL_TMP_GOODSSENDLIST
        WHERE
            TG_MEMBERID IS NOT NULL
        GROUP BY
            TG_CAMPAIGNID
            ,TG_CONTACTDT
            ,TG_MEMBERID
            ,TG_GOODSID
    ) AS GOODSSENDLIST
        ON MO_SENDDT = GS_SENDDT
        AND MO_CAMPAIGNID = GS_CAMPAIGNID
        AND MO_MEMBERID = GS_MEMBERID
) AS SENDRESULTFORMAIL /* PREFIX = SRM */
LEFT OUTER JOIN TAT_DB_RESULT_NEWARRIVAL_TMP_ORDER
    ON SRM_MEMBERID = TO_MEMBERID
    AND SRM_GOODSID = TO_GOODSID
    AND SRM_OPENDT < TO_ORDERDT
    AND TO_ORDERDT <= SRM_OPENDT + INTERVAL '1DAY' /* 開封から1日以内の購買対象 */
LEFT OUTER JOIN TAT_DB_RESULT_NEWARRIVAL_TMP_FAV
    ON SRM_MEMBERID = TF_MEMBERID
    AND SRM_GOODSID = TF_GOODSID
    AND SRM_OPENDT < TF_REGISTDT
    AND TF_REGISTDT <= SRM_OPENDT + INTERVAL '1DAY' /* 開封から1日以内のお気に入り登録対象 */
    AND (TF_DELETEDT IS NULL OR SRM_OPENDT < TF_DELETEDT)
WHERE
    SRM_OPENDT < SRM_SENDDT + INTERVAL '8DAYS'
;

/* 日別配信数/開封数/クリック数/経由売上を集計 */
CREATE TEMP TABLE TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_DAILY
(
    TRD_SENDDT DATE,
    TRD_CAMPAIGNID INTEGER,
    TRD_CHANNELID BYTEINT,
    TRD_DEVICEID BYTEINT,
    TRD_USERTYPEID BYTEINT,
    TRD_CNT_SEND INTEGER,
    TRD_CNT_OPEN INTEGER,
    TRD_CNT_CLICK INTEGER,
    TRD_CNT_CV INTEGER,
    TRD_REVENUE_TOTAL BIGINT
)
DISTRIBUTE ON (TRD_SENDDT, TRD_CAMPAIGNID, TRD_DEVICEID, TRD_USERTYPEID)
;

--日ごとの配信通数、開封通数、流入通数、経由売上
INSERT INTO TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_DAILY
SELECT
    DD_SENDDT AS TRD_SENDDT
    ,DD_CAMPAIGNID AS TRD_CAMPAIGNID
    ,DD_CHANNELID AS TRD_CHANNELID
    ,DD_DEVICEID AS TRD_DEVICEID
    ,DD_USERTYPEID AS TRD_USERTYPEID
    ,DD_CNT_SEND AS TRD_CNT_SEND
    ,DD_CNT_OPEN AS TRD_CNT_OPEN
    ,VD_CNT_CLICK AS TRD_CNT_CLICK
    ,VD_CNT_CV AS TRD_CNT_CV
    ,VD_REVENUE_TOTAL AS TRD_REVENUE_TOTAL
FROM (
    SELECT
        TD_SENDDT::DATE AS DD_SENDDT
        ,TD_CAMPAIGNID AS DD_CAMPAIGNID
        ,TD_CHANNELID AS DD_CHANNELID
        ,TD_DEVICEID AS DD_DEVICEID
        ,TD_USERTYPEID AS DD_USERTYPEID
        ,COUNT(DISTINCT TD_EMAILID) AS DD_CNT_SEND
        ,COUNT(DISTINCT CASE WHEN TD_OPENDT < TD_SENDDT::DATE + INTERVAL '8DAYS' AND TD_DEVICEID = 2 THEN TD_EMAILID ELSE NULL END) AS DD_CNT_OPEN
    FROM
        TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
    GROUP BY
        DD_SENDDT
        ,DD_CAMPAIGNID
        ,DD_CHANNELID
        ,DD_DEVICEID
        ,DD_USERTYPEID
    ) AS DELIVERYDATA/*PREFIX = DD*/
    LEFT OUTER JOIN (
        SELECT
            HVU_SENDDT AS VD_SENDDT
            ,HVU_CAMPAIGNID AS VD_CAMPAIGNID
            ,HVU_CHANNELID AS VD_CHANNELID
            ,HVU_DEVICEID AS VD_DEVICEID
            ,TD_USERTYPEID AS VD_USERTYPEID
            ,COUNT(DISTINCT CASE WHEN HVU_VISITTIME < TD_SENDDT::DATE + INTERVAL '8DAYS' THEN TD_EMAILID ELSE NULL END) AS VD_CNT_CLICK
            ,COUNT(DISTINCT CASE WHEN HVU_VISITTIME < TD_SENDDT::DATE + INTERVAL '8DAYS' AND HVU_FULLVISITORID_CV IS NOT NULL THEN TD_EMAILID ELSE NULL END) AS VD_CNT_CV
            ,SUM(HVU_REVENUE) AS VD_REVENUE_TOTAL
        FROM
            TAT_DB_HISTORY_VISIT_USER
            INNER JOIN TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY ON HVU_SENDDT = TD_SENDDT::DATE AND HVU_CAMPAIGNID = TD_CAMPAIGNID AND HVU_EMAILID = TD_EMAILID
        WHERE
            HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND HVU_VISITTIME >= HVU_SENDDT::TIMESTAMP
            AND HVU_CHANNELID = 1--メール
            AND HVU_CHANNEL_DETAILID = 1--新着
            AND HVU_DEVICEID IN (1,2)--MO、PC
        GROUP BY
            VD_SENDDT
            ,VD_CAMPAIGNID
            ,VD_CHANNELID
            ,VD_DEVICEID
            ,VD_USERTYPEID
    ) AS VISITDATA /*PREFIX = VD*/ ON DD_SENDDT = VD_SENDDT
                            AND DD_CAMPAIGNID = VD_CAMPAIGNID
                            AND DD_CHANNELID = VD_CHANNELID
                            AND DD_DEVICEID = VD_DEVICEID
                            AND DD_USERTYPEID = VD_USERTYPEID
;

--日次実績更新
DELETE
FROM
	TAT_DB_RESULT_NEWARRIVAL
WHERE
	RNA_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
	OR RNA_SENDDT < DATE_TRUNC('MONTH','${pd_base_date}'::DATE + INTERVAL '-25MONTHS')
;

INSERT INTO TAT_DB_RESULT_NEWARRIVAL
SELECT
    RNA_SENDDT
    ,RNA_CAMPAIGNID
    --配信数
    ,RNA_CNT_SEND_PC_HEAVY
    ,RNA_CNT_SEND_PC_LIGHT
    ,RNA_CNT_SEND_MO
    --開封数
    ,RNA_CNT_OPEN_PC_HEAVY
    ,RNA_CNT_OPEN_PC_LIGHT
    --流入数
    ,RNA_CNT_CLICK_PC_HEAVY
    ,RNA_CNT_CLICK_PC_LIGHT
    ,RNA_CNT_CLICK_MO
    --CV数
    ,RNA_CNT_CV_PC_HEAVY
    ,RNA_CNT_CV_PC_LIGHT
    ,RNA_CNT_CV_MO
    --経由売上
    ,RNA_REVENUE_TOTAL_PC_HEAVY
    ,RNA_REVENUE_TOTAL_PC_LIGHT
    ,RNA_REVENUE_TOTAL_MO
    --掲載アイテム数
    ,NVL(TRI_CNT_SENDITEM_PC_HEAVY, 0) AS RNA_CNT_SENDITEM_PC_HEAVY
    ,NVL(TRI_CNT_SENDITEM_PC_LIGHT, 0) AS RNA_CNT_SENDITEM_PC_LIGHT
    --掲載アイテム購買数
    ,NVL(TRI_CNT_BUY_SENDITEM_PC_HEAVY, 0) AS RNA_CNT_BUY_SENDITEM_PC_HEAVY
    ,NVL(TRI_CNT_BUY_SENDITEM_PC_LIGHT, 0) AS RNA_CNT_BUY_SENDITEM_PC_LIGHT
    --掲載アイテム売上
    ,NVL(TRI_REVENUE_BUY_SENDITEM_PC_HEAVY, 0) AS RNA_REVENUE_BUY_SENDITEM_PC_HEAVY
    ,NVL(TRI_REVENUE_BUY_SENDITEM_PC_LIGHT, 0) AS RNA_REVENUE_BUY_SENDITEM_PC_LIGHT
    --掲載アイテムお気に入り登録
    ,NVL(TRI_CNT_FAVORITE_ITEM_PC_HEAVY, 0) AS RNA_CNT_FAVORITE_ITEM_PC_HEAVY
    ,NVL(TRI_CNT_FAVORITE_ITEM_PC_LIGHT, 0) AS RNA_CNT_FAVORITE_ITEM_PC_LIGHT
FROM (
    SELECT
        TRD_SENDDT AS RNA_SENDDT
        ,TRD_CAMPAIGNID AS RNA_CAMPAIGNID
        --配信数
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 1 THEN TRD_CNT_SEND ELSE 0 END) AS RNA_CNT_SEND_PC_HEAVY
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 2 THEN TRD_CNT_SEND ELSE 0 END) AS RNA_CNT_SEND_PC_LIGHT
        ,SUM(CASE WHEN TRD_DEVICEID = 1 THEN TRD_CNT_SEND ELSE 0 END) AS RNA_CNT_SEND_MO
        --開封数（PC）
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 1 THEN TRD_CNT_OPEN ELSE 0 END) AS RNA_CNT_OPEN_PC_HEAVY
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 2 THEN TRD_CNT_OPEN ELSE 0 END) AS RNA_CNT_OPEN_PC_LIGHT
        --クリック数
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 1 THEN TRD_CNT_CLICK ELSE 0 END) AS RNA_CNT_CLICK_PC_HEAVY
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 2 THEN TRD_CNT_CLICK ELSE 0 END) AS RNA_CNT_CLICK_PC_LIGHT
        ,SUM(CASE WHEN TRD_DEVICEID = 1 THEN TRD_CNT_CLICK ELSE 0 END) AS RNA_CNT_CLICK_MO
        --CV数
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 1 THEN TRD_CNT_CV ELSE 0 END) AS RNA_CNT_CV_PC_HEAVY
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 2 THEN TRD_CNT_CV ELSE 0 END) AS RNA_CNT_CV_PC_LIGHT
        ,SUM(CASE WHEN TRD_DEVICEID = 1 THEN TRD_CNT_CV ELSE 0 END) AS RNA_CNT_CV_MO
        --経由売上
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 1 THEN TRD_REVENUE_TOTAL ELSE 0 END) AS RNA_REVENUE_TOTAL_PC_HEAVY
        ,SUM(CASE WHEN TRD_DEVICEID = 2 AND TRD_USERTYPEID = 2 THEN TRD_REVENUE_TOTAL ELSE 0 END) AS RNA_REVENUE_TOTAL_PC_LIGHT
        ,SUM(CASE WHEN TRD_DEVICEID = 1 THEN TRD_REVENUE_TOTAL ELSE 0 END) AS RNA_REVENUE_TOTAL_MO
    FROM
        TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_DAILY
    GROUP BY
        TRD_SENDDT
        ,TRD_CAMPAIGNID
    ) AS DELIVERY
    LEFT OUTER JOIN (
        SELECT
            TRI_SENDDT
            ,TRI_CAMPAIGNID
            --掲載アイテム数
            ,COUNT(DISTINCT CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 1 THEN TRI_UNIQUEGOODSID ELSE NULL END) AS TRI_CNT_SENDITEM_PC_HEAVY
            ,COUNT(DISTINCT CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 2 THEN TRI_UNIQUEGOODSID ELSE NULL END) AS TRI_CNT_SENDITEM_PC_LIGHT
            --掲載アイテム購買数
            ,COUNT(DISTINCT CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 1 THEN TRI_BUY_UNIQUEGOODSID ELSE NULL END) AS TRI_CNT_BUY_SENDITEM_PC_HEAVY
            ,COUNT(DISTINCT CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 2 THEN TRI_BUY_UNIQUEGOODSID ELSE NULL END) AS TRI_CNT_BUY_SENDITEM_PC_LIGHT
            --掲載アイテム購買売上
            ,SUM(CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 1 THEN TRI_BUYPRICE ELSE 0 END) AS TRI_REVENUE_BUY_SENDITEM_PC_HEAVY
            ,SUM(CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 2 THEN TRI_BUYPRICE ELSE 0 END) AS TRI_REVENUE_BUY_SENDITEM_PC_LIGHT
            --掲載アイテムお気に入り登録数
            ,COUNT(DISTINCT CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 1 THEN TRI_FAV_UNIQUEGOODSID ELSE NULL END) AS TRI_CNT_FAVORITE_ITEM_PC_HEAVY
            ,COUNT(DISTINCT CASE WHEN TRI_DEVICEID = 2 AND TRI_USERTYPEID = 2 THEN TRI_FAV_UNIQUEGOODSID ELSE NULL END) AS TRI_CNT_FAVORITE_ITEM_PC_LIGHT
        FROM
            TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_ITEM
        GROUP BY
            TRI_SENDDT
            ,TRI_CAMPAIGNID
    ) AS ITEM ON RNA_SENDDT = TRI_SENDDT
             AND RNA_CAMPAIGNID = TRI_CAMPAIGNID
;

/* 時間帯別配信実績 */
--ベース項目生成
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_TMP_MASTER
(
    TM_CAMPAIGNID INTEGER,
    TM_CHANNELID BYTEINT,
    TM_DEVICEID BYTEINT,
    TM_HOUR BYTEINT
)
DISTRIBUTE ON (TM_CAMPAIGNID, TM_CHANNELID, TM_DEVICEID, TM_HOUR)
;

INSERT INTO TAT_DB_RESULT_HOURLY_TMP_MASTER
SELECT
    TD_CAMPAIGNID AS TM_CAMPAIGNID
    ,TD_CHANNELID AS TM_CHANNELID
    ,TD_DEVICEID AS TM_DEVICEID
    ,MDH_HOUR AS TM_HOUR
FROM (
    SELECT DISTINCT
        TD_CAMPAIGNID
        ,TD_CHANNELID
        ,TD_DEVICEID
    FROM
        TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
) AS CAMPAIGN
CROSS JOIN TAT_DB_MASTER_DELIVERY_HOUR
;

--配信数
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_TMP_HOURLY_DELIVERY
(
    THD_CAMPAIGNID INTEGER,
    THD_CHANNELID BYTEINT,
    THD_DEVICEID BYTEINT,
    THD_HOUR BYTEINT,
    THD_CNT_DELIVERY INTEGER
)
DISTRIBUTE ON (THD_CAMPAIGNID, THD_CHANNELID, THD_HOUR, THD_CNT_DELIVERY)
;

INSERT INTO TAT_DB_RESULT_HOURLY_TMP_HOURLY_DELIVERY
SELECT
    TM_CAMPAIGNID AS THD_CAMPAIGNID
    ,TM_CHANNELID AS THD_CHANNELID
    ,TM_DEVICEID AS THD_DEVICEID
    ,TM_HOUR AS THD_HOUR
    ,NVL(CNT_DELIVERY,0) AS THD_CNT_DELIVERY
FROM
    TAT_DB_RESULT_HOURLY_TMP_MASTER
    LEFT OUTER JOIN (
        SELECT
            TD_CAMPAIGNID
            ,TD_CHANNELID
            ,TD_DEVICEID
            ,DATE_PART('HOUR', TD_SENDDT) AS HOUR_DELIVERY
            ,COUNT(DISTINCT TD_EMAILID) AS CNT_DELIVERY
        FROM
            TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
        GROUP BY
            TD_CAMPAIGNID
            ,TD_CHANNELID
            ,TD_DEVICEID
            ,HOUR_DELIVERY
    ) AS DELIVERYDATA ON TM_CAMPAIGNID = TD_CAMPAIGNID
                                            AND TM_CHANNELID = TD_CHANNELID
                                            AND TM_DEVICEID = TD_DEVICEID
                                            AND TM_HOUR = HOUR_DELIVERY
;

--開封数
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_TMP_HOURLY_OPEN
(
    THO_CAMPAIGNID INTEGER,
    THO_CHANNELID BYTEINT,
    THO_DEVICEID BYTEINT,
    THO_HOUR BYTEINT,
    THO_CNT_OPEN INTEGER
)
DISTRIBUTE ON (THO_CAMPAIGNID, THO_CHANNELID, THO_HOUR, THO_CNT_OPEN)
;

INSERT INTO TAT_DB_RESULT_HOURLY_TMP_HOURLY_OPEN
SELECT
    TM_CAMPAIGNID AS THO_CAMPAIGNID
    ,TM_CHANNELID AS THO_CHANNELID
    ,TM_DEVICEID AS THO_DEVICEID
    ,TM_HOUR AS THO_HOUR
    ,NVL(CNT_OPEN,0) AS THO_CNT_OPEN
FROM
    TAT_DB_RESULT_HOURLY_TMP_MASTER
    LEFT OUTER JOIN (
        SELECT
            TD_CAMPAIGNID
            ,TD_CHANNELID
            ,TD_DEVICEID
            ,DATE_PART('HOUR', TD_OPENDT) AS HOUR_OPEN
            ,COUNT(DISTINCT CASE WHEN TD_OPENDT IS NOT NULL AND TD_DEVICEID = 2 THEN TD_EMAILID ELSE NULL END) AS CNT_OPEN
        FROM
            TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY
        GROUP BY
            TD_CAMPAIGNID
            ,TD_CHANNELID
            ,TD_DEVICEID
            ,HOUR_OPEN
    ) AS OPENDATA ON TM_CAMPAIGNID = TD_CAMPAIGNID
                                            AND TM_CHANNELID = TD_CHANNELID
                                            AND TM_DEVICEID = TD_DEVICEID
                                            AND TM_HOUR = HOUR_OPEN
;

--クリック数
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_TMP_HOURLY_CLICK
(
    THC_CAMPAIGNID INTEGER,
    THC_CHANNELID BYTEINT,
    THC_DEVICEID BYTEINT,
    THC_HOUR BYTEINT,
    THC_CNT_CLICK INTEGER
)
DISTRIBUTE ON (THC_CAMPAIGNID, THC_CHANNELID, THC_HOUR, THC_CNT_CLICK)
;

INSERT INTO TAT_DB_RESULT_HOURLY_TMP_HOURLY_CLICK
SELECT
    TM_CAMPAIGNID AS THC_CAMPAIGNID
    ,TM_CHANNELID AS THC_CHANNELID
    ,TM_DEVICEID AS THC_DEVICEID
    ,TM_HOUR AS THC_HOUR
    ,NVL(CNT_CLICK,0) AS THC_CNT_CLICK
FROM
    TAT_DB_RESULT_HOURLY_TMP_MASTER
    LEFT OUTER JOIN (
        SELECT
            HVU_CAMPAIGNID
            ,HVU_CHANNELID
            ,HVU_DEVICEID
            ,DATE_PART('HOUR', HVU_VISITTIME) AS HOUR_CLICK
            ,COUNT(DISTINCT CASE WHEN HVU_VISITTIME < TD_SENDDT::DATE + INTERVAL '8DAYS' THEN TD_EMAILID ELSE NULL END) AS CNT_CLICK
        FROM
            TAT_DB_HISTORY_VISIT_USER
            INNER JOIN TAT_DB_RESULT_NEWARRIVAL_TMP_DELIVERY ON HVU_SENDDT = TD_SENDDT::DATE AND HVU_CAMPAIGNID = TD_CAMPAIGNID AND HVU_EMAILID = TD_EMAILID
        WHERE
            HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND HVU_VISITTIME >= HVU_SENDDT::TIMESTAMP
            AND HVU_CHANNELID = 1--メール
            AND HVU_CHANNEL_DETAILID = 1--新着
            AND HVU_DEVICEID IN (1,2)--MO、PC
        GROUP BY
            HVU_CAMPAIGNID
            ,HVU_CHANNELID
            ,HVU_DEVICEID
            ,HOUR_CLICK
    ) AS CLICKDATA ON TM_CAMPAIGNID = HVU_CAMPAIGNID
                AND TM_CHANNELID = HVU_CHANNELID
                AND TM_DEVICEID = HVU_DEVICEID
                AND TM_HOUR = HOUR_CLICK
;

--購買アイテム数
CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_TMP_HOURLY_BUYITEM
(
    THB_CAMPAIGNID INTEGER,
    THB_CHANNELID BYTEINT,
    THB_DEVICEID BYTEINT,
    THB_HOUR BYTEINT,
    THB_CNT_BUYITEM INTEGER
)
DISTRIBUTE ON (THB_CAMPAIGNID, THB_CHANNELID, THB_HOUR, THB_CNT_BUYITEM)
;

INSERT INTO TAT_DB_RESULT_HOURLY_TMP_HOURLY_BUYITEM
SELECT
    TM_CAMPAIGNID AS THB_CAMPAIGNID
    ,TM_CHANNELID AS THB_CHANNELID
    ,TM_DEVICEID AS THB_DEVICEID
    ,TM_HOUR AS THB_HOUR
    ,NVL(CNT_BUYITEM,0) AS THB_CNT_BUYITEM
FROM
    TAT_DB_RESULT_HOURLY_TMP_MASTER
    LEFT OUTER JOIN (
    SELECT
        TRI_CAMPAIGNID
        ,TRI_CHANNELID
        ,TRI_DEVICEID
        ,DATE_PART('HOUR', TRI_ORDERDT) AS HOUR_ORDER
        ,COUNT(DISTINCT TRI_BUY_UNIQUEGOODSID) AS CNT_BUYITEM
    FROM
        TAT_DB_RESULT_NEWARRIVAL_TMP_RESULT_ITEM
    GROUP BY
        TRI_CAMPAIGNID
        ,TRI_CHANNELID
        ,TRI_DEVICEID
        ,HOUR_ORDER
    ) AS BUYITEMDATA ON TM_CAMPAIGNID = TRI_CAMPAIGNID
                                            AND TM_CHANNELID = TRI_CHANNELID
                                            AND TM_DEVICEID = TRI_DEVICEID
                                            AND TM_HOUR = HOUR_ORDER
;

--データマージ
DELETE FROM TAT_DB_RESULT_HOURLY WHERE RHO_CHANNELID = 1 AND RHO_CHANNEL_DETAILID = 1
;

INSERT INTO TAT_DB_RESULT_HOURLY
SELECT
    THD_HOUR AS RHO_HOUR
    ,THD_CHANNELID AS RHO_CHANNELID
    ,1 AS RHO_CHANNEL_DETAILID
    ,THD_CAMPAIGNID AS RHO_CAMPAIGNID
    ,THD_DEVICEID AS RHO_DEVICEID
    ,NULL AS RHO_OSID
    ,THD_CNT_DELIVERY AS RHO_CNT_SEND
    ,THO_CNT_OPEN AS RHO_CNT_OPEN
    ,THC_CNT_CLICK AS RHO_CNT_CLICK
    ,THB_CNT_BUYITEM AS RHO_CNT_BUYITEM
FROM
    TAT_DB_RESULT_HOURLY_TMP_HOURLY_DELIVERY
    INNER JOIN TAT_DB_RESULT_HOURLY_TMP_HOURLY_OPEN ON THD_HOUR = THO_HOUR
                                    AND THD_CHANNELID = THO_CHANNELID
                                    AND THD_CAMPAIGNID = THO_CAMPAIGNID
                                    AND THD_DEVICEID = THO_DEVICEID
    INNER JOIN TAT_DB_RESULT_HOURLY_TMP_HOURLY_CLICK ON THD_HOUR = THC_HOUR
                                    AND THD_CHANNELID = THC_CHANNELID
                                    AND THD_CAMPAIGNID = THC_CAMPAIGNID
                                    AND THD_DEVICEID = THC_DEVICEID
    INNER JOIN TAT_DB_RESULT_HOURLY_TMP_HOURLY_BUYITEM ON THD_HOUR = THB_HOUR
                                    AND THD_CHANNELID = THB_CHANNELID
                                    AND THD_CAMPAIGNID = THB_CAMPAIGNID
                                    AND THD_DEVICEID = THB_DEVICEID
;

/* 処理終了 */
COMMIT
;