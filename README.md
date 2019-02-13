## Open Street Maps on Debian - Postgresql 9.6 + Apache2
Running OSM local server.

Build as docker container, or install locally.
#### Local installation
Add repositories
```
echo "#Debian Stable (9) Stretch
deb http://ftp.debian.sk/debian/ stretch main contrib non-free
deb-src http://ftp.debian.sk/debian/ stretch main contrib non-free
deb http://ftp.debian.sk/debian/ stretch-updates main contrib non-free
deb-src http://ftp.debian.sk/debian/ stretch-updates main contrib non-free
deb http://ftp.debian.sk/debian/ stretch-proposed-updates main contrib non-free
deb-src http://ftp.debian.sk/debian/ stretch-proposed-updates main contrib non-free
deb http://ftp.debian.sk/debian/ stretch-backports main contrib non-free
deb-src http://ftp.debian.sk/debian/ stretch-backports main contrib non-free
deb http://security.debian.org/ stretch/updates main contrib
deb-src http://security.debian.org/ stretch/updates main contrib" > /etc/apt/sources.list
```
Do the update and upgrade of system to newest version
```
apt-get update && apt-get -y upgrade && apt-get -y dist-upgrade && apt-get -y autoremove
```
Install all necessary packages
```
apt-get update && apt-get -y install postgresql-9.6-postgis-2.3 postgresql-contrib-9.6 git vim wget curl screen osm2pgsql autoconf libtool libmapnik-dev apache2-dev unzip gdal-bin mapnik-utils node-carto apache2 gosu && apt-get clean
```
Replace some strings, and do user management. 
```
sed -i 's/max_connections = 100/max_connections = 1000/g' /etc/postgresql/9.6/main/postgresql.conf
user -m -p osm osm
sed -i 's/\/home\/osm:/\/home\/osm:\/bin\/bash/g' /etc/passwd
```
Download necessary packages from git and compile it, and again do some replacement
```cd /home/osm && git clone https://github.com/openstreetmap/mod_tile.git && cd mod_tile && ./autogen.sh && ./configure && make && make install && cp debian/renderd.init /etc/init.d/renderd

cd /home/osm && wget https://github.com/gravitystorm/openstreetmap-carto/archive/v2.29.1.tar.gz && tar -xzf v2.29.1.tar.gz && cd /home/osm/openstreetmap-carto-2.29.1 && ./get-shapefiles.sh && sed -i 's/"dbname": "gis"/"dbname": "world"/' project.mml && carto project.mml > style.xml

sed -i 's/XML=\/home\/jburgess\/osm\/svn\.openstreetmap\.org\/applications\/rendering\/mapnik\/osm\-local\.xml/XML=\/home\/osm\/openstreetmap-carto-2.29.1\/style.xml/' /usr/local/etc/renderd.conf && sed -i 's/HOST=tile\.openstreetmap\.org/HOST=localhost/' /usr/local/etc/renderd.conf && sed -i 's/plugins_dir=\/usr\/lib\/mapnik\/input/plugins_dir=\/usr\/lib\/mapnik\/3.0\/input\//' /usr/local/etc/renderd.conf && cat /usr/local/etc/renderd.conf | grep -v ';' > /usr/local/etc/renderd.conf.new && mv /usr/local/etc/renderd.conf /usr/local/etc/renderd.conf.bak && mv /usr/local/etc/renderd.conf.new /usr/local/etc/renderd.conf && chmod a+x /etc/init.d/renderd && sed -i 's/DAEMON=\/usr\/bin\/$NAME/DAEMON=\/usr\/local\/bin\/$NAME/' /etc/init.d/renderd && sed -i 's/DAEMON_ARGS=""/DAEMON_ARGS=" -c \/usr\/local\/etc\/renderd.conf"/' /etc/init.d/renderd && sed -i 's/RUNASUSER=www-data/RUNASUSER=osm/' /etc/init.d/renderd

mkdir -p /var/lib/mod_tile && chown osm:osm /var/lib/mod_tile
```
Create config for Apache module
```
echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/tile.load && ln -s /etc/apache2/mods-available/tile.load /etc/apache2/mods-enabled/

echo "ServerName localhost" >> /etc/apache2/apache2.conf

echo "<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
        ErrorLog /var/log/apache2/error.log
        CustomLog /var/log/apache2/access.log combined
        LoadTileConfigFile /usr/local/etc/renderd.conf
        ModTileRenderdSocketName /var/run/renderd/renderd.sock
        ModTileRequestTimeout 0
        ModTileMissingRequestTimeout 30
</VirtualHost>" > /etc/apache2/sites-enabled/000-default.conf

cp /home/osm/mod_tile/src/.libs/mod_tile.so /usr/lib/apache2/modules/mod_tile.so && ldconfig -v
```
Restart services
```
service renderd restart
service apache2 restart
```
Add files to the path
```
index.html /var/www/html/index.html
script.js /var/www/html/script.js
style.css /var/www/html/style.css
```
Set the rights, owner, group, and create user, database for postgresql
```
chown -R postgres:postgres /var/lib/postgresql/9.6/main
chmod 0700 /var/lib/postgresql/9.6/main
gosu postgres psql -c "CREATE USER osm;"
gosu postgres psql -c "CREATE DATABASE world;"
gosu postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE world TO osm;"
gosu postgres psql -c "CREATE EXTENSION hstore;" -d world
gosu postgres psql -c "CREATE EXTENSION postgis;" -d world
```
Finally, restart all services
```
/etc/init.d/postgresql restart
/etc/init.d/renderd restart
/etc/init.d/apache2 restart
```


#### Here are some usefull commands
MANUAL RENDER
```su osm -c "render_list -m default -a -z 0 -Z 5"```

CHECK STATS
```cat /var/run/renderd/renderd.stats | grep -v ": 0"```

DIR WITH TILES
```/var/lib/mod_tile```

DELETE DB
```gosu postgres psql -c "DROP DATABASE world;"```

MANUAL CREATE DB
```
gosu postgres psql -c "CREATE USER osm;"
gosu postgres psql -c "CREATE DATABASE world;"
gosu postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE world TO osm;"
gosu postgres psql -c "CREATE EXTENSION hstore;" -d world
gosu postgres psql -c "CREATE EXTENSION postgis;" -d world
```
IMPORT 
```su osm -c "osm2pgsql --slim --database world --disable-parallel-indexing --cache 800 --cache-strategy sparse --hstore --style /home/osm/openstreetmap-carto-2.29.1/openstreetmap-carto.style /maps_source/latvia-latest.osm.pbf"```
