CALL NZA..DROP_TABLE('TAT_SAITO_LOADTEST_20171010');

CREATE TABLE TAT_SAITO_LOADTEST_20171010 (
    FULLVISITORID VARCHAR(30) NOT NULL
    ,MEMBERID INTEGER DEFAULT NULL
    ,ACCESSDT TIMESTAMP DEFAULT NULL
) DISTRIBUTE ON RANDOM;

BEGIN;
-- ②ファイルからデータの読み込み
CREATE TEMP TABLE TAT_SAITO_LOADTEST_20171010_TMP AS
  SELECT
    FULLVISITORID
    ,MEMBERID
    ,ACCESSDT
  from
  -- TODO 下記のパスを適度最適な場所に変更する
  EXTERNAL '/tmp/embulk/digdag_export_sample/loadfile_digdag_export_sample.csv'
  (
    FULLVISITORID VARCHAR(30)
    ,MEMBERID NUMERIC(19,4)
    ,ACCESSDT TIMESTAMP
  )
  USING (DELIM ',' REMOTESOURCE 'JDBC' LOGDIR '/tmp/embulk/puredata/log'); -- skipRows 1

INSERT INTO TAT_SAITO_LOADTEST_20171010
SELECT * FROM TAT_SAITO_LOADTEST_20171010_TMP;
;
COMMIT;
