#!/usr/bin/env bash

ROOT_DIR=$(cd $(dirname $0)/../ && pwd)

array=()

changed_file=$(git diff --name-only origin/master^...origin/master | grep -e ^project)

# PJ SETTINGS
DIGDAG_SERVER_DEV=10.201.161.10:65432
# DIGDAG_SERVER_PRD=10.201.161.10:23456

DIGDAG_SERVER=${DIGDAG_SERVER_DEV}

DEV_SCHEDULES=$(/var/jenkins_home/bin/digdag schedules --endpoint ${DIGDAG_SERVER_DEV})

# check diff from previous master
for file in ${changed_file}; do
    may_dir=$(echo ${file} | cut -d'/' -f 2)
    if [ -d "${ROOT_DIR}/project/${may_dir}" ]; then
        array=("${array[@]}" "${may_dir}")
    fi
done

deploy_list=$(echo ${array} | uniq)
flag=true

for pjname in ${deploy_list}; do

    echo ""
    echo "--- ${pjname} ---"

    # find workflow file
    pjdir=${ROOT_DIR}/project/${pjname}
    digfile=${pjdir}/${pjname}.dig
    ls ${digfile} || {
        echo "自動デプロイのための $(basename ${digfile}) が見つかりませんでした"
        exit 1
    }

    # check schedule with dev
    line=$(echo ${DEV_SCHEDULES} | grep -o -e "id: [0-9]* project: ${pjname} workflow: ${pjname}" | wc -l | awk '{print $1}')
    if [ ${line} != "0" ]; then
        echo ${DEV_SCHEDULES} | grep -o -e "id: [0-9]* project: ${pjname} workflow: ${pjname}"
        echo "DEV環境に同一プロジェクトでスケジュールが登録されています。スケジュールを削除してから再ビルドしてください"
        exit 1
    fi

    echo "重複するスケジュールは、開発環境に登録されていません。"
    response=$(/var/jenkins_home/bin/digdag push ${pjname} --project ${pjdir} -r "$(date +%Y-%m-%dT%H:%M:%S%z)" --endpoint ${DIGDAG_SERVER} 2>&1)
    # do digdag check
    if [ $? != 0 ]; then
        echo ${response}
        echo "${pjname}のPUSHに失敗しました"
        exit 1
    fi

    # bigqueryのアクセスキーを設定します
    echo "BigQuery用のシークレットキーを登録しています"
    cp /tmp/zozo-e62ae29b6c4f_cfm.json .
    secret=$(/var/jenkins_home/bin/digdag secrets --project ${pjname} --set gcp.credential=@zozo-e62ae29b6c4f_cfm.json --endpoint ${DIGDAG_SERVER} 2>&1)

    # register secret key
    if [ $? != 0 ]; then
        echo ${secret}
        echo "${pjname}へGCPのJson keyの登録に失敗しました"
        exit 1
    fi
    rm zozo-e62ae29b6c4f_cfm.json

    echo "${pjname}のPUSHは成功しました。"

    flag=false
done

if  ${flag} ; then
    echo 'デプロイするプロジェクトファイルは存在しませんでした。'
fi
