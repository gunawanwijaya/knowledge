exec_otel() {
  local SRC=$1;
  local DST=$2;
  local SVC=$3;
  local PROMETHEUS_METRICS_URL=$4;
  local STDOUT=$5;
  local TXTOUT=$6;
  local EXITCODE=$7;

  cp "${SRC}" "${DST}";

  local FIND=" # receivers.prometheus.config.scrape_configs";
  local REPL="";
  REPL="${REPL}\\n        - job_name: ${SVC}";
  REPL="${REPL}\\n          static_configs:";
  REPL="${REPL}\\n            - targets: [${PROMETHEUS_METRICS_URL}]";
  sed -i "s|${FIND}|${REPL}|" "${DST}";

  local FIND=" # receivers.filelog.operators";
  local REPL="";
  REPL="${REPL}\\n      - { type: add, field: attributes.service.name, value: ${SVC} }";
  REPL="${REPL}\\n      - { type: add, field: resource.service.name, value: ${SVC} }";
  sed -i "s|${FIND}|${REPL}|" "${DST}";

  local FIND=" # extensions.file_storage/filelog.directory";
  local REPL=" /var/lib/${SVC}/otelcol-contrib/file_storage/filelog";
  sed -i "s|${FIND}|${REPL}|" "${DST}";

  local FLAG="";
  FLAG="${FLAG}+filelog.allowHeaderMetadataParsing,";
  FLAG="${FLAG}+filelog.allowFileDeletion";
  
  set -o pipefail;
  otelcol-contrib --config="${DST}" --feature-gates="${FLAG}" 2>&1 | tee "${TXTOUT}" > "${STDOUT}" && echo $? > "${EXITCODE}";
}; exec_otel "$@"
