#!/bin/bash
# 테스트용 Docker container들을 연결할 네트워크를 생성
docker network create --driver=bridge dream-x-network
