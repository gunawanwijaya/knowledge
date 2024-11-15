#!/bin/sh
# set -e

# ----------------------------------------------------------------------------------------------------------------------
EXITCODE="/tmp/otelcol-contrib.exit";
sleep .5 & /otelcol-contrib.exec.sh \
  "/etc/config/otelcol-contrib.yml" \
  "/config.0.yml" \
  "tempo" \
  "tempo-all:${HTTP_LISTEN_PORT}" \
  "${STDOUT}" \
  "/var/log/tempo/otelcol-contrib.jsonl" \
  "${EXITCODE}" \
& wait -n;
if [ -r "${EXITCODE}" ]; then { CODE=$(cat ${EXITCODE}); [ ${CODE} -ge 0 ] && [ ${CODE} -le 127 ] && exit ${CODE}; } fi
# ----------------------------------------------------------------------------------------------------------------------
S3_HOST=$(cat /run/secrets/minio.host);
S3_PORT=$(cat /run/secrets/minio.port);
S3_REGION=$(cat /run/secrets/minio.region);
S3_BUCKET_BLOCKS=$(cat /run/secrets/minio.tempo-bucket-blocks);
S3_ACCESS=$(cat /run/secrets/minio.tempo-accesskey);
S3_SECRET=$(cat /run/secrets/minio.tempo-secretkey);
S3_ENDPOINT="${S3_HOST}:${S3_PORT}"
RING_REPLICA=1
RING_STORE="inmemory"
QUERIER_FRONTEND="tempo-all:${GRPC_LISTEN_PORT}"
# ----------------------------------------------------------------------------------------------------------------------
CONFIG_FILE="/etc/config/tempo.TMP.yml"
cp /etc/config/tempo.yml "${CONFIG_FILE}";
sed -i "s|# storage.trace.s3.region|\"${S3_REGION}\"|"                                              "${CONFIG_FILE}";
sed -i "s|# ingester.lifecycler.ring.replication_factor|${RING_REPLICA}|"                           "${CONFIG_FILE}";
sed -i "s|# metrics_generator.ring.kvstore.store|\"${RING_STORE}\"|"                                "${CONFIG_FILE}";
sed -i "s|# compactor.ring.kvstore.store|\"${RING_STORE}\"|"                                        "${CONFIG_FILE}";
tempo -config.file="${CONFIG_FILE}" -target="${TARGET}" \
  -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
  -server.http-listen-port="${HTTP_LISTEN_PORT}" \
  \
  -storage.trace.backend="s3" \
  -storage.trace.s3.endpoint="${S3_ENDPOINT}" \
  -storage.trace.s3.access_key="${S3_ACCESS}" \
  -storage.trace.s3.secret_key="${S3_SECRET}" \
  -storage.trace.s3.bucket="${S3_BUCKET_BLOCKS}" \
  -querier.frontend-address="${QUERIER_FRONTEND}" \
  \
  2>&1 | tee "/var/log/tempo/tempo.jsonl" > "${STDOUT}";






















# # ----------------------------------------------------------------------------------------------------------------------
# target="all";
# suffix=${2};

# s3_host=$(cat /run/secrets/minio.host);
# s3_port=$(cat /run/secrets/minio.port);
# s3_region=$(cat /run/secrets/minio.region);
# s3_bucket=$(cat /run/secrets/minio.tempo-bucket);
# s3_access=$(cat /run/secrets/minio.tempo-accesskey);
# s3_secret=$(cat /run/secrets/minio.tempo-secretkey);
# # ----------------------------------------------------------------------------------------------------------------------
# tmp="/tmp/tempo/tempo-${target}${suffix}";
# cp /config.yml /config.TMP.yml;
# sed -i "s|/tmp/tempo/metrics_generator.storage.path|${tmp}/metrics|"                        /config.TMP.yml;
# sed -i "s|grpc: { endpoint: \"\" }|grpc: { endpoint: \"tempo-${target}${suffix}:4317\" }|"  /config.TMP.yml;
# sed -i "s|region: \"\"|region: \"${s3_region}\"|"                                           /config.TMP.yml;
# mkdir -p /data/tempo /tmp/tempo /var/log/tempo ${tmp}/wal ${tmp}/traces ${tmp}/metrics;

# query_frontend="query-frontend"
# query_scheduler="query-scheduler"
# memberlist_join="ingester-0"
# if [ "${target}" = "all" ]; then
#     query_frontend="all"
#     query_scheduler="all"
#     memberlist_join="all"
# fi

# version=$(/tempo -version | head -n 1);
# echo '{"message":"healthy","instance":"'${target}${suffix}'","version":"'${version}'"}'; # > /logpipe;
# # /tempo -config.file="/config.TMP.yml" -help;
# # /tempo -config.file="/config.TMP.yml" -list-targets;
# /tempo -config.file="/config.TMP.yml" -target="${target}" \
#     -storage.trace.s3.endpoint="${s3_host}:${s3_port}" \
#     -storage.trace.s3.bucket="${s3_bucket}" \
#     -storage.trace.s3.access_key="${s3_access}" \
#     -storage.trace.s3.secret_key="${s3_secret}" \
#     -storage.trace.local.path="${tmp}/traces" \
#     -storage.trace.wal.path="${tmp}/wal" \
#     -querier.frontend-address="tempo-${query_frontend}:3301" \
#     -memberlist.host-port="tempo-${memberlist_join}:7946" \
#  2>&1 | tee "/var/log/tempo/tempo-${target}${suffix}.log";
#     # > /logpipe;
