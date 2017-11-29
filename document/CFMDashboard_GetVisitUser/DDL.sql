CREATE TABLE TAT_VIACHANNEL_VISITUSER
(
    VC_VISITTIME TIMESTAMP NOT NULL,
    VC_SENDDT DATE,
    VC_CHANNEL BYTEINT NOT NULL,
    VC_CHANNEL_DETAIL BYTEINT,
    VC_CAMPAIGNID INTEGER NOT NULL,
    VC_DEVICE BYTEINT,
    VC_OS BYTEINT,
    VC_EMAILID BIGINT,
    VC_OFFERID BIGINT,
    VC_FULLVISITORID NVARCHAR(30),
    VC_TRANSACTIONREVENUE BIGINT
)
DISTRIBUTE ON (VC_VISITTIME, VC_CHANNEL, VC_CHANNEL_DETAIL, VC_CAMPAIGNID);

CREATE TABLE TAT_PARAMETERMAPPING
(
    PM_CHANNEL INTEGER NOT NULL,
    PM_CHANNEL_DETAIL INTEGER,
    PM_PARAMETER NVARCHAR(50) NOT NULL,
    PM_MAPPINGID INTEGER NOT NULL
)
DISTRIBUTE ON (PM_CHANNEL, PM_CHANNEL_DETAIL, PM_PARAMETER);

CREATE TABLE TAT_CHANNELIDMASTER
(
    CM_CHANNEL INTEGER NOT NULL,
    CM_DEFINITION NVARCHAR(50) NOT NULL
)
DISTRIBUTE ON (CM_CHANNEL);

CREATE TABLE TAT_CHANNELDETAILIDMASTER	
(
    CDM_CHANNEL_DETAIL INTEGER NOT NULL,
    CDM_DEFINITION NVARCHAR(50) NOT NULL
)
DISTRIBUTE ON (CDM_CHANNEL_DETAIL);

