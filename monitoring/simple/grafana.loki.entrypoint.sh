#!/bin/sh
set -e

# ----------------------------------------------------------------------------------------------------------------------
target="all";
suffix=${2};

s3_host=$(cat /run/secrets/minio.host);
s3_port=$(cat /run/secrets/minio.port);
s3_region=$(cat /run/secrets/minio.region);
s3_bucket=$(cat /run/secrets/minio.loki-bucket);
s3_access=$(cat /run/secrets/minio.loki-accesskey);
s3_secret=$(cat /run/secrets/minio.loki-secretkey);
s3_url="http://${s3_access}:${s3_secret}@${s3_region}.${s3_host}:${s3_port}/${s3_bucket}";
# echo $s3_url;
# ----------------------------------------------------------------------------------------------------------------------
tmp="/tmp/loki/loki-${target}${suffix}";
mkdir -p /data/loki /tmp/loki /var/log/loki ${tmp};

querier="querier-0"
query_frontend="query-frontend"
query_scheduler="query-scheduler"
memberlist_join="ingester-0"
compactor="compactor"
if [ "${target}" = "all" ]; then
    querier="all"
    query_frontend="all"
    query_scheduler="all"
    memberlist_join="all"
    compactor="all"
fi

version=$(loki -version | head -n 1);
echo '{"message":"healthy","instance":"'${target}${suffix}'","version":"'${version}'"}'; # > /logpipe;
# loki -config.file="/config.yml" -list-targets;
loki -config.file="/config.yml" -target="${target}" \
    -config.expand-env=true \
    -common.storage.s3.endpoint="http://${s3_host}:${s3_port}" \
    -common.storage.s3.region="${s3_region}" \
    -common.storage.s3.buckets="${s3_bucket}" \
    -common.storage.s3.access-key-id="${s3_access}" \
    -common.storage.s3.secret-access-key="${s3_secret}" \
    -ruler.rule-path="${tmp}/rules" \
    -ruler.storage.local.directory="${tmp}/ruler_storage" \
    -ruler.wal.dir="${tmp}/ruler_wal" \
    -ingester.wal-dir="${tmp}/ingester_wal" \
    -boltdb.dir="${tmp}/boltdb" \
    -boltdb.shipper.active-index-directory="${tmp}/boltdb_index" \
    -boltdb.shipper.cache-location="${tmp}/boltdb_cache" \
    -tsdb.shipper.active-index-directory="${tmp}/tsdb_index" \
    -tsdb.shipper.cache-location="${tmp}/tsdb_cache" \
    -local.chunk-directory="${tmp}/local_chunk" \
    -frontend.tail-proxy-url="http://loki-${querier}:3100" \
    -querier.frontend-address="loki-${query_frontend}:3101" \
    -common.compactor-address="http://loki-${compactor}:3100" \
    -common.compactor-grpc-address="loki-${compactor}:3101" \
    -memberlist.join="loki-${memberlist_join}:7946" \
 2>&1 | tee "/var/log/loki/loki-${target}${suffix}.log";
    # > /logpipe;

# -common.storage.s3.url="${s3_url}" \
# -boltdb.shipper.compactor.working-directory="${tmp}/boltdb_compactor" \
# s3_url="http://${s3_access}:${s3_secret}@${s3_host}.${s3_region}:${s3_port}/${s3_bucket}";
# -common.storage.s3.url="${s3_url}" \
# -querier.scheduler-address="loki-${query_scheduler}:3101" \
# -query-scheduler.ring.tokens-file-path \
# -ingester.tokens-file-path \
# -index-gateway.ring.tokens-file-path \
# -boltdb.shipper.compactor.ring.tokens-file-path \
# -common.storage.ring.tokens-file-path \
