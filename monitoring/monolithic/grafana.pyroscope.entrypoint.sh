#!/bin/sh
# set -e

# ----------------------------------------------------------------------------------------------------------------------
EXITCODE="/tmp/otelcol-contrib.exit";
sleep .5 & /otelcol-contrib.exec.sh \
  "/etc/config/otelcol-contrib.yml" \
  "/config.0.yml" \
  "pyroscope" \
  "pyroscope-all:${HTTP_LISTEN_PORT}" \
  "${STDOUT}" \
  "/var/log/pyroscope/otelcol-contrib.jsonl" \
  "${EXITCODE}" \
& wait -n;
if [ -r "${EXITCODE}" ]; then { CODE=$(cat ${EXITCODE}); [ ${CODE} -ge 0 ] && [ ${CODE} -le 127 ] && exit ${CODE}; } fi
# ----------------------------------------------------------------------------------------------------------------------
S3_HOST=$(cat /run/secrets/minio.host);
S3_PORT=$(cat /run/secrets/minio.port);
S3_REGION=$(cat /run/secrets/minio.region);
S3_BUCKET_BLOCKS=$(cat /run/secrets/minio.pyroscope-bucket-blocks);
S3_ACCESS=$(cat /run/secrets/minio.pyroscope-accesskey);
S3_SECRET=$(cat /run/secrets/minio.pyroscope-secretkey);
S3_ENDPOINT="${S3_HOST}:${S3_PORT}"
RING_REPLICA=1
RING_STORE="inmemory"
# ----------------------------------------------------------------------------------------------------------------------
pyroscope -config.file="/etc/config/pyroscope.yml" -target="${TARGET}" \
  -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
  -server.http-listen-port="${HTTP_LISTEN_PORT}" \
  \
  -storage.backend="s3" \
  -storage.s3.insecure=true \
  -storage.s3.force-path-style=true \
  -storage.s3.signature-version="v4" \
  -storage.s3.endpoint="${S3_ENDPOINT}" \
  -storage.s3.region="${S3_REGION}" \
  -storage.s3.access-key-id="${S3_ACCESS}" \
  -storage.s3.secret-access-key="${S3_SECRET}" \
  -storage.s3.bucket-name="${S3_BUCKET_BLOCKS}" \
  \
  -distributor.replication-factor=${RING_REPLICA} \
  -store-gateway.sharding-ring.replication-factor=${RING_REPLICA} \
  -store-gateway.sharding-ring.store="${RING_STORE}" \
  -compactor.ring.store="${RING_STORE}" \
  -ring.store="${RING_STORE}" \
  2>&1 | tee "/var/log/pyroscope/pyroscope.jsonl" > "${STDOUT}";




#   -alertmanager-storage.s3.bucket-name="${S3_BUCKET_ALERTMANAGER}" \
#   -blocks-storage.s3.bucket-name="${S3_BUCKET_BLOCKS}" \
#   -ruler-storage.s3.bucket-name="${S3_BUCKET_RULER}" \
#   \
#   -ingester.ring.replication-factor="${RING_REPLICA}" \
#   -alertmanager.sharding-ring.replication-factor="${RING_REPLICA}" \
#   -store-gateway.sharding-ring.replication-factor="${RING_REPLICA}" \
#   -query-frontend.scheduler-address="${QUERIER_SCHEDULER}" \
#   -ruler.query-frontend.address="${QUERIER_FRONTEND}" \
#   -querier.frontend-address="${QUERIER_FRONTEND}" \
#   -querier.scheduler-address="${QUERIER_SCHEDULER}" \
#   \
#   -store-gateway.sharding-ring.store="${RING_STORE}" \
#   -compactor.ring.store="${RING_STORE}" \
#   -alertmanager.sharding-ring.store="${RING_STORE}" \
#   -ruler.ring.store="${RING_STORE}" \
#   -query-scheduler.ring.store="${RING_STORE}" \
#   -ingester.ring.store="${RING_STORE}" \
#   -ingester.partition-ring.store="${RING_STORE}" \
#   -distributor.ha-tracker.store="${RING_STORE}" \
#   -distributor.ring.store="${RING_STORE}" \
#   -overrides-exporter.ring.store="${RING_STORE}" \















# # ----------------------------------------------------------------------------------------------------------------------
# target="all";
# suffix=${2};

# s3_host=$(cat /run/secrets/minio.host);
# s3_port=$(cat /run/secrets/minio.port);
# s3_region=$(cat /run/secrets/minio.region);
# s3_bucket=$(cat /run/secrets/minio.pyroscope-bucket);
# s3_access=$(cat /run/secrets/minio.pyroscope-accesskey);
# s3_secret=$(cat /run/secrets/minio.pyroscope-secretkey);
# # ----------------------------------------------------------------------------------------------------------------------
# mkdir -p /data/pyroscope /tmp/pyroscope /var/log/pyroscope /data/pyroscope/pyroscope-${target}${suffix};

# query_frontend="query-frontend"
# query_scheduler="query-scheduler"
# memberlist_join="ingester-0"
# if [ "${target}" = "all" ]; then
#     query_frontend="all"
#     query_scheduler="all"
#     memberlist_join="all"
# fi

# version=$(pyroscope -version | head -n 1);
# echo '{"message":"healthy","instance":"'${target}${suffix}'","version":"'${version}'"}'; # > /logpipe
# pyroscope -config.file="/config.yml" -target="${target}" \
#     -storage.s3.endpoint="${s3_host}:${s3_port}" \
#     -storage.s3.region="${s3_region}" \
#     -storage.s3.bucket-name="${s3_bucket}" \
#     -storage.s3.access-key-id="${s3_access}" \
#     -storage.s3.secret-access-key="${s3_secret}" \
#     -pyroscopedb.data-path="/data/pyroscope/pyroscope-${target}${suffix}" \
#     -memberlist.join="pyroscope-${memberlist_join}:7946" \
#  2>&1 | tee "/var/log/pyroscope/pyroscope-${target}${suffix}.log";
#     # -config.show_banner=false \
#     # > /logpipe;
