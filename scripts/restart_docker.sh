#!/usr/bin/env bash

echo -e "更新镜像"
docker pull registry.cn-shanghai.aliyuncs.com/aweminds/bolt.new:latest
docker pull registry.cn-shanghai.aliyuncs.com/aweminds/bolt.new:latest

#echo -e "重新启动服务..."
docker compose -f /root/llm/bolt.new/docker-compose.yml up -d

echo -e "删除悬空镜像..."
docker image prune -f
