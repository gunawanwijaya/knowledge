#!/bin/sh
set -e

chown -R postgres:root /var/lib/postgres /var/log/postgres;

# once the databases is populated, we start the services, here we're using `postgres`, because the ${PGDATA}
# directory is not empty the files from docker-entrypoint-initdb.d are not executed.
#
# https://www.postgresql.org/docs/current/app-postgres.html
docker-entrypoint.sh postgres \
    -D "${PGDATA}" \
    -c "config_file=/etc/config/postgres.conf" \
    -c "log_directory=/var/log/postgres" \
    -c "log_timezone=${TZ}" \
    -c "timezone=${TZ}" \
 2>&1;
