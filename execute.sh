#!/usr/bin/env bash

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
    PJ_NAME=$(echo ${PJ_NAME} | sed -e 's/^\///' -e 's/\//\\/g' -e 's/^./\0:/')
else
    DIGDAG=digdag
fi

# プロジェクトの登録
echo "digdag push ${PJ_NAME} --project ${PJ_DIR} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER}"
${DIGDAG} push ${PJ_NAME} --project ${PJ_DIR} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER} || exit 1

# bigqueryのアクセスキーを設定します
cp ~/git/zozo-e62ae29b6c4f_cfm.json .
${DIGDAG} secrets --project ${PJ_NAME} --set gcp.credential=@zozo-e62ae29b6c4f_cfm.json --endpoint ${DIGDAG_SERVER}
rm zozo-e62ae29b6c4f_cfm.json

# ワークフローのテスト(dry-run)
echo "digdag start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} ${PJ_OPTION}"
${DIGDAG} start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} ${PJ_OPTION}