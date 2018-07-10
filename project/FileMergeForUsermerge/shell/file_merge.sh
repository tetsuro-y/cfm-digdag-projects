#!/usr/bin/env bash

#if [ -z "$(command -v aws)" ]; then
#    echo 'aws command not found. error'
#fi

mkdir -p /tmp/filemerge

targetdt=$(date +"%Y%m%d%H%M%S")
tmppath=/tmp/filemerge/${targetdt}
listfile=/tmp/filemerge/${targetdt}.txt
aws s3 ls stk-rmd-recommend-production/transfer/accesslog/ --profile JP1_DIGDAG | awk '{print $4}' | grep a > ${listfile}
file_length=$(cat ${listfile} | wc -l)

if [ $(( ${file_length} % 100 )) -eq 0 ]; then
    loop=$(( ${file_length} / 100))
else
    loop=$(( ${file_length} / 100 + 1))
fi

echo $loop

for i in $(seq 1 ${loop}); do
    echo $(( (${i} - 1) * 100 + 1 )),$(( (${i}) * 100 ))
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

    rm -f ${tmppath}/*
done

rm -rf ${tmppath}
rm -rf ${listfile}
