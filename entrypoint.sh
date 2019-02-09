#!/bin/bash
if [ ! -f /var/lib/postgresql/9.6/main/PG_VERSION_ok ]; then
 cp -pr /var/lib/postgresql/9.6/main_bak/* /var/lib/postgresql/9.6/main/
 /etc/init.d/postgresql restart
 gosu postgres psql -c "CREATE USER osm;"
 gosu postgres psql -c "CREATE DATABASE world;"
 gosu postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE world TO osm;"
 gosu postgres psql -c "CREATE EXTENSION hstore;" -d world
 gosu postgres psql -c "CREATE EXTENSION postgis;" -d world
 touch /var/lib/postgresql/9.6/main/PG_VERSION_ok
fi

chown -R postgres:postgres /var/lib/postgresql/9.6/main
chmod 0700 /var/lib/postgresql/9.6/main

/etc/init.d/postgresql restart
/etc/init.d/renderd restart
/etc/init.d/apache2 restart

while true; do
 sleep 600
done
