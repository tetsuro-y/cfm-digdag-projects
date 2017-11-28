# Digdag Project

Digdagによるワークフローです。 `sample` 配下に例が入っています。

## 開発フロー

下記の開発環境を用いて、ワークフローの動作は確認してください。
動作の確認ができたら、PRを出してMasterにマージすると自動でJenkinsが本番環境にプロジェクトを登録します。

## 注意事項

プロジェクト実行に必要な `config` ファイル名は、 `config.yml` にしてください。
実行登録用シェルがハードコーディングになっています。

## 実行方法

### テスト

プロジェクトを登録し `dry-run` をおこなう。

```aidl
./regist.sh {プロジェクトのパス} {server:ポート}

例)
./regist.sh /Users/kenichiro.saito/git/digdagProject/sample 10.201.161.10:65432
```
### 実行

プロジェクトの登録し、現在時刻(session now)で実行する。

```aidl
./execute.sh {プロジェクトのパス} {server:ポート}

例)
./execute.sh /Users/kenichiro.saito/git/digdagProject/sample 10.201.161.10:65432
```

## 環境

### 開発環境

自由に検証できる環境です。

http://10.201.161.10:65432/

### 本番環境

PRからMasterにマージされたプロジェクトが自動的に登録され
ワークフローが実行されます。基本的に手動で登録作業などはしません。

http://10.201.161.10:23456/