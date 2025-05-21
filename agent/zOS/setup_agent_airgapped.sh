#!/bin/bash

### Copyright IBM Corp. 2024, 2025
### Copyright 2019, 2025, Instana Inc.
###
### Licensed under the Apache License, Version 2.0 (the "License");
### you may not use this file except in compliance with the License.
### You may obtain a copy of the License at
###
###     http://www.apache.org/licenses/LICENSE-2.0
###
### Unless required by applicable law or agreed to in writing, software
### distributed under the License is distributed on an "AS IS" BASIS,
### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
### See the License for the specific language governing permissions and
### limitations under the License.
###


AGENT_DIR_ZOS="${PWD}/instana-agent"
AGENT_DIR_ZOS_OLD="${PWD}/instana-agent-old"
AGENT_TYPE="dynamic"
PROMPT=true


function exists {
  if which "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

function log_error {
  local message=$1

  if [[ $TERM == *"color"* ]]; then
    echo -e "\e[31m$message\e[0m"
  else
    echo $message
  fi
}

function log_info {
  local message=$1

  if [[ $TERM == *"color"* ]]; then
    echo -e "\e[32m$message\e[0m"
  else
    echo $message
  fi
}

function log_warn {
  local message=$1

  if [[ $TERM == *"color"* ]]; then
    echo -e "\e[33m${message}\e[0m"
  else
    echo "${message}"
  fi
}

function receive_confirmation() {
  read -r -p "$1 [y/N] " response

  if [[ ! $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    return 1
  fi

  return 0
}

function check_zOS_prerequisites() {
 if command -v gzip > /dev/null && command -v pax > /dev/null; then
   log_info 'pax and gzip are available on the system'
 else
   log_error 'This script requires pax and gzip to be installed on this system. Aborting installation.'
   exit 1
 fi

}

function check_user_privilege() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "You are root!"
  else
    echo "You are not root Aborting Agent Installation. Switch to the user which has root privilege and retry"
    exit 1
  fi
}

function setup_agent_airgapped() {

    echo "Please enter the path to the Instana-agent .tar.gz file: e.g. /u/nghon/agent-assembly-linux-offline-s390x.tar.gz"
    read file_path

    if [[ -f "$file_path" && "$file_path" == *.tar.gz ]]; then
        echo "File exists and is a .tar.gz file."
        log_info "Cheking on Prereq. for Installing Instana agent"
        check_user_privilege
        check_zOS_prerequisites
        check_zOS_server_update_prerequisites
        check_existing_instana_agent
        log_info "Installing Instana agent"
        EXPECTED_FILE="org.apache.felix.framework-*.jar"
        DIR="$AGENT_DIR_ZOS/system/org/apache/felix/org.apache.felix.framework/"
        gzip -d ${file_path}
        pax -r -f ${file_path%.gz}
        if ls "$DIR"/*/org.apache.felix.framework-*.jar 2>/dev/null | grep -q .; then
            echo "The required file is available for further installation process of instana-agent i.e. $EXPECTED_FILE"
        else
            echo "The required file NOT found: i.e. $EXPECTED_FILE, Issue during download/Untar of build aborting further installation"
            exit 1
        fi

        export _BPXK_AUTOCVT=ON
        echo 'INFO: Auto Character Conversion (export _BPXK_AUTOCVT=ON) is enabled for this session. For convenience it is recommended to set this in your User Profile, so you don’t need to export it each time you log in'
        echo 'Enabling codepage Setting'
        chtag -R -tc 819 ${AGENT_DIR_ZOS}/bin
        chtag -R -tc 819 ${AGENT_DIR_ZOS}/etc
        echo 'Codepage Setting for required folder of Instana-Agent has been enabled'
        set_java_home_and_start_agent
    else
       echo "The file either doesn't exist or is not a .tar.gz file. Please check the file path and try again."
    fi

}

function check_existing_instana_agent() {
  # Check if the instana-agent path exists in the current directory
  process_command="/bin/sh ${AGENT_DIR_ZOS}/bin/karaf server"

  if [ -d "${AGENT_DIR_ZOS}" ]; then
      echo "Instana agent path is available in the current directory."
      mkdir ${AGENT_DIR_ZOS_OLD}
      cp "${AGENT_DIR_ZOS}/etc/mvn-settings.xml" "${AGENT_DIR_ZOS_OLD}"
      cp "${AGENT_DIR_ZOS}/etc/org.ops4j.pax.url.mvn.cfg" "${AGENT_DIR_ZOS_OLD}"
      cp "${AGENT_DIR_ZOS}/etc/instana/com.instana.agent.bootstrap.AgentBootstrap.cfg" "${AGENT_DIR_ZOS_OLD}"
      cp "${AGENT_DIR_ZOS}/etc/instana/com.instana.agent.main.config.UpdateManager.cfg" "${AGENT_DIR_ZOS_OLD}"
      cp "${AGENT_DIR_ZOS}/etc/instana/configuration.yaml" "${AGENT_DIR_ZOS_OLD}"
      cp "${AGENT_DIR_ZOS}/etc/instana/com.instana.agent.main.config.Agent.cfg" "${AGENT_DIR_ZOS_OLD}"
      cp "${AGENT_DIR_ZOS}/etc/instana/com.instana.agent.main.sender.Backend.cfg" "${AGENT_DIR_ZOS_OLD}"
  else
      echo "Instana agent path is NOT available in the current directory."
  fi

  # Check if the process is running
  echo $process_command
  pid=$(ps -ef | grep "$process_command" | grep -v grep | awk '{print $2}')
  if [ -n	"$pid" ]; then
      echo "Process is running with PID: $pid"
      echo "Stopping running agent process and cleaning the directory"
      if [ $PROMPT = true ]; then
        if ! receive_confirmation 'Do you want to continue to stop the running process?'; then
          exit 1
        fi
        echo "Stopping current running agent"
        kill -9 ${pid}
        rm -rf ${AGENT_DIR_ZOS}
      fi
  else
      echo "Process is not running."
  fi

}

function check_zOS_server_update_prerequisites() {
  if command -v sed > /dev/null; then
    log_info 'sed are available on the system'
  else
    log_error 'This script requires sed to be installed on this system. Aborting installation.'
    exit 1
  fi

}

function set_java_home_and_start_agent(){
  echo " To Start the Agent we need JAVA_HOME path, checking with installed java on the system"

  java_version=$(java -version 2>&1 | head -n 1 |	sed -E 's/.*"([^"]+)".*/\1/')
  # Check if the Java command succeeded
  if [ $?	-ne 0 ]; then
      echo "Java is not installed	or not in the PATH."
      echo "Please provide the path to the JAVA_HOME directory, ensuring it is located before the	'bin' directory; for example: /usr/lpp/java/11.0"
      read -p "Enter JAVA_HOME: "	JAVA_HOME
      echo "Entered JAVA_HOME is:	$JAVA_HOME"
  else
      echo "Java version detected: $java_version"
  fi

  # Extract the major version number
  if echo "$java_version" | grep -q "^1\."; then
      # For version like 1.8.x (Java 8), extract the second part of the version
      major_version=$(echo $java_version | cut -d. -f2)
  else
      # For versions like 9.x.x, 11.x.x, etc., the major version starts from the first number
      major_version=$(echo $java_version | cut -d. -f1)
  fi

  # Check if the version is exactly Java 11
  if [ "$major_version" -eq 11 ]; then
      echo "Java version $java_version is installed and is a supported version."
  else
      echo "Java version $java_version is installed, but it is not a supported version. Supported version is JAVA 11."
      log_warn 'Please provide the path to the JAVA_HOME directory with a supported version, ensuring it is located before the "bin" directory; for example : /usr/lpp/java/11.0'
      read JAVA_HOME
      echo "Enterd JAVA_HOME is :  $JAVA_HOME"

  fi

  echo 'Setting JAVA_HOME for Instana-Agent'
  FILE="${AGENT_DIR_ZOS}/bin/setenv"

  sed '/# unset JAVA_HOME/ {
    s/# unset JAVA_HOME/unset JAVA_HOME/;
  }' "$FILE" > "$FILE.tmp"
  echo "export JAVA_HOME=$JAVA_HOME" >> "$FILE.tmp"
  mv "$FILE.tmp" "$FILE"
  echo 'Updated JAVA_HOME for Instana-Agent'

  echo 'Ready to start the agent, will start the agent'
  if test -d "${AGENT_DIR_ZOS_OLD}"; then
      test -f "${AGENT_DIR_ZOS_OLD}/mvn-settings.xml" && cp "${AGENT_DIR_ZOS_OLD}/mvn-settings.xml" "${AGENT_DIR_ZOS}/etc/"
      test -f "${AGENT_DIR_ZOS_OLD}/org.ops4j.pax.url.mvn.cfg" && cp "${AGENT_DIR_ZOS_OLD}/org.ops4j.pax.url.mvn.cfg" "${AGENT_DIR_ZOS}/etc/"
      test -f "${AGENT_DIR_ZOS_OLD}/com.instana.agent.bootstrap.AgentBootstrap.cfg" && cp "${AGENT_DIR_ZOS_OLD}/com.instana.agent.bootstrap.AgentBootstrap.cfg" "${AGENT_DIR_ZOS}/etc/instana/"
      test -f "${AGENT_DIR_ZOS_OLD}/com.instana.agent.main.config.UpdateManager.cfg" && cp "${AGENT_DIR_ZOS_OLD}/com.instana.agent.main.config.UpdateManager.cfg" "${AGENT_DIR_ZOS}/etc/instana/"
      test -f "${AGENT_DIR_ZOS_OLD}/configuration.yaml" && cp "${AGENT_DIR_ZOS_OLD}/configuration.yaml" "${AGENT_DIR_ZOS}/etc/instana/"
      test -f "${AGENT_DIR_ZOS_OLD}/com.instana.agent.main.config.Agent.cfg" && cp "${AGENT_DIR_ZOS_OLD}/com.instana.agent.main.config.Agent.cfg" "${AGENT_DIR_ZOS}/etc/instana"
      test -f "${AGENT_DIR_ZOS_OLD}/com.instana.agent.main.sender.Backend.cfg" && cp "${AGENT_DIR_ZOS_OLD}/com.instana.agent.main.sender.Backend.cfg" "${AGENT_DIR_ZOS}/etc/instana"
      chtag -R -tc 819 ${AGENT_DIR_ZOS}/etc
      rm -rf ${AGENT_DIR_ZOS_OLD}/
  else
      echo "No configuration files are copied from the previously installed agent"
  fi


  ./instana-agent/bin/start
  echo 'Now, you can check logs at instana-agent/data/log/agent.log '

}


if ! setup_agent_airgapped; then
  exit 1
fi

