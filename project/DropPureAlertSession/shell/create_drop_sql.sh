#!/usr/bin/env bash

WORKFLOW_SESSION=$1

filepath=$(echo ${pure} | jq -r .out_dir)/$(echo ${pure} | jq -r .out_file)
CHANNEL="#bot-test"

line=$(cat ${filepath} | wc -l | awk '{print $1}')
if [ ${line} == "0" ]; then
    echo "dropするsessionはありません"
    exit 0
fi

echo "${line}件のセッションをdropします。詳細は下記です。"
echo "--------------------------------------------------------------------------------"
cat ${filepath}
echo "--------------------------------------------------------------------------------"

touch $(echo ${pure} | jq -r .drop_dir)/dropsession.sql

for session in $(cat ${filepath} | cut -f1); do
    echo "DROP SESSION ${session};" >> $(echo ${pure} | jq -r .drop_dir)/dropsession.sql
done

java -cp $(echo ${pure} | jq -r .jar) $(echo ${pure} | jq -r .class) $(echo ${pure} | jq -r .drop_dir) $(echo ${pure} | jq -r .properties)

# slackにdropしたsession情報を送る
cat ${filepath} | while read line; do

    # set tab as a delimiter
    IFS="$(echo -e '\t' )"
    GLOBIGNORE=\*

    # convert tab
    tab_line=(${line})

    # reset settings
    unset IFS
    unset GLOBIGNORE

    # mapping
    session_num="${tab_line[0]}"
    execute_time="${tab_line[1]}"
    dbname="${tab_line[2]}"
    username="${tab_line[3]}"
    summary="${tab_line[4]}"
    duration="${tab_line[5]}"

    message="{\"title\":\"SESSION\", \"value\":\"${session_num}\", \"short\":true}, {\"title\":\"USERNAME\", \"value\":\"${username}\", \"short\":true}, {\"title\":\"EXECUTION\", \"value\":\"${execute_time}\", \"short\":true}, {\"title\":\"DB\", \"value\":\"${dbname}\", \"short\":true}, {\"title\":\"DURATION\", \"value\":\"${duration}\", \"short\":true}, {\"title\":\"WORKFLOW\", \"value\":\"http://${DIGDAGSERVER_HOST}/sessions/${WORKFLOW_SESSION}\", \"short\":false}, {\"title\":\"QUERY SUMMARY\", \"value\":\" \`\`\` ${summary} \`\`\` \", \"short\":false}"
    payload="{\"text\":\"*下記のクエリはアラート条件に一致したためKillされました*\", \"channel\":\"$(echo ${slack} | jq -r .channel)\",\"username\":\"PureData Drop Session Notification\", \"attachments\":[{\"color\":\"warning\",\"fields\":[${message}],\"mrkdwn_in\":[\"fields\", \"text\"]}]}"

    # send slack message
    curl -X POST --data-urlencode "payload=${payload}" $(echo ${slack} | jq -r .webhook)
    echo "slackに通知しました"
done

