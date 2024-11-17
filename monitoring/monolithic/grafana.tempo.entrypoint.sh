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
S3_BUCKET_BLOCKS=$(cat /run/secrets/tempo__bucket_blocks);
S3_ACCESS=$(cat /run/secrets/tempo_access);
S3_SECRET=$(cat /run/secrets/tempo_secret);
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
