#!/bin/bash

CURRENT_WORKING_DIR=`pwd`

# 
source ./env

# initdb script를 생성하여 마운트할 볼륨에 복사한다. 스크립트에서는 SERVICE_VS_USER 환경변수를 참조한다.
mkdir -p ${CURRENT_WORKING_DIR}/volumes/vectorstore/docker-entrypoint-initdb.d
chmod 777 ${CURRENT_WORKING_DIR}/volumes/vectorstore/docker-entrypoint-initdb.d
./create-initdb-sql.sh > ${CURRENT_WORKING_DIR}/volumes/vectorstore/docker-entrypoint-initdb.d/initdb.sql

mkdir -p ${CURRENT_WORKING_DIR}/volumes/vectorstore/data
chmod 7777 ${CURRENT_WORKING_DIR}/volumes/vectorstore/data

docker run -d \
  --network dream-x-network \
  -e POSTGRES_DB=${SERVICE_VS_DATABASE} \
  -e POSTGRES_USER=${SERVICE_VS_USER} \
  -e POSTGRES_PASSWORD=${SERVICE_VS_PASSWD} \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  -v ${CURRENT_WORKING_DIR}/volumes/vectorstore/data:/var/lib/postgresql/data \
  -v ${CURRENT_WORKING_DIR}/volumes/vectorstore/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
  -p ${SERVICE_VS_PORT}:5432 \
  --name vs \
  --hostname vs \
 pgvector/pgvector:pg16
