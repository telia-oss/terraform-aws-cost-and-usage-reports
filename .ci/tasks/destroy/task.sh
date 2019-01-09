#!/bin/sh
export DIR="${PWD}"
cd ${DIR}/secret-source/examples/${directory}
rm -rf .terraform
terraform init
terraform destroy --auto-approve
