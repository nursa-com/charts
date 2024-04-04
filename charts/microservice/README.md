# Microservices

This chart is a template for a simple microservice with some configurable options.

Below you can see the instructions of how to use it and configure it.
If you need more details and examples of configuration, check the `values.yaml` file.

## TL;DR

```console
helm install my-release oci://registry-1.docker.io/bitnamicharts/haproxy
```

Looking to use HAProxy in production? Try [VMware Tanzu Application Catalog](https://bitnami.com/enterprise), the enterprise edition of Bitnami Application Catalog.

## Introduction

Bitnami charts for Helm are carefully engineered, actively maintained and are the quickest and easiest way to deploy containers on a Kubernetes cluster that are ready to handle production workloads.

This chart bootstraps a [HAProxy](https://github.com/haproxytech/haproxy) Deployment in a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

Bitnami charts can be used with [Kubeapps](https://kubeapps.dev/) for deployment and management of Helm Charts in clusters.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.8.0+

## Using the Chart in a microservice

Add the repository to your local shell. To name it `nursa` use the following command:

```console
helm add repo nursa https://nursa-com.github.io/charts
```

To install the chart with the release name `my-app` using the:

```console
helm install my-app oci://nursa-com.github.io/charts/microservice
```

> Note: This installation sets the default values from `values.yaml`.

> **Tip**: List all releases using `helm list`

## Configuration and installation details

### Resource requests and limits

This chart allows setting min/max resources for all containers inside the chart deployment. Setting requests is essential for production workloads and these should be adapted to your specific use case.

To make this process easier, the chart contains the default values for a small application, and the scaling configuration. Ideally, never set the minimum of replicas to something lower than 2, unless for a specific need. This way we can have the app always available even during cluster operations. Find more information on container resource management in the [official Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
