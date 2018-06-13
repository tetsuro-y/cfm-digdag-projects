BEGIN;

CREATE TEMP TABLE TBQ_MEASUREMENT_SCANNING_ERROR_UID_TEMP
(
	VISITSTARTDT TIMESTAMP NOT NULL,
	FULLVISITORID CHARACTER VARYING(100) NOT NULL,
	UID CHARACTER VARYING(100) NOT NULL,
	VISITID CHARACTER VARYING(50) NOT NULL,
	EVENTCATEGORY CHARACTER VARYING(60),
	HITS_APPINFO_VERSION CHARACTER VARYING(20),
	DEVICE_MARKETINGNAME CHARACTER VARYING(60),
	DEVICE_INFO CHARACTER VARYING(100),
	DEVICE_MOBILEDEVICEMODEL CHARACTER VARYING(50),
	DEVICE_OS CHARACTER VARYING(50),
	DEVICE_OSVERSION CHARACTER VARYING(20)
)
DISTRIBUTE ON (VISITSTARTDT, UID, VISITID, EVENTCATEGORY);

INSERT INTO TBQ_MEASUREMENT_SCANNING_ERROR_UID_TEMP
SELECT
    VISITSTARTDT
    ,FULLVISITORID
    ,UID
    ,VISITID
    ,EVENTCATEGORY
    ,HITS_APPINFO_VERSION
    ,DEVICE_MARKETINGNAME
    ,DEVICE_INFO
    ,DEVICE_MOBILEDEVICEMODEL
    ,DEVICE_OS
    ,DEVICE_OSVERSION
FROM
    EXTERNAL '${embulk.file_path}/${embulk.out_file}'
USING (DELIM ',' REMOTESOURCE 'JDBC' LOGDIR '/tmp/embulk/puredata/log')
;

--運用時使用クエリ
DELETE FROM TBQ_MEASUREMENT_SCANNING_ERROR_UID
WHERE
    VISITSTARTDT BETWEEN (
                SELECT
                    MIN(VISITSTARTDT)
                FROM
                    TBQ_MEASUREMENT_SCANNING_ERROR_UID_TEMP
                )
            AND (
                SELECT
                    MAX(VISITSTARTDT)
                FROM
                    TBQ_MEASUREMENT_SCANNING_ERROR_UID_TEMP
                )
;

INSERT INTO TBQ_MEASUREMENT_SCANNING_ERROR_UID
SELECT
    VISITSTARTDT
    ,FULLVISITORID
    ,UID
    ,VISITID
    ,EVENTCATEGORY
    ,HITS_APPINFO_VERSION
    ,DEVICE_MARKETINGNAME
    ,DEVICE_INFO
    ,DEVICE_MOBILEDEVICEMODEL
    ,DEVICE_OS
    ,DEVICE_OSVERSION
FROM
    TBQ_MEASUREMENT_SCANNING_ERROR_UID_TEMP
;

COMMIT
;