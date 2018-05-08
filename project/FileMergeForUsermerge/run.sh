#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname $0) && pwd)
PJNAME=FileMergeForUsermerge

# プロジェクトの登録
digdag push ${PJNAME} --project ${SCRIPT_DIR} --endpoint 10.201.161.10:65432

# ワークフローの実行
# digdag start ${PJNAME} ${PJNAME} --session now --endpoint 10.201.161.10:65432
