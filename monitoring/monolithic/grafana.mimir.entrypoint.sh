#!/bin/sh
# set -e

# ----------------------------------------------------------------------------------------------------------------------
EXITCODE="/tmp/otelcol-contrib.exit";
sleep .5 & /otelcol-contrib.exec.sh \
  "/etc/config/otelcol-contrib.yml" \
  "/config.0.yml" \
  "mimir" \
  "mimir-all:${HTTP_LISTEN_PORT}" \
  "${STDOUT}" \
  "/var/log/mimir/otelcol-contrib.jsonl" \
  "${EXITCODE}" \
& wait -n;
if [ -r "${EXITCODE}" ]; then { CODE=$(cat ${EXITCODE}); [ ${CODE} -ge 0 ] && [ ${CODE} -le 127 ] && exit ${CODE}; } fi
# ----------------------------------------------------------------------------------------------------------------------
S3_BUCKET_ALERTMANAGER=$(cat /run/secrets/mimir__bucket_alertmanager);
S3_BUCKET_BLOCKS=$(cat /run/secrets/mimir__bucket_blocks);
S3_BUCKET_RULER=$(cat /run/secrets/mimir__bucket_ruler);
S3_ACCESS=$(cat /run/secrets/mimir_access);
S3_SECRET=$(cat /run/secrets/mimir_secret);
RING_REPLICA=1
RING_STORE="inmemory"
QUERIER_FRONTEND="mimir-all:${GRPC_LISTEN_PORT}"
QUERIER_SCHEDULER=""
# ----------------------------------------------------------------------------------------------------------------------
mimir -config.file="/etc/config/mimir.yml" -target="${TARGET}" \
  -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
  -server.http-listen-port="${HTTP_LISTEN_PORT}" \
  \
  -common.storage.backend="s3" \
  -common.storage.s3.insecure=true \
  -common.storage.s3.signature-version="v4" \
  -common.storage.s3.storage-class="STANDARD" \
  -common.storage.s3.endpoint="${S3_ENDPOINT}" \
  -common.storage.s3.region="${S3_REGION}" \
  -common.storage.s3.access-key-id="${S3_ACCESS}" \
  -common.storage.s3.secret-access-key="${S3_SECRET}" \
  -common.storage.s3.bucket-name="${S3_BUCKET_BLOCKS}" \
  -alertmanager-storage.s3.bucket-name="${S3_BUCKET_ALERTMANAGER}" \
  -blocks-storage.s3.bucket-name="${S3_BUCKET_BLOCKS}" \
  -ruler-storage.s3.bucket-name="${S3_BUCKET_RULER}" \
  \
  -ingester.ring.replication-factor="${RING_REPLICA}" \
  -alertmanager.sharding-ring.replication-factor="${RING_REPLICA}" \
  -store-gateway.sharding-ring.replication-factor="${RING_REPLICA}" \
  -query-frontend.scheduler-address="${QUERIER_SCHEDULER}" \
  -ruler.query-frontend.address="${QUERIER_FRONTEND}" \
  -querier.frontend-address="${QUERIER_FRONTEND}" \
  -querier.scheduler-address="${QUERIER_SCHEDULER}" \
  \
  -store-gateway.sharding-ring.store="${RING_STORE}" \
  -compactor.ring.store="${RING_STORE}" \
  -alertmanager.sharding-ring.store="${RING_STORE}" \
  -ruler.ring.store="${RING_STORE}" \
  -query-scheduler.ring.store="${RING_STORE}" \
  -ingester.ring.store="${RING_STORE}" \
  -ingester.partition-ring.store="${RING_STORE}" \
  -distributor.ha-tracker.store="${RING_STORE}" \
  -distributor.ring.store="${RING_STORE}" \
  -overrides-exporter.ring.store="${RING_STORE}" \
  2>&1 | tee "/var/log/mimir/mimir.jsonl" > "${STDOUT}";
