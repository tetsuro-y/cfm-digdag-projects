--SUIT計測エラー（measurementのスクリーンかつイベントカテゴリにerrorの文字列が含まれるアクセス）UID取得
SELECT
    visitStartTime as VISITSTARTDT,
    fullVisitorId,
    uid,
    visitId,
    hits.eventInfo.eventCategory as EVENTCATEGORY,
    hits.appInfo.version as HITS_APPINFO_VERSION,
    device.mobileDeviceMarketingName as DEVICE_MARKETINGNAME,
    device.mobileDeviceInfo as DEVICE_INFO,
    device.mobileDeviceModel as DEVICE_MOBILEDEVICEMODEL,
    device.operatingSystem as DEVICE_OS,
    device.operatingSystemVersion as DEVICE_OSVERSION
FROM
    flatten((
        SELECT
            STRFTIME_UTC_USEC(visitStartTime * 1000000, "%Y-%m-%d %H:%M:%S") AS visitStartTime,
            fullVisitorId,
            customDimensions.value as uid,
            visitId,
            hits.eventInfo.eventCategory,
            hits.appInfo.version,
            device.mobileDeviceInfo,
            device.mobileDeviceMarketingName,
            device.mobileDeviceModel,
            device.operatingSystem,
            device.operatingSystemVersion,
            customDimensions.index
        FROM
--過去分全量取得
--             table_date_range([90402834.ga_sessions_], timestamp('2018-4-27'),
--                                 timestamp(current_date()))
--             , table_date_range([90303901.ga_sessions_], timestamp('2018-4-27'),
--                             timestamp(current_date()))
            table_date_range([90402834.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -2, 'DAY'),
                                timestamp(current_date()))
            , table_date_range([90303901.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -2, 'DAY'),
                            timestamp(current_date()))
    ), customDimensions)
WHERE
    REGEXP_MATCH(hits.eventInfo.eventCategory, r'^measurement_.*error.*') IS TRUE
    AND customDimensions.index = 2
GROUP EACH BY
    VISITSTARTDT,
    fullVisitorId,
    uid,
    visitId,
    EVENTCATEGORY,
    HITS_APPINFO_VERSION,
    DEVICE_MARKETINGNAME,
    DEVICE_INFO,
    DEVICE_MOBILEDEVICEMODEL,
    DEVICE_OS,
    DEVICE_OSVERSION
;
