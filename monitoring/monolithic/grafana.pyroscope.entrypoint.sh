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
S3_BUCKET_BLOCKS=$(cat /run/secrets/pyroscope__bucket_blocks);
S3_ACCESS=$(cat /run/secrets/pyroscope_access);
S3_SECRET=$(cat /run/secrets/pyroscope_secret);
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
