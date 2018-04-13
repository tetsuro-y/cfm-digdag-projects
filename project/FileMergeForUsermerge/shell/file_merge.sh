#!/usr/bin/env bash

#if [ -z "$(command -v aws)" ]; then
#    echo 'aws command not found. error'
#fi

files=$(aws s3 ls stk-rmd-recommend-production/transfer/accesslog/ --profile JP1_DIGDAG | awk '{print $4}')
targetdt=$(date +"%Y%m%d%H%M%S")
tmppath=/tmp/filemerge/${targetdt}

mkdir -p /tmp/filemerge
rm -f ${tmppath}/*

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
aws s3 cp ${tmppath}/merged_accesslog-${targetdt}.tsv s3://stk-rmd-recommend-production/transfer/accesslog/accesslog-${targetdt}.tsv --profile JP1_DIGDAG

rm -rf ${tmppath}