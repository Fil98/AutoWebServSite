# JustScriptsAddSiteAndDB
We have a ready-configured server on which Debian OC and web environment:
- nginx
-apache2
- mysql
- proftpd

Debian 10.x
sudo apt-get update && apt-get install nginx php7.0-fpm php7.0-mysql mysql-server curl php mysql mailutils posftix jq

need to create 2 scripts on bash

The first script accepts the domain name as a positional parameter
The script creates:
- DocumentRoot of the site at the path /home/sites/(domain name)/www
- Virtual host in nginx, where the static is given by nginx, and php scripts are proxied to apache2
- Virtual host in apache2
- A database and a user with full privileges to this database in MySQL.
The database name is formed from the domain name, where the dots and hyphens should be replaced with an underscore. (For example, a domain name site-studio.ru, should become site_studio_ru)
The user name is the same as the DB name.
For the password, use the gen_pass function shown below.
- A proFTPd virtual user account using the ftpasswd program (authorization is stored in the /etc/proftpd/ftppasswd file, the working directory for the user is created at the path /home/sites/(domain name) / ftp). The user name is formed in the same way as the database name.
- Restarts the necessary services for the changes to take effect
- Makes an HTTP request to an abstract API with the transfer in the request body of JSON (domain name and access details) (you can create the JSON structure yourself)
- Tests the host for availability
- Sends a report with access details to the e-mail address

The second script also accepts the domain name as a positional parameter
The script makes a backup of the site and the database:
- The path for storing backups /home / backup
-The site files are located on the path /home/sites/(domain name)/www
- Backup files to archive in the format tar.gz, when backing up exclude files with the extension jpg, png,gif
-Dump the database using mysqldump
-Backups older than 10 days to delete.
