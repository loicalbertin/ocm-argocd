#!/usr/bin/env bash

set -euo pipefail

# Prerequirements:
# - docker
# - kubectl
# - kind
# - clusteradm
# - argocd

# TODOs:
# - check http(s)_proxy
# - install some prerequirements automatically

kind create cluster --name hub --config ./manifests/kind-cluster-config.yaml
echo
kind create cluster --name cluster1 --config ./manifests/kind-cluster-config.yaml
echo
kind create cluster --name cluster2 --config ./manifests/kind-cluster-config.yaml
echo

echo "⏲️  Initializing OCM cluster hub..."
clusteradm init --wait --context kind-hub --use-bootstrap-token --output-join-command-file='clusteradm-bootstrap-cmd'

echo -n ' --force-internal-endpoint-lookup --context kind-$1' | tee -a clusteradm-bootstrap-cmd > /dev/null
echo
echo "⏲️   Requesting registration for managed clusters"
bash clusteradm-bootstrap-cmd cluster1
bash clusteradm-bootstrap-cmd cluster2

echo
echo "✅  Accepting managed clusters on OCM cluster hub"
clusteradm accept --clusters cluster1 --context kind-hub
clusteradm accept --clusters cluster2 --context kind-hub

clusteradm create clusterset deploy-clusterset --context kind-hub
clusteradm clusterset set deploy-clusterset --clusters cluster1,cluster2 --context kind-hub

echo
echo "🚀  Deploying Argo CD..."
kubectl create namespace argocd --context kind-hub
# TODO: check if those namespaces are required
kubectl create namespace argocd --context kind-cluster1
kubectl create namespace argocd --context kind-cluster2

clusteradm clusterset bind deploy-clusterset --namespace argocd --context kind-hub

kubectl apply -n argocd --wait -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --context kind-hub

kubectl -n argocd  wait --for=condition=available --all deployments  --context kind-hub --timeout=3m

kubectl -n argocd  --context kind-hub  apply --wait -f ./manifests/cluster-role-placement-read.yaml
kubectl -n argocd  --context kind-hub  apply --wait -f ./manifests/placement-cm.yaml

ARGO_PSWD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"  --context kind-hub  | base64 -d; echo)"

nohup kubectl port-forward svc/argocd-server -n argocd 8080:443 --context kind-hub </dev/null >/dev/null 2>&1 &
sleep 30
export ARGOCD_OPTS='--port-forward-namespace argocd'
# TODO check if we can do better than echoing response (--yes option is not present for login command)
echo "Registering managed clusters in Argo CD"
echo -e 'y\ny' | argocd login localhost:8080 --username admin --password "${ARGO_PSWD}"  --kube-context kind-hub
argocd cluster add kind-cluster1 --name cluster1 --kube-context kind-hub --yes
argocd cluster add kind-cluster2 --name cluster2 --kube-context kind-hub --yes

echo
echo "🎉  We are done! Argo CD GUI is accessible at: https://127.0.0.1:8080 (admin / ${ARGO_PSWD})"
