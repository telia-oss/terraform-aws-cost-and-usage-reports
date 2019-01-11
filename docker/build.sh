#!/bin/bash
set -ex

echo "Update and install os packages"
yum update -y
yum install -y \
    gcc \
    gcc-c++ \
    lapack-devel \
    python27-devel \
    python27-virtualenv \
    findutils \
    zip

echo "Setting up virtualenv"
/usr/bin/virtualenv \
    --python /usr/bin/python /venv \
    --always-copy \
    --no-site-packages
source /venv/bin/activate

echo "Update and install python packages"
pip install --upgrade pip wheel
pip install -r source/docker/requirements.txt

echo "Stripping binaries"
find $VIRTUAL_ENV/lib64/python2.7/site-packages/ -name "*.so" | xargs strip

echo "Adding lib/python2.7/site-packages/ to environment.zip"
pushd $VIRTUAL_ENV/lib/python2.7/site-packages/
zip -r -9 /tmp/environment.zip *
popd

echo "Adding lib64/python2.7/site-packages/ to environment.zip"
pushd $VIRTUAL_ENV/lib64/python2.7/site-packages/
zip -r -9 /tmp/environment.zip *
popd

mv /tmp/environment.zip source/dist
echo "Saved to environment.zip to /dist"
