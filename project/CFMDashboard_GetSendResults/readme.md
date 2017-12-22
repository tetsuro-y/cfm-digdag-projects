# CFMDashboard_GetSendResults

## ワークフロー概要

BigQueryから下記対象チャネル経由の流入データを取得しPD側のデータマートにインサートしたうえで
PDの各種データマートを更新するワークフロー。
更新対象はチャネルごとの日次実績格納データマート及び全チャネルを対象とした時間帯別実績格納データマート。

チャネル | チャネル詳細 | 
--- | --- | 
 メール |新着(TOWN)
 メール |新着(USED)
 メール |マス
 メール |トランザクション
 メール |パーソナライズ
 LINE|マス
 LINE|パーソナライズ
 LINE|タイムライン
 LINE|リッチメニュー
 PUSH|新着（おまとめ）
 PUSH|新着（リアルタイム）
 PUSH|マス
 PUSH|パーソナライズ
 サイトお知らせ（WEB）|
 サイトお知らせ（APP）|


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
 pd_base_date | PDの計算開始日 | '2017/01/01'。空【''】の場合 CURRENT_DATE

## 手動実行のためのコマンド

現在

```aidl
digdag start ${PJ_NAME} ${PJ_NAME} --session now --endpoint ${DIGDAG_SERVER} -p ex_bg_start_dt='${date}' -p ex_bg_end_dt='${date}' -p ex_pure_start_dt='${date}'

例) 開発環境で現在日で実行する場合
digdag start CFMDashboard_GetSendResults CFMDashboard_GetSendResults --session now --endpoint 10.201.161.10:65432 -p ex_bg_start_dt='' -p ex_bg_end_dt='' -p pd_base_date=''

例) 開発環境で日付指定して実行する場合
digdag start CFMDashboard_GetSendResults CFMDashboard_GetSendResults --session now --endpoint 10.201.161.10:65432 -p ex_bg_start_dt='2017/12/19' -p ex_bg_end_dt='2017/12/20' -p pd_base_date='2017/12/20'
```