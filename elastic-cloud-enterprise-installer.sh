#!/bin/bash
set -e

REPOSITORY=docker.elastic.co/cloud-enterprise
HOST_STORAGE_PATH=/mnt/data/elastic
CLOUD_ENTERPRISE_VERSION=1.0.0-alpha4
ENABLE_DEBUG_LOGGING=false
OVERWRITE_EXISTING_IMAGE=false

while [ "$1" != "" ]; do
  echo $1
  echo $2
  case $1 in
    --coordinator-host )            shift
                                    COORDINATOR_HOST=$1
                                    ;;
    --host-storage-path )           shift
                                    HOST_STORAGE_PATH=$1
                                    ;;
    --cloud-enterprise-version )    shift
                                    CLOUD_ENTERPRISE_VERSION=$1
                                    ;;
    --debug )                       ENABLE_DEBUG_LOGGING=true
                                    ;;
    --repository )                  shift
                                    REPOSITORY=$1
                                    ;;
    --overwrite-existing-image )    OVERWRITE_EXISTING_IMAGE=true
                                    ;;
    --installation-id )             shift
                                    INSTALLATION_ID=$1
                                    ;;
    --public-host-name )            shift
                                    PUBLIC_HOST_NAME=$1
                                    ;;
    --host-ip )                     shift
                                    HOST_IP=$1
                                    ;;
    --availability-zone )           shift
                                    AVAILABILITY_ZONE=$1
                                    ;;
    --capacity )                    shift
                                    CAPACITY=$1
                                    ;;
  esac
  shift
done

createAndValidateHostStoragePath() {
  if test ! -e ${HOST_STORAGE_PATH}; then
    mkdir -p ${HOST_STORAGE_PATH}
    chown -R 1000:1000 ${HOST_STORAGE_PATH}
  fi

  if test ! -r ${HOST_STORAGE_PATH}; then
    printf "%s\n" "Host storage path ${HOST_STORAGE_PATH} exists but doesn't have read permissions for user '$(whoami)' with ID '$(id -u)'."
    printf "%s\n" "Please supply the correct permissions for the host storage path"
    exit 1
  fi

  if test ! -w ${HOST_STORAGE_PATH}; then
    printf "%s\n" "Host storage path ${HOST_STORAGE_PATH} exists but doesn't have write permissions for user '$(whoami)' with ID '$(id -u)'."
    printf "%s\n" "Please supply the correct permissions for the host storage path"
    exit 1
  fi
}

runBootstrapInitiatorContainer() {
  docker run \
      --env COORDINATOR_HOST=${COORDINATOR_HOST} \
      --env HOST_STORAGE_PATH=${HOST_STORAGE_PATH} \
      --env CLOUD_ENTERPRISE_VERSION=${CLOUD_ENTERPRISE_VERSION} \
      --env ENABLE_DEBUG_LOGGING=${ENABLE_DEBUG_LOGGING} \
      --env REPOSITORY=${REPOSITORY} \
      --env INSTALLATION_ID=${INSTALLATION_ID} \
      --env PUBLIC_HOST_NAME=${PUBLIC_HOST_NAME} \
      --env HOST_IP=${HOST_IP} \
      --env AVAILABILITY_ZONE=${AVAILABILITY_ZONE} \
      --env CAPACITY=${CAPACITY} \
      --env ROLE="bootstrap-initiator" \
      -p 20000:20000 \
      -v /run/docker.sock:/run/docker.sock \
      -v ${HOST_STORAGE_PATH}:${HOST_STORAGE_PATH} \
      --name elastic-cloud-enterprise-installer-${CLOUD_ENTERPRISE_VERSION} \
      --rm -it ${REPOSITORY}/elastic-cloud-enterprise:${CLOUD_ENTERPRISE_VERSION} elastic-cloud-enterprise-installer
}

pullElasticCloudEnterpriseImage() {
  printf "%s\n" "Pulling ${REPOSITORY}/elastic-cloud-enterprise:${CLOUD_ENTERPRISE_VERSION} image"
  docker pull ${REPOSITORY}/elastic-cloud-enterprise:${CLOUD_ENTERPRISE_VERSION}
}

main() {
  createAndValidateHostStoragePath

  if [ ${OVERWRITE_EXISTING_IMAGE} == false ]; then
    runBootstrapInitiatorContainer
  else
    if [ ${OVERWRITE_EXISTING_IMAGE} == true ]; then
      pullElasticCloudEnterpriseImage
      runBootstrapInitiatorContainer
    fi
  fi
}

# Main function
main
