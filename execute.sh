#!/usr/bin/env bash

source $(cd $(dirname $0) && pwd)/env.sh
source $(cd $(dirname $0) && pwd)/option_check.sh

# SERVER SETTING
case "$(uname -s)" in
    Linux*)     machine=linux;;
    Darwin*)    machine=mac;;
    CYGWIN*)    machine=cygwin;;
    MINGW*)     machine=mingw;;
    *)          machine="other"
esac

if [ "${machine}" = "cygwin"  ] || [ "${machine}" = "mingw"  ]; then
    DIGDAG=digdag.bat
else
    DIGDAG=digdag
fi

echo "#!/usr/bin/env bash"

# プロジェクトの登録
echo "${DIGDAG} push ${PJ_NAME} --project ${PJ_DIR} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER}"
#${DIGDAG} push ${PJ_NAME} --project ${PJ_DIR} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER} || exit 1

# bigqueryのアクセスキーを設定します
echo "cp ${KEY_PATH} ."
filename=$(basename ${KEY_PATH} | grep -e zozo -e json | head -1)

if [ "${machine}" = "cygwin"  ] || [ "${machine}" = "mingw"  ]; then
    echo "cmd.exe /c \"digdag secrets --project ${PJ_NAME} --set \\\"gcp.credential=@${filename}\\\" --endpoint ${DIGDAG_SERVER}\""
else
    echo "${DIGDAG} secrets --project ${PJ_NAME} --set gcp.credential=@${filename} --endpoint ${DIGDAG_SERVER}"
fi

echo "rm ${filename}"

# ワークフローのテスト(dry-run)
echo "${DIGDAG} start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} ${PJ_OPTION}"
#${DIGDAG} start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} ${PJ_OPTION}