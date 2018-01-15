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

ADD step_01 /root/
ADD step_02 /root/
ADD step_03 /root/
ADD step_04 /root/
ADD step_05 /root/
ADD step_06 /root/
ADD step_07 /root/

RUN cd /root && bash step_01 && bash step_02 && bash step_03 && bash step_04 && bash step_05 && bash step_06 && bash step_07

RUN service renderd restart
RUN service apache2 restart

CMD service renderd restart && service apache2 restart && while true; do sleep 10; done
