BEGIN
;

TRUNCATE TABLE TAT_SITE_RANKING_SALES
;

INSERT INTO TAT_SITE_RANKING_SALES
--ショップ別ランキング
SELECT
    MONTH AS SRS_MONTH
    ,1 AS SRS_RANKING_CONTENTSID
    ,SHNAMEEN AS SRS_NAME
    ,SALES AS SRS_SALES
    ,RANK_RESULTS AS SRS_RANK_RESULTS
    ,CASE WHEN MONTH_TO_MONTH_BASIS IS NOT NULL THEN RANK_MONTH_TO_MONTH_BASIS ELSE NULL END AS SRS_RANK_MONTH_TO_MONTH_BASIS
FROM (
    SELECT
        MONTH
        ,SHNAMEEN
        ,SALES
        ,MONTH_TO_MONTH_BASIS
        ,RANK() OVER (ORDER BY SALES DESC) AS RANK_RESULTS
        ,RANK() OVER (ORDER BY MONTH_TO_MONTH_BASIS DESC) AS RANK_MONTH_TO_MONTH_BASIS
    FROM (
        SELECT
            DATE_TRUNC('MONTH', ORORDERDT) AS MONTH
            ,SHNAMEEN
            ,SUM(ODPRICE * ODQUANTITY) AS SALES
            ,LAG(SALES) OVER (PARTITION BY SHNAMEEN ORDER BY MONTH) AS SALES_LAG
            ,ROUND(SALES / SALES_LAG, 4) AS MONTH_TO_MONTH_BASIS
        FROM (
            --ゲスト以外
            SELECT
                ORORDERDT
                ,SHNAMEEN
                ,ODPRICE
                ,ODQUANTITY
            FROM
                TORDER
                INNER JOIN TORDERDETAIL ON ORORDERID = ODORDERID
                INNER JOIN TSHOPSHELF ON ODSHELFID = SSSHELFID
                INNER JOIN TSHOP ON SSSHOPID = SHSHOPID
                INNER JOIN TORDERINFO ON ORORDERID = OIORDERID
            WHERE
                ORORDERDT >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-2MONTHS'
                AND ORORDERDT < DATE_TRUNC('MONTH', CURRENT_DATE)
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

                UNION ALL

                --ゲスト
                 SELECT
                    ORORDERDT
                    ,SHNAMEEN
                    ,ODPRICE
                    ,ODQUANTITY
                FROM
                    TORDER
                    INNER JOIN TORDERDETAIL ON ORORDERID = ODORDERID
                    INNER JOIN TSHOPSHELF ON ODSHELFID = SSSHELFID
                    INNER JOIN TSHOP ON SSSHOPID = SHSHOPID
                    INNER JOIN TORDERONETIMEINFO ON ORORDERID = OOTORDERID
                WHERE
                    ORORDERDT >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-2MONTHS'
                    AND ORORDERDT < DATE_TRUNC('MONTH', CURRENT_DATE)
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
                    AND ORMEMBERID = 4388014--ゲスト
                    AND
                    (
                        (OOTSITEID IN (1,2,3,4) AND OOTUID NOT LIKE 'S6%' AND OOTUID NOT LIKE 'S9%')--PC/SP
                        OR
                        (OOTUID LIKE 'S6%' OR OOTUID LIKE 'S9%')--APP
                    )
            ) AS UNIONDATA
        GROUP BY
            MONTH
            ,SHNAMEEN
    ) AS GETSALES
    WHERE
        MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-1MONTH'
) AS GETRANK

UNION ALL

--ブランド別ランキング
SELECT
    MONTH AS SRS_MONTH
    ,2 AS SRS_RANKING_CONTENTSID
    ,TBNAME AS SRS_NAME
    ,SALES AS SRS_SALES
    ,RANK_RESULTS AS SRS_RANK_RESULTS
    ,CASE WHEN MONTH_TO_MONTH_BASIS IS NOT NULL THEN RANK_MONTH_TO_MONTH_BASIS ELSE NULL END AS SRS_RANK_MONTH_TO_MONTH_BASIS
FROM (
    SELECT
        MONTH
        ,TBNAME
        ,SALES
        ,MONTH_TO_MONTH_BASIS
        ,RANK() OVER (ORDER BY SALES DESC) AS RANK_RESULTS
        ,RANK() OVER (ORDER BY MONTH_TO_MONTH_BASIS DESC) AS RANK_MONTH_TO_MONTH_BASIS
    FROM (
        SELECT
            DATE_TRUNC('MONTH', ORORDERDT) AS MONTH
            ,TBNAME
            ,SUM(ODPRICE * ODQUANTITY) AS SALES
            ,LAG(SALES) OVER (PARTITION BY TBNAME ORDER BY MONTH) AS SALES_LAG
            ,ROUND(SALES / SALES_LAG, 4) AS MONTH_TO_MONTH_BASIS
        FROM (
            --ゲスト以外
            SELECT
                ORORDERDT
                ,TBNAME
                ,ODPRICE
                ,ODQUANTITY
            FROM
                TORDER
                INNER JOIN TORDERDETAIL ON ORORDERID = ODORDERID
                INNER JOIN TSHOPSHELF ON ODSHELFID = SSSHELFID
                INNER JOIN TSHOP ON SSSHOPID = SHSHOPID
                INNER JOIN TGOODSDETAIL ON SSGOODSDETAILID = GDGOODSDETAILID
                INNER JOIN TGOODSBRAND ON GDGOODSID = GBGOODSID
                INNER JOIN TTAGBRAND ON GBTAGBRANDID = TBTAGBRANDID
                INNER JOIN TORDERINFO ON ORORDERID = OIORDERID
            WHERE
                ORORDERDT >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-2MONTHS'
                AND ORORDERDT < DATE_TRUNC('MONTH', CURRENT_DATE)
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
                AND GBDEFAULTFLAG = 1--デフォルトで紐づけられているブランドに絞る

                UNION ALL

                --ゲスト
                SELECT
                    ORORDERDT
                    ,TBNAME
                    ,ODPRICE
                    ,ODQUANTITY
                FROM
                    TORDER
                    INNER JOIN TORDERDETAIL ON ORORDERID = ODORDERID
                    INNER JOIN TSHOPSHELF ON ODSHELFID = SSSHELFID
                    INNER JOIN TSHOP ON SSSHOPID = SHSHOPID
                    INNER JOIN TGOODSDETAIL ON SSGOODSDETAILID = GDGOODSDETAILID
                    INNER JOIN TGOODSBRAND ON GDGOODSID = GBGOODSID
                    INNER JOIN TTAGBRAND ON GBTAGBRANDID = TBTAGBRANDID
                    INNER JOIN TORDERONETIMEINFO ON ORORDERID = OOTORDERID
                WHERE
                    ORORDERDT >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-2MONTHS'
                    AND ORORDERDT < DATE_TRUNC('MONTH', CURRENT_DATE)
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
                    AND ORMEMBERID = 4388014--ゲスト
                    AND
                    (
                        (OOTSITEID IN (1,2,3,4) AND OOTUID NOT LIKE 'S6%' AND OOTUID NOT LIKE 'S9%')--PC/SP
                        OR
                        (OOTUID LIKE 'S6%' OR OOTUID LIKE 'S9%')--APP
                    )
                    AND GBDEFAULTFLAG = 1--デフォルトで紐づけられているブランドに絞る
        ) AS UNIONDATA
        GROUP BY
            MONTH
            ,TBNAME
    ) AS GETSALES
    WHERE
        MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-1MONTH'
) AS GETRANK
;

COMMIT
;