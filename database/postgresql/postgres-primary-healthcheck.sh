#!/bin/sh
set -e

pg_isready -q -h "localhost" -p "5432" \
    -d "$(cat ${POSTGRES_DB_FILE})" \
    -U "$(cat ${POSTGRES_USER_FILE})" \
 2>&1;
