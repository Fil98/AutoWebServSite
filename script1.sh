#!/bin/bash

echo "Loading....."

####### CONFIG START ########

OWNER_NAME='root' # Пользователь, которому будет принадлежать директория вирт. хоста 
OWNER_GROUP='root' # Группа, которой будет принадлежать директория вирт. хоста 
HOME_WWW=/home/sites # Домашняя директория для вирт. хостов 
HOST_DIRS=('logs' 'www') 
SERVER_IP='127.0.0.1' # IP адрес сервера

WHEREIS_APACHE=/etc/apache2
WHEREIS_NGINX=/etc/nginx

APACHE_HOSTS_DIR=$WHEREIS_APACHE'/sites-available'
NGINX_HOSTS_DIR=$WHEREIS_NGINX'/sites-available'
NGINX_HOSTS_ENABLED=$WHEREIS_NGINX'/sites-enabled'

######## CONFIG END ##########

# COLORS
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_NOTICE="echo -en \\033[1;33;40m"

# FUNCTIONS

function restart_servers {
    echo 'Перезапускаем Apache'
    systemctl reload apache2

    echo 'Перезапускаем Nginx'
    systemctl reload nginx

    return 1
}

function error_config {
    $SETCOLOR_FAILURE
    echo "$(tput hpa $(tput cols))$(tput cub 6)[Fail]"
    echo '[CONFIG ERROR]: '$1
    $SETCOLOR_NORMAL

    exit 1
}

function error_force_exec {
    $SETCOLOR_FAILURE
    echo "$(tput hpa $(tput cols))$(tput cub 6)[Fail]"
    echo -n '[FORCE EXEC ERROR]: '

    if [ -z "$1" ]; then
        echo 'Скрипт не может корректно выполнить все процедуры в автоматическом режиме'
    else
        echo $1
    fi

    $SETCOLOR_NORMAL

    exit 1
}

function error_failure {
    $SETCOLOR_FAILURE
    echo "$(tput hpa $(tput cols))$(tput cub 6)[Fail]"
    echo '[ERROR]: '$1
    $SETCOLOR_NORMAL

    exit 1
}

function error_notice {
    $SETCOLOR_NOTICE
    echo '[NOTICE]: '$1
    $SETCOLOR_NORMAL

    return 1
}

# Если запущен с ключем -f, значит задаем пользователю минимум вопросов 
# Игнорируются вопросы: 
# - имя директории виртуального хоста 
# - вопрос о перезапуске серверов (будут перезапущены)

force_execution=false
if [ "$1" == "-f" ]; then
    force_execution=true
fi

echo

$SETCOLOR_NORMAL

if [ -d "$HOME_WWW" ]; then
    cd "$HOME_WWW"
else
    error_config "Директория $HOME_WWW не существует"
fi

# Запрашивает имя домена, пока не будет введено
function get_domain_name {
    echo -n "Имя домена: "
    read -r domain_name

    # Если ничего не было введено
    if [ -z "$domain_name" ]; then
        $SETCOLOR_FAILURE
        echo "Вы не ввели имя домена"
        $SETCOLOR_NORMAL
        get_domain_name
    else
        return 1
    fi
}

# Запрашивает имя директории для виртуального хоста или предлагает создать автоматически 
# проверяет его на существование
function get_host_dir {
    echo -n "Имя директории хоста (нажмите enter чтобы выбрать по умолчанию директорию (/home/sites/domain_name/)): "
    read -r host_dir

    # Если ничего не было введено
    if [ -z "$host_dir" ]; then
        $SETCOLOR_NOTICE
        echo -n "Вы не ввели имя директории хоста. Создать автоматически в /home/sites/domain_name? [Y/N]? "
        $SETCOLOR_NORMAL

        read -r answer

        case "$answer" in
            Y|y|д|Д)
                host_dir=${domain_name//./_}
                host_dir=${host_dir//-/}

                if [ -d "${HOME_WWW}/${host_dir}" ]; then
                    error_notice "Автоматический выбор имени директории невозможен. Задайте его самостоятельно"
                    get_host_dir
                else
                    error_notice "Директория хоста будет создана автоматически: $host_dir"
                fi
                return 1
                ;;
            N|n|о|О) get_host_dir
                ;;
            *) get_host_dir
                ;;
        esac
        get_host_dir
    else
        return 1
    fi
}

get_domain_name

if $force_execution; then
    host_dir=${domain_name//./_}

    if [ -d "${HOME_WWW}/${host_dir}" ]; then
        error_force_exec
    fi
else
    get_host_dir
fi

# Проверяем пути Apache из конфига
if [ -d "$APACHE_HOSTS_DIR" ]; then
    if [ -e "$APACHE_HOSTS_DIR/$domain_name" ]; then
        error_failure "Виртуальный хост $domain_name уже существует для Apache"
    fi
else
    error_config "Директория $APACHE_HOSTS_DIR не существует"
fi

# Проверяем пути Nginx из конфига
if [ -d "$NGINX_HOSTS_DIR" ]; then
    if [ -e "$NGINX_HOSTS_DIR/$domain_name" ]; then
        error_failure "Виртуальный хост $domain_name уже существует для Nginx"
    fi
else
    error_config "Директория $NGINX_HOSTS_DIR не существует"
fi

echo "Домен: $domain_name"

# Создаем директории виртуального хоста
host_dir_path="${HOME_WWW}/${host_dir}"
echo "Создаем директории виртуального хоста:"

mkdir -p "$host_dir_path"
for dir_name in "${HOST_DIRS[@]}"; do
    mkdir -p "$host_dir_path/$dir_name"
    echo -e "\t $host_dir_path/$dir_name"
done

touch "${host_dir_path}/www/index.html"

# Рекурсивно проставляем права
chown -R "$OWNER_NAME:$OWNER_GROUP" "$host_dir_path"

apache_template="<VirtualHost *:8080>
      ServerAdmin webmaster@$domain_name
      ServerName $domain_name
      ServerAlias www.$domain_name
      DocumentRoot $HOME_WWW/$host_dir/www

      ScriptAlias /cgi-bin/ $HOME_WWW/$host_dir/www/cgi-bin/
      ErrorLog $HOME_WWW/$host_dir/logs/apache.error.log
      LogLevel warn
      CustomLog $HOME_WWW/$host_dir/logs/apache.access.log combined
</VirtualHost>"

# Создаем конфиг виртуального хоста Apache
echo 'Создаем конфиг виртуального хоста Apache:'
echo "$apache_template" > "${APACHE_HOSTS_DIR}/${domain_name}"
echo -e "\t${APACHE_HOSTS_DIR}/${domain_name}"

# создаем симлинк
a2ensite "$domain_name"

nginx_template="server {
      listen *:80;

      server_name $domain_name www.$domain_name;
      access_log  $HOME_WWW/$host_dir/logs/nginx.access.log;

      location ~* ^.+\.(jpg|jpeg|gif|png|svg|js|css|mp3|ogg|mpe?g|avi|zip|gz|bz2?|rar)$ {
            root $HOME_WWW/$host_dir/www;
      }

      location / {
            proxy_pass http://backend;
            proxy_redirect off;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;

            charset utf-8;
            index index.html;
            root $HOME_WWW/$host_dir/www;
      }
}"

# Создаем конфиг виртуального хоста Nginx
echo 'Создаем конфиг виртуального хоста Nginx:'
echo "$nginx_template" > "${NGINX_HOSTS_DIR}/${domain_name}"
echo -e "\t${NGINX_HOSTS_DIR}/${domain_name}"

# создаем симлинк
ln -s "${NGINX_HOSTS_DIR}/${domain_name}" "${NGINX_HOSTS_ENABLED}/${domain_name}"

# Перезапускаем сервера
if $force_execution; then
    restart_servers
else
    echo -n 'Перезапустить Apache и Nginx? [Y/N] '
    read -r restart_answer

    case "$restart_answer" in
        Y|y|д|Д)
            restart_servers
        ;;
        *)
            echo 'Apache и Nginx не были перезагружены'
        ;;
    esac
fi

$SETCOLOR_SUCCESS
echo "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
$SETCOLOR_NORMAL

####################END NGINX AND APACHE CONFIG#################

echo "Loading....."
###############START CREATE DATABASE MYSQL######################
echo -e "Создать базу Mysql? (yes/no)"
read -r CREATE_BAZA

if [[ "$CREATE_BAZA" =~ ^(yes|y|YES|Y)$ ]]; then
    echo -e "Введите имя базы данных (по умолчанию $domain_name): "
    read -r NAME_OF_PROJECT
    NAME_OF_PROJECT=${NAME_OF_PROJECT:-$domain_name}

    ##########Generation pass##############
    gen_pass() {
      vector=$1
      length=$2
      [ -z "$vector" ] && vector=0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
      [ -z "$length" ] && length=21
      pass=$(cat /dev/urandom | tr -dc "$vector" | fold -w "$length" | head -n 1)
      echo "$pass"
    }
    #########################################

    pass="$(gen_pass)"
    mysql -uroot -p"$pass" --execute="CREATE DATABASE $NAME_OF_PROJECT;"
    mysql -uroot -p"$pass" --execute="GRANT ALL PRIVILEGES ON $NAME_OF_PROJECT.* TO '${NAME_OF_PROJECT}_user'@'localhost' IDENTIFIED BY '$pass' WITH GRANT OPTION;"

    echo -e "База данных $NAME_OF_PROJECT создана"
fi
###############END CREATE DATABASE MYSQL######################

echo "Перезапускаем apache..."
systemctl restart apache2
echo -e "Локальный сайт готов к работе."

################PROFTP CREATE################
mkdir -p "/home/sites/$domain_name/ftp"
echo "$pass" | sudo ftpasswd --stdin --passwd --file=/etc/proftpd/ftppasswd --name="$domain_name" --uid=60 --gid=60 --home="/$host_dir_path/ftp" --shell=/bin/false
###############END PROFTP CREATE#############

echo "Loading....."
#################START JSON#############################
cat << EOF > "$host_dir_path/json.txt"
{
    "domainname": "$domain_name",
    "db": "$domain_name",
    "location": {
        "street": "Block 1",
        "city": "Innopolis",
        "country": "RU"
    }
}
EOF

jq . "$host_dir_path/json.txt"
#################END JSON###############################

echo "Loading....."

############TEST HOST####################
/sbin/apache2ctl -t -D DUMP_VHOSTS ### получить список виртуальных хостов, настроенных на определенном сервере

echo "Loading......."

hosts=("$domain_name" "127.0.0.1")
for h in "${hosts[@]}"; do
    result=$(ping -c 2 -W 1 -q "$h" | grep transmitted)
    pattern="0 received"
    if [[ $result =~ $pattern ]]; then
        echo "$h is down"
    else
        echo "$h is up"
    fi
done
############TEST HOST####################
echo "Loading....."

##################SEND TO MAIL##################
{
    echo "***********************************"
    echo "** Отправляем данные на email : **"
    echo "***********************************"
    echo "** Имя домена: $domain_name"
    echo "** Создана новая база MySql с именем: $domain_name"
    echo "** К этой базе нужно коннектится под юзером: ${domain_name}_user"
    echo "** Пользователь proftpd: $domain_name"
    echo "** Пароль proftpd: $pass"
    echo "** Пароль БД: $pass"
} >> "$host_dir_path/mail.txt"

mail -s "Данные сайта" ilya.rocker.1998@gmail.com < "$host_dir_path/mail.txt"
##################END SEND TO MAIL##################

echo "***********************************"
