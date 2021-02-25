#!/bin/bash

# {{{ config
mysql_host="localhost"
mysql_user="root"
mysql_pass="password"
	echo -n "Имя домена: "
	read domain_name
	if [ -z $domain_name ]; then
	$SETCOLOR_FAILURE
	echo "Вы не ввели имя домена"
	$SETCOLOR_NORMAL
	get_domain_name
	else
	return 1
	fi

dir_backup="/home/backup/"
dir_sites="/home/sites/$domain_name"

date_folder=`date +%Y-%m-%d`

days_keep_backup=10
# }}}

# {{{ remove old backups
find ${dir_backup} -maxdepth 1 -ctime +$[${days_keep_backup}-1] -exec rm -rf {} \; >/dev/null 2>&1
# }}}

# {{{ create folder backup
if ! [ -d ${dir_backup}${domain_name}/ ]; then
    mkdir -p ${dir_backup}${domain_name}/
    chmod 700 ${dir_backup}${domain_name}/
fi
# }}}

# {{{ mysql dump
if ! [ -d ${dir_backup}${domain_name}/mysql/ ]; then
    mkdir ${dir_backup}${domain_name}/mysql/
fi

for db_name in `mysql -u${mysql_user} -p${mysql_pass} -h${mysql_host} -e "show databases;" | tr -d "| " | grep -Ev "(Database|information_schema|performance_schema)"`
do
    if [[ ${db_name} != "information_schema" ]] && [[ ${db_name} != _* ]] ; then
        echo "Dumping database: ${db_name}"
        mysqldump -u${mysql_user} -p${mysql_pass} -h${mysql_host} --events ${db_name} > ${dir_backup}${domain_name}/mysql/${db_name}.sql
    fi
done
# }}}

# {{{ files sites backup
#if ! [ -d ${dir_backup}${date_folder}/home/ ]; then
#    mkdir ${dir_backup}${date_folder}/home/
#fi

cd ${dir_backup}/$domain_name

for site_folder in `ls ${dir_sites} | grep -Ev "*.(html|php)"`
do
    echo "Dumping site: ${site_folder}"
    tar -pczvf $domain_name.tar.gz --exclude="*.jpg" --exclude "*.png" --exclude "*.gif" /home/sites/$domain_name
done
# }}}

# {{{ etc folder backup
if ! [ -d ${dir_backup}${domain_name}/etc/ ]; then
    mkdir ${dir_backup}${domain_name}/etc/
fi

echo "Dumping /etc/"
tar cpfP ${dir_backup}${domain_name}/etc/etc.tar ${dir_backup}/$domain_name
# }}}
