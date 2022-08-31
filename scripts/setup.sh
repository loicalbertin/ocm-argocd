#!/usr/bin/env bash

set -euo pipefail

# Prerequirements:
# - kubectl
# - clusteradm
# - argocd

# TODOs:
# - check http(s)_proxy
# - install some prerequirements automatically

function join_by {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

CONTEXT_PREFIX="${CONTEXT_PREFIX:=kind-}"
HUB_NAME="${HUB_NAME:=hub}"
defaut_cluster_names=("mcluster1" "mcluster2")
MANAGED_CLUSTERS_NAMES=("${MANAGED_CLUSTERS_NAMES[@]:-${defaut_cluster_names[@]}}")

JOINED_CLUSTER_NAMES="$(join_by , ${MANAGED_CLUSTERS_NAMES[@]})"

echo "⏲️  Initializing OCM cluster hub..."
clusteradm init --wait --context "${CONTEXT_PREFIX}${HUB_NAME}" ${OCM_INIT_OPTS:=} --output-join-command-file='clusteradm-bootstrap-cmd'

echo -n " ${OCM_JOIN_OPTS:=} --context ${CONTEXT_PREFIX}\$1" | tee -a clusteradm-bootstrap-cmd > /dev/null
echo
echo "⏲️  Requesting registration for managed clusters"
for cluster in ${MANAGED_CLUSTERS_NAMES[@]}; do
  bash clusteradm-bootstrap-cmd "${cluster}"
done

echo
echo "✅  Accepting managed clusters on OCM cluster hub"
for cluster in ${MANAGED_CLUSTERS_NAMES[@]}; do
  clusteradm accept --clusters "${cluster}" --context "${CONTEXT_PREFIX}${HUB_NAME}"
done

clusteradm create clusterset deploy-clusterset --context "${CONTEXT_PREFIX}${HUB_NAME}"
clusteradm clusterset set deploy-clusterset --clusters "${JOINED_CLUSTER_NAMES}" --context "${CONTEXT_PREFIX}${HUB_NAME}"

echo
echo "🚀  Deploying Argo CD..."
kubectl create namespace argocd --context ${CONTEXT_PREFIX}${HUB_NAME}
# TODO: check if those namespaces are required
for cluster in ${MANAGED_CLUSTERS_NAMES[@]}; do
  kubectl create namespace argocd --context "${CONTEXT_PREFIX}${cluster}"
done

clusteradm clusterset bind deploy-clusterset --namespace argocd --context "${CONTEXT_PREFIX}${HUB_NAME}"

kubectl apply -n argocd --wait -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --context "${CONTEXT_PREFIX}${HUB_NAME}"

kubectl -n argocd  wait --for=condition=available --all deployments  --context "${CONTEXT_PREFIX}${HUB_NAME}" --timeout=3m

kubectl -n argocd  --context "${CONTEXT_PREFIX}${HUB_NAME}"  apply --wait -f ./manifests/cluster-role-placement-read.yaml
kubectl -n argocd  --context "${CONTEXT_PREFIX}${HUB_NAME}"  apply --wait -f ./manifests/placement-cm.yaml

ARGO_PSWD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"  --context "${CONTEXT_PREFIX}${HUB_NAME}"  | base64 -d; echo)"

nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 --context "${CONTEXT_PREFIX}${HUB_NAME}" </dev/null >/dev/null 2>&1 &
sleep 30
export ARGOCD_OPTS='--port-forward-namespace argocd'
# TODO check if we can do better than echoing response (--yes option is not present for login command)
echo "Registering managed clusters in Argo CD"
echo -e 'y\ny' | argocd login localhost:8080 --username admin --password "${ARGO_PSWD}"  --kube-context "${CONTEXT_PREFIX}${HUB_NAME}"
for cluster in ${MANAGED_CLUSTERS_NAMES[@]}; do
  argocd cluster add "${CONTEXT_PREFIX}${cluster}" --name "${cluster}" --kube-context "${CONTEXT_PREFIX}${HUB_NAME}" --yes
done

echo
echo "🎉  We are done! Argo CD GUI is accessible at: https://127.0.0.1:8080 (admin / ${ARGO_PSWD})"
