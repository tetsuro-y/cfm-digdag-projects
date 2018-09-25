BEGIN
;

CREATE TEMP TABLE TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
(
    TD_SYSTEMID BYTEINT,
    TD_OFFERID INTEGER,
    TD_CAMPAIGNID INTEGER,
    TD_MEMBERID INTEGER,
    TD_EMAILID INTEGER,
    TD_CHANNELID BYTEINT,
    TD_DEVICEID BYTEINT,
    TD_SENDDT TIMESTAMP,
    TD_OPENDT TIMESTAMP,
    TD_CLICKDT TIMESTAMP,
    TD_CVDT TIMESTAMP
)
DISTRIBUTE ON (TD_OFFERID, TD_CAMPAIGNID, TD_MEMBERID, TD_SENDDT)
;

--対象となる配信データ
INSERT INTO TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
SELECT DISTINCT--OFFERIDごとのレコードをユニークにするため念のためDISTINCTをつける
    1 AS TD_SYSTEMID--流入データを紐づけるときに3.0か否かを判断するためのID
    ,OFFER_ID AS TD_OFFERID
    ,CAMPAIGN_ID AS TD_CAMPAIGNID
    ,MEMBER_ID AS TD_MEMBERID
    ,NULL AS TD_EMAILID
    ,CHANNEL AS TD_CHANNELID
    ,OFFER_DEVICE AS TD_DEVICEID
    ,OFFER_DELIVERY_DT AS TD_SENDDT
    ,OPEN_DT AS TD_OPENDT
    ,CLICK_DT AS TD_CLICKDT
    ,CONVERSION_DT AS TD_CVDT
FROM
    TRTM_OFFER_DELIVERY
WHERE
    OFFER_DELIVERY_DT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
    AND OFFER_DELIVERY_DT < '${pd_base_date}'::TIMESTAMP
    AND OFFER_STATUS_DELIVERY = '0'    --配信成功（1の場合は失敗）
    AND OFFER_DELIVERY_DT IS NOT NULL
    AND ARTICLE_ID IS NOT NULL    --配信成功

UNION ALL

SELECT DISTINCT
    2 AS TD_SYSTEMID--流入データを紐づけるときに3.0か否かを判断するためのID
    ,NULL AS TD_OFFERID
    ,MPM_MAPPINGID AS TD_CAMPAIGNID
    ,MMMEMBERID AS TD_MEMBERID
    ,MMDD.EMAILID AS TD_EMAILID
    ,1 AS TD_CHANNELID--メール
    ,CASE
        WHEN MMD.MOBILEFLAG = 0 THEN 2--PCの場合は3.0とあわせて2とする
        ELSE MMD.MOBILEFLAG
    END AS TD_DEVICEID
    ,MMD.DELIVERYDT AS TD_SENDDT
    ,MMDD.OPENDT AS TD_OPENDT
    ,NULL AS TD_CLICKDT
    ,NULL AS TD_CVDT
FROM
    TUCMAILMAGDELIVERY AS MMD
    INNER JOIN TUCMAILMAGDELIVERYDETAIL AS MMDD ON MMD.ARTICLEID = MMDD.ARTICLEID
    INNER JOIN TUCMAILMAGCAMPAIGN CP ON MMD.MAILMAGCAMPAIGNID = CP.MAILMAGCAMPAIGNID
    INNER JOIN TAT_DB_MASTER_PARAMETER_MAPPING ON MMD.MAILMAGCAMPAIGNID::VARCHAR(50) = MPM_PARAMETER
    INNER JOIN TMEMBEREMAIL ON MMDD.EMAIL = MMEMAIL AND MMDEFAULT IS TRUE
WHERE
    DELIVERYDT >= '${pd_base_date}'::TIMESTAMP + INTERVAL '-8DAYS'
    AND DELIVERYDT < '${pd_base_date}'::TIMESTAMP
    AND UPPER(CP.TYPENAME) = 'PA_M'
;

CREATE TEMP TABLE TAT_DB_RESULT_PERSONALIZE_TMP_ORDER
(
    TO_ORDERDT TIMESTAMP,
    TO_MEMBERID INTEGER,
    TO_GOODSID INTEGER,
    TO_BUYPRICE INTEGER
)
DISTRIBUTE ON (TO_ORDERDT, TO_MEMBERID, TO_GOODSID)
;

--対象となる購買データ
INSERT INTO TAT_DB_RESULT_PERSONALIZE_TMP_ORDER
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

CREATE TEMP TABLE TAT_DB_RESULT_PERSONALIZE_TMP_FAV
(
    TF_MEMBERID INTEGER,
    TF_GOODSID INTEGER,
    TF_REGISTDT TIMESTAMP,
    TF_DELETEDT TIMESTAMP
)
DISTRIBUTE ON (TF_MEMBERID, TF_GOODSID, TF_REGISTDT)
;

--対象となるお気に入り登録データ
INSERT INTO TAT_DB_RESULT_PERSONALIZE_TMP_FAV
SELECT DISTINCT
    FGD_MEMBERID AS TF_MEMBERID
    ,GDGOODSID AS TF_GOODSID
    ,FGD_REGISTDT AS TF_REGISTDT
    ,FGD_DELETEDT AS TF_DELETEDT
FROM (
    SELECT
        FLMEMBERID AS FGD_MEMBERID
        ,FLGOODSDETAILID AS FGD_GOODSDETAILID
        ,FLREGISTDT AS FGD_REGISTDT
        ,FLDELETEDT AS FGD_DELETEDT
    FROM (
        SELECT
            FLMEMBERID
            ,FLGOODSDETAILID
            ,FLREGISTDT
            ,FLDELETEDT
            ,ROW_NUMBER() OVER (PARTITION BY FLFAVORITELISTID ORDER BY FLFLAG) AS ROWNUM
        FROM (
            SELECT
                FLFAVORITELISTID
                ,FLMEMBERID
                ,FLGOODSDETAILID
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
                ,FLDGOODSDETAILID AS FLGOODSDETAILID
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
) AS GET_FLGOODSDETAIL /*PREFIX = FGD*/
INNER JOIN TGOODSDETAIL ON FGD_GOODSDETAILID = GDGOODSDETAILID
;

CREATE TEMP TABLE TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_ITEM
(
    TRI_SENDDT DATE,
    TRI_CAMPAIGNID INTEGER,
    TRI_CHANNELID BYTEINT,
    TRI_DEVICEID BYTEINT,
    TRI_OPENDT TIMESTAMP,
    TRI_UNIQUEGOODSID VARCHAR(30),
    TRI_AREATYPEID BYTEINT,
    TRI_ORDERDT TIMESTAMP,
    TRI_BUY_UNIQUEGOODSID VARCHAR(30),
    TRI_BUYPRICE INTEGER,
    TRI_FAV_UNIQUEGOODSID VARCHAR(30)
)
DISTRIBUTE ON (TRI_UNIQUEGOODSID, TRI_AREATYPEID, TRI_ORDERDT, TRI_FAV_UNIQUEGOODSID)
;

--配信/購入/お気に入り登録データ詳細
INSERT INTO TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_ITEM
--メール配信データ
--ORDERDTを最小単位としたレコードをつくる
SELECT DISTINCT
    SRM_SENDDT AS TRI_SENDDT
    ,SRM_CAMPAIGNID AS TRI_CAMPAIGNID
    ,SRM_CHANNELID AS TRI_CHANNELID
    ,SRM_DEVICEID AS TRI_DEVICEID
    ,SRM_OPENDT AS TRI_OPENDT
    ,SRM_UNIQUEGOODSID AS TRI_UNIQUEGOODSID
    ,SRM_AREATYPEID AS TRI_AREATYPEID
    ,CASE
        WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL) THEN TO_ORDERDT
        ELSE NULL
    END AS TRI_ORDERDT
    --配信日以降同商品が再度配信・開封されていた場合は次の開封日より前の購買もしくはお気に入り登録を対象とする
    ,CASE
        WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL) THEN SRM_UNIQUEGOODSID
        ELSE NULL
    END AS TRI_BUY_UNIQUEGOODSID
    ,CASE
        WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL) THEN TO_BUYPRICE
        ELSE 0
    END AS TRI_BUYPRICE
    ,CASE
        WHEN TF_MEMBERID IS NOT NULL AND (TF_REGISTDT < SRM_LEADOPENDT OR SRM_LEADOPENDT IS NULL) THEN SRM_UNIQUEGOODSID
        ELSE NULL
    END AS TRI_FAV_UNIQUEGOODSID
FROM (
    --OFFERごとの掲載商品とその配信ユーザが同商品を次に開封したタイミングを取得する
    SELECT
        GGM_SENDDT AS SRM_SENDDT
        ,GGM_OFFERID AS SRM_OFFERID
        ,GGM_CAMPAIGNID AS SRM_CAMPAIGNID
        ,GGM_CHANNELID AS SRM_CHANNELID
        ,GGM_DEVICEID AS SRM_DEVICEID
        ,GGM_MEMBERID AS SRM_MEMBERID
        ,GGM_OPENDT AS SRM_OPENDT
        ,GGM_GOODSID AS SRM_GOODSID
        ,GGM_AREATYPEID AS SRM_AREATYPEID
        ,GGM_OFFERID || '_' || GGM_GOODSID AS SRM_UNIQUEGOODSID
        ,LEAD(GGM_OPENDT) OVER (PARTITION BY GGM_CAMPAIGNID, GGM_DEVICEID, GGM_MEMBERID, GGM_AREATYPEID, GGM_GOODSID ORDER BY GGM_OPENDT) AS SRM_LEADOPENDT
    FROM (
        --SENDDT・OFFERID・MEMBERID・OPENDT・GOODSID・AREATYPEIDで一意となるレコードに整える
        SELECT DISTINCT
            SBM_SENDDT AS GGM_SENDDT
            ,SBM_OFFERID AS GGM_OFFERID
            ,SBM_CAMPAIGNID AS GGM_CAMPAIGNID
            ,SBM_CHANNELID AS GGM_CHANNELID
            ,SBM_DEVICEID AS GGM_DEVICEID
            ,SBM_MEMBERID AS GGM_MEMBERID
            ,SBM_OPENDT AS GGM_OPENDT
            ,GDGOODSID AS GGM_GOODSID
            ,SBM_AREATYPEID AS GGM_AREATYPEID
        FROM (
            SELECT DISTINCT
                MO_SENDDT AS SBM_SENDDT
                ,MO_OFFERID AS SBM_OFFERID
                ,MO_CAMPAIGNID AS SBM_CAMPAIGNID
                ,MD_CHANNELID AS SBM_CHANNELID
                ,MO_DEVICEID AS SBM_DEVICEID
                ,MO_MEMBERID AS SBM_MEMBERID
                ,MO_OPENDT AS SBM_OPENDT
                ,CONTENTS_ID AS SBM_CONTENTSID--GOODSDETAILID
                ,AREA_TYPE AS SBM_AREATYPEID
            FROM (
                SELECT
                    DATE_TRUNC('DAY', TD_SENDDT) AS MO_SENDDT
                    ,TD_OFFERID AS MO_OFFERID
                    ,TD_CAMPAIGNID AS MO_CAMPAIGNID
                    ,TD_CHANNELID AS MD_CHANNELID
                    ,TD_DEVICEID AS MO_DEVICEID
                    ,TD_MEMBERID AS MO_MEMBERID
                    ,TD_OPENDT AS MO_OPENDT
                FROM
                    TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
                WHERE
                    TD_CHANNELID = 1    --メール
                    AND TD_OFFERID IS NOT NULL--3.0の配信実績に限定
            ) AS MAILOFFER /*PREFIX = MO*/
            INNER JOIN TRTM_CONTENTS_DELIVERY ON MO_OFFERID = OFFER_ID AND DELETE_DT IS NULL AND CONTENTS_TYPE = 2
        ) AS SENDBASEFORMAIL /*PREFIX = SBM*/
        INNER JOIN TGOODSDETAIL ON SBM_CONTENTSID = GDGOODSDETAILID
    ) AS GETGOODSIDFORMAIL /*PREFIX = GGM*/
) AS SENDRESULTFORMAIL /*PREFIX = SRM*/
LEFT OUTER JOIN TAT_DB_RESULT_PERSONALIZE_TMP_ORDER ON SRM_MEMBERID = TO_MEMBERID
    AND SRM_GOODSID = TO_GOODSID
    AND TO_ORDERDT > SRM_OPENDT
    AND TO_ORDERDT <= SRM_OPENDT + INTERVAL '1DAY'--開封から1日以内の購買対象
LEFT OUTER JOIN TAT_DB_RESULT_PERSONALIZE_TMP_FAV ON SRM_MEMBERID = TF_MEMBERID
    AND SRM_GOODSID = TF_GOODSID
    AND TF_REGISTDT > SRM_OPENDT
    AND TF_REGISTDT <= SRM_OPENDT + INTERVAL '1DAY'--開封から1日以内のお気に入り登録対象
    AND (TF_DELETEDT IS NULL OR TF_DELETEDT > SRM_OPENDT)
WHERE
    TRI_OPENDT < TRI_SENDDT + INTERVAL '8DAYS'

UNION ALL

--LINE配信データ
--ORDERDTを最小単位としたレコードをつくる
SELECT DISTINCT
    SRL_SENDDT AS TRI_SENDDT
    ,SRL_CAMPAIGNID AS TRI_CAMPAIGNID
    ,SRL_CHANNELID AS TRI_CHANNELID
    ,SRL_DEVICEID AS TRI_DEVICEID
    ,NULL AS TRI_OPENDT
    ,SRL_UNIQUEGOODSID AS TRI_UNIQUEGOODSID
    ,NULL AS TRI_AREATYPEID
    ,CASE
        WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRL_LEADDELIVERYDT OR SRL_LEADDELIVERYDT IS NULL) THEN TO_ORDERDT
        ELSE NULL
    END AS TRI_ORDERDT
    --配信日以降同商品が再度配信されていた場合は次の配信日より前の購買もしくはお気に入り登録を対象とする
    ,CASE
        WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRL_LEADDELIVERYDT OR SRL_LEADDELIVERYDT IS NULL) THEN SRL_UNIQUEGOODSID
        ELSE NULL
    END AS TRI_BUY_UNIQUEGOODSID    --購入商品
    ,CASE
        WHEN TO_MEMBERID IS NOT NULL AND (TO_ORDERDT < SRL_LEADDELIVERYDT OR SRL_LEADDELIVERYDT IS NULL) THEN TO_BUYPRICE
        ELSE 0
    END AS TRI_BUYPRICE    --購入金額
    ,CASE
        WHEN TF_MEMBERID IS NOT NULL AND (TF_REGISTDT < SRL_LEADDELIVERYDT OR SRL_LEADDELIVERYDT IS NULL) THEN SRL_UNIQUEGOODSID
        ELSE NULL
    END AS TRI_FAV_UNIQUEGOODSID
FROM (
    SELECT
        GGL_SENDDT AS SRL_SENDDT
        ,GGL_OFFERID AS SRL_OFFERID
        ,GGL_CAMPAIGNID AS SRL_CAMPAIGNID
        ,GGL_CHANNELID AS SRL_CHANNELID
        ,GGL_DEVICEID AS SRL_DEVICEID
        ,GGL_MEMBERID AS SRL_MEMBERID
        ,GGL_OFFERDELIVERYDT AS SRL_OFFERDELIVERYDT
        ,GGL_GOODSID AS SRL_GOODSID
        ,GGL_OFFERID || '_' || GGL_GOODSID AS SRL_UNIQUEGOODSID
        ,LEAD(GGL_OFFERDELIVERYDT) OVER (PARTITION BY GGL_CAMPAIGNID, GGL_DEVICEID, GGL_MEMBERID, GGL_GOODSID ORDER BY GGL_OFFERDELIVERYDT) AS SRL_LEADDELIVERYDT
    FROM (
        --SENDDT・OFFERID・MEMBERID・GOODSIDで一意となるレコードに整える
        SELECT DISTINCT
            SBL_SENDDT AS GGL_SENDDT
            ,SBL_OFFERID AS GGL_OFFERID
            ,SBL_CAMPAIGNID AS GGL_CAMPAIGNID
            ,SBL_CHANNELID AS GGL_CHANNELID
            ,SBL_DEVICEID AS GGL_DEVICEID
            ,SBL_MEMBERID AS GGL_MEMBERID
            ,SBL_OFFERDELIVERYDT AS GGL_OFFERDELIVERYDT
            ,GDGOODSID AS GGL_GOODSID
        FROM (
            SELECT DISTINCT
                LO_SENDDT AS SBL_SENDDT
                ,LO_OFFERID AS SBL_OFFERID
                ,LO_CAMPAIGNID AS SBL_CAMPAIGNID
                ,LO_CHANNELID AS SBL_CHANNELID
                ,LO_DEVICEID AS SBL_DEVICEID
                ,LO_MEMBERID AS SBL_MEMBERID
                ,LO_OFFERDELIVERYDT AS SBL_OFFERDELIVERYDT
                ,CONTENTS_ID AS SBL_CONTENTSID--GOODSDETAILID
            FROM (
                SELECT
                    DATE_TRUNC('DAY', TD_SENDDT) AS LO_SENDDT
                    ,TD_OFFERID AS LO_OFFERID
                    ,TD_CAMPAIGNID AS LO_CAMPAIGNID
                    ,TD_CHANNELID AS LO_CHANNELID
                    ,TD_DEVICEID AS LO_DEVICEID
                    ,TD_MEMBERID AS LO_MEMBERID
                    ,TD_SENDDT AS LO_OFFERDELIVERYDT
                FROM
                    TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
                WHERE
                    TD_CHANNELID = 2    --LINEに限定
                    AND TD_OFFERID IS NOT NULL--3.0の配信実績に限定
            ) AS LINEOFFER    /*PREFIX = LO*/
            INNER JOIN TRTM_MAINCONTENTS_DELIVERY ON LO_OFFERID = OFFER_ID
        ) AS SENDBASEFORLINE /*PREFIX = SBL*/
        INNER JOIN TGOODSDETAIL ON SBL_CONTENTSID = GDGOODSDETAILID
    ) AS GETGOODSIDFORLINE /*PREFIX = GGL*/
) AS SENDRESULTFORLINE /*PREFIX = SRL*/
LEFT OUTER JOIN TAT_DB_RESULT_PERSONALIZE_TMP_ORDER ON SRL_MEMBERID = TO_MEMBERID
    AND SRL_GOODSID = TO_GOODSID
    AND TO_ORDERDT > SRL_OFFERDELIVERYDT
    AND TO_ORDERDT <= SRL_OFFERDELIVERYDT + INTERVAL '1DAY'--配信から1日以内の購買対象
LEFT OUTER JOIN TAT_DB_RESULT_PERSONALIZE_TMP_FAV ON SRL_MEMBERID = TF_MEMBERID
    AND SRL_GOODSID = TF_GOODSID
    AND TF_REGISTDT > SRL_OFFERDELIVERYDT
    AND TF_REGISTDT <= SRL_OFFERDELIVERYDT + INTERVAL '1DAY'--配信から1日以内のお気に入り登録対象
    AND (TF_DELETEDT IS NULL OR TF_DELETEDT > SRL_OFFERDELIVERYDT)
;

CREATE TEMP TABLE TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_DAILY
(
    TRD_SENDDT DATE,
    TRD_CAMPAIGNID INTEGER,
    TRD_CHANNELID BYTEINT,
    TRD_DEVICEID BYTEINT,
    TRD_CNT_SEND INTEGER,
    TRD_CNT_OPEN INTEGER,
    TRD_CNT_CLICK INTEGER,
    TRD_CNT_CV INTEGER,
    TRD_REVENUE_TOTAL BIGINT
)
DISTRIBUTE ON (TRD_SENDDT, TRD_CAMPAIGNID, TRD_CHANNELID, TRD_DEVICEID)
;

--日ごとの配信通数、開封通数、流入通数、経由売上
INSERT INTO TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_DAILY
SELECT
    DD_SENDDT AS TRD_SENDDT
    ,DD_CAMPAIGNID AS TRD_CAMPAIGNID
    ,DD_CHANNELID AS TRD_CHANNELID
    ,DD_DEVICEID AS TRD_DEVICEID
    ,DD_CNT_SEND AS TRD_CNT_SEND
    ,DD_CNT_OPEN AS TRD_CNT_OPEN
    ,DD_CNT_CLICK AS TRD_CNT_CLICK
    ,DD_CNT_CV AS TRD_CNT_CV
    ,VD_REVENUE_TOTAL AS TRD_REVENUE_TOTAL
FROM (
    SELECT
        DATE_TRUNC('DAY', TD_SENDDT) AS DD_SENDDT
        ,TD_CAMPAIGNID AS DD_CAMPAIGNID
        ,TD_CHANNELID AS DD_CHANNELID
        ,TD_DEVICEID AS DD_DEVICEID
        ,COUNT(DISTINCT NVL(TD_OFFERID, TD_EMAILID)) AS DD_CNT_SEND
        ,COUNT(DISTINCT CASE WHEN TD_OPENDT < TD_SENDDT::DATE + INTERVAL '8DAYS' AND TD_CHANNELID = 1 AND TD_DEVICEID = 2 THEN NVL(TD_OFFERID, TD_EMAILID) ELSE NULL END) AS DD_CNT_OPEN
        ,COUNT(DISTINCT CASE WHEN TD_CLICKDT < TD_SENDDT::DATE + INTERVAL '8DAYS' THEN TD_OFFERID ELSE NULL END) AS DD_CNT_CLICK
        ,COUNT(DISTINCT CASE WHEN TD_CLICKDT < TD_SENDDT::DATE + INTERVAL '8DAYS' AND TD_CVDT IS NOT NULL THEN TD_OFFERID ELSE NULL END) AS DD_CNT_CV
    FROM
        TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
    GROUP BY
        DD_SENDDT
        ,DD_CAMPAIGNID
        ,DD_CHANNELID
        ,DD_DEVICEID
    ) AS DELIVERYDATA/*PREFIX = DD*/
    LEFT OUTER JOIN (
        SELECT
            HVU_SENDDT AS VD_SENDDT
            ,HVU_CAMPAIGNID AS VD_CAMPAIGNID
            ,HVU_CHANNELID AS VD_CHANNELID
            ,NVL(HVU_DEVICEID, 2) AS VD_DEVICEID--LINEのデバイスがNULLなので2(SP)とする
            ,SUM(HVU_REVENUE) AS VD_REVENUE_TOTAL
        FROM
            TAT_DB_HISTORY_VISIT_USER
            INNER JOIN (
                SELECT DISTINCT
                    TD_SYSTEMID
                    ,TD_SENDDT::DATE AS TD_SENDDT
                    ,TD_CAMPAIGNID
                FROM
                    TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
                ) AS DELIVERY ON HVU_SENDDT = TD_SENDDT AND HVU_CAMPAIGNID = TD_CAMPAIGNID
        WHERE
            HVU_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS'
            AND HVU_CHANNELID IN (1, 2)--メールおよびLINE
            AND HVU_CHANNEL_DETAILID = 4--パーソナライズ
            AND HVU_VISITTIME >= HVU_SENDDT::TIMESTAMP--配信日以降の流入に絞る（配信日が流入日より後になっているような不正なレコードを除外する）
            AND (
                TD_SYSTEMID = 1 AND HVU_OFFERID IS NOT NULL
                OR
                TD_SYSTEMID = 2
            )
        GROUP BY
            VD_SENDDT
            ,VD_CAMPAIGNID
            ,VD_CHANNELID
            ,VD_DEVICEID
    ) AS VISITDATA /*PREFIX = VD*/ ON DD_SENDDT = VD_SENDDT
                            AND DD_CAMPAIGNID = VD_CAMPAIGNID
                            AND DD_CHANNELID = VD_CHANNELID
                            AND DD_DEVICEID = VD_DEVICEID
;

--日次実績更新
DELETE FROM TAT_DB_RESULT_PERSONALIZE
WHERE RPA_SENDDT >= '${pd_base_date}'::DATE + INTERVAL '-8DAYS' OR RPA_SENDDT < DATE_TRUNC('MONTH','${pd_base_date}'::DATE + INTERVAL '-25MONTHS')
;

INSERT INTO TAT_DB_RESULT_PERSONALIZE
SELECT
    TRD_SENDDT AS RPA_SENDDT
    ,TRD_CAMPAIGNID AS RPA_CAMPAIGNID
    ,TRD_CHANNELID AS RPA_CHANNELID
    ,TRD_DEVICEID AS RPA_DEVICEID
    ,TRI_AREATYPEID AS RPA_AREATYPEID
    ,NVL(TRI_CNT_SENDITEM, 0) AS RPA_CNT_SENDITEM
    ,NVL(TRI_CNT_BUY_SENDITEM, 0) AS RPA_CNT_BUY_SENDITEM
    ,NVL(TRI_REVENUE_BUY_SENDITEM, 0) AS RPA_REVENUE_BUY_SENDITEM
    ,NVL(TRI_CNT_FAVORITE_ITEM, 0) AS RPA_CNT_FAVORITE_ITEM
    ,TRD_CNT_SEND AS RPA_CNT_SEND
    ,TRD_CNT_OPEN AS RPA_CNT_OPEN
    ,TRD_CNT_CLICK AS RPA_CNT_CLICK
    ,TRD_CNT_CV AS RPA_CNT_CV
    ,NVL(TRD_REVENUE_TOTAL, 0) AS RPA_REVENUE_TOTAL
FROM
    TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_DAILY
    LEFT OUTER JOIN (
        SELECT
            TRI_SENDDT
            ,TRI_CAMPAIGNID
            ,TRI_CHANNELID
            ,TRI_DEVICEID
            ,TRI_AREATYPEID
            ,COUNT(DISTINCT TRI_UNIQUEGOODSID) AS TRI_CNT_SENDITEM--表示商品数
            ,COUNT(DISTINCT TRI_BUY_UNIQUEGOODSID) AS TRI_CNT_BUY_SENDITEM--購買商品数（1つの配信商品に対しそれが買われたかどうかの数を数えるのでDISTINCTをとる）
            ,SUM(TRI_BUYPRICE) AS TRI_REVENUE_BUY_SENDITEM--購買金額（金額は実績として複数購買の場合も全部対象とするのですべてSUMする）
            ,COUNT(DISTINCT TRI_FAV_UNIQUEGOODSID) AS TRI_CNT_FAVORITE_ITEM--お気に入り登録商品数
        FROM
            TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_ITEM
        GROUP BY
            TRI_SENDDT
            ,TRI_CAMPAIGNID
            ,TRI_CHANNELID
            ,TRI_DEVICEID
            ,TRI_AREATYPEID
    ) AS ITEM ON TRI_SENDDT = TRD_SENDDT
                    AND TRI_CAMPAIGNID = TRD_CAMPAIGNID
                    AND TRI_CHANNELID = TRD_CHANNELID
                    AND TRI_DEVICEID = TRD_DEVICEID
;

CREATE TEMP TABLE TAT_DB_RESULT_HOURLY_TMP_MASTER
(
    TM_CAMPAIGNID INTEGER,
    TM_CHANNELID BYTEINT,
    TM_DEVICEID BYTEINT,
    TM_HOUR BYTEINT
)
DISTRIBUTE ON (TM_CAMPAIGNID, TM_CHANNELID, TM_DEVICEID, TM_HOUR)
;

--時間帯別実績更新
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
        TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
) AS CAMPAIGN
CROSS JOIN TAT_DB_MASTER_DELIVERY_HOUR
;

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
            ,COUNT(DISTINCT NVL(TD_OFFERID, TD_EMAILID)) AS CNT_DELIVERY
        FROM
            TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
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
            ,COUNT(DISTINCT CASE WHEN TD_OPENDT IS NOT NULL AND TD_CHANNELID = 1 AND TD_DEVICEID = 2 THEN NVL(TD_OFFERID, TD_EMAILID) ELSE NULL END) AS CNT_OPEN
        FROM
            TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
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
            TD_CAMPAIGNID
            ,TD_CHANNELID
            ,TD_DEVICEID
            ,DATE_PART('HOUR', TD_CLICKDT) AS HOUR_CLICK
            ,COUNT(DISTINCT CASE WHEN TD_CLICKDT IS NOT NULL THEN TD_OFFERID ELSE NULL END) AS CNT_CLICK
        FROM
            TAT_DB_RESULT_PERSONALIZE_TMP_DELIVERY
        GROUP BY
            TD_CAMPAIGNID
            ,TD_CHANNELID
            ,TD_DEVICEID
            ,HOUR_CLICK
    ) AS CLICKDATA ON TM_CAMPAIGNID = TD_CAMPAIGNID
                                            AND TM_CHANNELID = TD_CHANNELID
                                            AND TM_DEVICEID = TD_DEVICEID
                                            AND TM_HOUR = HOUR_CLICK
;

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
        TAT_DB_RESULT_PERSONALIZE_TMP_RESULT_ITEM
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

--パーソナライズメール及びパーソナルLINEのレコードのみ削除
DELETE FROM TAT_DB_RESULT_HOURLY WHERE RHO_CHANNELID IN (1, 2) AND RHO_CHANNEL_DETAILID = 4
;

INSERT INTO TAT_DB_RESULT_HOURLY
SELECT
    THD_HOUR AS RHO_HOUR
    ,THD_CHANNELID AS RHO_CHANNELID
    ,4 AS RHO_CHANNEL_DETAILID
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

COMMIT
;