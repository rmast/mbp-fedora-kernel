#!/bin/bash

set -eu -o pipefail

DOCKER_IMAGE=fedora:33
# DOCKER_IMAGE=fedora_build:33
RPMBUILD_HOST_PATH=~/rpmbuild

mkdir -p ${RPMBUILD_HOST_PATH}

RPM_SIGNING_KEY=${RPM_SIGNING_KEY:-$(gpg --export-secret-keys -a 'mbp-fedora' | base64)}

# docker pull ${DOCKER_IMAGE}
docker run \
  -t \
  --rm \
  -e RPM_SIGNING_KEY="$RPM_SIGNING_KEY" \
  -v "$(pwd)":/repo \
  -v ${RPMBUILD_HOST_PATH}:/root/rpmbuild \
  -w /repo \
  ${DOCKER_IMAGE} \
  /bin/bash -c './build.sh'
