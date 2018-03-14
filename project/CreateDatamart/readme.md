# CreateDatamart

## ワークフロー概要

毎朝下記のリポジトリのmasterに設定してあるSQLを使用してデータマートを作成するためのワークフローです。

http://10.201.161.10:8084/CFM/sql-digdag


## 実行手順

1. 1M1BのファイルをS3から取得し、PureDataにinsertする
1. KPIレポートのファイルを実行する

## 手動実行のためのコマンド

```aidl
./CreateDatamart/run.sh
```
