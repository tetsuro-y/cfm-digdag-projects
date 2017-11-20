/************************

ユーザマージ構築

*************************/
SELECT
    FL_FULLVISITORID AS FULLVISITORID
    ,FL_MEMBERID AS MEMBERID
    ,FL_ACCESSDT AS ACCESSDT
FROM (--ユーザーごと1つ前のアクセスを取得
    SELECT
        FULLVISITORID AS FL_FULLVISITORID
        ,MEMBERID AS FL_MEMBERID
        ,ACCESSDT AS FL_ACCESSDT
        ,LAG(MEMBERID, 1)OVER(PARTITION BY FULLVISITORID ORDER BY ACCESSDT) AS FL_LAGMEMBERID
    FROM (--FULLVISITORID、MEMBERIDごとの訪問日取得
        SELECT
            EB_FULLVISITORID AS FULLVISITORID
            ,MEMBERID
            ,EB_ACCESSDT AS ACCESSDT
        FROM (
            SELECT
                  VB_FULLVISITORID AS EB_FULLVISITORID
                  ,INTEGER(VB_EMAILID) AS EB_EMAILID
                  ,VB_DATE AS EB_ACCESSDT
            FROM (
                --②マスメール、新着メールからの流入
                SELECT
                    FULLVISITORID AS VB_FULLVISITORID
                    ,CASE
                        WHEN LENGTH(trafficsource.campaign) >= 16 AND trafficsource.source NOT IN ('ni_m', 'ni_u_m') --town新着またはused新着以外
                            THEN REGEXP_REPLACE(trafficsource.campaign, r'^\d+_(pc|mo)_(w|m|o)_((.*_)+|\d{1,3}_|)', '')
                        WHEN LENGTH(trafficsource.campaign) >= 19 AND trafficsource.source IN ('ni_m', 'ni_u_m') ----town新着またはused新着
                            THEN SUBSTR(trafficsource.campaign, 13, LENGTH(trafficsource.campaign) - (LENGTH(REGEXP_REPLACE(trafficsource.campaign, r'^\d+', '')) + 12))--キャンペーンの値から日付+_以降の値を引く
                        ELSE NULL
                    END AS VB_EMAILID
                    ,FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS VB_DATE
                FROM
                    TABLE_DATE_RANGE([109049626.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'),CURRENT_TIMESTAMP()) --昨日の実績
                WHERE
                    trafficsource.medium = 'mailmag'
                    AND trafficsource.source NOT IN('ios','android') --ウェブビュー除外（念のため）
                    AND REGEXP_MATCH(hits.page.pagePath,r'^zozo\.jp/sp/app/(brand/(default\.html)*|category/category_list\.html)') IS FALSE--ウェブビュー除外（念のため）
                    AND visitStartTime IS NOT NULL
                GROUP BY
                    VB_FULLVISITORID
                    ,VB_EMAILID
                    ,VB_DATE
            ) AS VISIT_BASE /*PREFIX=VB*/
            WHERE
                  VB_EMAILID IS NOT NULL
        ) AS EMAIL_BASE /*PREFIX=EB*/
        INNER JOIN [durable-binder-547:temp.MEMBER_LIST] AS MEMBER_LIST ON EB_EMAILID = EMAILID
        WHERE
              EB_ACCESSDT IS NOT NULL
        GROUP BY
            FULLVISITORID
            ,MEMBERID
            ,ACCESSDT
    )
    ,(--③Pメール、LINE、サイト流入
      SELECT
        FULLVISITORID
        ,INTEGER(MEMBERID) AS MEMBERID
        ,VISIT_DATE AS ACCESSDT
      FROM (
        SELECT
            FULLVISITORID
            ,hits.customVariables.customVarValue AS MEMBERID
            ,FORMAT_UTC_USEC(visitStartTime*  1000000+ 32400000000) AS VISIT_DATE
        FROM
            TABLE_DATE_RANGE([109049626.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'),CURRENT_TIMESTAMP()) --昨日の実績
        WHERE
            trafficsource.medium <> 'mailmag' --マスメール除外
            AND trafficsource.source NOT IN ('ni_m', 'ni_u_m')--新着除外
            AND trafficsource.source NOT IN('ios','android') --ウェブビュー除外（念のため）
            AND REGEXP_MATCH(hits.page.pagePath,r'^zozo\.jp/sp/app/(brand/(default\.html)*|category/category_list\.html)') IS FALSE--ウェブビュー除外（念のため）
            AND REGEXP_MATCH(hits.customVariables.customVarname,r'(memberId|memberID)')
            AND visitStartTime IS NOT NULL
        GROUP EACH BY
            FULLVISITORID
            ,MEMBERID
            ,VISIT_DATE
      ) AS OTHER_VISIT /*PREFIX=OB*/
      GROUP EACH BY
        FULLVISITORID
        ,MEMBERID
        ,ACCESSDT
    )
) AS LAG_VISIT /*PREFIX=FL*/
WHERE
    FL_MEMBERID <> FL_LAGMEMBERID --1つまえのMEMEBERIDが同じレコードは除く
    OR FL_LAGMEMBERID IS NULL --最初のMEMBERIIDを残す
