#!/bin/bash
mkdir -p /dist
source/docker/build.sh
export DIR="${PWD}"
cd source
mkdir -p /dist
make build-csv-processor
make build-manifest-processor
make build-bucket-forwarder
cp -a ${DIR}/source/. ${DIR}/built-source/