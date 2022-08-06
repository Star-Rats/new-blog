#!/bin/bash
read -p "请输入接口IP(例:127.0.0.1):" SERVER_IP
read -p "请输入接口PORT(例:8080)" SERVER_PORT
read -p "是否使用HTTPS[y/n]:" USE_HTTPS

if  test y = $USE_HTTPS
then
    PROTOCOL='https'
else
    PROTOCOL='http'
fi
BASE_API="${PROTOCOL}://${SERVER_IP}:${SERVER_PORT}"
echo "接口地址为${BASE_API}"

#修改BLOG前端的BASEAPI
sed -i "s#http://localhost:8080#$BASE_API#g" blog-vue/admin/vue.config.js
sed -i "s#http://localhost:8080#$BASE_API#g" blog-vue/blog/vue.config.js

#安装docker 没有就装有就跳过

echo "检查Docker是否安装......"
docker -v
   if [ $? -eq  0 ]; then
     	echo "检查到Docker已安装!"
   else
   	echo "安装docker环境..."
       	curl -sSL https://get.daocloud.io/docker | sh
       	echo "安装docker环境...安装完成!"
   fi

#安装docker-compose没有就安装 有就跳过
echo '检查docker-compose是否安装...'
docker-compose --version
	if [ $? -eq  0 ]; then
        	echo "检查到docker-compose已安装!"
  	 else
        	echo "安装docker-compose环境..."
       		sudo curl -L https://get.daocloud.io/docker/compose/releases/download/1.24.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
		sudo chmod +x /usr/local/bin/docker-compose
		docker-compose --version
			if [ $? -eq  0 ]; then
			  	echo "安装docker-compose环境...安装完成!"
  			else
       			 	echo "安装docker-compose环境...安装失败!"
              exit 8
  			fi
  fi

#安装JDk
echo "检查jdk是否安装......."
java -version 
	if [ $? -eq  0 ]; then
        	echo "检查到JDK已安装!"
  	 else
        	echo "安装JDK..."
       		mkdir /opt/jdk/
          wget -P /opt/jdk/ https://repo.huaweicloud.com/java/jdk/8u202-b08/jdk-8u202-linux-x64.tar.gz
          tar -zxvf /opt/jdk/jdk-8u202-linux-x64.tar.gz -C /opt/jdk/
          sed -i '$aexport JAVA_HOME=/opt/jdk/jdk1.8.0_202' /etc/profile
          sed -i '$aexport PATH=$PATH:$JAVA_HOME/bin' /etc/profile

          source /etc/profile
          
		  java -version
			if [ $? -eq  0 ]; then
			  	echo "JDK...安装完成!"
  			else
       			 	echo "JDK...安装失败!"
              exit 8
  		fi
  fi
  
  
#安装maven
echo "检查maven是否安装......."
mvn -v 
	if [ $? -eq  0 ]; then
        	echo "检查到maven已安装!"
  	 else
        	echo "安装maven环境..."
       		mkdir /opt/maven/
          wget -P /opt/maven https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
          tar -zxvf /opt/maven/apache-maven-3.6.3-bin.tar.gz -C /opt/maven/
          sed -i '$aexport MAVEN_HOME=/opt/maven/apache-maven-3.6.3' /etc/profile
          sed -i '$aexport PATH=$PATH:$MAVEN_HOME/bin' /etc/profile
          source /etc/profile

           rm -rf /opt/maven/apache-maven-3.6.3/conf/settings.xml
           touch /opt/maven/apache-maven-3.6.3/conf/settings.xml
           sudo cat >> /opt/maven/apache-maven-3.6.3/conf/settings.xml << EOF 
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
<pluginGroups>
</pluginGroups>
<proxies>
</proxies>
<servers>
</servers>
<mirrors>
    <mirror>
        <id>nexus-aliyun</id>
        <mirrorOf>central</mirrorOf>
        <name>Nexus aliyun</name>
        <url>http://maven.aliyun.com/nexus/content/groups/public</url>
    </mirror>
</mirrors>
<profiles>
</profiles>
</settings>    
EOF
         
		  /opt/maven/apache-maven-3.6.3/bin/mvn -v
			if [ $? -eq  0 ]; then
			  	echo "maven...安装完成!"
  			else
       		echo "maven环境...安装失败!"
          exit 8
  		fi
  fi
  
  
#安装node
echo "检查node是否安装......."
node -v 
	if [ $? -eq  0 ]; then
        	echo "检查到node已安装!"
  	 else
        	echo "安装node环境..."
       		yum install -y epel-release
          yum install -y nodejs
	  yum install -y npm
		  npm -v
			if [ $? -eq  0 ]; then
			  	echo "node...安装完成!"
  			else
       	  echo "node环境...安装失败!"
          exit 8
  		fi
  fi

# 接口打包
echo "接口开始打包......."
cd blog-springboot/
/opt/maven/apache-maven-3.6.3/bin/mvn clean package -Dmaven.test.skip=true 
#构建接口Docker镜像
docker build -t blog:v1 .
cd -

# 前端blog打包
cd blog-vue/blog/
npm config set registry https://registry.npm.taobao.org
npm install
npm run build
mkdir -p /opt/blog/blog
cp -r dist/* /opt/blog/blog
cd -

# 前端admin打包
cd blog-vue/admin/
npm install
npm run build
mkdir -p /opt/blog/admin
cp -r dist/* /opt/blog/admin
cd -

read -p "是否使用已经存在的MySQL[y/n]:" USE_OTHER_MYSQL
if  test y = $USE_OTHER_MYSQL
then
    read -p "MySQL IP:" MYSQL_IP
    read -p "MySQL PORT:" MYSQL_PORT
    read -p "MySQL USERNAME:" MYSQL_USER_NAME
    read -p "MYSQL PASSWORD:" MYSQL_PASSWORD
else
    read -p "请输入MySQL root帐号的默认密码:" MYSQL_PASSWORD
    MYSQL_IP='127.0.0.1'
    MYSQL_PORT=3306
    MYSQL_USER_NAME=root
mkdir -p /blog/dev/data/mysql/conf/
rm -rf /blog/dev/data/mysql/conf/my.cnf
touch /blog/dev/data/mysql/conf/my.cnf
cat >> /blog/dev/data/mysql/conf/my.cnf << EOF
[mysqld]
default_authentication_plugin=mysql_native_password  #使用mysql8以前的密码插件，以便navicat等工具能够正常连接
default-storage-engine=INNODB
character_set_server = utf8
secure_file_priv=/var/lib/mysql
[mysqld_safe]
character_set_server = utf8
[mysql]
default-character-set = utf8
[mysql.server]
default-character-set = utf8
[client]
default-character-set = utf8
EOF
    #安装MySQL 最新版本为MySQL8
    docker run -p $MYSQL_PORT:$MYSQL_PORT --name blog-mysql -v /blog/dev/data/mysql/conf:/etc/mysql -v /blog/dev/data/mysql/log:/var/log/mysql -v /blog/dev/data/mysql/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=$MYSQL_PASSWORD  -e TZ="Asia/Shanghai" -d --restart=always mysql:8.0
    # 将数据库的SQL文件初始化到MySQL中去
    docker cp blog-mysql8.sql blog-mysql:/
    rm -rf init_database.sql
    touch init_database.sql

cat >> init_database.sql << EOF
use mysql;
#update user set host = '%' where user = 'root';
#flush privileges;
alter user 'root'@'%' identified with mysql_native_password by '$MYSQL_PASSWORD';
CREATE DATABASE blog CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
flush privileges;
EOF
    docker cp init_database.sql  blog-mysql:/
    echo "考虑到你的机器可能有点拉，MySQL可能还没启动成功，在这里等它3分钟，你可以放松一下"
    sleep 180
    docker exec -it blog-mysql /bin/bash -c "mysql -uroot -p'$MYSQL_PASSWORD' -e 'source /init_database.sql'"
    docker exec -it blog-mysql /bin/bash -c "mysql -uroot -p'$MYSQL_PASSWORD' -e 'use blog;source /blog-mysql8.sql;'"
fi

# 是否使用已经存在的redis,没有就使用创建的redis容器
read -p "是否使用已经存在的redis[y/n]:" USE_OTHER_REDIS
if  test y = $USE_OTHER_REDIS
then
    read -p "REDIS IP:" REDIS_HOST
    read -p "REDIS PORT:" REDIS_PORT
    read -p "REDIS PASSWORD:" REDIS_PASSWORD
else
    read -p "请输入redis的默认密码:" REDIS_PASSWORD
    REDIS_HOST='127.0.0.1'
    REDIS_PORT=6379
    docker run --name blog-redis  --restart=always -p $REDIS_PORT:$REDIS_PORT -d redis --requirepass "$REDIS_PASSWORD"
fi

#是否使用自建rabbitmq
read -p "是否使用已经存在的rabbitmq[y/n]:" USE_OTHER_MQ
if  test y = $USE_OTHER_MQ
then
    read -p "MQ HOST:" MQ_HOST
    read -p "MQ PORT:" MQ_PORT
    read -p "MQ USERNAME:" MQ_USER_NAME
    read -p "MQ PASSWORD:" MQ_PASSWORD
else
    MQ_IP='127.0.0.1'
    MQ_PORT=5672
    MQ_USER_NAME='guest'
    MQ_PASSWORD='guest'
    docker run --name blog-rabbit --restart=always -p 15672:15672 -p 5672:5672  -d  rabbitmq:management
fi

#安装NGINX
echo "开始安装NGINX......"
systemctl stop firewalld
mkdir -p /blog/dev/nginx/
touch /blog/dev/nginx/nginx.conf
# 生成配置文件
sudo tee /blog/dev/nginx/nginx.conf << EOF
events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    client_max_body_size     50m;
    client_body_buffer_size  10m; 
    client_header_timeout    1m;
    client_body_timeout      1m;

    gzip on;
    gzip_min_length  1k;
    gzip_buffers     4 16k;
    gzip_comp_level  4;
    gzip_types text/plain application/javascript application/x-javascript text/css application/xml text/javascript application/x-httpd-php image/jpeg image/gif image/png;
    gzip_vary on;

server {
        listen       80;
        server_name  127.0.0.1;
     
        location / {		
            root   /usr/local/vue/blog;
            index  index.html index.htm; 
            try_files \$uri \$uri/ /index.html;	
        }
        
        location ^~ /api/ {		
            proxy_pass http://127.0.0.1:$SERVER_PORT/;
            proxy_set_header   Host             \$host;
            proxy_set_header   X-Real-IP       \$remote_addr;						
            proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
        }
    }
	
server {
        listen       81;
        server_name  127.0.0.1;
     
        location / {		
            root   /usr/local/vue/admin;
            index  index.html index.htm; 
            try_files \$uri \$uri/ /index.html;	
        }
        
        location ^~ /api/ {		
            proxy_pass http://127.0.0.1:$SERVER_PORT/;
            proxy_set_header   Host             \$host;
            proxy_set_header   X-Real-IP        \$remote_addr;						
            proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
        }
    }

server {
        listen       82;
        server_name  127.0.0.1;
     
        location / {
          proxy_pass http://127.0.0.1:8080/websocket;
          proxy_http_version 1.1;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection "Upgrade";
          proxy_set_header Host \$host:\$server_port;
          proxy_set_header X-Real-IP \$remote_addr;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto \$scheme;
       }
	
    }

server {
        listen       83;
        server_name  127.0.0.1;
     
        location / {		
          root /usr/local/upload/; 
        }		
		
    }
 
 }

EOF
docker run --name blog-nginx --restart=always --network=host -d -v /blog/dev/nginx/nginx.conf:/etc/nginx/nginx.conf -v /opt/blog/:/usr/local/vue -v /blog/dev/nginx/upload:/usr/local/upload nginx

read -p "请输入邮箱的host:" MAIL_HOST
read -p "请输入邮箱的用户名:" MAIL_USER_NAME
read -p "请输入邮箱的授权码或密码:" MAIL_PASSWORD
read -p "请输入邮箱服务器的端口:" MAIL_PORT

echo "上传模式为OSS,如果你需要其他的上传模式可以联系我或者自己修改该脚本~"
read -p "请输入OSS的URL:" OSS_URL
read -p "请输入OSS的accessKeyId:" OSS_AKID
read -p "请输入OSS的endpoint:" OSS_ENDPOINT
read -p "请输入OSS的accessKeySecret:" OSS_AKS
read -p "请输入OSS的bucketName:" OSS_BUCKET

echo "开始第三方配置......"
read -p "请输入qq的app-id:" QQ_APPID
read -p "请输入qq的check-token-url:" QQ_CTU
read -p "请输入qq的user-info-url:" QQ_UIU

read -p "请输入微博的app-id:" WB_APPID
read -p "请输入微博的app-secret:" WB_AS
read -p "请输入微博的grant-type:" WB_GT
read -p "请输入微博的redirect-url:" WB_RU
read -p "请输入微博的access-token-url:" WB_ATU
read -p "请输入微博的user-info-url:" WB_UIU

# 启动Blog接口容器
BOOT_PARAM="--server.port=$SERVER_PORT --spring.datasource.url=jdbc:mysql://$MYSQL_IP:$MYSQL_PORT/blog?serverTimezone=Asia/Shanghai&allowMultiQueries=true --spring.datasource.username=$MYSQL_USER_NAME --spring.datasource.password=$MYSQL_PASSWORD --spring.redis.host=$REDIS_HOST  --spring.redis.port=$REDIS_PORT --spring.redis.password=$REDIS_PASSWORD --spring.rabbitmq.host=$MQ_HOST  --spring.rabbitmq.port=$MQ_PORT --spring.rabbitmq.username=$MQ_USER_NAME --spring.rabbitmq.password=$MQ_PASSWORD  --spring.mail.host=$MAIL_HOST --spring.mail.username=$MAIL_USER_NAME --spring.mail.password=$MAIL_PASSWORD --spring.mail.port=$MAIL_PORT --upload.mode=oss --upload.oss.url=$OSS_URL  --upload.oss.endpoint=$OSS_ENDPOINT  --upload.oss.accessKeyId=$OSS_AKID --upload.oss.accessKeySecret=$OSS_AKS --upload.oss.bucketName=$OSS_BUCKET --websit.url=http://$SERVER_IP:80 --qq.app-id=$QQ_APPID --qq.check-token-url=$QQ_CTU --qq.user-info-url=$QQ_UIU --weibo.app-id=$WB_APPID --weibo.app-secret=$WB_AS --weibo.grant-type=$WB_GT --weibo.redirect-url=$WB_RU --weibo.access-token-url=$WB_ATU --weibo.user-info-url=$WB_UIU"
docker run --name blog --restart=always --network=host blog:v1 $BOOT_PARAM

