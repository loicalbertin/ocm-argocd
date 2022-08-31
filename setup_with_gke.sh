#!/usr/bin/env bash

set -euo pipefail

set -x

# Prerequirements:
# - gcloud
# - gcloud components install gke-gcloud-auth-plugin
# - kubectl
# - clusteradm
# - argocd

# TODOs:
# - check http(s)_proxy
# - install some prerequirements automatically
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

gcloud container clusters create ocm-hub --zone=europe-west1-b --num-nodes=1 --quiet
gcloud container clusters get-credentials ocm-hub --zone=europe-west1-b
echo
gcloud container clusters create ocm-mcluster1 --zone=europe-west1-b --num-nodes=1 --quiet
gcloud container clusters get-credentials ocm-mcluster1 --zone=europe-west1-b
echo
gcloud container clusters create ocm-mcluster2 --zone=europe-west1-b --num-nodes=1 --quiet
gcloud container clusters get-credentials ocm-mcluster1 --zone=europe-west1-b
echo

export CONTEXT_PREFIX="$(kubectl config get-contexts -o name | grep ocm-hub | sed -e 's/ocm-hub//g')"
export HUB_NAME="ocm-hub"
export MANAGED_CLUSTERS_NAMES=("ocm-mcluster1" "ocm-mcluster2")

. ./scripts/setup.sh
