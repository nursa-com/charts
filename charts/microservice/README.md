# Microservices

This chart is a template for a simple microservice with some configurable options.

Below you can see the instructions of how to use it and configure it.
If you need more details and examples of configuration, check the `values.yaml` file.

## TL;DR

```console
helm install <release-name> charts/microservice
```
or

```console
helm install <release-name> oci://nursa-com.github.io/charts/microservice
```

## Introduction
Helm charts are groups of Kubernetes resources, with customizable behavior. The behavior is defined in the values files, check `values.yaml` of each chart to validate the default values and the options to customize the usage.

The charts in this repository are public, and easily downloaded and reused. We recommend the usage of this chart as a [depencency](https://helm.sh/docs/helm/helm_dependency/) of other charts, but not necessarily.

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

## Updating this chart
To update this repo and publish a new chart, 2 things are required:
- new changes to the chart merged to the `main` branch
- a new version is updated in the `Chart.yaml` (for intance, update it from `version: 1.8.0` to `version: 1.9.0`)

If the 2 conditions are met, a new automation will be triggered that will create a new release in Github with the corresponding version. Also, a new commit to the branch `gh-pages` will be added updating the `index.html` file with the new tarball file in its list, so helm clients know that there is a new version available.

If you are using this chart as a dependency, you can set the dependency like the following. This way, if the update was a patch/minor version, your chart will be automatically updated with the new features at the next deployment. Major changes will be applied when breaking changes are introduced.
```
dependencies:
  - name: microservice
    version: "1.x"
    repository: "https://nursa-com.github.io/charts"
```
## Configuration and installation details

### Customize your implementation
To customize your implementation, you should update the values as described in the `values.yaml` file. If you are using this chart as a dependency, you can create a new values file in the parent chart, and customize the behavior of this chart like the following example:

```parent-chart-values.yaml
microservice:
  parameters: {}
  image: my-custom-image
  image_tag: my-custom-tag
  ...
  ...
  ...
  any_parameter_to_override_from_default: custom value
```

If you need to update the values dinamically, such as in CI/CD for an image_tag, it's possible to set values in the helm commands, for instance:
```
helm install <release-name> oci://nursa-com.github.io/charts/microservice --set "image_tag=$image_tag"
```
and if you are using the chart as a dependency:
```
helm install <release-name> <parent_chart> --set "microservice.image_tag=$image_tag"
```

### Resource requests and limits

This chart allows setting min/max resources for all containers inside the chart deployment. Setting requests is essential for production workloads and these should be adapted to your specific use case.

To make this process easier, the chart contains the default values for a small application, and the scaling configuration. Ideally, never set the minimum of replicas to something lower than 2, unless for a specific need. This way we can have the app always available even during cluster operations. Find more information on container resource management in the [official Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
