#!/bin/sh
# set -e

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
RING_STORE="memberlist"
if [ "${TARGET}" = "all" ]; then
    COMPACTOR="all"
    QUERIER="all"
    QUERY_FRONTEND="all"
    QUERY_SCHEDULER="all"
    MEMBERLIST_JOIN="all"
    RING_REPLICA=1
    RING_STORE="inmemory"
fi

# ----------------------------------------------------------------------------------------------------------------------
COMPACTOR="http://loki-${COMPACTOR}:${HTTP_LISTEN_PORT}"
QUERIER="http://loki-${QUERIER}:${HTTP_LISTEN_PORT}"
QUERIER_FRONTEND=""
QUERIER_SCHEDULER=""
MEMBERLIST_JOIN="loki-${MEMBERLIST_JOIN}:${MEMBERLIST_PORT}"
if [ "${TARGET}" = "all" ]; then
    QUERIER_FRONTEND="loki-${QUERY_FRONTEND}:${GRPC_LISTEN_PORT}"
else
    QUERIER_SCHEDULER="loki-${QUERY_SCHEDULER}:${GRPC_LISTEN_PORT}"
fi
# ----------------------------------------------------------------------------------------------------------------------
EXITCODE="/tmp/otelcol-contrib.exit";
exec_otel() {
  cp /etc/config/otelcol-contrib.yml /config.0.yml;
  local FIND=" # receivers.prometheus.config.scrape_configs";
  local REPL="";
  REPL="${REPL}\\n        - job_name: loki";
  REPL="${REPL}\\n          static_configs:";
  REPL="${REPL}\\n            - targets: [loki-all:3100]";
  sed -i "s|${FIND}|${REPL}|" "/config.0.yml";

  local FIND=" # receivers.filelog.operators";
  local REPL="";
  REPL="${REPL}\\n      - { type: add, field: attributes.service.name, value: loki }";
  REPL="${REPL}\\n      - { type: add, field: resource.service.name, value: loki }";
  sed -i "s|${FIND}|${REPL}|" "/config.0.yml";

  local FLAG="";
  FLAG="${FLAG}+filelog.allowHeaderMetadataParsing";
  FLAG="${FLAG},+filelog.allowFileDeletion";
  set -o pipefail
  otelcol-contrib --config="/config.0.yml" --feature-gates="${FLAG}" \
    2>&1 | tee "/var/log/loki/otelcol-contrib.jsonl";
  echo $? > "${EXITCODE}";
}
exec_otel & sleep .25 & wait -n;
if [ -r "${EXITCODE}" ]; then
  CODE=$(cat ${EXITCODE}); [ ${CODE} -ge 0 ] && [ ${CODE} -le 127 ] && exit ${CODE};
fi
# ----------------------------------------------------------------------------------------------------------------------
loki -config.file="/etc/config/loki.yml" -target="${TARGET}" \
  -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
  -server.http-listen-port="${HTTP_LISTEN_PORT}" \
    \
  -common.storage.s3.endpoint="${S3_ENDPOINT}"        -ruler.storage.s3.endpoint="${S3_ENDPOINT}" \
  -common.storage.s3.region="${S3_REGION}"            -ruler.storage.s3.region="${S3_REGION}" \
  -common.storage.s3.access-key-id="${S3_ACCESS}"     -ruler.storage.s3.access-key-id="${S3_ACCESS}" \
  -common.storage.s3.secret-access-key="${S3_SECRET}" -ruler.storage.s3.secret-access-key="${S3_SECRET}" \
  -common.storage.s3.buckets="${S3_BUCKET_BLOCKS}"    -ruler.storage.s3.buckets="${S3_BUCKET_RULER}" -ruler.storage.type="s3" \
    \
  -common.storage.ring.replication-factor="${RING_REPLICA}" \
  -common.storage.ring.store="${RING_STORE}" \
  -common.compactor-address="${COMPACTOR}" \
  -frontend.tail-proxy-url="${QUERIER}" \
  -querier.frontend-address="${QUERIER_FRONTEND}" \
  -querier.scheduler-address="${QUERIER_SCHEDULER}" \
  -ruler.evaluation.query-frontend.address="${QUERIER_FRONTEND}" \
  -memberlist.bind-port="${MEMBERLIST_PORT}" \
  -memberlist.join="${MEMBERLIST_JOIN}" \
 2>&1 | tee "/var/log/loki/loki.jsonl";
