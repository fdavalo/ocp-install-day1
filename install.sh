#!/bin/bash
set -x

export CLUSTER=$1

. ./install.env.sh
. ./install.env.$CLUSTER.sh

mkdir -p $CLUSTER

sed -e "s/@CLUSTER@/${CLUSTER}/g" -e "s/@API_VIP@/${API_VIP}/g" -e "s/@INGRESS_VIP@/${INGRESS_VIP}/g" install-config.yaml.vsphere > $CLUSTER/install-config.yaml

./$INSTALLER create manifests --dir $CLUSTER/

rm -f $CLUSTER/openshift/99_openshift-cluster-api_master-machines-*.yaml $CLUSTER/openshift/99_openshift-cluster-api_worker-machineset-*.yaml 

sed -i 's/mastersSchedulable:true/mastersSchedulable:false/g' $CLUSTER/manifests/cluster-scheduler-02-config.yml

python3.6 custom.py $CLUSTER

./$INSTALLER create ignition-configs --dir $CLUSTER/

base64 -w0 $CLUSTER/master.ign > $CLUSTER/master.64
base64 -w0 $CLUSTER/worker.ign > $CLUSTER/worker.64
base64 -w0 $CLUSTER/bootstrap.ign > $CLUSTER/bootstrap.64

basedomain="redhat.hpecic.net"
clustername="$CLUSTER"

nodes=(
    "bootstrap-${clustername}"
    "master-0-${clustername}"
    "master-1-${clustername}"
    "master-2-${clustername}"
    "worker-0-${clustername}"
    "worker-1-${clustername}"
    "worker-2-${clustername}"
)

ips=(
    "ip=$IP_BOOTSTRAP::${IP_GATEWAY}:255.255.255.0:bootstrap-${clustername}:ens192:none nameserver=${IP_DNS}"
    "ip=$IP_MASTER_0::${IP_GATEWAY}:255.255.255.0:master-0-${clustername}:ens192:none nameserver=${IP_DNS}"
    "ip=$IP_MASTER_1::${IP_GATEWAY}:255.255.255.0:master-1-${clustername}:ens192:none nameserver=${IP_DNS}"
    "ip=$IP_MASTER_2::${IP_GATEWAY}:255.255.255.0:master-2-${clustername}:ens192:none nameserver=${IP_DNS}"
    "ip=$IP_WORKER_0::${IP_GATEWAY}:255.255.255.0:worker-0-${clustername}:ens192:none nameserver=${IP_DNS}"
    "ip=$IP_WORKER_1::${IP_GATEWAY}:255.255.255.0:worker-1-${clustername}:ens192:none nameserver=${IP_DNS}"
    "ip=$IP_WORKER_2::${IP_GATEWAY}:255.255.255.0:worker-2-${clustername}:ens192:none nameserver=${IP_DNS}"
)

ignitions=(
    "$CLUSTER/bootstrap.64"
    "$CLUSTER/master.64"
    "$CLUSTER/master.64"
    "$CLUSTER/master.64"
    "$CLUSTER/worker.64"
    "$CLUSTER/worker.64"
    "$CLUSTER/worker.64"
);

#gzip+base64
encodings=(
    "base64"
    "base64"
    "base64"
    "base64"
    "base64"
    "base64"
    "base64"
);

macs=(
    "$MAC_BOOTSTRAP"
    "$MAC_MASTER_0"
    "$MAC_MASTER_1"
    "$MAC_MASTER_2"
    "$MAC_WORKER_0"
    "$MAC_WORKER_1"
    "$MAC_WORKER_2"
);

for (( i=0; i < ${#nodes[@]} ; i++ ))
do
    node=${nodes[$i]}
    ip=${ips[$i]}
    mac=${macs[$i]}
    ignition=${ignitions[$i]}
    encoding=${encodings[$i]}

    echo "Setup $node -> $ip"
 
    govc vm.clone -vm "coreos-template" \
      -annotation="Cluster $CLUSTER" \
      -c=4 \
      -m=16384 \
      -cluster="${GOVC_CLUSTER}" \
      -net="${GOVC_NETWORK}" \
      -pool="/${GOVC_CLUSTER}/host/${GOVC_DATACENTER}/Resources/" \
      -on=false \
      -folder="/${GOVC_CLUSTER}/vm/OCP-NODES" \
      -dc="${GOVC_DATACENTER}" \
      -ds="${GOVC_DATASTORE}" \
      -net.address=${mac} \
      $node

    govc vm.disk.change -vm "$node" -disk.label "Hard disk 1" -size 120G
 
    govc vm.change -vm="$node" \
      -e="disk.enableUUID=TRUE" \
      -e="stealclock.enable=TRUE" \
      -e="guestinfo.afterburn.initrd.network-kargs=$ip" \
      -e="guestinfo.ignition.config.data.encoding=${encoding}" \
      -f="guestinfo.ignition.config.data=${ignition}"
done
 
for node in ${nodes[@]}
do
    echo "Start $node"
    govc vm.power -on=true $node
done

./$INSTALLER --dir $CLUSTER/ wait-for bootstrap-complete --log-level debug


