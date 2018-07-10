#!/usr/bin/env bash

#if [ -z "$(command -v aws)" ]; then
#    echo 'aws command not found. error'
#fi

mkdir -p /tmp/filemerge

targetdt=$(date +"%Y%m%d%H%M%S")
tmppath=/tmp/filemerge/${targetdt}

# 該当ファイルをファイルに吐き出す
listfile=/tmp/filemerge/${targetdt}.txt
aws s3 ls stk-rmd-recommend-production/transfer/accesslog/ --profile JP1_DIGDAG | awk '{print $4}' | grep a > ${listfile}
file_length=$(cat ${listfile} | wc -l)

# 繰り返しループする回数を決定する
if [ $(( ${file_length} % 100 )) -eq 0 ]; then
    loop=$(( ${file_length} / 100 ))
else
    loop=$(( ${file_length} / 100 + 1 ))
fi

echo loop is ${loop}

# ディレクトリがない場合に作成する
mkdir -p ${tmppath}
# 前回の実行などでファイルが既にある場合に削除する
rm -f ${tmppath}/*

for i in $(seq 1 ${loop}); do
    # ループの開始と終了ポジジョン
    echo $(( (${i} - 1) * 100 + 1 )),$(( ${i} * 100 ))

    # 該当ファイルを取得する
    files=$(cat ${listfile} | sed -n $(( (${i} - 1) * 100 + 1 )),$(( (${i}) * 100 ))p)
    echo $files

    for file in ${files}; do
        echo "copy ${file} to local"
        aws s3 cp s3://stk-rmd-recommend-production/transfer/accesslog/${file} ${tmppath}/${file} --profile JP1_DIGDAG
    done

    cat /tmp/filemerge/${targetdt}/accesslog-*.tsv > ${tmppath}/merged_accesslog-${targetdt}.tsv

    for file in ${files}; do
        echo "remove ${file} in s3"
        aws s3 rm s3://stk-rmd-recommend-production/transfer/accesslog/${file} --profile JP1_DIGDAG
    done

    echo "upload new file to s3"
    aws s3 cp ${tmppath}/merged_accesslog-${targetdt}.tsv s3://stk-rmd-recommend-production/transfer/accesslog/accesslog-${targetdt}-${i}.tsv --profile JP1_DIGDAG

    # ダウンロードしたファイルを削除する
    rm -f ${tmppath}/*
done

rm -rf ${tmppath}
rm -rf ${listfile}
