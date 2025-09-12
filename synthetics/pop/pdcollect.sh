#!/bin/bash -i

CWD=$(dirname $0)
[ "${CWD}" = "." ] && CWD=$(pwd -P)

usage()
{
    echo "usage: pdcollect.sh -n <namespace> -d <log_output_directory>. By default, namespace is 'default', log output directory is /tmp."
}

type kubectl >/dev/null 2>&1
if [ $? -ne 0 ] ; then 
   type microk8s 2>/dev/null
   if [ $? -eq 0 ] ; then
      alias kubectl='microk8s kubectl'
   fi   
fi

namespace="default"
log_dir="/tmp"

while getopts 'n:d:h' opt; do
  case "$opt" in
    n)
      namespace=${OPTARG}
      ;;
    d)
      if [ ! -d "${OPTARG}" ]; then
         echo "Directory ${OPTARG} does not exist, exit."
         exit 1
      fi
      log_dir=$(cd ${OPTARG}; pwd)
      if [ ! -d "$log_dir" ]; then
         echo "Directory $log_dir does not exist, exit."
         exit 1
      fi
      ;;
    ?|h)
      echo "usage: pdcollect.sh -n <namespace> -d <log_output_directory>. By default, namespace is 'default', log output directory is /tmp."
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

installed_pop=$(helm list -n $namespace | grep synthetic-pop | wc -l)
if [ $installed_pop -le 0 ]; 
then
   echo "No Synthetic PoP installed in $namespace namespace."
   exit 1;
fi

echo "collecting synthetic pod information and logging files from namespace $namespace" 
TIMESTAMP="$(date +%Y%m%d%H%M)"
LOG_FOLDER="syntheticpop_logs_${TIMESTAMP}"  
mkdir ${log_dir}/${LOG_FOLDER}

cd ${log_dir}/${LOG_FOLDER}

helm list -n $namespace >> helm_list.log 2>&1
kubectl get pod -n $namespace -o wide >> pod_list.log 2>&1

for line in $(kubectl get po -n $namespace | grep 'synthetic-pop' | awk {'print$1'}); do
    kubectl describe po $line -n $namespace >> ${line}_describe.log 2>&1
    case $line in
        *"controller"*)
           kubectl exec $line -n $namespace -- printenv | grep -i POP_CONTROLLER_VERSION  >> version.log 2>&1
           kubectl cp ${line}:logs ./${line}_log -n $namespace >> mountdir.log 2>&1
           ;;
        *"http"*)
           kubectl exec $line -n $namespace -- printenv | grep -i HTTP_ENGINE_VERSION  >> version.log 2>&1
           kubectl cp ${line}:logs ./${line}_log -n $namespace >> mountdir.log 2>&1
           ;;
        *"javascript"*)
           kubectl exec $line -n $namespace -- printenv | grep -i JAVASCRIPT_ENGINE_VERSION  >> version.log 2>&1
           kubectl cp ${line}:logs ./${line}_log -n $namespace >> mountdir.log 2>&1
           ;;
        *"browserscript"*)
           kubectl exec $line -n $namespace -- printenv | grep -i BROWSERSCRIPT_ENGINE_VERSION  >> version.log 2>&1
           kubectl cp ${line}:logs ./${line}_log -n $namespace >> mountdir.log 2>&1
           ;;
         *"ism"*)
           kubectl exec $line -n $namespace -- printenv | grep -i ISM_ENGINE_VERSION  >> version.log 2>&1
           kubectl cp ${line}:logs ./${line}_log -n $namespace >> mountdir.log 2>&1
           ;;
        *"redis"*)
           kubectl exec $line -n $namespace -- printenv | grep -i REDIS_VERSION >> version.log 2>&1
           mkdir ./${line}_log
           kubectl logs $line -n $namespace >> ./${line}_log/redis.log 2>&1
           ;;
        *)
          ;;
    esac
done

if [ -d "${log_dir}/${LOG_FOLDER}" ] && [ -n "$(ls -A "${log_dir}/${LOG_FOLDER}")" ]; then
    tar -rf ${log_dir}/${LOG_FOLDER}.tar -C ${log_dir}/${LOG_FOLDER} .
    gzip ${log_dir}/${LOG_FOLDER}.tar
    rm -rf ${log_dir}/${LOG_FOLDER}
 
   echo "logging files are packaged successfully, see ${log_dir}/${LOG_FOLDER}.tar.gz"
else
   echo "No logging files. Please check your resources in $namespace namespace"
   exit -1
fi

cd ${CWD}