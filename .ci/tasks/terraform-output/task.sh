#!/bin/sh
export DIR="${PWD}"
cd ${DIR}/source/examples/${directory}
terraform init
terraform output -json > ${DIR}/terraform-out/terraform-out.json