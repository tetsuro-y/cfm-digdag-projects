# DataRobotResult

## ワークフロー概要

毎朝下記のリポジトリのmasterに設定してあるDatarobot関連SQLを使用してデータマートを作成するためのワークフローです。

http://10.201.161.10:8084/CFM/sql-digdag


## 実行手順

1. インポートしたいモデルの結果をS3にファイルをアップロードします。
1. ワークフローを実行してpure dataに取り込みを行います。

## 手動実行のためのコマンド

手動で実行する場合は、下記の方法で実行することが可能です。その場合、日付指定なしでデフォルト値の本日データが使用されます。

```aidl
./DataRobotResult/run.sh
```

## 日付の指定方法

`ex_execute_date` は、 `YYYYMMDD` のフォーマットで入力してください。

```aidl
digdag start ${PJNAME} ${PJNAME} --session now --endpoint 10.201.161.10:65432 -p ex_execute_date="" -p ex_model_name="IMPORT_TEST" -p ex_threshold="0.3111"
```
