SELECT
    visitStartTime,
    uid,
    device.mobileDeviceInfo as DEVICE_INFO,
    device.mobileDeviceModel as DEVICE_MOBILEDEVICEMODEL,
    device.operatingSystem as DEVICE_OS
FROM
    (
        SELECT
            visitStartTime,
            uid,
            device.mobileDeviceInfo,
            device.mobileDeviceModel,
            device.operatingSystem,
            ROW_NUMBER() OVER(PARTITION BY uid ORDER BY visitStartTime DESC) AS ROWNUM
        FROM
            flatten((
                SELECT
                    STRFTIME_UTC_USEC(visitStartTime * 1000000, "%Y-%m-%d %H:%M:%S") AS visitStartTime,
                    customDimensions.value as uid,
                    device.mobileDeviceInfo,
                    device.mobileDeviceModel,
                    device.operatingSystem,
                    customDimensions.index
                FROM
                    --過去分全量取得
                    table_date_range([90402834.ga_sessions_], timestamp('2018-4-27'), timestamp(current_date()))
                    ,table_date_range([90303901.ga_sessions_], timestamp('2018-4-27'), timestamp(current_date()))
                WHERE
                    (
                        device.operatingSystem = 'Android'
                    AND NOT REGEXP_MATCH(device.mobileDeviceInfo,'.*Galaxy.*(S5|S7|S8).*')
                    AND NOT REGEXP_MATCH(device.mobileDeviceInfo,'.*Xperia.*(XZ|X Compact|X Performance).*')
                    AND NOT REGEXP_MATCH(device.mobileDeviceInfo,'.*AQUOS.*(R|ZETA|sense).*')
                    )
                    OR (
                        device.operatingSystem = 'iOS'
                    AND device.mobileDeviceModel != 'iPhone'
                    )
            ), customDimensions)
        WHERE
            customDimensions.index = 2
    ) BASE
WHERE
    ROWNUM = 1
