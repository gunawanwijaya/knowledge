#!/bin/sh
# set -e

# ----------------------------------------------------------------------------------------------------------------------
# PROMETHEUS_METRICS_URL="loki-all:${HTTP_LISTEN_PORT}"
sleep .5 & /otelcol-contrib.exec.sh \
  "/etc/config/otelcol-contrib.yml" \
  "/config.0.yml" \
  "loki" \
  "loki-all:${HTTP_LISTEN_PORT}" \
  "${STDOUT}" \
  "/var/log/loki/otelcol-contrib.jsonl" \
  "${EXITCODE}" \
& wait -n;
if [ -r "${EXITCODE}" ]; then { CODE=$(cat ${EXITCODE}); [ ${CODE} -ge 0 ] && [ ${CODE} -le 127 ] && exit ${CODE}; } fi
# ----------------------------------------------------------------------------------------------------------------------
S3_HOST=$(cat /run/secrets/minio.host);
S3_PORT=$(cat /run/secrets/minio.port);
S3_REGION=$(cat /run/secrets/minio.region);
S3_BUCKET_BLOCKS=$(cat /run/secrets/minio.loki-bucket-blocks);
S3_BUCKET_RULER=$(cat /run/secrets/minio.loki-bucket-ruler);
S3_ACCESS=$(cat /run/secrets/minio.loki-accesskey);
S3_SECRET=$(cat /run/secrets/minio.loki-secretkey);
S3_ENDPOINT="http://${S3_HOST}:${S3_PORT}"
RING_REPLICA=1
RING_STORE="inmemory"
COMPACTOR="http://loki-all:${HTTP_LISTEN_PORT}"
QUERIER="http://loki-all:${HTTP_LISTEN_PORT}"
QUERIER_FRONTEND="loki-all:${GRPC_LISTEN_PORT}"
QUERIER_SCHEDULER=""
# ----------------------------------------------------------------------------------------------------------------------
loki -config.file="/etc/config/loki.yml" -target="${TARGET}" \
  -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
  -server.http-listen-port="${HTTP_LISTEN_PORT}" \
  \
  -common.storage.s3.insecure=true \
  -common.storage.s3.force-path-style=true \
  -common.storage.s3.signature-version="v4" \
  -common.storage.s3.storage-class="STANDARD" \
  -common.storage.s3.endpoint="${S3_ENDPOINT}" \
  -common.storage.s3.region="${S3_REGION}" \
  -common.storage.s3.access-key-id="${S3_ACCESS}" \
  -common.storage.s3.secret-access-key="${S3_SECRET}" \
  -common.storage.s3.buckets="${S3_BUCKET_BLOCKS}" \
  -ruler.storage.s3.buckets="${S3_BUCKET_RULER}" -ruler.storage.type="s3" \
  \
  -common.storage.ring.replication-factor="${RING_REPLICA}" \
  -common.storage.ring.store="${RING_STORE}" \
  -common.compactor-address="${COMPACTOR}" \
  -frontend.tail-proxy-url="${QUERIER}" \
  -querier.frontend-address="${QUERIER_FRONTEND}" \
  -querier.scheduler-address="${QUERIER_SCHEDULER}" \
  -ruler.evaluation.query-frontend.address="${QUERIER_FRONTEND}" \
 2>&1 | tee "/var/log/loki/loki.jsonl" > "${STDOUT}";
