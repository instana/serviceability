#!/bin/sh
###############################################################################
#
# This script is used to collect data for
# the Instana Host Agent on Kubernetes / Openshift
#
# ./instana-k8s-mustgather.sh
#
###############################################################################
VERSION=1.0.1
CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")

export MGDIR=instana-mustgather-$CURRENT_TIME
mkdir -p $MGDIR
echo "$VERSION" > $MGDIR/version.txt

if command -v oc > /dev/null
then
  CMD=oc
  LIST_NS="instana-agent openshift-controller-manager"
else
  CMD=kubectl
  LIST_NS="instana-agent"
fi

$CMD get nodes > $MGDIR/node-list.txt
$CMD describe nodes > $MGDIR/node-describe.txt
$CMD get namespaces > $MGDIR/namespaces.txt
$CMD describe cm instana-agent -n instana-agent > $MGDIR/configMap.txt

if [ $CMD == "oc" ]
then
  $CMD get clusteroperators > $MGDIR/cluster-operators.txt
fi
$CMD get pods -n instana-agent -o wide > $MGDIR/instana-agent-pod-list.txt
# copy logs from pod directly
awk 'NR>1 && $1 !~ /k8sensor/ { system("'"$CMD"' -n '"instana-agent"' cp "$1":/opt/instana/agent/data/log/ '"$MGDIR"'/'"instana-agent"'/"$1"_logs") }' $MGDIR/instana-agent-pod-list.txt

if [ $CMD == "oc" ]
then
  $CMD get pods -n openshift-controller-manager -o wide > $MGDIR/openshift-controller-manager-pod-list.txt
fi
for NS in $LIST_NS; do
  export NS=$NS
  mkdir $MGDIR/$NS
  $CMD get all,events -n $NS -o wide &> $MGDIR/$NS/all-list.txt
  $CMD get pods -n $NS | awk 'NR>1{print "'$CMD' -n $NS describe pod "$1" > $MGDIR/$NS/"$1"-describe.txt && echo described "$1}' | bash
  $CMD get pods -n $NS -o go-template='{{range $i := .items}}{{range $c := $i.spec.containers}}{{println $i.metadata.name $c.name}}{{end}}{{end}}' > $MGDIR/$NS/container-list.txt
  awk '{print "'$CMD' -n $NS logs "$1" -c "$2" --tail=10000 > $MGDIR/$NS/"$1"_"$2".log && echo gathered logs of "$1"_"$2}' $MGDIR/$NS/container-list.txt | bash
  awk '{print "'$CMD' -n $NS logs "$1" -c "$2" --tail=10000 -p > $MGDIR/$NS/"$1"_"$2"_previous.log && echo gathered previous logs of "$1"_"$2}' $MGDIR/$NS/container-list.txt | bash
done
tar czf $MGDIR.tgz $MGDIR/