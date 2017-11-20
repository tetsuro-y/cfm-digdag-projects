#!/usr/bin/env bash

# プロジェクトの登録
digdag push bigquery-export-sample --project /Users/kenichiro.saito/git/digdagProject/sample -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint 10.201.161.10:65432

# bigqueryのアクセスキーを設定します
cp ~/git/zozo-e62ae29b6c4f_cfm.json .
digdag secrets --project bigquery-export-sample --set gcp.credential=@zozo-e62ae29b6c4f_cfm.json --endpoint 10.201.161.10:65432
rm zozo-e62ae29b6c4f_cfm.json

# ワークフローの実行
digdag start bigquery-export-sample bigquery-export-sample --session now --params-file /Users/kenichiro.saito/git/digdagProject/sample/config.yml --endpoint 10.201.161.10:65432
