#!/usr/bin/env bash

# for windows using MYNGW64
export MSYS2_ARG_CONV_EXCL="*"
export MSYS_NO_PATHCONV=1

# evaluate parameters
if [ $# -ne 2 ]; then
    echo "[ERROR] Invalid num of parameter. Should be 1) path, 2) server."
    exit
fi

# evaluate project path
if ls $1/*.dig 1> /dev/null 2>&1; then
    echo ".dig file for project exists"

    # get project dir
    PJ_DIR=$(cd $(dirname $1/dummy) && pwd)
else
    echo "files do not exist"
    exit
fi

# evaluate environment
if [ "$2" = "10.201.161.10:65432" ]; then
    export DIGDAG_SERVER=10.201.161.10:65432
    export EXECUTE_ENV=Development
elif [ "$2" = "10.201.161.10:23456" ]; then
    export DIGDAG_SERVER=10.201.161.10:23456
    export EXECUTE_ENV=Production
elif [ "$2" = "localhost:65432" ]; then
    export DIGDAG_SERVER=localhost:65432
    export EXECUTE_ENV=Development
elif [ "$2" = "localhost:23456" ]; then
    export DIGDAG_SERVER=localhost:23456
    export EXECUTE_ENV=Production
else
    echo "server setting does not exist"
    exitく
fi

export PJ_NAME=$(basename ${PJ_DIR})

echo PJ_DIR=${PJ_DIR}
echo PJ_NAME=${PJ_NAME}
echo DIGDAG_SERVER=${DIGDAG_SERVER}