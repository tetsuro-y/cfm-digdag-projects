--SUIT計測エラー（measurement_scanning_error）UID取得※visitStartDate、uid、visitIdごとに一意
SELECT
    visitStartTime as VISITSTARTDT,
    fullVisitorId,
    uid,
    visitId,
    hits.appInfo.version as HITS_APPINFO_VERSION,
    device.mobileDeviceModel as DEVICE_MOBILEDEVICEMODEL,
    device.operatingSystem as DEVICE_OS,
    device.operatingSystemVersion as DEVICE_OSVERSION
FROM
    flatten((
        SELECT
            STRFTIME_UTC_USEC(visitStartTime * 1000000 + 32400000000, "%Y-%m-%d %H:%M:%S") AS visitStartTime,
            fullVisitorId,
            customDimensions.value as uid,
            visitId,
            hits.eventInfo.eventCategory,
            hits.appInfo.version,
            device.mobileDeviceModel,
            device.operatingSystem,
            device.operatingSystemVersion,
            customDimensions.index
        FROM
--過去分全量取得
            table_date_range([90402834.ga_sessions_], timestamp('2018-4-27'),
                                timestamp(current_date()))
            , table_date_range([90303901.ga_sessions_], timestamp('2018-4-27'),
                            timestamp(current_date()))
--             table_date_range([90402834.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -2, 'DAY'),
--                                 timestamp(current_date()))
--             , table_date_range([90303901.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -2, 'DAY'),
--                             timestamp(current_date()))
    ), customDimensions)
WHERE
 REGEXP_MATCH(hits.eventInfo.eventCategory, r'^measurement_scanning_error') IS TRUE 
    AND customDimensions.index = 2
GROUP EACH BY
    visitStartTime,
    fullVisitorId,
    uid,
    visitId,
    hits.appInfo.version,
    device.mobileDeviceModel,
    device.operatingSystem,
    device.operatingSystemVersion
;
