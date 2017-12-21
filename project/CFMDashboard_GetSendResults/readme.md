# CFMDashboard_GetSendResults

## ワークフロー概要

説明を書く

## 実行について

JP1からデータマートが終了したときに、AWS SQSに下記の実行コマンドを送信します。
別のワークフローが、5分毎にSQSから取り出し、タスクが存在する場合については、
コマンドを実行してサーバでこのワークフローを日付指定したパラメータで実行します。

## 実行時パラメータ

パラメータを付けずに実行はできません。またスケジュール実行もできませんので
必ず手動で実行する必要があります。

 パラメータ名 | 説明 | 例
--- | --- | --- |
 ex_bg_start_dt | BQの計算開始日 | '2017/01/01'。空【''】の場合本日より２日前
 ex_bg_end_dt | BQの計算終了日 | '2017/01/01'。空【''】の場合本日より1日前
 ex_pure_start_dt | PDの計算開始日 | '2017/01/01'。空【''】の場合 CURRENT_DATE

## 手動実行のためのコマンド

現在

```aidl
digdag start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} -p ex_bg_start_dt='${date}' -p ex_bg_end_dt='${date}' -p ex_pure_start_dt='${date}'

例) 開発環境で現在日で実行する場合
digdag start CFMDashboard_GetSendResults CFMDashboard_GetSendResults --session now --endpoint 10.201.161.10:65432 -p ex_bg_start_dt='' -p ex_bg_end_dt='' -p ex_pure_start_dt=''

例) 開発環境で日付指定して実行する場合
digdag start CFMDashboard_GetSendResults CFMDashboard_GetSendResults --session now --endpoint 10.201.161.10:65432 -p ex_bg_start_dt='2017/12/19' -p ex_bg_end_dt='2017/12/20' -p ex_pure_start_dt='2017/12/20'
```