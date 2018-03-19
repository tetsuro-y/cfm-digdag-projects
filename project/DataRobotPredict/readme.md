# DataRobotPredict

## ワークフロー概要

毎朝下記のリポジトリのmasterに設定してあるDatarobot関連SQLを使用してデータマートを作成するためのワークフローです。

http://10.201.161.10:8084/CFM/sql-digdag


## 実行手順

1. 予測するためのデータをPure Dataから取得します。
1. S3にファイルをアップロードします。

## 手動実行のためのコマンド

手動で実行する場合は、下記の方法で実行することが可能です。その場合、日付指定なしでデフォルト値の本日データが使用されます。

```aidl
./DataRobotPredict/run.sh
```

## 日付の指定方法

※　現在この設定は、スケジュール起動のためオフになっています。

`ex_execute_date` は、 `YYYYMMDD` のフォーマットで入力してください。

```aidl
digdag start ${PJNAME} ${PJNAME} --session now --endpoint 10.201.161.10:65432 -p ex_execute_date="20180315"
```
