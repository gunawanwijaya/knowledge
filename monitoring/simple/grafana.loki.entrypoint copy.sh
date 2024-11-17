#!/bin/sh
set -e

# ----------------------------------------------------------------------------------------------------------------------
S3_HOST=$(cat /run/secrets/minio.host);
S3_PORT=$(cat /run/secrets/minio.port);
S3_REGION=$(cat /run/secrets/minio.region);
S3_BUCKET_BLOCKS=$(cat /run/secrets/minio.loki-bucket-blocks);
S3_BUCKET_RULER=$(cat /run/secrets/minio.loki-bucket-ruler);
S3_ACCESS=$(cat /run/secrets/minio.loki-accesskey);
S3_SECRET=$(cat /run/secrets/minio.loki-secretkey);
S3_ENDPOINT="http://${S3_HOST}:${S3_PORT}"
# ----------------------------------------------------------------------------------------------------------------------
COMPACTOR="compactor"
QUERIER="querier-0"
QUERY_FRONTEND="query-frontend"
QUERY_SCHEDULER="query-scheduler"
MEMBERLIST_JOIN="ingester-0"
RING_REPLICA=3
if [ "${TARGET}" = "all" ]; then
    COMPACTOR="all"
    QUERIER="all"
    QUERY_FRONTEND="all"
    QUERY_SCHEDULER="all"
    MEMBERLIST_JOIN="all"
    # RING_REPLICA=1
fi
# ----------------------------------------------------------------------------------------------------------------------
COMPACTOR="loki-${COMPACTOR}:${GRPC_LISTEN_PORT}"
QUERIER="http://loki-${QUERIER}:${HTTP_LISTEN_PORT}"
QUERIER_FRONTEND=""
QUERIER_SCHEDULER=""
MEMBERLIST_JOIN="loki-${MEMBERLIST_JOIN}:7946"
if [ "${TARGET}" = "all" ]; then
    QUERIER_FRONTEND="loki-${QUERY_FRONTEND}:${GRPC_LISTEN_PORT}"
else
    QUERIER_SCHEDULER="loki-${QUERY_SCHEDULER}:${GRPC_LISTEN_PORT}"
fi
# ----------------------------------------------------------------------------------------------------------------------
cp /config.otelcol-contrib.yml /config.0.yml
sed -i "s| # receivers.prometheus.config.scrape_configs|\\n      - { job_name: loki, static_configs: [{ targets: [loki-all:3100] }] }|" "/config.0.yml";
# ----------------------------------------------------------------------------------------------------------------------
otelcol-contrib --config="/config.0.yml" \
    2>&1 | tee "/var/log/loki/otelcol-contrib.jsonl" &

    # -ruler.storage.s3.buckets="${S3_BUCKET_RULER}" -ruler.storage.type="s3" \
loki -config.file="/config.yml" -target="${TARGET}" \
    -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
    -server.http-listen-port="${HTTP_LISTEN_PORT}" \
    -common.compactor-grpc-address="${COMPACTOR}" \
    -common.storage.s3.endpoint="${S3_ENDPOINT}" \
    -common.storage.s3.region="${S3_REGION}" \
    -common.storage.s3.access-key-id="${S3_ACCESS}" \
    -common.storage.s3.secret-access-key="${S3_SECRET}" \
    -common.storage.s3.buckets="${S3_BUCKET_BLOCKS}" \
    -common.storage.ring.replication-factor=${RING_REPLICA} \
    -frontend.tail-proxy-url="${QUERIER}" \
    -querier.frontend-address="${QUERIER_FRONTEND}" \
    -querier.scheduler-address="${QUERIER_SCHEDULER}" \
    -memberlist.join="${MEMBERLIST_JOIN}" \
 2>&1 | tee "/var/log/loki/loki.jsonl";
