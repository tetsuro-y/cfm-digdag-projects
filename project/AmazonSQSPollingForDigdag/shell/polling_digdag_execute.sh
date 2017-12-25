#!/usr/bin/env bash

WORKFLOW_SESSION=$1

AWS_OPTIONS="--region us-west-2 --profile JP1_DIGDAG"
QUEUE_NAME=UnsynchronizedDigdagWorkflow.fifo

QUEUE_URL=$(aws sqs get-queue-url --queue-name ${QUEUE_NAME} ${AWS_OPTIONS} | jq -r .QueueUrl)

records=$(aws sqs get-queue-attributes --queue-url ${QUEUE_URL} --attribute-names ApproximateNumberOfMessages ${AWS_OPTIONS})
count=$(echo ${records} | jq -r .Attributes.ApproximateNumberOfMessages)

echo URL=${QUEUE_URL}
echo count=${count}

if [ ${count} -ne 0 ]; then
    for i in $(seq 1 ${count});do
        # データを取得する
        echo "aws sqs receive-message --queue-url ${QUEUE_URL} ${AWS_OPTIONS}"
        response=$(aws sqs receive-message --queue-url ${QUEUE_URL} ${AWS_OPTIONS})

        # レスポンスが空でなかったら実行する
        if [ "${response}" != "" ]; then
            echo ${response}
            receiptHandle=$(echo ${response} | jq -r .Messages[0].ReceiptHandle)

            # 本文を取得する
            body=$(echo ${response} | jq -r .Messages[0].Body)

            project=$(echo ${body} | cut -d' ' -f3)
            server=$(echo ${body} | egrep -o -e '(-e|--endpoint)\s+[^\s-]+' | cut -d' ' -f2)

            # digdagの最新のタスクを確認する
            status=$(digdag session ${project} --endpoint ${server} | grep status: | grep running | wc -l | awk '{print $1}')

            echo "実行中のタスクは、 ${status}件です"
            if [ "${status}" != "0" ]; then
                echo '下記のワークフローは現在実行中です。'
                echo '---------------------------------------------------------'
                echo "${body}"
                echo '---------------------------------------------------------'
                exit 0
            else
                echo '-------------------------------------------------------------------------------'
                echo "${body}"

                execution_time=$(date '+%Y-%m-%d %H:%M:%S')
                # 実行する
                result=$(eval "${body}" 2>&1)

                # 実行結果が失敗したら通知を出す
                if [ $? == 0 ]; then
                    # mapping
                    NEW_WORKFLOW_SESSION=$(echo ${result} | egrep -o "session id: [0-9]+" | cut -d' ' -f3)

                    message="{\"title\":\"Command\", \"value\":\" \`\`\` $(echo ${body} | sed 's/"/\\\"/g') \`\`\` \", \"short\":false}, {\"title\":\"起動したWORKFLOW\", \"value\":\"http://${DIGDAGSERVER_HOST}/sessions/${WORKFLOW_SESSION}\", \"short\":false}, {\"title\":\"実行するWORKFLOW\", \"value\":\"http://${DIGDAGSERVER_HOST}/sessions/${NEW_WORKFLOW_SESSION}\", \"short\":false}, {\"title\":\"DATETIME\", \"value\":\"${execution_time}\", \"short\":true}"
                    payload="{\"text\":\"*JP1からのdigdag startを実行しました*\", \"channel\":\"#cfm_science_team\",\"username\":\"DIGDAG Task Starter\", \"attachments\":[{\"color\":\"good\",\"fields\":[${message}],\"mrkdwn_in\":[\"fields\", \"text\"]}]}"


                    # send slack message
                    curl -X POST --data-urlencode "payload=${payload}" $(echo ${slack} | jq -r .webhook)
                else
                    echo "pushに失敗しました。"
                    echo ${result}

                    # mapping
                    message="{\"title\":\"Detail\", \"value\":\"下記のコマンドは、手動で再実行する必要があります。\", \"short\":false}, {\"title\":\"Command\", \"value\":\" \`\`\` $(echo ${body} | sed 's/"/\\\"/g') \`\`\` \", \"short\":false}, {\"title\":\"Error Log\", \"value\":\" \`\`\` $(echo ${result} | sed 's/"/\\\"/g') \`\`\` \", \"short\":false}, {\"title\":\"DATETIME\", \"value\":\"${execution_time}\", \"short\":true}, {\"title\":\"WORKFLOW\", \"value\":\"http://${DIGDAGSERVER_HOST}/sessions/${WORKFLOW_SESSION}\", \"short\":true}"
                    payload="{\"text\":\"*JP1からのdigdag startに失敗しました。*\", \"channel\":\"$(echo ${slack} | jq -r .channel)\",\"username\":\"DIGDAG Task Starter\", \"attachments\":[{\"color\":\"danger\",\"fields\":[${message}],\"mrkdwn_in\":[\"fields\", \"text\"]}]}"

                    # send slack message
                    curl -X POST --data-urlencode "payload=${payload}" $(echo ${slack} | jq -r .webhook)
                fi

                # キューを削除する
                echo "deleting ${receiptHandle}"
                aws sqs delete-message --queue-url ${QUEUE_URL} --receipt-handle ${receiptHandle} ${AWS_OPTIONS}

                echo '-------------------------------------------------------------------------------'
            fi
        else
            echo '処理すべきタスクは見つかりませんでした'
            exit 0
        fi
    done
else
    echo '処理すべきタスクは見つかりませんでした'
    exit 0
fi