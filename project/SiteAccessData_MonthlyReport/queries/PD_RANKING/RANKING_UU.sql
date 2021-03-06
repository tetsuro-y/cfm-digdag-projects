BEGIN;

--PC・SPの流入実績
CREATE TEMP TABLE TAT_SITE_RANKING_UU_WEB_TEMP (
    SRU_MONTH DATE,
    SRU_RANKING_CONTENTSID BYTEINT,
    SRU_NAME NVARCHAR(100),
    SRU_CNT_USER INTEGER
) DISTRIBUTE ON (SRU_MONTH, SRU_RANKING_CONTENTSID, SRU_NAME)
;

--APPの流入実績
CREATE TEMP TABLE TAT_SITE_RANKING_UU_APP_TEMP (
    SRU_MONTH DATE,
    SRU_BRANDID INTEGER,
    SRU_CNT_USER INTEGER
) DISTRIBUTE ON (SRU_MONTH, SRU_BRANDID)
;

INSERT INTO TAT_SITE_RANKING_UU_WEB_TEMP
SELECT
    SRU_MONTH::DATE,
    SRU_RANKING_CONTENTSID,
    SRU_NAME,
    SRU_CNT_USER
FROM
    EXTERNAL '${embulk.file_path1}/${embulk.out_file1}'
USING (DELIM ',' REMOTESOURCE 'JDBC' LOGDIR '/tmp/embulk/puredata/log' MAXERRORS 0)
;

INSERT INTO TAT_SITE_RANKING_UU_APP_TEMP
SELECT
    SRU_MONTH::DATE,
    SRU_BRANDID,
    SRU_CNT_USER
FROM
    EXTERNAL '${embulk.file_path2}/${embulk.out_file2}'
USING (DELIM ',' REMOTESOURCE 'JDBC' LOGDIR '/tmp/embulk/puredata/log' MAXERRORS 0)
;

TRUNCATE TABLE TAT_SITE_RANKING_UU
;

INSERT INTO TAT_SITE_RANKING_UU
--ショップ別ランキング
SELECT
    SRU_MONTH
    ,1 AS SRU_RANKING_CONTENTSID
    ,SRU_NAME
    ,SRU_CNT_USER
    ,RANK_RESULTS AS SRU_RANK_RESULTS
    ,CASE WHEN MONTH_TO_MONTH_BASIS IS NOT NULL THEN RANK_MONTH_TO_MONTH_BASIS ELSE NULL END AS SRU_RANK_MONTH_TO_MONTH_BASIS
FROM (
    SELECT
        SRU_MONTH
        ,SRU_NAME
        ,SRU_CNT_USER
        ,MONTH_TO_MONTH_BASIS
        ,RANK() OVER (ORDER BY SRU_CNT_USER DESC) AS RANK_RESULTS
        ,RANK() OVER (ORDER BY MONTH_TO_MONTH_BASIS DESC) AS RANK_MONTH_TO_MONTH_BASIS
    FROM (
        SELECT
            SRU_MONTH
            ,SHNAMEEN AS SRU_NAME
            ,SRU_CNT_USER
            ,LAG(SRU_CNT_USER) OVER (PARTITION BY SRU_NAME ORDER BY SRU_MONTH) AS UUCNT_LAG
            ,ROUND(SRU_CNT_USER * 1.0 / UUCNT_LAG, 4) AS MONTH_TO_MONTH_BASIS
        FROM (
            SELECT
                SRU_MONTH
                ,SRU_RANKING_CONTENTSID
                ,'shop/' || SRU_NAME AS SRU_NAME
                ,SRU_CNT_USER
            FROM
                TAT_SITE_RANKING_UU_WEB_TEMP
            WHERE
                SRU_RANKING_CONTENTSID = 1--ショップ
             ) AS TEMP
            INNER JOIN TSHOP ON SRU_NAME = SHZOZOPATH
        WHERE
            SHOPENFLAG IS TRUE
            AND SHMALLID = 1
    ) AS GETLAG
WHERE
    SRU_MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-1MONTH'
) AS GETRANK

UNION ALL
    
--ブランド別ランキング
SELECT
    SRU_MONTH
    ,2 AS SRU_RANKING_CONTENTSID
    ,SRU_NAME
    ,SRU_CNT_USER
    ,RANK_RESULTS AS SRU_RANK_RESULTS
    ,CASE WHEN MONTH_TO_MONTH_BASIS IS NOT NULL THEN RANK_MONTH_TO_MONTH_BASIS ELSE NULL END AS SRU_RANK_MONTH_TO_MONTH_BASIS
FROM (
    SELECT
        SRU_MONTH
        ,SRU_NAME
        ,SRU_CNT_USER
        ,MONTH_TO_MONTH_BASIS
        ,RANK() OVER (ORDER BY SRU_CNT_USER DESC) AS RANK_RESULTS
        ,RANK() OVER (ORDER BY MONTH_TO_MONTH_BASIS DESC) AS RANK_MONTH_TO_MONTH_BASIS
    FROM (
        SELECT
            SRU_MONTH
            ,SRU_NAME
            ,SRU_CNT_USER
            ,LAG(SRU_CNT_USER) OVER (PARTITION BY SRU_NAME ORDER BY SRU_MONTH) AS UUCNT_LAG
            ,ROUND(SRU_CNT_USER * 1.0 / UUCNT_LAG, 4) AS MONTH_TO_MONTH_BASIS
        FROM (
            SELECT
                SRU_MONTH
                ,SRU_NAME
                ,SUM(SRU_CNT_USER) AS SRU_CNT_USER
            FROM (
                --WEB
                SELECT
                    SRU_MONTH
                    ,TBNAME AS SRU_NAME
                    ,SRU_CNT_USER
                FROM
                    TAT_SITE_RANKING_UU_WEB_TEMP
                    INNER JOIN TTAGBRAND ON SRU_NAME = TBBRANDFILENAME
                WHERE
                    SRU_RANKING_CONTENTSID = 2--ブランド

                UNION ALL

                --APP
                SELECT
                    SRU_MONTH
                    ,TBNAME AS SRU_NAME
                    ,SRU_CNT_USER
                FROM
                    TAT_SITE_RANKING_UU_APP_TEMP
                    INNER JOIN TTAGBRAND ON SRU_BRANDID = TBTAGBRANDID
            ) AS UNIONDATA
            GROUP BY
                SRU_MONTH
                ,SRU_NAME
        ) AS GETSUM
    ) AS GETLAG
WHERE
    SRU_MONTH >= DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL'-1MONTH'
) AS GETRANK
;

COMMIT
;