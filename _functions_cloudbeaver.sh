#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_CLOUDBEAVER_LOADED:-false} && return
set -u

# if the script was started from the base directory, then the
# expansion returns a period
if test "${SCRIPT_DIR}" == "."; then
  SCRIPT_DIR="$PWD"
  # if the script was not called with an absolute path, then we need to add the
  # current working directory to the relative path of the script
elif test "${SCRIPT_DIR:0:1}" != "/"; then
  SCRIPT_DIR="$PWD/${SCRIPT_DIR}"
fi

do_get_cloudbeaver_settings() {  
  if [ "${DEPLOYMENT_CLOUDBEAVER_ENABLED}" == "false" ]; then
    return;
  fi
  env_var DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME "${INSTANCE_KEY}_Cloudbeaver"
  case ${DEPLOYMENT_DB_TYPE} in
    DOCKER_MYSQL)
      env_var DEPLOYMENT_CLOUDBEAVER_DB_PROVIDER "mysql"
      env_var DEPLOYMENT_CLOUDBEAVER_DB_PROTO "mysql"
      env_var DEPLOYMENT_CLOUDBEAVER_DB_NAME "MySQL"
    ;;
    DOCKER_POSTGRES)
      env_var DEPLOYMENT_CLOUDBEAVER_DB_PROVIDER "postgres"
      env_var DEPLOYMENT_CLOUDBEAVER_DB_PROTO "postgresql"
      env_var DEPLOYMENT_CLOUDBEAVER_DB_NAME "PostgreSQL"
    ;;  
    *)
      echo_error "Invalid database type \"${DEPLOYMENT_DB_TYPE}\""
      print_usage
      exit 1
    ;;
  esac  
}

#
# Drops all Cloudbeaver data used by the instance.
#
do_drop_cloudbeaver_data() {
  echo_info "Dropping Cloudbeaver data ..."
  if [ "${DEPLOYMENT_CLOUDBEAVER_ENABLED}" == "true" ]; then
    echo_info "Drops Cloudbeaver container ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} ..."
    delete_docker_container ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME}
    delete_docker_volume ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME}_cbeaver
    echo_info "Done."
    echo_info "Cloudbeaver data dropped"
  else
    echo_info "Skip Drops Cloudbeaver container ..."
  fi
}

do_stop_cloudbeaver() {
  echo_info "Stopping Cloudbeaver ..."
  if [ "${DEPLOYMENT_CLOUDBEAVER_ENABLED}" == "false" ]; then
    echo_info "Cloudbeaver wasn't specified, skiping its server container shutdown"
    return
  fi
  ensure_docker_container_stopped ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME}
  echo_info "Cloudbeaver container ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} stopped."
}

do_start_cloudbeaver() {
  echo_info "Starting Cloudbeaver..."
  if [ "${DEPLOYMENT_CLOUDBEAVER_ENABLED}" == "false" ]; then
    echo_info "Cloudbeaver not specified, skiping its server container startup"
    return
  fi

  echo_info "Starting Cloudbeaver container ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} based on image ${DEPLOYMENT_CLOUDBEAVER_IMAGE}:${DEPLOYMENT_CLOUDBEAVER_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME}
  delete_docker_volume ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME}_cbeaver
  ${DOCKER_CMD} volume create ${DEPLOYMENT_CONTAINER_NAME}_cbeaver
  local volume_path=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_CONTAINER_NAME}_cbeaver)
  cp -rvf ${ETC_DIR}/cloudbeaver ${DEPLOYMENT_DIR}/cloudbeaver 
  evaluate_file_content ${DEPLOYMENT_DIR}/cloudbeaver/GlobalConfiguration/.dbeaver/data-sources.json.template ${DEPLOYMENT_DIR}/cloudbeaver/GlobalConfiguration/.dbeaver/data-sources.json
  sudo mv ${DEPLOYMENT_DIR}/cloudbeaver/GlobalConfiguration ${volume_path}/GlobalConfiguration
  local CB_LOCAL_HOST_ADDR=$(ifconfig | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v 127.0.0.1 | awk '{ print $2 }' | cut -f2 -d: | head -n1)

  ${DOCKER_CMD} run \
  -d \
  -e CLOUDBEAVER_USER=root \
  -e CLOUDBEAVER_PASSWORD=password \
  -p "${DEPLOYMENT_CLOUDBEAVER_HTTP_PORT}:8978" \
  -v "${DEPLOYMENT_CONTAINER_NAME}_cbeaver:/opt/cloudbeaver/workspace" \
  --add-host=host.docker.internal:${CB_LOCAL_HOST_ADDR} \
  --name ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} ${DEPLOYMENT_CLOUDBEAVER_IMAGE}:${DEPLOYMENT_CLOUDBEAVER_IMAGE_VERSION}

  echo_info "${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} container started"  
  check_cloudbeaver_availability

}

check_cloudbeaver_availability() {
  echo_info "Waiting for Cloudbeaver availability on port ${DEPLOYMENT_CLOUDBEAVER_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    curl -s -q --max-time ${wait_time} http://localhost:${DEPLOYMENT_CLOUDBEAVER_HTTP_PORT}  > /dev/null
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Cloudbeaver not yet available (${count} / ${try})..."    
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Cloudbeaver ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Cloudbeaver ${DEPLOYMENT_CLOUDBEAVER_CONTAINER_NAME} up and available"
}

# #############################################################################
# Env var to not load it several times
_FUNCTIONS_CLOUDBEAVER_LOADED=true
echo_debug "_function_cloudbeaver.sh Loaded"