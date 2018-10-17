CREATE EXTERNAL TABLE '/tmp/puredata/alert/dropsession/result/drop_list.tsv'
USING (
    DELIMITER '\t'
    NULLVALUE ''
    DATEDELIM '/'
    ENCODING 'INTERNAL'
    ESCAPECHAR '\'
    TIMESTYLE '24HOUR'
    REMOTESOURCE 'JDBC'
    LOGDIR '/tmp/puredata/alert/dropsession/log'
) AS
SELECT
    SESSION_ID AS EX_SESSIONID
    ,SESSION_CONNTIME AS EX_START_DT
    ,SESSION_DBNAME AS EX_DBNAME
    ,SESSION_USERNAME AS EX_USERNAME
    ,SESSION_COMMAND AS EX_QUERY
    ,EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - (SESSION_CONNTIME::TIMESTAMP + INTERVAL '9 HOURS'))) AS EX_RUNNING_DURATION
FROM
    (
        SELECT 
            ID AS SESSION_ID
            ,PID AS SESSION_PID
            ,USERNAME AS SESSION_USERNAME
            ,DBNAME AS SESSION_DBNAME
            ,"TYPE" AS SESSION_TYPE
            ,CONNTIME AS SESSION_CONNTIME
            ,STATUS AS SESSION_STATUS
            ,TRANSLATE(TRANSLATE(TRANSLATE(SUBSTR(COMMAND,1,200), CHR(10),' '), CHR(9),' '), '?', '') AS SESSION_COMMAND
            ,PRIORITY AS SESSION_PRIORITY
            ,CID AS SESSION_CID
            ,IPADDR AS SESSION_IPADDR
        FROM 
            _V_SESSION
    ) BASE
WHERE
    SESSION_STATUS = 'active'
AND SESSION_USERNAME NOT IN ('ADMIN', 'ZOZO_CRM', 'ZOZO_KPIREPORT', 'ZOZO_REPORT', 'DIGDAG')
AND (SESSION_CONNTIME::TIMESTAMP + INTERVAL '9 HOURS') <= CURRENT_TIMESTAMP + INTERVAL '-60 MINUTES'
ORDER BY
    EX_RUNNING_DURATION DESC
;
