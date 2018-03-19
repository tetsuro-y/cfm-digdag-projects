#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
PJNAME=DataRobotPredict

# プロジェクトの登録
digdag push ${PJNAME} --project ${SCRIPT_DIR} --endpoint 10.201.161.10:65432

# bigqueryのアクセスキーを設定します
# digdag secrets --project ${PJNAME} --set "gcp.credential=@zozo-70a08e5ccb2b_local.json" --endpoint 10.201.161.10:65432
# cp ~/git/zozo-e62ae29b6c4f_cfm.json .
# digdag secrets --project getvisituser --set "gcp.credential=@zozo-e62ae29b6c4f_cfm.json" --endpoint 10.201.161.10:65432
# rm zozo-e62ae29b6c4f_cfm.json

# ワークフローの実行
digdag start ${PJNAME} ${PJNAME} --session now --endpoint 10.201.161.10:65432 -p ex_execute_date=""
