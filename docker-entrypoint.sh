#!/bin/bash

# Copyright 2017 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { echo "$ $@" 1>&2; "$@" || die "cannot $*"; }

setup_autoregister_properties_file() {
  if [ -n "$AGENT_AUTO_REGISTER_KEY" ]; then
    echo "agent.auto.register.key=$AGENT_AUTO_REGISTER_KEY" >> $1
  fi

  if [ -n "$AGENT_AUTO_REGISTER_RESOURCES" ]; then
    echo "agent.auto.register.resources=$AGENT_AUTO_REGISTER_RESOURCES" >> $1
  fi

  if [ -n "$AGENT_AUTO_REGISTER_ENVIRONMENTS" ]; then
    echo "agent.auto.register.environments=$AGENT_AUTO_REGISTER_ENVIRONMENTS" >> $1
  fi

  if [ -n "$AGENT_AUTO_REGISTER_HOSTNAME" ]; then
    echo "agent.auto.register.hostname=$AGENT_AUTO_REGISTER_HOSTNAME" >> $1
  fi

  # unset variables, so we don't pollute and leak sensitive stuff to the agent process...
  unset AGENT_AUTO_REGISTER_KEY AGENT_AUTO_REGISTER_RESOURCES AGENT_AUTO_REGISTER_ENVIRONMENTS AGENT_AUTO_REGISTER_HOSTNAME
}

VOLUME_DIR="/godata"

# these 3 vars are used by `/go-agent/agent.sh`, so we export
export AGENT_WORK_DIR="/go"
export STDOUT_LOG_FILE="/go/go-agent-bootstrapper.out.log"

# no arguments are passed so assume user wants to run the gocd server
# we prepend "/go-agent/agent.sh" to the argument list
if [[ $# -eq 0 ]] ; then
	set -- /go-agent/agent.sh "$@"
fi

# if running go server as root, then initialize directory structure and call ourselves as `go` user
if [ "$1" = '/go-agent/agent.sh' ]; then

  if [ "$(id -u)" = '0' ]; then
    server_dirs=(config logs pipelines)

    yell "Creating directories and symlinks to hold GoCD configuration, data, and logs"

    # ensure working dir exist
    if [ ! -e "${AGENT_WORK_DIR}" ]; then
      try mkdir "${AGENT_WORK_DIR}"
      try chown go:go "${AGENT_WORK_DIR}"
    fi

    # ensure proper directory structure in the volume directory
    if [ ! -e "${VOLUME_DIR}" ]; then
      try mkdir "${VOLUME_DIR}"
      try chown go:go "${AGENT_WORK_DIR}"
    fi

    for each_dir in "${server_dirs[@]}"; do
      if [ ! -e "${VOLUME_DIR}/${each_dir}" ]; then
        try mkdir -v "${VOLUME_DIR}/${each_dir}"
        try chown go:go "${VOLUME_DIR}/${each_dir}"
      fi

      if [ ! -e "${AGENT_WORK_DIR}/${each_dir}" ]; then
        try ln -sv "${VOLUME_DIR}/${each_dir}" "${AGENT_WORK_DIR}/${each_dir}"
        try chown go:go "${AGENT_WORK_DIR}/${each_dir}"
      fi
    done

    setup_autoregister_properties_file "${AGENT_WORK_DIR}/config/autoregister.properties"
	  try exec /usr/local/sbin/tini -- /usr/local/sbin/gosu go "$0" "$@" >> ${STDOUT_LOG_FILE} 2>&1
  fi
fi

try exec "$@"
