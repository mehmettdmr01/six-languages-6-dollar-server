#!/usr/bin/env bash
# nginx + PHP-FPM with Ubuntu's own configuration files. Only paths change, so both run as the benchmark user.
set -euo pipefail
cd "$(dirname "$0")"; APP="$(pwd)"; RUN=/tmp/yarisma-php; rm -rf "$RUN"; mkdir -p "$RUN"
sed -e '/^user /d' -e "s#^pid .*#pid $RUN/nginx.pid;#" -e "s#/var/log/nginx/#$RUN/#g" \
    -e "s#include /etc/nginx/sites-enabled/\*;#include $RUN/site.conf;#" \
    -e "s#include /etc/nginx/modules-enabled/\*.conf;#include /etc/nginx/modules-enabled/*.conf;#" /etc/nginx/nginx.conf > "$RUN/nginx.conf"
sed -i "s#^http {#http {\n\tclient_body_temp_path $RUN/body; fastcgi_temp_path $RUN/fastcgi; proxy_temp_path $RUN/proxy; uwsgi_temp_path $RUN/uwsgi; scgi_temp_path $RUN/scgi;#" "$RUN/nginx.conf"
# Ubuntu's PHP snippet includes fastcgi.conf by a relative path; point that one include back at /etc/nginx.
mkdir -p "$RUN/snippets"
sed 's#include fastcgi.conf;#include /etc/nginx/fastcgi.conf;#' /etc/nginx/snippets/fastcgi-php.conf > "$RUN/snippets/fastcgi-php.conf"
cat > "$RUN/site.conf" <<SITE
server {
	listen ${PORT} default_server;
	root $APP/public;
	index index.php;
	location / { try_files \$uri /index.php\$is_args\$args; }
	location ~ \.php\$ {
		include $RUN/snippets/fastcgi-php.conf;
		fastcgi_pass unix:$RUN/php-fpm.sock;
	}
}
SITE
sed -e '/^user = /d' -e '/^group = /d' -e '/^listen.owner/d' -e '/^listen.group/d' -e "s#^listen = .*#listen = $RUN/php-fpm.sock#" \
    /etc/php/8.3/fpm/pool.d/www.conf > "$RUN/www.conf"
echo "env[SQLITE_PATH] = $SQLITE_PATH" >> "$RUN/www.conf"
printf '[global]\npid = %s/php-fpm.pid\nerror_log = %s/php-fpm.log\ninclude = %s/www.conf\n' "$RUN" "$RUN" "$RUN" > "$RUN/php-fpm.conf"
php-fpm8.3 -F -y "$RUN/php-fpm.conf" &
for _ in $(seq 50); do [ -S "$RUN/php-fpm.sock" ] && break; sleep 0.1; done
exec nginx -e "$RUN/error.log" -c "$RUN/nginx.conf" -g 'daemon off;'
