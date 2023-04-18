#!/usr/bin/env bash

KUBECONFIG="${1}"

while [ -f $KUBECONFIG ]
do
    echo "Approving all CSR requests"
    oc --kubeconfig="$KUBECONFIG" get csr --no-headers | grep Pending | \
        awk '{print $1}' | \
        xargs --no-run-if-empty oc --kubeconfig="$KUBECONFIG" adm certificate approve

    echo "Push custom kubernetes config"
    oc --kubeconfig="$KUBECONFIG" create -f /usr/local/src/custom.yaml 2>/dev/null
    oc --kubeconfig="$KUBECONFIG" apply -f /usr/local/src/custom.yaml

    sleep 60
done

