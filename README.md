# Open Cluster Management + Argo CD experiments

This repository contains experiment materials to setup an [Argo CD](https://argo-cd.readthedocs.io/en/stable/)
cluster that can use [OCM](https://open-cluster-management.io/concepts/) to place applications to target clusters.

## Setup using kind

[kind](https://kind.sigs.k8s.io/) is a tool for running local Kubernetes clusters using Docker.

This setup will create a 3 single-node kind clusters:

* hub: contains the OCM hub and Argo CD server
* cluster1 and cluster2: are OCM managed clusters and are used as deploy environments by Argo

The following binaries should be present in our path for setting up this infrastructure:

* [docker](https://docs.docker.com/engine/install/)
* [kind](https://kind.sigs.k8s.io/docs/user/quick-start)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [clusteradm](https://open-cluster-management.io/getting-started/quick-start/#install-clusteradm-cli-tool)
* [argocd](https://argo-cd.readthedocs.io/en/stable/getting_started/#2-download-argo-cd-cli)

Then you can run the `setup_with_kind.sh` to install the infrastructure.
If you need some proxies to access internet you should export your proxy settings before running the command:

```bash
export http_proxy="..."
export https_proxy="..."
export no_proxy="127.0.0.1,172.17.0.1(,...)"
./setup_with_kind.sh
```

## Deploy the demo application

Now we will first deploy a placement policy that in our case will request to deploy the application on both cluster1 and cluster2.
And then we will deploy the actual application using an ApplicationSet (a kind of application template).

You can follow the deployment in the Argo UI.

```bash
# Deploy a placement policy
kubectl -n argocd  --context kind-hub  apply --wait -f ./manifests/placement.yaml
# Deploy the app
kubectl -n argocd  --context kind-hub  apply --wait -f ./manifests/argocd_application_set.yaml
```

## Cleanup

Simply run the following command to delete kind clusters:

```bash
kind delete clusters cluster1 cluster2 hub
```
