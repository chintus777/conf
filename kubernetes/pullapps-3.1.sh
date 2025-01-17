#!/bin/bash
#
#
# pull images script kubernetes for abcdesktopio
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This file will be fetched as: curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/pullimages.sh | sh -
# so it should be pure bourne shell
#
# run curl -L https://raw.githubusercontent.com/abcdesktopio/conf/main/kubernetes/pullimages.sh | sh -
#

# define default NAMESPACE
NAMESPACE=abcdesktop

# define force
FORCE=0

# define ABCDESKTOP_YAML path
# ABCDESKTOP_YAML=abcdesktop.yaml 

# current release
ABCDESKTOP_RELEASE=3.0

# docker hub prefix
# REGISTRY_DOCKERHUB="docker.io/abcdesktopio"

# list of default applications to prefetch
# and
# list of template application to download quickly
# ABCDESKTOP_APPLICATIONS="
# $REGISTRY_DOCKERHUB/oc.template:$ABCDESKTOP_RELEASE
# $REGISTRY_DOCKERHUB/oc.template.gtk:$ABCDESKTOP_RELEASE
# $REGISTRY_DOCKERHUB/2048.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/xterm.d:$ABCDESKTOP_RELEASE
# $REGISTRY_DOCKERHUB/writer.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/calc.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/impress.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/firefox.d:$ABCDESKTOP_RELEASE 
# $REGISTRY_DOCKERHUB/gimp.d:$ABCDESKTOP_RELEASE"


# gimp.d.$ABCDESKTOP_RELEASE.json

URL_APPLICATION_CONF_SOURCE="https://raw.githubusercontent.com/abcdesktopio/oc.apps/main"
# list of json default applications to prefetch
ABCDESKTOP_JSON_APPLICATIONS="
2048-alpine.d.$ABCDESKTOP_RELEASE.json
xterm.d.$ABCDESKTOP_RELEASE.json
writer.d.$ABCDESKTOP_RELEASE.json
firefox.d.$ABCDESKTOP_RELEASE.json
nautilus.d.$ABCDESKTOP_RELEASE.json
geany.d.$ABCDESKTOP_RELEASE.json
qterminalpod.d.$ABCDESKTOP_RELEASE.json
evince.d.$ABCDESKTOP_RELEASE.json
"


if [ -z "${LOG_FILE}" ];
then
    LOG_FILE="/var/log/kube.log"
fi

# $1 message
display_section() {
    printf "\033[0;1;4m%s\033[0;0m\n" "$1"
}

# $1 message
# $2 status
display_message() {
    # ${2^^}: bad substitution, use "${2}" 
    # use printf instead of echo for better compatibility sh zsh bash
    case "${2}" in
        "OK") COLOR="\033[0;32m";;
        "KO") COLOR="\033[0;31m";;
        "ERROR") COLOR="\033[0;31m";;
        "WARN") COLOR="\033[0;33m";;
        "INFO") COLOR="\033[1;34m";;
    esac
    printf "[$COLOR%s\033[0;0m] %s\n" "$2" "$1"
}

# $1 message
display_message_result() {
    exit_code="$?"
    if [ "$exit_code" -eq 0 ];
    then
        display_message "$1" "OK"
    else
        display_message "$1 error $exit_code" "KO"
	# by default force=0, exit
	if [ "$FORCE" -eq 0 ];
	then
        	exit 1
	fi
    fi
}

# $1 command
check_command() {
  if ! command -v "$1" &> /dev/null
  then
    display_message "$1 could not be found" "KO"
    exit 1
  fi
}



function help() {
        cat <<-EOF
abcdesktop pull application tool

Usage: abcdesktop-pullapplications [OPTION] [--namespace abcdesktop]...

Options (exclusives):
 --help                     Display this help and exit
 --version                  Display version information and exit
 --clean 		    Remove *.pem od.config abcdesktop.yaml poduser.yaml files only

Parameters:
 --namespace                Define the abcdesktop namespace default value is abcdesktop
 --force                    Continue if an error occurs
 
Examples:
    abcdesktop-pullapplications
    Install an abcdesktop service on a kubernetes cluster.

    abcdesktop-pullapplications --namespace=superdesktop
    Install an abcdesktop service in the superdesktop namespace on a kubernetes cluster

    abcdesktop-pullapplications --force=1
    Continue if a system or a kubernetes error occurs

  
Exit status:
 0      if OK,
 1      if any problem

Report bugs to https://github.com/abcdesktopio/conf/issues
EOF
}


function clean() {
  for app in $ABCDESKTOP_JSON_APPLICATIONS
  do
    rm "$app"
    display_message_result "remove files $app"
  done
}



function version() {
    cat <<-EOF
abcdesktop pull images script - $VERSION
This is free software; see the source for copying conditions.
Written by Alexandre DEVELY
Written by J.F. Vincent
EOF
}

opts=$(getopt \
    --longoptions "help,version,clean,force:,namespace:," \
    --name "$(basename "$0")" \
    --options "" \
    -- "$@"
)
eval set "--$opts"

while [ $# -gt 0 ]
do
    case "$1" in
      # commands
      --help) help; exit;;
      --version) version; exit;;
      --clean) clean; exit;;
      --namespace) NAMESPACE="$2";shift;;
      --force) FORCE="$2";shift;;
    esac
    shift
done

echo "abcdesktop pull images script namespace=${NAMESPACE}"

#
# give me a free tcp port starting from 30443
BASE_PORT=30443
INCREMENT=1
port=$BASE_PORT
if ! [ -x "$(command -v netstat)" ]; then
  echo "netstat is not installed. I'm using port=$port" >&2
else
  isfree=$(netstat -taln |grep $port)
  while [[ -n "$isfree" ]]; do
    port=$((port+INCREMENT))
    isfree=$(netstat -taln |grep "$port")
  done
fi
display_message "Forwarding abcdesktop service for you on port=$port" "OK"


# Check if kubectl command is supported
# run command kubectl version
check_command kubectl
kubectl version > /dev/null
display_message_result "kubectl version"

NGINX_POD_NAME=$(kubectl get pods -l run=nginx-od -o jsonpath={.items..metadata.name} -n "$NAMESPACE")
display_message_result "kubectl pods -l run=nginx-od -o jsonpath={.items..metadata.name} -n $NAMESPACE"

display_message "nginx pod name=$NGINX_POD_NAME" "OK"
echo "starting port-forward on tcp port $port"
echo "kubectl port-forward $NGINX_POD_NAME --address 0.0.0.0 $port:80 -n $NAMESPACE" 
rm -f port_forward
kubectl port-forward "$NGINX_POD_NAME" --address 0.0.0.0 "$port:80" -n "$NAMESPACE" > port_forward & 
PORT_FORWARD_PID=$! 
echo "waiting for pid $PORT_FORWARD_PID" 
while [ ! -f port_forward ]
do 
  echo "." 
  sleep 1
done
display_message_result "kubectl port-forward $NGINX_POD_NAME get pid $PORT_FORWARD_PID"

# define service URL
URL="http://localhost:$port/API/manager/image"

# call HEALTZ
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  echo "## this process wil take several minutes to complete ##"
  for app in $ABCDESKTOP_JSON_APPLICATIONS
  do
      curl -sL --output "$app" "$URL_APPLICATION_CONF_SOURCE/$app"
      display_message_result "curl $URL_APPLICATION_CONF_SOURCE/$app"
      curl -X PUT -H 'Content-Type: text/javascript' "$URL" -d "@$app" > /dev/null
      display_message_result "curl -X PUT -H 'Content-Type: text/javascript' $URL -d @$app"
      pods=$(kubectl -n "$NAMESPACE" get pods --selector=type=pod_application_pull --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
      echo ""
      echo "list of created pods for pulling is: "
      echo "$pods"
      echo "waiting for all pods condition Ready. timeout=-1s (it will take a while)"
      kubectl wait --for=condition=Ready pods --selector=type=pod_application_pull --timeout=-1s -n "$NAMESPACE"
      kubectl delete pod --selector=type=pod_application_pull -n "$NAMESPACE" > /dev/null
  done
  kill $PORT_FORWARD_PID
  echo "$ABCDESKTOP_JSON_APPLICATIONS"
  echo "applications are ready to use"
else
  echo "abcdesktop is not ready"	
  PYOS_POD_NAME=$(kubectl get pods -l run=pyos-od -o jsonpath={.items..metadata.name} -n "$NAMESPACE")
  echo "Somethings goes wrong with this pod $PYOS_POD_NAME or with $NGINX_POD_NAME"
  kubectl logs "$PYOS_POD_NAME" -n "$NAMESPACE"
fi
