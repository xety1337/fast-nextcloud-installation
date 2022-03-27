#!/bin/sh

nextcloud_user="db_admin"
nextcloud_pass="db_pass"
admin_user="admin"
admin_pass="password"
nexcloud_link="https://download.nextcloud.com/server/releases/nextcloud-23.0.3.tar.bz2"

#install all requiered packages
apt update
apt upgrade -y
apt install apache2 php postgresql php-curl php-gd php-mbstring php-zip php-bz2 php-intl php-xml php-gmp php-apcu php-bcmath php-imap php-ldap php-mysql php-fpm php-cli php-pgsql php-igbinary smbclient -y

#download nextcloud
cd /var/www/
wget $nexcloud_link -qO - | tar -jxf -

sudo chown -R www-data:www-data /var/www/nextcloud/
cd /var/www/nextcloud/

#prepare Database
sudo -u postgres psql <<END
CREATE USER $nextcloud_user WITH PASSWORD '$nextcloud_pass';
CREATE DATABASE nextcloud WITH OWNER $nextcloud_user TEMPLATE template0 ENCODING 'UTF8';
END

#install nextcloud
sudo -u www-data php occ  maintenance:install --database \
"pgsql" --database-name "nextcloud"  --database-user "$nextcloud_user" --database-pass \
"$nextcloud_pass" --admin-user "$admin_user" --admin-pass "$admin_pass"

#make nextcloud locally available, add local ip to trusted_domains and Pretty URLs
myip_address="`hostname -I`"

sudo cat << SITE_AVAILABLE > /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
	DocumentRoot /var/www/nextcloud/
	ServerName  $myip_address
	<Directory /var/www/nextcloud/>
		Satisfy Any
		Require all granted
		AllowOverride All
		Options FollowSymLinks MultiViews
		<IfModule mod_dav.c>
			Dav off
		</IfModule>
	</Directory>
</VirtualHost>
SITE_AVAILABLE

sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value=$myip_address
sudo -u www-data php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value=http://$myip_address
sudo -u www-data php /var/www/nextcloud/occ config:system:set htaccess.RewriteBase --value=/
sudo -u www-data php /var/www/nextcloud/occ maintenance:update:htaccess
a2ensite nextcloud.conf

a2enmod rewrite headers proxy proxy_fcgi setenvif env mime dir authz_core alias ssl
a2enconf php7.4-fpm
systemctl reload apache2
service apache2 restart
