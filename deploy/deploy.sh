#!/bin/bash -xe

ROOT_DIR=$(cd $(dirname $0)/../ && pwd)

changed_pj=$(git diff --name-only origin/master^...origin/master | grep -e ^project | cut -d'/' -f 2 | uniq)

# PJ SETTINGS
DIGDAG_SERVER_DEV=10.201.161.10:65432
DIGDAG_SERVER_PRD=10.201.161.10:23456

DIGDAG_SERVER=${DIGDAG_SERVER_PRD}

DEV_SCHEDULES=$(digdag schedules --endpoint ${DIGDAG_SERVER_DEV})

flag=true

for pjname in ${changed_pj}; do

    echo ""
    echo "--- ${pjname} ---"

    # find workflow file
    pjdir=${ROOT_DIR}/project/${pjname}
    digfile=${pjdir}/${pjname}.dig
    command=$(ls ${digfile})
    if [ $? != 0 ]; then
        echo "自動デプロイのための $(basename ${digfile}) が見つかりませんでした"
        exit 1
    fi

    # check schedule with dev
    line=$(echo ${DEV_SCHEDULES} | grep -o -e "id: [0-9]* project: ${pjname} workflow: ${pjname}" | wc -l | awk '{print $1}')
    if [ ${line} != "0" ]; then
        echo ${DEV_SCHEDULES} | grep -o -e "id: [0-9]* project: ${pjname} workflow: ${pjname}"
        echo "DEV環境に同一プロジェクトでスケジュールが登録されています。スケジュールを削除してから再ビルドしてください"
        exit 1
    fi

    echo "重複するスケジュールは、開発環境に登録されていません。"
    response=$(digdag push ${pjname} --project ${pjdir} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER} 2>&1)
    # do digdag check
    if [ $? != 0 ]; then
        echo ${response}
        echo "${pjname}のPUSHに失敗しました"
        exit 1
    fi

    # deployしたプロジェクトリストを書き出す
    id=$(echo ${response} | grep -o -e "id: [0-9]*" | cut -d ' ' -f 2)
    echo "${pjname}のPUSHは成功しました。"
    echo "http://${DIGDAG_SERVER}/projects/${id}/workflows/${pjname}"

    # bigqueryのアクセスキーを設定します
    cp /usr/local/.credential/gcpcredential.json .
    secret=$(digdag secrets --project ${pjname} --set gcp.credential=@gcpcredential.json --endpoint ${DIGDAG_SERVER} 2>&1)

    # register secret key
    if [ $? != 0 ]; then
        echo ${secret}
        echo "${pjname}へGCPのJson keyの登録に失敗しました"
        exit 1
    fi

    echo "BigQuery用のシークレットキーを登録しました"
    rm gcpcredential.json

    flag=false
done

if  ${flag} ; then
    echo 'デプロイするプロジェクトファイルは存在しませんでした。'
fi
