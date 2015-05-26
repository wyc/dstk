FROM ubuntu:14.04

RUN apt-get update && \
    apt-get install -y aptitude
RUN apt-get install -y software-properties-common

RUN add-apt-repository -y ppa:webupd8team/java          && \
    apt-get update                                     && \
    apt-get safe-upgrade -y                            && \
    apt-get full-upgrade -y
RUN apt-get install -y build-essential apache2 apache2.2-common apache2-mpm-prefork apache2-utils libexpat1 ssl-cert postgresql libpq-dev ruby1.8-dev ruby1.8 ri1.8 rdoc1.8 irb1.8 libreadline-ruby1.8 libruby1.8 libopenssl-ruby sqlite3 libsqlite3-ruby1.8 git-core libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libaprutil1-dev subversion postgresql-9.1-postgis autoconf libtool libxml2-dev libbz2-1.0 libbz2-dev libgeos-dev proj-bin libproj-dev ocropus pdftohtml catdoc unzip ant openjdk-6-jdk lftp php5-cli rubygems flex postgresql-server-dev-9.1 proj libjson0-dev xsltproc docbook-xsl docbook-mathml gettext postgresql-contrib-9.1 pgadmin3 python-software-properties bison dos2unix
RUN echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections         && \
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections           && \
    apt-get install -y oracle-java7-installer
RUN apt-get install -y libgdal-dev
RUN apt-get install -y libgeos++-dev
RUN bash -c 'echo "/usr/lib/jvm/java-7-oracle/jre/lib/amd64/server" > /etc/ld.so.conf.d/jvm.conf' && \
    ldconfig                                                                                      && \
    mkdir /sources

WORKDIR /sources
RUN wget http://download.osgeo.org/postgis/source/postgis-2.0.3.tar.gz && \
    tar -xfvz postgis-2.0.3.tar.gz

WORKDIR /sources/postgis-2.0.3
RUN ./configure --with-gui                                                    && \
    make                                                                      && \
    make install                                                              && \
    ldconfig                                                                  && \
    make comments-install

RUN sed -i "s/ident/trust/" /etc/postgresql/9.1/main/pg_hba.conf && \
    sed -i "s/md5/trust/" /etc/postgresql/9.1/main/pg_hba.conf   && \
    sed -i "s/peer/trust/" /etc/postgresql/9.1/main/pg_hba.conf  && \
    update-rc.d postgresql defaults                              && \
    /etc/init.d/postgresql restart                               && \
    createdb -U postgres geodict

RUN sudo -u postgres createdb template_postgis                                                                          && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis.sql              && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/spatial_ref_sys.sql      && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/postgis_comments.sql     && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/rtpostgis.sql            && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/raster_comments.sql      && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/topology.sql             && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/topology_comments.sql    && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/legacy.sql               && \
    sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-2.0/legacy_gist.sql

WORKDIR /sources
RUN git clone git://github.com/petewarden/dstk.git      && \
    git clone git://github.com/petewarden/dstkdata.git
WORKDIR /sources/dstk
RUN sudo gem install bundler && \
    sudo bundle install

WORKDIR /sources/dstkdata
RUN createdb -U postgres -T template_postgis statistics && \
    tar xzf statistics/gl_gpwfe_pdens_15_bil_25.tar.gz  && \
    export PATH=$PATH:/usr/lib/postgresql/9.1/bin/      && \
    raster2pgsql -s 4236 -t 32x32 -I gl_gpwfe_pdens_15_bil_25/glds15ag.bil public.population_density | psql -U postgres -d statistics && \
    rm -rf gl_gpwfe_pdens_15_bil_25                     && \
    unzip statistics/glc2000_v1_1_Tiff.zip              && \
    raster2pgsql -s 4236 -t 32x32 -I Tiff/glc2000_v1_1.tif public.land_cover | psql -U postgres -d statistics && \
    rm -rf Tiff

RUN mkdir -p /mnt/data && \
    chown ubuntu /mnt/data
WORKDIR /mnt/data
RUN curl -O "http://static.datasciencetoolkit.org.s3-website-us-east-1.amazonaws.com/SRTM_NE_250m.tif.zip" && \
    unzip SRTM_NE_250m.tif.zip && \
    raster2pgsql -s 4236 -t 32x32 SRTM_NE_250m.tif public.elevation | psql -U postgres -d statistics && \
    rm -rf SRTM_NE_250m* && \
    curl -O "http://static.datasciencetoolkit.org.s3-website-us-east-1.amazonaws.com/SRTM_W_250m.tif.zip" && \
    unzip SRTM_W_250m.tif.zip && \
    raster2pgsql -s 4236 -t 32x32 -a SRTM_W_250m.tif public.elevation | psql -U postgres -d statistics && \
    rm -rf unzip SRTM_W_250m* && \
    curl -O "http://static.datasciencetoolkit.org.s3-website-us-east-1.amazonaws.com/SRTM_SE_250m.tif.zip" && \
    unzip SRTM_SE_250m.tif.zip && \
    raster2pgsql -s 4236 -t 32x32 -a -I SRTM_SE_250m.tif public.elevation | psql -U postgres -d statistics && \
    rm -rf SRTM_SE_250m* && \
    curl -O "http://static.datasciencetoolkit.org.s3-website-us-east-1.amazonaws.com/tmean_30s_bil.zip" && \
    unzip tmean_30s_bil.zip

RUN /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_1.bil public.mean_temperature_01 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_2.bil public.mean_temperature_02 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_3.bil public.mean_temperature_03 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_4.bil public.mean_temperature_04 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_5.bil public.mean_temperature_05 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_6.bil public.mean_temperature_06 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_7.bil public.mean_temperature_07 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_8.bil public.mean_temperature_08 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_9.bil public.mean_temperature_09 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_10.bil public.mean_temperature_10 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_11.bil public.mean_temperature_11 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I tmean_12.bil public.mean_temperature_12 | psql -U postgres -d statistics && \
    rm -rf tmean_*
    
RUN curl -O "http://static.datasciencetoolkit.org.s3-website-us-east-1.amazonaws.com/prec_30s_bil.zip" && \
    unzip prec_30s_bil.zip && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_1.bil public.precipitation_01 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_2.bil public.precipitation_02 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_3.bil public.precipitation_03 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_4.bil public.precipitation_04 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_5.bil public.precipitation_05 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_6.bil public.precipitation_06 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_7.bil public.precipitation_07 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_8.bil public.precipitation_08 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_9.bil public.precipitation_09 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_10.bil public.precipitation_10 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_11.bil public.precipitation_11 | psql -U postgres -d statistics && \
    /usr/lib/postgresql/9.1/bin/raster2pgsql -s 4236 -t 32x32 -I prec_12.bil public.precipitation_12 | psql -U postgres -d statistics && \
    rm -rf prec_*

RUN unzip /sources/dstkdata/statistics/us_statistics_rasters.zip -d . && \
    for f in *.tif; do raster2pgsql -s 4236 -t 32x32 -I $f `basename $f .tif` | psql -U postgres -d statistics; done && \
    rm -rf us* && \
    rm -rf metadata

RUN gem install passenger && \
    passenger-install-apache2-module

#RUN # You'll need to update the version number below to match whichever actual passenger version was installed
#RUN sudo bash -c 'echo "LoadModule passenger_module /var/lib/gems/1.8/gems/passenger-4.0.2/libout/apache2/mod_passenger.so"  > /etc/apache2/mods-enabled/passenger.load'
#RUN sudo bash -c 'echo "PassengerRoot /var/lib/gems/1.8/gems/passenger-4.0.2" > /etc/apache2/mods-enabled/passenger.conf'
#RUN sudo bash -c 'echo "PassengerRuby /usr/bin/ruby1.8" >> /etc/apache2/mods-enabled/passenger.conf'
#RUN sudo bash -c 'echo "PassengerMaxPoolSize 3" >> /etc/apache2/mods-enabled/passenger.conf'
#RUN sudo sed -i "s/MaxRequestsPerChild[ \t][ \t]*[0-9][0-9]*/MaxRequestsPerChild 20/" /etc/apache2/apache2.conf
#RUN 
#RUN sudo bash -c 'echo "
#  <VirtualHost *:80>
#      ServerName www.yourhost.com
#      DocumentRoot /sources/dstk/public
#      RewriteEngine On
#      RewriteCond %{HTTP_HOST} ^datasciencetoolkit.org$ [NC]
#      RewriteRule ^(.*)$ http://www.datasciencetoolkit.org$1 [R=301,L]
#      RewriteCond %{HTTP_HOST} ^datasciencetoolkit.com$ [NC]
#      RewriteRule ^(.*)$ http://www.datasciencetoolkit.com$1 [R=301,L]
#      <Directory /sources/dstk/public>
#         AllowOverride all
#         Options -MultiViews
#      </Directory>
#   </VirtualHost>
#" > /etc/apache2/sites-enabled/000-default'
#RUN sudo ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load
#RUN 
#RUN sudo /etc/init.d/apache2 restart
#RUN 
#RUN sudo gem install postgres -v '0.7.9.2008.01.28'
#RUN 
#RUN cd ~/sources/dstk
#RUN ./populate_database.rb
#RUN 
#RUN cd ~/sources
#RUN mkdir maxmind
#RUN cd maxmind
#RUN wget "http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz"
#RUN gunzip GeoLiteCity.dat.gz
#RUN wget "http://geolite.maxmind.com/download/geoip/api/c/GeoIP.tar.gz"
#RUN tar xzvf GeoIP.tar.gz
#RUN cd GeoIP-1.4.8/
#RUN libtoolize -f
#RUN ./configure
#RUN make
#RUN sudo make install
#RUN cd ..
#RUN svn checkout svn://rubyforge.org/var/svn/net-geoip/trunk net-geoip
#RUN cd net-geoip/
#RUN ruby ext/extconf.rb 
#RUN make
#RUN sudo make install
#RUN 
#RUN cd ~/sources
#RUN wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.11.tar.gz
#RUN tar -xvzf libiconv-1.11.tar.gz
#RUN cd libiconv-1.11
#RUN ./configure --prefix=/usr/local/libiconv
#RUN make
#RUN sudo make install
#RUN sudo ln -s /usr/local/libiconv/lib/libiconv.so.2 /usr/lib/libiconv.so.2
#RUN 
#RUN createdb -U postgres -T template_postgis reversegeo
#RUN 
#RUN cd ~/sources
#RUN git clone git://github.com/petewarden/osm2pgsql
#RUN cd osm2pgsql/
#RUN ./autogen.sh
#RUN sed -i 's/version = BZ2_bzlibVersion();//' configure
#RUN sed -i 's/version = zlibVersion();//' configure
#RUN ./configure
#RUN make
#RUN sudo make install
#RUN cd ..
#RUN 
#RUN osm2pgsql -U postgres -d reversegeo -p world_countries -S osm2pgsql/styles/world_countries.style dstkdata/world_countries.osm -l
#RUN osm2pgsql -U postgres -d reversegeo -p admin_areas -S osm2pgsql/styles/admin_areas.style dstkdata/admin_areas.osm -l
#RUN osm2pgsql -U postgres -d reversegeo -p neighborhoods -S osm2pgsql/styles/neighborhoods.style dstkdata/neighborhoods.osm -l
#RUN 
#RUN cd ~/sources
#RUN git clone git://github.com/petewarden/boilerpipe
#RUN cd boilerpipe/boilerpipe-core/
#RUN ant
#RUN cd src
#RUN javac -cp ../dist/boilerpipe-1.1-dev.jar boilerpipe.java
#RUN 
#RUN cd ~/sources/dstk/
#RUN psql -U postgres -d reversegeo -f sql/loadukpostcodes.sql
#RUN 
#RUN osm2pgsql -U postgres -d reversegeo -p uk_osm -S ../osm2pgsql/default.style ../dstkdata/uk_osm.osm.bz2 -l
#RUN 
#RUN psql -U postgres -d reversegeo -f sql/buildukindexes.sql
#RUN 
#RUN cd ~/sources
#RUN git clone git://github.com/geocommons/geocoder.git
#RUN cd geocoder
#RUN make
#RUN sudo make install
#RUN 
#RUN # Build the latest Tiger/Line data for US address lookups
#RUN cd /mnt/data
#RUN mkdir tigerdata
#RUN cd tigerdata
#RUN lftp ftp2.census.gov:/geo/tiger/TIGER2012/EDGES
#RUN mirror --parallel=5 .
#RUN cd ../FEATNAMES
#RUN mirror --parallel=5 .
#RUN cd ../ADDR
#RUN mirror --parallel=5 .
#RUN exit
#RUN cd ~/sources/geocoder/build/
#RUN mkdir ../../geocoderdata/
#RUN ./tiger_import ../../geocoderdata/geocoder2012.db /mnt/data/tigerdata/
#RUN 
#RUN cd ~/sources
#RUN git clone git://github.com/luislavena/sqlite3-ruby.git
#RUN cd sqlite3-ruby
#RUN ruby setup.rb config
#RUN ruby setup.rb setup
#RUN sudo ruby setup.rb install
#RUN 
#RUN cd ~/sources/geocoder
#RUN bin/rebuild_metaphones ../geocoderdata/geocoder2012.db
#RUN chmod +x build/build_indexes 
#RUN build/build_indexes ../geocoderdata/geocoder2012.db
#RUN rm -rf /mnt/data/tigerdata
#RUN 
#RUN createdb -U postgres names
#RUN cd /mnt/data
#RUN curl -O "http://www.ssa.gov/oact/babynames/names.zip"
#RUN dos2unix yob*.txt
#RUN ~/sources/dstk/dataconversion/analyzebabynames.rb . > babynames.csv
#RUN psql -U postgres -d names -f ~/sources/dstk/sql/loadnames.sql
#RUN 
#RUN # Fix for postgres crashes, 
#RUN sudo sed -i "s/shared_buffers = [0-9A-Za-z]*/shared_buffers = 512MB/" /etc/postgresql/9.1/main/postgresql.conf
#RUN sudo sysctl -w kernel.shmmax=576798720
#RUN sudo bash -c 'echo "kernel.shmmax=576798720" >> /etc/sysctl.conf'
#RUN sudo bash -c 'echo "vm.overcommit_memory=2" >> /etc/sysctl.conf'
#RUN sudo sed -i "s/max_connections = 100/max_connections = 200/" /etc/postgresql/9.1/main/postgresql.conf
#RUN sudo /etc/init.d/postgresql restart
#RUN 
#RUN # Remove files not needed at runtime
#RUN rm -rf /mnt/data/*
#RUN rm -rf ~/sources/libiconv-1.11.tar.gz
#RUN rm -rf ~/sources/postgis-2.0.3.tar.gz
#RUN cd ~/sources/
#RUN mkdir dstkdata_runtime
#RUN mv dstkdata/ethnicityofsurnames.csv dstkdata_runtime/
#RUN mv dstkdata/GeoLiteCity.dat dstkdata_runtime/
#RUN rm -rf dstkdata
#RUN mv dstkdata_runtime dstkdata
#RUN 
#RUN # Up to this point, you'll have a 0.50 version of the toolkit.
#RUN # The following will upgrade you to a 0.51 version
#RUN 
#RUN cd ~/sources/dstk
#RUN git pull origin master
#RUN 
#RUN # TwoFishes geocoder
#RUN cd ~/sources
#RUN mkdir twofishes
#RUN cd twofishes
#RUN mkdir bin
#RUN curl "http://www.twofishes.net/binaries/latest.jar" > bin/twofishes.jar
#RUN mkdir data
#RUN curl "http://www.twofishes.net/indexes/revgeo/latest.zip" > data/twofishesdata.zip
#RUN cd data
#RUN unzip twofishesdata.zip
#RUN sudo cp ~/sources/dstk/twofishes.conf /etc/init/twofishes.conf
#RUN sudo service twofishes start
#RUN 
#RUN sudo bash -c 'echo "
#RUN   <VirtualHost *:80>
#RUN       ServerName www.yourhost.com
#RUN       DocumentRoot /sources/dstk/public
#RUN       RewriteEngine On
#RUN       RewriteCond %{HTTP_HOST} ^datasciencetoolkit.org$ [NC]
#RUN       RewriteRule ^(.*)$ http://www.datasciencetoolkit.org$1 [R=301,L]
#RUN       RewriteCond %{HTTP_HOST} ^datasciencetoolkit.com$ [NC]
#RUN       RewriteRule ^(.*)$ http://www.datasciencetoolkit.com$1 [R=301,L]
#RUN       # We have an internal TwoFishes server running on port 8081, so redirect
#RUN       # requests that look like they belong to its API
#RUN       ProxyPass /twofishes http://localhost:8081        
#RUN       <Directory /sources/dstk/public>
#RUN          AllowOverride all
#RUN          Options -MultiViews
#RUN          Header set Access-Control-Allow-Origin "*"
#RUN          Header set Cache-Control "max-age=86400"
#RUN       </Directory>
#RUN    </VirtualHost>
#RUN " > /etc/apache2/sites-enabled/000-default'
#RUN sudo ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load
#RUN sudo ln -s /etc/apache2/mods-available/proxy.load /etc/apache2/mods-enabled/proxy.load
#RUN sudo ln -s /etc/apache2/mods-available/proxy_http.load /etc/apache2/mods-enabled/proxy_http.load
#RUN sudo ln -s /etc/apache2/mods-available/headers.load /etc/apache2/mods-enabled/headers.load
#RUN 
#RUN sudo /etc/init.d/apache2 restart
