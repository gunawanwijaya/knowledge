#!/bin/sh
set -e

# in order to start standby server, we need clone from primary server using `pg_basebackup`,
# we required a password prompt if the replication user in primary are set to have a password
# that's why we pipe the password into `pg_basebackup` STDIN. `pg_basebackup` will populate
# identical/mirror of ALL databases from primary that usually contains in ${PGDATA} directory.
#
# https://www.postgresql.org/docs/current/app-pgbasebackup.html
docker-entrypoint.sh pg_basebackup \
    -D "${PGDATA}" \
    -h "postgres-primary" -p "5432" \
    -X "stream" \
    -c "fast" \
    -U "$(cat /run/secrets/postgres__rp_username)" \
    -S "$(cat /run/secrets/postgres__rp_slotname)" \
    -PRvW   < /run/secrets/postgres__rp_password \
 2>&1;

# ----------------------------------------------------------------------------------------------------------------------
# once the databases is populated, we start the services, here we're using `postgres`, because the ${PGDATA}
# directory is not empty the files from docker-entrypoint-initdb.d are not executed.
#
# https://www.postgresql.org/docs/current/app-postgres.html
docker-entrypoint.sh postgres \
    -D "${PGDATA}" \
    -c "log_directory=/var/log/postgres" \
    -c "log_timezone=${TZ}" \
    -c "timezone=${TZ}" \
 2>&1;
