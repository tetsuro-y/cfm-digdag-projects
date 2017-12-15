#!/usr/bin/env bash

# プロジェクトの登録
digdag push getvisituser --project C:\Users\keiko\DatagripProjects\digdagProject\project\CFMDashboard_GetVisitUser -r "2017/11/20" --endpoint 10.201.161.10:65432

# bigqueryのアクセスキーを設定します
digdag secrets --project getvisituser --set "gcp.credential=@zozo-70a08e5ccb2b_local.json" --endpoint 10.201.161.10:65432
# cp ~/git/zozo-e62ae29b6c4f_cfm.json .
# digdag secrets --project getvisituser --set "gcp.credential=@zozo-e62ae29b6c4f_cfm.json" --endpoint 10.201.161.10:65432
# rm zozo-e62ae29b6c4f_cfm.json

# ワークフローの実行
cd C:\Users\keiko\DatagripProjects\digdagProject\project\CFMDashboard_GetVisitUser
digdag start getvisituser getvisituser --session now --params-file ./config.yml --endpoint 10.201.161.10:65432
