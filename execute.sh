#!/usr/bin/env bash

source $(cd $(dirname $0) && pwd)/option_check.sh

# プロジェクトの登録
echo "digdag push ${PJ_NAME} --project ${PJ_DIR} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER}"
digdag push ${PJ_NAME} --project ${PJ_DIR} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER} || exit 1

# bigqueryのアクセスキーを設定します
cp ~/git/zozo-e62ae29b6c4f_cfm.json .
digdag secrets --project ${PJ_NAME} --set gcp.credential=@zozo-e62ae29b6c4f_cfm.json --endpoint ${DIGDAG_SERVER}
rm zozo-e62ae29b6c4f_cfm.json

# ワークフローのテスト(dry-run)
echo "digdag start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} ${PJ_OPTION}"
digdag start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} ${PJ_OPTION}