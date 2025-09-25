#!/bin/bash
# importiert die beiden Dumps IMPORTFILE in Schema BEM_DB_SCHEMA.
# Alternativ können Pfade zu dump und dup_lp als Parameter übergeben werden.

IMPORTFILE=dumps/bem_dev.sql
IMPORTFILE_LP=dumps/bem_dev_lp.sql

BEM_DB_SCHEMA=bem_dev
BEM_DB_SCHEMA_LP=bem_dev_lp

THIS_SCRIPT=mariaDB-DumpImport.sh
CONTAINER_MARIADB=mariadb

# falls zwei Parameter vorhanden, dann handelt es sich um Dump und Dump_lp.
if [ ! -z "$2" ]; then
	IMPORTFILE=$1
	IMPORTFILE_LP=$2
fi

echo "$THIS_SCRIPT:"
echo "     IMPORTFILE   =$IMPORTFILE "
echo "     IMPORTFILE_LP=$IMPORTFILE_LP "



# function getMariaDBContainerId()
# liefert die Docker-ID des laufenden BEM-DEV-Containers $CONTAINER_MARIADB (bem_local_dev).
getMariaDBContainerId() {
	CONTAINER_ID="$(docker ps | grep $CONTAINER_MARIADB | awk '{ print $1 }')"
	if [[ -z "$CONTAINER_ID" ]]; then
		echo
		echo "ERROR, $THIS_SCRIPT:"
		echo "   Keinen laufenden Docker-Container mit dem Namen '$CONTAINER_MARIADB' gefunden."
		echo "   Container mit MariaDB kann im WSL so gestartet werden:"
		echo "        cd /usr/applications/liferay-bem/docker/compose"
		echo "        export ENVFILE=env-local-dev.env && docker compose -f ./docker-compose.yml --env-file ${ENVFILE} run --rm bem /bin/bash"
		echo
		exit -1
	fi
}

getMariaDBContainerId
echo "$THIS_SCRIPT: Schema anlegen in Container $CONTAINER_MARIADB"

# Weiterleitung an laufenden Docker-Container "mariadb"
docker exec -i $CONTAINER_MARIADB mysql -u root -proot -h127.0.0.1 --default-character-set=utf8 <<EOF
DROP DATABASE IF EXISTS $BEM_DB_SCHEMA;
DROP DATABASE IF EXISTS $BEM_DB_SCHEMA_LP;
CREATE DATABASE $BEM_DB_SCHEMA          CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE DATABASE $BEM_DB_SCHEMA_LP       CHARACTER SET utf8 COLLATE utf8_general_ci;
EOF


echo "$THIS_SCRIPT: Dumps importieren"
docker exec -i $CONTAINER_MARIADB mysql -uroot -proot -h127.0.0.1 --port=3306 --default-character-set=utf8 $BEM_DB_SCHEMA_LP < $IMPORTFILE_LP
docker exec -i $CONTAINER_MARIADB mysql -uroot -proot -h127.0.0.1 --port=3306 --default-character-set=utf8 $BEM_DB_SCHEMA    < $IMPORTFILE


echo "$THIS_SCRIPT: VirtualHost setzen"
docker exec -i $CONTAINER_MARIADB mysql -u root -proot -h127.0.0.1 --default-character-set=utf8 <<EOF
UPDATE $BEM_DB_SCHEMA_LP.VirtualHost SET hostname = REPLACE(hostname, 'itsd-serv2.de', 'localhost');
EOF


echo "$THIS_SCRIPT: done"
