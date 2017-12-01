# Digdag Project

Digdagによるワークフローです。 `sample` 配下に例が入っています。

## 開発フロー

下記の開発環境を用いて、ワークフローの動作は確認してください。
動作の確認ができたら、PRを出してMasterにマージすると自動でJenkinsが本番環境にプロジェクトを登録します。

## プロジェクトの作成場所

`/project/{プロジェクト名}/{プロジェクト名.dig}` に従ってください。
これは、自動でJenkinsがPUSHするのに必要なプロジェクト構成です。

## 注意事項

digファイルの書き方は、 `/sample/sample.dig` を参考にしてください。下記のパラメータは、必須です。
（特に必要がなければ変更する必要はありません。）

```aidl
_export:
  wf:
    name: Sample Digdag Workflow using Pure & Bigquery # わかりやすいプロジェクト名を設定してください。

  my_param:
    - DIGDAGSERVER_HOST # （変更不要）実行した環境でslackの通知に記載されるURLになります 
    - DIGDAGSERVER_ENV  # （変更不要）開発環境か本番環境となります

  slack:
    webhook: https://hooks.slack.com/services/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
    channel: '#cfm_science_team'
    username: digdag
    icon_emoji: ghost
    template_path: notification
    good: good-template.yml
    danger: danger-template.yml

  plugin:
    repositories:
      - https://jitpack.io
    dependencies:
      - com.github.szyn:digdag-slack:0.1.2
  # Set Reqired params
  webhook_url: ${slack.webhook}
  # Set Option params
  workflow_name: ${wf.name}
```

実行環境を取得するために下記のタスクを実行する必要があります。

```aidl
+prepare_environments:
  py>: tasks.PrepareEnviroments.set_parameters
```

プロジェクトには、必ず `tasks` と `notification` のディレクトリを追加する必要があります。

## スケジュール設定について

スケジュール設定をした場合、外部パラメータの埋め込みや設定ファイルの読み込みはできません。
実行する.digファイルに記述してください。

### スケジュール設定の確認方法

設定しているスケジュールを確認できます。

```aidl
digdag schedules --endpoint {server:ポート}

例)
digdag schedules --endpoint 10.201.161.10:65432
```


## 実行方法

### テスト

プロジェクトの登録し、現在時刻(session now)で実行する。

```aidl
digdag check {プロジェクトのパス}/{.difファイル} --project {プロジェクトのパス}

例)
digdag check /Users/kenichiro.saito/git/digdagProject/sample/sample.dig --project /Users/kenichiro.saito/git/digdagProject/sample
```

### 実行

プロジェクトの登録し、現在時刻(session now)で実行する。

```aidl
./execute.sh {プロジェクトのパス} {server:ポート}

例)
./execute.sh /Users/kenichiro.saito/git/digdagProject/sample 10.201.161.10:65432
```

## 環境

### ローカルで環境を構築したい場合

下記のリポジトリをcloneして、該当のシェルを実行してください。

https://52.68.139.32/gitbucket/CFM/WorkflowDocker#%e5%ae%9f%e8%a1%8c

### 開発環境

自由に検証できる環境です。

http://10.201.161.10:65432/

### 本番環境

PRからMasterにマージされたプロジェクトが自動的に登録され
ワークフローが実行されます。基本的に手動で登録作業などはしません。

http://10.201.161.10:23456/