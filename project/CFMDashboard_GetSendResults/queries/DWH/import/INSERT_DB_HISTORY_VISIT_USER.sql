BEGIN;

CREATE TEMP TABLE TAT_DB_HISTORY_VISIT_USER_TEMP
(
    HVU_SENDDT DATE,
    HVU_CHANNELID BYTEINT,
    HVU_CHANNEL_DETAILID BYTEINT,
    HVU_CAMPAIGNID INTEGER,
    HVU_DEVICEID BYTEINT,
    HVU_OSID BYTEINT,
    HVU_FULLVISITORID VARCHAR(30),
    HVU_EMAILID BIGINT,
    HVU_OFFERID BIGINT,
    HVU_VISITTIME TIMESTAMP,
    HVU_REVENUE BIGINT
)
DISTRIBUTE ON (HVU_VISITTIME, HVU_CHANNELID, HVU_CHANNEL_DETAILID, HVU_CAMPAIGNID);

INSERT INTO TAT_DB_HISTORY_VISIT_USER_TEMP
SELECT
    HVU_SENDDT::DATE
    ,HVU_CHANNELID
    ,HVU_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID
    ,HVU_DEVICEID
    ,HVU_OSID
    ,HVU_FULLVISITORID
    ,HVU_EMAILID
    ,HVU_OFFERID
    ,HVU_VISITTIME
    ,HVU_REVENUE
FROM
	EXTERNAL '/tmp/embulk/cfmdashboard_getvisituser/CFMDashboard_GetVisitUser.csv'
USING (DELIM ',' REMOTESOURCE 'JDBC' LOGDIR '/tmp/embulk/puredata/log');

DELETE FROM TAT_DB_HISTORY_VISIT_USER
WHERE
    HVU_VISITTIME BETWEEN (SELECT MIN(HVU_VISITTIME) FROM TAT_DB_HISTORY_VISIT_USER_TEMP) AND (SELECT MAX(HVU_VISITTIME) FROM TAT_DB_HISTORY_VISIT_USER_TEMP)
    OR HVU_VISITTIME < DATE_TRUNC('MONTH', CURRENT_DATE + INTERVAL '-25MONTHS')::TIMESTAMP;

INSERT INTO TAT_DB_HISTORY_VISIT_USER
SELECT
    HVU_SENDDT::DATE
    ,HVU_CHANNELID
    ,HVU_CHANNEL_DETAILID
    ,HVU_CAMPAIGNID
    ,HVU_DEVICEID
    ,HVU_OSID
    ,HVU_FULLVISITORID
    ,HVU_EMAILID
    ,HVU_OFFERID
    ,HVU_VISITTIME
    ,HVU_REVENUE
FROM
	TAT_DB_HISTORY_VISIT_USER_TEMP;

COMMIT;