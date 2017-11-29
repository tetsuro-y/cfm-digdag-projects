CREATE TABLE TAT_VIACHANNEL_VISITUSER
(
    VC_VISITTIME TIMESTAMP NOT NULL,
    VC_SENDDT DATE,
    VC_CHANNELID BYTEINT NOT NULL,
    VC_CHANNEL_DETAILID BYTEINT,
    VC_CAMPAIGNID INTEGER NOT NULL,
    VC_DEVICEID BYTEINT,
    VC_OSID BYTEINT,
    VC_EMAILID BIGINT,
    VC_OFFERID BIGINT,
    VC_FULLVISITORID NVARCHAR(30),
    VC_TRANSACTIONREVENUE BIGINT
)
DISTRIBUTE ON (VC_VISITTIME, VC_CHANNELID, VC_CHANNEL_DETAILID, VC_CAMPAIGNID);

CREATE TABLE TAT_PARAMETERMAPPING
(
    PM_CHANNELID INTEGER NOT NULL,
    PM_CHANNEL_DETAILID INTEGER,
    PM_PARAMETER NVARCHAR(50) NOT NULL,
    PM_MAPPINGID INTEGER NOT NULL
)
DISTRIBUTE ON (PM_CHANNELID, PM_CHANNEL_DETAILID, PM_PARAMETER);

CREATE TABLE TAT_CHANNELID_MASTER
(
    CM_CHANNELID INTEGER NOT NULL,
    CM_CHANNELNAME NVARCHAR(50) NOT NULL
)
DISTRIBUTE ON (CM_CHANNELID);

CREATE TABLE TAT_CHANNELDETAILID_MASTER
(
    CDM_CHANNEL_DETAILID INTEGER NOT NULL,
    CDM_CHANNEL_DETAILNAME NVARCHAR(50) NOT NULL
)
DISTRIBUTE ON (CDM_CHANNEL_DETAILID);

