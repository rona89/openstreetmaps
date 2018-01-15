FROM debian:stretch

RUN echo "#Debian Stable (9) Stretch \n\
deb http://ftp.debian.sk/debian/ stretch main contrib non-free \n\
deb-src http://ftp.debian.sk/debian/ stretch main contrib non-free \n\
\n\
deb http://ftp.debian.sk/debian/ stretch-updates main contrib non-free \n\
deb-src http://ftp.debian.sk/debian/ stretch-updates main contrib non-free \n\
\n\
deb http://ftp.debian.sk/debian/ stretch-proposed-updates main contrib non-free \n\
deb-src http://ftp.debian.sk/debian/ stretch-proposed-updates main contrib non-free \n\
\n\
deb http://ftp.debian.sk/debian/ stretch-backports main contrib non-free \n\
deb-src http://ftp.debian.sk/debian/ stretch-backports main contrib non-free \n\
\n\
deb http://security.debian.org/ stretch/updates main contrib \n\
deb-src http://security.debian.org/ stretch/updates main contrib" > /etc/apt/sources.list

RUN apt-get update && apt-get -y upgrade && apt-get -y dist-upgrade && apt-get -y autoremove
RUN apt-get -y install postgresql-9.6-postgis-2.3 postgresql-contrib-9.6 git vim wget curl screen osm2pgsql autoconf libtool libmapnik-dev apache2-dev unzip gdal-bin mapnik-utils node-carto apache2  && apt-get clean

RUN sed -i 's/max_connections = 100/max_connections = 1000/g' /etc/postgresql/9.6/main/postgresql.conf
RUN /etc/init.d/postgresql start
RUN useradd -m -p osm osm
RUN sed -i 's/\/home\/osm:/\/home\/osm:\/bin\/bash/g' /etc/passwd
RUN su postgres
RUN cd ~
RUN createuser osm
RUN createdb -E UTF8 -O osm world
RUN psql -c "CREATE EXTENSION hstore;" -d world
RUN psql -c "CREATE EXTENSION postgis;" -d world
RUN exit

RUN su osm
RUN cd ~
RUN git clone https://github.com/openstreetmap/mod_tile.git
RUN cd mod_tile
RUN ./autogen.sh
RUN ./configure
RUN make
RUN exit
RUN cd /home/osm/mod_tile/
RUN make install

RUN su osm
RUN cd ~
RUN #git clone https://github.com/gravitystorm/openstreetmap-carto.git
RUN wget https://github.com/gravitystorm/openstreetmap-carto/archive/v2.29.1.tar.gz
RUN tar -xzf v2.29.1.tar.gz
RUN cd ~/openstreetmap-carto-2.29.1/
RUN ./get-shapefiles.sh
RUN sed -i 's/"dbname": "gis"/"dbname": "world"/' project.mml
RUN carto project.mml > style.xml
RUN exit

RUN cd /home/osm/openstreetmap-carto-2.29.1
RUN sed -i 's/XML=\/home\/jburgess\/osm\/svn\.openstreetmap\.org\/applications\/rendering\/mapnik\/osm\-local\.xml/XML=\/home\/osm\/openstreetmap-carto-2.29.1\/style.xml/' /usr/local/etc/renderd.conf
RUN sed -i 's/HOST=tile\.openstreetmap\.org/HOST=localhost/' /usr/local/etc/renderd.conf
RUN sed -i 's/plugins_dir=\/usr\/lib\/mapnik\/input/plugins_dir=\/usr\/lib\/mapnik\/3.0\/input\//' /usr/local/etc/renderd.conf
RUN cp /home/osm/mod_tile/debian/renderd.init /etc/init.d/renderd
RUN chmod a+x /etc/init.d/renderd
RUN sed -i 's/DAEMON=\/usr\/bin\/$NAME/DAEMON=\/usr\/local\/bin\/$NAME/' /etc/init.d/renderd
RUN sed -i 's/DAEMON_ARGS=""/DAEMON_ARGS=" -c \/usr\/local\/etc\/renderd.conf"/' /etc/init.d/renderd
RUN sed -i 's/RUNASUSER=www-data/RUNASUSER=osm/' /etc/init.d/renderd
RUN mkdir -p /var/lib/mod_tile
RUN chown osm:osm /var/lib/mod_tile

RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/tile.load
RUN ln -s /etc/apache2/mods-available/tile.load /etc/apache2/mods-enabled/

RUN echo "<VirtualHost *:80> " > /etc/apache2/sites-enabled/000-default.conf
RUN echo "        ServerAdmin webmaster@localhost " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        DocumentRoot /var/www/html " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        ErrorLog ${APACHE_LOG_DIR}/error.log " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        CustomLog ${APACHE_LOG_DIR}/access.log combined " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        LoadTileConfigFile /usr/local/etc/renderd.conf " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        ModTileRenderdSocketName /var/run/renderd/renderd.sock " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        ModTileRequestTimeout 0 " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "        ModTileMissingRequestTimeout 30 " >> /etc/apache2/sites-enabled/000-default.conf
RUN echo "</VirtualHost> " >> /etc/apache2/sites-enabled/000-default.conf

RUN cp /home/osm/mod_tile/src/.libs/mod_tile.so /usr/lib/apache2/modules/mod_tile.so
RUN ldconfig -v

RUN service renderd restart
RUN service apache2 restart

CMD service renderd restart && service apache2 restart && while true; do sleep 10; done
