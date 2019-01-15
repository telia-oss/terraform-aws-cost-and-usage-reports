#!/bin/sh
export DIR="${PWD}"
cd ${DIR}/source/examples/${directory}
rm -rf .terraform
terraform init
terraform destroy --auto-approve
