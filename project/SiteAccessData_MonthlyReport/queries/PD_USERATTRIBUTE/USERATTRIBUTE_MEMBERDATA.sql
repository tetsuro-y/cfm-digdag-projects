BEGIN;

CREATE TEMP TABLE TAT_SITE_USERATTRIBUTE_TEMP
(
    SUT_DT DATE,
    SUT_DEVICEID BYTEINT,
    SUT_MEMBERID INTEGER,
    SUT_UID VARCHAR(30)
)
DISTRIBUTE ON (SUT_DT, SUT_DEVICEID, SUT_MEMBERID, SUT_UID);

INSERT INTO TAT_SITE_USERATTRIBUTE_TEMP
SELECT
    SUT_DT
    ,SUT_DEVICEID
    ,SUT_MEMBERID
    ,SUT_UID
FROM
    EXTERNAL '${embulk.file_path2}/${embulk.out_file2}'
USING (DELIM ',' REMOTESOURCE 'JDBC' LOGDIR '/tmp/embulk/puredata/log' MAXERRORS 0)
;

--UIDをMEMBERIDと紐づけてMEMBERIDに統一したデータを作る
CREATE TEMP TABLE TAT_SITE_USERATTRIBUTE_MEMBERID_TEMP
(
    SUMT_DT DATE,
    SUMT_DEVICEID BYTEINT,
    SUMT_MEMBERID INTEGER
)
DISTRIBUTE ON (SUMT_DT, SUMT_DEVICEID, SUMT_MEMBERID);

INSERT INTO TAT_SITE_USERATTRIBUTE_MEMBERID_TEMP
SELECT
    SUT_DT AS SUMT_DT
    ,SUT_DEVICEID AS SUMT_DEVICEID
    ,SUT_MEMBERID AS SUMT_MEMBERID
FROM
    TAT_SITE_USERATTRIBUTE_TEMP
WHERE
    SUT_DEVICEID IN (1, 2)

UNION ALL

SELECT DISTINCT
    SUT_DT AS SUMT_DT
    ,SUT_DEVICEID AS SUMT_DEVICEID
    ,PNMEMBERID AS SUMT_MEMBERID
FROM
    TAT_SITE_USERATTRIBUTE_TEMP
    INNER JOIN TPUSHNOTIFICATION ON SUT_UID = PNUID
WHERE
    SUT_DEVICEID = 3
;

--⑤-2アクセスユーザ属性_性別
--インサート期間のデータを削除
DELETE FROM TAT_SITE_USERATTRIBUTE_SEX
WHERE
    SUS_MONTH < DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-2YEARS')::TIMESTAMP
    OR SUS_MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-1MONTH')::TIMESTAMP
;

--データインサート
INSERT INTO TAT_SITE_USERATTRIBUTE_SEX
SELECT
    DATE_TRUNC('MONTH', SUMT_DT) AS SUS_MONTH
    ,SUS_DEVICEID
    ,SUS_SEXID
    ,SUM(SUS_CNT_MEMBER) AS SUS_CNT_MEMBER
FROM (
    SELECT
        SUMT_DT
        ,SUMT_DEVICEID AS SUS_DEVICEID
        ,MESEXID AS SUS_SEXID
        ,COUNT(DISTINCT SUMT_MEMBERID) AS SUS_CNT_MEMBER
    FROM
        TAT_SITE_USERATTRIBUTE_MEMBERID_TEMP
        INNER JOIN TMEMBER ON SUMT_MEMBERID = MEMEMBERID
    GROUP BY
        SUMT_DT
        ,SUS_DEVICEID
        ,SUS_SEXID
) AS GETDAILYDATA
GROUP BY
    SUS_MONTH
    ,SUS_DEVICEID
    ,SUS_SEXID
;

--⑤-3アクセスユーザ属性_年代
--インサート期間のデータを削除
DELETE FROM TAT_SITE_USERATTRIBUTE_AGE
WHERE
    SUA_MONTH < DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-2YEARS')::TIMESTAMP
    OR SUA_MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-1MONTH')::TIMESTAMP
;

--データインサート
INSERT INTO TAT_SITE_USERATTRIBUTE_AGE
SELECT
    DATE_TRUNC('MONTH', SUMT_DT) AS SUA_MONTH
    ,SUA_DEVICEID
    ,SUA_AGEID
    ,SUM(SUA_CNT_MEMBER) AS SUA_CNT_MEMBER
FROM (
    SELECT
        SUMT_DT
        ,SUMT_DEVICEID AS SUA_DEVICEID
        --前月末時点の年齢とする
        ,CASE
            WHEN MEBIRTHDAY IS NULL OR MEBIRTHDAY = '1900/1/1' THEN 99
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 20 THEN 1
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 25 THEN 2
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 30 THEN 3
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 35 THEN 4
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 40 THEN 5
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 45 THEN 6
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 50 THEN 7
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 55 THEN 8
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) < 60 THEN 9
            WHEN EXTRACT(YEAR FROM AGE(DATE_TRUNC('MONTH', SUMT_DT) + INTERVAL'-1DAY', MEBIRTHDAY)) >= 60 THEN 10
            ELSE NULL
        END AS SUA_AGEID
        ,COUNT(DISTINCT SUMT_MEMBERID) AS SUA_CNT_MEMBER
    FROM
        TAT_SITE_USERATTRIBUTE_MEMBERID_TEMP
        INNER JOIN TMEMBER ON SUMT_MEMBERID = MEMEMBERID
    GROUP BY
        SUMT_DT
        ,SUA_DEVICEID
        ,SUA_AGEID
) AS GETDAILYDATA
GROUP BY
    SUA_MONTH
    ,SUA_DEVICEID
    ,SUA_AGEID
;

--⑤-4アクセスユーザ属性_デシル
--インサート期間のデータを削除
DELETE FROM TAT_SITE_USERATTRIBUTE_DECIL
WHERE
    SUD_MONTH < DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-2YEARS')::TIMESTAMP
    OR SUD_MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-1MONTH')::TIMESTAMP
;

--データインサート
INSERT INTO TAT_SITE_USERATTRIBUTE_DECIL
SELECT
    DATE_TRUNC('MONTH', SUMT_DT) AS SUD_MONTH
    ,SUD_DEVICEID
    ,SUD_DECIL
    ,SUM(SUD_CNT_MEMBER) AS SUD_CNT_MEMBER
FROM (
    SELECT
        SUMT_DT
        ,SUMT_DEVICEID AS SUD_DEVICEID
        ,CASE
            WHEN MEMBERID IS NOT NULL THEN DECIL
            ELSE 99
        END AS SUD_DECIL
        ,COUNT(DISTINCT SUMT_MEMBERID) AS SUD_CNT_MEMBER
    FROM
        TAT_SITE_USERATTRIBUTE_MEMBERID_TEMP
        LEFT OUTER JOIN (
            --前月末から1年間の購入実績対象にデシルをとる
            SELECT
                ORMEMBERID AS MEMBERID
                ,SUM(ODPRICE*ODQUANTITY) AS PRICE
                ,NTILE(10) OVER (ORDER BY PRICE DESC) AS DECIL
            FROM
                TORDER
                INNER JOIN TORDERDETAIL ON ORORDERID = ODORDERID
                INNER JOIN TORDERINFO ON ORORDERID = OIORDERID
            WHERE
                ORORDERDT >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-1MONTH' + INTERVAL'-1YEAR'
                AND ORORDERDT < DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-1MONTH'
                AND ORMALLID = 1
                AND ORORDERID = ORORIGINALORDERID --発送後キャンセルを考慮しない。上記ORORDERSTATUSの-1除外だけでは発送後キャンセルが含まれるためこの指定が必要
                AND ORPAYMENTTYPEID <> 13 --定期便の注文を除外
                --タイツ0円購入を除外
                AND NOT EXISTS (
                    SELECT
                        *
                    FROM
                        TORDERDETAILDISCOUNT--TORDERDETAILDISCOUNTのDISCOUNTTYPEIDでタイツ0円購入を指定できる・ORDISCOUNTだとのちのちお気に入り割引など入ってくるのでこっちが確実
                    WHERE
                        ODORDERDETAILID = ODDORDERDETAILID
                        AND ODDDISCOUNTTYPEID = 2 --1:お気に入り値引き/2:初回タイツ無料/22022:シングル（靴擦れ可）/22023:ダブル（靴擦れ可）/22024:シングル（靴擦れ不可）/22026:ダブル（靴擦れ不可）/22028:タタキ（靴擦れ不可）/22029:裾上げ未指定
                )
                AND ORMEMBERID <> 4388014--ゲスト以外
                AND
                (
                    (OISITEID IN (1,2,3,4) AND OIUID NOT LIKE 'S6%' AND OIUID NOT LIKE 'S9%')--PC/SP
                    OR
                    (OIUID LIKE 'S6%' OR OIUID LIKE 'S9%')--APP
                )
            GROUP BY
                MEMBERID
        ) AS DECIL ON SUMT_MEMBERID = MEMBERID
    GROUP BY
        SUMT_DT
        ,SUD_DEVICEID
        ,SUD_DECIL
) AS GETDAILYDATA
GROUP BY
    SUD_MONTH
    ,SUD_DEVICEID
    ,SUD_DECIL
;

COMMIT;