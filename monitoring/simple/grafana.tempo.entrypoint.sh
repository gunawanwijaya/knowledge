#!/bin/sh
set -e

# ----------------------------------------------------------------------------------------------------------------------
target="all";
suffix=${2};

s3_host=$(cat /run/secrets/minio.host);
s3_port=$(cat /run/secrets/minio.port);
s3_region=$(cat /run/secrets/minio.region);
s3_bucket=$(cat /run/secrets/minio.tempo-bucket);
s3_access=$(cat /run/secrets/minio.tempo-accesskey);
s3_secret=$(cat /run/secrets/minio.tempo-secretkey);
# ----------------------------------------------------------------------------------------------------------------------
tmp="/tmp/tempo/tempo-${target}${suffix}";
cp /config.yml /config.TMP.yml;
sed -i "s|/tmp/tempo/metrics_generator.storage.path|${tmp}/metrics|"                        /config.TMP.yml;
sed -i "s|grpc: { endpoint: \"\" }|grpc: { endpoint: \"tempo-${target}${suffix}:4317\" }|"  /config.TMP.yml;
sed -i "s|region: \"\"|region: \"${s3_region}\"|"                                           /config.TMP.yml;
mkdir -p /data/tempo /tmp/tempo /var/log/tempo ${tmp}/wal ${tmp}/traces ${tmp}/metrics;

query_frontend="query-frontend"
query_scheduler="query-scheduler"
memberlist_join="ingester-0"
if [ "${target}" = "all" ]; then
    query_frontend="all"
    query_scheduler="all"
    memberlist_join="all"
fi

version=$(/tempo -version | head -n 1);
echo '{"message":"healthy","instance":"'${target}${suffix}'","version":"'${version}'"}'; # > /logpipe;
# /tempo -config.file="/config.TMP.yml" -help;
# /tempo -config.file="/config.TMP.yml" -list-targets;
/tempo -config.file="/config.TMP.yml" -target="${target}" \
    -storage.trace.s3.endpoint="${s3_host}:${s3_port}" \
    -storage.trace.s3.bucket="${s3_bucket}" \
    -storage.trace.s3.access_key="${s3_access}" \
    -storage.trace.s3.secret_key="${s3_secret}" \
    -storage.trace.local.path="${tmp}/traces" \
    -storage.trace.wal.path="${tmp}/wal" \
    -querier.frontend-address="tempo-${query_frontend}:3301" \
    -memberlist.host-port="tempo-${memberlist_join}:7946" \
 2>&1 | tee "/var/log/tempo/tempo-${target}${suffix}.log";
    # > /logpipe;
