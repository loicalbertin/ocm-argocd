#!/usr/bin/env bash

set -euo pipefail

set -x

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
kind create cluster --name mcluster1 --config ./manifests/kind-cluster-config.yaml
echo
kind create cluster --name mcluster2 --config ./manifests/kind-cluster-config.yaml
echo

export CONTEXT_PREFIX="kind-"
export HUB_NAME="hub"
export MANAGED_CLUSTERS_NAMES=("mcluster1" "mcluster2")
export OCM_INIT_OPTS="--use-bootstrap-token "
export OCM_JOIN_OPTS="--force-internal-endpoint-lookup "

. ./scripts/setup.sh
