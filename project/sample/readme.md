## digファイルの書き方の例

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
