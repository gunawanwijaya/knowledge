#!/bin/sh
set -e

# ----------------------------------------------------------------------------------------------------------------------
POSTGRES_REPLICA_SLOT="$(cat /run/secrets/postgres__rp_slotname)";
POSTGRES_REPLICA_USER="$(cat /run/secrets/postgres__rp_username)";
POSTGRES_REPLICA_PASSWORD="$(cat /run/secrets/postgres__rp_password)";
POSTGRES_READONLY_USER="$(cat /run/secrets/postgres__ro_username)";
POSTGRES_READONLY_PASSWORD="$(cat /run/secrets/postgres__ro_password)";
# ----------------------------------------------------------------------------------------------------------------------
SONAR_DB="$(cat /run/secrets/sonar_database)";
SONAR_USER="$(cat /run/secrets/sonar_username)";
SONAR_PASSWORD="$(cat /run/secrets/sonar_password)";
# ----------------------------------------------------------------------------------------------------------------------


# ----------------------------------------------------------------------------------------------------------------------
# Worth to note that `${POSTGRES_REPLICA_SLOT}` and `${POSTGRES_REPLICA_USER}` should be in lowercase.
# but when running CREATE USER `${POSTGRES_REPLICA_USER}` there are no errors, instead it will
# transform the value to the lowercase format.
#
# we should also have a different role for read only user, usually used in analytical purposes
# https://www.keyvanfatehi.com/2021/07/14/how-to-create-read-only-user-in-postgresql/
psql -v "ON_ERROR_STOP=1" -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
	-----------------------------------------------------------------------------------------------
	CREATE USER ${POSTGRES_REPLICA_USER} WITH REPLICATION
		ENCRYPTED PASSWORD '${POSTGRES_REPLICA_PASSWORD}';
	SELECT * FROM pg_create_physical_replication_slot('${POSTGRES_REPLICA_SLOT}');
	-----------------------------------------------------------------------------------------------
	CREATE ROLE __readonly;
		GRANT USAGE ON SCHEMA public TO __readonly;
		GRANT SELECT ON ALL TABLES IN SCHEMA public TO __readonly;
		ALTER DEFAULT PRIVILEGES IN SCHEMA public
			GRANT SELECT ON TABLES TO __readonly;
	CREATE USER ${POSTGRES_READONLY_USER} WITH
		ENCRYPTED PASSWORD '${POSTGRES_READONLY_PASSWORD}';
	GRANT __readonly TO ${POSTGRES_READONLY_USER};
	-----------------------------------------------------------------------------------------------
	CREATE USER ${SONAR_USER} WITH
		ENCRYPTED PASSWORD '${SONAR_PASSWORD}';
	CREATE DATABASE ${SONAR_DB} OWNER ${SONAR_USER};
	-----------------------------------------------------------------------------------------------
	\du
EOSQL

# ----------------------------------------------------------------------------------------------------------------------
# LINE="host replication ${POSTGRES_REPLICA_USER} all trust";
LINE="host replication ${POSTGRES_REPLICA_USER} all scram-sha-256";
grep -qxF "${LINE}" "${PGDATA}/pg_hba.conf" || echo "${LINE}" >> "${PGDATA}/pg_hba.conf";
