#!/bin/bash -eu

# Don't load it several times
set +u
${_FUNCTIONS_ES_LOADED:-false} && return
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

do_get_es_settings() {
  env_var DEPLOYMENT_ES_CONTAINER_NAME "${INSTANCE_KEY}_es"
  configurable_env_var DEPLOYMENT_ES_HEAP "512m"
  # Make this configurable :
  configurable_env_var DEPLOYMENT_ES_SECURED_ENABLED true
  env_var DEPLOYMENT_ES_ELASTIC_PASSWORD "inKosHwKv2FZGAWLDvxL"
  env_var DEPLOYMENT_ES_EXO_PASSWORD "1h6nrptc5Py7n3nAfxkO"
}

#
# Drops all Elasticsearch datas used by the instance.
#
do_drop_es_data() {
  echo_info "Dropping es data ..."
  if ${DEPLOYMENT_ES_ENABLED}; then
    if ${DEPLOYMENT_ES_EMBEDDED}; then
      local path="${DEPLOYMENT_DIR}/${DEPLOYMENT_ES_PATH_DATA}"
      echo_info "Drops ES embedded instance datas in ${path} ..."
      rm -rf ${path}
      echo_info "Done."
    else
      echo_info "Drops ES container ${DEPLOYMENT_ES_CONTAINER_NAME} ..."
      delete_docker_container ${DEPLOYMENT_ES_CONTAINER_NAME}
      echo_info "Drops ES docker volume ${DEPLOYMENT_ES_CONTAINER_NAME} ..."
      delete_docker_volume ${DEPLOYMENT_ES_CONTAINER_NAME}
      echo_info "Done."
    fi
    echo_info "ES data dropped"
  else
    echo_info "Es deployment disabled, no data to drop"
  fi
}

do_create_es() {
  if ! ${DEPLOYMENT_ES_EMBEDDED}; then
    echo_info "Creation of the ES Docker volume ${DEPLOYMENT_ES_CONTAINER_NAME} ..."
    create_docker_volume ${DEPLOYMENT_ES_CONTAINER_NAME}
    echo_info "ES Docker volume ${DEPLOYMENT_ES_CONTAINER_NAME} created"
  fi
}

do_stop_es() {
  echo_info "Stopping Elasticsearch ..."

  if ${DEPLOYMENT_ES_EMBEDDED}; then
    echo_info "ES embedded mode, standalone es stop skipped"
    return
  fi

  ensure_docker_container_stopped ${DEPLOYMENT_ES_CONTAINER_NAME}

  echo_info "Elasticsearch container ${DEPLOYMENT_ES_CONTAINER_NAME} stopped."
}

do_start_es() {
  echo_info "Starting Elasticsearch..."
  if ${DEPLOYMENT_ES_EMBEDDED}; then
    echo_info "ES embedded mode, standalone es startup skipped"
    return
  else
    if ${DEPLOYMENT_ES_EMBEDDED_MIGRATION_ENABLED:-false}; then 
      do_migrate_embedded
    fi
  fi

  echo_info "Starting elasticsearch container ${DEPLOYMENT_ES_CONTAINER_NAME} based on image ${DEPLOYMENT_ES_IMAGE}:${DEPLOYMENT_ES_IMAGE_VERSION}"

  # Ensure there is no container with the same name
  delete_docker_container ${DEPLOYMENT_ES_CONTAINER_NAME}
  ${DOCKER_CMD} run \
    -d \
    -p "127.0.0.1:${DEPLOYMENT_ES_HTTP_PORT}:9200" \
    -v ${DEPLOYMENT_ES_CONTAINER_NAME}:/usr/share/elasticsearch/data \
    -e ES_JAVA_OPTS="-Xms${DEPLOYMENT_ES_HEAP} -Xmx${DEPLOYMENT_ES_HEAP}" \
    -e "node.name=${INSTANCE_KEY}" \
    -e "cluster.name=${INSTANCE_KEY}" \
    -e "discovery.type=single-node" \
    -e "xpack.security.enabled=${DEPLOYMENT_ES_SECURED_ENABLED}" \
    -e "xpack.security.http.ssl.enabled=false" \
    -e "ELASTIC_PASSWORD=${DEPLOYMENT_ES_ELASTIC_PASSWORD}" \
    -e "network.host=_site_" \
    --name ${DEPLOYMENT_ES_CONTAINER_NAME} ${DEPLOYMENT_ES_IMAGE}:${DEPLOYMENT_ES_IMAGE_VERSION}
  echo_info "${DEPLOYMENT_ES_CONTAINER_NAME} container started"

  check_es_availability
  if ${DEPLOYMENT_ES_SECURED_ENABLED:-false}; then 
    do_configure_es_user
  fi
}

check_es_availability() {
  echo_info "Waiting for elasticsearch availability on port ${DEPLOYMENT_ES_HTTP_PORT}"
  local count=0
  local try=600
  local wait_time=1
  local RET=-1

  local temp_file="/tmp/${DEPLOYMENT_ES_CONTAINER_NAME}_${DEPLOYMENT_ES_HTTP_PORT}.txt"

  while [ $count -lt $try -a $RET -ne 0 ]; do
    count=$(( $count + 1 ))
    set +e

    if ${DEPLOYMENT_ES_SECURED_ENABLED:-false}; then 
      CURL_COMMAND="curl -s -q --max-time ${wait_time} -u elastic:${DEPLOYMENT_ES_ELASTIC_PASSWORD}"
    else
      CURL_COMMAND="curl -s -q --max-time ${wait_time}"
    fi

    ${CURL_COMMAND} http://localhost:${DEPLOYMENT_ES_HTTP_PORT}
    RET=$?
    if [ $RET -ne 0 ]; then
      [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Elasticsearch not yet available (${count} / ${try})..."
    else
      ${CURL_COMMAND} http://localhost:${DEPLOYMENT_ES_HTTP_PORT}/_cluster/health > ${temp_file} 
      local status=$(jq -r '.status' ${temp_file})
      if [ "${status}" == "green" ]; then
        RET=0
      else
        [ $(( ${count} % 10 )) -eq 0 ] && echo_info "Elasticsearch available but status is ${status} (${count} / ${try})..."
        RET=1
      fi
    fi

    if [ $RET -ne 0 ]; then
      echo -n "."
      sleep $wait_time
    fi
    set -e
  done
  if [ $count -eq $try ]; then
    echo_error "Elasticseatch ${DEPLOYMENT_ES_CONTAINER_NAME} not available after $(( ${count} * ${wait_time}))s"
    exit 1
  fi
  echo_info "Elasticsearch ${DEPLOYMENT_ES_CONTAINER_NAME} up and available"
}

# Create exo ES user and role
do_configure_es_user() {
  echo_info "Creating or updating ES exo User and Role"
  local temp_file="/tmp/${DEPLOYMENT_ES_CONTAINER_NAME}_${DEPLOYMENT_ES_HTTP_PORT}.txt"
  local temp_json="/tmp/${DEPLOYMENT_ES_CONTAINER_NAME}_${DEPLOYMENT_ES_HTTP_PORT}_json.txt"

  # exo role
  cat << EOF > ${temp_json}
  {
    "cluster": [
      "manage_index_templates",
      "monitor",
      "manage_ingest_pipelines"
    ],
    "indices": [
      {
        "names": [
          "wiki*",
          "news*",
          "event*",
          "analytics*",
          "profile*",
          "file*",
          "activity*",
          "space*"
        ],
        "privileges": [
          "all"
        ],
        "allow_restricted_indices": false
      }
    ],
    "applications": [],
    "run_as": [],
    "metadata": {},
    "transient_metadata": {
      "enabled": true
    }
  }
EOF
  cat ${temp_json}

  curl -s -q  -XPOST http://localhost:${DEPLOYMENT_ES_HTTP_PORT}/_security/role/exo -u elastic:${DEPLOYMENT_ES_ELASTIC_PASSWORD} -H 'Content-Type: application/json' -d @${temp_json} > ${temp_file}
  RET=$?
  rm ${temp_json}
  if [ $RET -ne 0 ]; then
    echo_error "Error in the curl command. Return code: $RET"
    exit 1
  fi
  local result_error=$(jq -r '.error.root_cause' ${temp_file})
  local result_created=$(jq -r '.role.created' ${temp_file})
  if [ $result_created == "null" ]; then
    echo_error "exo role was not created nor updated sucessfully"
    echo_error "Message: $result_error"
    exit 1
  else
    if [[ $result_created == "true" ]];then
      echo_info "exo role created successfully"
    else
      echo_info "exo role updated successfully"
    fi
  fi

  # exo user
  cat << EOF > ${temp_json}
  {
    "username": "exo",
    "password" : "${DEPLOYMENT_ES_EXO_PASSWORD}",
    "roles": [
      "exo"
    ],
    "full_name": "",
    "email": "",
    "metadata": {},
    "enabled": true
  }
EOF

  curl -s -q  -XPOST http://localhost:${DEPLOYMENT_ES_HTTP_PORT}/_security/user/exo -u elastic:${DEPLOYMENT_ES_ELASTIC_PASSWORD} -H 'Content-Type: application/json' -d @${temp_json} > ${temp_file}
  RET=$?
  rm ${temp_json}
  if [ $RET -ne 0 ]; then
    echo_error "Error in the curl command. Return code: $RET"
    exit 1
  fi
  local result_error=$(jq -r '.error.root_cause' ${temp_file})
  local result_created=$(jq -r '.created' ${temp_file})
  if [ $result_created == "null" ]; then
    echo_error "exo user was not created nor updated sucessfully"
    echo_error "Message: $result_error"
    exit 1
  else
    if [[ $result_created == "true" ]];then
      echo_info "exo user created successfully"
    else
      echo_info "exo user updated successfully"
    fi
  fi
}

# Migrate ES Embedded to Standalone 
do_migrate_embedded() {
  echo_info "Elasticsearch migration from embedded to standalone is enabled! Starting..."
  local path="${DEPLOYMENT_DIR}/${DEPLOYMENT_ES_PATH_DATA}"
  # Check if the folder is empty or not. if it is empty, skip the migration
  if [ $(ls -al ${path} 2>/dev/null | wc -l) -le 3 ]; then 
    echo_warn "No ES embedded data found! Skipping the migration..."
    return 
  fi
  do_drop_es_data
  do_create_es
  local mount_point=$(${DOCKER_CMD} volume inspect --format '{{ .Mountpoint }}' ${DEPLOYMENT_ES_CONTAINER_NAME}) || return 0
  sudo mv -v ${path}/* ${mount_point}/ > /dev/null
  sudo chown 1000.1000 -R ${mount_point}
  echo "ES Embedded data have successfuly moved."
}
# #############################################################################
# Env var to not load it several times
_FUNCTIONS_DATABASE_LOADED=true
echo_debug "_functions_database.sh Loaded"
