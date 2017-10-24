#!/usr/bin/env bash

sudo apt-get -y install libssl-dev
sudo apt-get -y install openssl
sudo apt-get -y install libpcre3 libpcre3-dev
mkdir -p /opt/benchmarks/Nginx/sslcert
mkdir -p ~/nginx
pushd ~/nginx
wget http://nginx.org/download/nginx-1.11.9.tar.gz
tar xf nginx-1.11.9.tar.gz
pushd nginx-1.11.9
wget https://www.openssl.org/source/openssl-1.1.0e.tar.gz
tar xf openssl-1.1.0e.tar.gz
./configure --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro' --prefix=/usr --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-http_ssl_module --with-debug --with-pcre-jit --with-http_stub_status_module --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-mail --with-mail_ssl_module --with-openssl=openssl-1.1.0e
make -j
sudo make install
sudo mkdir -p /var/lib/nginx
sudo mkdir -p /var/log/nginx
sudo mkdir -p /etc/nginx/ssl
NM=bm_test && sudo openssl req -new -nodes -x509 -newkey rsa:2048 -subj "/C=US/ST=CA/L=LA/O=Shay/CN=${NM}" -days 3650 \
-keyout /opt/benchmarks/Nginx/sslcert/${NM}.key -out /opt/benchmarks/Nginx/sslcert/${NM}.crt \
-extensions v3_ca
popd
popd