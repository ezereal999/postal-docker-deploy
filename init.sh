#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "用法: $0 <你的Postal主域名，例如 postal.example.com>"
  exit 1
fi

POSTAL_HOSTNAME="$1"
mkdir -p config

if [ ! -f "config/postal.yml" ]; then
  echo "=> 生成 Postal 配置文件..."
  cp config/postal.yml.example config/postal.yml
  sed -i "s/postal.yourdomain.com/${POSTAL_HOSTNAME}/g" config/postal.yml
  sed -i "s/mx.postal.yourdomain.com/mx.${POSTAL_HOSTNAME}/g" config/postal.yml
  sed -i "s/rp.postal.yourdomain.com/rp.${POSTAL_HOSTNAME}/g" config/postal.yml
  sed -i "s/spf.postal.yourdomain.com/spf.${POSTAL_HOSTNAME}/g" config/postal.yml
  sed -i "s/track.postal.yourdomain.com/track.${POSTAL_HOSTNAME}/g" config/postal.yml
  sed -i "s/routes.postal.yourdomain.com/routes.${POSTAL_HOSTNAME}/g" config/postal.yml
  sed -i "s/postal.example.com/${POSTAL_HOSTNAME}/g" config/postal.yml
  SECRET_KEY=$(openssl rand -hex 64)
  sed -i "s/{{secretkey}}/${SECRET_KEY}/" config/postal.yml
fi

if [ ! -f "config/signing.key" ]; then
  echo "=> 生成签名密钥 signing.key..."
  openssl genrsa -out config/signing.key 1024
  chmod 600 config/signing.key
fi

echo "=> 启动数据库和 RabbitMQ 服务..."
docker compose up -d mariadb rabbitmq

echo "=> 正在等待数据库启动完成..."
until docker exec postal-mariadb mysqladmin ping -ppostal --silent; do
  sleep 2
done

echo "=> 初始化 Postal 数据库 (postal initialize)..."
docker compose run --rm postal postal initialize

echo "=> 创建 Postal 管理员账户 (postal make-user)..."
docker compose run --rm postal postal make-user

echo "=> 启动 Postal 服务..."
docker compose up -d postal

echo "Postal 部署完成！请访问 https://${POSTAL_HOSTNAME} 登录后台。"