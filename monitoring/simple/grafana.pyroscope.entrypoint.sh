#!/bin/sh
set -e

# ----------------------------------------------------------------------------------------------------------------------
target="all";
suffix=${2};

s3_host=$(cat /run/secrets/minio.host);
s3_port=$(cat /run/secrets/minio.port);
s3_region=$(cat /run/secrets/minio.region);
s3_bucket=$(cat /run/secrets/minio.pyroscope-bucket);
s3_access=$(cat /run/secrets/minio.pyroscope-accesskey);
s3_secret=$(cat /run/secrets/minio.pyroscope-secretkey);
# ----------------------------------------------------------------------------------------------------------------------
mkdir -p /data/pyroscope /tmp/pyroscope /var/log/pyroscope /data/pyroscope/pyroscope-${target}${suffix};

query_frontend="query-frontend"
query_scheduler="query-scheduler"
memberlist_join="ingester-0"
if [ ${target} = "all" ]; then
    query_frontend="all"
    query_scheduler="all"
    memberlist_join="all"
fi

version=$(pyroscope -version | head -n 1);
echo "{\"version\":\"${version}\",\"msg\":\"ok ${target}${suffix}\"}"; # > /logpipe
pyroscope -config.file="/config.yml" -target="${target}" \
    -storage.s3.endpoint="${s3_host}:${s3_port}" \
    -storage.s3.region="${s3_region}" \
    -storage.s3.bucket-name="${s3_bucket}" \
    -storage.s3.access-key-id="${s3_access}" \
    -storage.s3.secret-access-key="${s3_secret}" \
    -pyroscopedb.data-path="/data/pyroscope/pyroscope-${target}${suffix}" \
    -memberlist.join="pyroscope-${memberlist_join}:7946" \
 2>&1 | tee "/var/log/pyroscope/pyroscope-${target}${suffix}.log";
    # > /logpipe;
