SELECT
    MEMBERID
FROM
    (
        SELECT
            MEMBERID
            ,DEVICE_INFO
            ,DEVICE_MOBILEDEVICEMODEL
            ,DEVICE_OS
            ,ROW_NUMBER() OVER(PARTITION BY MEMBERID ORDER BY VISITTIME DESC) AS ROWNUM
        FROM
            (
                SELECT
                     hits.customVariables.customVarValue AS MEMBERID
                    ,device.mobileDeviceInfo as DEVICE_INFO
                    ,device.mobileDeviceModel as DEVICE_MOBILEDEVICEMODEL
                    ,device.operatingSystem as DEVICE_OS
                    ,MAX(STRFTIME_UTC_USEC(visitStartTime * 1000000, "%Y/%m/%d %H:%M:%S")) AS VISITTIME
                FROM
                        table_date_range([109049626.ga_sessions_],timestamp(DATE_ADD(CURRENT_DATE(), -2, 'MONTH')),timestamp(current_date()))
                WHERE
                    hits.customVariables.customVarname = 'memberID'
                    AND device.mobileDeviceModel != '(not set)'
                    AND device.mobileDeviceInfo != '(not set)'
                    AND device.operatingSystem IN ('iOS', 'Android')
                GROUP EACH BY
                MEMBERID
                ,DEVICE_INFO
                ,DEVICE_MOBILEDEVICEMODEL
                ,DEVICE_OS
            ) BASE
    ) BASE
WHERE
    ROWNUM = 1
    AND (
        (
            DEVICE_OS = 'Android'
            AND NOT REGEXP_MATCH(DEVICE_INFO,'.*Galaxy.*(S5|S7|S8).*')
            AND NOT REGEXP_MATCH(DEVICE_INFO,'.*Xperia.*(XZ|X Compact|X Performance).*')
            AND NOT REGEXP_MATCH(DEVICE_INFO,'.*AQUOS.*(R|ZETA).*')
        )
        OR (
            DEVICE_OS = 'iOS'
            AND DEVICE_MOBILEDEVICEMODEL != 'iPhone'
        )
    )