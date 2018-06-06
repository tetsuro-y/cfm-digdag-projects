BEGIN
;

CREATE TEMP TABLE TAT_DB_RESULT_MASSLINE_TMP_TERM AS
SELECT
    DATE_TRUNC('MONTH', CURRENT_DATE) + INTERVAL '-25MONTHS' AS TT_STARTDT
    ,CURRENT_DATE AS TT_ENDDT
;

DELETE FROM TAT_DB_RESULT_MASSLINE
WHERE
    (
        (
            RML_SENDDT >= (SELECT TT_STARTDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
            AND
            RML_SENDDT < (SELECT TT_ENDDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
        )
        AND RML_SENDDT IS NOT NULL
    )
    OR
    (
        (
            RML_VISITDT >= (SELECT TT_STARTDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
            AND
            RML_VISITDT < (SELECT TT_ENDDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
        )
        AND RML_VISITDT IS NOT NULL
    )
;

-------------------------------
--マスLINEの集計結果をINSERT
-------------------------------
INSERT INTO TAT_DB_RESULT_MASSLINE
SELECT
    HVU_CHANNEL_DETAILID AS RML_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID AS RML_CAMPAIGNID
    ,HVU_SENDDT AS RML_SENDDT
    ,NULL AS RML_VISITDT
    ,COUNT(DISTINCT HVU_FULLVISITORID) AS RML_CNT_CLICK
    ,SUM(HVU_REVENUE) AS RML_REVENUE_TOTAL
FROM
    TAT_DB_HISTORY_VISIT_USER
WHERE
    HVU_SENDDT >= (SELECT TT_STARTDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
    AND HVU_SENDDT < (SELECT TT_ENDDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
    AND HVU_CHANNELID = 2--LINE
    AND HVU_CHANNEL_DETAILID IN (2,5)--マス,タイムライン
    AND HVU_VISITTIME >= HVU_SENDDT::TIMESTAMP
GROUP BY
    RML_CHANNEL_DETAILID
    ,RML_CAMPAIGNID
    ,RML_SENDDT
    ,RML_VISITDT

UNION ALL

SELECT
    HVU_CHANNEL_DETAILID AS RML_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID AS RML_CAMPAIGNID
    ,NULL AS RML_SENDDT
    ,HVU_VISITTIME::DATE AS RML_VISITDT
    ,COUNT(DISTINCT HVU_FULLVISITORID) AS RML_CNT_CLICK
    ,SUM(HVU_REVENUE) AS RML_REVENUE_TOTAL
FROM
    TAT_DB_HISTORY_VISIT_USER
WHERE
    HVU_SENDDT >= (SELECT TT_STARTDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
    AND HVU_SENDDT < (SELECT TT_ENDDT FROM TAT_DB_RESULT_MASSLINE_TMP_TERM)
    AND HVU_CHANNELID = 2--LINE
    AND HVU_CHANNEL_DETAILID = 6--リッチメニュー
GROUP BY
    RML_CHANNEL_DETAILID
    ,RML_CAMPAIGNID
    ,RML_SENDDT
    ,RML_VISITDT
;

COMMIT
;