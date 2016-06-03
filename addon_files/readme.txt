test services ******************************
cd /Users/admin/Work/PServices/addon_files
sh install_services.sh
... or
sh uninstall_services.sh


enable php *********************************
edit file "/etc/apache2/httpd.conf"
uncomment line like "php5_module libexec/apache2/libphp5.so"
restart apache: "sudo apachectl restart"


mysql **************************************
http://dev.mysql.com/downloads/workbench/
http://dev.mysql.com/downloads/mysql/

after mysql server installation launch mysql server:
sudo launchctl load -F /Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist
...then change default password
/usr/local/mysql/bin/mysql -uroot -p"your_default_password"
SET PASSWORD = PASSWORD('your_new_password');