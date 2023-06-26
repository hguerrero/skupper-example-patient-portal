#!/bin/bash

echo $POSTGRESQL_USER
echo $POSTGRESQL_DATABASE
echo $(pwd)
export SQL_DIR=$(pwd)/sql

psql -d $POSTGRESQL_DATABASE -w -c "grant all privileges on database ${POSTGRESQL_DATABASE} to ${POSTGRESQL_USER};"

envsubst < $SQL_DIR/data.sql > /tmp/data-subst.sql

psql -U$POSTGRESQL_USER -d $POSTGRESQL_DATABASE -w < /tmp/data-subst.sql