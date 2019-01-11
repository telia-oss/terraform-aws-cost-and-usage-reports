#!/bin/bash
source/docker/build.sh
export DIR="${PWD}"
cd source
make build-csv-processor
make build-manifest-processor
make build-bucket-forwarder
cp -a ${DIR}/source/. ${DIR}/built-source/