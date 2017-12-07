#!/bin/bash -xe

# PJ PATH
ROOT_DIR=$(cd $(dirname $0)/../ && pwd)

# PJ SETTINGS
DIGDAG_SERVER_DEV=10.201.161.10:65432

DEV_SCHEDULES=$(digdag schedules --endpoint ${DIGDAG_SERVER_DEV})

flag=true

# check test target project
for pjname in $(ls ${ROOT_DIR}/project); do
    echo ""
    echo "--- ${pjname} ---"

    # find workflow file
    pjdir=${ROOT_DIR}/project/${pjname}
    digfile=${pjdir}/${pjname}.dig
    ls ${digfile} || {
        echo "自動デプロイのための $(basename ${digfile}) が見つかりませんでした"
        exit 1
    }

    echo ".digファイルのテストを実行します"
    response=$(digdag check ${digfile} --project ${pjdir} 2>&1)

    # do digdag check
    if [ $? != 0 ]; then
        echo ${response}
        echo "$(basename ${digfile}) の表記方法に問題が見つかりました"
        exit 1
    fi
    echo ".digファイルの表記に問題はありません"

    # check schedule with dev
    line=$(echo ${DEV_SCHEDULES} | grep -o -e "id: [0-9]* project: ${pjname} workflow: ${pjname}" | wc -l | awk '{print $1}')
    if [ ${line} != "0" ]; then
        echo ${line}
        echo "DEV環境に同一プロジェクトでスケジュールが登録されています。スケジュールを削除してから再ビルドしてください"
        exit 1
    fi

    echo "重複するスケジュールは、開発環境に登録されていません。"
    echo "${pjname}のCHECKは成功しました。"

    flag=false
done

if  ${flag} ; then
    echo 'ビルドするプロジェクトファイルは存在しませんでした。'
fi