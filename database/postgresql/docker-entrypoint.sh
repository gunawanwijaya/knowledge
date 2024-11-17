#!/bin/sh
set -e

# chown -R postgres:root /var/lib/postgres /var/log/postgres;
if [ -z "${OUTPUT}" ]; then OUTPUT="/dev/stdout"; fi

cat << EOF > /healthcheck && chmod +x /healthcheck;
pg_isready -q -h "localhost" -p "5432" \
    -d "$(cat ${POSTGRES_DB_FILE})" \
    -U "$(cat ${POSTGRES_USER_FILE})" \
 2>&1;
EOF

rm -rf /var/log/postgres/*;

CONFIG_FILE="/etc/config/postgres.TMP.conf"
cp /etc/config/postgres.conf "${CONFIG_FILE}"
add_args(){
    cp "${CONFIG_FILE}" /etc/config/postgres.TMP.0.conf
    echo "$1" | cat - /etc/config/postgres.TMP.0.conf > "${CONFIG_FILE}"
    rm /etc/config/postgres.TMP.0.conf
}

if [ ! -z "${REPLICATE_FROM_HOST}" ] && [ ! -z "${REPLICATE_FROM_PORT}" ]; then
    REPLICATION_SLOTNAME="$(cat /run/secrets/postgres__rp_slotname)";
    REPLICATION_USERNAME="$(cat /run/secrets/postgres__rp_username)";
    REPLICATION_PASSWORD="$(cat /run/secrets/postgres__rp_password)"
    # in order to start standby server, we need clone from primary server using `pg_basebackup`,
    # we required a password prompt if the replication user in primary are set to have a password
    # that's why we pipe the password into `pg_basebackup` STDIN. `pg_basebackup` will populate
    # identical/mirror of ALL databases from primary that usually contains in ${PGDATA} directory.
    #
    # https://www.postgresql.org/docs/current/app-pgbasebackup.html
    rm -rf "${PGDATA}" && docker-entrypoint.sh pg_basebackup \
        -D "${PGDATA}" \
        -X "stream" \
        -c "fast" \
        -h "${REPLICATE_FROM_HOST}" \
        -p "${REPLICATE_FROM_PORT}" \
        -S "${REPLICATION_SLOTNAME}" \
        -U "${REPLICATION_USERNAME}" \
        -PRvW < /run/secrets/postgres__rp_password \
    >"${OUTPUT}" 2>&1;
    touch "${PGDATA}/standby.signal";
    add_args "primary_conninfo = 'host=${REPLICATE_FROM_HOST} port=${REPLICATE_FROM_PORT} user=${REPLICATION_USERNAME} password=${REPLICATION_PASSWORD}'"
    add_args "primary_slot_name = '${REPLICATION_SLOTNAME}'"
    add_args "hot_standby_feedback = on"
fi

add_args "log_timezone = '${TZ}'"
add_args "timezone = '${TZ}'"
add_args "restore_command = '[ -s ${PGDATA}/pg_wal/%f ] && cp ${PGDATA}/pg_wal/%f %p'"
add_args "archive_cleanup_command = 'pg_archivecleanup ${PGDATA}/pg_wal %r'"

# ----------------------------------------------------------------------------------------------------------------------
# once the databases is populated, we start the services, here we're using `postgres`, because the ${PGDATA}
# directory is not empty the files from docker-entrypoint-initdb.d are not executed.
#
# https://www.postgresql.org/docs/current/app-postgres.html
docker-entrypoint.sh postgres \
    -c "config_file=${CONFIG_FILE}" \
    -D "${PGDATA}" \
    -d 2 \
 >"${OUTPUT}" 2>&1;
